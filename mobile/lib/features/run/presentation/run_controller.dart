import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:runova/core/network/api_client.dart';
import 'package:runova/core/storage/local_database.dart';
import 'package:runova/features/run/data/run_repository.dart';
import 'package:runova/features/run/domain/run_session.dart';
import 'package:sensors_plus/sensors_plus.dart';

final localDatabaseProvider = Provider<LocalDatabase>((ref) => LocalDatabase());
final runRepositoryProvider = Provider<RunRepository>(
  (ref) => RunRepository(
    ref.watch(apiClientProvider),
    ref.watch(localDatabaseProvider),
    ref.watch(authStoreProvider),
  ),
);
final runSessionProvider = NotifierProvider<RunController, RunSession>(RunController.new);

class RunController extends Notifier<RunSession> {
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

  @override
  RunSession build() {
    ref.onDispose(_dispose);
    return const RunSession();
  }

  Future<void> start() async {
    if (_busy || state.phase != RunPhase.idle) return;
    _busy = true;
    state = state.copyWith(gpsStatus: 'CONNECTING', clearError: true);
    try {
      await _ensureLocationPermission();
      _remoteRun = await ref.read(runRepositoryProvider).start(DateTime.now());
      _monotonic
        ..reset()
        ..start();
      state = const RunSession(phase: RunPhase.running, gpsStatus: 'SEARCHING');
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
    }
  }

  Future<void> pause() async {
    if (state.phase != RunPhase.running) return;
    _timer?.cancel();
    await _stopStreams();
    _monotonic.stop();
    state = state.copyWith(phase: RunPhase.paused, gpsStatus: 'PAUSED');
  }

  void resume() {
    if (state.phase != RunPhase.paused) return;
    _monotonic.start();
    state = state.copyWith(phase: RunPhase.running, gpsStatus: 'SEARCHING');
    _startTimer();
    _startStreams();
  }

  Future<void> finish() async {
    if (!state.isActive || _busy || _remoteRun == null) return;
    _busy = true;
    _timer?.cancel();
    await _stopStreams();
    _monotonic.stop();
    state = state.copyWith(gpsStatus: 'UPLOADING', clearError: true);
    try {
      final result = await ref.read(runRepositoryProvider).uploadAndFinish(
            run: _remoteRun!,
            finishedAt: DateTime.now(),
            elapsedSeconds: state.elapsed.inSeconds,
            movingSeconds: state.elapsed.inSeconds,
          );
      state = state.copyWith(
        phase: RunPhase.completed,
        gpsStatus: 'COMPLETE',
        activityType: result.activity,
        result: RunResult(
          status: result.status,
          trustScore: result.trustScore,
          xp: result.xp,
          level: result.level,
          territoryCount: result.territoryCount,
        ),
      );
    } catch (error) {
      state = state.copyWith(
        phase: RunPhase.paused,
        gpsStatus: 'UPLOAD FAILED',
        error: '${_friendlyError(error)} Your samples remain on this device.',
      );
    } finally {
      _busy = false;
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
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
    _positionSubscription = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onPosition,
      onError: (Object error) {
        state = state.copyWith(gpsStatus: 'GPS ERROR', error: _friendlyError(error));
      },
    );
    _segmentStartedMs = _monotonic.elapsedMilliseconds;
    _sensorSubscription = userAccelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(_onAcceleration);
  }

  Future<void> _onPosition(Position position) async {
    if (state.phase != RunPhase.running || _remoteRun == null) return;
    final previous = _previousPosition;
    var addedDistance = 0.0;
    if (previous != null && position.accuracy <= 50) {
      addedDistance = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        position.latitude,
        position.longitude,
      );
      final seconds = position.timestamp.difference(previous.timestamp).inMilliseconds / 1000;
      if (seconds > 0) _latestSpeed = addedDistance / seconds;
      if (_latestSpeed > 25) addedDistance = 0;
    }
    _previousPosition = position;
    final sequence = _pointSequence++;
    await ref.read(runRepositoryProvider).storePoint(_remoteRun!.id, {
      'sequence': sequence,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'recorded_at': position.timestamp.toUtc().toIso8601String(),
      'monotonic_ms': _monotonic.elapsedMilliseconds,
      'accuracy': position.accuracy,
      'altitude': position.altitude,
      'speed': position.speed < 0 ? null : position.speed,
      'heading': position.heading < 0 ? null : position.heading,
    });
    state = state.copyWith(
      distanceMeters: state.distanceMeters + addedDistance,
      gpsStatus: position.accuracy <= 35 ? 'GPS GOOD' : 'GPS WEAK',
      pointCount: _pointSequence,
      activityType: _localActivity(),
    );
  }

  void _onAcceleration(UserAccelerometerEvent event) {
    if (state.phase != RunPhase.running || _remoteRun == null) return;
    final magnitude = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
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
    final variance = samples
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
    await ref.read(runRepositoryProvider).storeSensorSegment(_remoteRun!.id, {
      'sequence': _sensorSequence++,
      'start_ms': start,
      'end_ms': end,
      'acceleration_variance': variance,
      'cadence_hz': end > start ? peaks / ((end - start) / 1000) : 0.0,
      'mean_jerk': samples.length > 1 ? jerkTotal / (samples.length - 1) : 0.0,
    });
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
      state = state.copyWith(elapsed: state.elapsed + const Duration(seconds: 1));
    });
  }

  Future<void> _stopStreams() async {
    await _positionSubscription?.cancel();
    await _sensorSubscription?.cancel();
    _positionSubscription = null;
    _sensorSubscription = null;
    await _flushSensorSegment();
  }

  void _disposeStreamsOnly() {
    _timer?.cancel();
    unawaited(_positionSubscription?.cancel());
    unawaited(_sensorSubscription?.cancel());
    _positionSubscription = null;
    _sensorSubscription = null;
  }

  void _dispose() {
    _disposeStreamsOnly();
    _monotonic.stop();
  }
}

String _friendlyError(Object error) {
  if (error is StateError) return error.message;
  return 'Could not record this run. Check the API and phone permissions.';
}
