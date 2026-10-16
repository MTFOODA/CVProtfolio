/// Regression tests for the two defects found by inspecting rendered pages.
///
/// 1. The base-14 fallback drew `.notdef` boxes for the characters those fonts
///    cannot encode (`’` in pasted prose, and the `•` the renderer emits for
///    every entry description).
/// 2. The default `ColorConfig` painted headings white on white paper, so the
///    person's name — and, in ATS mode, every section heading — was invisible.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/document_models.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/export/base_font_text.dart';
import 'package:cv_portfolio_maker/core/export/export_fonts.dart';
import 'package:cv_portfolio_maker/core/export/export_service.dart';
import 'package:cv_portfolio_maker/core/export/pdf_sections.dart';
import 'package:cv_portfolio_maker/core/export/pdf_style.dart';
import 'package:cv_portfolio_maker/core/render/resolved_document.dart';

import 'support/arabic_font.dart';
import 'support/pdf_text.dart';

CvDocument _document() => CvDocument(
  id: 'd1',
  ownerId: 'u1',
  title: 'CV',
  design: const DocumentDesign(
    sections: [
      SectionConfig(id: 'profile', kind: SectionKind.profile),
      SectionConfig(id: 'experience', kind: SectionKind.experience),
    ],
  ),
);

/// Prose with the characters that used to come out as boxes.
UserProfile _profile() => const UserProfile(
  id: 'u1',
  details: ProfileDetails(
    fullName: 'Ada Lovelace',
    email: 'ada@example.com',
    summary: 'Wrote the first algorithm — for the engine’s notes.',
  ),
  experiences: [
    ExperienceEntry(
      id: 'e1',
      company: 'Analytical Engines Ltd',
      position: 'Lead Analyst',
      descriptions: ['Documented the engine’s instruction set.'],
    ),
  ],
);

Future<String> _exportText(ExportFontSource fonts) async {
  final result = await DocumentExporter(fonts: fonts).export(
    document: _document(),
    profile: _profile(),
    mode: ExportMode.designed,
  );
  return extractNormalisedPdfText(result.bytes);
}

