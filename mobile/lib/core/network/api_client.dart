import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:runova/core/config/app_config.dart';
import 'package:runova/core/storage/auth_store.dart';

final authStoreProvider = Provider<AuthStore>((ref) {
  final store = AuthStore(const FlutterSecureStorage());
  ref.onDispose(store.dispose);
  return store;
});

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
        final expectedUser = options.extra['userId'];
        if (expectedUser != null &&
            (await authStore.readProfile())?['id'] != expectedUser) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.cancel,
              message: 'Account changed',
            ),
          );
          return;
        }
        final token = await authStore.readToken();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 &&
            !error.requestOptions.path.startsWith('/v1/auth/')) {
          final sent = error.requestOptions.headers['Authorization'];
          if (sent == 'Bearer ${await authStore.readToken()}') {
            await authStore.clearToken();
          }
        }
        handler.next(error);
      },
    ),
  );
  return dio;
});
