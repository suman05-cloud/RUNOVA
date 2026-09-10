import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  // ignore: prefer_initializing_formals
  LocalDatabase({Database? database}) : _database = database;
  Database? _database;
  Future<Database>? _opening;

  Future<Database> get database async {
    if (_database != null) return _database!;
    return _opening ??= _open();
  }

  Future<Database> _open() async {
    final directory = await getApplicationDocumentsDirectory();
    _database = await openDatabase(
      p.join(directory.path, 'runova.db'),
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE local_runs ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'LEGACY'",
          );
          await db.execute('ALTER TABLE local_runs ADD COLUMN user_id TEXT');
          await db.execute(
            'ALTER TABLE local_runs ADD COLUMN result_json TEXT',
          );
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE local_runs (
            id TEXT PRIMARY KEY,
            session_nonce TEXT NOT NULL,
            started_at TEXT NOT NULL,
            finished_at TEXT,
            state TEXT NOT NULL,
            sync_status TEXT NOT NULL DEFAULT 'RECORDING',
            user_id TEXT,
            result_json TEXT,
            elapsed_seconds INTEGER NOT NULL DEFAULT 0,
            moving_seconds INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE gps_points (
            run_id TEXT NOT NULL,
            sequence INTEGER NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            recorded_at TEXT NOT NULL,
            monotonic_ms INTEGER NOT NULL,
            accuracy REAL NOT NULL,
            altitude REAL,
            speed REAL,
            heading REAL,
            PRIMARY KEY (run_id, sequence)
          )
        ''');
        await db.execute('''
          CREATE TABLE sensor_segments (
            run_id TEXT NOT NULL,
            sequence INTEGER NOT NULL,
            start_ms INTEGER NOT NULL,
            end_ms INTEGER NOT NULL,
            acceleration_variance REAL NOT NULL,
            cadence_hz REAL NOT NULL,
            mean_jerk REAL NOT NULL,
            PRIMARY KEY (run_id, sequence)
          )
        ''');
      },
    );
    return _database!;
  }

  Future<void> createRun(
    String id,
    String nonce,
    DateTime startedAt,
    String userId,
  ) async {
    final db = await database;
    await db.insert('local_runs', {
      'id': id,
      'session_nonce': nonce,
      'started_at': startedAt.toUtc().toIso8601String(),
      'state': 'STARTED',
      'user_id': userId,
    });
  }

  Future<void> addGpsPoint(String runId, Map<String, Object?> point) async {
    final db = await database;
    await db.insert('gps_points', {'run_id': runId, ...point});
  }

  Future<void> addSensorSegment(
    String runId,
    Map<String, Object?> segment,
  ) async {
    final db = await database;
    await db.insert('sensor_segments', {'run_id': runId, ...segment});
  }

  Future<List<Map<String, Object?>>> gpsPoints(String runId) async {
    final db = await database;
    return db.query(
      'gps_points',
      where: 'run_id = ?',
      whereArgs: [runId],
      orderBy: 'sequence',
    );
  }

  Future<List<Map<String, Object?>>> sensorSegments(String runId) async {
    final db = await database;
    return db.query(
      'sensor_segments',
      where: 'run_id = ?',
      whereArgs: [runId],
      orderBy: 'sequence',
    );
  }

  Future<void> finishRun(
    String runId,
    DateTime finishedAt,
    int elapsedSeconds,
    int movingSeconds,
  ) async {
    final db = await database;
    await db.update(
      'local_runs',
      {
        'finished_at': finishedAt.toUtc().toIso8601String(),
        'state': 'FINISHED',
        'sync_status': 'PENDING_SYNC',
        'elapsed_seconds': elapsedSeconds,
        'moving_seconds': movingSeconds,
      },
      where: 'id = ?',
      whereArgs: [runId],
    );
  }

  Future<List<Map<String, Object?>>> pendingRuns(String userId) async {
    final db = await database;
    return db.query(
      'local_runs',
      where: 'user_id = ? AND sync_status = ?',
      whereArgs: [userId, 'PENDING_SYNC'],
      orderBy: 'started_at',
    );
  }

  Future<void> markSynced(String runId, String resultJson) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'local_runs',
        {
          'sync_status': 'SYNCED',
          'result_json': resultJson,
          'session_nonce': '',
        },
        where: 'id = ?',
        whereArgs: [runId],
      );
      await txn.delete('gps_points', where: 'run_id = ?', whereArgs: [runId]);
      await txn.delete(
        'sensor_segments',
        where: 'run_id = ?',
        whereArgs: [runId],
      );
    });
  }
}
