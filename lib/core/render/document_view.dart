import '../widgets/profile_image.dart';
import '../widgets/description_items_editor.dart';
import '../utils/project_media.dart';
import '../utils/project_links.dart';
import '../design/entry_heading.dart';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';

import 'contact_detail_icon.dart';

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
  const DocumentView({super.key, required this.resolved, this.sectionBuilder});

  final ResolvedDocument resolved;
  final Widget? Function(BuildContext, ResolvedSection)? sectionBuilder;

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
      fontFamilyFallback: const ['notoNaskhArabic'],
      fontSize: typography.bodyFontSize,
      height: typography.bodyLineHeight,
      color: bodyColor,
    );

    return Container(
      color: Color(colors.paper),
      padding: EdgeInsets.symmetric(
        horizontal: spacing.resolvedHorizontalMargin,
        vertical: spacing.resolvedVerticalMargin,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DocumentHeader(resolved: resolved, bodyStyle: bodyStyle),
          if (resolved.summary.isNotEmpty) ...[
            SizedBox(height: spacing.sectionSpacing),
            _SectionHeading(
              title: typography.uppercaseSectionTitles
                  ? resolved.summaryTitle.toUpperCase()
                  : resolved.summaryTitle,
              kind: SectionKind.profile,
              typography: typography,
              presentation: presentation,
              headingColor: headingColor,
              accentColor: Color(colors.accent),
            ),
            _SectionDivider(
              presentation: presentation,
              dividerColor: dividerColor,
              accent: Color(colors.accent),
            ),
            SizedBox(height: spacing.itemSpacing),
            Text(
              resolved.summary,
              style: bodyStyle.copyWith(height: typography.bodyLineHeight),
            ),
            SizedBox(height: spacing.sectionSpacing),
          ],
          ..._buildBody(
            context: context,
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
    required BuildContext context,
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
            sectionBuilder?.call(context, section) ??
                _DocumentSection(
                  ownerId: resolved.document.ownerId,
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
      fontFamily: typography.resolvedNameFont,
      fontFamilyFallback: const ['notoNaskhArabic'],
      letterSpacing: typography.headingLetterSpacing,
      fontSize: typography.headingFontSize * typography.headingScale,
      height: typography.headingLineHeight,
      fontWeight: FontWeight.w700,
      color: headingColor,
    );
    final titleStyle = bodyStyle.copyWith(
      fontFamily: typography.bodyFont,
      fontFamilyFallback: const ['notoNaskhArabic'],
      fontSize: typography.resolvedProfessionalTitleFontSize,
      fontWeight: FontWeight.w600,
      color: Color(colors.secondary),
    );

    final identityChildren = <Widget>[
      if (name.isNotEmpty)
        Text(
          name,
          style: nameStyle,
          textAlign: pres.headerStyle == 'center'
              ? TextAlign.center
              : TextAlign.start,
        ),
      if (title.isNotEmpty)
        Text(
          title,
          style: titleStyle,
          textAlign: pres.headerStyle == 'center'
              ? TextAlign.center
              : TextAlign.start,
        ),
    ];
    final identity = pres.identityArrangement == 'inline'
        ? Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: pres.headerStyle == 'center'
                ? WrapAlignment.center
                : WrapAlignment.start,
            children: identityChildren,
          )
        : Column(
            crossAxisAlignment: pres.headerStyle == 'center'
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: identityChildren,
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
            if (pres.avatarShape != AvatarShape.hidden &&
                (details.avatarUrl?.isNotEmpty ?? false)) ...[
              avatar,
              const SizedBox(width: 12),
            ],
            Expanded(child: identity),
            if (resolved.contacts.isNotEmpty) Expanded(child: contactBlock),
          ],
        );
      case 'left':
      default:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pres.avatarShape != AvatarShape.hidden &&
                (details.avatarUrl?.isNotEmpty ?? false)) ...[
              avatar,
              const SizedBox(width: 12),
            ],
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : 260.0;
      final center = presentation.headerStyle == 'center';
      Widget item(ResolvedContact c) {
        final content = Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: center
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            if (presentation.showContactIcons) ...[
              ContactDetailIcon(
                label: c.label,
                style: presentation.contactIconStyle,
                size: presentation.resolvedContactIconSize(
                  textStyle.fontSize ?? 12,
                ),
                color: textStyle.color ?? Colors.black,
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                c.text(),
                style: textStyle,
                textAlign: center ? TextAlign.center : TextAlign.start,
              ),
            ),
          ],
        );
        if (c.url == null) return content;
        return Semantics(
          link: true,
          label: c.label,
          child: InkWell(
            onTap: () async {
              var opened = false;
              try {
                opened = await launchUrl(
                  Uri.parse(c.url!),
                  mode: LaunchMode.externalApplication,
                );
              } catch (_) {
                /* Surface a friendly error, never a broken navigation. */
              }
              if (!opened && context.mounted) {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(content: Text(context.tr('errorGeneric'))),
                );
              }
            },
            child: content,
          ),
        );
      }

      Widget row(List<ResolvedContact> values) => Wrap(
        alignment: center ? WrapAlignment.center : WrapAlignment.start,
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final c in values)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width),
              child: item(c),
            ),
        ],
      );
      final middle = (contacts.length / 2).ceil();
      return switch (presentation.resolvedContactArrangement) {
        'compact' || 'oneRow' => row(contacts),
        'twoRows' => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row(contacts.take(middle).toList()),
            const SizedBox(height: 4),
            row(contacts.skip(middle).toList()),
          ],
        ),
        'grid' => Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final c in contacts)
              SizedBox(
                width: width < 220 ? width : (width - 12) / 2,
                child: item(c),
              ),
          ],
        ),
        _ => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final c in contacts)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: item(c),
              ),
          ],
        ),
      };
    },
  );
}

