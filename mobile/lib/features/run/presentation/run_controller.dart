import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:runova/core/network/api_client.dart';
import 'package:runova/core/storage/local_database.dart';
import 'package:runova/features/auth/presentation/auth_controller.dart';
import 'package:runova/features/run/data/run_repository.dart';
import 'package:runova/features/run/domain/run_session.dart';
import 'package:runova/features/run/domain/run_clock.dart';
import 'package:sensors_plus/sensors_plus.dart';

final localDatabaseProvider = Provider<LocalDatabase>((ref) => LocalDatabase());
final runRepositoryProvider = Provider<RunRepository>(
  (ref) => RunRepository(
    ref.watch(apiClientProvider),
    ref.watch(localDatabaseProvider),
    ref.watch(authStoreProvider),
  ),
);
final runSessionProvider = NotifierProvider<RunController, RunSession>(
  RunController.new,
);

class RunController extends Notifier<RunSession> with WidgetsBindingObserver {
  Timer? _timer;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<UserAccelerometerEvent>? _sensorSubscription;
  final Stopwatch _monotonic = Stopwatch();
  final List<double> _accelerations = [];
  final List<int> _accelerationTimes = [];
  RemoteRunSession? _remoteRun;
  Position? _previousPosition;
  int _pointSequence = 0;
  int _sensorSequence = 0;
  int _segmentStartedMs = 0;
  double _latestSpeed = 0;
  bool _busy = false;
  final RunClock _clock = RunClock();
  double _movingSeconds = 0;
  Future<void> _writes = Future.value();
  Object? _writeError;
  DateTime? _lastGpsAt;
  DateTime? _lastSensorAt;
  bool _disposed = false;

