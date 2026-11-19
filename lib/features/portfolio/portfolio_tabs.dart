import '../../core/design/app_icons.dart';

import 'package:cv_portfolio_maker/core/l10n/ui_text.dart';
import 'package:cv_portfolio_maker/core/l10n/app_strings.dart';
import 'package:flutter/material.dart';

import '../../core/domain/document_entity.dart';
import '../../core/domain/document_models.dart';
import '../../core/domain/enums.dart';
import '../../core/domain/profile_models.dart';
import '../../core/render/resolved_document.dart';
import '../../core/render/section_titles.dart';
import '../../core/design/skill_icons.dart';
import 'portfolio_project_media.dart';
import 'portfolio_contacts.dart';
import '../../core/utils/input_validation.dart';
import 'portfolio_controller.dart';
import 'portfolio_widgets.dart';
import 'portfolio_navigation.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/description_items_editor.dart';
import '../../core/theme/app_tokens.dart';

class PortfolioAboutTab extends StatelessWidget {
  const PortfolioAboutTab({
    super.key,
    required this.profile,
    required this.document,
    required this.resolved,
    required this.onWork,
    required this.onOpen,
    required this.onEdit,
    required this.onDownload,
    this.editable = true,
    this.showDownload = true,
    this.showWork = true,
  });
  final UserProfile profile;
  final CvDocument document;
  final ResolvedDocument resolved;
  final VoidCallback onWork;
  final VoidCallback onEdit;
  final VoidCallback onDownload;
  final bool editable;
  final bool showDownload;
  final bool showWork;
  final ValueChanged<Uri> onOpen;

  @override
  Widget build(BuildContext context) {
    final details = profile.details;
    final accent = Theme.of(context).colorScheme.primary;
    final avatarAccent = Color.lerp(accent, AppPalette.ice, .70)!;
    final intro =
        document.design.sectionOf(SectionKind.profile)?.visible ?? true;
    final contact =
        document.design.sectionOf(SectionKind.personalDetails)?.visible ?? true;
    final name = details.fullName?.trim() ?? '';
    final words = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final initials = words.isEmpty
        ? '?'
        : (words.first.characters.first +
                  (words.length > 1 ? words.last.characters.first : ''))
              .toUpperCase();
    final email = details.email?.trim() ?? '';
    final validEmail = email.isNotEmpty && InputValidation.email(email) == null;
    final actions = portfolioContacts(details);
    final remainingContacts = resolved.contacts
        .where(
          (item) =>
              !contactShownAsIcon(item.value, actions) &&
              !['Link', 'Website'].contains(item.label),
        )
        .toList();
    final content = PortfolioContent(resolved, profile);
    Widget contacts() => Column(
      children: [
        PortfolioContactActions(actions: actions, onOpen: onOpen),
        for (final item in remainingContacts)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item.label == 'Location' ? AppIcons.location : AppIcons.phone,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(child: Text(item.value, textAlign: TextAlign.center)),
              ],
            ),
          ),
      ],
    );
    return PortfolioScroll(
      id: 'portfolio-about',
      children: [
        if (intro)
          AppHeroSurface(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xl,
            ),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: .18),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: PortfolioImage(
                      source: details.avatarUrl,
                      ownerId: profile.id,
                      fallback: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              avatarAccent,
                              Color.lerp(avatarAccent, AppPalette.accent, .6)!,
                            ],
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: AppPalette.primaryDark,
                            fontWeight: AppTypography.semibold,
                            fontSize: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: context.ui("Hi, I'm ")),
                      TextSpan(
                        text: name.isEmpty ? context.ui('Your name') : name,
                        style: TextStyle(color: accent),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: AppTypography.semibold,
                    height: 1.3,
                  ),
                ),
                if ((details.professionalTitle ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    details.professionalTitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 15,
                    ),
                  ),
                ],
                if (resolved.summary.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    resolved.summary,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.65,
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (contact && validEmail)
                      FilledButton(
                        onPressed: () =>
                            onOpen(Uri(scheme: 'mailto', path: email)),
                        child: const UiText('Get In Touch'),
                      ),
                    if (showWork)
                      OutlinedButton(
                        onPressed: onWork,
                        child: const UiText('View Work'),
                      ),
                  ],
                ),
                if (contact) ...[const SizedBox(height: 16), contacts()],
              ],
            ),
          ),
        if (intro) const SizedBox(height: AppSpacing.lg),
        if (!intro && contact) AppHeroSurface(child: contacts()),
        for (final section in content.sections(PortfolioPage.about))
          _AdditionalSection(
            section: section,
            ownerId: profile.id,
            onOpen: onOpen,
          ),
      ],
    );
  }
}

