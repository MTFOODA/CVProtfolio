/// Application configuration.
///
/// Normal startup loads the bundled public project settings. Build-time
/// `--dart-define` values can override them for a different deployment:
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

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Immutable public application settings.
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
  factory AppConfig.fromEnvironment() =>
      AppConfig._fromValues(_environmentValues);

  static const publicConfigAsset = 'assets/config/public_app_config.json';

  static Map<String, String> get _environmentValues => {
    'SUPABASE_URL': const String.fromEnvironment('SUPABASE_URL'),
    'SUPABASE_ANON_KEY': const String.fromEnvironment('SUPABASE_ANON_KEY'),
    'GOOGLE_WEB_CLIENT_ID': const String.fromEnvironment(
      'GOOGLE_WEB_CLIENT_ID',
    ),
    'GOOGLE_IOS_CLIENT_ID': const String.fromEnvironment(
      'GOOGLE_IOS_CLIENT_ID',
    ),
    'SHARE_BASE_URL': const String.fromEnvironment('SHARE_BASE_URL'),
  };

  /// Loads the same connected settings on Android, web and desktop even when
  /// launched with plain `flutter run`. Offline operation is an explicit choice.
  static Future<AppConfig> load({
    AssetBundle? bundle,
    Map<String, String>? environmentValues,
    bool offline = const bool.fromEnvironment('OFFLINE_MODE'),
  }) async {
    if (offline) return AppConfig._fromValues(const {});
    final overrides = environmentValues ?? _environmentValues;
    final url = overrides['SUPABASE_URL']?.trim() ?? '';
    final key = overrides['SUPABASE_ANON_KEY']?.trim() ?? '';
    if (url.isNotEmpty != key.isNotEmpty) {
      throw const FormatException(
        'SUPABASE_URL and SUPABASE_ANON_KEY must be supplied together',
      );
    }
    // Never combine credentials for a different project with the bundled ones.
    if (url.isNotEmpty && key.isNotEmpty) {
      return AppConfig._fromValues(overrides);
    }
    final raw = await (bundle ?? rootBundle).loadString(publicConfigAsset);
    final defaults = (jsonDecode(raw) as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value as String),
    );
    final config = AppConfig._fromValues({
      ...defaults,
      for (final entry in overrides.entries)
        if (entry.value.trim().isNotEmpty) entry.key: entry.value,
    });
    if (!config.isSupabaseConfigured || !config.hasGoogleWebClientId) {
      throw const FormatException(
        'Bundled public application settings are incomplete',
      );
    }
    return config;
  }

  factory AppConfig._fromValues(Map<String, String> values) {
    final url = values['SUPABASE_URL']?.trim() ?? '';
    final key = values['SUPABASE_ANON_KEY']?.trim() ?? '';

    // Without both credentials the app falls back to local persistence so the
    // full product remains usable and testable offline.
    final hasSupabase = url.isNotEmpty && key.isNotEmpty;

    return AppConfig(
      supabaseUrl: url,
      supabaseAnonKey: key,
      googleWebClientId: values['GOOGLE_WEB_CLIENT_ID']?.trim() ?? '',
      googleIosClientId: values['GOOGLE_IOS_CLIENT_ID']?.trim() ?? '',
      shareBaseUrl: (values['SHARE_BASE_URL']?.trim().isNotEmpty ?? false)
          ? values['SHARE_BASE_URL']!.trim()
          : 'https://cv-portfolio.example.com',
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
      ? 'Supabase configured'
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
