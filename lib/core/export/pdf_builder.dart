/// Assembles a PDF from a resolved document and a design configuration.
///
/// The exporter never screenshots the Flutter preview: it walks structured
/// content and emits real PDF text, which is what makes the result selectable,
/// searchable and ATS-extractable.
///
/// Pagination strategy
/// -------------------
/// A single-column document flows through `MultiPage` and paginates naturally.
/// Two-column and mixed documents use `Table`, whose rows may be split across
/// pages; sections are paired row-by-row so nothing is ever clipped. A section
/// taller than one page therefore spans pages only in single-column layouts,
/// which is the standard compromise for generative PDF layout.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/export/export_fonts.dart';
import 'package:cv_portfolio_maker/core/export/pdf_sections.dart';
import 'package:cv_portfolio_maker/core/export/pdf_style.dart';
import 'package:cv_portfolio_maker/core/render/document_layout.dart';
import 'package:cv_portfolio_maker/core/render/resolved_document.dart';

/// Everything needed to build one PDF.
class PdfBuildRequest {
  const PdfBuildRequest({
    required this.resolved,
    required this.mode,
    required this.fonts,
    this.images,
    this.languageCode = 'en',
  });

  /// A document already resolved for [mode] (ATS uses `atsFriendly: true`, so
  /// the saved design is never mutated).
  final ResolvedDocument resolved;
  final ExportMode mode;
  final ExportFontSet fonts;
  final ImageLookup? images;
  final String languageCode;
}

/// The result of building a PDF.
class PdfBuildResult {
  const PdfBuildResult({required this.bytes, required this.pageCount});

  final Uint8List bytes;

  /// Pages actually emitted, read from the generated document (not estimated).
  final int pageCount;
}

/// Builds PDF bytes.
class PdfDocumentBuilder {
  const PdfDocumentBuilder();

