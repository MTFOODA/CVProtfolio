/// Session, locale and theme controllers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cv_portfolio_maker/app/providers.dart';
import 'package:cv_portfolio_maker/data/auth/auth_service.dart';

const _kLocale = 'settings.locale';
const _kTheme = 'settings.themeMode';

/// Holds the signed-in user and bootstraps the persisted session.
class SessionController extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() async {
    return ref.watch(authServiceProvider).restoreSession();
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    try {
      final user = await ref.read(authServiceProvider).signInWithGoogle();
      state = AsyncData(user);
    } on AuthException catch (e, st) {
      if (e.cancelled) {
        state = await AsyncValue.guard(
          () => ref.read(authServiceProvider).restoreSession(),
        );
        return;
      }
      state = AsyncError(e, st);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> signInLocally() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authServiceProvider).signInLocally(),
    );
  }

  Future<void> signOut() async {
    await ref.read(authServiceProvider).signOut();
    ref.invalidate(profileProvider);
    ref.invalidate(documentsProvider);
    ref.invalidate(sharesProvider);
    state = const AsyncData(null);
  }
}

final sessionProvider2 = AsyncNotifierProvider<SessionController, AuthUser?>(
  SessionController.new,
);

/// `en` or `ar`. Changing it flips the whole UI direction.
class LocaleController extends Notifier<String> {
  @override
  String build() => 'en';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_kLocale) ?? 'en';
  }

  Future<void> setLocale(String code) async {
    state = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocale, code);
  }
}

final localeProvider = NotifierProvider<LocaleController, String>(
  LocaleController.new,
);

/// `system`, `light` or `dark`.
class ThemeModeController extends Notifier<String> {
  @override
  String build() => 'system';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_kTheme) ?? 'system';
  }

  Future<void> setMode(String mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTheme, mode);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, String>(
  ThemeModeController.new,
);
