import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runova/core/network/api_client.dart';
import 'package:runova/features/auth/presentation/auth_controller.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'stored session restores profile, and a protected 401 clears it',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'runova_access_token': 'existing-token',
        'runova_profile': jsonEncode(testProfile),
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final dio = container.read(apiClientProvider);
      dio.httpClientAdapter = TestAdapter(
        (request) => request.path == '/v1/me'
            ? (200, testProfile)
            : (401, {'detail': 'expired'}),
      );
      final user = await container.read(authControllerProvider.future);
      expect(user?.username, 'runner');
      await expectLater(dio.get<dynamic>('/v1/runs'), throwsA(anything));
      expect(await container.read(authStoreProvider).readToken(), isNull);
      expect(container.read(authControllerProvider).value, isNull);
    },
  );

  test(
    '401 during session restoration cannot retain a cached profile',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'runova_access_token': 'expired-token',
        'runova_profile': jsonEncode(testProfile),
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(apiClientProvider).httpClientAdapter = TestAdapter(
        (_) => (401, {'detail': 'expired'}),
      );
      expect(await container.read(authControllerProvider.future), isNull);
      expect(await container.read(authStoreProvider).readToken(), isNull);
    },
  );
}
