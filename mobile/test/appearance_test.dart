import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runova/app/runova_app.dart';
import 'package:runova/app/router.dart';
import 'package:runova/core/network/api_client.dart';
import 'package:runova/core/theme/appearance_controller.dart';
import 'package:runova/features/auth/presentation/auth_controller.dart';
import 'package:runova/features/run/data/run_sync.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_UI')) {
      final font = FontLoader('Roboto')
        ..addFont(
          File(
            '../.tooling/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await font.load();
      final fallback = FontLoader('Ahem')
        ..addFont(
          File(
            '../.tooling/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await fallback.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });
  testWidgets('appearance switches, persists, and restores', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [runSyncProvider.overrideWith(IdleSync.new)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const RunovaApp()),
    );
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), ThemeMode.light);
    await tester.tap(find.byTooltip('Switch to dark mode'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
    expect(
      await const FlutterSecureStorage().read(
        key: AppearanceController.storageKey,
      ),
      'dark',
    );
    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    restored.read(themeModeProvider);
    await tester.pumpAndSettle();
    expect(restored.read(themeModeProvider), ThemeMode.dark);
    await container.read(themeModeProvider.notifier).select(ThemeMode.system);
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('${mode.name} screens fit compact phones and enlarged text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      FlutterSecureStorage.setMockInitialValues({
        'runova_access_token': 'saved-token',
        AppearanceController.storageKey: mode.name,
      });
      final container = ProviderContainer(
        overrides: [runSyncProvider.overrideWith(IdleSync.new)],
      );
      addTearDown(container.dispose);
      container.read(apiClientProvider).httpClientAdapter = TestAdapter((
        request,
      ) {
        if (request.path == '/v1/me') {
          return (200, testProfile);
        }
        if (request.path == '/v1/me/progression') {
          return (
            200,
            {
              'fitness_xp': 750,
              'level': 2,
              'current_streak_days': 3,
              'territories_owned': 6,
              'territory_points': 120,
            },
          );
        }
        if (request.path == '/v1/leaderboards') {
          return (200, {'entries': <Object>[]});
        }
        return (200, <Object>[]);
      });
      await tester.runAsync(
        () => container.read(authControllerProvider.future),
      );
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: RepaintBoundary(key: boundaryKey, child: const RunovaApp()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_UI')) {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('../.tooling/runova-${mode.name}-redesign.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      final router = container.read(runovaRouterProvider);
      for (final route in [
        '/run',
        '/profile',
        '/leaderboard',
        '/history',
        '/events',
        '/settings',
        '/settings/app',
        '/settings/notifications',
        '/settings/help',
        '/settings/contact',
        '/login',
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
      }
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final route in [
        '/',
        '/run',
        '/profile',
        '/leaderboard',
        '/events',
        '/settings',
        '/settings/app',
        '/settings/notifications',
        '/settings/help',
        '/settings/contact',
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$route at large text');
      }
      await container.read(authStoreProvider).clearToken();
      await tester.pumpAndSettle();
      expect(find.text('Create your runner profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
