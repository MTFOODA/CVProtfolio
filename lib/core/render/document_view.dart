import 'package:flutter/material.dart';

import 'package:cv_portfolio_maker/core/domain/document_models.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/render/document_layout.dart';
import 'package:cv_portfolio_maker/core/render/resolved_document.dart';
import 'package:cv_portfolio_maker/core/render/section_titles.dart';

/// A reusable, design-aware renderer for a [ResolvedDocument].
///
/// This is the single rendering implementation shared by the editor preview and
/// the public viewer. It honours the document's [DocumentDesign] (columns,
/// typography, colours, spacing, presentation) so every surface shows the same
/// result. Future PDF/DOCX exporters consume the same [ResolvedDocument] and
/// [DocumentDesign] data, never this widget.
class DocumentView extends StatelessWidget {
  const DocumentView({super.key, required this.resolved});

  final ResolvedDocument resolved;

  @override
  Widget build(BuildContext context) {
    final design = resolved.design;
    final colors = design.colors;
    final typography = design.typography;
    final spacing = design.spacing;
    final presentation = design.presentation;

    final headingColor = Color(colors.headingText);
    final bodyColor = Color(colors.bodyText);
    final dividerColor = Color(colors.divider);

    final bodyStyle = TextStyle(
      fontFamily: typography.bodyFont,
      fontSize: typography.bodyFontSize,
      height: typography.bodyLineHeight,
      color: bodyColor,
    );

    return Container(
      color: Color(colors.paper),
      padding: EdgeInsets.all(spacing.pageMargin + spacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DocumentHeader(resolved: resolved, bodyStyle: bodyStyle),
          if (resolved.summary.isNotEmpty) ...[
            SizedBox(height: spacing.sectionSpacing),
            Text(
              resolved.summary,
              style: bodyStyle.copyWith(height: typography.bodyLineHeight),
            ),
          ],
          ..._buildBody(
            design: design,
            colors: colors,
            typography: typography,
            spacing: spacing,
            presentation: presentation,
            bodyStyle: bodyStyle,
            headingColor: headingColor,
            dividerColor: dividerColor,
          ),
        ],
      ),
    );
  }

  /// Arranges the section bands according to the layout mode.
  ///
  /// * `One`   – a single reading order; column slots are ignored.
  /// * `Two`   – exactly two columns; full-width slots fall back to the left.
  /// * `Mix`   – full-width bands interleaved with column bands, in order.
  List<Widget> _buildBody({
    required DocumentDesign design,
    required ColorConfig colors,
    required TypographyConfig typography,
    required SpacingConfig spacing,
    required PresentationConfig presentation,
    required TextStyle bodyStyle,
    required Color headingColor,
    required Color dividerColor,
  }) {
    Widget sectionColumn(List<ResolvedSection> sections) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final section in sections)
            _DocumentSection(
              section: section,
              colors: colors,
              typography: typography,
              spacing: spacing,
              presentation: presentation,
              bodyStyle: bodyStyle,
              headingColor: headingColor,
              dividerColor: dividerColor,
            ),
        ],
      );
    }

    // Ratio is clamped so neither column can become unusably narrow.
    final ratio = clampColumnRatio(spacing.leftColumnRatio);

    Widget columnsRow(List<ResolvedSection> left, List<ResolvedSection> right) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: (ratio * 100).round(), child: sectionColumn(left)),
          SizedBox(width: spacing.columnGap),
          Expanded(
            flex: ((1 - ratio) * 100).round(),
            child: sectionColumn(right),
          ),
        ],
      );
    }

    switch (design.layoutMode) {
      case LayoutMode.one:
        // Single reading order; column slots are ignored.
        return [sectionColumn(resolved.sections)];

      case LayoutMode.two:
        final buckets = twoColumnBuckets(resolved.sections);
        if (!buckets.hasColumns) return [sectionColumn(resolved.sections)];
        return [columnsRow(buckets.left, buckets.right)];

      case LayoutMode.mix:
        // Full-width sections keep their reading-order position instead of
        // being hoisted above the columns (that is what distinguishes Mix).
        return [
          for (final row in buildMixRows(resolved.sections))
            if (row.isFullWidth)
              sectionColumn(row.full)
            else
              columnsRow(row.left, row.right),
        ];
    }
  }
}

