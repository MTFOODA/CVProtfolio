/// Renders resolved sections into `pdf` widgets.
///
/// Content only: colours, fonts and spacing all come from [PdfStyle], and
/// ordering/visibility were already decided by [ResolvedDocument]. Nothing here
/// inspects the saved design directly, which is what keeps the designed and ATS
/// outputs consistent.
library;

import 'package:pdf/widgets.dart' as pw;

import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/export/pdf_style.dart';
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
    _heading(style.sectionTitle(section.title)),
    style.divider(),
    pw.SizedBox(height: style.spacing.itemSpacing / 2),
    ..._entries(section),
  ];

  /// A section heading that spans the content width.
  ///
  /// A bare `Text` shrinks to its content and the multi-page flow then places
  /// it at the left, so a right-to-left heading would hug the wrong margin even
  /// though it carries the right `textAlign`.
  pw.Widget _heading(String title) =>
      _fullWidth(_text(title, style.sectionStyle()));

  List<pw.Widget> _entries(ResolvedSection section) {
    switch (section.config.kind) {
      case SectionKind.experience:
        return [
          for (final e in section.experiences)
            _block([
              _entryTitle(joinNonEmpty([e.position, e.company])),
              _optional(
                joinNonEmpty([
                  e.location,
                  e.employmentType,
                  e.dateRange.format(),
                ]),
                style.metaStyle(),
              ),
              ...e.descriptions.where((d) => d.trim().isNotEmpty).map(_bullet),
            ]),
        ];

      case SectionKind.education:
        return [
          for (final e in section.education)
            _block([
              _entryTitle(joinNonEmpty([e.qualification, e.fieldOfStudy])),
              _optional(
                joinNonEmpty([e.institution, e.dateRange.format()]),
                style.metaStyle(),
              ),
              _optional(joinNonEmpty(['Grade', e.grade]), style.metaStyle()),
              _optional(e.description, style.style()),
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
              _entryTitle(joinNonEmpty([c.name, c.issuer])),
              _optional(c.dateRange.format(), style.metaStyle()),
            ]),
        ];

      case SectionKind.courses:
        return [
          for (final c in section.courses)
            _block([
              _entryTitle(joinNonEmpty([c.name, c.institution])),
              _optional(c.dateRange.format(), style.metaStyle()),
            ]),
        ];

      case SectionKind.awards:
        return [
          for (final a in section.awards)
            _block([
              _entryTitle(joinNonEmpty([a.name, a.issuer])),
              _optional(a.dateRange.format(), style.metaStyle()),
              _optional(a.description, style.style()),
            ]),
        ];

      case SectionKind.volunteer:
        return [
          for (final v in section.volunteer)
            _block([
              _entryTitle(joinNonEmpty([v.role, v.organization])),
              _optional(
                joinNonEmpty([v.location, v.dateRange.format()]),
                style.metaStyle(),
              ),
              ...v.descriptions.where((d) => d.trim().isNotEmpty).map(_bullet),
            ]),
        ];

      case SectionKind.publications:
        return [
          for (final p in section.publications)
            _block([
              _entryTitle(p.title ?? ''),
              _optional(
                joinNonEmpty([p.venue, p.dateRange.format()]),
                style.metaStyle(),
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
        return [_projects(section.projects)];

      case SectionKind.custom:
        return [
          for (final e in section.customEntries)
            _block([_entryTitle(e.title), _optional(e.content, style.style())]),
        ];

      case SectionKind.personalDetails:
      case SectionKind.profile:
      case SectionKind.pageBreak:
        return const <pw.Widget>[];
    }
  }

  // -------------------------------------------------------------- primitives

  pw.Widget _text(String value, pw.TextStyle textStyle) =>
      pw.Text(style.text(value), style: textStyle, textAlign: style.bodyAlign);

  /// Stretches [child] to the available width.
  ///
  /// `pdf` clamps the infinite constraint to whatever the parent offers, so
  /// this fills the page, a column cell or an `Expanded` without overflowing,
  /// and it is what lets `textAlign` actually position text in RTL documents.
  pw.Widget _fullWidth(pw.Widget child) =>
      pw.SizedBox(width: double.infinity, child: child);

  pw.Widget _entryTitle(String value) => _text(value, style.entryStyle());

  /// A line that is skipped entirely when [value] is blank, so no empty
  /// headings or orphan separators are ever emitted.
  pw.Widget? _optional(String? value, pw.TextStyle textStyle) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return _text(trimmed, textStyle);
  }

  pw.Widget _bullet(String value) {
    final marker = pw.SizedBox(
      width: 10,
      // Through `style.text` so the bullet is substituted when only the
      // base-14 fonts are available (U+2022 is not in Latin-1).
      child: pw.Text(style.text('•'), style: style.style()),
    );
    final body = pw.Expanded(child: _text(value, style.style()));
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      // The marker sits on the reading side — left for LTR, right for RTL — so
      // it stays beside right-aligned Arabic text instead of being orphaned
      // against the opposite margin.
      children: style.rtl ? [body, marker] : [marker, body],
    );
  }

  /// A vertical stack of entry lines with the configured spacing.
  pw.Widget _block(List<pw.Widget?> children) {
    final kept = children.whereType<pw.Widget>().toList();
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: style.spacing.itemSpacing),
      child: pw.Column(
        // `stretch`, not `start`: each line only honours its `textAlign` when
        // the text box spans the full width, which is what right-aligns entry
        // titles and meta lines in a right-to-left document.
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < kept.length; i++) ...[
            kept[i],
            if (i < kept.length - 1)
              pw.SizedBox(height: style.spacing.paragraphSpacing / 2),
          ],
        ],
      ),
    );
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
            width: gallery ? (width / 2) - style.spacing.itemSpacing : width,
            child: _project(p),
          ),
      ],
    );
  }

  pw.Widget _project(ProjectEntry p) {
    final cover = style.ats ? null : _cover(p);
    final children = <pw.Widget?>[
      if (cover != null) ...[
        pw.ClipRRect(
          horizontalRadius: 4,
          verticalRadius: 4,
          child: pw.Image(cover, height: 90, fit: pw.BoxFit.cover),
        ),
        pw.SizedBox(height: 4),
      ],
      _entryTitle(p.title ?? ''),
      _optional(p.summary, style.style()),
      _optional(p.description, style.style()),
      if (p.technologies.isNotEmpty)
        _text(p.technologies.join(', '), style.metaStyle()),
      _linkLine('Demo', p.demoUrl),
      _linkLine('Source', p.sourceUrl),
      _linkLine('Website', p.websiteUrl),
    ];
    return pw.Column(
      // `stretch` so each line spans the card width and its `textAlign` can
      // right-align it in a right-to-left document.
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: children.whereType<pw.Widget>().toList(),
    );
  }

  pw.Widget? _linkLine(String label, String? url) {
    final target = url?.trim() ?? '';
    if (target.isEmpty) return null;
    final text = _text('$label: $target', style.metaStyle());
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

/// `true` when [url] may be embedded as a clickable PDF link.
///
/// Guards against malformed destinations and non-navigable schemes such as
/// `javascript:`, which `pdf` would otherwise write into the annotation.
bool isSafeExternalUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return const {'http', 'https', 'mailto', 'tel'}.contains(uri.scheme);
}
