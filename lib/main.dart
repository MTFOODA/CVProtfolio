import 'dart:async';

import 'core/utils/web_routing.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthException, AuthUser;

import 'app/providers.dart';
import 'app/router.dart';
import 'app/session.dart';
import 'app/biometric_lock.dart';
import 'core/branding/app_branding.dart';
import 'core/config/app_config.dart';
import 'core/l10n/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_surfaces.dart';
import 'data/auth/auth_service.dart';
import 'data/auth/secure_session_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureWebRouting();

  final config = await AppConfig.load();
  if (config.isSupabaseConfigured) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: kIsWeb
            ? null
            : SecureSessionStorage(
                'sb-${Uri.parse(config.supabaseUrl).host.split('.').first}-auth-token',
              ),
      ),
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

/// The root of the CV & Portfolio Builder application.
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

class _AppContentState extends ConsumerState<_AppContent>
    with WidgetsBindingObserver {
  /// Mirrors the auth state so GoRouter can react to sign-in changes.
  final ValueNotifier<bool> _isSignedIn = ValueNotifier(false);
  final ValueNotifier<bool> _isRecoveringPassword = ValueNotifier(false);

  late final GoRouter _router;
  bool _privacyCover = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = buildRouter(
      isSignedIn: _isSignedIn,
      isRecoveringPassword: _isRecoveringPassword,
      currentUserId: () => ref.read(sessionProvider2).value?.id ?? '',
    );
    unawaited(ref.read(localeProvider.notifier).load());
    unawaited(ref.read(themeModeProvider.notifier).load());
    // Reflect the already-restored session (e.g. after hot reload).
    _isSignedIn.value = ref.read(sessionProvider2).value != null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    _isSignedIn.dispose();
    _isRecoveringPassword.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    final lock = ref.read(biometricLockProvider.notifier);
    switch (lifecycle) {
      case AppLifecycleState.resumed:
        lock.onResume();
        setState(() => _privacyCover = false);
      case AppLifecycleState.inactive:
        // Leaving the app locks immediately, except for our own native prompt.
        // A real background transition still invalidates an in-flight prompt.
        if (!ref.read(biometricLockProvider).busy) lock.onBackground();
        setState(() => _privacyCover = true);
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        lock.onBackground();
        setState(() => _privacyCover = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(passwordRecoveryProvider, (previous, next) {
      _isRecoveringPassword.value = next;
    });
    // Keep the router's sign-in listenable in sync with the session controller.
    ref.listen(sessionProvider2, (previous, next) {
      _isSignedIn.value = next.value != null;
    });

    return MaterialApp.router(
      title: kAppDisplayName,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      builder: (context, child) => AppBackdrop(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ?child,
            if (_privacyCover && ref.watch(biometricLockProvider).enabled)
              const ColoredBox(color: Colors.black),
          ],
        ),
      ),
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
