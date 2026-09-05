import 'package:go_router/go_router.dart';
import 'package:runova/app/shell.dart';
import 'package:runova/features/auth/presentation/login_screen.dart';
import 'package:runova/features/dashboard/presentation/dashboard_screen.dart';
import 'package:runova/features/history/presentation/history_screen.dart';
import 'package:runova/features/leaderboard/presentation/leaderboard_screen.dart';
import 'package:runova/features/profile/presentation/profile_screen.dart';
import 'package:runova/features/run/presentation/run_screen.dart';
import 'package:runova/features/territories/presentation/territory_map_screen.dart';

final runovaRouter = GoRouter(
  initialLocation: '/login',
  routes: [
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
            GoRoute(path: '/run', builder: (context, state) => const RunScreen()),
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
