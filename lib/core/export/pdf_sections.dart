/// Renders resolved sections into `pdf` widgets.
///
/// Content only: colours, fonts and spacing all come from [PdfStyle], and
/// ordering/visibility were already decided by [ResolvedDocument]. Nothing here
/// inspects the saved design directly, which is what keeps the designed and ATS
/// outputs consistent.
library;

import 'package:pdf/widgets.dart' as pw;

import '../design/entry_heading.dart';

import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/export/pdf_style.dart';
import 'package:cv_portfolio_maker/core/export/document_text.dart'
    show containsArabicScript;
import 'package:cv_portfolio_maker/core/render/resolved_document.dart';
import 'package:cv_portfolio_maker/core/render/section_titles.dart';

/// Resolves a URL to an embeddable image, or `null` when unavailable.
typedef ImageLookup = pw.MemoryImage? Function(String url);

/// Joins non-empty parts with a separator.
String joinNonEmpty(Iterable<String?> parts, {String separator = ' · '}) {
  final kept = <String>[];
  for (final part in parts) {
    final trimmed = part?.trim() ?? '';
    if (trimmed.isNotEmpty) kept.add(trimmed);
  }
  return kept.join(separator);
}

/// Builds the widgets for one resolved section.
class SectionRenderer {
  SectionRenderer({required this.style, required this.width, this.images});

  final PdfStyle style;

  /// Available content width, used to lay out project galleries.
  final double width;

  /// Optional image resolver (profile photo and project covers).
  final ImageLookup? images;

  /// Every widget belonging to [section], in reading order.
  List<pw.Widget> build(ResolvedSection section) => [
    if (style.design.layoutMode == LayoutMode.one)
      pw.NewPage(
        freeSpace:
            style.typography.sectionTitleFontSize +
            style.typography.resolvedEntryHeaderFontSize +
            style.typography.bodyFontSize * 4,
      ),
    heading(section.title, section.config.kind),
    style.divider(),
    pw.SizedBox(height: style.spacing.itemSpacing / 2),
    for (final entry in _entries(section)) ...[
      if (style.design.layoutMode == LayoutMode.one)
        pw.NewPage(
          freeSpace:
              style.typography.resolvedEntryHeaderFontSize * 2 +
              style.typography.bodyFontSize * 2,
        ),
      if (style.design.layoutMode == LayoutMode.one && entry is _EntryBlock)
        ...entry.flowChildren.map(
          (child) => child is pw.Text ? _fullWidth(child) : child,
        )
      else
        entry,
    ],
  ];

  /// A section heading that spans the content width.
  ///
  /// A bare `Text` shrinks to its content and the multi-page flow then places
  /// it at the left, so a right-to-left heading would hug the wrong margin even
  /// though it carries the right `textAlign`.
  pw.Widget _heading(String title) =>
      _fullWidth(_text(title, style.sectionStyle()));

