enum RunPhase { idle, running, paused, completed }

class RunSession {
  const RunSession({
    this.phase = RunPhase.idle,
    this.elapsed = Duration.zero,
    this.distanceMeters = 0,
    this.gpsStatus = 'READY',
    this.activityType = 'UNKNOWN',
    this.pointCount = 0,
    this.error,
    this.result,
  });

  final RunPhase phase;
  final Duration elapsed;
  final double distanceMeters;
  final String gpsStatus;
  final String activityType;
  final int pointCount;
  final String? error;
  final RunResult? result;

  bool get isActive => phase == RunPhase.running || phase == RunPhase.paused;

  double get averagePaceMinutesPerKm {
    if (distanceMeters <= 0) return 0;
    return elapsed.inSeconds / 60 / (distanceMeters / 1000);
  }

  RunSession copyWith({
    RunPhase? phase,
    Duration? elapsed,
    double? distanceMeters,
    String? gpsStatus,
    String? activityType,
    int? pointCount,
    String? error,
    bool clearError = false,
    RunResult? result,
  }) {
    return RunSession(
      phase: phase ?? this.phase,
      elapsed: elapsed ?? this.elapsed,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      gpsStatus: gpsStatus ?? this.gpsStatus,
      activityType: activityType ?? this.activityType,
      pointCount: pointCount ?? this.pointCount,
      error: clearError ? null : error ?? this.error,
      result: result ?? this.result,
    );
  }
}

class RunResult {
  const RunResult({
    required this.status,
    required this.trustScore,
    required this.xp,
    required this.level,
    required this.territoryCount,
  });

  final String status;
  final int trustScore;
  final int xp;
  final int level;
  final int territoryCount;
}
