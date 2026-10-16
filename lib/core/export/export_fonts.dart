/// Font resolution for the document exporters.
///
/// The `pdf` package can embed TrueType fonts (real Unicode support) or use the
/// base-14 PostScript fonts (Latin-1 only). Embedding is required for Arabic and
/// for the typography chosen in the layout designer, but it needs a font file.
///
/// [GoogleFontSource] resolves the selected family from Google Fonts (SIL Open
/// Font License / Apache-2.0 — redistributable) and caches it on the device. It
/// verifies that the Arabic font actually contains the shaped presentation
/// forms before advertising Arabic support, and falls back to [BaseFontSource]
/// when neither an asset nor a download is available.
///
/// One Arabic font ships with the app ([bundledArabicFontAsset]), so Arabic
/// documents export correctly on a device that has never been online. Only the
/// Latin display families are still downloaded on first use.
library;

import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// A resolved set of fonts for one document export.
class ExportFontSet {
  const ExportFontSet({
    required this.regular,
    required this.bold,
    required this.italic,
    required this.boldItalic,
    this.fallback = const <pw.Font>[],
    required this.familyLabel,
    required this.supportsArabic,
    required this.isFallback,
  });

  final pw.Font regular;
  final pw.Font bold;
  final pw.Font italic;
  final pw.Font boldItalic;

  /// Fonts consulted for code points missing from the primary font.
  final List<pw.Font> fallback;

  /// Human readable family name, e.g. `Inter`.
  final String familyLabel;

  /// `true` only when every font needed for the document was embedded.
  final bool supportsArabic;

  /// `true` when the base-14 fonts were used because nothing could be fetched.
  final bool isFallback;
}

/// Loads the fonts required to export a document.
abstract interface class ExportFontSource {
  /// Loads fonts for [headingFont] (a design font id such as `inter`).
  ///
  /// When [needsArabic] is `true` an Arabic-capable font is embedded and
  /// validated, otherwise the request stays lightweight.
  Future<ExportFontSet> load({
    required String headingFont,
    required bool needsArabic,
  });
}

/// Base-14 PostScript fonts shipped inside every PDF reader.
///
/// Requires no network and no assets, but only covers Latin-1. Used as the
/// offline fallback and by tests that must not depend on the network.
class BaseFontSource implements ExportFontSource {
  const BaseFontSource();

  @override
  Future<ExportFontSet> load({
    required String headingFont,
    required bool needsArabic,
  }) async {
    return ExportFontSet(
      regular: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
      italic: pw.Font.helveticaOblique(),
      boldItalic: pw.Font.helveticaBoldOblique(),
      familyLabel: 'Helvetica',
      supportsArabic: false,
      isFallback: true,
    );
  }
}

/// Verifies that [font] can actually draw [sample].
///
/// Guards against advertising a script as supported when the downloaded font is
/// missing the glyphs: `pdf` throws a [pw.PdfException] during layout otherwise.
/// Defined here (rather than guessed from the file name) so the capability flag
/// is measured, not assumed.
Future<bool> fontsRenderSample(pw.Font font, String sample) async {
  try {
    final probe = pw.Document(compress: true);
    probe.addPage(
      pw.Page(
        build: (context) =>
            pw.Text(sample, style: pw.TextStyle(font: font, fontSize: 12)),
      ),
    );
    await probe.save();
    return true;
  } on Object {
    return false;
  }
}

/// A `PdfGoogleFonts` weight loader.
typedef FontLoader = Future<pw.Font> Function();

/// Shaped Arabic presentation forms used to probe a candidate Arabic font.
const String arabicProbeSample = '\uFE8D\uFE91\uFE9F\uFEA9\uFEFB';

/// Arabic font shipped with the app so Arabic documents export offline.
///
/// Noto Naskh Arabic is licensed under the SIL Open Font License 1.1, which
/// permits bundling the font with an application provided the copyright notice
/// and the licence travel with every copy. Both ship in the same directory,
/// see `assets/google_fonts/README.md`.
///
/// Bundling one Arabic font (~210 KB, already compressed) removes the network
/// requirement for the first Arabic export without a meaningful size cost.
const String bundledArabicFontAsset =
    'assets/google_fonts/NotoNaskhArabic-Regular.ttf';

/// Loads [bundledArabicFontAsset] from [bundle] (`rootBundle` by default).
///
/// Throws when the asset is unavailable so callers can fall through to a
/// download.
Future<pw.Font> loadBundledArabicFont({AssetBundle? bundle}) async {
  final data = await (bundle ?? rootBundle).load(bundledArabicFontAsset);
  return pw.Font.ttf(data);
}

/// Embedded Google Fonts, suitable for redistribution.
///
/// Arabic resolves from the bundled [bundledArabicFontAsset] first and only
/// downloads when that asset is unavailable. Falls back to [BaseFontSource]
/// whenever nothing can be resolved (offline device, no plugin host, blocked
/// network) so export never hard-fails on fonts alone.
class GoogleFontSource implements ExportFontSource {
  GoogleFontSource({
    ExportFontSource? fallback,
    AssetBundle? assetBundle,
    List<FontLoader>? arabicCandidates,
  }) : _fallback = fallback ?? const BaseFontSource(),
       _bundle = assetBundle,
       _arabicCandidates = arabicCandidates ?? _downloadableArabicCandidates;

