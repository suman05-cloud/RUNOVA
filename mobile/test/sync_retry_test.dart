import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runova/core/storage/auth_store.dart';
import 'package:runova/core/storage/local_database.dart';
import 'package:runova/features/run/data/run_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('partial upload retries stable batches and deletes samples only after confirmation', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
    );
    addTearDown(db.close);
    await db.execute(
      'CREATE TABLE local_runs (id TEXT PRIMARY KEY, session_nonce TEXT, '
      'user_id TEXT, started_at TEXT, finished_at TEXT, state TEXT, sync_status TEXT, '
      'elapsed_seconds INTEGER, moving_seconds INTEGER, result_json TEXT)',
    );
    await db.execute(
      'CREATE TABLE gps_points (run_id TEXT, sequence INTEGER, latitude REAL, '
      'longitude REAL, recorded_at TEXT, monotonic_ms INTEGER, accuracy REAL, '
      'altitude REAL, speed REAL, heading REAL)',
    );
    await db.execute(
      'CREATE TABLE sensor_segments (run_id TEXT, sequence INTEGER, start_ms INTEGER, '
      'end_ms INTEGER, acceleration_variance REAL, cadence_hz REAL, mean_jerk REAL)',
    );
    final store = LocalDatabase(database: db);
    await store.createRun('run-one', 'nonce', DateTime.utc(2026), 'user-one');
    await store.createRun(
      'other-run',
      'other-nonce',
      DateTime.utc(2026),
      'user-two',
    );
    final seed = db.batch();
    for (var i = 0; i < 501; i++) {
      seed.insert('gps_points', {
        'run_id': 'run-one',
        'sequence': i,
        'latitude': 22.0,
        'longitude': 88.0,
        'recorded_at': DateTime.utc(2026).toIso8601String(),
        'monotonic_ms': i * 2000,
        'accuracy': 5.0,
      });
    }
    for (var i = 0; i < 201; i++) {
      seed.insert('sensor_segments', {
        'run_id': 'run-one',
        'sequence': i,
        'start_ms': i * 5000,
        'end_ms': (i + 1) * 5000,
        'acceleration_variance': 1.0,
        'cadence_hz': 2.0,
        'mean_jerk': 1.0,
      });
    }
    await seed.commit(noResult: true);
    FlutterSecureStorage.setMockInitialValues({});
    final auth = AuthStore(const FlutterSecureStorage());
    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    final payloads = <String, String>{};
    var fail = true;
    dio.httpClientAdapter = TestAdapter((options) {
      if (options.path.endsWith('/batches')) {
        final body = options.data as Map<String, dynamic>;
        expect((body['points'] as List).length, lessThanOrEqualTo(500));
        expect(
          (body['sensor_segments'] as List).length,
          lessThanOrEqualTo(100),
        );
        final id = body['batch_id'] as String;
        if (payloads.containsKey(id)) {
          expect(jsonEncode(body), payloads[id]);
        } else {
          payloads[id] = jsonEncode(body);
        }
        if (fail && payloads.length == 2) return (503, {'detail': 'offline'});
        return (200, {'duplicate': false});
      }
      return (
        200,
        {
          'validation_status': 'VERIFIED',
          'activity_type': 'RUNNING',
          'trust_score': 90,
          'xp_earned': 12,
          'level': 1,
          'distance_meters': 1000,
          'territory_changes': <Object>[],
        },
      );
    });
    final repo = RunRepository(dio, store, auth);
    await expectLater(
      repo.uploadAndFinish(
        run: const RemoteRunSession(
          id: 'run-one',
          nonce: 'nonce',
          userId: 'user-one',
        ),
        finishedAt: DateTime.utc(2026, 1, 1, 1),
        elapsedSeconds: 3600,
        movingSeconds: 1000,
      ),
      throwsA(isA<DioException>()),
    );
    expect((await store.gpsPoints('run-one')).length, 501);
    expect((await store.sensorSegments('run-one')).length, 201);
    final pending = await store.pendingRuns('user-one');
    expect(pending.length, 1);
    expect(await store.pendingRuns('user-two'), isEmpty);
    fail = false;
    await repo.syncRun(pending.single);
    expect(payloads.length, 5);
    expect(await store.gpsPoints('run-one'), isEmpty);
    expect(await store.sensorSegments('run-one'), isEmpty);
    expect(await store.pendingRuns('user-one'), isEmpty);
    final rows = await db.query(
      'local_runs',
      where: 'id = ?',
      whereArgs: ['run-one'],
    );
    expect(rows.single['sync_status'], 'SYNCED');
    expect(rows.single['session_nonce'], '');
  });
}
