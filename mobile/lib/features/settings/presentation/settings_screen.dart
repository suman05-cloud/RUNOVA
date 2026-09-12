import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:runova/core/theme/appearance_controller.dart';
import 'package:runova/features/auth/presentation/auth_controller.dart';
import 'package:runova/features/settings/data/preferences.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const SettingsHeading('Account'),
          Card(
            child: Column(
              children: [
                SettingsTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Profile',
                  subtitle:
                      user?.displayName ??
                      user?.username ??
                      'Manage your profile information',
                  onTap: () => context.go('/profile'),
                ),
                SettingsTile(
                  icon: Icons.credit_card_rounded,
                  title: 'Subscription',
                  subtitle: 'Your current plan',
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Your Runova plan'),
                      content: const Text(
                        'No paid subscriptions are available in this version of Runova.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SettingsHeading('Preferences'),
          Card(
            child: Column(
              children: [
                SettingsTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: 'Choose which updates appear in Events',
                  onTap: () => context.push('/settings/notifications'),
                ),
                SettingsTile(
                  icon: Icons.settings_outlined,
                  title: 'App Settings',
                  subtitle: 'Appearance, language and permissions',
                  onTap: () => context.push('/settings/app'),
                ),
              ],
            ),
          ),
          const SettingsHeading('Support'),
          Card(
            child: Column(
              children: [
                SettingsTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Help Center',
                  subtitle: 'Get help with running and syncing',
                  onTap: () => context.push('/settings/help'),
                ),
                SettingsTile(
                  icon: Icons.mail_outline_rounded,
                  title: 'Contact Us',
                  subtitle: 'Prepare a support request',
                  onTap: () => context.push('/settings/contact'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text('RUNOVA · Version 0.1.0', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class SettingsHeading extends StatelessWidget {
  const SettingsHeading(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 12),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    leading: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Theme.of(context).colorScheme.primary),
    ),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({this.notificationsOnly = false, super.key});
  final bool notificationsOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesProvider);
    final theme = ref.watch(themeModeProvider);
    Future<void> save(AppPreferences Function(AppPreferences) change) async {
      try {
        await ref.read(preferencesProvider.notifier).save(change);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not save settings. Please try again.'),
            ),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(notificationsOnly ? 'Notifications' : 'App Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const SettingsHeading('Notifications'),
          preferences.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Card(
              child: ListTile(
                title: const Text('Could not load your settings'),
                trailing: TextButton(
                  onPressed: () => ref.invalidate(preferencesProvider),
                  child: const Text('Retry'),
                ),
              ),
            ),
            data: (prefs) => Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('App Notifications'),
                    subtitle: const Text(
                      'Show activity updates in your Events inbox',
                    ),
                    value: prefs.notifications,
                    onChanged: (value) =>
                        save((p) => p.copyWith(notifications: value)),
                  ),
                  if (notificationsOnly) ...[
                    SwitchListTile(
                      title: const Text('Run updates'),
                      subtitle: const Text(
                        'Completed runs, XP and territory changes',
                      ),
                      value: prefs.runUpdates,
                      onChanged: prefs.notifications
                          ? (value) =>
                                save((p) => p.copyWith(runUpdates: value))
                          : null,
                    ),
                    SwitchListTile(
                      title: const Text('Sync updates'),
                      subtitle: const Text(
                        'Runs waiting to upload or needing attention',
                      ),
                      value: prefs.syncUpdates,
                      onChanged: prefs.notifications
                          ? (value) =>
                                save((p) => p.copyWith(syncUpdates: value))
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (notificationsOnly) ...[
            const SizedBox(height: 12),
            const Text(
              'These preferences control the in-app inbox on this device. Phone push notifications are not available in this version.',
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push('/events'),
              icon: const Icon(Icons.inbox_outlined),
              label: const Text('Open Events'),
            ),
          ] else ...[
            const SettingsHeading('Appearance'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Theme',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text('Choose light, dark or follow your device.'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ThemeMode.values
                          .map(
                            (mode) => ChoiceChip(
                              label: Text(switch (mode) {
                                ThemeMode.system => 'System',
                                ThemeMode.light => 'Light',
                                ThemeMode.dark => 'Dark',
                              }),
                              selected: theme == mode,
                              onSelected: (_) => ref
                                  .read(themeModeProvider.notifier)
                                  .select(mode),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SettingsHeading('Language'),
            const Card(
              child: ListTile(
                title: Text('English'),
                subtitle: Text(
                  'More languages will be available in a future version.',
                ),
                trailing: Icon(Icons.check_rounded),
              ),
            ),
            const SettingsHeading('Permissions'),
            Card(
              child: SettingsTile(
                icon: Icons.location_on_outlined,
                title: 'Location access',
                subtitle: 'Manage Runova permissions on your device',
                onTap: () async {
                  try {
                    final opened = await Geolocator.openAppSettings();
                    if (!opened) throw StateError('Settings unavailable');
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Open your device Settings and choose Runova to manage permissions.',
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: 32),
            const Text('Version 0.1.0', textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Help Center')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        _HelpItem(
          'How do I record a run?',
          'Open Run, allow location access and start your session outdoors. Finish the run when you are done to save it and calculate your results.',
        ),
        _HelpItem(
          'Why is my run waiting to sync?',
          'Runova keeps unsynced runs on your device and retries when a connection is available. Open Events and choose Retry sync if a run needs attention.',
        ),
        _HelpItem(
          'Where are my notifications?',
          'Tap the bell on Home or open Events from your profile. Tap a run update to open its details, or choose Mark all as read to clear the unread count.',
        ),
        _HelpItem(
          'How do I change my profile or theme?',
          'Open Settings from your profile. Profile lets you edit your name, location and public visibility. App Settings offers Light, Dark and System themes.',
        ),
        _HelpItem(
          'Who can see my GPS route?',
          'Raw GPS routes are private. Your own route is only loaded when you choose to view it in your run details.',
        ),
      ],
    ),
  );
}

class _HelpItem extends StatelessWidget {
  const _HelpItem(this.question, this.answer);
  final String question;
  final String answer;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: ExpansionTile(
        title: Text(question),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        children: [Text(answer)],
      ),
    ),
  );
}

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});
  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _message = TextEditingController();
  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Contact Us')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'How can we help?',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        const Text(
          'A support contact is not configured in this version. You can prepare and copy a report to share with the person who provided the app.',
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _message,
          minLines: 5,
          maxLines: 10,
          maxLength: 4000,
          decoration: const InputDecoration(
            labelText: 'Describe the issue',
            hintText: 'What happened, and what did you expect?',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _message.text.trim().isEmpty
              ? null
              : () async {
                  try {
                    await Clipboard.setData(
                      ClipboardData(
                        text:
                            'Runova 0.1.0 support request\n\n${_message.text.trim()}',
                      ),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Support report copied.')),
                      );
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not copy the report. Please try again.',
                          ),
                        ),
                      );
                    }
                  }
                },
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Copy support report'),
        ),
      ],
    ),
  );
}
