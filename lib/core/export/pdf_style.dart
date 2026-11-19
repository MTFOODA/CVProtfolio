/// Maps the application's [DocumentDesign] onto `pdf` package primitives.
///
/// This is the single translation point between the saved design configuration
/// and the PDF representation, so the editor preview, the public viewer and the
/// exporters all agree on what "primary colour" or "section spacing" means.
library;

import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

import 'package:cv_portfolio_maker/core/domain/document_models.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/export/arabic_text.dart';
import 'package:cv_portfolio_maker/core/export/base_font_text.dart';
import 'package:cv_portfolio_maker/core/export/export_fonts.dart';

/// Resolved styling values for one PDF export.
class PdfStyle {
  PdfStyle({
    required this.design,
    required this.fonts,
    this.nameFonts,
    required this.ats,
  });

  final DocumentDesign design;
  final ExportFontSet fonts;
  final ExportFontSet? nameFonts;

  /// `true` for the ATS-friendly output, which trades styling for
  /// machine-readability (no accent colour, no images, no divider ornaments).
  final bool ats;

  TypographyConfig get typography => design.typography;
  ColorConfig get colorConfig => design.colors;
  SpacingConfig get spacing => design.spacing;
  PresentationConfig get presentation => design.presentation;

  /// Effective reading direction. ATS output is always left-to-right: a
  /// reversed canvas would confuse a text extractor's reading order.
  bool get rtl => design.isRtl && !ats;

  pdf.PdfColor get paper => pdf.PdfColor.fromInt(colorConfig.paper);
  pdf.PdfColor get headingColor =>
      pdf.PdfColor.fromInt(colorConfig.headingText);
  pdf.PdfColor get bodyColor => pdf.PdfColor.fromInt(colorConfig.bodyText);
  pdf.PdfColor get accentColor =>
      pdf.PdfColor.fromInt(ats ? colorConfig.headingText : colorConfig.accent);
  pdf.PdfColor get dividerColor => pdf.PdfColor.fromInt(colorConfig.divider);
  pdf.PdfColor get secondaryColor =>
      pdf.PdfColor.fromInt(colorConfig.secondary);
  pdf.PdfColor get projectChipColor => pdf.PdfColor(
    accentColor.red * .12 + paper.red * .88,
    accentColor.green * .12 + paper.green * .88,
    accentColor.blue * .12 + paper.blue * .88,
  );

  /// Page geometry for the configured page size and orientation.
  pdf.PdfPageFormat get pageFormat {
    final base = switch (design.page.pageSize) {
      'letter' => pdf.PdfPageFormat.letter,
      'legal' => pdf.PdfPageFormat.legal,
      _ => pdf.PdfPageFormat.a4,
    };
    return design.page.portrait
        ? base
        : pdf.PdfPageFormat(base.height, base.width);
  }

  /// Page margin in points.
  double get margin => spacing.resolvedHorizontalMargin;
  double get verticalMargin => spacing.resolvedVerticalMargin;

  /// Left column ratio, clamped exactly like the on-screen layout engine.
  double get leftRatio {
    final ratio = spacing.leftColumnRatio;
    if (!ratio.isFinite) return 0.5;
    return ratio.clamp(0.25, 0.75).toDouble();
  }

  /// Prepares [input] for painting: shapes Arabic and reorders RTL text.
  ///
  /// When only the base-14 fonts could be resolved it also replaces the
  /// characters those fonts cannot draw, so the page never shows `.notdef`
  /// boxes. Embedded TrueType fonts keep the original characters.
  String text(String input, {bool? rtlBase}) {
    final prepared = prepareForPdf(input, rtlBase: rtlBase ?? rtl);
    return fonts.isFallback ? transliterateForBaseFonts(prepared) : prepared;
  }

  /// The document theme, wiring every font weight and the Arabic fallback.
  pw.ThemeData theme() => pw.ThemeData.withFont(
    base: fonts.regular,
    bold: fonts.bold,
    italic: fonts.italic,
    boldItalic: fonts.boldItalic,
    fontFallback: fonts.fallback,
  );