  /// Generates the PDF for [request].
  Future<PdfBuildResult> build(PdfBuildRequest request) async {
    final resolved = request.resolved;
    final style = PdfStyle(
      design: resolved.design,
      fonts: request.fonts,
      ats: request.mode == ExportMode.atsFriendly,
    );
    final renderer = SectionRenderer(
      style: style,
      width: _contentWidth(style),
      images: request.images,
    );

    final document = pw.Document(
      title: resolved.document.title,
      author: resolved.details.fullName ?? resolved.document.title,
      creator: 'CV & Portfolio Studio',
      producer: 'CV & Portfolio Studio',
      subject: resolved.document.type == DocumentType.portfolio
          ? 'Portfolio'
          : 'Curriculum Vitae',
      theme: style.theme(),
      compress: true,
    );

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: style.pageFormat,
          margin: pw.EdgeInsets.all(style.margin),
          theme: style.theme(),
        ),
        header: (context) => _runningHeader(style),
        footer: (context) =>
            _runningFooter(style, context.pageNumber, context.pagesCount),
        maxPages: 200,
        build: (context) =>
            _flow(resolved, style, renderer, _contentWidth(style)),
      ),
    );

    return PdfBuildResult(
      bytes: await document.save(),
      pageCount: document.document.pdfPageList.pages.length,
    );
  }

  double _contentWidth(PdfStyle style) =>
      style.pageFormat.width - (style.margin * 2);

  // ------------------------------------------------------------------- flow

  /// Builds the page content, honouring explicit page breaks in every layout.
  List<pw.Widget> _flow(
    ResolvedDocument resolved,
    PdfStyle style,
    SectionRenderer renderer,
    double width,
  ) {
    final widgets = <pw.Widget>[];
    final header = _documentHeader(resolved, style, renderer);
    if (header != null) widgets.add(header);

    // Split the section list on explicit page breaks.
    final groups = <List<ResolvedSection>>[];
    var current = <ResolvedSection>[];
    for (final section in resolved.sections) {
      if (section.isPageBreak) {
        groups.add(current);
        current = <ResolvedSection>[];
        continue;
      }
      current.add(section);
    }
    groups.add(current);

    final populated = groups.where((g) => g.isNotEmpty).toList();
    for (var i = 0; i < populated.length; i++) {
      if (i > 0) widgets.add(pw.NewPage());
      widgets.addAll(_layoutGroup(populated[i], style, renderer, width));
    }
    return widgets;
  }

  /// Lays out one group of sections (no page breaks inside) per layout mode.
  List<pw.Widget> _layoutGroup(
    List<ResolvedSection> sections,
    PdfStyle style,
    SectionRenderer renderer,
    double width,
  ) {
    if (sections.isEmpty) return const <pw.Widget>[];

    switch (style.design.layoutMode) {
      case LayoutMode.one:
        return [for (final section in sections) ...renderer.build(section)];

      case LayoutMode.two:
        final buckets = twoColumnBuckets(sections);
        if (!buckets.hasColumns) {
          return [for (final section in sections) ...renderer.build(section)];
        }
        return [_columnsTable(buckets.left, buckets.right, style, renderer)];

      case LayoutMode.mix:
        final widgets = <pw.Widget>[];
        for (final row in buildMixRows(sections)) {
          if (row.isFullWidth) {
            for (final section in row.full) {
              widgets.addAll(renderer.build(section));
            }
          } else {
            widgets.add(_columnsTable(row.left, row.right, style, renderer));
          }
        }
        return widgets;
    }
  }

  /// A two-column band.
  ///
  /// The two columns are fanned out into their individual widgets and paired
  /// row by row. `pdf` can only split a `Table` *between* rows, so a cell that
  /// holds a whole section makes that section unsplittable: anything taller than
  /// a page would overflow and be clipped. With one widget per row the band
  /// paginates at section-heading and entry granularity, so long sections flow
  /// onto the next page instead of disappearing.
  ///
  /// The smallest indivisible unit is a single entry (its title, meta line and
  /// description lines are one widget). An entry alone taller than a page cannot
  /// be split and is reported by `validateExport` as `exportWarnOversizedEntry`.
  pw.Widget _columnsTable(
    List<ResolvedSection> left,
    List<ResolvedSection> right,
    PdfStyle style,
    SectionRenderer renderer,
  ) {
    final leftWidgets = <pw.Widget>[
      for (final section in left) ...renderer.build(section),
    ];
    final rightWidgets = <pw.Widget>[
      for (final section in right) ...renderer.build(section),
    ];

    final rows = <pw.TableRow>[];
    final count = math.max(leftWidgets.length, rightWidgets.length);
    final halfGap = style.spacing.columnGap / 2;
    for (var i = 0; i < count; i++) {
      rows.add(
        pw.TableRow(
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.only(right: halfGap),
              child: i < leftWidgets.length
                  ? leftWidgets[i]
                  : pw.SizedBox.shrink(),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.only(left: halfGap),
              child: i < rightWidgets.length
                  ? rightWidgets[i]
                  : pw.SizedBox.shrink(),
            ),
          ],
        ),
      );
    }
    return pw.Table(
      columnWidths: {
        0: pw.FractionColumnWidth(style.leftRatio),
        1: pw.FractionColumnWidth(1 - style.leftRatio),
      },
      children: rows,
    );
  }

  // ---------------------------------------------------------------- header

  /// The document's own header: name, title, contacts, avatar and summary.
  pw.Widget? _documentHeader(
    ResolvedDocument resolved,
    PdfStyle style,
    SectionRenderer renderer,
  ) {
    final details = resolved.details;
    final name = details.fullName?.trim() ?? '';
    final title = details.professionalTitle?.trim() ?? '';
    final contacts = resolved.contacts;
    final summary = resolved.summary.trim();
    if (name.isEmpty && title.isEmpty && contacts.isEmpty && summary.isEmpty) {
      return null;
    }

    final align = style.rtl
        ? pw.CrossAxisAlignment.end
        : pw.CrossAxisAlignment.start;
    final avatar = renderer.avatarWidget(details);
    final identity = pw.Column(
      crossAxisAlignment: align,
      children: [
        if (name.isNotEmpty)
          pw.Text(style.text(name), style: style.nameStyle()),
        if (title.isNotEmpty)
          pw.Text(style.text(title), style: style.subtitleStyle()),
      ],
    );
    final contactBlock = _contacts(contacts, style);

    final pw.Widget head = switch (style.presentation.headerStyle) {
      'center' => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (avatar != null) ...[avatar, pw.SizedBox(height: 6)],
          identity,
          if (contacts.isNotEmpty) ...[pw.SizedBox(height: 6), contactBlock],
        ],
      ),
      'split' => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (avatar != null) ...[avatar, pw.SizedBox(width: 10)],
          pw.Expanded(child: identity),
          if (contacts.isNotEmpty) contactBlock,
        ],
      ),
      _ => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (avatar != null) ...[avatar, pw.SizedBox(width: 10)],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: align,
              children: [
                identity,
                if (contacts.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  contactBlock,
                ],
              ],
            ),
          ),
        ],
      ),
    };

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        head,
        if (summary.isNotEmpty) ...[
          pw.SizedBox(height: style.spacing.itemSpacing),
          pw.Text(
            style.text(summary),
            style: style.style(),
            textAlign: style.bodyAlign,
          ),
        ],
        pw.SizedBox(height: style.spacing.sectionSpacing),
      ],
    );
  }

  /// Contact details, always including the label so the information survives
  /// text extraction and is never conveyed by an icon alone.
  pw.Widget _contacts(List<ResolvedContact> contacts, PdfStyle style) {
    final items = [for (final c in contacts) '${c.label}: ${c.value}'];
    if (items.isEmpty) return pw.SizedBox.shrink();
    final align = style.rtl
        ? pw.CrossAxisAlignment.end
        : pw.CrossAxisAlignment.start;
    if (style.presentation.contactInline &&
        style.presentation.showContactIcons) {
      return pw.Wrap(
        spacing: 10,
        runSpacing: 2,
        children: [
          for (final item in items)
            pw.Text(style.text(item), style: style.metaStyle()),
        ],
      );
    }
    return pw.Column(
      crossAxisAlignment: align,
      children: [
        for (final item in items)
          pw.Text(style.text(item), style: style.metaStyle()),
      ],
    );
  }

  // ----------------------------------------------------------- running bands

  /// Optional running header text.
  pw.Widget _runningHeader(PdfStyle style) {
    final page = style.design.page;
    final text = page.headerText?.trim() ?? '';
    if (!page.showHeader || text.isEmpty) return pw.SizedBox.shrink();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        style.text(text),
        style: style.metaStyle(),
        textAlign: style.bodyAlign,
      ),
    );
  }

  /// Optional footer text plus page numbering.
  pw.Widget _runningFooter(PdfStyle style, int pageNumber, int pagesCount) {
    final page = style.design.page;
    final footerText = page.footerText?.trim() ?? '';
    final parts = <pw.Widget>[];
    if (page.showFooter && footerText.isNotEmpty) {
      parts.add(
        pw.Expanded(
          child: pw.Text(style.text(footerText), style: style.metaStyle()),
        ),
      );
    }
    if (page.showPageNumbers) {
      parts.add(
        pw.Text(
          '$pageNumber / $pagesCount',
          style: style.metaStyle(),
          textAlign: style.bodyAlign,
        ),
      );
    }
    if (parts.isEmpty) return pw.SizedBox.shrink();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: parts,
      ),
    );
  }
}
