import '../../core/design/app_icons.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/form_validation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth/auth_redirect.dart';

import 'package:cv_portfolio_maker/app/session.dart';
import 'package:cv_portfolio_maker/core/l10n/app_strings.dart';
import 'package:cv_portfolio_maker/core/theme/app_tokens.dart';

import 'auth_error_text.dart';

/// Registration: full name, email, password.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(sessionProvider2.notifier)
        .registerWithEmail(
          email: _email.text.trim(),
          password: _password.text,
          fullName: _name.text.trim(),
        );
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
    } else if (ref.read(sessionProvider2).value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('confirmEmailToContinue'))),
      );
    }
  }

  String? _emailValidator(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return context.tr('required');
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
    return valid ? null : context.tr('invalidCredentials');
  }

  String? _passwordValidator(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return context.tr('required');
    return text.length < 6 ? context.tr('weakPassword') : null;
  }

  String? _confirmValidator(String? value) {
    if ((value ?? '').isEmpty) return context.tr('required');
    return value != _password.text ? context.tr('passwordMismatch') : null;
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(sessionProvider2).isLoading;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('createNewAccount'))),
      body: AppAuthLayout(
        title: context.tr('authHeroTitle'),
        subtitle: context.tr('authHeroSubtitle'),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('register'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                context.tr('registerSubtitle'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              TextFormField(
                controller: _name,
                validator: context.validateName,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: context.tr('fullName'),
                  hintText: context.tr('fullNamePlaceholder'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _email,
                validator: _emailValidator,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: context.tr('email'),
                  hintText: context.tr('emailPlaceholder'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _password,
                validator: _passwordValidator,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: context.tr('passwordPlaceholder'),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? AppIcons.preview : AppIcons.hidden),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _confirm,
                validator: _confirmValidator,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: context.tr('confirmPassword'),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: loading ? null : _submit,
                child: Text(
                  loading ? context.tr('saving') : context.tr('createAccount'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(context.tr('alreadyHaveAccount')),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () => context.go(
                            authFlowLocation(
                              '/login',
                              GoRouterState.of(context).uri,
                            ),
                          ),
                    child: Text(context.tr('signInInstead')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
