/// Authentication abstraction.
///
/// [LocalAuthService] provides a fully working, offline identity so the app is
/// usable and testable without external credentials. [SupabaseAuthService]
/// implements the real Google Sign-In flow.
library;

import 'package:cv_portfolio_maker/core/config/app_config.dart';
import 'package:cv_portfolio_maker/data/auth/local_auth_service.dart';
import 'package:cv_portfolio_maker/data/auth/supabase_auth_service.dart';

/// An authenticated user.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
}

/// Authentication contract.
abstract interface class AuthService {
  /// The currently signed-in user, if any.
  AuthUser? get currentUser;

  /// Emits session changes (null on sign-out).
  Stream<AuthUser?> get authStateChanges;

  /// Starts Google Sign-In.
  ///
  /// Throws [AuthException] when the flow is cancelled or fails.
  Future<AuthUser> signInWithGoogle();

  /// Signs in as a local, offline user. No external credentials required.
  Future<AuthUser> signInLocally({String email = 'local@example.com'});

  /// Restores a persisted session, returning null when none exists.
  Future<AuthUser?> restoreSession();

  /// Signs out and clears persisted credentials.
  Future<void> signOut();
}

/// Raised for any authentication failure.
class AuthException implements Exception {
  const AuthException(this.message, {this.cancelled = false});

  final String message;

  /// `true` when the user dismissed the flow (not an error worth shouting).
  final bool cancelled;

  @override
  String toString() => 'AuthException: $message';
}

/// Builds the correct [AuthService] for the active configuration.
AuthService createAuthService(AppConfig config) {
  if (config.isSupabaseConfigured) {
    return SupabaseAuthService(config);
  }
  return LocalAuthService();
}
