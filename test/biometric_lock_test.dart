import 'dart:async';
import 'dart:io';

import 'package:cv_portfolio_maker/app/biometric_lock.dart';
import 'package:cv_portfolio_maker/app/providers.dart';
import 'package:cv_portfolio_maker/app/session.dart';
import 'package:cv_portfolio_maker/core/config/app_config.dart';
import 'package:cv_portfolio_maker/data/auth/auth_service.dart';
import 'package:cv_portfolio_maker/data/auth/biometric_authenticator.dart';
import 'package:cv_portfolio_maker/features/auth/login_screen.dart';
import 'package:cv_portfolio_maker/features/settings/settings_screen.dart';
import 'package:cv_portfolio_maker/main.dart';
import 'package:cv_portfolio_maker/data/local/local_repositories.dart';
import 'package:cv_portfolio_maker/data/local/local_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const owner = AuthUser(id: 'owner', email: 'owner@example.test');

class _Device implements BiometricAuthenticator {
  bool available = true;
  bool result = true;
  Completer<bool>? pending;
  int calls = 0;
  @override
  bool get usesWindowsHello => false;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<bool> authenticate(String reason) async {
    calls++;
    return pending == null ? result : pending!.future;
  }
}

class _Preferences implements BiometricPreferenceStore {
  String? ownerId;
  bool failRead = false;
  bool failWrite = false;
  @override
  Future<String?> readOwner() async {
    if (failRead) throw StateError('Storage unavailable');
    return ownerId;
  }

  @override
  Future<void> saveOwner(String? userId) async {
    if (failWrite) throw StateError('Storage unavailable');
    ownerId = userId;
  }
}

class _Auth extends Fake implements AuthService {
  final events = StreamController<AuthUser?>.broadcast();
  AuthUser? user = owner;
  bool cancelGoogle = false;
  int signOutCalls = 0;
  @override
  AuthUser? get currentUser => user;
  @override
  bool get isRecoveringPassword => false;
  @override
  Stream<AuthUser?> get authStateChanges => events.stream;
  @override
  Future<AuthUser?> restoreSession() async => user;
  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async => user!;
  @override
  Future<AuthUser> signInWithGoogle() async {
    if (cancelGoogle) throw const AuthException('Cancelled', cancelled: true);
    return user!;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    user = null;
    events.add(null);
  }
}