/// Renders the document header (name, title, contacts, optional avatar).
class _DocumentHeader extends StatelessWidget {
  const _DocumentHeader({required this.resolved, required this.bodyStyle});

  final ResolvedDocument resolved;
  final TextStyle bodyStyle;

  @override
  Widget build(BuildContext context) {
    final details = resolved.details;
    final pres = resolved.design.presentation;
    final colors = resolved.design.colors;
    final typography = resolved.design.typography;

    final name = details.fullName ?? '';
    final title = details.professionalTitle ?? '';
    final headingColor = Color(colors.headingText);

    final nameStyle = TextStyle(
      fontFamily: typography.headingFont,
      fontSize: typography.headingFontSize * typography.headingScale,
      height: typography.headingLineHeight,
      fontWeight: FontWeight.w700,
      color: headingColor,
    );
    final titleStyle = bodyStyle.copyWith(
      fontFamily: typography.headingFont,
      fontSize: typography.bodyFontSize * typography.headingScale + 1,
      fontWeight: FontWeight.w600,
      color: Color(colors.secondary),
    );

    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (name.isNotEmpty) Text(name, style: nameStyle),
        if (title.isNotEmpty) Text(title, style: titleStyle),
      ],
    );

    final avatar = _buildAvatar(context, details);
    final contactBlock = _ContactBlock(
      contacts: resolved.contacts,
      presentation: pres,
      textStyle: bodyStyle.copyWith(color: Color(colors.bodyText)),
    );

    switch (pres.headerStyle) {
      case 'center':
        return Column(
          children: [
            avatar,
            identity,
            if (resolved.contacts.isNotEmpty) ...[
              const SizedBox(height: 8),
              contactBlock,
            ],
          ],
        );
      case 'split':
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(child: identity),
            if (resolved.contacts.isNotEmpty) contactBlock,
          ],
        );
      case 'left':
      default:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  identity,
                  if (resolved.contacts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    contactBlock,
                  ],
                ],
              ),
            ),
          ],
        );
    }
  }

  Widget _buildAvatar(BuildContext context, ProfileDetails details) {
    final pres = resolved.design.presentation;
    final url = details.avatarUrl;
    if (pres.avatarShape == AvatarShape.hidden || url == null || url.isEmpty) {
      return const SizedBox.shrink();
    }
    final size = pres.avatarSize;
    return ClipRRect(
      borderRadius: _avatarRadius(pres.avatarShape),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          color: Color(resolved.design.colors.secondary),
          child: Icon(Icons.person, size: size * 0.6, color: Colors.white),
        ),
      ),
    );
  }

  BorderRadius _avatarRadius(AvatarShape shape) {
    switch (shape) {
      case AvatarShape.circle:
        return BorderRadius.circular(1000);
      case AvatarShape.roundedSquare:
        return BorderRadius.circular(12);
      case AvatarShape.square:
      case AvatarShape.hidden:
        return BorderRadius.zero;
    }
  }
}

class _ContactBlock extends StatelessWidget {
  const _ContactBlock({
    required this.contacts,
    required this.presentation,
    required this.textStyle,
  });

  final List<ResolvedContact> contacts;
  final PresentationConfig presentation;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    if (presentation.contactInline) {
      return Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final c in contacts)
            Text('${c.label}: ${c.value}', style: textStyle),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in contacts)
          Text('${c.label}: ${c.value}', style: textStyle),
      ],
    );
  }
}

/// Renders a single section: heading, divider and its entries.
class _DocumentSection extends StatelessWidget {
  const _DocumentSection({
    required this.section,
    required this.colors,
    required this.typography,
    required this.spacing,
    required this.presentation,
    required this.bodyStyle,
    required this.headingColor,
    required this.dividerColor,
  });

  final ResolvedSection section;
  final ColorConfig colors;
  final TypographyConfig typography;
  final SpacingConfig spacing;
  final PresentationConfig presentation;
  final TextStyle bodyStyle;
  final Color headingColor;
  final Color dividerColor;

