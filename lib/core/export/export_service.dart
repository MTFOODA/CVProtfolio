/// Orchestrates document export: resolution, fonts, validation, PDF bytes and
/// filenames.
///
/// Lives on top of the existing repository boundary: callers pass the
/// [CvDocument] and [UserProfile] they already loaded through the authorised
/// repository, so exporting never opens a new data path and never touches
/// another owner's records.
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/export/document_text.dart';
import 'package:cv_portfolio_maker/core/export/docx_builder.dart';
import 'package:cv_portfolio_maker/core/export/export_fonts.dart';
import 'package:cv_portfolio_maker/core/export/export_validation.dart';
import 'package:cv_portfolio_maker/core/export/pdf_builder.dart';
import 'package:cv_portfolio_maker/core/export/pdf_sections.dart';
import 'package:cv_portfolio_maker/core/render/resolved_document.dart';
import 'package:cv_portfolio_maker/core/render/section_titles.dart';

/// Raised when an export cannot be produced.
///
/// [messageKey] is a localisation key, never a raw exception string, so nothing
/// sensitive can leak into the UI.
class ExportException implements Exception {
  const ExportException(this.messageKey, {this.args});

  final String messageKey;
  final Map<String, String>? args;

  @override
  String toString() => 'ExportException($messageKey)';
}

/// Fetches raw bytes for a remote image (profile photo, project cover).
typedef ImageBytesLoader = Future<Uint8List?> Function(String url);

/// The maximum image size embedded into a PDF (8 MiB).
const int maxEmbeddedImageBytes = 8 * 1024 * 1024;

/// A produced export.
class ExportResult {
  const ExportResult({
    required this.bytes,
    required this.fileName,
    required this.mode,
    required this.validation,
    required this.fonts,
    required this.pageCount,
  });

  final Uint8List bytes;
  final String fileName;
  final ExportMode mode;
  final ExportValidationResult validation;
  final ExportFontSet fonts;

  /// Number of pages actually written into the PDF.
  final int pageCount;
}

/// Produces PDF files for a document.
class DocumentExporter {
  DocumentExporter({
    ExportFontSource? fonts,
    PdfDocumentBuilder? builder,
    ImageBytesLoader? imageLoader,
  }) : _fonts = fonts ?? GoogleFontSource(),
       _builder = builder ?? const PdfDocumentBuilder(),
       _images = imageLoader;

  final ExportFontSource _fonts;
  final PdfDocumentBuilder _builder;
  final ImageBytesLoader? _images;

  /// Resolves [document] for [mode] without mutating the saved design.
  ResolvedDocument resolveFor({
    required CvDocument document,
    required UserProfile profile,
    required ExportMode mode,
    required String languageCode,
  }) => ResolvedDocument.resolve(
    document: document,
    profile: profile,
    defaultTitle: defaultTitleResolver(languageCode),
    atsFriendly: mode == ExportMode.atsFriendly,
  );

  /// Loads the fonts [document] needs and validates it for [mode].
  Future<ExportValidationResult> validate({
    required CvDocument document,
    required UserProfile profile,
    required ExportMode mode,
    String languageCode = 'en',
  }) async {
    final resolved = resolveFor(
      document: document,
      profile: profile,
      mode: mode,
      languageCode: languageCode,
    );
    final fonts = await _fonts.load(
      headingFont: resolved.design.typography.headingFont,
      needsArabic: documentNeedsArabicFont(
        resolved,
        languageCode: languageCode,
      ),
    );
    return validateExport(
      resolved: resolved,
      mode: mode,
      fontSupportsArabic: fonts.supportsArabic,
      fontsEmbedded: !fonts.isFallback,
      languageCode: languageCode,
    );
  }