  @override
  RunSession build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(_dispose);
    ref.listen(authControllerProvider, (before, after) {
      if (_remoteRun != null &&
          after.value?.id != _remoteRun!.userId &&
          state.phase == RunPhase.running) {
        unawaited(pause());
      }
    });
    return const RunSession();
  }

  Future<void> start() async {
    if (_busy || state.phase != RunPhase.idle) return;
    _busy = true;
    state = state.copyWith(
      gpsStatus: 'CONNECTING',
      clearError: true,
      busy: true,
    );
    try {
      await _ensureLocationPermission();
      await Permission.notification.request();
      await Permission.activityRecognition.request();
      final started = DateTime.now();
      _remoteRun = await ref.read(runRepositoryProvider).start(started);
      _clock.start(started);
      _monotonic
        ..reset()
        ..start();
      state = RunSession(
        phase: RunPhase.running,
        gpsStatus: 'SEARCHING',
        runId: _remoteRun!.id,
      );
      _startTimer();
      _startStreams();
    } catch (error) {
      state = state.copyWith(
        phase: RunPhase.idle,
        gpsStatus: 'UNAVAILABLE',
        error: _friendlyError(error),
      );
    } finally {
      _busy = false;
      if (!_disposed) state = state.copyWith(busy: false);
    }
  }

  Future<void> pause() async {
    if (state.phase != RunPhase.running || _busy) return;
    _busy = true;
    _clock.pause(DateTime.now());
    state = state.copyWith(
      phase: RunPhase.paused,
      gpsStatus: 'PAUSED',
      busy: true,
      elapsed: _clock.activeElapsed(DateTime.now()),
    );
    _timer?.cancel();
    await _stopStreams();
    _previousPosition = null;
    _busy = false;
    state = state.copyWith(busy: false);
  }

  void resume() {
    if (state.phase != RunPhase.paused || _busy) return;
    if (ref.read(authControllerProvider).value?.id != _remoteRun?.userId) {
      state = state.copyWith(
        error: 'Sign in to the account that started this run.',
      );
      return;
    }
    _clock.resume(DateTime.now());
    _monotonic.start();
    _previousPosition = null;
    state = state.copyWith(phase: RunPhase.running, gpsStatus: 'SEARCHING');
    _startTimer();
    _startStreams();
  }

  Future<void> finish() async {
    if (!state.isActive || _busy || _remoteRun == null) return;
    _busy = true;
    final stoppedAt = DateTime.now();
    _clock.pause(stoppedAt);
    _clock.finish(stoppedAt);
    state = state.copyWith(
      phase: RunPhase.paused,
      busy: true,
      elapsed: _clock.activeElapsed(DateTime.now()),
    );
    _timer?.cancel();
    await _stopStreams();
    _monotonic.stop();
    state = state.copyWith(gpsStatus: 'UPLOADING', clearError: true);
    try {
      await _writes;
      if (_writeError != null) {
        throw StateError('Some samples could not be saved locally.');
      }
      final result = await ref
          .read(runRepositoryProvider)
          .uploadAndFinish(
            run: _remoteRun!,
            finishedAt: DateTime.now(),
            elapsedSeconds: state.elapsed.inSeconds,
            movingSeconds: _movingSeconds.floor().clamp(
              0,
              state.elapsed.inSeconds,
            ),
          );
      state = state.copyWith(
        phase: RunPhase.completed,
        gpsStatus: 'COMPLETE',
        activityType: result.activity,
        distanceMeters: result.distance,
        result: RunResult(
          status: result.status,
          trustScore: result.trustScore,
          xp: result.xp,
          level: result.level,
          territoryCount: result.territoryCount,
        ),
      );
    } catch (error) {
      var pending = false;
      try {
        pending = await ref.read(runRepositoryProvider).isPending(_remoteRun!);
      } catch (_) {
        // A local database failure must not be reported as a saved run.
      }
      state = state.copyWith(
        phase: pending ? RunPhase.completed : RunPhase.paused,
        gpsStatus: 'PENDING SYNC',
        error: pending
            ? 'Run saved on this device. Sync will retry when connected.'
            : 'Could not save all samples. Check available storage before retrying.',
      );
    } finally {
      _busy = false;
      state = state.copyWith(busy: false);
    }
  }

  void reset() {
    _disposeStreamsOnly();
    _remoteRun = null;
    _previousPosition = null;
    _pointSequence = 0;
    _sensorSequence = 0;
    _accelerations.clear();
    _accelerationTimes.clear();
    _monotonic.reset();
    _movingSeconds = 0;
    _writeError = null;
    _writes = Future.value();
    state = const RunSession();
  }

  Future<void> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Turn on location services to start a run.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Location permission is required to record a run.');
    }
  }

  void _startStreams() {
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 2),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Recording run',
        notificationText: 'Runova is recording your route. Tap to return.',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen(
          _onPosition,
          onError: (Object error) {
            _lastGpsAt = null;
            state = state.copyWith(
              gpsStatus: 'GPS ERROR',
              error: _friendlyError(error),
            );
          },
        );
    _segmentStartedMs = _monotonic.elapsedMilliseconds;
    _sensorSubscription =
        userAccelerometerEventStream(
          samplingPeriod: SensorInterval.gameInterval,
        ).listen(
          _onAcceleration,
          onError: (Object error) {
            _lastSensorAt = null;
            if (!_disposed) {
              state = state.copyWith(
                error: 'Motion sensor unavailable; GPS is still recorded.',
              );
            }
          },
        );
  }

  void _onPosition(Position position) {
    if (state.phase != RunPhase.running || _remoteRun == null) return;
    final previous = _previousPosition;
    _lastGpsAt = DateTime.now();
    var addedDistance = 0.0;
    if (previous != null &&
        previous.accuracy <= 50 &&
        position.accuracy <= 50) {
      addedDistance = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        position.latitude,
        position.longitude,
      );
      final seconds =
          position.timestamp.difference(previous.timestamp).inMilliseconds /
          1000;
      if (seconds > 0) _latestSpeed = addedDistance / seconds;
      _movingSeconds += movingIntervalSeconds(
        _latestSpeed,
        seconds,
        position.accuracy,
      );
      if (_latestSpeed > 25 || seconds <= 0 || seconds > 30) addedDistance = 0;
    }
    _previousPosition = position;
    final sequence = _pointSequence++;
    final repository = ref.read(runRepositoryProvider);
    final runId = _remoteRun!.id;
    final point = <String, Object?>{
      'sequence': sequence,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'recorded_at': position.timestamp.toUtc().toIso8601String(),
      'monotonic_ms': _monotonic.elapsedMilliseconds,
      'accuracy': position.accuracy,
      'altitude': position.altitude,
      'speed': position.speed < 0 ? null : position.speed,
      'heading': position.heading < 0 ? null : position.heading,
    };
    _enqueue(() => repository.storePoint(runId, point));
    state = state.copyWith(
      distanceMeters: state.distanceMeters + addedDistance,
      gpsStatus: position.accuracy <= 35 ? 'GPS GOOD' : 'GPS WEAK',
      pointCount: _pointSequence,
      activityType: _localActivity(),
      movingSeconds: _movingSeconds.floor(),
    );
  }

  void _onAcceleration(UserAccelerometerEvent event) {
    if (state.phase != RunPhase.running || _remoteRun == null) return;
    _lastSensorAt = DateTime.now();
    final magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    _accelerations.add(magnitude);
    _accelerationTimes.add(_monotonic.elapsedMilliseconds);
    if (_monotonic.elapsedMilliseconds - _segmentStartedMs >= 5000) {
      unawaited(_flushSensorSegment());
    }
  }

  Future<void> _flushSensorSegment() async {
    if (_accelerations.isEmpty || _remoteRun == null) return;
    final samples = List<double>.from(_accelerations);
    final times = List<int>.from(_accelerationTimes);
    _accelerations.clear();
    _accelerationTimes.clear();
    final start = _segmentStartedMs;
    final end = _monotonic.elapsedMilliseconds;
    _segmentStartedMs = end;
    final mean = samples.reduce((a, b) => a + b) / samples.length;
    final variance =
        samples
            .map((sample) => math.pow(sample - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        samples.length;
    var peaks = 0;
    for (var index = 1; index < samples.length - 1; index++) {
      if (samples[index] > 1.2 &&
          samples[index] > samples[index - 1] &&
          samples[index] >= samples[index + 1]) {
        peaks++;
      }
    }
    var jerkTotal = 0.0;
    for (var index = 1; index < samples.length; index++) {
      final deltaSeconds = (times[index] - times[index - 1]) / 1000;
      if (deltaSeconds > 0) {
        jerkTotal += (samples[index] - samples[index - 1]).abs() / deltaSeconds;
      }
    }
    final repository = ref.read(runRepositoryProvider);
    final runId = _remoteRun!.id;
    final segment = <String, Object?>{
      'sequence': _sensorSequence++,
      'start_ms': start,
      'end_ms': end,
      'acceleration_variance': variance,
      'cadence_hz': end > start ? peaks / ((end - start) / 1000) : 0.0,
      'mean_jerk': samples.length > 1 ? jerkTotal / (samples.length - 1) : 0.0,
    };
    _enqueue(() => repository.storeSensorSegment(runId, segment));
  }

  String _localActivity() {
    if (_latestSpeed > 8) return 'CAR';
    if (_latestSpeed >= 3) return 'CYCLING / RUNNING';
    if (_latestSpeed >= 1.7) return 'RUNNING';
    if (_latestSpeed >= 0.5) return 'WALKING';
    return 'STATIONARY';
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(elapsed: _clock.activeElapsed(DateTime.now()));
    });
  }

  Future<void> _stopStreams() async {
    await _positionSubscription?.cancel();
    await _sensorSubscription?.cancel();
    _positionSubscription = null;
    _sensorSubscription = null;
    await _flushSensorSegment();
    await _writes;
  }

  void _disposeStreamsOnly() {
    _timer?.cancel();
    unawaited(_positionSubscription?.cancel());
    unawaited(_sensorSubscription?.cancel());
    _positionSubscription = null;
    _sensorSubscription = null;
  }

  void _dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _disposeStreamsOnly();
    _monotonic.stop();
  }

  void _enqueue(Future<void> Function() write) {
    _writes = _writes.then((_) => write()).catchError((Object error) {
      _writeError = error;
      if (!_disposed) {
        state = state.copyWith(
          error: 'Could not save a sample. Check device storage.',
        );
      }
    });
  }

  @override
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed &&
        state.phase == RunPhase.running &&
        !_busy) {
      unawaited(_recoverStreams());
    }
  }

  Future<void> _recoverStreams() async {
    final now = DateTime.now();
    state = state.copyWith(elapsed: _clock.activeElapsed(now));
    if (_lastGpsAt != null &&
        _lastSensorAt != null &&
        now.difference(_lastGpsAt!).inSeconds < 30 &&
        now.difference(_lastSensorAt!).inSeconds < 10) {
      return;
    }
    _busy = true;
    state = state.copyWith(busy: true);
    await _stopStreams();
    _previousPosition = null;
    if (!_disposed && state.phase == RunPhase.running) _startStreams();
    _busy = false;
    if (!_disposed) state = state.copyWith(busy: false);
  }
}

String _friendlyError(Object error) {
  if (error is StateError) return error.message;
  return 'Could not record this run. Check the API and phone permissions.';
}