void main() {
  group('base-14 fallback text', () {
    test('every substitution targets a character outside Latin-1', () {
      baseFontReplacements.forEach((rune, replacement) {
        expect(
          rune,
          greaterThan(0xFF),
          reason:
              'U+${rune.toRadixString(16).toUpperCase()} is already drawable, '
              'so replacing it would degrade real output',
        );
        expect(replacement, isNotEmpty);
      });
    });

    test('maps the characters the built-in fonts cannot draw', () {
      final cases = <String, String>{
        'engine’s': "engine's",
        '“quoted”': '"quoted"',
        'a – b': 'a - b',
        'wait…': 'wait...',
        'five • bullets': 'five - bullets',
        '€19': 'EUR19',
      };
      cases.forEach((input, expected) {
        expect(transliterateForBaseFonts(input), expected, reason: input);
      });
    });

    test('leaves drawable text untouched', () {
      // Latin-1 (including ·, ©, £, é) and Arabic are not substituted here.
      const sample = 'Plain ASCII, £, ©, ·, é, ø, العربية';
      expect(needsBaseFontTransliteration(sample), isFalse);
      expect(transliterateForBaseFonts(sample), sample);
      expect(transliterateForBaseFonts(''), '');
    });

    test('removes the box characters from a real export', () async {
      final text = await _exportText(const BaseFontSource());

      expect(text, contains("engine's"));
      expect(text, contains('first algorithm - for'));
      expect(
        text,
        isNot(contains('’')),
        reason: 'U+2019 was drawn as .notdef by the base-14 font',
      );
      expect(
        text,
        isNot(contains('•')),
        reason: 'U+2022 was drawn as .notdef by the base-14 font',
      );
    });

    test('keeps the original characters when a font is embedded', () async {
      final font = await loadPdfFont(bundledArabicFontAsset);
      final text = await _exportText(FixtureFontSource(font));

      expect(text, contains('engine’s'));
      expect(text, contains('algorithm — for'));
      expect(text, isNot(contains('engine s')));
    });
  });

  group('default palette legibility', () {
    test('the default heading colour is visible on the default paper', () {
      const colors = ColorConfig();
      expect(colors.headingText, isNot(colors.paper));
      expect(colors.headingText, colors.bodyText);
    });

    test(
      'a persisted design without an explicit heading colour is legible',
      () {
        final colors = ColorConfig.fromJson(const <String, dynamic>{
          'paper': 0xFFFFFFFF,
        });
        expect(colors.headingText, isNot(colors.paper));
      },
    );

    test('the name is never painted in the paper colour', () async {
      final fonts = await const BaseFontSource().load(
        headingFont: 'inter',
        needsArabic: false,
      );
      final designed = PdfStyle(
        design: const DocumentDesign(),
        fonts: fonts,
        ats: false,
      );
      expect(designed.nameStyle().color, isNot(designed.paper));
      expect(designed.headingColor.toInt(), 0xFF1F2933);

      // ATS paints section headings with the accent colour.
      final ats = PdfStyle(
        design: const DocumentDesign(),
        fonts: fonts,
        ats: true,
      );
      expect(ats.accentColor.toInt(), isNot(ats.paper.toInt()));
    });
  });

  group('RTL layout', () {
    /// The bullet row rendered for the first experience description.
    Future<pw.Row> bulletRow({required bool rtl}) async {
      final resolved = ResolvedDocument.resolve(
        document: CvDocument(
          id: 'd1',
          ownerId: 'u1',
          title: 'CV',
          isRtl: rtl,
          design: DocumentDesign(
            isRtl: rtl,
            sections: const [
              SectionConfig(id: 'experience', kind: SectionKind.experience),
            ],
          ),
        ),
        profile: _profile(),
        defaultTitle: (kind) => kind.name,
      );
      final fonts = await const BaseFontSource().load(
        headingFont: 'inter',
        needsArabic: false,
      );
      final renderer = SectionRenderer(
        style: PdfStyle(design: resolved.design, fonts: fonts, ats: false),
        width: 400,
      );
      final section = resolved.sections.firstWhere(
        (s) => s.experiences.isNotEmpty,
      );

      for (final widget in renderer.build(section)) {
        if (widget is pw.Padding && widget.child is pw.Column) {
          final rows = (widget.child! as pw.Column).children
              .whereType<pw.Row>();
          if (rows.isNotEmpty) return rows.first;
        }
      }
      throw StateError('the experience block produced no bullet row');
    }

    test('the marker leads a left-to-right line', () async {
      final row = await bulletRow(rtl: false);
      expect(row.children.first, isA<pw.SizedBox>());
      expect(row.children.last, isA<pw.Expanded>());
    });

    test('the marker trails a right-to-left line', () async {
      final row = await bulletRow(rtl: true);
      expect(row.children.first, isA<pw.Expanded>());
      expect(row.children.last, isA<pw.SizedBox>());
    });

    test('headings and entry blocks align to the reading side', () async {
      final fonts = await const BaseFontSource().load(
        headingFont: 'inter',
        needsArabic: false,
      );

      for (final rtl in <bool>[false, true]) {
        final style = PdfStyle(
          design: DocumentDesign(isRtl: rtl),
          fonts: fonts,
          ats: false,
        );
        expect(style.bodyAlign, rtl ? pw.TextAlign.right : pw.TextAlign.left);

        final resolved = ResolvedDocument.resolve(
          document: CvDocument(
            id: 'd1',
            ownerId: 'u1',
            title: 'CV',
            isRtl: rtl,
            design: DocumentDesign(
              isRtl: rtl,
              sections: const [
                SectionConfig(id: 'experience', kind: SectionKind.experience),
              ],
            ),
          ),
          profile: _profile(),
          defaultTitle: (kind) => kind.name,
        );
        final section = resolved.sections.firstWhere(
          (s) => s.experiences.isNotEmpty,
        );
        final widgets = SectionRenderer(
          style: style,
          width: 400,
        ).build(section);

        // The section heading spans the width (so `textAlign` has room) and
        // carries the reading direction's alignment.
        final heading = widgets.first;
        expect(heading, isA<pw.SizedBox>());
        final headingText = (heading as pw.SizedBox).child;
        expect(headingText, isA<pw.Text>());
        expect((headingText! as pw.Text).textAlign, style.bodyAlign);

        // …and the entry block must stretch, otherwise its lines keep their
        // intrinsic width, `textAlign` has nothing to align, and right-to-left
        // titles hug the left margin.
        final column = widgets
            .whereType<pw.Padding>()
            .map((p) => p.child)
            .whereType<pw.Column>()
            .first;
        expect(column.crossAxisAlignment, pw.CrossAxisAlignment.stretch);
      }
    });
  });
}
