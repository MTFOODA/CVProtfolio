# Bundled fonts

## `NotoNaskhArabic-Regular.ttf`

Arabic text needs a font with the shaped presentation forms (U+FExx) that
`pdf`'s Arabic shaper emits. Without one, an Arabic document cannot be exported
at all, so the app ships a single Arabic font instead of requiring a download on
first use.

* **Family:** Noto Naskh Arabic, Regular
* **Source:** `https://fonts.gstatic.com/s/notonaskharabic/v34/RrQ5bpV-9Dd1b1OAGA6M9PkyDuVBePeKNaxcsss0Y7bwvc5krK0z9_Mnuw.ttf`
  (the exact URL `PdfGoogleFonts.notoNaskhArabicRegular` requests, so the
  runtime download path and the bundled asset are byte-compatible)
* **Copyright:** Copyright 2022 The Noto Project Authors
  (<https://github.com/notofonts/arabic>)
* **Licence:** SIL Open Font License 1.1 — full text in
  `NotoNaskhArabic-OFL.txt`
* **Size:** ~212 KB (already compressed; it is a single second-order table
  stream, so APK compression gains nothing)

### Why this is safe to redistribute

The OFL grants permission to "use, study, copy, merge, embed, modify,
redistribute, and sell modified and unmodified copies", provided (condition 2)
that "each copy contains the above copyright notice and this license". No
Reserved Font Name is declared, and the file is redistributed unmodified, so
conditions 3 and 4 do not apply. Shipping `NotoNaskhArabic-OFL.txt` in this same
directory satisfies the notice requirement; OSS attribution in the app's about
screen should also mention it.

### Related code

* `lib/core/export/export_fonts.dart` — `bundledArabicFontAsset` and
  `loadBundledArabicFont()`; the bundled font is tried before any download, so
  the asset key is `assets/google_fonts/NotoNaskhArabic-Regular.ttf` (Flutter's
  key is the pubspec-relative path, including the `assets/` prefix — it is not
  the `google_fonts/<FontName>.ttf` key that `printing`'s own `AssetManifest`
  lookup would use, because the app does not rely on that internal convention).
  Keep the file name unchanged if you replace the font with a newer release.
* `pubspec.yaml` — `assets: - assets/google_fonts/`.
