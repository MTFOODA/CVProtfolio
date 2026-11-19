import '../../core/widgets/app_surfaces.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/session.dart';
import '../../core/l10n/app_strings.dart';
import 'auth_error_text.dart';
import '../../data/auth/auth_redirect.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  Object? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider2.notifier).updatePassword(_password.text);
      if (mounted) {
        context.go(
          internalReturnLocation(
                GoRouterState.of(context).uri.queryParameters['from'],
              ) ??
              '/',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider2);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('resetPassword'))),
      body: AppAuthLayout(
        title: context.tr('authHeroTitle'),
        subtitle: context.tr('authHeroSubtitle'),
        child: session.isLoading
            ? const Center(child: CircularProgressIndicator())
            : session.value == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.tr('authRecoveryExpired')),
                  TextButton(
                    onPressed: () => context.go(
                      authFlowLocation(
                        '/forgot-password',
                        GoRouterState.of(context).uri,
                      ),
                    ),
                    child: Text(context.tr('resetPassword')),
                  ),
                ],
              )
            : Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      enabled: !_saving,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: context.tr('authNewPassword'),
                      ),
                      validator: (value) => (value ?? '').length < 6
                          ? context.tr('weakPassword')
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirm,
                      obscureText: true,
                      enabled: !_saving,
                      decoration: InputDecoration(
                        labelText: context.tr('confirmPassword'),
                      ),
                      validator: (value) => value != _password.text
                          ? context.tr('passwordMismatch')
                          : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: Text(
                        context.tr(_saving ? 'saving' : 'resetPassword'),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        authErrorText(context, _error),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