  @override
  Widget build(BuildContext context) {
    if (section.isPageBreak) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.sectionSpacing),
        child: _PageBreakMarker(color: dividerColor),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.sectionSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            title: typography.uppercaseSectionTitles
                ? section.title.toUpperCase()
                : section.title,
            kind: section.config.kind,
            typography: typography,
            presentation: presentation,
            headingColor: headingColor,
            accentColor: Color(colors.accent),
          ),
          _buildDivider(),
          SizedBox(height: spacing.itemSpacing),
          ..._buildEntries(context),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    switch (presentation.dividerStyle) {
      case DividerStyle.none:
        return const SizedBox.shrink();
      case DividerStyle.thin:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Divider(height: 1, thickness: 1, color: dividerColor),
        );
      case DividerStyle.thick:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Divider(height: 3, thickness: 3, color: dividerColor),
        );
      case DividerStyle.dotted:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (var i = 0; i < 40; i++)
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: dividerColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        );
      case DividerStyle.gradient:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [dividerColor, Color(colors.accent), dividerColor],
              ),
            ),
          ),
        );
    }
  }

  List<Widget> _buildEntries(BuildContext context) {
    switch (section.config.kind) {
      case SectionKind.experience:
        return [for (final e in section.experiences) _experience(context, e)];
      case SectionKind.education:
        return [for (final e in section.education) _education(context, e)];
      case SectionKind.skills:
        return [
          _chips(
            context,
            section.skills.map((s) => _label(s.name, s.proficiency)),
          ),
        ];
      case SectionKind.languages:
        return [
          _chips(
            context,
            section.languages.map((l) => _label(l.name, l.proficiency)),
          ),
        ];
      case SectionKind.certificates:
        return [for (final e in section.certificates) _certificate(context, e)];
      case SectionKind.courses:
        return [for (final e in section.courses) _course(context, e)];
      case SectionKind.awards:
        return [for (final e in section.awards) _award(context, e)];
      case SectionKind.volunteer:
        return [for (final e in section.volunteer) _volunteer(context, e)];
      case SectionKind.publications:
        return [for (final e in section.publications) _publication(context, e)];
      case SectionKind.references:
        return [for (final e in section.references) _reference(context, e)];
      case SectionKind.projects:
        return [
          _ProjectSection(
            section: section,
            spacing: spacing,
            bodyStyle: bodyStyle,
            accent: Color(colors.accent),
            presentation: presentation,
          ),
        ];
      case SectionKind.custom:
        return [for (final e in section.customEntries) _custom(context, e)];
      case SectionKind.profile:
      case SectionKind.personalDetails:
      case SectionKind.pageBreak:
        return const [];
    }
  }

  String _label(String? name, int? proficiency) {
    final level = proficiencyLabel(proficiency);
    final base = name ?? '';
    return level.isEmpty ? base : '$base · $level';
  }

  Widget _experience(BuildContext c, ExperienceEntry e) => _Entry(
    title: _join([e.position, e.company]),
    meta: e.dateRange.format(),
    lines: e.descriptions,
    bodyStyle: bodyStyle,
    accent: Color(colors.accent),
    spacing: spacing,
  );

  Widget _education(BuildContext c, EducationEntry e) => _Entry(
    title: _join([e.qualification, e.institution]),
    meta: _join([e.fieldOfStudy, e.dateRange.format()]),
    lines: [
      if (e.grade != null && e.grade!.isNotEmpty) e.grade!,
      if (e.description != null && e.description!.isNotEmpty) e.description!,
    ],
    bodyStyle: bodyStyle,
    accent: Color(colors.accent),
    spacing: spacing,
  );

  Widget _certificate(BuildContext c, CertificateEntry e) => _Entry(
    title: e.name,
    meta: _join([e.issuer, e.dateRange.format()]),
    bodyStyle: bodyStyle,
    accent: Color(colors.accent),
    spacing: spacing,
  );

  Widget _course(BuildContext c, CourseEntry e) => _Entry(
    title: e.name ?? '',
    meta: _join([e.institution, e.dateRange.format()]),
    bodyStyle: bodyStyle,
    accent: Color(colors.accent),
    spacing: spacing,
  );

  Widget _award(BuildContext c, AwardEntry e) => _Entry(
    title: e.name ?? '',
    meta: _join([e.issuer, e.dateRange.format()]),
    lines: [
      if (e.description != null && e.description!.isNotEmpty) e.description!,
    ],
    bodyStyle: bodyStyle,
    accent: Color(colors.accent),
    spacing: spacing,
  );

  Widget _volunteer(BuildContext c, VolunteerEntry e) => _Entry(
    title: _join([e.role, e.organization]),
    meta: _join([e.location, e.dateRange.format()]),
    lines: e.descriptions,
    bodyStyle: bodyStyle,
    accent: Color(colors.accent),
    spacing: spacing,
  );

  Widget _publication(BuildContext c, PublicationEntry e) => _Entry(
    title: e.title ?? '',
    meta: _join([e.venue, e.dateRange.format()]),
    bodyStyle: bodyStyle,
    accent: Color(colors.accent),
    spacing: spacing,
  );

  Widget _reference(BuildContext c, ReferenceEntry e) => _Entry(
    title: e.name ?? '',
    meta: e.relationship ?? '',
    lines: [if (e.notes != null && e.notes!.isNotEmpty) e.notes!],
    bodyStyle: bodyStyle,
    accent: Color(colors.accent),
    spacing: spacing,
  );

  Widget _custom(BuildContext c, CustomEntry e) => _Entry(
    title: e.title,
    lines: [if (e.content != null && e.content!.isNotEmpty) e.content!],
    bodyStyle: bodyStyle,
    accent: Color(colors.accent),
    spacing: spacing,
  );

  Widget _chips(BuildContext c, Iterable<String> labels) {
    final visible = labels.where((l) => l.isNotEmpty).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: spacing.itemSpacing,
      runSpacing: spacing.itemSpacing,
      children: [
        for (final label in visible)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Color(colors.accent).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: bodyStyle.copyWith(color: Color(colors.accent)),
            ),
          ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.kind,
    required this.typography,
    required this.presentation,
    required this.headingColor,
    required this.accentColor,
  });

  final String title;
  final SectionKind kind;
  final TypographyConfig typography;
  final PresentationConfig presentation;
  final Color headingColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: typography.headingFont,
      fontSize: typography.sectionTitleFontSize * typography.headingScale,
      fontWeight: FontWeight.w700,
      letterSpacing: typography.headingLetterSpacing,
      color: headingColor,
    );
    if (presentation.showSectionIcons) {
      return Row(
        children: [
          Icon(_sectionIcon(kind), size: style.fontSize, color: accentColor),
          const SizedBox(width: 6),
          Expanded(child: Text(title, style: style)),
        ],
      );
    }
    return Text(title, style: style);
  }
}

