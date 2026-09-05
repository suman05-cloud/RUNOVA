import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:runova/core/network/api_client.dart';
import 'package:runova/core/theme/runova_theme.dart';
import 'package:runova/features/auth/presentation/auth_controller.dart';

final progressionProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final response = await ref.watch(apiClientProvider).get<Map<String, dynamic>>(
        '/v1/me/progression',
      );
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
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 112),
        children: [
          const CircleAvatar(
            radius: 44,
            backgroundColor: RunovaColors.elevatedSurface,
            child: Icon(Icons.person_rounded, size: 46, color: RunovaColors.primary),
          ),
          const SizedBox(height: 14),
          Text(
            profile?.displayName ?? profile?.username ?? 'Runner',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          Text(
            profile == null ? 'Runova profile' : '@${profile.username} · ${profile.email}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: RunovaColors.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            'Level $level · $xp Fitness XP',
            textAlign: TextAlign.center,
            style: const TextStyle(color: RunovaColors.primary, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 28),
          const _ProfileItem(icon: Icons.lock_outline_rounded, label: 'Privacy'),
          const SizedBox(height: 10),
          const _ProfileItem(icon: Icons.location_on_outlined, label: 'Location permissions'),
          const SizedBox(height: 10),
          const _ProfileItem(icon: Icons.security_rounded, label: 'Email OTP coming later'),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () async {
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
  const _ProfileItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: RunovaColors.primary),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