/// Renders a single section: heading, divider and its entries.
class _DocumentSection extends StatelessWidget {
  const _DocumentSection({
    required this.section,
    required this.ownerId,
    required this.colors,
    required this.typography,
    required this.spacing,
    required this.presentation,
    required this.bodyStyle,
    required this.headingColor,
    required this.dividerColor,
  });

  final ResolvedSection section;
  final String ownerId;
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

  Widget _buildDivider() => _SectionDivider(
    presentation: presentation,
    dividerColor: dividerColor,
    accent: Color(colors.accent),
  );

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
            ownerId: ownerId,
            metadataColor: Color(colors.secondary),
            typography: typography,
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
    metadataColor: Color(colors.secondary),
    title: e.position ?? '',
    organization: e.company ?? '',
    meta: _join([e.dateRange.format(), e.location, e.employmentType]),
    descriptionItems: e.resolvedDescriptions,
    bodyStyle: bodyStyle,
    accent: Color(colors.accent),
    spacing: spacing,
    presentation: presentation,
    typography: typography,
  );

  Widget _education(BuildContext c, EducationEntry e) => _Entry(
    metadataColor: Color(colors.secondary),
    title: _join([e.qualification, e.fieldOfStudy]),
    meta: e.dateRange.format(),
    organization: e.institution ?? '',
    lines: [
      if (e.grade != null && e.grade!.isNotEmpty) e.grade!,
      if (e.description != null && e.description!.isNotEmpty) e.description!,
    ],
    bodyStyle: bodyStyle,
    accent: Color(colors.accent),
    spacing: spacing,
    presentation: presentation,
    typography: typography,
  );

  Widget _certificate(BuildContext c, CertificateEntry e) => _Entry(
    metadataColor: Color(colors.secondary),
    title: e.name,
    meta: _join([e.issuer, e.dateRange.format()]),
    bodyStyle: bodyStyle,
    accent: Color(colors.accent),
    spacing: spacing,
    presentation: presentation,
    typography: typography,
  );

  Widget _course(BuildContext c, CourseEntry e) => _Entry(
    metadataColor: Color(colors.secondary),
    title: e.name ?? '',
    meta: _join([e.institution, e.dateRange.format()]),
    bodyStyle: bodyStyle,
    accent: Color(colors.accent),
    spacing: spacing,
    presentation: presentation,
    typography: typography,
  );

  Widget _award(BuildContext c, AwardEntry e) => _Entry(
    metadataColor: Color(colors.secondary),
    title: e.name ?? '',
    meta: _join([e.issuer, e.dateRange.format()]),
    lines: [
      if (e.description != null && e.description!.isNotEmpty) e.description!,
    ],
    bodyStyle: bodyStyle,
    accent: Color(colors.accent),
    spacing: spacing,
    presentation: presentation,
    typography: typography,
  );

  Widget _volunteer(BuildContext c, VolunteerEntry e) => _Entry(
    metadataColor: Color(colors.secondary),
    title: _join([e.role, e.organization]),
    meta: _join([e.location, e.dateRange.format()]),
    lines: e.descriptions,
    bodyStyle: bodyStyle,
    accent: Color(colors.accent),
    spacing: spacing,
    presentation: presentation,
    typography: typography,
  );

  Widget _publication(BuildContext c, PublicationEntry e) => _Entry(
    metadataColor: Color(colors.secondary),
    title: e.title ?? '',
    meta: _join([e.venue, e.dateRange.format()]),
    bodyStyle: bodyStyle,
    accent: Color(colors.accent),
    spacing: spacing,
    presentation: presentation,
    typography: typography,
  );

  Widget _reference(BuildContext c, ReferenceEntry e) => _Entry(
    metadataColor: Color(colors.secondary),
    title: e.name ?? '',
    meta: e.relationship ?? '',
    lines: [if (e.notes != null && e.notes!.isNotEmpty) e.notes!],
    bodyStyle: bodyStyle,
    accent: Color(colors.accent),
    spacing: spacing,
    presentation: presentation,
    typography: typography,
  );

  Widget _custom(BuildContext c, CustomEntry e) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Entry(
        title: e.title,
        meta: e.formatMetadata(languageCode: c.languageCode),
        lines: [
          if ((e.url ?? '').isNotEmpty) e.url!,
          if ((e.content ?? '').isNotEmpty) e.content!,
        ],
        bodyStyle: bodyStyle,
        accent: Color(colors.accent),
        spacing: spacing,
        presentation: presentation,
        typography: typography,
      ),
      if ((e.imageUrl ?? '').isNotEmpty)
        Padding(
          padding: EdgeInsets.only(bottom: spacing.itemSpacing),
          child: SizedBox(
            height: 160,
            child: PortfolioImage(
              source: e.imageUrl,
              ownerId: ownerId,
              fit: BoxFit.contain,
              fallback: const SizedBox.shrink(),
            ),
          ),
        ),
    ],
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
      fontFamily: typography.bodyFont,
      fontFamilyFallback: const ['notoNaskhArabic'],
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
    this.organization = '',
    this.summary = '',
    this.metadataColor = const Color(0xff52606d),
    this.extra = const [],
    this.titleLinks = const [],
    this.lines = const [],
    this.descriptionItems = const [],
    required this.bodyStyle,
    required this.accent,
    required this.spacing,
    this.presentation = const PresentationConfig(),
    this.typography = const TypographyConfig(),
  });
  final String title;
  final String meta;
  final String organization;
  final String summary;
  final Color metadataColor;
  final List<Widget> extra;
  final List<ProjectHeadingLink> titleLinks;
  final List<String> lines;
  final List<DescriptionItem> descriptionItems;
  final TextStyle bodyStyle;
  final Color accent;
  final SpacingConfig spacing;
  final PresentationConfig presentation;
  final TypographyConfig typography;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: spacing.itemSpacing),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EntryHeading(
          links: titleLinks,
          metadataColor: metadataColor,
          title: title,
          meta: meta,
          organization: organization,
          bodyStyle: bodyStyle,
          typography: typography,
          presentation: presentation,
        ),
        if (summary.isNotEmpty) Text(summary, style: bodyStyle),
        for (final item in descriptionItems)
          if (item.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 12, top: 2),
              child: DescriptionItemText(item: item, style: bodyStyle),
            ),
        for (final line in lines)
          if (line.isNotEmpty)
            _BulletLine(text: line, bodyStyle: bodyStyle, accent: accent),
        ...extra,
      ],
    ),
  );
}