class _PageBreakMarker extends StatelessWidget {
  const _PageBreakMarker({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(height: 1, color: color),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(Icons.insert_page_break_outlined, size: 14, color: color),
              const SizedBox(width: 6),
              Text('Page break', style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
        ),
        Container(height: 1, color: color),
      ],
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.title,
    this.meta = '',
    this.lines = const [],
    required this.bodyStyle,
    required this.accent,
    required this.spacing,
  });

  final String title;
  final String meta;
  final List<String> lines;
  final TextStyle bodyStyle;
  final Color accent;
  final SpacingConfig spacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: spacing.itemSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(title, style: bodyStyle.copyWith(fontWeight: FontWeight.w600)),
          if (meta.isNotEmpty)
            Text(
              meta,
              style: bodyStyle.copyWith(
                fontSize: (bodyStyle.fontSize ?? 12) - 1.5,
              ),
            ),
          for (final line in lines)
            if (line.isNotEmpty)
              _BulletLine(text: line, bodyStyle: bodyStyle, accent: accent),
        ],
      ),
    );
  }
}

/// One description line with its list marker.
///
/// The marker follows the reading direction: left for LTR, right for RTL, so
/// it stays beside right-aligned Arabic text instead of being orphaned against
/// the opposite margin. Mirrors the PDF renderer in `pdf_sections.dart`.
class _BulletLine extends StatelessWidget {
  const _BulletLine({
    required this.text,
    required this.bodyStyle,
    required this.accent,
  });

  final String text;
  final TextStyle bodyStyle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final marker = Text('• ', style: bodyStyle.copyWith(color: accent));
    final body = Expanded(child: Text(text, style: bodyStyle));
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 12, top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rtl ? [body, marker] : [marker, body],
      ),
    );
  }
}

String _join(List<String?> parts) =>
    parts.whereType<String>().where((s) => s.isNotEmpty).join(' · ');

/// Renders the projects of a section using the configured card style.
class _ProjectSection extends StatelessWidget {
  const _ProjectSection({
    required this.section,
    required this.spacing,
    required this.bodyStyle,
    required this.accent,
    required this.presentation,
  });

