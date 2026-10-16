/// Flattens a [ResolvedDocument] into an ordered list of text lines.
///
/// This is the reading order of the document, independent of any presentation:
/// the PDF exporters, the DOCX writer, the ATS text export, the validation
/// pass and the tests all consume it. Because it works on a *resolved*
/// document, hidden sections, hidden entries and empty sections are already
/// gone, so no caller can accidentally export them.
library;

import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/render/resolved_document.dart';
import 'package:cv_portfolio_maker/core/render/section_titles.dart';

/// One logical line of a resolved document.
class DocumentLine {
  const DocumentLine(
    this.text, {
    this.isHeading = false,
    this.level = 0,
    this.url,
    this.isBullet = false,
  });

  final String text;

  /// `true` for the document title and section headings.
  final bool isHeading;

  /// `0` document title, `1` section heading, `2` entry title, `3` body.
  final int level;

  /// Clickable target when the line represents a link.
  final String? url;

  /// `true` for free-text description lines, which export as list items.
  final bool isBullet;

  @override
  String toString() => text;
}

/// Joins the non-empty parts of [parts] with `' · '`.
String joinParts(Iterable<String?> parts, {String separator = ' · '}) {
  final kept = <String>[];
  for (final part in parts) {
    final trimmed = part?.trim();
    if (trimmed != null && trimmed.isNotEmpty) kept.add(trimmed);
  }
  return kept.join(separator);
}

/// `true` when [text] contains Arabic-block code points (either logical or
/// already-shaped presentation forms).
bool containsArabicScript(String text) {
  for (final code in text.runes) {
    if ((code >= 0x0600 && code <= 0x06FF) ||
        (code >= 0x0750 && code <= 0x077F) ||
        (code >= 0xFB50 && code <= 0xFEFF)) {
      return true;
    }
  }
  return false;
}

/// Flattens [resolved] into reading order.
List<DocumentLine> flattenDocument(
  ResolvedDocument resolved, {
  String languageCode = 'en',
}) {
  final lines = <DocumentLine>[];
  final details = resolved.details;

  final name = details.fullName?.trim();
  if (name != null && name.isNotEmpty) {
    lines.add(DocumentLine(name, isHeading: true, level: 0));
  }
  final title = details.professionalTitle?.trim();
  if (title != null && title.isNotEmpty) {
    lines.add(DocumentLine(title, level: 1));
  }
  for (final contact in resolved.contacts) {
    lines.add(DocumentLine('${contact.label}: ${contact.value}', level: 3));
  }
  final summary = resolved.summary.trim();
  if (summary.isNotEmpty) lines.add(DocumentLine(summary, level: 3));

  for (final section in resolved.sections) {
    if (section.isPageBreak) continue;
    lines.add(DocumentLine(section.title, isHeading: true, level: 1));
    _appendSection(lines, section, languageCode);
  }

  return lines.where((l) => l.text.trim().isNotEmpty).toList();
}

