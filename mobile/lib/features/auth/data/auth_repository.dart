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
        'display_name': displayName?.trim().isEmpty == true
            ? null
            : displayName?.trim(),
      },
    );
    final body = response.data!;
    await _store.saveToken(body['access_token'] as String);
    await _store.saveProfile(body['profile'] as Map<String, dynamic>);
    return UserProfile.fromJson(body['profile'] as Map<String, dynamic>);
  }

  Future<void> logout() => _store.clearToken();

  Future<UserProfile?> restore() async {
    if (await _store.readToken() == null) return null;
    try {
      final response = await _dio.get<Map<String, dynamic>>('/v1/me');
      await _store.saveProfile(response.data!);
      return UserProfile.fromJson(response.data!);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) return null;
      // Keep a previously validated profile when the network is unavailable.
      final cached = await _store.readProfile();
      if (cached != null && error.response == null) {
        return UserProfile.fromJson(cached);
      }
      rethrow;
    }
  }

  Future<UserProfile> update(Map<String, dynamic> changes) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/v1/me',
      data: changes,
    );
    await _store.saveProfile(response.data!);
    return UserProfile.fromJson(response.data!);
  }
}
