import '../about/about_app_screen.dart';
import '../../core/design/app_icons.dart';

import 'package:cv_portfolio_maker/core/l10n/ui_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cv_portfolio_maker/app/providers.dart';
import 'package:cv_portfolio_maker/app/session.dart';
import 'package:cv_portfolio_maker/app/statistics.dart';
import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/l10n/app_strings.dart';
import 'package:cv_portfolio_maker/core/theme/app_tokens.dart';
import 'package:cv_portfolio_maker/core/widgets/app_motion.dart';
import 'package:cv_portfolio_maker/core/widgets/app_navigation_shell.dart';
import 'package:cv_portfolio_maker/core/widgets/app_surfaces.dart';
import 'package:cv_portfolio_maker/core/branding/app_branding.dart';
import 'package:cv_portfolio_maker/core/utils/utils.dart';
import 'package:cv_portfolio_maker/features/cv_builder/cv_builder_wizard_screen.dart';

import 'package:cv_portfolio_maker/features/settings/settings_screen.dart';

/// Landing surface for authenticated users.
///
/// A fixed bottom navigation switches between Home, Build CV, Portfolio and
/// Settings while each tab keeps its own state.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key, this.settingsRoute = false});
  final bool settingsRoute;

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final tab = widget.settingsRoute ? 3 : ref.watch(dashboardTabProvider);
    return AppNavigationShell(
      body: AppContentTransition(
        identity: tab,
        child: IndexedStack(
          index: tab,
          children: [
            const _DashboardHome(),
            CvBuilderWizardScreen(active: tab == 1),
            const SizedBox.shrink(),
            tab == 3 ? const SettingsScreen() : const SizedBox.shrink(),
          ],
        ),
      ),
      selectedIndex: tab,
      onSelected: (value) {
        if (value == 2) {
          context.push('/portfolio');
        } else if (value == 3) {
          context.go('/settings');
        } else {
          ref.read(dashboardTabProvider.notifier).select(value);
          if (widget.settingsRoute) context.go('/');
          final userId = ref.read(sessionProvider2).value?.id;
          if (value == 0 && userId != null) {
            ref.invalidate(sharesProvider(userId));
            ref.invalidate(downloadCountProvider(userId));
          }
        }
      },
      destinations: [
        NavigationDestination(
          icon: const Icon(AppIcons.home),
          selectedIcon: const Icon(AppIcons.home),
          label: context.tr('home'),
        ),
        NavigationDestination(
          icon: const Icon(AppIcons.document),
          selectedIcon: const Icon(AppIcons.document),
          label: context.tr('buildCv'),
        ),
        NavigationDestination(
          icon: const Icon(AppIcons.portfolio),
          selectedIcon: const Icon(AppIcons.portfolio),
          label: context.tr('portfolio'),
        ),
        NavigationDestination(
          icon: const Icon(AppIcons.settings),
          selectedIcon: const Icon(AppIcons.settings),
          label: context.tr('settings'),
        ),
      ],
    );
  }
}

/// The scrollable Home tab: greeting, statistics, CVs and profile completion.
class _DashboardHome extends ConsumerStatefulWidget {
  const _DashboardHome();