  /// Generates the PDF for [document] in [mode].
  ///
  /// Throws [ExportException] when validation blocks the export, and maps font
  /// rendering failures to `exportErrorFont` so the UI can explain that a
  /// script could not be rendered instead of writing a broken file.
  Future<ExportResult> export({
    required CvDocument document,
    required UserProfile profile,
    required ExportMode mode,
    String languageCode = 'en',
  }) async {
    final resolved = resolveFor(
      document: document,
      profile: profile,
      mode: mode,
      languageCode: languageCode,
    );
    final fonts = await _fonts.load(
      headingFont: resolved.design.typography.headingFont,
      needsArabic: documentNeedsArabicFont(
        resolved,
        languageCode: languageCode,
      ),
    );

    final validation = validateExport(
      resolved: resolved,
      mode: mode,
      fontSupportsArabic: fonts.supportsArabic,
      fontsEmbedded: !fonts.isFallback,
      languageCode: languageCode,
    );
    if (!validation.canExport) {
      final blocking = validation.errors.first;
      throw ExportException(blocking.code, args: blocking.args);
    }

    final images = await _prefetchImages(resolved);

    final PdfBuildResult built;
    try {
      built = await _builder.build(
        PdfBuildRequest(
          resolved: resolved,
          mode: mode,
          fonts: fonts,
          images: images,
          languageCode: languageCode,
        ),
      );
    } on pdf.PdfException {
      throw const ExportException('exportErrorFont');
    } on ExportException {
      rethrow;
    } on Object {
      throw const ExportException('exportErrorGeneric');
    }

    return ExportResult(
      bytes: built.bytes,
      fileName: exportFileName(document.title, mode),
      mode: mode,
      validation: validation,
      fonts: fonts,
      pageCount: built.pageCount,
    );
  }

  /// Downloads every image the document references, tolerating failures.
  ///
  /// Missing, oversized or unsupported images are skipped: a broken avatar must
  /// never fail an export or leak a storage URL into the PDF.
  Future<ImageLookup?> _prefetchImages(ResolvedDocument resolved) async {
    final loader = _images;
    if (loader == null) return null;

    final urls = <String>{};
    final avatar = resolved.details.avatarUrl?.trim() ?? '';
    if (avatar.isNotEmpty) urls.add(avatar);
    for (final section in resolved.sections) {
      for (final project in section.projects) {
        for (final media in project.media) {
          final trimmed = media.trim();
          if (trimmed.isNotEmpty) urls.add(trimmed);
        }
      }
    }
    if (urls.isEmpty) return null;

    final cache = <String, pw.MemoryImage>{};
    for (final url in urls) {
      try {
        final bytes = await loader(url);
        if (bytes == null || bytes.isEmpty) continue;
        if (bytes.length > maxEmbeddedImageBytes) continue;
        cache[url] = pw.MemoryImage(bytes);
      } on Object {
        continue;
      }
    }
    if (cache.isEmpty) return null;
    return (url) => cache[url];
  }

  /// Generates an editable `.docx` for [document].
  ///
  /// Reuses the same resolved content as the PDF exporters, so hidden sections
  /// and hidden entries are excluded identically. Arabic needs no font probe
  /// here: DOCX stores Unicode text and Word performs the shaping itself.
  Future<({Uint8List bytes, String fileName})> exportDocx({
    required CvDocument document,
    required UserProfile profile,
    String languageCode = 'en',
  }) async {
    final resolved = resolveFor(
      document: document,
      profile: profile,
      mode: ExportMode.designed,
      languageCode: languageCode,
    );
    final validation = validateExport(
      resolved: resolved,
      mode: ExportMode.designed,
      fontSupportsArabic: true,
      languageCode: languageCode,
    );
    if (!validation.canExport) {
      final blocking = validation.errors.first;
      throw ExportException(blocking.code, args: blocking.args);
    }
    return (
      bytes: const DocxDocumentBuilder().build(
        DocxBuildRequest(resolved: resolved, languageCode: languageCode),
      ),
      fileName: docxFileName(document.title),
    );
  }
}

/// Builds a filesystem-safe file name for the exported document.
String exportFileName(String title, ExportMode mode) {
  final base = sanitiseFileName(title);
  final suffix = mode == ExportMode.atsFriendly ? 'ATS' : 'Designed';
  return '$base-$suffix.pdf';
}

/// Builds a filesystem-safe `.docx` file name.
String docxFileName(String title) => '${sanitiseFileName(title)}-Editable.docx';

/// Strips path separators, control characters and whitespace from a name.
String sanitiseFileName(String input) {
  final cleaned = input
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '-')
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp('-{2,}'), '-')
      .replaceAll(RegExp(r'^[-.]+'), '')
      .replaceAll(RegExp(r'[-.]+$'), '');
  if (cleaned.isEmpty) return 'document';
  return cleaned.length <= 60 ? cleaned : cleaned.substring(0, 60);
}
