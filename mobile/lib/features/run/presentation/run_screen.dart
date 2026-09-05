import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:runova/core/theme/runova_theme.dart';
import 'package:runova/features/run/domain/run_session.dart';
import 'package:runova/features/run/presentation/run_controller.dart';

class RunScreen extends ConsumerWidget {
  const RunScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(runSessionProvider);
    final controller = ref.read(runSessionProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  session.phase == RunPhase.idle ? 'Ready to run?' : _phaseLabel(session.phase),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const Spacer(),
                _GpsBadge(status: session.gpsStatus),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: RunovaColors.surface,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (session.distanceMeters / 1000).toStringAsFixed(2),
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: 72,
                            ),
                      ),
                      const Text('KILOMETRES', style: TextStyle(color: RunovaColors.textMuted)),
                      const SizedBox(height: 38),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _RunMetric(label: 'TIME', value: _duration(session.elapsed)),
                          _RunMetric(
                            label: 'AVG PACE',
                            value: session.averagePaceMinutesPerKm == 0
                                ? '--:--'
                                : _pace(session.averagePaceMinutesPerKm),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '${session.activityType} · ${session.pointCount} GPS points',
                        style: const TextStyle(color: RunovaColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (session.phase == RunPhase.idle || session.phase == RunPhase.completed)
              FilledButton.icon(
                key: const Key('start-run-button'),
                onPressed: session.phase == RunPhase.completed ? controller.reset : controller.start,
                icon: Icon(
                  session.phase == RunPhase.completed
                      ? Icons.refresh_rounded
                      : Icons.play_arrow_rounded,
                ),
                label: Text(session.phase == RunPhase.completed ? 'NEW RUN' : 'START RUN'),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: session.phase == RunPhase.paused
                          ? controller.resume
                          : controller.pause,
                      icon: Icon(
                        session.phase == RunPhase.paused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                      ),
                      label: Text(session.phase == RunPhase.paused ? 'RESUME' : 'PAUSE'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: controller.finish,
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('FINISH'),
                    ),
                  ),
                ],
              ),
            if (session.error != null) ...[
              const SizedBox(height: 12),
              Text(
                session.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: RunovaColors.danger),
              ),
            ],
            if (session.result != null) ...[
              const SizedBox(height: 12),
              Text(
                '${session.result!.status} · Trust ${session.result!.trustScore}% · '
                '+${session.result!.xp} XP · Level ${session.result!.level} · '
                '${session.result!.territoryCount} territories',
                textAlign: TextAlign.center,
                style: const TextStyle(color: RunovaColors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _phaseLabel(RunPhase phase) => switch (phase) {
      RunPhase.running => 'Run in progress',
      RunPhase.paused => 'Run paused',
      RunPhase.completed => 'Run complete',
      RunPhase.idle => 'Ready to run?',
    };

String _duration(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

String _pace(double minutesPerKm) {
  final minutes = minutesPerKm.floor();
  final seconds = ((minutesPerKm - minutes) * 60).round();
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

class _RunMetric extends StatelessWidget {
  const _RunMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: RunovaColors.textMuted, fontSize: 11)),
      ],
    );
  }
}

class _GpsBadge extends StatelessWidget {
  const _GpsBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.gps_fixed_rounded, color: RunovaColors.primary, size: 18),
      label: Text(status),
    );
  }
}