  /// A body text style, optionally overridden.
  pw.TextStyle style({
    bool bold = false,
    bool italic = false,
    double? size,
    pdf.PdfColor? color,
    double? letterSpacing,
    double? height,
  }) => pw.TextStyle(
    font: bold ? fonts.bold : (italic ? fonts.italic : fonts.regular),
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
    fontSize: size ?? typography.bodyFontSize,
    lineSpacing:
        ((height ?? typography.bodyLineHeight) - 1) *
        (size ?? typography.bodyFontSize),
    color: color ?? bodyColor,
    letterSpacing: letterSpacing ?? 0,
  );

  /// Style for a section heading.
  pw.TextStyle sectionStyle() => style(
    bold: true,
    size: typography.sectionTitleFontSize * typography.headingScale,
    color: ats ? accentColor : headingColor,
    letterSpacing: typography.headingLetterSpacing,
    height: typography.headingLineHeight,
  );

  /// Style for the document title (the person's name).
  pw.TextStyle nameStyle() =>
      style(
        bold: true,
        size: typography.headingFontSize * typography.headingScale,
        color: headingColor,
        height: typography.headingLineHeight,
        letterSpacing: typography.headingLetterSpacing,
      ).copyWith(
        fontNormal: (nameFonts ?? fonts).regular,
        fontBold: (nameFonts ?? fonts).bold,
        fontItalic: (nameFonts ?? fonts).italic,
        fontBoldItalic: (nameFonts ?? fonts).boldItalic,
      );

  /// Style for the professional title under the name.
  pw.TextStyle subtitleStyle() => style(
    bold: true,
    size: typography.resolvedProfessionalTitleFontSize,
    color: secondaryColor,
  );

  /// Style for an entry heading such as a job title.
  pw.TextStyle entryStyle() =>
      style(bold: true, size: typography.resolvedEntryHeaderFontSize);

  /// Style for supporting text under an entry.
  pw.TextStyle metaStyle() =>
      style(size: typography.bodyFontSize, color: secondaryColor);

  pw.TextStyle dateStyle() =>
      style(size: typography.resolvedDateFontSize, color: secondaryColor);

  /// Applies the configured casing to a section heading.
  String sectionTitle(String title) =>
      typography.uppercaseSectionTitles ? title.toUpperCase() : title;

  /// A separator honouring the configured divider style.
  pw.Widget divider() {
    if (ats || presentation.dividerStyle == DividerStyle.none) {
      return pw.SizedBox.shrink();
    }
    if (presentation.dividerStyle == DividerStyle.dotted) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (var i = 0; i < 40; i++)
              pw.Container(
                width: 4,
                height: 4,
                decoration: pw.BoxDecoration(
                  color: dividerColor,
                  shape: pw.BoxShape.circle,
                ),
              ),
          ],
        ),
      );
    }
    if (presentation.dividerStyle == DividerStyle.gradient) {
      return pw.Container(
        height: 2,
        margin: const pw.EdgeInsets.symmetric(vertical: 4),
        decoration: pw.BoxDecoration(
          gradient: pw.LinearGradient(
            colors: [dividerColor, accentColor, dividerColor],
          ),
        ),
      );
    }
    final thick = presentation.dividerStyle == DividerStyle.thick;
    return pw.Container(
      height: thick ? 3 : 1,
      color: dividerColor,
      margin: const pw.EdgeInsets.symmetric(vertical: 4),
    );
  }

  /// Corner radius used for the profile photo, in points.
  double avatarRadius() => switch (presentation.avatarShape) {
    AvatarShape.circle => 1000,
    AvatarShape.roundedSquare => 8,
    AvatarShape.square || AvatarShape.hidden => 0,
  };

  /// Whether a profile image should be embedded at all.
  bool get showAvatar => !ats && presentation.avatarShape != AvatarShape.hidden;

  /// Alignment applied to body text in RTL documents.
  pw.TextAlign get bodyAlign => rtl ? pw.TextAlign.right : pw.TextAlign.left;
}