class _EntryHeading extends StatelessWidget {
  const _EntryHeading({
    required this.title,
    required this.meta,
    this.organization = '',
    this.metadataColor = const Color(0xff52606d),
    this.links = const [],
    required this.bodyStyle,
    required this.typography,
    required this.presentation,
  });
  final String title, meta, organization;
  final List<ProjectHeadingLink> links;
  final Color metadataColor;
  final TextStyle bodyStyle;
  final TypographyConfig typography;
  final PresentationConfig presentation;

  @override
  Widget build(BuildContext context) {
    final content = EntryHeadingContent.resolve(
      title: title,
      metadata: meta,
      organization: organization,
      presentation: presentation,
    );
    final titleStyle = bodyStyle.copyWith(
      fontSize: typography.resolvedEntryHeaderFontSize,
      fontWeight: FontWeight.w600,
    );
    final dateStyle = bodyStyle.copyWith(
      fontSize: typography.resolvedDateFontSize,
      color: metadataColor,
    );
    final heading = links.isEmpty
        ? Text(content.title, style: titleStyle)
        : Text.rich(
            TextSpan(
              text: content.title,
              children: [
                for (final link in links) ...[
                  const TextSpan(text: '\u00a0'),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: _ProjectTitleLink(link: link, style: titleStyle),
                  ),
                ],
              ],
            ),
            style: titleStyle,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (content.metadata.isEmpty) return heading;
            final metadata = Text(
              content.metadata,
              style: dateStyle,
              maxLines: presentation.dateLocationPosition == 'right' ? 1 : null,
              softWrap: presentation.dateLocationPosition != 'right',
            );
            if (presentation.dateLocationPosition != 'right') {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [heading, metadata],
              );
            }
            final painter = TextPainter(
              text: TextSpan(text: content.metadata, style: dateStyle),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              maxLines: 1,
            )..layout();
            final measured = painter.width + 1;
            painter.dispose();
            if (constraints.maxWidth >= 240 &&
                measured <= constraints.maxWidth * .6) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: 12),
                  SizedBox(width: measured, child: metadata),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: metadata,
                  ),
                ),
              ],
            );
          },
        ),
        if (content.organization.isNotEmpty)
          Text(
            content.organization,
            style: bodyStyle.copyWith(color: metadataColor),
          ),
      ],
    );
  }
}