void main() {
  late _Device device;
  late _Preferences preferences;
  late _Auth auth;
  late ProviderContainer container;

  Future<void> start({LocalBackendOrSupabase? backend}) async {
    container = ProviderContainer(
      overrides: [
        if (backend != null) backendProvider.overrideWithValue(backend),
        biometricAuthenticatorProvider.overrideWithValue(device),
        biometricPreferenceStoreProvider.overrideWithValue(preferences),
        authServiceProvider.overrideWithValue(auth),
        appConfigProvider.overrideWithValue(
          const AppConfig(
            supabaseUrl: 'https://example.supabase.co',
            supabaseAnonKey: 'anon',
            googleWebClientId: '',
            googleIosClientId: '',
            shareBaseUrl: 'https://example.test',
            backendMode: BackendMode.supabase,
          ),
        ),
      ],
    );
    container.listen(sessionProvider2, (_, _) {});
    await container.read(sessionProvider2.future);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    device = _Device();
    preferences = _Preferences();
    auth = _Auth();
  });
  tearDown(() async {
    container.dispose();
    await auth.events.close();
  });

  test(
    'startup locks an opted-in account and refresh events cannot unlock it',
    () async {
      preferences.ownerId = owner.id;
      await start();
      expect(container.read(sessionProvider2).value, isNull);
      auth.events.add(owner);
      await container.pump();
      expect(container.read(sessionProvider2).value, isNull);
      device.result = false;
      expect(
        await container
            .read(sessionProvider2.notifier)
            .unlockWithBiometrics('Unlock'),
        isFalse,
      );
      expect(container.read(sessionProvider2).value, isNull);
      device.result = true;
      expect(
        await container
            .read(sessionProvider2.notifier)
            .unlockWithBiometrics('Unlock'),
        isTrue,
      );
      expect(container.read(sessionProvider2).value?.id, owner.id);
    },
  );

  test('backgrounding relocks, returning does not unlock, fresh credentials can unlock', () async {
    await start();
    final lock = container.read(biometricLockProvider.notifier);
    expect(await lock.enable(owner.id, 'Enable'), isTrue);
    expect(preferences.ownerId, owner.id);
    lock.onBackground();
    expect(container.read(sessionProvider2).value, isNull);
    lock.onResume();
    expect(container.read(sessionProvider2).value, isNull);
    auth.cancelGoogle = true;
    await container.read(sessionProvider2.notifier).signInWithGoogle();
    expect(container.read(sessionProvider2).value, isNull);
    await container
        .read(sessionProvider2.notifier)
        .signInWithEmail(email: owner.email, password: 'password');
    expect(container.read(sessionProvider2).value?.id, owner.id);
    expect(preferences.ownerId, owner.id);
  });

  test(
    'late biometric results after backgrounding never unlock the account',
    () async {
      preferences.ownerId = owner.id;
      await start();
      device.pending = Completer<bool>();
      final future = container
          .read(sessionProvider2.notifier)
          .unlockWithBiometrics('Unlock');
      await container.pump();
      final lock = container.read(biometricLockProvider.notifier);
      lock.onBackground();
      lock.onResume();
      device.pending!.complete(true);
      expect(await future, isFalse);
      expect(container.read(sessionProvider2).value, isNull);
    },
  );

  test('a failed enable or unavailable sensor never saves an opt-in', () async {
    await start();
    final lock = container.read(biometricLockProvider.notifier);
    device.result = false;
    expect(await lock.enable(owner.id, 'Enable'), isFalse);
    expect(preferences.ownerId, isNull);
    device.available = false;
    expect(await lock.enable(owner.id, 'Enable'), isFalse);
    expect(preferences.ownerId, isNull);
  });

  test('disabled feature preserves current session on backgrounding', () async {
    await start();
    final lock = container.read(biometricLockProvider.notifier);
    await lock.enable(owner.id, 'Enable');
    await lock.disable();
    lock.onBackground();
    lock.onResume();
    expect(preferences.ownerId, isNull);
    expect(container.read(sessionProvider2).value?.id, owner.id);
  });

  test('complete sign-out clears enrollment and does not leave an unlockable session', () async {
    await start();
    await container
        .read(biometricLockProvider.notifier)
        .enable(owner.id, 'Enable');
    await container.read(sessionProvider2.notifier).signOut();
    expect(preferences.ownerId, isNull);
    expect(auth.currentUser, isNull);
    expect(container.read(sessionProvider2).value, isNull);
  });

  test('logout preserves an enrolled session across restart and requires biometrics', () async {
    await start();
    await container
        .read(biometricLockProvider.notifier)
        .enable(owner.id, 'Enable');
    await container.read(sessionProvider2.notifier).exitToLogin();
    expect(auth.signOutCalls, 0);
    expect(auth.currentUser?.id, owner.id);
    expect(preferences.ownerId, owner.id);
    expect(container.read(sessionProvider2).value, isNull);
    auth.events.add(owner);
    await container.pump();
    expect(container.read(sessionProvider2).value, isNull);
    container.dispose();
    await start();
    expect(container.read(sessionProvider2).value, isNull);
    device.result = false;
    expect(
      await container
          .read(sessionProvider2.notifier)
          .unlockWithBiometrics('Unlock'),
      isFalse,
    );
    expect(container.read(sessionProvider2).value, isNull);
    device.result = true;
    expect(
      await container
          .read(sessionProvider2.notifier)
          .unlockWithBiometrics('Unlock'),
      isTrue,
    );
    expect(container.read(sessionProvider2).value?.id, owner.id);
  });

  test('logout without biometric enrollment revokes the session', () async {
    await start();
    await container.read(sessionProvider2.notifier).exitToLogin();
    expect(auth.signOutCalls, 1);
    expect(auth.currentUser, isNull);
    expect(preferences.ownerId, isNull);
    expect(container.read(sessionProvider2).value, isNull);
  });

  test(
    'logout cannot retain a different account using an old enrollment',
    () async {
      preferences.ownerId = 'old-owner';
      await start();
      await container.read(sessionProvider2.notifier).exitToLogin();
      expect(auth.signOutCalls, 1);
      expect(auth.currentUser, isNull);
      expect(preferences.ownerId, isNull);
    },
  );

  test('unreadable opt-in fails closed and changing accounts clears old enrollment', () async {
    preferences.failRead = true;
    await start();
    expect(container.read(sessionProvider2).value, isNull);
    await container
        .read(sessionProvider2.notifier)
        .signInWithEmail(email: owner.email, password: 'password');
    expect(container.read(sessionProvider2).value?.id, owner.id);
    preferences.failRead = false;
    final lock = container.read(biometricLockProvider.notifier);
    await lock.enable(owner.id, 'Enable');
    lock.onBackground();
    lock.onResume();
    auth.user = const AuthUser(id: 'another', email: 'another@example.test');
    await container
        .read(sessionProvider2.notifier)
        .signInWithEmail(email: auth.user!.email, password: 'password');
    expect(preferences.ownerId, isNull);
    expect(container.read(sessionProvider2).value?.id, 'another');
  });

  testWidgets(
    'the actual app returns to login on pause and keeps its enrolled session locked after resume',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'cv_biometric_lifecycle_',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final backend = LocalBackendOrSupabase.local(
        LocalBackend(LocalStore.forDirectory(directory)),
      );
      preferences.ownerId = owner.id;
      await start(backend: backend);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CVPortfolioStudio(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      device.pending = Completer<bool>();
      await tester.tap(find.byKey(const ValueKey('biometric-login')));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      device.pending!.complete(true);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(container.read(sessionProvider2).value, isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(container.read(sessionProvider2).value, isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('biometric-login')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'expired locked session removes the biometric action without clearing enrollment',
    (tester) async {
      preferences.ownerId = owner.id;
      await start();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(container.read(sessionProvider2).value, isNull);
      expect(find.byKey(const ValueKey('biometric-login')), findsOneWidget);
      auth.user = null;
      auth.events.add(null);
      await tester.pumpAndSettle();
      expect(container.read(sessionProvider2).value, isNull);
      expect(find.byKey(const ValueKey('biometric-login')), findsNothing);
      expect(find.byKey(const ValueKey('google-login')), findsOneWidget);
      expect(preferences.ownerId, owner.id);
      expect(device.calls, 0);
      expect(auth.signOutCalls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'settings enables the option and login shows its button only for an enrolled session',
    (tester) async {
      await start();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final toggle = find.widgetWithText(
        SwitchListTile,
        'Sign in with biometrics',
      );
      final settingsScroll = find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(toggle, 350, scrollable: settingsScroll);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(preferences.ownerId, owner.id);
      final logout = find.byKey(const ValueKey('account-logout'));
      await tester.scrollUntilVisible(logout, 250, scrollable: settingsScroll);
      await tester.tap(logout);
      await tester.pumpAndSettle();
      expect(auth.signOutCalls, 0);
      expect(container.read(sessionProvider2).value, isNull);
      expect(preferences.ownerId, owner.id);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('biometric-login')), findsOneWidget);
      device.result = false;
      await tester.tap(find.byKey(const ValueKey('biometric-login')));
      await tester.pumpAndSettle();
      expect(container.read(sessionProvider2).value, isNull);
      device.result = true;
      await tester.tap(find.byKey(const ValueKey('biometric-login')));
      await tester.pumpAndSettle();
      expect(container.read(sessionProvider2).value?.id, owner.id);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
