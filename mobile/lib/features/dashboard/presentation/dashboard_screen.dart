import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:runova/core/theme/appearance_controller.dart';
import 'package:runova/core/widgets/metric_card.dart';
import 'package:runova/core/widgets/trail_artwork.dart';
import 'package:runova/features/auth/presentation/auth_controller.dart';
import 'package:runova/features/events/presentation/events_screen.dart';
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
    final user = ref.watch(authControllerProvider).value;
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
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(progressionProvider);
          ref.invalidate(runHistoryProvider);
          await ref.read(runHistoryProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RUNOVA',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 2.5,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Hello, ${user?.displayName ?? user?.username ?? 'Runner'}',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const EventsButton(),
                const SizedBox(width: 6),
                const AppearanceButton(),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'A little further.\nA little more you.',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -1.2,
                height: 1.12,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Make room for a run today.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 22),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 170,
                    child: Stack(
                      children: [
                        const Positioned.fill(child: TrailArtwork()),
                        Positioned(
                          left: 18,
                          top: 16,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              child: Text(
                                'YOUR NEXT ADVENTURE',
                                style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Find your own pace.',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Head outside. Run a loop. Make it yours.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => context.go('/run'),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  'Start a run',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(width: 12),
                              Icon(Icons.arrow_forward_rounded, size: 19),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 8,
              children: [
                const Text(
                  'Your rhythm',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Level $level',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (progress.isLoading || history.isLoading)
              const LinearProgressIndicator(),
            if (progress.hasError || history.hasError)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Some stats could not load. Pull down to retry.'),
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                final cards = [
                  MetricCard(
                    label: 'Total distance',
                    value: total == null
                        ? '—'
                        : '${(total / 1000).toStringAsFixed(2)} km',
                    icon: Icons.route_outlined,
                  ),
                  MetricCard(
                    label: 'Current streak',
                    value: data == null
                        ? '—'
                        : '${data['current_streak_days']} days',
                    icon: Icons.local_fire_department_outlined,
                  ),
                  MetricCard(
                    label: 'Territories',
                    value: data == null ? '—' : '${data['territories_owned']}',
                    icon: Icons.hexagon_outlined,
                  ),
                  MetricCard(
                    label: 'Last run',
                    value: last == null
                        ? '—'
                        : '${((last['distance_meters'] as num) / 1000).toStringAsFixed(2)} km',
                    icon: Icons.directions_run_outlined,
                  ),
                ];
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: cards
                      .map(
                        (card) => SizedBox(
                          width: (constraints.maxWidth - 12) / 2,
                          child: card,
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        const Text(
                          'One step stronger',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          data == null ? '—' : '$xp XP',
                          style: TextStyle(color: colors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: data == null
                          ? 0
                          : ((xp - base) / (next - base)).clamp(0, 1),
                      minHeight: 5,
                    ),
                    const SizedBox(height: 9),
                    Text(
                      data == null
                          ? 'Progress unavailable'
                          : '${(next - xp).clamp(0, next)} XP to your next level',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: ListTile(
                title: const Text('Explore territories'),
                subtitle: const Text('Run your own loop and claim area'),
                leading: const Icon(Icons.explore_outlined),
                trailing: const Icon(Icons.arrow_forward_rounded, size: 19),
                onTap: () => context.go('/territories'),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                title: const Text('Run history'),
                subtitle: Text(
                  runs == null
                      ? 'View your runs'
                      : '${runs.length} completed runs',
                ),
                leading: const Icon(Icons.history_rounded),
                trailing: const Icon(Icons.arrow_forward_rounded, size: 19),
                onTap: () => context.go('/history'),
              ),
            ),
            if (sync.pending > 0)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text('${sync.pending} runs waiting to sync'),
              ),
          ],
        ),
      ),
    );
  }
}
