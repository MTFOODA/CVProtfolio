import '../../core/design/app_icons.dart';
import '../../core/widgets/app_surfaces.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cv_portfolio_maker/app/session.dart';
import 'package:cv_portfolio_maker/core/l10n/app_strings.dart';
import 'package:cv_portfolio_maker/core/theme/app_tokens.dart';

import 'auth_error_text.dart';

/// Password reset request screen.
///
/// The email is sent by the configured auth provider (Supabase when
/// configured). The screen reports success only when the provider accepted the
/// request.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(sessionProvider2.notifier).resetPassword(_email.text.trim());
    if (!mounted) return;
    if (ref.read(sessionProvider2).hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authErrorText(context, ref.read(sessionProvider2).error),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    setState(() => _sent = true);
  }

  String? _emailValidator(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return context.tr('required');
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
    return valid ? null : context.tr('invalidCredentials');
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(sessionProvider2).isLoading;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('resetPassword'))),
      body: AppAuthLayout(
        title: context.tr('authHeroTitle'),
        subtitle: context.tr('authHeroSubtitle'),
        child: _sent
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    AppIcons.markEmailRead,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    context.tr('resetLinkSent'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    context.tr('resetLinkSentBody'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.tr('signInInstead')),
                  ),
                ],
              )
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      AppIcons.lockReset,
                      size: 56,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      context.tr('resetPassword'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      context.tr('resetPasswordSubtitle'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    TextFormField(
                      controller: _email,
                      validator: _emailValidator,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: context.tr('email'),
                        hintText: context.tr('resetEmailPlaceholder'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      onPressed: loading ? null : _submit,
                      child: Text(
                        loading
                            ? context.tr('sending')
                            : context.tr('sendResetLink'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
