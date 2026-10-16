/// Font resolution: what ships with the app, what is downloaded, and what the
/// user is told when neither is available.
///
/// None of these tests touch the network — the asset-bundle seam on
/// [GoogleFontSource] is injected with a disk-backed bundle (the real bundled
/// font) and with an empty one (nothing available).
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/document_models.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/export/export_fonts.dart';
import 'package:cv_portfolio_maker/core/export/export_service.dart';
import 'package:cv_portfolio_maker/core/l10n/strings_ar.dart';
import 'package:cv_portfolio_maker/core/l10n/strings_en.dart';

import 'support/arabic_font.dart';

CvDocument _document() => CvDocument(
  id: 'd1',
  ownerId: 'u1',
  title: 'CV',
  design: const DocumentDesign(
    sections: [SectionConfig(id: 'profile', kind: SectionKind.profile)],
  ),
);

UserProfile _profile({String? name}) => UserProfile(
  id: 'u1',
  details: ProfileDetails(fullName: name, email: 'ada@example.com'),
);

void main() {
  // Every downloadable weight is resolved through `PdfBaseCache.defaultCache`.
  // Replacing it with a cache that always fails keeps this file offline and
  // deterministic, and is exactly the situation being audited.
  setUpAll(() => PdfBaseCache.defaultCache = const OfflineFontCache());
  tearDownAll(() => PdfBaseCache.defaultCache = PdfMemoryCache());

  group('bundled Arabic font', () {
    test('ships with the app and renders shaped Arabic', () async {
      final file = File(bundledArabicFontAsset);
      expect(
        file.existsSync(),
        isTrue,
        reason: 'the bundled font must be present at $bundledArabicFontAsset',
      );
      // A real Arabic font is a few hundred kilobytes; an error page or an
      // empty file would be tiny and would fail below anyway.
      expect(await file.length(), greaterThan(100000));

      final font = await loadPdfFont(bundledArabicFontAsset);
      expect(font, isA<pw.TtfFont>());
      expect(await fontsRenderSample(font, arabicProbeSample), isTrue);
    });

    test('is declared as a Flutter asset', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('assets/google_fonts/'));
    });

    test('ships its OFL licence next to it (OFL condition 2)', () {
      final licence = File('assets/google_fonts/NotoNaskhArabic-OFL.txt');
      expect(licence.existsSync(), isTrue);
      final text = licence.readAsStringSync();
      expect(text, contains('SIL OPEN FONT LICENSE Version 1.1'));
      expect(text, contains('The Noto Project Authors'));
      expect(
        licence.parent.path,
        File(bundledArabicFontAsset).parent.path,
        reason: 'the notice must travel with every copy of the font',
      );
    });

    test('loads through the asset bundle without any network access', () async {
      final font = await loadBundledArabicFont(bundle: DiskAssetBundle());
      expect(await fontsRenderSample(font, arabicProbeSample), isTrue);
    });

    test('throws when it is missing so callers can fall back', () async {
      await expectLater(
        loadBundledArabicFont(bundle: EmptyAssetBundle()),
        throwsA(isA<FlutterError>()),
      );
    });
  });

  group('font selection', () {
    test('base-14 fonts are separate instances (why `==` cannot be used)', () {
      // `pdf` does not override `operator ==` on `Font`, and `Font.helvetica()`
      // builds a new instance per call, so identity comparison cannot detect
      // the Helvetica substitution `DownloadableFont.getFont` performs when a
      // download fails. `GoogleFontSource` therefore classifies fonts by type.
      // If this assertion ever fails, upstream changed and `_isEmbedded` should
      // be revisited.
      expect(pw.Font.helvetica() == pw.Font.helvetica(), isFalse);
    });

    test('prefers the bundled font and needs no download', () async {
      final source = GoogleFontSource(
        assetBundle: DiskAssetBundle(),
        arabicCandidates: const <FontLoader>[],
      );

      final fonts = await source.load(headingFont: 'inter', needsArabic: true);

      expect(fonts.supportsArabic, isTrue);
      expect(fonts.fallback, isNotEmpty);
      expect(
        await fontsRenderSample(fonts.fallback.first, arabicProbeSample),
        isTrue,
        reason: 'the Arabic fallback must be the bundled font',
      );
    });

    test('reports no Arabic support instead of broken glyphs', () async {
      final source = GoogleFontSource(
        assetBundle: EmptyAssetBundle(),
        arabicCandidates: const <FontLoader>[],
      );

      final fonts = await source.load(headingFont: 'inter', needsArabic: true);

      expect(fonts.supportsArabic, isFalse);
    });

    test('reports the base-14 substitution when nothing resolves', () async {
      final source = GoogleFontSource(
        assetBundle: EmptyAssetBundle(),
        arabicCandidates: const <FontLoader>[],
      );

      final fonts = await source.load(headingFont: 'inter', needsArabic: false);

      // No asset and no downloadable fallback here: the exporter must admit it
      // fell back to the base-14 fonts rather than claim the chosen family.
      expect(fonts.isFallback, isTrue);
      expect(fonts.familyLabel, 'Helvetica');
      expect(fonts.regular, isNot(isA<pw.TtfFont>()));
    });

    test('does not look for an Arabic font for a Latin document', () async {
      final source = GoogleFontSource(
        assetBundle: DiskAssetBundle(),
        arabicCandidates: const <FontLoader>[],
      );

      final fonts = await source.load(headingFont: 'inter', needsArabic: false);

      expect(fonts.supportsArabic, isFalse);
      expect(fonts.fallback, hasLength(1));
    });
  });

  group('what the user is told', () {
    test('a base-14 substitution is surfaced, not hidden', () async {
      final validation = await DocumentExporter(fonts: const BaseFontSource())
          .validate(
            document: _document(),
            profile: _profile(name: 'Ada Lovelace'),
            mode: ExportMode.designed,
          );

      expect(validation.canExport, isTrue);
      expect(
        validation.issues.map((i) => i.code),
        contains('exportFontsFallback'),
      );
    });

    test('an embedded font produces no fallback notice', () async {
      final font = await loadPdfFont(bundledArabicFontAsset);
      final validation = await DocumentExporter(fonts: FixtureFontSource(font))
          .validate(
            document: _document(),
            profile: _profile(name: 'Ada Lovelace'),
            mode: ExportMode.designed,
          );

      expect(
        validation.issues.map((i) => i.code),
        isNot(contains('exportFontsFallback')),
      );
    });

    test('missing Arabic support blocks the export with a clear key', () async {
      final validation = await DocumentExporter(fonts: const BaseFontSource())
          .validate(
            document: _document(),
            profile: _profile(name: 'مطور برمجيات'),
            mode: ExportMode.designed,
          );

      expect(validation.canExport, isFalse);
      expect(
        validation.errors.map((i) => i.code),
        contains('exportErrorNoArabicFont'),
      );
    });

    test('both messages are localized', () {
      for (final map in <Map<String, String>>[enStrings, arStrings]) {
        expect(map['exportFontsFallback'], isNotNull);
        expect(map['exportErrorNoArabicFont'], isNotNull);
      }
      expect(
        arStrings['exportErrorNoArabicFont'],
        isNot(enStrings['exportErrorNoArabicFont']),
        reason: 'the Arabic table must not fall back to English copy',
      );
    });
  });
}
