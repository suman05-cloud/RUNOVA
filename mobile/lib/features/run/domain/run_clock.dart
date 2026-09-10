/// Wall-clock durations are independent of Flutter timer scheduling.
class RunClock {
  DateTime? startedAt;
  DateTime? _pausedAt;
  DateTime? _finishedAt;
  Duration _paused = Duration.zero;

  void start(DateTime now) {
    startedAt = now;
    _pausedAt = null;
    _finishedAt = null;
    _paused = Duration.zero;
  }

  void pause(DateTime now) => _pausedAt ??= now;
  void resume(DateTime now) {
    if (_pausedAt != null) _paused += now.difference(_pausedAt!);
    _pausedAt = null;
    _finishedAt = null;
  }

  void finish(DateTime now) => _finishedAt = now;
  Duration activeElapsed(DateTime now) {
    if (startedAt == null) return Duration.zero;
    final end = _pausedAt ?? _finishedAt ?? now;
    final value = end.difference(startedAt!) - _paused;
    return value.isNegative ? Duration.zero : value;
  }
}

/// Only measured, short GPS intervals count; gaps never invent moving time.
double movingIntervalSeconds(double speed, double seconds, double accuracy) =>
    speed >= 0.5 &&
        speed <= 25 &&
        seconds > 0 &&
        seconds <= 30 &&
        accuracy <= 50
    ? seconds
    : 0;
