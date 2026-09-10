import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:runova/features/history/data/run_history_repository.dart';
import 'package:runova/features/history/presentation/run_detail_screen.dart';
import 'package:runova/features/run/data/run_sync.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(runHistoryProvider);
    final sync = ref.watch(runSyncProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Run history'),
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(runSyncProvider.notifier).sync();
          ref.invalidate(runHistoryProvider);
          await ref.read(runHistoryProvider.future);
        },
        child: history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ListView(
            children: [
              const ListTile(
                title: Text('Could not load run history. Pull to retry.'),
              ),
              if (sync.pending > 0)
                ListTile(title: Text('${sync.pending} runs waiting to sync')),
            ],
          ),
          data: (runs) {
            final completed = runs
                .where((run) => run['finished_at'] != null)
                .toList();
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              children: [
                if (sync.pending > 0 || sync.error != null)
                  ListTile(
                    title: Text('${sync.pending} runs waiting to sync'),
                    subtitle: Text(sync.error ?? 'Will retry when connected.'),
                    trailing: IconButton(
                      onPressed: sync.busy
                          ? null
                          : () => ref.read(runSyncProvider.notifier).sync(),
                      icon: const Icon(Icons.sync),
                    ),
                  ),
                if (completed.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No completed runs yet. Your distance, pace and XP will appear here.',
                    ),
                  ),
                ...completed.map((run) {
                  final date = DateTime.parse(run['started_at'] as String)
                      .toLocal();
                  return Card(
                    child: ListTile(
                      onTap: () => context.push('/history/${run['id']}'),
                      title: Text(
                        '${((run['distance_meters'] as num) / 1000).toStringAsFixed(2)} km · '
                        '${date.day}/${date.month}/${date.year}',
                      ),
                      subtitle: Text(
                        '${durationLabel(run['elapsed_seconds'] as int)} · '
                        '${run['activity_type']}\n${run['validation_status']}',
                      ),
                      isThreeLine: true,
                      trailing: Text('+${run['xp_earned']} XP'),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}
