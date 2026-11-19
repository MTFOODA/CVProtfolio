/// Session, locale and theme controllers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cv_portfolio_maker/app/providers.dart';
import 'package:cv_portfolio_maker/data/auth/auth_service.dart';

import '../data/local/export_counter.dart';

import 'biometric_lock.dart';
import 'statistics.dart';

const _kLocale = 'settings.locale';
const _kTheme = 'settings.themeMode';

class PasswordRecoveryController extends Notifier<bool> {
  @override
  bool build() => false;

  void setActive(bool active) => state = active;
}

final passwordRecoveryProvider =
    NotifierProvider<PasswordRecoveryController, bool>(
      PasswordRecoveryController.new,
    );

/// Holds the signed-in user and bootstraps the persisted session.
class SessionController extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() async {
    final auth = ref.watch(authServiceProvider);
    final lock = ref.read(biometricLockProvider.notifier);
    ref.listen(biometricLockProvider.select((value) => value.locked), (
      _,
      locked,
    ) {
      if (locked) state = const AsyncData(null);
    });
    // Recovery can change while the user stays identical. Consume each auth
    // event directly rather than losing it to StreamProvider deduplication.
    String? lastUserId = auth.currentUser?.id;
    bool bootstrapped = false;
    bool hasPendingEvent = false;
    AuthUser? pendingUser;
    final subscription = auth.authStateChanges.listen((user) {
      if (!ref.mounted) return;
      if (!bootstrapped) {
        hasPendingEvent = true;
        pendingUser = user;
        return;
      }
      ref
          .read(passwordRecoveryProvider.notifier)
          .setActive(auth.isRecoveringPassword);
      if (lastUserId != user?.id) {
        ref.invalidate(profileProvider);
        ref.invalidate(documentsProvider);
        ref.invalidate(sharesProvider);
      }
      lastUserId = user?.id;
      state = AsyncData(ref.read(biometricLockProvider).locked ? null : user);
    });
    ref.onDispose(subscription.cancel);
    await lock.load();
    final restored = await auth.restoreSession();
    if (!ref.mounted) return null;
    final user = hasPendingEvent ? pendingUser : restored;
    bootstrapped = true;
    lastUserId = user?.id;
    if (ref.mounted) {
      ref
          .read(passwordRecoveryProvider.notifier)
          .setActive(auth.isRecoveringPassword);
    }
    return ref.read(biometricLockProvider).locked ? null : user;
  }

  Future<void> _acceptLogin(AuthUser? user) async {
    if (user != null) {
      await ref.read(biometricLockProvider.notifier).acceptFreshLogin(user.id);
    }
    if (ref.mounted) {
      state = AsyncData(ref.read(biometricLockProvider).locked ? null : user);
    }
  }

  Future<bool> unlockWithBiometrics(String reason) async {
    final auth = ref.read(authServiceProvider);
    final owner = ref.read(biometricLockProvider).ownerId;
    if (owner == null || auth.currentUser?.id != owner) return false;
    if (!await ref.read(biometricLockProvider.notifier).unlock(owner, reason)) {
      return false;
    }
    final user = await auth.restoreSession();
    if (!ref.mounted) return false;
    if (user?.id != owner) {
      ref.read(biometricLockProvider.notifier).lock();
      state = const AsyncData(null);
      return false;
    }
    if (ref.read(biometricLockProvider).locked) return false;
    state = AsyncData(user);
    return true;
  }

  Future<void> updatePassword(String password) async {
    final auth = ref.read(authServiceProvider);
    await auth.updatePassword(password);
    ref.read(passwordRecoveryProvider.notifier).setActive(false);
    state = AsyncData(
      ref.read(biometricLockProvider).locked ? null : auth.currentUser,
    );
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    try {
      final user = await ref.read(authServiceProvider).signInWithGoogle();
      await _acceptLogin(user);
    } on AuthException catch (e, st) {
      if (e.cancelled) {
        state = await AsyncValue.guard(() async {
          final user = await ref.read(authServiceProvider).restoreSession();
          return ref.read(biometricLockProvider).locked ? null : user;
        });
        return;
      }
      state = AsyncError(e, st);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = const AsyncLoading();
    try {
      final user = await ref
          .read(authServiceProvider)
          .registerWithEmail(
            email: email,
            password: password,
            fullName: fullName,
          );
      await _acceptLogin(user);
    } on AuthException catch (e, st) {
      state = AsyncError(e, st);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      final user = await ref
          .read(authServiceProvider)
          .signInWithEmail(email: email, password: password);
      await _acceptLogin(user);
    } on AuthException catch (e, st) {
      state = AsyncError(e, st);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncLoading();
    try {
      await ref.read(authServiceProvider).resetPassword(email);
      state = const AsyncData(null);
    } on AuthException catch (e, st) {
      state = AsyncError(e, st);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> signInLocally() async {
    state = const AsyncLoading();
    try {
      await _acceptLogin(await ref.read(authServiceProvider).signInLocally());
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> deleteAccount(String userId) async {
    if (state.value?.id != userId ||
        ref.read(authServiceProvider).currentUser?.id != userId) {
      throw const AuthException('Sign in before deleting your account');
    }
    // A failed server deletion must not erase the account's local statistics.
    await ref.read(backendProvider).deleteAccount(userId);
    try {
      await clearExportCount(userId);
    } finally {
      if (ref.mounted &&
          ref.read(authServiceProvider).currentUser?.id == userId) {
        await signOut();
      }
    }
  }

  /// User-facing exit: an enrolled account stays encrypted for biometric login.
  /// Revoking its refresh token would make native verification unable to log in.
  Future<void> exitToLogin() async {
    await ref.read(biometricLockProvider.notifier).load();
    if (!ref.mounted) return;
    final biometric = ref.read(biometricLockProvider);
    final user = ref.read(authServiceProvider).currentUser;
    if (biometric.enabled && biometric.ownerId == user?.id) {
      ref.read(biometricLockProvider.notifier).lock();
      state = const AsyncData(null);
      _clearAccountViews();
      return;
    }
    await signOut();
  }

  /// Complete sign-out, used when forgetting the session or deleting an account.
  Future<void> signOut() async {
    ref.read(biometricLockProvider.notifier).lock();
    state = const AsyncData(null);
    await ref.read(authServiceProvider).signOut();
    await ref.read(biometricLockProvider.notifier).disable();
    _clearAccountViews();
    state = const AsyncData(null);
  }

  void _clearAccountViews() {
    ref.invalidate(profileProvider);
    ref.invalidate(documentsProvider);
    ref.invalidate(sharesProvider);
    ref.invalidate(dashboardTabProvider);
    ref.invalidate(downloadCountProvider);
  }
}

final sessionProvider2 = AsyncNotifierProvider<SessionController, AuthUser?>(
  SessionController.new,
);

/// `en` or `ar`. Changing it flips the whole UI direction.
class LocaleController extends Notifier<String> {
  int _revision = 0;
  @override
  String build() => 'en';

  Future<void> load() async {
    final revision = _revision;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (ref.mounted && revision == _revision) {
        final saved = prefs.getString(_kLocale);
        state = saved == 'ar' ? 'ar' : 'en';
      }
    } catch (_) {
      /* Keep the usable default if preferences cannot be read. */
    }
  }

  Future<void> setLocale(String code) async {
    if (!{'ar', 'en'}.contains(code)) return;
    final previous = state;
    final revision = ++_revision;
    state = code;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(_kLocale, code)) {
        throw StateError('Preference was not saved');
      }
    } catch (_) {
      if (ref.mounted && revision == _revision) state = previous;
      rethrow;
    }
  }
}

final localeProvider = NotifierProvider<LocaleController, String>(
  LocaleController.new,
);

/// `system`, `light` or `dark`.
class ThemeModeController extends Notifier<String> {
  int _revision = 0;
  @override
  String build() => 'system';

  Future<void> load() async {
    final revision = _revision;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (ref.mounted && revision == _revision) {
        final saved = prefs.getString(_kTheme);
        state = {'system', 'light', 'dark'}.contains(saved) ? saved! : 'system';
      }
    } catch (_) {
      /* Keep the usable default if preferences cannot be read. */
    }
  }

  Future<void> setMode(String mode) async {
    if (!{'system', 'light', 'dark'}.contains(mode)) return;
    final previous = state;
    final revision = ++_revision;
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(_kTheme, mode)) {
        throw StateError('Preference was not saved');
      }
    } catch (_) {
      if (ref.mounted && revision == _revision) state = previous;
      rethrow;
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, String>(
  ThemeModeController.new,
);

class DashboardTabController extends Notifier<int> {
  @override
  int build() => 0;
  void select(int tab) => state = tab.clamp(0, 3);
}

final dashboardTabProvider = NotifierProvider<DashboardTabController, int>(
  DashboardTabController.new,
);
