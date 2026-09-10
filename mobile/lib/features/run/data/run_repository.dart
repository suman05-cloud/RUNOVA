import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:runova/core/storage/auth_store.dart';
import 'package:runova/core/storage/local_database.dart';
import 'package:uuid/uuid.dart';

class RemoteRunSession {
  const RemoteRunSession({
    required this.id,
    required this.nonce,
    required this.userId,
  });
  final String id;
  final String nonce;
  final String userId;
}

class FinishResult {
  FinishResult(this.json);
  final Map<String, dynamic> json;
  String get status => json['validation_status'] as String;
  String get activity => json['activity_type'] as String;
  int get trustScore => json['trust_score'] as int;
  int get xp => json['xp_earned'] as int;
  int get level => json['level'] as int;
  int get territoryCount => (json['territory_changes'] as List).length;
  double get distance => (json['distance_meters'] as num).toDouble();
}

class RunRepository {
  RunRepository(this._dio, this._database, this._authStore);
  final Dio _dio;
  final LocalDatabase _database;
  final AuthStore _authStore;
  final Map<String, Future<FinishResult>> _syncing = {};

  Future<RemoteRunSession> start(DateTime startedAt) async {
    final userId = (await _authStore.readProfile())?['id'] as String?;
    if (userId == null) throw StateError('Sign in before starting a run.');
    var installationId = await _authStore.readDeviceId();
    if (installationId == null) {
      installationId = const Uuid().v4();
      await _authStore.saveDeviceId(installationId);
    }
    // The backend binds a registration to one account.
    final deviceId = const Uuid().v5(
      Namespace.url.value,
      '$installationId/$userId',
    );
    final info = await DeviceInfoPlugin().androidInfo;
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/runs',
      options: Options(extra: {'userId': userId}),
      data: {
        'device': {
          'id': deviceId,
          'os_version': info.version.release,
          'model': '${info.manufacturer} ${info.model}',
          'app_version': '0.1.0',
        },
        'client_started_at': startedAt.toUtc().toIso8601String(),
      },
    );
    final body = response.data!;
    final run = RemoteRunSession(
      id: body['run_id'] as String,
      nonce: body['session_nonce'] as String,
      userId: userId,
    );
    await _database.createRun(run.id, run.nonce, startedAt, userId);
    return run;
  }

  Future<void> storePoint(String runId, Map<String, Object?> point) =>
      _database.addGpsPoint(runId, point);
  Future<void> storeSensorSegment(String runId, Map<String, Object?> segment) =>
      _database.addSensorSegment(runId, segment);

  Future<bool> isPending(RemoteRunSession run) async =>
      (await _database.pendingRuns(run.userId))
          .any((row) => row['id'] == run.id);

  Future<FinishResult> uploadAndFinish({
    required RemoteRunSession run,
    required DateTime finishedAt,
    required int elapsedSeconds,
    required int movingSeconds,
  }) async {
    // Persist the immutable finish envelope BEFORE any network attempt.
    await _database.finishRun(
      run.id,
      finishedAt,
      elapsedSeconds,
      movingSeconds,
    );
    return syncRun({
      'id': run.id,
      'user_id': run.userId,
      'session_nonce': run.nonce,
      'finished_at': finishedAt.toUtc().toIso8601String(),
      'elapsed_seconds': elapsedSeconds,
      'moving_seconds': movingSeconds,
    });
  }

  Future<FinishResult> syncRun(Map<String, Object?> row) {
    final id = row['id'] as String;
    return _syncing.putIfAbsent(
      id,
      () => _upload(row).whenComplete(() {
        _syncing.remove(id);
      }),
    );
  }

  Future<FinishResult> _upload(Map<String, Object?> row) async {
    final id = row['id'] as String;
    final nonce = row['session_nonce'] as String;
    final options = Options(extra: {'userId': row['user_id']});
    final points = await _database.gpsPoints(id);
    final segments = await _database.sensorSegments(id);
    // Separate bounded streams: long runs may have thousands of sensor windows.
    for (var offset = 0; offset < points.length; offset += 500) {
      final batch = points.sublist(
        offset,
        (offset + 500).clamp(0, points.length),
      );
      await _dio.put<void>(
        '/v1/runs/$id/batches',
        options: options,
        data: {
          'batch_id': batchId(id, 'gps', offset),
          'session_nonce': nonce,
          'first_sequence': batch.first['sequence'],
          'last_sequence': batch.last['sequence'],
          'points': batch.map(_pointPayload).toList(),
          'sensor_segments': <Object>[],
        },
      );
    }
    for (var offset = 0; offset < segments.length; offset += 100) {
      final batch = segments.sublist(
        offset,
        (offset + 100).clamp(0, segments.length),
      );
      await _dio.put<void>(
        '/v1/runs/$id/batches',
        options: options,
        data: {
          'batch_id': batchId(id, 'sensors', offset),
          'session_nonce': nonce,
          'first_sequence': 0,
          'last_sequence': 0,
          'points': <Object>[],
          'sensor_segments': batch.map(_sensorPayload).toList(),
        },
      );
    }
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/runs/$id/finish',
      options: options,
      data: {
        'session_nonce': nonce,
        'client_finished_at': row['finished_at'],
        'elapsed_seconds': row['elapsed_seconds'],
        'moving_seconds': row['moving_seconds'],
      },
    );
    await _database.markSynced(id, jsonEncode(response.data!));
    return FinishResult(response.data!);
  }
}

String batchId(String runId, String stream, int offset) =>
    const Uuid().v5(Namespace.url.value, 'runova/$runId/$stream/$offset');

Map<String, Object?> _pointPayload(Map<String, Object?> row) => {
  'sequence': row['sequence'],
  'latitude': row['latitude'],
  'longitude': row['longitude'],
  'client_recorded_at': row['recorded_at'],
  'monotonic_ms': row['monotonic_ms'],
  'accuracy_meters': row['accuracy'],
  'altitude_meters': row['altitude'],
  'speed_mps': row['speed'],
  'heading_degrees': row['heading'],
};
Map<String, Object?> _sensorPayload(Map<String, Object?> row) => {
  'sequence': row['sequence'],
  'start_monotonic_ms': row['start_ms'],
  'end_monotonic_ms': row['end_ms'],
  'features': {
    'acceleration_variance': row['acceleration_variance'],
    'cadence_hz': row['cadence_hz'],
    'mean_jerk': row['mean_jerk'],
  },
};
