export '../../core/widgets/profile_image.dart' show PortfolioImage;
import '../../core/design/app_icons.dart';

import 'package:cv_portfolio_maker/core/l10n/ui_text.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_motion.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/domain/profile_models.dart';

const portfolioInk = Color(0xFF111B30);
const portfolioMuted = Color(0xFF748094);

/// A single responsibility or achievement, distinct from adjacent points.
class PortfolioDescriptionBox extends StatelessWidget {
  const PortfolioDescriptionBox({super.key, required this.item});
  final DescriptionItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: dark ? .06 : .50),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: .16)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (item.label.trim().isNotEmpty) ...[
            Text(
              item.label.trim(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: AppTypography.semibold,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(item.text, style: const TextStyle(fontSize: 14, height: 1.65)),
        ],
      ),
    );
  }
}

class PortfolioCard extends StatelessWidget {
  const PortfolioCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => AppInteractive(
    child: AppGlassCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: padding,
      child: Material(color: Colors.transparent, child: child),
    ),
  );
}

class PortfolioHeading extends StatelessWidget {
  const PortfolioHeading(this.title, this.subtitle, {super.key});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 24, 8, 32),
    child: Column(
      children: [
        UiText(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: AppTypography.semibold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        UiText(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}

class PortfolioEmpty extends StatelessWidget {
  const PortfolioEmpty({
    super.key,
    required this.message,
    this.onEdit,
    this.hidden = false,
  });
  final String message;
  final VoidCallback? onEdit;
  final bool hidden;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          hidden ? AppIcons.hidden : AppIcons.autoAwesome,
          size: 40,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 16),
        UiText(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        if (onEdit != null) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(AppIcons.edit),
            label: const UiText('Edit in CV Builder'),
          ),
        ],
      ],
    ),
  );
}

/// The same widget handles uploaded local media and stored Supabase paths.
/// Its future is retained across tab switches and parent rebuilds.
class PortfolioScroll extends StatelessWidget {
  const PortfolioScroll({
    super.key,
    required this.id,
    required this.children,
    this.embedded = false,
  });
  final String id;
  final List<Widget> children;
  final bool embedded;
  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++)
          AppReveal(index: i, child: children[i]),
      ],
    );
    if (embedded) return content;
    return SingleChildScrollView(
      key: PageStorageKey(id),
      padding: AppSpacing.pagePadding(context).copyWith(bottom: AppSpacing.xxl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.contentWidth),
          child: content,
        ),
      ),
    );
  }
}
