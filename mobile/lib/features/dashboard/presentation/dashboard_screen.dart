import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:runova/core/theme/runova_theme.dart';
import 'package:runova/core/widgets/metric_card.dart';
import 'package:runova/features/history/data/run_history_repository.dart';
import 'package:runova/features/profile/presentation/profile_screen.dart';
import 'package:runova/features/run/data/run_sync.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressionProvider);
    final history = ref.watch(runHistoryProvider);
    final sync = ref.watch(runSyncProvider);
    final data = progress.value;
    final level = (data?['level'] as num?)?.toInt() ?? 1;
    final xp = (data?['fitness_xp'] as num?)?.toInt() ?? 0;
    final base = (level - 1) * (level - 1) * 500;
    final next = level * level * 500;
    final runs = history.value?.where((r) => r['finished_at'] != null).toList();
    final total = runs?.fold<double>(
      0,
      (sum, run) => sum + (run['distance_meters'] as num),
    );
    final last = runs == null || runs.isEmpty ? null : runs.first;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(progressionProvider);
          ref.invalidate(runHistoryProvider);
          await ref.read(runHistoryProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
          children: [
            Text(
              'RUNOVA',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: RunovaColors.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const Text('Run. Claim. Conquer.'),
            const SizedBox(height: 24),
            if (progress.isLoading || history.isLoading)
              const LinearProgressIndicator(),
            if (progress.hasError || history.hasError)
              const Text('Some stats could not load. Pull down to retry.'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data == null
                          ? 'Progress unavailable'
                          : 'LEVEL $level · $xp XP',
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: ((xp - base) / (next - base)).clamp(0, 1),
                    ),
                    Text('${next - xp} XP to the next level'),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () => context.go('/run'),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('START A RUN'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 130,
              child: Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      label: 'Total distance',
                      value: total == null
                          ? '—'
                          : '${(total / 1000).toStringAsFixed(2)} km',
                      icon: Icons.route,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricCard(
                      label: 'Current streak',
                      value: data == null
                          ? '—'
                          : '${data['current_streak_days']} days',
                      icon: Icons.local_fire_department,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 130,
              child: Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      label: 'Territories',
                      value: data == null
                          ? '—'
                          : '${data['territories_owned']}',
                      icon: Icons.hexagon,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricCard(
                      label: 'Last run',
                      value: last == null
                          ? '—'
                          : '${((last['distance_meters'] as num) / 1000).toStringAsFixed(2)} km',
                      icon: Icons.directions_run,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (sync.pending > 0) Text('${sync.pending} runs waiting to sync'),
            Card(
              child: ListTile(
                title: const Text('Run history'),
                subtitle: Text(
                  runs == null
                      ? 'View your runs'
                      : '${runs.length} completed runs',
                ),
                leading: const Icon(Icons.history),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/history'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
