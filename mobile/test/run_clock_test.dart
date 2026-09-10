import 'package:flutter_test/flutter_test.dart';
import 'package:runova/features/run/domain/run_clock.dart';

void main() {
  test('elapsed survives skipped timer ticks, pauses and finishing', () {
    final clock = RunClock();
    final start = DateTime.utc(2026, 9, 10);
    clock.start(start);
    expect(
      clock.activeElapsed(start.add(const Duration(minutes: 12))).inSeconds,
      720,
    );
    clock.pause(start.add(const Duration(minutes: 12)));
    expect(
      clock.activeElapsed(start.add(const Duration(minutes: 20))).inSeconds,
      720,
    );
    clock.resume(start.add(const Duration(minutes: 20)));
    clock.finish(start.add(const Duration(minutes: 25)));
    expect(
      clock.activeElapsed(start.add(const Duration(hours: 1))).inSeconds,
      1020,
    );
  });
  test(
    'moving time excludes stationary, poor fixes, vehicles and GPS gaps',
    () {
      expect(movingIntervalSeconds(3, 2, 5), 2);
      expect(movingIntervalSeconds(0.5, 2, 5), 2);
      expect(movingIntervalSeconds(0.4, 2, 5), 0);
      expect(movingIntervalSeconds(3, 90, 5), 0);
      expect(movingIntervalSeconds(3, 2, 80), 0);
      expect(movingIntervalSeconds(30, 2, 5), 0);
    },
  );
  test('resuming after a failed local finish does not count time spent stopped', () {
    final clock = RunClock();
    final start = DateTime.utc(2026, 9, 10);
    clock.start(start);
    clock.pause(start.add(const Duration(minutes: 5)));
    clock.finish(start.add(const Duration(minutes: 5)));
    clock.resume(start.add(const Duration(minutes: 8)));
    expect(clock.activeElapsed(start.add(const Duration(minutes: 10))).inMinutes, 7);
  });
}
