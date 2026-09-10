import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:runova/core/network/api_client.dart';
import 'package:runova/features/auth/presentation/auth_controller.dart';
import 'package:runova/core/theme/runova_theme.dart';
import 'package:runova/features/leaderboard/data/leaderboard_repository.dart';

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>(
  (ref) => LeaderboardRepository(ref.watch(apiClientProvider)),
);
final leaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) {
  if (ref.watch(authControllerProvider).value == null) return [];
  return ref.watch(leaderboardRepositoryProvider).globalFitnessXp();
});

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboard = ref.watch(leaderboardProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Leaderboards',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => ref.invalidate(leaderboardProvider),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const Text(
              'Global Fitness XP',
              style: TextStyle(color: RunovaColors.textMuted),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: leaderboard.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => const Center(
                  child: Text(
                    'Sign in and check that the Runova API is running.',
                  ),
                ),
                data: (entries) => entries.isEmpty
                    ? const _EmptyLeaderboard()
                    : ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return Card(
                            color: entry.isCurrentUser
                                ? RunovaColors.elevatedSurface
                                : null,
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text('${entry.rank}'),
                              ),
                              title: Text('@${entry.username}'),
                              trailing: Text(
                                '${entry.score.round()} XP',
                                style: const TextStyle(
                                  color: RunovaColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLeaderboard extends StatelessWidget {
  const _EmptyLeaderboard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 64,
            color: RunovaColors.warning,
          ),
          SizedBox(height: 18),
          Text(
            'No rankings yet',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text('Complete a run to earn XP.'),
        ],
      ),
    );
  }
}
