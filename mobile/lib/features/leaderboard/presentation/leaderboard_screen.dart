import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:runova/core/network/api_client.dart';
import 'package:runova/features/auth/presentation/auth_controller.dart';
import 'package:runova/core/theme/runova_theme.dart';
import 'package:runova/features/leaderboard/data/leaderboard_repository.dart';

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>(
  (ref) => LeaderboardRepository(ref.watch(apiClientProvider)),
);
final leaderboardScopeProvider = NotifierProvider<LeaderboardScope, String>(
  LeaderboardScope.new,
);

class LeaderboardScope extends Notifier<String> {
  @override
  String build() => 'GLOBAL';
  void select(String value) => state = value;
}

final leaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) {
  if (ref.watch(authControllerProvider).value == null) return [];
  return ref
      .watch(leaderboardRepositoryProvider)
      .territoryPoints(ref.watch(leaderboardScopeProvider));
});

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboard = ref.watch(leaderboardProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Leaderboards',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),

                IconButton(
                  onPressed: () => ref.invalidate(leaderboardProvider),
                  icon: Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            Text(
              'Current territory points · region from your profile',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            DropdownButton<String>(
              value: ref.watch(leaderboardScopeProvider),
              items: const ['GLOBAL', 'COUNTRY', 'STATE', 'CITY']
                  .map(
                    (scope) =>
                        DropdownMenuItem(value: scope, child: Text(scope)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  ref.read(leaderboardScopeProvider.notifier).select(value);
                }
              },
            ),
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
                                ? Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                : null,
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text('${entry.rank}'),
                              ),
                              title: Text('@${entry.username}'),
                              trailing: Text(
                                '${entry.score.round()} pts',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
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
      child: SingleChildScrollView(
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
            Text(
              'Capture an area. Set your region in Edit profile.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