  @override
  ConsumerState<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends ConsumerState<_DashboardHome> {
  Future<void> _refresh() async {
    final userId = ref.read(sessionProvider2).value?.id;
    if (userId != null) {
      ref.invalidate(documentsProvider(userId));
      ref.invalidate(profileProvider(userId));
      ref.invalidate(sharesProvider(userId));
      ref.invalidate(downloadCountProvider(userId));
      await ref.read(downloadCountProvider(userId).future);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider2).value;
    final userId = user?.id;

    if (userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final documentsAsync = ref.watch(documentsProvider(userId));
    final profileAsync = ref.watch(profileProvider(userId));
    final sharesAsync = ref.watch(sharesProvider(userId));
    final downloads = ref.watch(downloadCountProvider(userId)).value ?? 0;

    final documents = documentsAsync.value ?? const <CvDocument>[];
    final cvs = documents.where((d) => d.type == DocumentType.cv).toList();
    final portfolioViews = portfolioViewTotal(
      userId,
      documents,
      sharesAsync.value ?? const <DocumentShare>[],
    );

    return RefreshIndicator(
      onRefresh: _refresh,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.contentWidth),
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              _DashboardHeader(
                name: profileAsync.value?.details.fullName ?? user?.displayName,
                avatarUrl: profileAsync.value?.details.avatarUrl,
                onSettings: () => context.go('/settings'),
                onProfile: () => context.push('/profile'),
                onBuild: () => _createCv(userId),
                onPortfolio: () => context.push('/portfolio'),
              ),
              Padding(
                padding: AppSpacing.pagePadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      [
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: _StatCard(
                                      icon: AppIcons.document,
                                      label: context.tr('cvCreated'),
                                      value: '${cvs.length}',
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: _StatCard(
                                      icon: AppIcons.preview,
                                      key: const ValueKey(
                                        'portfolio-views-stat',
                                      ),
                                      label: context.tr('portfolioViews'),
                                      value: '$portfolioViews',
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: _StatCard(
                                      icon: AppIcons.download,
                                      key: const ValueKey('downloads-stat'),
                                      label: context.tr('downloads'),
                                      value: '$downloads',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Row(
                              children: [
                                Text(
                                  context.tr('myCvs'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () => _createCv(userId),
                                  icon: const Icon(AppIcons.add, size: 18),
                                  label: Text(context.tr('add')),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            if (documentsAsync.isLoading && documents.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(AppSpacing.xl),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (documentsAsync.hasError)
                              Card(
                                child: ListTile(
                                  leading: const Icon(AppIcons.errorOutline),
                                  title: Text(context.tr('errorGeneric')),
                                  trailing: TextButton(
                                    onPressed: () => ref.invalidate(
                                      documentsProvider(userId),
                                    ),
                                    child: Text(context.tr('retry')),
                                  ),
                                ),
                              )
                            else if (cvs.isEmpty)
                              _EmptyCard(
                                icon: AppIcons.projects,
                                title: context.tr('noCvs'),
                                body: context.tr('noCvsBody'),
                                actionLabel: context.tr('createCv'),
                                onAction: () => _createCv(userId),
                              )
                            else
                              for (final cv in cvs)
                                _CvTile(
                                  document: cv,
                                  onPreview: () => _preview(cv),
                                  onEdit: () => _edit(cv),
                                  onDuplicate: () => _duplicate(userId, cv),
                                  onDelete: () => _delete(userId, cv),
                                ),
                            const SizedBox(height: AppSpacing.lg),
                            _ProfileStrength(
                              profile: profileAsync.value,
                              onEdit: () => context.push('/profile'),
                            ),
                          ]
                          .map(
                            (child) => child is SizedBox
                                ? child
                                : AppReveal(child: child),
                          )
                          .toList(),
                ),
              ),
            ].map((child) => AppReveal(child: child)).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _createCv(String userId) async {
    await context.push('/wizard');
    if (mounted) ref.invalidate(documentsProvider(userId));
  }

  void _preview(CvDocument document) => context.push('/doc/${document.id}');

  void _edit(CvDocument document) => context.push('/wizard/${document.id}');

  Future<void> _duplicate(String userId, CvDocument source) async {
    final now = DateTime.now().toIso8601String();
    final copy = source.copyWith(
      id: newId(),
      ownerId: userId,
      title: '${source.title} (copy)',
      published: false,
      shareMode: ShareMode.privateDraft,
      publicSlug: () => null,
      accessPasswordHash: () => null,
      version: 1,
      createdAtIso: () => now,
      updatedAtIso: () => now,
    );
    try {
      await ref.read(backendProvider).saveDocument(copy);
      ref.invalidate(documentsProvider(userId));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('saved'))));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('errorGeneric'))));
      }
    }
  }

  Future<void> _delete(String userId, CvDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('deleteCv')),
        content: Text(context.tr('deleteDocumentWarning')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(backendProvider).deleteDocument(document.id, userId);
      ref.invalidate(documentsProvider(userId));
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('errorGeneric'))));
      }
    }
  }
}