  pw.Widget heading(String title, SectionKind kind) {
    final label = style.sectionTitle(title);
    final icon = style.fonts.iconFont;
    final code = sectionIconCodes[kind];
    if (style.ats ||
        !style.presentation.showSectionIcons ||
        icon == null ||
        code == null) {
      return _heading(label);
    }
    final iconWidget = pw.Text(
      String.fromCharCode(code),
      style: pw.TextStyle(
        font: icon,
        fontNormal: icon,
        fontBold: icon,
        fontItalic: icon,
        fontBoldItalic: icon,
        color: style.accentColor,
        fontSize:
            style.typography.sectionTitleFontSize *
            style.typography.headingScale,
      ),
    );
    final text = pw.Expanded(child: _text(label, style.sectionStyle()));
    return _fullWidth(
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: style.rtl
            ? [text, pw.SizedBox(width: 6), iconWidget]
            : [iconWidget, pw.SizedBox(width: 6), text],
      ),
    );
  }

  List<pw.Widget> _entries(ResolvedSection section) {
    switch (section.config.kind) {
      case SectionKind.experience:
        return [
          for (final e in section.experiences)
            _block([
              _entryHeader(
                e.position ?? '',
                joinNonEmpty([
                  e.dateRange.format(),
                  e.location,
                  e.employmentType,
                ]),
                organization: e.company ?? '',
              ),
              ...e.resolvedDescriptions
                  .where((d) => d.text.trim().isNotEmpty)
                  .map(_description),
            ]),
        ];

      case SectionKind.education:
        return [
          for (final e in section.education)
            _block([
              _entryHeader(
                joinNonEmpty([e.qualification, e.fieldOfStudy]),
                e.dateRange.format(),
                organization: e.institution ?? '',
              ),
              if ((e.grade ?? '').trim().isNotEmpty) _bullet(e.grade!),
              if ((e.description ?? '').trim().isNotEmpty)
                _bullet(e.description!),
            ]),
        ];

      case SectionKind.skills:
        return [_skills(section.skills)];

      case SectionKind.languages:
        return [
          for (final l in section.languages)
            _fullWidth(
              _text(
                joinNonEmpty([l.name, proficiencyLabel(l.proficiency)]),
                style.style(),
              ),
            ),
        ];

      case SectionKind.certificates:
        return [
          for (final c in section.certificates)
            _block([
              _entryHeader(
                joinNonEmpty([c.name, c.issuer]),
                c.dateRange.format(),
              ),
            ]),
        ];

      case SectionKind.courses:
        return [
          for (final c in section.courses)
            _block([
              _entryHeader(
                joinNonEmpty([c.name, c.institution]),
                c.dateRange.format(),
              ),
            ]),
        ];

      case SectionKind.awards:
        return [
          for (final a in section.awards)
            _block([
              _entryHeader(
                joinNonEmpty([a.name, a.issuer]),
                a.dateRange.format(),
              ),
              _optional(a.description, style.style()),
            ]),
        ];

      case SectionKind.volunteer:
        return [
          for (final v in section.volunteer)
            _block([
              _entryHeader(
                joinNonEmpty([v.role, v.organization]),
                joinNonEmpty([v.location, v.dateRange.format()]),
              ),
              ...v.descriptions.where((d) => d.trim().isNotEmpty).map(_bullet),
            ]),
        ];

      case SectionKind.publications:
        return [
          for (final p in section.publications)
            _block([
              _entryHeader(
                p.title ?? '',
                joinNonEmpty([p.venue, p.dateRange.format()]),
              ),
            ]),
        ];

      case SectionKind.references:
        return [
          for (final r in section.references)
            _block([
              _entryTitle(r.name ?? ''),
              _optional(r.relationship, style.metaStyle()),
              _optional(r.notes, style.style()),
            ]),
        ];

      case SectionKind.projects:
        if (style.design.layoutMode == LayoutMode.one &&
            style.presentation.projectCardStyle != 'gallery') {
          return [for (final project in section.projects) _project(project)];
        }
        return [_projects(section.projects)];

      case SectionKind.custom:
        return [
          for (final e in section.customEntries)
            _block([
              _entryTitle(e.title),
              _optional(e.metadata, style.metaStyle()),
              _optional(e.content, style.style()),
              _linkLine('Website', e.url),
              if (!style.ats &&
                  e.imageUrl != null &&
                  images?.call(e.imageUrl!) != null)
                pw.Image(
                  images!(e.imageUrl!)!,
                  height: 110,
                  fit: pw.BoxFit.contain,
                ),
            ]),
        ];

      case SectionKind.personalDetails:
      case SectionKind.profile:
      case SectionKind.pageBreak:
        return const <pw.Widget>[];
    }
  }

  // -------------------------------------------------------------- primitives

  pw.Widget _text(String value, pw.TextStyle textStyle) => pw.Text(
    style.text(value),
    style: textStyle,
    textAlign: style.bodyAlign,
    overflow: pw.TextOverflow.span,
  );

  /// Stretches [child] to the available width.
  ///
  /// `pdf` clamps the infinite constraint to whatever the parent offers, so
  /// this fills the page, a column cell or an `Expanded` without overflowing,
  /// and it is what lets `textAlign` actually position text in RTL documents.
  pw.Widget _fullWidth(pw.Widget child) =>
      pw.SizedBox(width: double.infinity, child: child);

  pw.Widget _entryHeader(
    String title,
    String meta, {
    String organization = '',
  }) {
    final content = EntryHeadingContent.resolve(
      title: title,
      metadata: meta,
      organization: organization,
      presentation: style.presentation,
    );
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.LayoutBuilder(
          builder: (context, constraints) {
            final heading = _text(content.title, style.entryStyle());
            if (content.metadata.isEmpty) return heading;
            if (style.presentation.dateLocationPosition != 'right') {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [heading, _text(content.metadata, style.dateStyle())],
              );
            }
            final available = constraints?.maxWidth ?? width;
            final date = pw.Text(
              style.text(content.metadata),
              style: style.dateStyle(),
              maxLines: 1,
            );
            date.layout(context, const pw.BoxConstraints());
            final measured = date.box!.width + 1;
            final alignment = style.rtl
                ? pw.Alignment.centerLeft
                : pw.Alignment.centerRight;
            pw.Widget fitted(double size) => pw.SizedBox(
              width: size,
              child: pw.FittedBox(
                fit: pw.BoxFit.scaleDown,
                alignment: alignment,
                child: date,
              ),
            );
            if (available >= 240 && measured <= available * .6) {
              final metadata = pw.Padding(
                padding: pw.EdgeInsets.only(
                  top:
                      (style.typography.resolvedEntryHeaderFontSize -
                              style.typography.resolvedDateFontSize)
                          .clamp(0, 24)
                          .toDouble() *
                      .7,
                ),
                child: fitted(measured),
              );
              return pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: style.rtl
                    ? [
                        metadata,
                        pw.SizedBox(width: 12),
                        pw.Expanded(child: heading),
                      ]
                    : [
                        pw.Expanded(child: heading),
                        pw.SizedBox(width: 12),
                        metadata,
                      ],
              );
            }
            // Keep the complete date together even in a narrow column.
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [heading, fitted(available)],
            );
          },
        ),
        if (content.organization.isNotEmpty)
          _text(content.organization, style.metaStyle()),
      ],
    );
  }

  pw.Widget _entryTitle(String value) => _text(value, style.entryStyle());

  /// A line that is skipped entirely when [value] is blank, so no empty
  /// headings or orphan separators are ever emitted.
  pw.Widget? _optional(String? value, pw.TextStyle textStyle) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return _text(trimmed, textStyle);
  }

  // A spanning text widget lets a single description continue on the next page.
  // A horizontal marker/body Row cannot span and fails for a page-long paragraph.
  pw.Widget _bullet(String value) => pw.Text(
    style.text('\u2022 $value'),
    style: style.style(),
    textAlign: style.bodyAlign,
    overflow: pw.TextOverflow.span,
  );

  pw.Widget _description(DescriptionItem item) {
    if (item.label.trim().isEmpty) return _bullet(item.text);
    // Reorder the whole line before splitting it into styled runs so the
    // heading, colon and marker keep their positions in both directions.
    final text = style.text('\u2022 ${item.formatted}');
    final heading = style.text(item.label.trim(), rtlBase: false);
    final start = style.rtl && containsArabicScript(item.label)
        ? text.lastIndexOf(heading)
        : text.indexOf(heading);
    if (start < 0) return _bullet(item.formatted);
    final boldStart = start > 0 && text[start - 1] == ':' ? start - 1 : start;
    final end = start + heading.length;
    final boldEnd = end < text.length && text[end] == ':' ? end + 1 : end;
    return pw.RichText(
      text: pw.TextSpan(
        style: style.style(),
        children: [
          pw.TextSpan(text: text.substring(0, boldStart)),
          pw.TextSpan(
            text: text.substring(boldStart, boldEnd),
            style: style.style(bold: true),
          ),
          pw.TextSpan(text: text.substring(boldEnd)),
        ],
      ),
      textAlign: style.bodyAlign,
      overflow: pw.TextOverflow.span,
    );
  }

  /// A vertical stack of entry lines with the configured spacing.
  pw.Widget _block(List<pw.Widget?> children) {
    final kept = children.whereType<pw.Widget>().toList();
    return _EntryBlock([
      for (var i = 0; i < kept.length; i++) ...[
        kept[i],
        if (i < kept.length - 1)
          pw.SizedBox(height: style.spacing.paragraphSpacing / 2),
      ],
      pw.SizedBox(height: style.spacing.itemSpacing),
    ]);
  }

  /// Skills as outlined chips, or a plain comma list for ATS output.
  pw.Widget _skills(List<SkillEntry> skills) {
    final names = skills
        .map((s) => (s.name ?? '').trim())
        .where((n) => n.isNotEmpty)
        .toList();
    if (names.isEmpty) return pw.SizedBox.shrink();
    if (style.ats) return _fullWidth(_text(names.join(', '), style.style()));
    return pw.Wrap(
      alignment: style.rtl ? pw.WrapAlignment.end : pw.WrapAlignment.start,
      spacing: style.spacing.itemSpacing / 2,
      runSpacing: style.spacing.itemSpacing / 2,
      children: [
        for (final name in names)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: style.dividerColor, width: 0.5),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: _text(
              name,
              style.style(size: style.typography.bodyFontSize - 1),
            ),
          ),
      ],
    );
  }

  /// Projects honouring the configured card style.
  pw.Widget _projects(List<ProjectEntry> projects) {
    if (projects.isEmpty) return pw.SizedBox.shrink();
    final gallery = style.presentation.projectCardStyle == 'gallery';
    return pw.Wrap(
      alignment: style.rtl ? pw.WrapAlignment.end : pw.WrapAlignment.start,
      spacing: style.spacing.itemSpacing,
      runSpacing: style.spacing.itemSpacing,
      children: [
        for (final p in projects)
          pw.SizedBox(
            width: gallery ? (width - style.spacing.itemSpacing) / 2 : width,
            child: _project(p),
          ),
      ],
    );
  }

  pw.Widget _project(ProjectEntry p) {
    final cover = style.ats || style.presentation.projectCardStyle == 'flat'
        ? null
        : _cover(p);
    final children = <pw.Widget?>[
      if (cover != null) ...[
        pw.ClipRRect(
          horizontalRadius: 8,
          verticalRadius: 8,
          child: pw.LayoutBuilder(
            builder: (context, constraints) {
              final available = constraints?.maxWidth ?? width;
              final aspect = style.presentation.projectImageAspectRatio;
              return pw.Image(
                cover,
                width: available,
                height:
                    available / (aspect.isFinite && aspect > 0 ? aspect : 1.6),
                fit: pw.BoxFit.cover,
              );
            },
          ),
        ),
        pw.SizedBox(height: style.spacing.itemSpacing),
      ],
      _entryHeader(p.title ?? '', p.dateRange.format()),
      _optional(p.summary, style.style()),
      ...p.resolvedDescriptions
          .where((d) => d.text.trim().isNotEmpty)
          .map(_description),
      if (style.presentation.showProjectTechChips && p.technologies.isNotEmpty)
        style.ats || style.presentation.projectCardStyle == 'flat'
            ? _text(p.technologies.join(', '), style.metaStyle())
            : pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final tech in p.technologies)
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: pw.BoxDecoration(
                          color: style.projectChipColor,
                          borderRadius: pw.BorderRadius.circular(10),
                        ),
                        child: _text(
                          tech,
                          style.style(
                            size: style.typography.bodyFontSize - 2,
                            color: style.accentColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      _fullWidth(
        pw.Wrap(
          alignment: style.rtl ? pw.WrapAlignment.end : pw.WrapAlignment.start,
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final link in [
              ('Demo', p.demoUrl),
              ('Source', p.sourceUrl),
              ('Website', p.websiteUrl),
            ])
              if (_linkLine(link.$1, link.$2) case final pw.Widget item) item,
          ],
        ),
      ),
    ];
    return _EntryBlock([
      ...children.whereType<pw.Widget>(),
      pw.SizedBox(height: style.spacing.itemSpacing),
    ]);
  }

  pw.Widget? _linkLine(String label, String? url) {
    final target = url?.trim() ?? '';
    if (target.isEmpty) return null;
    final icon = style.fonts.iconFont;
    final text = style.ats
        ? _text('$label: $target', style.metaStyle())
        : pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              if (icon != null) ...[
                pw.Text(
                  String.fromCharCode(0xe157),
                  style: pw.TextStyle(
                    font: icon,
                    fontNormal: icon,
                    fontBold: icon,
                    fontItalic: icon,
                    fontBoldItalic: icon,
                    fontSize: style.typography.bodyFontSize,
                    color: style.secondaryColor,
                  ),
                ),
                pw.SizedBox(width: 3),
              ],
              _text(label, style.metaStyle()),
            ],
          );
    return isSafeExternalUrl(target)
        ? pw.UrlLink(destination: target, child: text)
        : text;
  }

  pw.MemoryImage? _cover(ProjectEntry p) {
    final lookup = images;
    if (lookup == null) return null;
    for (final url in p.media) {
      if (url.trim().isEmpty) continue;
      final image = lookup(url);
      if (image != null) return image;
    }
    return null;
  }

  /// The profile image, when the design requests one.
  pw.Widget? avatarWidget(ProfileDetails details) {
    if (!style.showAvatar) return null;
    final url = details.avatarUrl?.trim() ?? '';
    if (url.isEmpty) return null;
    final image = images?.call(url);
    if (image == null) return null;
    final size = style.presentation.avatarSize;
    final radius = style.avatarRadius();
    return pw.ClipRRect(
      horizontalRadius: radius,
      verticalRadius: radius,
      child: pw.Image(image, width: size, height: size, fit: pw.BoxFit.cover),
    );
  }
}

/// Retains grouped layout inside columns while exposing a spanning page flow.
/// Text must be a direct MultiPage child to receive bounded page constraints.
class _EntryBlock extends pw.StatelessWidget {
  _EntryBlock(this.flowChildren);

  final List<pw.Widget> flowChildren;

  @override
  pw.Widget build(pw.Context context) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: flowChildren,
  );
}

/// `true` when [url] may be embedded as a clickable PDF link.
///
/// Guards against malformed destinations and non-navigable schemes such as
/// `javascript:`, which `pdf` would otherwise write into the annotation.
bool isSafeExternalUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return const {'http', 'https', 'mailto', 'tel'}.contains(uri.scheme);
}
