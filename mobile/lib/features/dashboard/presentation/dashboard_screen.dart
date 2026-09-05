import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runova/core/theme/runova_theme.dart';
import 'package:runova/core/widgets/metric_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RUNOVA',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: RunovaColors.primary,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                          ),
                          const Text(
                            'Run. Claim. Conquer.',
                            style: TextStyle(color: RunovaColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: RunovaColors.elevatedSurface,
                      child: Icon(Icons.person_rounded, color: RunovaColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _LevelCard(onRunPressed: () => context.go('/run')),
                const SizedBox(height: 24),
                Text(
                  'This week',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 14),
                const SizedBox(
                  height: 130,
                  child: Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          label: 'Distance',
                          value: '0.0 km',
                          icon: Icons.route_rounded,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: MetricCard(
                          label: 'Current streak',
                          value: '0 days',
                          icon: Icons.local_fire_department_rounded,
                          accent: RunovaColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const SizedBox(
                  height: 130,
                  child: Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          label: 'Territories',
                          value: '0',
                          icon: Icons.hexagon_rounded,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: MetricCard(
                          label: 'Local rank',
                          value: '—',
                          icon: Icons.emoji_events_rounded,
                          accent: RunovaColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    leading: const Icon(Icons.history_rounded, color: RunovaColors.primary),
                    title: const Text('Run history'),
                    subtitle: const Text('Completed runs will appear here'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.go('/history'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.onRunPressed});

  final VoidCallback onRunPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [RunovaColors.elevatedSurface, Color(0xFF103D25)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: RunovaColors.primary.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Text('LEVEL 1', style: TextStyle(fontWeight: FontWeight.w900)),
                Spacer(),
                Text('0 / 500 XP', style: TextStyle(color: RunovaColors.textMuted)),
              ],
            ),
            const SizedBox(height: 10),
            const LinearProgressIndicator(value: 0, minHeight: 7),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onRunPressed,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('START A RUN'),
            ),
          ],
        ),
      ),
    );
  }
}

