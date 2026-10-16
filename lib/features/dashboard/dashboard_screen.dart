import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cv_portfolio_maker/app/providers.dart';
import 'package:cv_portfolio_maker/app/session.dart';
import 'package:cv_portfolio_maker/core/design/templates.dart';
import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/l10n/app_strings.dart';
import 'package:cv_portfolio_maker/core/theme/app_tokens.dart';
import 'package:cv_portfolio_maker/core/utils/utils.dart';

/// Landing screen for authenticated users: documents overview and creation.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider2).value;
    final userId = user?.id;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('dashboard'))),
      body: userId == null
          ? const Center(child: CircularProgressIndicator())
          : _DashboardBody(userId: userId),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(documentsProvider(userId));
    final profile = ref.watch(profileProvider(userId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(documentsProvider);
        ref.invalidate(profileProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _CompletionHeader(profile: profile.value),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      _create(context, ref, userId, DocumentType.cv),
                  icon: const Icon(Icons.add),
                  label: Text(context.tr('createCv')),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () =>
                      _create(context, ref, userId, DocumentType.portfolio),
                  icon: const Icon(Icons.add),
                  label: Text(context.tr('createPortfolio')),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.tr('myDocuments'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          documents.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Center(child: Text(context.tr('errorGeneric'))),
            ),
            data: (list) => list.isEmpty
                ? const _EmptyState()
                : Column(
                    children: [
                      for (final doc in list)
                        _DocumentTile(
                          document: doc,
                          onTap: () => context.go('/doc/${doc.id}'),
                          onDelete: () => _delete(context, ref, userId, doc),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _create(
    BuildContext context,
    WidgetRef ref,
    String userId,
    DocumentType type,
  ) async {
    final now = DateTime.now().toIso8601String();
    final document = CvDocument(
      id: newId(),
      ownerId: userId,
      title: type == DocumentType.cv
          ? context.tr('cv')
          : context.tr('portfolio'),
      type: type,
      design: designForTemplate('minimal', type),
      createdAtIso: now,
      updatedAtIso: now,
    );

    try {
      await ref.read(backendProvider).saveDocument(document);
      ref.invalidate(documentsProvider);
      if (context.mounted) context.go('/doc/${document.id}');
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('errorGeneric'))));
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    String userId,
    CvDocument document,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('delete')),
        content: Text(context.tr('deleteDocumentWarning')),
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

    await ref.read(backendProvider).deleteDocument(document.id, userId);
    ref.invalidate(documentsProvider);
  }
}

class _CompletionHeader extends StatelessWidget {
  const _CompletionHeader({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final completion = profile == null ? 0 : profileCompletion(profile!);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('welcomeBack'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.tr('profileCompletion'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            LinearProgressIndicator(value: completion / 100),
            const SizedBox(height: AppSpacing.xs),
            Text('$completion%', style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.tr('noDocumentsTitle'),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.tr('noDocumentsBody'),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.document,
    required this.onTap,
    required this.onDelete,
  });

  final CvDocument document;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isPortfolio = document.type == DocumentType.portfolio;
    return Card(
      child: ListTile(
        leading: Icon(
          isPortfolio ? Icons.folder_outlined : Icons.description_outlined,
        ),
        title: Text(document.title),
        subtitle: Text(
          isPortfolio ? context.tr('portfolio') : context.tr('cv'),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
        onTap: onTap,
      ),
    );
  }
}