class _ProjectTitleLink extends StatelessWidget {
  const _ProjectTitleLink({required this.link, required this.style});
  final ProjectHeadingLink link;
  final TextStyle style;
  @override
  Widget build(BuildContext context) => Semantics(
    link: true,
    label: context.ui(link.label),
    child: Tooltip(
      message: context.ui(link.label),
      child: InkWell(
        onTap: () async {
          var opened = false;
          try {
            opened = await launchUrl(
              Uri.parse(link.url),
              mode: LaunchMode.externalApplication,
            );
          } catch (_) {
            /* Keep failed launches in the current CV. */
          }
          if (!opened && context.mounted) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(content: Text(context.tr('errorGeneric'))),
            );
          }
        },
        child: Icon(
          switch (link.label) {
            'Source' => const IconData(0xf09b, fontFamily: 'CvBrandIcons'),
            'Website' => const IconData(0xe894, fontFamily: 'CvContactIcons'),
            _ => const IconData(0xe157, fontFamily: 'CvContactIcons'),
          },
          size: style.fontSize ?? 12,
          color: style.color,
        ),
      ),
    ),
  );
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
    required this.ownerId,
    required this.metadataColor,
    required this.section,
    required this.spacing,
    required this.bodyStyle,
    required this.accent,
    required this.presentation,
    required this.typography,
  });

  final ResolvedSection section;
  final String ownerId;
  final Color metadataColor;
  final SpacingConfig spacing;
  final TextStyle bodyStyle;
  final Color accent;
  final PresentationConfig presentation;
  final TypographyConfig typography;

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
                  metadataColor: metadataColor,
                  ownerId: ownerId,
                  project: p,
                  spacing: spacing,
                  bodyStyle: bodyStyle,
                  accent: accent,
                  typography: typography,
                  presentation: presentation,
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
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: spacing.itemSpacing,
        runSpacing: spacing.itemSpacing,
        children: [
          for (final p in projects)
            SizedBox(
              width: ((constraints.maxWidth - spacing.itemSpacing) / 2).clamp(
                1,
                double.infinity,
              ),
              child: _ProjectCard(
                metadataColor: metadataColor,
                ownerId: ownerId,
                project: p,
                spacing: spacing,
                bodyStyle: bodyStyle,
                accent: accent,
                typography: typography,
                presentation: presentation,
                aspectRatio: presentation.projectImageAspectRatio,
              ),
            ),
        ],
      ),
    );
  }

  Widget _flat(BuildContext context, ProjectEntry p) => _Entry(
    titleLinks: projectHeadingLinks(p),
    metadataColor: metadataColor,
    title: p.title ?? '',
    meta: p.dateRange.format(),
    summary: p.summary ?? '',
    descriptionItems: p.resolvedDescriptions,
    bodyStyle: bodyStyle,
    accent: accent,
    spacing: spacing,
    typography: typography,
    presentation: presentation,
    extra: [
      if (presentation.showProjectTechChips && p.technologies.isNotEmpty)
        Text(
          p.technologies.join(', '),
          style: bodyStyle.copyWith(color: metadataColor),
        ),
    ],
  );
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.ownerId,
    required this.metadataColor,
    required this.project,
    required this.spacing,
    required this.bodyStyle,
    required this.accent,
    this.aspectRatio,
    required this.typography,
    required this.presentation,
  });

  final ProjectEntry project;
  final String ownerId;
  final Color metadataColor;
  final SpacingConfig spacing;
  final TextStyle bodyStyle;
  final Color accent;
  final double? aspectRatio;
  final TypographyConfig typography;
  final PresentationConfig presentation;

  @override
  Widget build(BuildContext context) {
    final images = project.media.where((m) => !isProjectVideo(m));
    final cover = images.isEmpty ? null : images.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cover != null && cover.isNotEmpty)
          AspectRatio(
            aspectRatio: aspectRatio ?? 1.6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: PortfolioImage(
                source: cover,
                ownerId: ownerId,
                fallback: Container(
                  color: accent.withValues(alpha: 0.15),
                  child: const Icon(Icons.image_outlined),
                ),
              ),
            ),
          ),
        if (cover != null && cover.isNotEmpty)
          SizedBox(height: spacing.itemSpacing),
        _EntryHeading(
          links: projectHeadingLinks(project),
          metadataColor: metadataColor,
          title: project.title ?? '',
          meta: project.dateRange.format(),
          bodyStyle: bodyStyle,
          typography: typography,
          presentation: presentation,
        ),
        if (project.summary != null && project.summary!.isNotEmpty)
          Text(project.summary!, style: bodyStyle),
        for (final item in project.resolvedDescriptions)
          if (item.text.trim().isNotEmpty)
            DescriptionItemText(item: item, style: bodyStyle),
        if (presentation.showProjectTechChips &&
            project.technologies.isNotEmpty)
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

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({
    required this.presentation,
    required this.dividerColor,
    required this.accent,
  });
  final PresentationConfig presentation;
  final Color dividerColor, accent;
  @override
  Widget build(BuildContext context) => switch (presentation.dividerStyle) {
    DividerStyle.none => const SizedBox.shrink(),
    DividerStyle.thin || DividerStyle.thick => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Divider(
        height: presentation.dividerStyle == DividerStyle.thick ? 3 : 1,
        thickness: presentation.dividerStyle == DividerStyle.thick ? 3 : 1,
        color: dividerColor,
      ),
    ),
    DividerStyle.dotted => Padding(
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
    ),
    DividerStyle.gradient => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        height: 2,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [dividerColor, accent, dividerColor],
          ),
        ),
      ),
    ),
  };
}

