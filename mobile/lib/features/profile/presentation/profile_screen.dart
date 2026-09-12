import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:runova/core/network/api_client.dart';
import 'package:runova/core/theme/appearance_controller.dart';
import 'package:runova/features/auth/presentation/auth_controller.dart';
import 'package:runova/features/leaderboard/presentation/leaderboard_screen.dart';
import 'package:runova/features/run/presentation/run_controller.dart';

final progressionProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) return {};
  final response = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>>('/v1/me/progression');
  return response.data!;
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).value;
    final progression = ref.watch(progressionProvider);
    final level = progression.value?['level'] ?? 1;
    final xp = progression.value?['fitness_xp'] ?? 0;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Your profile',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
                ),
              ),
              AppearanceButton(),
            ],
          ),
          const SizedBox(height: 24),
          CircleAvatar(
            radius: 44,
            backgroundColor: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest,
            child: Icon(
              Icons.person_rounded,
              size: 46,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            profile?.displayName ?? profile?.username ?? 'Runner',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            profile == null
                ? 'Runova profile'
                : '@${profile.username} · ${profile.email}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Level $level · $xp Fitness XP',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            '${progression.value?['territory_points'] ?? 0} territory points',
            textAlign: TextAlign.center,
          ),
          const Text(
            'Your raw GPS routes are private and only loaded when you choose to view them.',
          ),
          const SizedBox(height: 10),
          _ProfileItem(
            icon: Icons.notifications_outlined,
            label: 'Events and notifications',
            onTap: () => context.push('/events'),
          ),
          const SizedBox(height: 10),
          _ProfileItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () => context.push('/settings'),
          ),
          const SizedBox(height: 10),
          _ProfileItem(
            icon: Icons.location_on_outlined,
            label: 'Location permissions',
            onTap: () => Geolocator.openAppSettings(),
          ),
          const SizedBox(height: 10),
          _ProfileItem(
            icon: Icons.edit_outlined,
            label: 'Edit profile',
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => const _EditProfileDialog(),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Appearance',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ThemeMode.values
                        .map(
                          (mode) => ChoiceChip(
                            label: Text(switch (mode) {
                              ThemeMode.light => 'Light',
                              ThemeMode.dark => 'Dark',
                              ThemeMode.system => 'Auto',
                            }),
                            selected: ref.watch(themeModeProvider) == mode,
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
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: ref.watch(runSessionProvider).isActive
                ? null
                : () async {
                    await ref.read(authControllerProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('LOG OUT'),
          ),
        ],
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  const _ProfileItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _EditProfileDialog extends ConsumerStatefulWidget {
  const _EditProfileDialog();
  @override
  ConsumerState<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog> {
  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _country;
  bool _public = false;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).value!;
    _name = TextEditingController(text: user.displayName);
    _city = TextEditingController(text: user.city);
    _state = TextEditingController(text: user.stateRegion);
    _country = TextEditingController(text: user.countryCode);
    _public = user.isPublic;
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _state.dispose();
    _country.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).updateProfile({
        'display_name': _name.text.trim().isEmpty ? null : _name.text.trim(),
        'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
        'state_region': _state.text.trim().isEmpty ? null : _state.text.trim(),
        'country_code': _country.text.trim().toUpperCase(),
        'profile_is_public': _public,
      });
      ref.invalidate(leaderboardProvider);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not save. Use a two-letter country code and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit profile'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
          TextField(
            controller: _city,
            decoration: const InputDecoration(labelText: 'City'),
          ),
          TextField(
            controller: _country,
            maxLength: 2,
            decoration: const InputDecoration(labelText: 'Country code'),
          ),
          TextField(
            controller: _state,
            decoration: const InputDecoration(labelText: 'State / region'),
          ),
          SwitchListTile(
            title: const Text('Public profile'),
            value: _public,
            onChanged: (value) => setState(() => _public = value),
          ),
          if (_error != null) Text(_error!),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: const Text('Save'),
      ),
    ],
  );
}
