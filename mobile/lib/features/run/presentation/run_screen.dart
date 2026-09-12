import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:runova/features/history/data/run_history_repository.dart';
import 'package:runova/features/leaderboard/presentation/leaderboard_screen.dart';
import 'package:runova/features/profile/presentation/profile_screen.dart';
import 'package:runova/features/run/data/run_sync.dart';
import 'package:runova/core/theme/runova_theme.dart';
import 'package:runova/features/run/domain/run_session.dart';
import 'package:runova/features/run/presentation/run_controller.dart';

class RunScreen extends ConsumerWidget {
  const RunScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(runSessionProvider);
    final controller = ref.read(runSessionProvider.notifier);
    ref.listen(runSessionProvider, (previous, next) {
      if (previous?.phase != RunPhase.completed &&
          next.phase == RunPhase.completed) {
        ref.invalidate(runHistoryProvider);
        ref.invalidate(progressionProvider);
        ref.invalidate(leaderboardProvider);
        ref.read(runSyncProvider.notifier).sync();
        if (next.result != null && next.runId != null) {
          context.push('/history/${next.runId}?summary=true');
        }
      }
    });

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(
                          session.phase == RunPhase.idle
                              ? 'Ready to run?'
                              : _phaseLabel(session.phase),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        _GpsBadge(status: session.gpsStatus),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 32,
                            horizontal: 12,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                (session.distanceMeters / 1000).toStringAsFixed(
                                  2,
                                ),
                                style: Theme.of(context).textTheme.displayLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 72,
                                    ),
                              ),
                              Text(
                                'KILOMETRES',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 38),
                              Wrap(
                                alignment: WrapAlignment.spaceEvenly,
                                spacing: 24,
                                runSpacing: 16,
                                children: [
                                  _RunMetric(
                                    label: 'TIME',
                                    value: _duration(session.elapsed),
                                  ),
                                  _RunMetric(
                                    label: 'AVG PACE',
                                    value: session.averagePaceMinutesPerKm == 0
                                        ? '--:--'
                                        : _pace(
                                            session.averagePaceMinutesPerKm,
                                          ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Text(
                                '${session.activityType} · ${session.pointCount} GPS points',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (session.phase == RunPhase.idle ||
                        session.phase == RunPhase.completed)
                      FilledButton.icon(
                        key: const Key('start-run-button'),
                        onPressed: session.busy
                            ? null
                            : session.phase == RunPhase.completed
                            ? controller.reset
                            : controller.start,
                        icon: Icon(
                          session.phase == RunPhase.completed
                              ? Icons.refresh_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(
                          session.phase == RunPhase.completed
                              ? 'NEW RUN'
                              : 'START RUN',
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: session.busy
                                  ? null
                                  : session.phase == RunPhase.paused
                                  ? controller.resume
                                  : controller.pause,
                              icon: Icon(
                                session.phase == RunPhase.paused
                                    ? Icons.play_arrow_rounded
                                    : Icons.pause_rounded,
                              ),
                              label: Text(
                                session.phase == RunPhase.paused
                                    ? 'RESUME'
                                    : 'PAUSE',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: session.busy
                                  ? null
                                  : controller.finish,
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
                      TextButton(
                        onPressed: () => context.push(
                          '/history/${session.runId}?summary=true',
                        ),
                        child: const Text('View run summary'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
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
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
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
      avatar: Icon(
        Icons.gps_fixed_rounded,
        color: Theme.of(context).colorScheme.primary,
        size: 18,
      ),
      label: Text(status),
    );
  }
}
