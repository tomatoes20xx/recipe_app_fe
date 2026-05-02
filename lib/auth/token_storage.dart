import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _kTokenKey = 'jwt_token';
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _cached;

  Future<String?> readToken() async {
    if (_cached != null) return _cached;
    try {
      _cached = await _storage.read(key: _kTokenKey);
    } catch (_) {
      return null;
    }
    return _cached;
  }

  Future<void> saveToken(String token) async {
    _cached = token;
    try {
      await _storage.write(key: _kTokenKey, value: token);
    } catch (_) {}
  }

  Future<void> deleteToken() async {
    _cached = null;
    try {
      await _storage.delete(key: _kTokenKey);
    } catch (_) {}
  }
}