class _AdditionalSection extends StatelessWidget {
  const _AdditionalSection({
    required this.section,
    required this.ownerId,
    required this.onOpen,
  });
  final ResolvedSection section;
  final String ownerId;
  final ValueChanged<Uri> onOpen;
  @override
  Widget build(BuildContext context) {
    final lines = <(String, String)>[
      for (final e in section.education.where((e) => e.visible))
        (
          [e.qualification, e.fieldOfStudy].whereType<String>().join(' · '),
          [
            e.institution,
            e.dateRange.format(languageCode: context.languageCode),
            e.description,
          ].whereType<String>().where((s) => s.isNotEmpty).join('\n'),
        ),
      for (final e in section.languages.where((e) => e.visible))
        (
          e.name,
          proficiencyLabel(e.proficiency, languageCode: context.languageCode),
        ),
      for (final e in section.awards.where((e) => e.visible))
        (e.name ?? '', e.description ?? ''),
      for (final e in section.volunteer.where((e) => e.visible))
        (
          e.role ?? '',
          [e.organization, ...e.descriptions].whereType<String>().join('\n'),
        ),
      for (final e in section.publications.where((e) => e.visible))
        (e.title ?? '', e.venue ?? ''),
      for (final e in section.references.where((e) => e.visible))
        (e.name ?? '', e.notes ?? ''),
    ];
    final structured = [
      ...section.customEntries,
      for (final e in section.certificates)
        CustomEntry(
          id: e.id,
          title: e.name,
          issuer: e.issuer,
          dateRange: e.dateRange,
          credentialId: e.credentialId,
          url: e.credentialUrl,
        ),
      for (final e in section.courses)
        CustomEntry(
          id: e.id,
          title: e.name ?? '',
          issuer: e.institution,
          dateRange: e.dateRange,
          url: e.credentialUrl,
        ),
    ];
    if (lines.isEmpty && structured.isEmpty && section.experiences.isEmpty) {
      return const SizedBox.shrink();
    }
    return PortfolioCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: AppTypography.semibold,
            ),
          ),
          for (final experience in section.experiences.where((e) => e.visible))
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    experience.position ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    [
                          experience.company,
                          experience.dateRange.format(
                            languageCode: context.languageCode,
                          ),
                        ]
                        .whereType<String>()
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                  ),
                  for (final item in experience.resolvedDescriptions)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: PortfolioDescriptionBox(item: item),
                    ),
                ],
              ),
            ),
          for (final entry in structured)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (entry
                      .formatMetadata(languageCode: context.languageCode)
                      .isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      entry.formatMetadata(languageCode: context.languageCode),
                    ),
                  ],
                  if ((entry.content ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(entry.content!),
                  ],
                  if ((entry.imageUrl ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: SizedBox(
                        height: 180,
                        child: PortfolioImage(
                          source: entry.imageUrl,
                          ownerId: ownerId,
                          fit: BoxFit.contain,
                          fallback: const Icon(AppIcons.image),
                        ),
                      ),
                    ),
                  if (portfolioWebUri(entry.url) case final Uri uri)
                    TextButton.icon(
                      onPressed: () => onOpen(uri),
                      icon: const Icon(AppIcons.link),
                      label: Text(entry.url!),
                    ),
                ],
              ),
            ),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.$1,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (line.$2.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      line.$2,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class PortfolioPageView extends StatelessWidget {
  const PortfolioPageView({
    super.key,
    required this.page,
    required this.content,
    required this.onWork,
    required this.onOpen,
    required this.onEdit,
    required this.onDownload,
    this.editable = true,
    this.showDownload = true,
    this.active = true,
  });
  final PortfolioPage page;
  final PortfolioContent content;
  final VoidCallback onWork, onEdit, onDownload;
  final ValueChanged<Uri> onOpen;
  final bool editable, showDownload, active;
  @override
  Widget build(BuildContext context) => switch (page) {
    PortfolioPage.about => PortfolioAboutTab(
      profile: content.profile,
      document: content.resolved.document,
      resolved: content.resolved,
      onWork: onWork,
      onOpen: onOpen,
      onEdit: onEdit,
      onDownload: onDownload,
      editable: editable,
      showDownload: showDownload,
      showWork: content.pages.contains(PortfolioPage.projects),
    ),
    PortfolioPage.projects => PortfolioProjectsTab(
      projects: content.sections(page).expand((s) => s.projects).toList(),
      ownerId: content.profile.id,
      hidden: false,
      onEdit: editable ? onEdit : null,
      onOpen: onOpen,
      active: active,
      customSections: content
          .sections(page)
          .where((s) => s.customEntries.isNotEmpty)
          .toList(),
    ),
    PortfolioPage.skills => PortfolioSkillsTab(
      skills: content.sections(page).expand((s) => s.skills).toList(),
      hidden: false,
      onEdit: editable ? onEdit : null,
    ),
    _ => PortfolioSectionsTab(
      id: 'portfolio-${page.name}',
      sections: content.sections(page),
      ownerId: content.profile.id,
      onOpen: onOpen,
    ),
  };
}

class PortfolioSectionsTab extends StatelessWidget {
  const PortfolioSectionsTab({
    super.key,
    required this.id,
    required this.sections,
    required this.ownerId,
    required this.onOpen,
  });
  final String id, ownerId;
  final List<ResolvedSection> sections;
  final ValueChanged<Uri> onOpen;
  @override
  Widget build(BuildContext context) => PortfolioScroll(
    id: id,
    children: [
      for (final section in sections)
        _AdditionalSection(section: section, ownerId: ownerId, onOpen: onOpen),
    ],
  );
}

class PortfolioProjectsTab extends StatelessWidget {
  const PortfolioProjectsTab({
    super.key,
    required this.projects,
    required this.ownerId,
    required this.hidden,
    required this.onEdit,
    required this.onOpen,
    this.active = true,
    this.customSections = const [],
  });
  final bool active;
  final List<ResolvedSection> customSections;
  final List<ProjectEntry> projects;
  final String ownerId;
  final bool hidden;
  final VoidCallback? onEdit;
  final ValueChanged<Uri> onOpen;
  @override
  Widget build(BuildContext context) => PortfolioScroll(
    id: 'portfolio-projects',
    children: [
      const PortfolioHeading(
        'Featured Projects',
        'A selection of my recent work and personal projects',
      ),
      if (hidden)
        const PortfolioEmpty(
          message: 'Projects are hidden. Show this section in Settings.',
          hidden: true,
        )
      else if (projects.isEmpty && customSections.isEmpty)
        PortfolioEmpty(
          message: onEdit == null ? 'No projects to show yet.' : 'Your next great project belongs here. Add your work to your CV to showcase it.',
          onEdit: onEdit,
        )
      else
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 2 : 1;
            final width =
                (constraints.maxWidth - AppSpacing.lg * (columns - 1)) /
                columns;
            return Wrap(
              spacing: AppSpacing.lg,
              runSpacing: 0,
              children: [
                for (final project in projects)
                  SizedBox(
                    width: width,
                    child: PortfolioProjectCard(
                      key: ValueKey(project.id),
                      project: project,
                      ownerId: ownerId,
                      onOpen: onOpen,
                      active: active,
                    ),
                  ),
              ],
            );
          },
        ),
      if (!hidden)
        for (final section in customSections)
          _AdditionalSection(
            section: section,
            ownerId: ownerId,
            onOpen: onOpen,
          ),
    ],
  );
}

