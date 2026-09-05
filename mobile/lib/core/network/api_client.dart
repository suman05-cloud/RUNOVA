import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:runova/core/config/app_config.dart';
import 'package:runova/core/storage/auth_store.dart';

final authStoreProvider = Provider<AuthStore>(
  (ref) => const AuthStore(FlutterSecureStorage()),
);

final apiClientProvider = Provider<Dio>((ref) {
  final authStore = ref.watch(authStoreProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await authStore.readToken();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
    ),
  );
  return dio;
});
