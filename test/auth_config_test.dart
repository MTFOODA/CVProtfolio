/// Configuration contract.
///
/// Pins down where credentials come from (`--dart-define`), what the app does
/// when they are absent (local mode), which auth service each mode selects, and
/// that a missing Google client ID fails with an actionable message instead of
/// an opaque plugin error.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cv_portfolio_maker/core/config/app_config.dart';
import 'package:cv_portfolio_maker/data/auth/auth_service.dart';
import 'package:cv_portfolio_maker/data/auth/local_auth_service.dart';
import 'package:cv_portfolio_maker/data/auth/supabase_auth_service.dart';
import 'package:cv_portfolio_maker/app/providers.dart';
import 'package:cv_portfolio_maker/app/session.dart';
import 'package:cv_portfolio_maker/features/auth/login_screen.dart';

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
  testWidgets(
    'explicit offline mode keeps Google visible but disabled and offers guest access',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = LocalAuthService();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(_unconfigured),
          authServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('google-login')))
            .onPressed,
        isNull,
      );
      expect(
        find.textContaining('Online sign-in is unavailable'),
        findsOneWidget,
      );
      expect(service.currentUser, isNull);
      await tester.ensureVisible(find.text('Explore without an account'));
      await tester.tap(find.text('Explore without an account'));
      await tester.pumpAndSettle();
      expect(container.read(sessionProvider2).value?.id, 'local-user');
    },
  );

  testWidgets(
    'normal startup without build flags shows enabled Google sign-in',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final config = await AppConfig.load(environmentValues: const {});
      expect(config.isSupabaseConfigured, isTrue);
      expect(config.hasGoogleWebClientId, isTrue);
      expect(createAuthService(config), isA<SupabaseAuthService>());
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          authServiceProvider.overrideWithValue(_SignedOutAuth()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('google-login')))
            .onPressed,
        isNotNull,
      );
      expect(find.text('Explore without an account'), findsNothing);
    },
  );

  test(
    'offline mode is explicit and does not need the bundled configuration',
    () async {
      final config = await AppConfig.load(
        offline: true,
        bundle: _MissingBundle(),
      );
      expect(config.isSupabaseConfigured, isFalse);
    },
  );

  test('a different deployment never mixes its credentials with the default project', () async {
    final config = await AppConfig.load(
      bundle: _MissingBundle(),
      environmentValues: const {
        'SUPABASE_URL': 'https://other.supabase.co',
        'SUPABASE_ANON_KEY': 'other-public-key',
        'GOOGLE_WEB_CLIENT_ID': 'other.apps.googleusercontent.com',
      },
    );
    expect(config.supabaseUrl, 'https://other.supabase.co');
    expect(config.supabaseAnonKey, 'other-public-key');
    expect(config.googleWebClientId, 'other.apps.googleusercontent.com');
    await expectLater(
      AppConfig.load(
        environmentValues: const {'SUPABASE_URL': 'https://other.supabase.co'},
      ),
      throwsFormatException,
    );
  });

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

    test('offline mode offers explicit guest sign-in', () async {
      SharedPreferences.setMockInitialValues({});
      final user = await createAuthService(_unconfigured).signInLocally();
      expect(user.id, isNotEmpty);
    });

    test(
      'an offline Google request cannot create or restore a guest account',
      () async {
        SharedPreferences.setMockInitialValues({});
        final service = createAuthService(_unconfigured);
        await expectLater(
          service.signInWithGoogle(),
          throwsA(isA<AuthException>()),
        );
        expect(await service.restoreSession(), isNull);
        final guest = await service.signInLocally();
        await expectLater(
          service.signInWithGoogle(),
          throwsA(isA<AuthException>()),
        );
        expect(service.currentUser, same(guest));
      },
    );
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

class _MissingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw StateError('Bundle should not be loaded');
}

class _SignedOutAuth extends Fake implements AuthService {
  @override
  AuthUser? get currentUser => null;
  @override
  bool get isRecoveringPassword => false;
  @override
  Stream<AuthUser?> get authStateChanges => const Stream.empty();
  @override
  Future<AuthUser?> restoreSession() async => null;
}