  final ExportFontSource _fallback;

  /// Bundle used to read [bundledArabicFontAsset]; `rootBundle` by default.
  /// Injectable so the bundled and unavailable paths are both testable offline.
  final AssetBundle? _bundle;

  /// Downloadable Arabic fallbacks; overridable for tests and for hosts that
  /// manage their own font downloads.
  final List<FontLoader> _arabicCandidates;

  /// Candidate loaders per design font id: regular, bold, italic, bold italic.
  static const Map<String, List<List<FontLoader>>> _families = {
    'inter': [
      [PdfGoogleFonts.interRegular],
      [PdfGoogleFonts.interBold],
      [PdfGoogleFonts.interItalic],
      [PdfGoogleFonts.interBoldItalic],
    ],
    'merriweather': [
      [PdfGoogleFonts.merriweatherRegular],
      [PdfGoogleFonts.merriweatherBold],
      [PdfGoogleFonts.merriweatherItalic],
      [PdfGoogleFonts.merriweatherBoldItalic],
    ],
    'lora': [
      [PdfGoogleFonts.loraRegular],
      [PdfGoogleFonts.loraBold],
      [PdfGoogleFonts.loraItalic],
      [PdfGoogleFonts.loraBoldItalic],
    ],
    'poppins': [
      [PdfGoogleFonts.poppinsRegular],
      [PdfGoogleFonts.poppinsBold],
      [PdfGoogleFonts.poppinsItalic],
      [PdfGoogleFonts.poppinsBoldItalic],
    ],
    'playfairdisplay': [
      [PdfGoogleFonts.playfairRegular],
      [PdfGoogleFonts.playfairBold],
      [PdfGoogleFonts.playfairItalic],
      [PdfGoogleFonts.playfairBoldItalic],
    ],
    'jetbrainsmono': [
      [PdfGoogleFonts.jetBrainsMonoRegular],
      [PdfGoogleFonts.jetBrainsMonoBold],
      [PdfGoogleFonts.jetBrainsMonoItalic],
      [PdfGoogleFonts.jetBrainsMonoBoldItalic],
    ],
  };

  /// Arabic-capable candidates, in order of preference.
  ///
  /// Only consulted when the bundled asset cannot be loaded.
  static const List<FontLoader> _downloadableArabicCandidates = [
    PdfGoogleFonts.notoNaskhArabicRegular,
    PdfGoogleFonts.amiriRegular,
    PdfGoogleFonts.cairoRegular,
  ];

  /// Arabic resolution order: the bundled asset first (no network at all),
  /// then the downloadable candidates.
  List<FontLoader> get _arabicSequence => <FontLoader>[
    () => loadBundledArabicFont(bundle: _bundle),
    ..._arabicCandidates,
  ];

  /// `true` when [font] is an embedded TrueType font rather than one of the
  /// base-14 PostScript fonts.
  ///
  /// `pdf`'s `Font` does not override `==`, and `Font.helvetica()` builds a new
  /// instance on every call, so an identity check cannot detect the silent
  /// substitution `DownloadableFont.getFont` performs when a download fails (it
  /// returns Helvetica instead of throwing). The concrete type is the only
  /// reliable signal that the chosen typography really reached the file.
  static bool _isEmbedded(pw.Font font) => font is pw.TtfFont;

  static Future<pw.Font?> _firstOf(List<FontLoader> loaders) async {
    for (final loader in loaders) {
      try {
        return await loader();
      } on Object {
        continue;
      }
    }
    return null;
  }

  @override
  Future<ExportFontSet> load({
    required String headingFont,
    required bool needsArabic,
  }) async {
    final base = await _fallback.load(
      headingFont: headingFont,
      needsArabic: false,
    );

    final weights = _families[headingFont] ?? _families['inter']!;
    final regular = await _firstOf(weights[0]) ?? base.regular;
    final bold = await _firstOf(weights[1]) ?? regular;
    final italic = await _firstOf(weights[2]) ?? regular;
    final boldItalic = await _firstOf(weights[3]) ?? regular;

    final embedded = _isEmbedded(regular);
    final fallbackFonts = <pw.Font>[regular];
    var supportsArabic = false;

    if (needsArabic) {
      for (final candidate in _arabicSequence) {
        final font = await _firstOf([candidate]);
        if (font == null) continue;
        if (await fontsRenderSample(font, arabicProbeSample)) {
          fallbackFonts.insert(0, font);
          supportsArabic = true;
          break;
        }
      }
    }

    return ExportFontSet(
      regular: regular,
      bold: bold,
      italic: italic,
      boldItalic: boldItalic,
      fallback: fallbackFonts,
      familyLabel: embedded ? _label(headingFont) : base.familyLabel,
      supportsArabic: supportsArabic,
      isFallback: !embedded,
    );
  }

  static String _label(String id) => _families.containsKey(id) ? id : 'Inter';
}
