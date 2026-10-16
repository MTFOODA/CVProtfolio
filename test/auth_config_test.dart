/// Configuration contract.
///
/// Pins down where credentials come from (`--dart-define`), what the app does
/// when they are absent (local mode), which auth service each mode selects, and
/// that a missing Google client ID fails with an actionable message instead of
/// an opaque plugin error.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cv_portfolio_maker/core/config/app_config.dart';
import 'package:cv_portfolio_maker/data/auth/auth_service.dart';
import 'package:cv_portfolio_maker/data/auth/local_auth_service.dart';
import 'package:cv_portfolio_maker/data/auth/supabase_auth_service.dart';

/// A fully configured app. Every value is an obvious placeholder.
const AppConfig _configured = AppConfig(
  supabaseUrl: 'https://YOUR_PROJECT_REF.supabase.co',
  supabaseAnonKey: 'YOUR_SUPABASE_PUBLISHABLE_KEY',
  googleWebClientId: 'YOUR_GOOGLE_WEB_CLIENT_ID.apps.googleusercontent.com',
  googleIosClientId: 'YOUR_GOOGLE_IOS_CLIENT_ID.apps.googleusercontent.com',
  shareBaseUrl: 'https://example.test',
  backendMode: BackendMode.supabase,
);

/// The same app with no credentials at all: the state of a fresh checkout.
const AppConfig _unconfigured = AppConfig(
  supabaseUrl: '',
  supabaseAnonKey: '',
  googleWebClientId: '',
  googleIosClientId: '',
  shareBaseUrl: 'https://example.test',
);

void main() {
  group('AppConfig', () {
    test('with Supabase credentials it selects the Supabase backend', () {
      expect(_configured.isSupabaseConfigured, isTrue);
      expect(_configured.backendMode, BackendMode.supabase);
      expect(_configured.backendStatus, contains('Supabase'));
    });

    test('with no credentials it falls back to local mode', () {
      expect(_unconfigured.isSupabaseConfigured, isFalse);
      expect(_unconfigured.backendMode, BackendMode.local);
      expect(_unconfigured.backendStatus.toLowerCase(), contains('local'));
    });

    test('reports whether the Google web client ID is present', () {
      expect(_configured.hasGoogleWebClientId, isTrue);
      expect(_unconfigured.hasGoogleWebClientId, isFalse);
      expect(
        const AppConfig(
          supabaseUrl: 'https://YOUR_PROJECT_REF.supabase.co',
          supabaseAnonKey: 'YOUR_SUPABASE_PUBLISHABLE_KEY',
          googleWebClientId: '   ',
          googleIosClientId: '',
          shareBaseUrl: 'https://example.test',
          backendMode: BackendMode.supabase,
        ).hasGoogleWebClientId,
        isFalse,
        reason: 'whitespace is not a client ID',
      );
    });

    test('never prints the publishable key or a client ID', () {
      final text = _configured.toString();
      expect(text, isNot(contains('YOUR_SUPABASE_PUBLISHABLE_KEY')));
      expect(text, isNot(contains('YOUR_GOOGLE_WEB_CLIENT_ID')));
      expect(text, contains('supabase'));
    });

    test('fromEnvironment stays usable when nothing is defined', () {
      final config = AppConfig.fromEnvironment();
      expect(config.shareBaseUrl, isNotEmpty);
      expect(config.shareBaseUrl, startsWith('http'));
    });
  });

  group('auth service selection', () {
    test('a configured backend yields the Google-backed service', () {
      expect(createAuthService(_configured), isA<SupabaseAuthService>());
    });

    test('an unconfigured app yields the offline service', () {
      expect(createAuthService(_unconfigured), isA<LocalAuthService>());
    });

    test('offline mode still offers a working sign-in', () async {
      SharedPreferences.setMockInitialValues({});
      final user = await createAuthService(_unconfigured).signInWithGoogle();
      expect(user.id, isNotEmpty);
    });
  });

  group('Google client ID guard', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('Android without a web client ID says what to pass', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final service = SupabaseAuthService(_unconfigured);

      await expectLater(
        service.signInWithGoogle(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            allOf(contains('GOOGLE_WEB_CLIENT_ID'), contains('--dart-define')),
          ),
        ),
      );
    });

    test('iOS without an iOS client ID says what to pass', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final service = SupabaseAuthService(_unconfigured);

      await expectLater(
        service.signInWithGoogle(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('GOOGLE_IOS_CLIENT_ID'),
          ),
        ),
      );
    });

    test(
      'Windows is reported as unsupported, not as a silent failure',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        final service = SupabaseAuthService(_configured);

        await expectLater(
          service.signInWithGoogle(),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              contains('not supported on this platform'),
            ),
          ),
        );
      },
    );

    test('a supplied Android client ID is never reported as missing', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final service = SupabaseAuthService(_configured);

      Object? error;
      try {
        await service.signInWithGoogle();
      } on Object catch (e) {
        error = e;
      }

      // No plugin is registered in a unit test, so the call may fail in some
      // other way; what it must not do is claim the client ID is missing.
      expect('${error ?? ''}', isNot(contains('GOOGLE_WEB_CLIENT_ID')));
    });
  });
}
