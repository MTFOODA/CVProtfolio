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

import 'package:cv_portfolio_maker/core/branding/app_branding.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/export/export_fonts.dart';
import 'package:cv_portfolio_maker/core/export/pdf_sections.dart';
import 'package:cv_portfolio_maker/core/export/pdf_style.dart';
import 'package:cv_portfolio_maker/core/render/document_layout.dart';
import 'package:cv_portfolio_maker/core/render/resolved_document.dart';

import '../render/section_titles.dart';
import '../utils/contact_links.dart';

/// Everything needed to build one PDF.
class PdfBuildRequest {
  const PdfBuildRequest({
    required this.resolved,
    required this.mode,
    required this.fonts,
    this.nameFonts,
    this.images,
    this.languageCode = 'en',
  });

  /// A document already resolved for [mode] (ATS uses `atsFriendly: true`, so
  /// the saved design is never mutated).
  final ResolvedDocument resolved;
  final ExportMode mode;
  final ExportFontSet fonts;
  final ExportFontSet? nameFonts;
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
      nameFonts: request.nameFonts,
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
      creator: kAppDisplayName,
      producer: kAppDisplayName,
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
          margin: pw.EdgeInsets.symmetric(
            horizontal: style.margin,
            vertical: style.verticalMargin,
          ),
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

    final align = style.presentation.headerStyle == 'center'
        ? pw.CrossAxisAlignment.center
        : style.rtl
        ? pw.CrossAxisAlignment.end
        : pw.CrossAxisAlignment.start;
    final avatar = renderer.avatarWidget(details);
    final identityChildren = <pw.Widget>[
      if (name.isNotEmpty)
        pw.Text(
          style.text(name),
          style: style.nameStyle(),
          textAlign: style.presentation.headerStyle == 'center'
              ? pw.TextAlign.center
              : style.bodyAlign,
        ),
      if (title.isNotEmpty)
        pw.Text(
          style.text(title),
          style: style.subtitleStyle(),
          textAlign: style.presentation.headerStyle == 'center'
              ? pw.TextAlign.center
              : style.bodyAlign,
        ),
    ];
    final identity = style.presentation.identityArrangement == 'inline'
        ? pw.Wrap(
            spacing: 10,
            runSpacing: 4,
            alignment: style.presentation.headerStyle == 'center'
                ? pw.WrapAlignment.center
                : pw.WrapAlignment.start,
            crossAxisAlignment: pw.WrapCrossAlignment.center,
            children: identityChildren,
          )
        : pw.Column(crossAxisAlignment: align, children: identityChildren);
    final headerWidth = style.pageFormat.width - style.margin * 2;
    final innerWidth =
        headerWidth - (avatar == null ? 0 : style.presentation.avatarSize + 10);
    final contactBlock = _contacts(
      contacts,
      style,
      availableWidth: style.presentation.headerStyle == 'center'
          ? headerWidth
          : style.presentation.headerStyle == 'split'
          ? innerWidth / 2
          : innerWidth,
    );

    final pw.Widget head = switch (style.presentation.headerStyle) {
      'center' => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
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
          if (contacts.isNotEmpty) pw.Expanded(child: contactBlock),
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
  pw.Widget _contacts(
    List<ResolvedContact> contacts,
    PdfStyle style, {
    double? availableWidth,
  }) => pw.Directionality(
    textDirection: style.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
    child: _contactDetails(contacts, style, availableWidth: availableWidth),
  );

  pw.Widget _contactDetails(
    List<ResolvedContact> contacts,
    PdfStyle style, {
    double? availableWidth,
  }) {
    final width = availableWidth ?? style.pageFormat.width - style.margin * 2;
    final center = style.presentation.headerStyle == 'center';
    pw.Widget item(ResolvedContact contact, double maxWidth) {
      final decorated = style.presentation.contactIconStyle != 'plain';
      final brand = contactBrandCodes[contact.label];
      final icon = brand == null ? style.fonts.iconFont : style.fonts.brandFont;
      final widget = pw.SizedBox(
        width: maxWidth,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (style.presentation.showContactIcons &&
                icon != null &&
                !style.ats) ...[
              pw.Container(
                padding: pw.EdgeInsets.all(decorated ? 2 : 0),
                decoration: decorated
                    ? pw.BoxDecoration(
                        border: pw.Border.all(
                          color: style.secondaryColor,
                          width: .4,
                        ),
                        borderRadius: pw.BorderRadius.circular(
                          style.presentation.contactIconStyle == 'circle'
                              ? 30
                              : style.presentation.contactIconStyle == 'rounded'
                              ? 3
                              : 0,
                        ),
                      )
                    : null,
                child: pw.Text(
                  String.fromCharCode(
                    brand ?? contactIconCodes[contact.label] ?? 0xe157,
                  ),
                  textDirection: pw.TextDirection.ltr,
                  style: pw.TextStyle(
                    font: icon,
                    fontNormal: icon,
                    fontBold: icon,
                    fontItalic: icon,
                    fontBoldItalic: icon,
                    fontSize: style.presentation.resolvedContactIconSize(
                      style.typography.bodyFontSize,
                    ),
                    color: style.secondaryColor,
                  ),
                ),
              ),
              pw.SizedBox(width: 4),
            ],
            pw.Expanded(
              child: pw.Text(
                style.text(contact.text(), rtlBase: false),
                // Text is already shaped; Directionality only controls the row.
                textDirection: pw.TextDirection.ltr,
                style: style.metaStyle(),
                textAlign: center ? pw.TextAlign.center : style.bodyAlign,
              ),
            ),
          ],
        ),
      );
      return contact.url == null
          ? widget
          : pw.UrlLink(destination: contact.url!, child: widget);
    }

    final arrangement = style.presentation.resolvedContactArrangement;
    pw.Widget row(List<ResolvedContact> values) => pw.Wrap(
      alignment: center ? pw.WrapAlignment.center : pw.WrapAlignment.start,
      spacing: 10,
      runSpacing: 4,
      children: [
        for (final c in values)
          item(
            c,
            (c.text().length * style.typography.bodyFontSize * .55 +
                    (style.presentation.showContactIcons
                        ? style.presentation.resolvedContactIconSize(
                                style.typography.bodyFontSize,
                              ) +
                              8
                        : 0))
                .clamp(60.0, width)
                .toDouble(),
          ),
      ],
    );
    if (arrangement == 'compact' || arrangement == 'oneRow') {
      return row(contacts);
    }
    if (arrangement == 'twoRows') {
      final middle = (contacts.length / 2).ceil();
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          row(contacts.take(middle).toList()),
          pw.SizedBox(height: 4),
          row(contacts.skip(middle).toList()),
        ],
      );
    }
    if (arrangement == 'grid') {
      return pw.Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [for (final c in contacts) item(c, (width - 12) / 2)],
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        for (final c in contacts)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: item(c, width),
          ),
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
