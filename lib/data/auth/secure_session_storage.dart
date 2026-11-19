import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Native session persistence; migrates the SDK's earlier plaintext session.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage(this.key, {FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final String key;
  final FlutterSecureStorage _storage;

  @override
  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = await _storage.read(key: key);
    final legacy = preferences.getString(key);
    if (existing == null && legacy != null) {
      await _storage.write(key: key, value: legacy);
    }
    // Remove plaintext only after its encrypted replacement has been written.
    if (legacy != null && !await preferences.remove(key)) {
      throw StateError('Could not remove legacy session');
    }
  }

  @override
  Future<bool> hasAccessToken() async => await _storage.read(key: key) != null;
  @override
  Future<String?> accessToken() => _storage.read(key: key);
  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: key, value: persistSessionString);
  @override
  Future<void> removePersistedSession() => _storage.delete(key: key);
}
