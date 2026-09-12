import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:runova/features/history/data/run_history_repository.dart';
import 'package:runova/features/run/data/run_sync.dart';
import 'package:runova/features/settings/data/preferences.dart';

class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.runId,
  });
  final String id;
  final String title;
  final String body;
  final DateTime time;
  final String runId;
}

List<ActivityEvent> eventsFromRuns(List<Map<String, dynamic>> runs) {
  final events = <ActivityEvent>[];
  for (final run in runs) {
    final time = DateTime.tryParse(run['finished_at']?.toString() ?? '');
    final id = run['id']?.toString();
    if (time == null || id == null) continue;
    final distance = ((run['distance_meters'] as num? ?? 0) / 1000)
        .toStringAsFixed(2);
    final xp = run['xp_earned'] as num? ?? 0;
    final territories = run['territories_changed'] as num? ?? 0;
    events.add(
      ActivityEvent(
        id: 'run:$id',
        runId: id,
        time: time,
        title: 'Run completed',
        body:
            '$distance km · $xp XP earned${territories > 0 ? ' · $territories territories updated' : ''}',
      ),
    );
  }
  events.sort((a, b) => b.time.compareTo(a.time));
  return events;
}

final activityEventsProvider = Provider<AsyncValue<List<ActivityEvent>>>((ref) {
  return ref.watch(runHistoryProvider).whenData(eventsFromRuns);
});

final unreadEventsProvider = Provider<int>((ref) {
  final prefs = ref.watch(preferencesProvider).value;
  if (prefs == null || !prefs.notifications || !prefs.runUpdates) return 0;
  return ref
          .watch(activityEventsProvider)
          .value
          ?.where((event) => !prefs.readIds.contains(event.id))
          .length ??
      0;
});

class EventsButton extends ConsumerWidget {
  const EventsButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadEventsProvider);
    return IconButton.filledTonal(
      tooltip: 'Events and notifications',
      onPressed: () => context.push('/events'),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_outlined, size: 21),
      ),
    );
  }
}

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});
  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  bool _unreadOnly = false;

  Future<void> _markRead(Iterable<String> ids) async {
    try {
      await ref.read(preferencesProvider.notifier).markRead(ids);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save read status. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(preferencesProvider);
    final activity = ref.watch(activityEventsProvider);
    final sync = ref.watch(runSyncProvider);
    final prefs = preferences.value;
    final events = activity.value ?? [];
    final enabled = prefs?.notifications == true && prefs?.runUpdates == true;
    final visible = enabled
        ? events
              .where((e) => !_unreadOnly || !prefs!.readIds.contains(e.id))
              .toList()
        : <ActivityEvent>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          IconButton(
            tooltip: 'Notification settings',
            onPressed: () => context.push('/settings/notifications'),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(runHistoryProvider);
          try {
            await ref.read(runHistoryProvider.future);
          } catch (_) {
            /* Render the retry state below. */
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'Your running story, as it happens.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Run updates and notifications in one place.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: !_unreadOnly,
                  onSelected: (_) => setState(() => _unreadOnly = false),
                ),
                ChoiceChip(
                  label: const Text('Unread'),
                  selected: _unreadOnly,
                  onSelected: (_) => setState(() => _unreadOnly = true),
                ),
                TextButton(
                  onPressed:
                      enabled &&
                          events.any((e) => !prefs!.readIds.contains(e.id))
                      ? () => _markRead(events.map((e) => e.id))
                      : null,
                  child: const Text('Mark all as read'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (preferences.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (preferences.hasError)
              _Notice(
                icon: Icons.error_outline,
                title: 'Preferences unavailable',
                body: 'Please retry to load your notification preferences.',
                action: TextButton(
                  onPressed: () => ref.invalidate(preferencesProvider),
                  child: const Text('Retry'),
                ),
              )
            else if (!prefs!.notifications)
              _Notice(
                icon: Icons.notifications_off_outlined,
                title: 'Notifications are paused',
                body: 'Turn on app notifications to see your activity here. Your runs are still available in History.',
                action: TextButton(
                  onPressed: () => context.push('/settings/notifications'),
                  child: const Text('Manage notifications'),
                ),
              )
            else ...[
              if (prefs.syncUpdates &&
                  (sync.pending > 0 || sync.error != null)) ...[
                _Notice(
                  icon: Icons.cloud_upload_outlined,
                  title: sync.busy
                      ? 'Syncing your runs'
                      : 'Runs need attention',
                  body: sync.error ?? '${sync.pending} runs waiting to sync.',
                  action: TextButton(
                    onPressed: sync.busy
                        ? null
                        : () => ref.read(runSyncProvider.notifier).sync(),
                    child: const Text('Retry sync'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (!prefs.runUpdates)
                const _Notice(
                  icon: Icons.directions_run,
                  title: 'Run updates are paused',
                  body: 'Enable run updates in notification settings to see completed runs.',
                )
              else if (activity.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (activity.hasError)
                _Notice(
                  icon: Icons.wifi_off_rounded,
                  title: 'Could not load events',
                  body: 'Check your connection and try again.',
                  action: TextButton(
                    onPressed: () => ref.invalidate(runHistoryProvider),
                    child: const Text('Retry'),
                  ),
                )
              else if (visible.isEmpty)
                _Notice(
                  icon: Icons.notifications_none_rounded,
                  title: _unreadOnly
                      ? 'You’re all caught up'
                      : 'Your next run starts the story',
                  body: _unreadOnly ? 'No unread run notifications.' : 'Complete and sync a run to see your first update here.',
                )
              else
                for (final event in visible) ...[
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        child: Icon(
                          prefs.readIds.contains(event.id)
                              ? Icons.task_alt_rounded
                              : Icons.directions_run_rounded,
                        ),
                      ),
                      title: Text(
                        event.title,
                        style: TextStyle(
                          fontWeight: prefs.readIds.contains(event.id)
                              ? FontWeight.w400
                              : FontWeight.w700,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${event.body}\n${MaterialLocalizations.of(context).formatMediumDate(event.time.toLocal())} · ${TimeOfDay.fromDateTime(event.time.toLocal()).format(context)}',
                        ),
                      ),
                      isThreeLine: true,
                      trailing: prefs.readIds.contains(event.id)
                          ? null
                          : const Tooltip(
                              message: 'Unread',
                              child: Icon(Icons.circle, size: 9),
                            ),
                      onTap: () {
                        _markRead([event.id]);
                        context.push(
                          '/history/${Uri.encodeComponent(event.runId)}',
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center),
          ?action,
        ],
      ),
    ),
  );
}
