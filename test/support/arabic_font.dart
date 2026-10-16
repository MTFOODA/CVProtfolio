/// Locates an Arabic-capable TrueType font on the machine running the tests.
///
/// No Arabic font can be committed as a fixture: the usual candidates (Arial,
/// Tahoma, Segoe UI) are not redistributable, and the app deliberately does not
/// bundle one (see `export_fonts.dart` for the download-and-cache strategy).
/// Tests therefore use whatever the host provides, and skip with an explicit
/// message when nothing is available.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:cv_portfolio_maker/core/export/export_fonts.dart';

/// Fonts commonly present on desktop systems, in preference order.
const List<String> candidateFontPaths = [
  r'C:\Windows\Fonts\arial.ttf',
  r'C:\Windows\Fonts\tahoma.ttf',
  r'C:\Windows\Fonts\segoeui.ttf',
  '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
  '/usr/share/fonts/truetype/noto/NotoNaskhArabic-Regular.ttf',
  '/System/Library/Fonts/Supplemental/Arial.ttf',
];

/// Returns the first available Arabic-capable font path, or `null`.
///
/// `CV_ARABIC_FONT` takes precedence so a specific font can be checked
/// explicitly. The font the app itself ships is tried next, which makes the
/// check portable; system fonts are the last resort.
String? findArabicFont() {
  final fromEnv = Platform.environment['CV_ARABIC_FONT'];
  if (fromEnv != null && fromEnv.isNotEmpty && File(fromEnv).existsSync()) {
    return fromEnv;
  }
  final bundled = File(bundledArabicFontAsset);
  if (bundled.existsSync()) return bundled.absolute.path;
  for (final path in candidateFontPaths) {
    if (File(path).existsSync()) return path;
  }
  return null;
}

/// Loads [path] as a PDF font.
Future<pw.Font> loadPdfFont(String path) async {
  final bytes = await File(path).readAsBytes();
  return pw.Font.ttf(ByteData.sublistView(bytes));
}

/// Supplies a pre-loaded font so no network access is required.
class FixtureFontSource implements ExportFontSource {
  FixtureFontSource(this.font);

  final pw.Font font;

  @override
  Future<ExportFontSet> load({
    required String headingFont,
    required bool needsArabic,
  }) async => ExportFontSet(
    regular: font,
    bold: font,
    italic: font,
    boldItalic: font,
    fallback: [font],
    familyLabel: 'fixture',
    supportsArabic: true,
    isFallback: false,
  );
}

/// An [AssetBundle] backed by the package directory on disk.
///
/// `flutter test` does not serve pubspec-declared assets through `rootBundle`
/// in every configuration, so tests exercise the real bundled files directly.
class DiskAssetBundle extends CachingAssetBundle {
  DiskAssetBundle({String? root}) : root = root ?? Directory.current.path;

  /// Package root the asset keys are resolved against.
  final String root;

  @override
  Future<ByteData> load(String key) async {
    final file = File(
      '$root${Platform.pathSeparator}'
      '${key.replaceAll('/', Platform.pathSeparator)}',
    );
    if (!file.existsSync()) {
      throw FlutterError('Unable to load asset: $key');
    }
    return ByteData.sublistView(await file.readAsBytes());
  }
}

/// An [AssetBundle] that contains nothing.
///
/// Stands in for a build that did not ship the bundled font, and for a device
/// where the asset is missing for any other reason.
class EmptyAssetBundle extends CachingAssetBundle {
  EmptyAssetBundle();

  @override
  Future<ByteData> load(String key) async =>
      throw FlutterError('Unable to load asset: $key');
}

/// A font cache that refuses to download anything.
///
/// [PdfGoogleFonts] resolves every downloadable weight through
/// [PdfBaseCache.defaultCache], which fetches over HTTP when the font is not
/// bundled. Installing this cache simulates an offline device and keeps the
/// suite hermetic: `DownloadableFont.getFont` turns the failure into a
/// Helvetica substitution instead of throwing.
class OfflineFontCache extends PdfBaseCache {
  const OfflineFontCache();

  @override
  Future<Uint8List> resolve({
    required String name,
    required Uri uri,
    bool cache = true,
    Map<String, String>? headers,
  }) async => throw FlutterError('offline: cannot download $name');

  @override
  Future<void> add(String key, Uint8List bytes) async {}

  @override
  Future<bool> contains(String key) async => false;

  @override
  Future<Uint8List?> get(String key) async => null;

  @override
  Future<void> remove(String key) async {}

  @override
  Future<void> clear() async {}
}
