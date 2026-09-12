import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runova/app/router.dart';
import 'package:runova/app/runova_app.dart';
import 'package:runova/core/network/api_client.dart';
import 'package:runova/features/auth/presentation/auth_controller.dart';
import 'package:runova/features/events/presentation/events_screen.dart';
import 'package:runova/features/run/data/run_sync.dart';
import 'package:runova/features/settings/data/preferences.dart';

import 'test_support.dart';

const runs = [
  {
    'id': 'older',
    'finished_at': '2026-09-10T09:00:00Z',
    'distance_meters': 2000,
    'xp_earned': 20,
    'territories_changed': 0,
  },
  {
    'id': 'newer',
    'finished_at': '2026-09-12T09:00:00Z',
    'distance_meters': 5100,
    'xp_earned': 51,
    'territories_changed': 3,
  },
  {'id': 'unfinished', 'finished_at': null},
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_UI')) {
      for (final name in ['Roboto', 'Ahem']) {
        await (FontLoader(name)..addFont(
              File(
                '../.tooling/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
              ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
            ))
            .load();
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });

  test(
    'events include only finished runs, newest first, with real rewards',
    () {
      final events = eventsFromRuns(runs);
      expect(events.map((event) => event.runId), ['newer', 'older']);
      expect(
        events.first.body,
        '5.10 km · 51 XP earned · 3 territories updated',
      );
    },
  );

  testWidgets(
    'inbox read state and notification preferences persist per account',
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
          return (200, {'fitness_xp': 71, 'level': 1});
        }
        if (request.path == '/v1/runs') return (200, runs);
        return (200, <Object>[]);
      });
      await tester.runAsync(
        () => container.read(authControllerProvider.future),
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: RepaintBoundary(key: boundaryKey, child: const RunovaApp()),
        ),
      );
      await tester.pumpAndSettle();
      final router = container.read(runovaRouterProvider);
      await tester.tap(find.byTooltip('Events and notifications'));
      await tester.pumpAndSettle();
      expect(find.text('Run completed'), findsNWidgets(2));
      expect(container.read(unreadEventsProvider), 2);

      Future<void> capture(String name) async {
        if (!const bool.fromEnvironment('CAPTURE_UI')) return;
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('../.tooling/runova-$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('events');
      await tester.tap(find.text('Mark all as read'));
      await tester.pumpAndSettle();
      expect(container.read(unreadEventsProvider), 0);
      await tester.tap(find.text('Unread'));
      await tester.pumpAndSettle();
      expect(find.text('You’re all caught up'), findsOneWidget);
      container.invalidate(preferencesProvider);
      await tester.pumpAndSettle();
      expect(container.read(preferencesProvider).value!.readIds, {
        'run:newer',
        'run:older',
      });

      router.go('/profile');
      await tester.pumpAndSettle();
      router.push('/settings');
      await tester.pumpAndSettle();
      await capture('settings');
      await tester.tap(find.text('App Settings'));
      await tester.pumpAndSettle();
      await capture('app-settings');
      await tester.tap(find.text('App Notifications'));
      await tester.pumpAndSettle();
      expect(container.read(preferencesProvider).value!.notifications, isFalse);
      final stored = await const FlutterSecureStorage().read(
        key: PreferencesController.storageKey('user-one'),
      );
      expect(jsonDecode(stored!)['notifications'], isFalse);
      expect(
        await const FlutterSecureStorage().read(
          key: PreferencesController.storageKey('another-user'),
        ),
        isNull,
      );
      router.go('/events');
      await tester.pumpAndSettle();
      expect(find.text('Notifications are paused'), findsOneWidget);
      expect(find.text('Run completed'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
