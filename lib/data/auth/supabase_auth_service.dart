/// Supabase + Google Sign-In authentication.
///
/// Native Google Sign-In (Android/iOS) obtains an OpenID Connect ID token via
/// `GoogleSignIn.instance` which is exchanged for a Supabase session with
/// `signInWithIdToken`. On web the OAuth redirect flow is used instead, because
/// the browser (not the plugin) owns that redirect.
///
/// Platform configuration required (no secrets are hardcoded — the public client
/// IDs come from `--dart-define`, see `dart_defines.example.json`):
///   * Google Cloud: a **Web** OAuth client (used by the Supabase Google
///     provider) and, for Android, an **Android** OAuth client registered for
///     package `com.mtfooda.cv_portfolio_maker` plus the SHA-1 of each signing
///     key that is used to build the app.
///   * Android: `GOOGLE_WEB_CLIENT_ID`, passed as `serverClientId`. The plugin
///     needs the *web* client ID on Android unless a `google-services.json`
///     supplies it; this project ships no `google-services.json`, so the Dart
///     value is the one in effect. No redirect URL, custom scheme or deep link
///     takes part: the ID token is handed straight to Supabase.
///   * iOS (only if an `ios/` folder is added): `GOOGLE_IOS_CLIENT_ID` plus the
///     matching URL scheme in `Info.plist`.
///   * Web: `GOOGLE_WEB_CLIENT_ID`. The OAuth redirect returns to the app's own
///     URL, so that URL must be allowed in Supabase (Authentication → URL
///     Configuration) and `https://<project-ref>.supabase.co/auth/v1/callback`
///     must be registered with Google.
///   * Supabase: the Google provider enabled, with its client ID and secret
///     stored in the dashboard — never in this app.
library;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

import 'package:cv_portfolio_maker/core/config/app_config.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthException, AuthUser;

import 'auth_service.dart';

/// Supabase-backed authentication with Google identity.
class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._config);

  final AppConfig _config;

  /// `true` once [GoogleSignIn.instance.initialize] has completed. The plugin
  /// documents that initialization must happen exactly once.
  bool _googleInitialized = false;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  AuthUser? get currentUser {
    final user = _client.auth.currentUser;
    return user == null ? null : _mapUser(user);
  }

  @override
  Stream<AuthUser?> get authStateChanges =>
      _client.auth.onAuthStateChange.map((state) {
        final user = state.session?.user;
        return user == null ? null : _mapUser(user);
      });

  @override
  Future<AuthUser> signInWithGoogle() async {
    if (kIsWeb) return _signInWeb();
    return _signInNative();
  }

  /// Web redirect flow. No native Google plugin is used on web.
  Future<AuthUser> _signInWeb() async {
    final started = await _client.auth.signInWithOAuth(OAuthProvider.google);
    if (!started) {
      throw const AuthException('Google sign-in did not start');
    }
    // The redirect returns the user asynchronously; wait for the session.
    final session = await _awaitSession();
    if (session == null) {
      throw const AuthException('Google sign-in was cancelled');
    }
    return _mapUser(session.user);
  }

  /// Native Google sign-in used on Android and iOS.
  Future<AuthUser> _signInNative() async {
    await _ensureGoogleInitialized();

    final GoogleSignInAccount googleUser;
    try {
      googleUser = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException {
      throw const AuthException(
        'Google sign-in was cancelled',
        cancelled: true,
      );
    }

    // google_sign_in 7.x exposes only an ID token on the authentication object.
    final idToken = googleUser.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('Google did not return an ID token');
    }

    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
    final user = response.user;
    if (user == null) {
      throw const AuthException('Google sign-in failed');
    }
    return _mapUser(user);
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;

    // Turn two silent failure modes into actionable messages: a platform the
    // plugin does not cover, and a client ID that was never supplied.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      throw const AuthException(
        'Google sign-in is not supported on this platform '
        '(google_sign_in ships Android, iOS, macOS and web only). '
        'Use the Android or web build, or continue offline.',
      );
    }

    final missing = _missingClientId;
    if (missing != null) {
      throw AuthException(
        'Google sign-in is not configured: $missing is empty. Pass it at '
        'build time, for example --dart-define=$missing=YOUR_CLIENT_ID',
      );
    }

    await GoogleSignIn.instance.initialize(
      clientId: _config.googleIosClientId.isEmpty
          ? null
          : _config.googleIosClientId,
      serverClientId: _config.googleWebClientId.isEmpty
          ? null
          : _config.googleWebClientId,
    );
    _googleInitialized = true;
  }

  /// The build-time client ID the running platform cannot sign in without.
  ///
  /// `google_sign_in` needs the *web* client ID as `serverClientId` on Android
  /// and the iOS client ID as `clientId` on iOS. Starting the flow without the
  /// one that applies only ever fails inside the plugin, where the cause is
  /// reported as a configuration error or even as a spurious cancellation.
  String? get _missingClientId {
    if (defaultTargetPlatform == TargetPlatform.android &&
        _config.googleWebClientId.trim().isEmpty) {
      return 'GOOGLE_WEB_CLIENT_ID';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        _config.googleIosClientId.trim().isEmpty) {
      return 'GOOGLE_IOS_CLIENT_ID';
    }
    return null;
  }

  /// Waits briefly for the OAuth redirect to establish a session.
  Future<Session?> _awaitSession() async {
    final existing = _client.auth.currentSession;
    if (existing != null) return existing;
    try {
      return await _client.auth.onAuthStateChange
          .firstWhere((state) => state.session != null)
          .timeout(const Duration(seconds: 120))
          .then((state) => state.session);
    } on Object {
      return null;
    }
  }

  @override
  Future<AuthUser> signInLocally({String email = 'local@example.com'}) async {
    throw const AuthException(
      'Local sign-in is unavailable when Supabase is configured',
    );
  }

  @override
  Future<AuthUser?> restoreSession() async {
    final session = _client.auth.currentSession;
    return session == null ? null : _mapUser(session.user);
  }

  @override
  Future<void> signOut() async {
    if (_googleInitialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } on Object {
        // Not signed in with the native plugin; ignore.
      }
    }
    await _client.auth.signOut();
  }

  AuthUser _mapUser(User user) => AuthUser(
    id: user.id,
    email: user.email ?? '',
    displayName:
        user.userMetadata?['full_name'] as String? ??
        user.userMetadata?['name'] as String?,
    photoUrl: user.userMetadata?['avatar_url'] as String?,
  );
}
