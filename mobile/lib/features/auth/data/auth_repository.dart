import 'package:dio/dio.dart';
import 'package:runova/core/storage/auth_store.dart';
import 'package:runova/features/auth/domain/user_profile.dart';

class AuthRepository {
  const AuthRepository(this._dio, this._store);

  final Dio _dio;
  final AuthStore _store;

  Future<UserProfile> directLogin({
    required String email,
    required String username,
    String? displayName,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/direct',
      data: {
        'email': email.trim().toLowerCase(),
        'username': username.trim(),
        'display_name': displayName?.trim().isEmpty == true ? null : displayName?.trim(),
      },
    );
    final body = response.data!;
    await _store.saveToken(body['access_token'] as String);
    return UserProfile.fromJson(body['profile'] as Map<String, dynamic>);
  }

  Future<void> logout() => _store.clearToken();
}
