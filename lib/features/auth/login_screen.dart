import '../../core/design/app_icons.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cv_portfolio_maker/app/session.dart';
import 'package:cv_portfolio_maker/app/providers.dart';
import 'package:cv_portfolio_maker/app/biometric_lock.dart';
import 'package:cv_portfolio_maker/core/branding/app_branding.dart';
import 'package:cv_portfolio_maker/core/l10n/app_strings.dart';
import 'package:cv_portfolio_maker/core/theme/app_tokens.dart';
import 'package:cv_portfolio_maker/core/widgets/app_motion.dart';

import 'auth_error_text.dart';
import '../../data/auth/auth_redirect.dart';
import '../../core/widgets/app_surfaces.dart';

/// Entry point for unauthenticated users.
///
/// Google, email/password and a local guest mode, plus links to registration
/// and password reset.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _emailMode = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider2);
    final loading = session.isLoading || ref.watch(biometricLockProvider).busy;

    return Scaffold(
      body: SafeArea(
        child: AppAuthLayout(
          title: context.tr('authHeroTitle'),
          subtitle: context.tr('authHeroSubtitle'),
          child: AppContentTransition(
            identity: _emailMode,
            child: _emailMode
                ? _EmailLoginForm(
                    onBack: () => setState(() => _emailMode = false),
                  )
                : _MainLoginOptions(
                    loading: loading,
                    hasError: session.hasError,
                    onEmailMode: () => setState(() => _emailMode = true),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Google / guest / email options.
class _MainLoginOptions extends ConsumerWidget {
  const _MainLoginOptions({
    required this.loading,
    required this.hasError,
    required this.onEmailMode,
  });

  final bool loading;
  final bool hasError;
  final VoidCallback onEmailMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(appConfigProvider).isSupabaseConfigured;
    final biometric = ref.watch(biometricLockProvider);
    final windowsHello = ref
        .watch(biometricAuthenticatorProvider)
        .usesWindowsHello;
    // The biometric gate intentionally keeps the routed session null while
    // locked. Observe Auth itself so an expired/revoked saved session still
    // rebuilds this button even when the routed session remains null.
    final authUser = ref.watch(authUserProvider);
    final savedUser = authUser.hasValue
        ? authUser.value
        : ref.read(authServiceProvider).currentUser;
    final canUnlock =
        biometric.locked &&
        biometric.ownerId != null &&
        savedUser?.id == biometric.ownerId;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Hero(
              tag: 'app-brand-mark',
              child: Image.asset(
                kAppLogoAsset,
                fit: BoxFit.cover,
                semanticLabel: context.tr('appName'),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          context.tr('appName'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.tr('signInSubtitle'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        if (canUnlock) ...[
          FilledButton.icon(
            key: const ValueKey('biometric-login'),
            icon: const Icon(AppIcons.fingerprint),
            label: Text(
              context.tr(windowsHello ? 'windowsHelloLogin' : 'biometricLogin'),
            ),
            onPressed: loading
                ? null
                : () async {
                    try {
                      final ok = await ref
                          .read(sessionProvider2.notifier)
                          .unlockWithBiometrics(
                            context.tr('biometricUnlockReason'),
                          );
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.tr('biometricFailed')),
                          ),
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.tr('biometricFailed')),
                          ),
                        );
                      }
                    }
                  },
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        FilledButton.icon(
          key: const ValueKey('google-login'),
          onPressed: loading || !online
              ? null
              : () => ref.read(sessionProvider2.notifier).signInWithGoogle(),
          icon: const Icon(AppIcons.google),
          label: Text(context.tr('signInWithGoogle')),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!online) ...[
          Text(
            context.tr('authOnlineUnavailable'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        OutlinedButton.icon(
          onPressed: loading ? null : onEmailMode,
          icon: const Icon(AppIcons.email),
          label: Text(context.tr('emailSignIn')),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!online)
          OutlinedButton.icon(
            onPressed: loading
                ? null
                : () => ref.read(sessionProvider2.notifier).signInLocally(),
            icon: const Icon(AppIcons.person),
            label: Text(context.tr('continueAsGuest')),
          ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: loading
              ? null
              : () => context.push(
                  authFlowLocation('/register', GoRouterState.of(context).uri),
                ),
          child: Text(context.tr('createNewAccount')),
        ),
        if (loading) ...[
          const SizedBox(height: AppSpacing.lg),
          const Center(child: CircularProgressIndicator()),
        ],
        if (hasError) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            authErrorText(context, ref.watch(sessionProvider2).error),
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

/// Email + password form with a forgot-password link.
class _EmailLoginForm extends ConsumerStatefulWidget {
  const _EmailLoginForm({required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<_EmailLoginForm> createState() => _EmailLoginFormState();
}

class _EmailLoginFormState extends ConsumerState<_EmailLoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(sessionProvider2.notifier)
        .signInWithEmail(email: _email.text.trim(), password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider2);
    final loading = session.isLoading;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          AppIcons.email,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          context.tr('emailSignIn'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.tr('emailSignInSubtitle'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return context.tr('required');
                  final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                      .hasMatch(text);
                  return valid ? null : context.tr('invalidCredentials');
                },
                decoration: InputDecoration(
                  labelText: context.tr('email'),
                  hintText: context.tr('emailPlaceholder'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (value) =>
                    (value ?? '').isEmpty ? context.tr('required') : null,
                decoration: InputDecoration(
                  labelText: context.tr('passwordPlaceholder'),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? AppIcons.preview : AppIcons.hidden),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: loading
                ? null
                : () => context.push(
                    authFlowLocation(
                      '/forgot-password',
                      GoRouterState.of(context).uri,
                    ),
                  ),
            child: Text(context.tr('forgotPassword')),
          ),
        ),
        FilledButton(
          onPressed: loading ? null : _submit,
          child: Text(context.tr('signIn')),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(context.tr('alreadyHaveAccount')),
            TextButton(
              onPressed: loading
                  ? null
                  : () => context.push(
                      authFlowLocation(
                        '/register',
                        GoRouterState.of(context).uri,
                      ),
                    ),
              child: Text(context.tr('createNewAccount')),
            ),
          ],
        ),
        OutlinedButton(
          onPressed: loading ? null : widget.onBack,
          child: Text(context.tr('back')),
        ),
        if (loading) ...[
          const SizedBox(height: AppSpacing.lg),
          const Center(child: CircularProgressIndicator()),
        ],
        if (session.hasError) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            authErrorText(context, session.error),
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}