/// Appends the entries of one resolved section.
void _appendSection(
  List<DocumentLine> lines,
  ResolvedSection section,
  String languageCode,
) {
  switch (section.config.kind) {
    case SectionKind.experience:
      for (final e in section.experiences) {
        lines.add(
          DocumentLine(
            joinParts([e.position, e.company]),
            isHeading: true,
            level: 2,
          ),
        );
        lines.add(
          DocumentLine(
            joinParts([e.location, e.employmentType, e.dateRange.format()]),
            level: 3,
          ),
        );
        for (final d in e.descriptions) {
          if (d.trim().isNotEmpty) {
            lines.add(DocumentLine(d.trim(), level: 3, isBullet: true));
          }
        }
      }

    case SectionKind.education:
      for (final e in section.education) {
        lines.add(
          DocumentLine(
            joinParts([e.qualification, e.fieldOfStudy]),
            isHeading: true,
            level: 2,
          ),
        );
        lines.add(
          DocumentLine(
            joinParts([e.institution, e.dateRange.format()]),
            level: 3,
          ),
        );
        if (e.grade != null && e.grade!.trim().isNotEmpty) {
          lines.add(DocumentLine(e.grade!.trim(), level: 3));
        }
        if (e.description != null && e.description!.trim().isNotEmpty) {
          lines.add(DocumentLine(e.description!.trim(), level: 3));
        }
      }

    case SectionKind.skills:
      final names = section.skills
          .map((s) => (s.name ?? '').trim())
          .where((n) => n.isNotEmpty);
      if (names.isNotEmpty) lines.add(DocumentLine(names.join(', '), level: 3));

    case SectionKind.languages:
      for (final l in section.languages) {
        final level = proficiencyLabel(
          l.proficiency,
          languageCode: languageCode,
        );
        lines.add(
          DocumentLine(
            joinParts([l.name, level.isEmpty ? null : level]),
            level: 3,
          ),
        );
      }

    case SectionKind.certificates:
      for (final c in section.certificates) {
        lines.add(DocumentLine(joinParts([c.name, c.issuer]), level: 2));
        lines.add(DocumentLine(c.dateRange.format(), level: 3));
      }

    case SectionKind.courses:
      for (final c in section.courses) {
        lines.add(DocumentLine(joinParts([c.name, c.institution]), level: 2));
        lines.add(DocumentLine(c.dateRange.format(), level: 3));
      }

    case SectionKind.awards:
      for (final a in section.awards) {
        lines.add(DocumentLine(joinParts([a.name, a.issuer]), level: 2));
        lines.add(DocumentLine(a.dateRange.format(), level: 3));
        if (a.description != null && a.description!.trim().isNotEmpty) {
          lines.add(DocumentLine(a.description!.trim(), level: 3));
        }
      }

    case SectionKind.volunteer:
      for (final v in section.volunteer) {
        lines.add(DocumentLine(joinParts([v.role, v.organization]), level: 2));
        lines.add(
          DocumentLine(joinParts([v.location, v.dateRange.format()]), level: 3),
        );
        for (final d in v.descriptions) {
          if (d.trim().isNotEmpty) lines.add(DocumentLine(d.trim(), level: 3));
        }
      }

    case SectionKind.publications:
      for (final p in section.publications) {
        lines.add(DocumentLine(p.title ?? '', level: 2));
        lines.add(
          DocumentLine(joinParts([p.venue, p.dateRange.format()]), level: 3),
        );
      }

    case SectionKind.references:
      for (final r in section.references) {
        lines.add(DocumentLine(r.name ?? '', level: 2));
        lines.add(DocumentLine(r.relationship ?? '', level: 3));
        if (r.notes != null && r.notes!.trim().isNotEmpty) {
          lines.add(DocumentLine(r.notes!.trim(), level: 3));
        }
      }

    case SectionKind.projects:
      for (final p in section.projects) {
        lines.add(DocumentLine(p.title ?? '', level: 2));
        if (p.summary != null && p.summary!.trim().isNotEmpty) {
          lines.add(DocumentLine(p.summary!.trim(), level: 3));
        }
        if (p.description != null && p.description!.trim().isNotEmpty) {
          lines.add(DocumentLine(p.description!.trim(), level: 3));
        }
        if (p.technologies.isNotEmpty) {
          lines.add(DocumentLine(p.technologies.join(', '), level: 3));
        }
        if (p.demoUrl != null && p.demoUrl!.trim().isNotEmpty) {
          lines.add(DocumentLine(p.demoUrl!.trim(), level: 3, url: p.demoUrl));
        }
        if (p.sourceUrl != null && p.sourceUrl!.trim().isNotEmpty) {
          lines.add(
            DocumentLine(p.sourceUrl!.trim(), level: 3, url: p.sourceUrl),
          );
        }
      }

    case SectionKind.custom:
      for (final e in section.customEntries) {
        lines.add(DocumentLine(e.title, level: 2));
        if (e.content != null && e.content!.trim().isNotEmpty) {
          lines.add(DocumentLine(e.content!.trim(), level: 3));
        }
      }

    case SectionKind.personalDetails:
    case SectionKind.profile:
    case SectionKind.pageBreak:
      break;
  }
}

/// The flattened document as a single block of text.
String plainText(ResolvedDocument resolved, {String languageCode = 'en'}) =>
    flattenDocument(
      resolved,
      languageCode: languageCode,
    ).map((l) => l.text).join('\n');

/// `true` when the document contains Arabic text that needs a shaping font.
bool documentNeedsArabicFont(
  ResolvedDocument resolved, {
  String languageCode = 'en',
}) => containsArabicScript(plainText(resolved, languageCode: languageCode));

/// Whether the document contains any renderable content at all.
bool documentHasContent(ResolvedDocument resolved) =>
    flattenDocument(resolved).isNotEmpty;
