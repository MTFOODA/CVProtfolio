import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthException, AuthUser;

import 'app/providers.dart';
import 'app/router.dart';
import 'app/session.dart';
import 'core/config/app_config.dart';
import 'core/l10n/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'data/auth/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  if (config.isSupabaseConfigured) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
    );
  }

  final backend = await createBackend(config);
  final authService = createAuthService(config);

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        backendProvider.overrideWithValue(backend),
        authServiceProvider.overrideWithValue(authService),
      ],
      child: const CVPortfolioStudio(),
    ),
  );
}

/// The root of the CV & Portfolio Studio application.
class CVPortfolioStudio extends StatelessWidget {
  const CVPortfolioStudio({super.key});

  @override
  Widget build(BuildContext context) => const _AppContent();
}

class _AppContent extends ConsumerStatefulWidget {
  const _AppContent();

  @override
  ConsumerState<_AppContent> createState() => _AppContentState();
}

class _AppContentState extends ConsumerState<_AppContent> {
  /// Mirrors the auth state so GoRouter can react to sign-in changes.
  final ValueNotifier<bool> _isSignedIn = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    // Reflect the already-restored session (e.g. after hot reload).
    _isSignedIn.value = ref.read(sessionProvider2).value != null;
  }

  @override
  void dispose() {
    _isSignedIn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the router's sign-in listenable in sync with the session controller.
    ref.listen(sessionProvider2, (previous, next) {
      _isSignedIn.value = next.value != null;
    });

    final router = buildRouter(
      isSignedIn: _isSignedIn,
      currentUserId: () => ref.read(sessionProvider2).value?.id ?? '',
    );

    return MaterialApp.router(
      title: 'CV & Portfolio Studio',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _resolveThemeMode(ref.watch(themeModeProvider)),
      locale: _resolveLocale(ref.watch(localeProvider)),
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }

  ThemeMode _resolveThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  Locale _resolveLocale(String code) {
    switch (code) {
      case 'ar':
        return const Locale('ar');
      case 'en':
      default:
        return const Locale('en');
    }
  }
}
