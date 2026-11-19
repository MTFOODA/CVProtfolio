import '../domain/document_models.dart';

/// Supported offline font families shared by Flutter, PDF and Word.
const cvFontNames = <String, String>{
  'inter': 'Inter',
  'lora': 'Lora',
  'roboto': 'Roboto',
  'notoNaskhArabic': 'Noto Naskh Arabic',
};
const cvFontAssets = <String, (String, String)>{
  'inter': ('Inter-Regular.ttf', 'Inter-Bold.ttf'),
  'lora': ('Lora-Regular.ttf', 'Lora-Bold.ttf'),
  'roboto': ('Roboto-Regular.ttf', 'Roboto-Bold.ttf'),
  'notoNaskhArabic': (
    'NotoNaskhArabic-Regular.ttf',
    'NotoNaskhArabic-Regular.ttf',
  ),
};
const cvIconAsset = 'assets/google_fonts/ContactIcons-Regular.ttf';
const pointsPerMm = 72 / 25.4;

/// Control metadata, never a second copy of the document's design.
enum CvDesignValue {
  body('Base Font Size', 8, 16, .5),
  name('Full Name', 14, 40, .5),
  title('Professional Title', 8, 24, .5),
  section('Section Headings', 9, 24, .5),
  entry('Entry Header', 8, 20, .5),
  line('Line Height', 1, 1.8, .05),
  elements('Space Between Elements', 0, 24, 1),
  horizontal('Left & Right Margin', 8, 32, 1),
  vertical('Top & Bottom Margin', 8, 32, 1);

  const CvDesignValue(this.label, this.min, this.max, this.step);
  final String label;
  final double min;
  final double max;
  final double step;
  double read(DocumentDesign d) => switch (this) {
    body => d.typography.bodyFontSize,
    name => d.typography.headingFontSize * d.typography.headingScale,
    title => d.typography.resolvedProfessionalTitleFontSize,
    section => d.typography.sectionTitleFontSize * d.typography.headingScale,
    entry => d.typography.resolvedEntryHeaderFontSize,
    line => d.typography.bodyLineHeight,
    elements => d.spacing.itemSpacing,
    horizontal => d.spacing.resolvedHorizontalMargin / pointsPerMm,
    vertical => d.spacing.resolvedVerticalMargin / pointsPerMm,
  };
  DocumentDesign apply(DocumentDesign d, double proposed) {
    final existing = read(d);
    final value = proposed.isFinite
        ? proposed.clamp(min, max).toDouble()
        : existing.isFinite
        ? existing.clamp(min, max).toDouble()
        : min;
    final t = d.typography;
    final scale = t.headingScale.isFinite && t.headingScale > 0
        ? t.headingScale
        : 1.0;
    final s = d.spacing;
    return switch (this) {
      body => d.copyWith(typography: t.copyWith(bodyFontSize: value)),
      name => d.copyWith(
        typography: t.copyWith(
          headingFontSize: value / scale,
          headingScale: scale,
        ),
      ),
      title => d.copyWith(
        typography: t.copyWith(professionalTitleFontSize: value),
      ),
      section => d.copyWith(
        typography: t.copyWith(
          sectionTitleFontSize: value / scale,
          headingScale: scale,
        ),
      ),
      entry => d.copyWith(typography: t.copyWith(entryHeaderFontSize: value)),
      line => d.copyWith(typography: t.copyWith(bodyLineHeight: value)),
      elements => d.copyWith(
        spacing: s.copyWith(
          itemSpacing: value,
          paragraphSpacing: value * .75,
          sectionSpacing: value * 2,
        ),
      ),
      horizontal => d.copyWith(
        spacing: s.copyWith(
          horizontalMargin: value * pointsPerMm - s.pagePadding,
        ),
      ),
      vertical => d.copyWith(
        spacing: s.copyWith(
          verticalMargin: value * pointsPerMm - s.pagePadding,
        ),
      ),
    };
  }

  String display(double value) => switch (this) {
    line => value.toStringAsFixed(2),
    horizontal || vertical => '${value.toStringAsFixed(1)} mm',
    _ => '${value.toStringAsFixed(1)} pt',
  };
}