class PortfolioProjectCard extends StatelessWidget {
  const PortfolioProjectCard({
    super.key,
    this.active = true,
    required this.project,
    required this.ownerId,
    required this.onOpen,
  });
  final bool active;
  final ProjectEntry project;
  final String ownerId;
  final ValueChanged<Uri> onOpen;
  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final demo =
        portfolioWebUri(project.demoUrl) ?? portfolioWebUri(project.websiteUrl);
    final code = portfolioWebUri(project.sourceUrl);
    final github = code?.host == 'github.com' || code?.host == 'www.github.com';
    return PortfolioCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PortfolioProjectMedia(
            source: project.media.isEmpty ? null : project.media.first,
            ownerId: ownerId,
            active: active,
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.title?.trim().isNotEmpty == true
                      ? project.title!
                      : context.ui('Untitled project'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: AppTypography.semibold,
                  ),
                ),
                if (!project.dateRange.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      project.dateRange.format(
                        languageCode: context.languageCode,
                      ),
                    ),
                  ),
                if ((project.summary ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    project.summary!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
                for (final item in project.resolvedDescriptions)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: DescriptionItemText(item: item),
                  ),
                if (project.technologies.any((t) => t.trim().isNotEmpty)) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 7,
                    children: [
                      for (final tech in project.technologies.where(
                        (t) => t.trim().isNotEmpty,
                      ))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: .09),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            tech,
                            style: TextStyle(color: accent, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ],
                if (demo != null || code != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    children: [
                      if (demo != null)
                        TextButton.icon(
                          onPressed: () => onOpen(demo),
                          onLongPress: () =>
                              copyPortfolioValue(context, demo.toString()),
                          icon: const Icon(AppIcons.link, size: 16),
                          label: const UiText('Live Demo'),
                        ),
                      if (code != null)
                        TextButton.icon(
                          onPressed: () => onOpen(code),
                          onLongPress: () =>
                              copyPortfolioValue(context, code.toString()),
                          icon: Icon(
                            github
                                ? const IconData(
                                    0xf09b,
                                    fontFamily: 'CvBrandIcons',
                                  )
                                : AppIcons.code,
                            size: 20,
                          ),
                          label: UiText(github ? 'GitHub' : 'Code'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PortfolioSkillsTab extends StatelessWidget {
  const PortfolioSkillsTab({
    super.key,
    required this.skills,
    required this.hidden,
    required this.onEdit,
  });
  final List<SkillEntry> skills;
  final bool hidden;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) {
    final visibleSkills = skills
        .where((s) => s.visible && (s.name ?? '').trim().isNotEmpty)
        .toList();
    return PortfolioScroll(
      id: 'portfolio-skills',
      children: [
        const PortfolioHeading(
          'Skills & Expertise',
          'Technologies and tools I use to bring ideas to life',
        ),
        if (hidden)
          const PortfolioEmpty(
            message: 'Skills are hidden. Show this section in Settings.',
            hidden: true,
          )
        else if (visibleSkills.isEmpty)
          PortfolioEmpty(
            message: onEdit == null
                ? 'No skills to show yet.'
                : 'Show what you do best. Add your skills in CV Builder.',
            onEdit: onEdit,
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 3
                  : constraints.maxWidth >= 600
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - AppSpacing.lg * (columns - 1)) /
                  columns;
              return Wrap(
                spacing: AppSpacing.lg,
                runSpacing: 0,
                children: [
                  for (final skill in visibleSkills)
                    SizedBox(
                      width: width,
                      child: PortfolioSkillCard(
                        key: ValueKey(skill.id),
                        skill: skill,
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class PortfolioSkillCard extends StatelessWidget {
  const PortfolioSkillCard({super.key, required this.skill});
  final SkillEntry skill;
  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final category = skill.category.trim();
    return PortfolioCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SkillIconView(skill.iconId, color: accent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skill.name ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: AppTypography.semibold,
                  ),
                ),
                if (category.isNotEmpty && category.toLowerCase() != 'general')
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (proficiencyLabel(
                  skill.proficiency,
                  languageCode: context.languageCode,
                ).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Text(
                      proficiencyLabel(
                        skill.proficiency,
                        languageCode: context.languageCode,
                      ),
                      style: TextStyle(color: accent, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
