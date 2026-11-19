import '../portfolio/portfolio_builder_screen.dart';
import '../../core/design/app_icons.dart';

import 'package:cv_portfolio_maker/core/l10n/ui_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cv_portfolio_maker/app/providers.dart';
import 'package:cv_portfolio_maker/app/session.dart';
import 'package:cv_portfolio_maker/app/biometric_lock.dart';
import 'package:cv_portfolio_maker/core/l10n/app_strings.dart';
import 'package:cv_portfolio_maker/core/theme/app_tokens.dart';
import 'package:cv_portfolio_maker/core/widgets/app_page_body.dart';
import 'package:cv_portfolio_maker/core/widgets/app_motion.dart';

/// Application preferences: theme, locale and account actions.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final userId = ref.watch(sessionProvider2).value?.id;
    final biometric = ref.watch(biometricLockProvider);
    final windowsHello = ref
        .watch(biometricAuthenticatorProvider)
        .usesWindowsHello;
    final online = ref.watch(appConfigProvider).isSupabaseConfigured;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(context.tr('settings')),
      ),
      body: AppPageBody(
        child: ListView(
          padding: AppSpacing.pagePadding(context),
          children: [
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(AppIcons.customize),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          context.tr('portfolioSettingsTitle'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const PortfolioBuilderScreen(
                    settingsOnly: true,
                    embeddedSettings: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('theme'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: 'system',
                        label: Text(context.tr('system')),
                      ),
                      ButtonSegment(
                        value: 'light',
                        label: Text(context.tr('light')),
                      ),
                      ButtonSegment(
                        value: 'dark',
                        label: Text(context.tr('dark')),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selection) => _savePreference(
                      context,
                      () => ref
                          .read(themeModeProvider.notifier)
                          .setMode(selection.first),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('language'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'en',
                        label: const UiText('English'),
                      ),
                      ButtonSegment(
                        value: 'ar',
                        label: const UiText('العربية'),
                      ),
                    ],
                    selected: {locale},
                    onSelectionChanged: (selection) => _savePreference(
                      context,
                      () => ref
                          .read(localeProvider.notifier)
                          .setLocale(selection.first),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(AppIcons.fingerprint),
                title: Text(
                  context.tr(
                    windowsHello ? 'windowsHelloLogin' : 'biometricLogin',
                  ),
                ),
                subtitle: Text(
                  context.tr(
                    !online
                        ? 'biometricRequiresAccount'
                        : biometric.available
                        ? 'biometricSettingDescription'
                        : 'biometricUnavailable',
                  ),
                ),
                value: userId != null && biometric.ownerId == userId,
                onChanged:
                    !online ||
                        userId == null ||
                        biometric.busy ||
                        (!biometric.available && !biometric.enabled)
                    ? null
                    : (enabled) => _savePreference(context, () async {
                        final controller = ref.read(
                          biometricLockProvider.notifier,
                        );
                        if (!enabled) {
                          await controller.disable();
                        } else {
                          final ok = await controller.enable(
                            userId,
                            context.tr('biometricEnableReason'),
                          );
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.tr('biometricFailed')),
                              ),
                            );
                          }
                        }
                      }),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('account'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    key: const ValueKey('account-logout'),
                    onPressed: () => _savePreference(
                      context,
                      () => ref.read(sessionProvider2.notifier).exitToLogin(),
                    ),
                    icon: const Icon(AppIcons.logout),
                    label: Text(context.tr('signOut')),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: userId == null
                        ? null
                        : () => _confirmDeleteAccount(context, ref, userId),
                    icon: const Icon(AppIcons.deleteForever),
                    label: Text(context.tr('deleteAccount')),
                  ),
                ],
              ),
            ),
          ].map((child) => AppReveal(child: child)).toList(),
        ),
      ),
    );
  }

  Future<void> _savePreference(
    BuildContext context,
    Future<void> Function() save,
  ) async {
    try {
      await save();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('errorGeneric'))));
      }
    }
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('deleteAccount')),
        content: Text(context.tr('deleteAccountWarning')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.tr('confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(sessionProvider2.notifier).deleteAccount(userId);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('errorGeneric'))));
      }
    }
  }
}

/// A simple card wrapper with a consistent surface colour.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: child,
      ),
    );
  }
}
