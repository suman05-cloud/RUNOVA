import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:runova/app/runova_app.dart';
import 'package:runova/features/run/data/run_sync.dart';
import 'package:runova/app/router.dart';
import 'package:runova/core/network/api_client.dart';
import 'package:runova/features/auth/presentation/auth_controller.dart';

import 'test_support.dart';

void main() {
  testWidgets('shows the Runova development login', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [runSyncProvider.overrideWith(IdleSync.new)],
        child: const RunovaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RUNOVA'), findsOneWidget);
    expect(find.text('Create your runner profile'), findsOneWidget);
    expect(find.byKey(const Key('direct-login-button')), findsOneWidget);
  });

  testWidgets(
    'restored sessions skip login and expired sessions guard protected routes',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({
        'runova_access_token': 'saved-token',
      });
      final container = ProviderContainer(
        overrides: [runSyncProvider.overrideWith(IdleSync.new)],
      );
      addTearDown(container.dispose);
      container.read(apiClientProvider).httpClientAdapter = TestAdapter((
        request,
      ) {
        if (request.path == '/v1/me') return (200, testProfile);
        if (request.path == '/v1/me/progression') {
          return (
            200,
            {
              'fitness_xp': 500,
              'level': 2,
              'current_streak_days': 2,
              'territories_owned': 3,
            },
          );
        }
        if (request.path == '/v1/leaderboards') {
          return (200, {'entries': <Object>[]});
        }
        return (200, <Object>[]);
      });
      await tester.runAsync(() => container.read(authControllerProvider.future));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RunovaApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Start a run'), findsOneWidget);
      final router = container.read(runovaRouterProvider);
      router.go('/login');
      await tester.pumpAndSettle();
      expect(find.text('Start a run'), findsOneWidget);
      await container.read(authStoreProvider).clearToken();
      await tester.pumpAndSettle();
      expect(find.text('Create your runner profile'), findsOneWidget);
      router.go('/profile');
      await tester.pumpAndSettle();
      expect(find.text('Create your runner profile'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
