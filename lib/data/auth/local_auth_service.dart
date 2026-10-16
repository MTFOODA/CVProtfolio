/// Offline authentication for local mode and tests.
///
/// No external service is contacted. A deterministic device-local identity is
/// created and persisted so sessions survive app restarts, which is exactly the
/// behaviour the persistence tests assert.
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

/// Session persistence keys.
const String _kUserId = 'auth.local.user_id';
const String _kEmail = 'auth.local.email';
const String _kName = 'auth.local.name';

/// A local, offline identity provider.
class LocalAuthService implements AuthService {
  LocalAuthService([SharedPreferences? prefs]) : _prefs = prefs;

  SharedPreferences? _prefs;
  AuthUser? _cached;

  Future<SharedPreferences> get _preferences async =>
      _prefs ??= await SharedPreferences.getInstance();

  @override
  AuthUser? get currentUser => _cached;

  @override
  Stream<AuthUser?> get authStateChanges => const Stream.empty();

  @override
  Future<AuthUser> signInWithGoogle() async {
    // Local mode has no Google provider configured; fall back to a local
    // identity so the product remains explorable.
    return signInLocally();
  }

  @override
  Future<AuthUser> signInLocally({String email = 'local@example.com'}) async {
    final prefs = await _preferences;
    final existingId = prefs.getString(_kUserId);
    final id = existingId ?? 'local-user';
    final user = AuthUser(
      id: id,
      email: prefs.getString(_kEmail) ?? email,
      displayName: prefs.getString(_kName),
    );
    await prefs.setString(_kUserId, user.id);
    await prefs.setString(_kEmail, user.email);
    _cached = user;
    return user;
  }

  @override
  Future<AuthUser?> restoreSession() async {
    final prefs = await _preferences;
    final id = prefs.getString(_kUserId);
    if (id == null) return null;
    final user = AuthUser(
      id: id,
      email: prefs.getString(_kEmail) ?? '',
      displayName: prefs.getString(_kName),
    );
    _cached = user;
    return user;
  }

  @override
  Future<void> signOut() async {
    final prefs = await _preferences;
    await prefs.remove(_kUserId);
    await prefs.remove(_kEmail);
    await prefs.remove(_kName);
    _cached = null;
  }
}
