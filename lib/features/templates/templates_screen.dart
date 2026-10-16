import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cv_portfolio_maker/app/providers.dart';
import 'package:cv_portfolio_maker/app/session.dart';
import 'package:cv_portfolio_maker/core/design/templates.dart';
import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/l10n/app_strings.dart';
import 'package:cv_portfolio_maker/core/theme/app_tokens.dart';
import 'package:cv_portfolio_maker/core/utils/utils.dart';

/// Browse the built-in template catalogue and start a document from one.
class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('templates'))),
      body: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 320,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.4,
        ),
        itemCount: builtinTemplates.length,
        itemBuilder: (context, index) {
          final template = builtinTemplates[index];
          return _TemplateCard(
            template: template,
            onTap: () => _useTemplate(context, ref, template),
          );
        },
      ),
    );
  }

  Future<void> _useTemplate(
    BuildContext context,
    WidgetRef ref,
    DesignTemplate template,
  ) async {
    final type = await showDialog<DocumentType>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(template.name),
        content: Text(template.description),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(DocumentType.cv),
            child: Text(context.tr('cv')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(DocumentType.portfolio),
            child: Text(context.tr('portfolio')),
          ),
        ],
      ),
    );
    if (type == null) return;
    if (!context.mounted) return;

    final user = ref.read(sessionProvider2).value;
    if (user == null) return;

    final now = DateTime.now().toIso8601String();
    final document = CvDocument(
      id: newId(),
      ownerId: user.id,
      title: type == DocumentType.cv
          ? context.tr('cv')
          : context.tr('portfolio'),
      type: type,
      design: template.build(type),
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
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.onTap});

  final DesignTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                template.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: Text(
                  template.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