/// Maps a section kind to a stable Material icon (const, so it is safe to use
/// directly inside `Icon`).
IconData _sectionIcon(SectionKind kind) => switch (kind) {
  SectionKind.profile => const IconData(0xe7fd, fontFamily: 'CvContactIcons'),
  SectionKind.experience => const IconData(
    0xe8f9,
    fontFamily: 'CvContactIcons',
  ),
  SectionKind.education => const IconData(0xe80c, fontFamily: 'CvContactIcons'),
  SectionKind.certificates => const IconData(
    0xe86f,
    fontFamily: 'CvContactIcons',
  ),
  SectionKind.projects => const IconData(0xe2c7, fontFamily: 'CvContactIcons'),
  SectionKind.courses => const IconData(0xe865, fontFamily: 'CvContactIcons'),
  SectionKind.skills => const IconData(0xe838, fontFamily: 'CvContactIcons'),
  SectionKind.languages => const IconData(0xe894, fontFamily: 'CvContactIcons'),
  SectionKind.awards => const IconData(0xe8e5, fontFamily: 'CvContactIcons'),
  SectionKind.volunteer => const IconData(0xe87c, fontFamily: 'CvContactIcons'),
  SectionKind.publications => const IconData(
    0xe873,
    fontFamily: 'CvContactIcons',
  ),
  SectionKind.references => const IconData(
    0xe7fb,
    fontFamily: 'CvContactIcons',
  ),
  SectionKind.custom => const IconData(0xe8b8, fontFamily: 'CvContactIcons'),
  _ => const IconData(0xe873, fontFamily: 'CvContactIcons'),
};
