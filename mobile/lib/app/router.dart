import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:runova/app/shell.dart';
import 'package:runova/features/events/presentation/events_screen.dart';
import 'package:runova/features/settings/presentation/settings_screen.dart';
import 'package:runova/features/auth/presentation/login_screen.dart';
import 'package:runova/features/auth/presentation/auth_controller.dart';
import 'package:runova/features/history/presentation/run_detail_screen.dart';
import 'package:runova/features/dashboard/presentation/dashboard_screen.dart';
import 'package:runova/features/history/presentation/history_screen.dart';
import 'package:runova/features/leaderboard/presentation/leaderboard_screen.dart';
import 'package:runova/features/profile/presentation/profile_screen.dart';
import 'package:runova/features/run/presentation/run_screen.dart';
import 'package:runova/features/territories/presentation/territory_map_screen.dart';

final runovaRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, next) => refresh.value++);
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      if (auth.isLoading &&
          auth.value == null &&
          state.matchedLocation != '/login') {
        return '/loading';
      }
      if (auth.hasError &&
          auth.value == null &&
          state.matchedLocation != '/login') {
        return '/loading';
      }
      if (auth.value == null) {
        return state.matchedLocation == '/login' ? null : '/login';
      }
      if (state.matchedLocation == '/login' ||
          state.matchedLocation == '/loading') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/events',
        builder: (context, state) => const EventsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'app',
            builder: (context, state) => const AppSettingsScreen(),
          ),
          GoRoute(
            path: 'notifications',
            builder: (context, state) =>
                const AppSettingsScreen(notificationsOnly: true),
          ),
          GoRoute(
            path: 'help',
            builder: (context, state) => const HelpScreen(),
          ),
          GoRoute(
            path: 'contact',
            builder: (context, state) => const ContactScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/loading',
        builder: (context, state) => const SessionLoadingScreen(),
      ),
      GoRoute(
        path: '/history/:id',
        builder: (context, state) => RunDetailScreen(
          runId: state.pathParameters['id']!,
          summary: state.uri.queryParameters['summary'] == 'true',
        ),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DashboardScreen(),
                routes: [
                  GoRoute(
                    path: 'history',
                    builder: (context, state) => const HistoryScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/run',
                builder: (context, state) => const RunScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/territories',
                builder: (context, state) => const TerritoryMapScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/leaderboard',
                builder: (context, state) => const LeaderboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class SessionLoadingScreen extends ConsumerWidget {
  const SessionLoadingScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      body: Center(
        child: auth.hasError
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not restore your session.'),
                  TextButton(
                    onPressed: () => ref.invalidate(authControllerProvider),
                    child: const Text('Retry'),
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
