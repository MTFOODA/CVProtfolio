import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cv_portfolio_maker/app/session.dart';
import 'package:cv_portfolio_maker/core/l10n/app_strings.dart';
import 'package:cv_portfolio_maker/core/theme/app_tokens.dart';

/// Entry point for unauthenticated users.
///
/// Offers the Google sign-in flow and, for offline/local mode, a guest sign-in.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider2);
    final loading = session.isLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.md),
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
                  FilledButton.icon(
                    onPressed: loading
                        ? null
                        : () => ref
                              .read(sessionProvider2.notifier)
                              .signInWithGoogle(),
                    icon: const Icon(Icons.login),
                    label: Text(context.tr('signIn')),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: loading
                        ? null
                        : () => ref
                              .read(sessionProvider2.notifier)
                              .signInLocally(),
                    icon: const Icon(Icons.person_outline),
                    label: Text(context.tr('continueAsGuest')),
                  ),
                  if (loading) ...[
                    const SizedBox(height: AppSpacing.lg),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  if (session.hasError) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      context.tr('errorGeneric'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
