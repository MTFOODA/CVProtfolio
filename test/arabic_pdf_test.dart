/// End-to-end Arabic PDF verification against a real TrueType font.
///
/// Arabic can only be *rendered* by a font that contains the shaped
/// presentation forms (U+FB50–U+FEFF). The app ships one
/// ([bundledArabicFontAsset], Noto Naskh Arabic, SIL OFL 1.1), and
/// [findArabicFont] uses it first, so this check is portable and needs no
/// network access. `CV_ARABIC_FONT` still takes precedence, and common desktop
/// fonts are used as a last resort.
///
/// Reproducible procedure
/// ----------------------
/// 1. `flutter test test/arabic_pdf_test.dart` — uses the bundled font.
/// 2. To check a different font, point `CV_ARABIC_FONT` at its `.ttf`.
///
/// Ordering and shaping of the *code points* are pinned independently by
/// `bidi_and_shaping_test.dart`.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/document_models.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/export/arabic_text.dart';
import 'package:cv_portfolio_maker/core/export/export_fonts.dart';
import 'package:cv_portfolio_maker/core/export/export_service.dart';

import 'support/arabic_font.dart';
import 'support/pdf_text.dart';

/// Arabic paragraphs that also carry the punctuation, bracket, number and
/// Latin runs a real CV contains.
const String _arabicName = 'أحمد بن علي';
const String _arabicTitle = 'مهندس برمجيات';
const String _arabicSummary = 'مطور تطبيقات الجوال (خبرة 8 سنوات)';
const String _arabicSalary = 'الراتب المتوقع: 15000 دولار';

CvDocument _document({required bool rtl}) => CvDocument(
  id: 'd1',
  ownerId: 'u1',
  title: 'CV',
  isRtl: rtl,
  design: DocumentDesign(
    isRtl: rtl,
    sections: const [
      SectionConfig(id: 'profile', kind: SectionKind.profile),
      SectionConfig(id: 'experience', kind: SectionKind.experience),
    ],
  ),
);

UserProfile _profile() => const UserProfile(
  id: 'u1',
  details: ProfileDetails(
    fullName: _arabicName,
    professionalTitle: _arabicTitle,
    email: 'ahmed@example.com',
    phone: '+20 123 456 7890',
    summary: _arabicSummary,
  ),
  experiences: [
    ExperienceEntry(
      id: 'e1',
      company: 'Cairo Software',
      position: 'Senior Engineer',
      location: 'Cairo',
      descriptions: [
        'Built the mobile platform for 2 million users.',
        _arabicSalary,
      ],
    ),
  ],
);

void main() {
  group('Arabic PDF rendering', () {
    test('shaped Arabic reaches a real PDF', () async {
      final fontPath = findArabicFont();
      if (fontPath == null) {
        markTestSkipped(
          'No Arabic-capable font found. Set CV_ARABIC_FONT to a '
          'redistributable font such as Noto Naskh Arabic to enable this '
          'check; see the file header for the procedure.',
        );
        return;
      }

      final font = await loadPdfFont(fontPath);
      if (!await fontsRenderSample(font, arabicProbeSample)) {
        markTestSkipped('$fontPath cannot render the shaped Arabic probe.');
        return;
      }

      final exporter = DocumentExporter(fonts: FixtureFontSource(font));
      final profile = _profile();

      // 1. A right-to-left document.
      final arabic = await exporter.export(
        document: _document(rtl: true),
        profile: profile,
        mode: ExportMode.designed,
      );
      expect(arabic.pageCount, greaterThanOrEqualTo(1));

      final arabicText = extractNormalisedPdfText(arabic.bytes);
      expect(
        countArabicPresentationForms(arabicText),
        greaterThan(0),
        reason: 'the shaped forms must reach the PDF, not the base letters',
      );
      // The visual order written into the PDF is exactly what the shaper
      // produced for a right-to-left document.
      expect(arabicText, contains(prepareForPdf(_arabicName, rtlBase: true)));
      expect(arabicText, contains(prepareForPdf(_arabicTitle, rtlBase: true)));
      // Latin content is preserved verbatim.
      expect(arabicText, contains('ahmed@example.com'));
      expect(arabicText, contains('Senior Engineer'));

      // 2. An English document containing an Arabic name: the Arabic run is
      //    still reversed even though the paragraph direction is left-to-right.
      final mixed = await exporter.export(
        document: _document(rtl: false),
        profile: profile,
        mode: ExportMode.designed,
      );
      final mixedText = extractNormalisedPdfText(mixed.bytes);
      expect(mixedText, contains(prepareForPdf(_arabicName, rtlBase: false)));
      expect(mixedText, contains('Built the mobile platform'));

      // 3. ATS output forces a single-column, left-to-right design without
      //    dropping the Arabic content.
      final ats = await exporter.export(
        document: _document(rtl: true),
        profile: profile,
        mode: ExportMode.atsFriendly,
      );
      final atsText = extractNormalisedPdfText(ats.bytes);
      expect(countArabicPresentationForms(atsText), greaterThan(0));
      expect(atsText, contains('Senior Engineer'));
    });

    test('brackets, digits and Latin runs inside Arabic survive', () async {
      final fontPath = findArabicFont();
      if (fontPath == null) {
        markTestSkipped('No Arabic-capable font found; see the file header.');
        return;
      }
      final font = await loadPdfFont(fontPath);
      if (!await fontsRenderSample(font, arabicProbeSample)) {
        markTestSkipped('$fontPath cannot render the shaped Arabic probe.');
        return;
      }

      final exporter = DocumentExporter(fonts: FixtureFontSource(font));
      final result = await exporter.export(
        document: _document(rtl: true),
        profile: _profile(),
        mode: ExportMode.designed,
      );
      final text = extractNormalisedPdfText(result.bytes);

      // Bracketed Arabic: the reordering engine also mirrors the pair, so the
      // whole segment is compared in its shaped visual order.
      expect(text, contains(prepareForPdf(_arabicSummary, rtlBase: true)));
      // Digits inside the Arabic run survived as real characters.
      expect(text, contains('8'));
      expect(text, contains('15000'));
      // LTR runs embedded in an RTL paragraph are left alone.
      expect(text, contains('ahmed@example.com'));
      expect(text, contains('+20 123 456 7890'));
    });
  });
}
