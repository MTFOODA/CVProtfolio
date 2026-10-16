/// Application configuration.
///
/// Every value is supplied at build/run time through Dart `--dart-define`
/// flags, or through a JSON file that feeds the same values:
///
/// ```sh
/// flutter run \
///   --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY \
///   --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
/// ```
///
/// `dart_defines.example.json` is a placeholder copy of that file form; a real
/// `dart_defines.json` is git-ignored and must never be committed.
///
/// Only *public client* values belong here. Two credentials must never reach
/// this app: the Supabase **service-role key** and the Google **OAuth client
/// secret**. Both are server-side secrets used by the Supabase dashboard and
/// the Google Cloud console respectively.
library;

import 'package:flutter/foundation.dart';

/// Immutable configuration resolved from compile-time environment values.
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.googleWebClientId,
    required this.googleIosClientId,
    required this.shareBaseUrl,
    this.backendMode = BackendMode.local,
  });

  /// Configuration built purely from `--dart-define` values.
  factory AppConfig.fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_ANON_KEY');

    // Without both credentials the app falls back to local persistence so the
    // full product remains usable and testable offline.
    final hasSupabase = url.isNotEmpty && key.isNotEmpty;

    return AppConfig(
      supabaseUrl: url,
      supabaseAnonKey: key,
      googleWebClientId: const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
      googleIosClientId: const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
      shareBaseUrl: const String.fromEnvironment(
        'SHARE_BASE_URL',
        defaultValue: 'https://cv-portfolio.example.com',
      ),
      backendMode: hasSupabase ? BackendMode.supabase : BackendMode.local,
    );
  }

  /// Public backend endpoint, e.g. `https://YOUR_PROJECT_REF.supabase.co`.
  /// Safe to ship in the app.
  final String supabaseUrl;

  /// The dashboard's publishable (a.k.a. anon) key. A public client key: Row
  /// Level Security, not secrecy, is what protects the data.
  final String supabaseAnonKey;

  /// Google **web** OAuth client ID. Used as `serverClientId` on Android, where
  /// `google_sign_in` requires it, and by the Supabase Google provider.
  final String googleWebClientId;

  /// Google **iOS** OAuth client ID, passed to
  /// `GoogleSignIn.instance.initialize(clientId: ...)`. Only needed when an
  /// `ios/` platform folder exists.
  final String googleIosClientId;

  /// Base URL used to build public/restricted share links.
  final String shareBaseUrl;
  final BackendMode backendMode;

  bool get isSupabaseConfigured => backendMode == BackendMode.supabase;

  /// `true` when the Google client ID that Android and the web build need is
  /// present. Native Android sign-in cannot start without it.
  bool get hasGoogleWebClientId => googleWebClientId.trim().isNotEmpty;

  /// Human readable status for the settings/debug surface.
  String get backendStatus => isSupabaseConfigured
      ? 'Supabase connected'
      : 'Local mode (Supabase not configured)';

  @override
  String toString() =>
      'AppConfig(mode: ${backendMode.name}, '
      'supabaseConfigured: $isSupabaseConfigured)';

  /// Logs non-sensitive configuration info. Never logs keys.
  void debugLog() {
    if (kDebugMode) {
      debugPrint(toString());
    }
  }
}

/// Which persistence/auth backend is active.
enum BackendMode { local, supabase }
