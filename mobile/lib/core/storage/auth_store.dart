import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStore {
  const AuthStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'runova_access_token';
  static const _deviceKey = 'runova_device_id';

  Future<String?> readToken() => _storage.read(key: _tokenKey);
  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);
  Future<String?> readDeviceId() => _storage.read(key: _deviceKey);
  Future<void> saveDeviceId(String value) => _storage.write(key: _deviceKey, value: value);
}
