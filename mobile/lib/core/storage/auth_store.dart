import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStore extends ChangeNotifier {
  AuthStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'runova_access_token';
  static const _deviceKey = 'runova_device_id';

  Future<String?> readToken() => _storage.read(key: _tokenKey);
  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);
  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: 'runova_profile');
    notifyListeners();
  }

  Future<void> saveProfile(Map<String, dynamic> profile) =>
      _storage.write(key: 'runova_profile', value: jsonEncode(profile));
  Future<Map<String, dynamic>?> readProfile() async {
    final value = await _storage.read(key: 'runova_profile');
    return value == null ? null : jsonDecode(value) as Map<String, dynamic>;
  }

  Future<String?> readDeviceId() => _storage.read(key: _deviceKey);
  Future<void> saveDeviceId(String value) =>
      _storage.write(key: _deviceKey, value: value);
}
