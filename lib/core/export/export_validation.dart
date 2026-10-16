/// Pre-export validation.
///
/// Runs on the *resolved* document, so hidden and empty content has already
/// been removed and cannot be flagged or exported by mistake. Issues are
/// reported as stable codes so the UI can localise them.
library;

import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/export/document_text.dart';
import 'package:cv_portfolio_maker/core/render/resolved_document.dart';

/// Severity of an export issue.
enum ExportIssueLevel {
  /// Informational; export can proceed unchanged.
  info,

  /// Export can proceed, but the result may not be what the user expects.
  warning,

  /// Export must not proceed.
  error,
}

/// A single validation finding.
class ExportIssue {
  const ExportIssue(this.code, this.level, {this.args});

  /// Stable identifier, also the localisation key.
  final String code;
  final ExportIssueLevel level;
  final Map<String, String>? args;

  @override
  String toString() => '$level:$code';
}

/// The outcome of validating a document for export.
class ExportValidationResult {
  const ExportValidationResult(this.issues);

  const ExportValidationResult.clean() : issues = const <ExportIssue>[];

  final List<ExportIssue> issues;

  List<ExportIssue> get errors => issues
      .where((i) => i.level == ExportIssueLevel.error)
      .toList(growable: false);

  List<ExportIssue> get warnings => issues
      .where((i) => i.level == ExportIssueLevel.warning)
      .toList(growable: false);

  bool get hasErrors => issues.any((i) => i.level == ExportIssueLevel.error);
  bool get hasWarnings =>
      issues.any((i) => i.level == ExportIssueLevel.warning);
  bool get isClean => issues.isEmpty;

  /// `true` when generation may proceed.
  bool get canExport => !hasErrors;
}

/// Above this many flattened lines the document is very likely multi-page.
const int multiPageLineThreshold = 55;

/// A single text block longer than this cannot be relied upon to fit inside one
/// column-sized page, because `pdf` cannot split a paragraph across pages.
const int oversizedTextBlockThreshold = 2000;

/// Validates that [resolved] can be exported in [mode].
///
/// [fontSupportsArabic] must be the *measured* capability of the fonts the
/// exporter will use; when the document contains Arabic and no capable font
/// could be embedded, export is blocked rather than silently emitting broken
/// text.
ExportValidationResult validateExport({
  required ResolvedDocument resolved,
  required ExportMode mode,
  bool fontSupportsArabic = true,
  bool fontsEmbedded = true,
  String languageCode = 'en',
}) {
  final issues = <ExportIssue>[];
  final lines = flattenDocument(resolved, languageCode: languageCode);

  if (lines.isEmpty) {
    issues.add(
      const ExportIssue('exportErrorNoContent', ExportIssueLevel.error),
    );
    return ExportValidationResult(issues);
  }

  final details = resolved.details;
  final name = details.fullName?.trim() ?? '';
  if (name.isEmpty) {
    issues.add(const ExportIssue('exportWarnNoName', ExportIssueLevel.warning));
  }

  final hasEmail = (details.email?.trim().isNotEmpty) ?? false;
  final hasPhone = (details.phone?.trim().isNotEmpty) ?? false;
  if (!hasEmail && !hasPhone) {
    issues.add(
      const ExportIssue('exportWarnNoContact', ExportIssueLevel.warning),
    );
  }

  if (documentNeedsArabicFont(resolved, languageCode: languageCode) &&
      !fontSupportsArabic) {
    issues.add(
      const ExportIssue('exportErrorNoArabicFont', ExportIssueLevel.error),
    );
  }

  // Tell the user when the chosen typography could not be embedded (no network
  // and nothing cached) so the standard fonts are used instead.
  if (!fontsEmbedded) {
    issues.add(const ExportIssue('exportFontsFallback', ExportIssueLevel.info));
  }

  if (mode == ExportMode.atsFriendly &&
      resolved.document.design.layoutMode != LayoutMode.one) {
    issues.add(
      const ExportIssue('exportInfoAtsSimplified', ExportIssueLevel.info),
    );
  }

  final incomplete = countIncompleteEntries(resolved);
  if (incomplete > 0) {
    issues.add(
      ExportIssue(
        'exportWarnIncompleteEntries',
        ExportIssueLevel.warning,
        args: {'count': '$incomplete'},
      ),
    );
  }

  if (lines.length > multiPageLineThreshold) {
    issues.add(
      ExportIssue(
        'exportInfoManyPages',
        ExportIssueLevel.info,
        args: {'count': '${lines.length}'},
      ),
    );
  }

  // Column layouts paginate between blocks, never inside one, so a single very
  // long paragraph cannot be split. Report it instead of letting it overflow.
  final longest = longestTextBlock(resolved, languageCode: languageCode);
  if (resolved.document.design.layoutMode != LayoutMode.one &&
      longest > oversizedTextBlockThreshold) {
    issues.add(
      ExportIssue(
        'exportWarnOversizedEntry',
        ExportIssueLevel.warning,
        args: {'count': '$longest'},
      ),
    );
  }

  return ExportValidationResult(issues);
}

/// The length of the longest single text block in the document.
///
/// These blocks are the smallest units the PDF exporter can place, so they are
/// also the units that cannot be split across a page boundary.
int longestTextBlock(ResolvedDocument resolved, {String languageCode = 'en'}) {
  var longest = 0;
  for (final line in flattenDocument(resolved, languageCode: languageCode)) {
    if (line.text.length > longest) longest = line.text.length;
  }
  return longest;
}

/// Counts entries that are missing the field that would identify them.
///
/// These entries are still exported (content is never dropped), but the user is
/// warned so they can fill the gap.
int countIncompleteEntries(ResolvedDocument resolved) {
  var count = 0;
  for (final section in resolved.sections) {
    switch (section.config.kind) {
      case SectionKind.experience:
        count += section.experiences
            .where((e) => (e.position ?? '').trim().isEmpty)
            .length;
      case SectionKind.education:
        count += section.education
            .where((e) => joinParts([e.qualification, e.institution]).isEmpty)
            .length;
      case SectionKind.certificates:
        count += section.certificates
            .where((c) => c.name.trim().isEmpty)
            .length;
      case SectionKind.courses:
        count += section.courses
            .where((c) => (c.name ?? '').trim().isEmpty)
            .length;
      case SectionKind.awards:
        count += section.awards
            .where((a) => (a.name ?? '').trim().isEmpty)
            .length;
      case SectionKind.projects:
        count += section.projects
            .where((p) => (p.title ?? '').trim().isEmpty)
            .length;
      case SectionKind.publications:
        count += section.publications
            .where((p) => (p.title ?? '').trim().isEmpty)
            .length;
      case SectionKind.languages:
        count += section.languages.where((l) => l.name.trim().isEmpty).length;
      case SectionKind.skills:
      case SectionKind.volunteer:
      case SectionKind.references:
      case SectionKind.custom:
      case SectionKind.personalDetails:
      case SectionKind.profile:
      case SectionKind.pageBreak:
        break;
    }
  }
  return count;
}