  final ResolvedSection section;
  final SpacingConfig spacing;
  final TextStyle bodyStyle;
  final Color accent;
  final PresentationConfig presentation;

  @override
  Widget build(BuildContext context) {
    final projects = section.projects;
    if (projects.isEmpty) return const SizedBox.shrink();
    switch (presentation.projectCardStyle) {
      case 'gallery':
        return _gallery(context, projects);
      case 'card':
        return _column(
          projects
              .map(
                (p) => _ProjectCard(
                  project: p,
                  spacing: spacing,
                  bodyStyle: bodyStyle,
                  accent: accent,
                ),
              )
              .toList(),
        );
      case 'flat':
      default:
        return _column(projects.map((p) => _flat(context, p)).toList());
    }
  }

  Widget _column(List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        children[i],
        if (i < children.length - 1) SizedBox(height: spacing.itemSpacing),
      ],
    ],
  );

  Widget _gallery(BuildContext context, List<ProjectEntry> projects) {
    return Wrap(
      spacing: spacing.itemSpacing,
      runSpacing: spacing.itemSpacing,
      children: [
        for (final p in projects)
          SizedBox(
            width: 200,
            child: _ProjectCard(
              project: p,
              spacing: spacing,
              bodyStyle: bodyStyle,
              accent: accent,
              aspectRatio: presentation.projectImageAspectRatio,
            ),
          ),
      ],
    );
  }

  Widget _flat(BuildContext context, ProjectEntry p) => _Entry(
    title: p.title ?? '',
    meta: p.summary ?? '',
    lines: [
      if (p.description != null && p.description!.isNotEmpty) p.description!,
      if (presentation.showProjectTechChips && p.technologies.isNotEmpty)
        p.technologies.join(', '),
      if (p.demoUrl != null && p.demoUrl!.isNotEmpty) p.demoUrl!,
    ],
    bodyStyle: bodyStyle,
    accent: accent,
    spacing: spacing,
  );
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.spacing,
    required this.bodyStyle,
    required this.accent,
    this.aspectRatio,
  });

  final ProjectEntry project;
  final SpacingConfig spacing;
  final TextStyle bodyStyle;
  final Color accent;
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final cover = project.media.isNotEmpty ? project.media.first : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cover != null && cover.isNotEmpty)
          AspectRatio(
            aspectRatio: aspectRatio ?? 1.6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                cover,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: accent.withValues(alpha: 0.15),
                  child: const Icon(Icons.image_outlined),
                ),
              ),
            ),
          ),
        if (cover != null && cover.isNotEmpty)
          SizedBox(height: spacing.itemSpacing),
        if (project.title != null && project.title!.isNotEmpty)
          Text(
            project.title!,
            style: bodyStyle.copyWith(fontWeight: FontWeight.w600),
          ),
        if (project.summary != null && project.summary!.isNotEmpty)
          Text(project.summary!, style: bodyStyle),
        if (project.technologies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final tech in project.technologies)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      tech,
                      style: bodyStyle.copyWith(
                        fontSize: (bodyStyle.fontSize ?? 12) - 2,
                        color: accent,
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

/// Maps a section kind to a stable Material icon (const, so it is safe to use
/// directly inside `Icon`).
IconData _sectionIcon(SectionKind kind) {
  switch (kind) {
    case SectionKind.personalDetails:
      return Icons.badge_outlined;
    case SectionKind.profile:
      return Icons.person_outline;
    case SectionKind.experience:
      return Icons.work_outline;
    case SectionKind.education:
      return Icons.school_outlined;
    case SectionKind.certificates:
      return Icons.workspace_premium_outlined;
    case SectionKind.projects:
      return Icons.folder_outlined;
    case SectionKind.courses:
      return Icons.menu_book_outlined;
    case SectionKind.skills:
      return Icons.star_outline;
    case SectionKind.languages:
      return Icons.translate;
    case SectionKind.awards:
      return Icons.emoji_events_outlined;
    case SectionKind.volunteer:
      return Icons.volunteer_activism_outlined;
    case SectionKind.publications:
      return Icons.article_outlined;
    case SectionKind.references:
      return Icons.people_outline;
    case SectionKind.custom:
      return Icons.tune;
    case SectionKind.pageBreak:
      return Icons.insert_page_break_outlined;
  }
}
