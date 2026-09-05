import 'dart:io';

import 'package:dio/dio.dart';
import 'package:runova/core/storage/auth_store.dart';
import 'package:runova/core/storage/local_database.dart';
import 'package:uuid/uuid.dart';

class RemoteRunSession {
  const RemoteRunSession({required this.id, required this.nonce});

  final String id;
  final String nonce;
}

class FinishResult {
  const FinishResult({
    required this.status,
    required this.activity,
    required this.trustScore,
    required this.xp,
    required this.level,
    required this.territoryCount,
  });

  final String status;
  final String activity;
  final int trustScore;
  final int xp;
  final int level;
  final int territoryCount;
}

class RunRepository {
  const RunRepository(this._dio, this._database, this._authStore);

  final Dio _dio;
  final LocalDatabase _database;
  final AuthStore _authStore;

  Future<RemoteRunSession> start(DateTime startedAt) async {
    var deviceId = await _authStore.readDeviceId();
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await _authStore.saveDeviceId(deviceId);
    }
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/runs',
      data: {
        'device': {
          'id': deviceId,
          'os_version': Platform.operatingSystemVersion,
          'model': 'Android device',
        },
        'client_started_at': startedAt.toUtc().toIso8601String(),
      },
    );
    final body = response.data!;
    final session = RemoteRunSession(
      id: body['run_id'] as String,
      nonce: body['session_nonce'] as String,
    );
    await _database.createRun(session.id, session.nonce, startedAt);
    return session;
  }

  Future<void> storePoint(String runId, Map<String, Object?> point) =>
      _database.addGpsPoint(runId, point);

  Future<void> storeSensorSegment(String runId, Map<String, Object?> segment) =>
      _database.addSensorSegment(runId, segment);

  Future<FinishResult> uploadAndFinish({
    required RemoteRunSession run,
    required DateTime finishedAt,
    required int elapsedSeconds,
    required int movingSeconds,
  }) async {
    final points = await _database.gpsPoints(run.id);
    final segments = await _database.sensorSegments(run.id);
    for (var offset = 0; offset < points.length; offset += 500) {
      final end = (offset + 500).clamp(0, points.length);
      final batch = points.sublist(offset, end);
      await _dio.put<void>(
        '/v1/runs/${run.id}/batches',
        data: {
          'batch_id': const Uuid().v4(),
          'session_nonce': run.nonce,
          'first_sequence': batch.first['sequence'],
          'last_sequence': batch.last['sequence'],
          'points': batch.map(_pointPayload).toList(),
          'sensor_segments': offset == 0 ? segments.map(_sensorPayload).toList() : [],
        },
      );
    }
    if (points.isEmpty && segments.isNotEmpty) {
      await _dio.put<void>(
        '/v1/runs/${run.id}/batches',
        data: {
          'batch_id': const Uuid().v4(),
          'session_nonce': run.nonce,
          'first_sequence': 0,
          'last_sequence': 0,
          'points': <Object>[],
          'sensor_segments': segments.map(_sensorPayload).toList(),
        },
      );
    }
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/runs/${run.id}/finish',
      data: {
        'session_nonce': run.nonce,
        'client_finished_at': finishedAt.toUtc().toIso8601String(),
        'elapsed_seconds': elapsedSeconds,
        'moving_seconds': movingSeconds,
      },
    );
    await _database.finishRun(run.id, finishedAt, elapsedSeconds, movingSeconds);
    final body = response.data!;
    return FinishResult(
      status: body['validation_status'] as String,
      activity: body['activity_type'] as String,
      trustScore: body['trust_score'] as int,
      xp: body['xp_earned'] as int,
      level: body['level'] as int,
      territoryCount: (body['territory_changes'] as List<dynamic>).length,
    );
  }
}

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