/// Greeting header with avatar, notification and settings affordances.
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.name,
    required this.avatarUrl,
    required this.onSettings,
    required this.onProfile,
    required this.onBuild,
    required this.onPortfolio,
  });

  final String? name;
  final String? avatarUrl;
  final VoidCallback onSettings;
  final VoidCallback onProfile;
  final VoidCallback onBuild;
  final VoidCallback onPortfolio;

  @override
  Widget build(BuildContext context) {
    final avatar = avatarUrl?.trim() ?? '';
    final parts = (name ?? '').trim().split(RegExp(r'\s+'));
    final first = parts.isEmpty ? '' : parts.first;
    return Padding(
      padding: AppSpacing.pagePadding(context).copyWith(bottom: 0),
      child: AppHeroSurface(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppInteractive(
                    child: InkWell(
                      onTap: onProfile,
                      borderRadius: BorderRadius.circular(28),
                      child: Tooltip(
                        message: context.tr('profileDetails'),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: AppPalette.accent,
                          backgroundImage: avatar.isNotEmpty
                              ? NetworkImage(avatar)
                              : null,
                          child: avatar.isEmpty
                              ? Text(
                                  first.isEmpty ? '?' : first[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: AppPalette.primaryDark,
                                    fontWeight: AppTypography.semibold,
                                    fontSize: 20,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UiText(
                          '${context.tr('welcomeBack')},',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          first.isEmpty ? context.tr('dashboard') : first,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    child: Hero(
                      tag: 'app-brand-mark',
                      child: Image.asset(
                        kAppLogoAsset,
                        width: 36,
                        height: 36,
                        semanticLabel: kAppDisplayName,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const AppInfoButton(buttonKey: ValueKey('home-app-about')),
                  IconButton(
                    key: const ValueKey('home-settings'),
                    tooltip: context.tr('settings'),
                    icon: const Icon(AppIcons.settings),
                    onPressed: onSettings,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                context.tr('careerChapter'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.compact),
              Text(
                context.tr('atagline'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.compact,
                runSpacing: AppSpacing.compact,
                children: [
                  FilledButton.icon(
                    onPressed: onBuild,
                    icon: const Icon(AppIcons.edit, size: 18),
                    label: Text(context.tr('buildCv')),
                  ),
                  OutlinedButton.icon(
                    onPressed: onPortfolio,
                    icon: const Icon(AppIcons.link, size: 18),
                    label: Text(context.tr('portfolio')),
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

class _ProfileStrength extends StatelessWidget {
  const _ProfileStrength({required this.profile, required this.onEdit});
  final UserProfile? profile;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) {
    final completion = profile == null ? 0 : profileCompletion(profile!);
    return AppGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('profileCompletion'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '$completion%',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: completion / 100),
            duration: AppMotion.reduced(context)
                ? Duration.zero
                : AppMotion.lighting,
            builder: (_, value, _) =>
                LinearProgressIndicator(value: value, minHeight: 8),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(AppIcons.person),
            label: Text(context.tr('profileDetails')),
          ),
        ],
      ),
    );
  }
}

/// A single dashboard statistic.
class _StatCard extends StatelessWidget {
  const _StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: AppSpacing.xs),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

/// One CV row: title, last-updated date, preview, edit and a more menu.
class _CvTile extends StatelessWidget {
  const _CvTile({
    required this.document,
    required this.onPreview,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  final CvDocument document;
  final VoidCallback onPreview;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final updated = prettyDate(
      document.updatedAtIso,
      languageCode: context.languageCode,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 52,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Icon(
                AppIcons.document,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (updated.isNotEmpty)
                    UiText(
                      '${context.tr('lastUpdated')}: $updated',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: context.tr('previewCv'),
              icon: const Icon(AppIcons.preview, size: 20),
              onPressed: onPreview,
            ),
            IconButton(
              tooltip: context.tr('editCv'),
              icon: const Icon(AppIcons.edit, size: 20),
              onPressed: onEdit,
            ),
            PopupMenuButton<String>(
              tooltip: context.tr('moreActions'),
              onSelected: (value) {
                switch (value) {
                  case 'duplicate':
                    onDuplicate();
                  case 'delete':
                    onDelete();
                  case 'preview':
                    onPreview();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'preview',
                  child: Text(context.tr('previewCv')),
                ),
                PopupMenuItem(
                  value: 'duplicate',
                  child: Text(context.tr('duplicateCv')),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    context.tr('deleteCv'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A card for empty/error states with an optional action.
class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              body,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
