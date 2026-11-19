import '../../core/domain/profile_models.dart';
import '../../core/design/app_icons.dart';
import '../../core/theme/app_tokens.dart';

import 'package:cv_portfolio_maker/core/l10n/ui_text.dart';
import 'package:flutter/material.dart';

import '../../core/design/portfolio_themes.dart';
import '../../core/domain/document_entity.dart';
import '../../core/domain/document_models.dart';
import '../../core/domain/enums.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/render/section_titles.dart';
import 'portfolio_widgets.dart';
import '../../core/widgets/app_motion.dart';

/// Embedded settings tab. All writes are delegated to the shared controller.
class PortfolioSettingsTab extends StatelessWidget {
  const PortfolioSettingsTab({
    super.key,
    required this.document,
    required this.busy,
    required this.shareUrl,
    required this.onSave,
    required this.onPublish,
    required this.onPassword,
    required this.onCopy,
    this.embedded = false,
    this.customSectionTitles = const {},
    this.profile,
  });
  final bool embedded;
  final UserProfile? profile;
  final Map<String, String> customSectionTitles;
  final CvDocument document;
  final bool busy;
  final String? shareUrl;
  final ValueChanged<CvDocument> onSave;
  final ValueChanged<bool> onPublish;
  final ValueChanged<bool> onPassword;
  final VoidCallback onCopy;

  void _sections(List<SectionConfig> sections) => onSave(
    document.copyWith(design: document.design.copyWith(sections: sections)),
  );
  @override
  Widget build(BuildContext context) {
    final sections = document.design.sections
        .where(
          (section) =>
              profile == null ||
              portfolioSectionHasContent(
                section,
                profile!,
                document.includedProjectIds,
              ),
        )
        .toList();
    final protected = document.accessPasswordHash != null;
    final published =
        document.published && document.shareMode == ShareMode.publicLink;
    final accent = Theme.of(context).colorScheme.primary;
    return PortfolioScroll(
      id: 'portfolio-settings',
      embedded: embedded,
      children: [
        const _Label('Color Theme'),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 480 ? 2 : 4;
            final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final theme in portfolioThemes)
                  SizedBox(
                    width: width,
                    child: Semantics(
                      selected: theme.id == document.design.templateId,
                      button: true,
                      label: context.tr(theme.labelKey),
                      child: InkWell(
                        onTap: busy
                            ? null
                            : () => onSave(
                                document.copyWith(
                                  design: document.design.copyWith(
                                    templateId: theme.id,
                                  ),
                                ),
                              ),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: AppMotion.reduced(context)
                              ? Duration.zero
                              : AppMotion.quick,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.id == document.design.templateId
                                  ? accent
                                  : Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                              width: theme.id == document.design.templateId
                                  ? 2
                                  : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: theme.surfaceGradient(
                                    Theme.of(context).brightness,
                                  ),
                                ),
                                child: theme.id == document.design.templateId
                                    ? const Center(
                                        child: Icon(
                                          AppIcons.checkCircle,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      )
                                    : null,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 9,
                                ),
                                child: Text(
                                  context.tr(theme.labelKey),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        const _Label('Section Visibility'),
        Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: UiText(
            context.tr('portfolioVisibilityHint'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
        if (sections.isEmpty) Text(context.tr('portfolioNoSections')),
        if (sections.isNotEmpty)
          PortfolioCard(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final section = sections[index];
                final label = switch (section.kind) {
                  SectionKind.profile => 'Introduction',
                  SectionKind.personalDetails => 'Contact',
                  _ => section.resolvedTitle(
                    (kind) => kind == SectionKind.custom
                        ? customSectionTitles[section.customSectionId] ??
                              context.tr('customEntries')
                        : defaultTitleResolver(context.languageCode)(kind),
                  ),
                };
                return DecoratedBox(
                  key: ValueKey(section.id),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: UiText(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            color: section.visible
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: context.tr(
                          section.visible
                              ? 'hideNamedSection'
                              : 'showNamedSection',
                          args: {'section': context.ui(label)},
                        ),
                        onPressed: busy
                            ? null
                            : () {
                                final updated = [...document.design.sections];
                                final sourceIndex = updated.indexWhere(
                                  (item) => item.id == section.id,
                                );
                                updated[sourceIndex] = section.copyWith(
                                  visible: !section.visible,
                                );
                                _sections(updated);
                              },
                        icon: Icon(
                          section.visible ? AppIcons.preview : AppIcons.hidden,
                          color: section.visible
                              ? accent
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        const _Label('Share Portfolio'),
        PortfolioCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        shareUrl ?? 'No published URL available',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: busy || shareUrl == null ? null : onCopy,
                    icon: const Icon(AppIcons.copy, size: 15),
                    label: const UiText('Copy'),
                  ),
                ],
              ),
              if (shareUrl == null)
                Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: UiText(
                    'Publish with a connected backend and configured share host to enable sharing.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              if (shareUrl != null && protected)
                Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: UiText(
                    'Visitors need your portfolio password. The password is never included in the link.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const _Label('Access Control'),
        PortfolioCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              SwitchListTile.adaptive(
                title: Text(
                  context.tr('sharePublished'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: UiText(
                  published
                      ? (protected
                            ? 'Published · password required'
                            : 'Anyone with the link can view')
                      : 'Unpublished · only you can view',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                value: published,
                onChanged: busy ? null : onPublish,
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                title: const UiText(
                  'Private (Password)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: UiText(
                  protected
                      ? 'Password verified by your repository'
                      : 'Require a password to access',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                value: protected,
                onChanged: busy ? null : onPassword,
              ),
              if (protected)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: TextButton.icon(
                      onPressed: busy ? null : () => onPassword(true),
                      icon: const Icon(AppIcons.lockReset, size: 18),
                      label: const UiText('Change password'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: UiText(
      text,
      style: const TextStyle(fontWeight: AppTypography.semibold, fontSize: 15),
    ),
  );
}

/// Inspect saved content independently of current visibility, so a hidden
/// populated section stays available to turn back on.
bool portfolioSectionHasContent(
  SectionConfig section,
  UserProfile profile,
  List<String>? projectIds,
) => switch (section.kind) {
  SectionKind.personalDetails => [
    profile.details.fullName,
    profile.details.email,
    profile.details.phone,
    profile.details.location,
    profile.details.website,
    ...profile.details.links,
  ].any((s) => s?.trim().isNotEmpty ?? false),
  SectionKind.profile => profile.details.summary?.trim().isNotEmpty ?? false,
  SectionKind.experience => profile.experiences.isNotEmpty,
  SectionKind.education => profile.education.isNotEmpty,
  SectionKind.projects => profile.projects.any(
    (p) => projectIds == null || projectIds.contains(p.id),
  ),
  SectionKind.skills => profile.skills.isNotEmpty,
  SectionKind.languages => profile.languages.isNotEmpty,
  SectionKind.certificates => profile.certificates.isNotEmpty,
  SectionKind.courses => profile.courses.isNotEmpty,
  SectionKind.awards => profile.awards.isNotEmpty,
  SectionKind.volunteer => profile.volunteer.isNotEmpty,
  SectionKind.publications => profile.publications.isNotEmpty,
  SectionKind.references => profile.references.isNotEmpty,
  SectionKind.custom => profile.customSections.any(
    (s) => s.id == section.customSectionId && s.entries.isNotEmpty,
  ),
  SectionKind.pageBreak => false,
};
