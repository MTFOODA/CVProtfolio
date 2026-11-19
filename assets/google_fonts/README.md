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


## CV design fonts

The CV Design Settings feature uses offline Inter, Lora, Roboto, and Noto
Naskh Arabic in Flutter, PDF and editable Word exports. Regular and bold
Latin faces are bundled; Noto Naskh Arabic supplies complex-script fallback.
Word embeds these licensed font files using ECMA-376 font obfuscation.

- Inter regular/bold: Google Fonts CSS API, family `Inter`, weights 400/700.
  Copyright 2020 The Inter Project Authors; license: `Inter-OFL.txt`.
- Lora regular/bold: Google Fonts CSS API, family `Lora`, weights 400/700.
  Copyright 2011 The Lora Project Authors; license: `Lora-OFL.txt`.
- Roboto regular/bold: the installed Flutter SDK's redistributable material
  fonts; license: `Roboto-LICENSE.txt`.
- Contact icons: Google `material-design-icons` repository,
  `font/MaterialIcons-Regular.ttf`, saved as `ContactIcons-Regular.ttf`.
  Apache 2.0 license: `MaterialIcons-LICENSE.txt`.

Legacy document font identifiers retain the existing PDF download/fallback
path. The new settings dropdown offers only the fully bundled families.

ContactBrands-Regular.ttf is the unmodified Font Awesome Free 6.7.2 Brands font.
Source: https://github.com/FortAwesome/Font-Awesome/tree/6.7.2/webfonts
SIL OFL license: FontAwesome-LICENSE.txt. Used for GitHub and LinkedIn contact logos.


## Modernized interface fonts

UI text uses Inter 400/500/600 for English and Tajawal 400/500/600 for Arabic.
`Inter-Variable.ttf` is the unmodified Google Fonts `ofl/inter/Inter[opsz,wght].ttf`
asset and supplies 500/600; its OFL is `Inter-OFL.txt`. Tajawal Regular, Medium
and Bold are unmodified Google Fonts `ofl/tajawal/` assets, licensed in
`Tajawal-OFL.txt`. Tajawal has no discrete 600 face: its Bold face supplies the
600 UI request. Existing export font files and family identifiers are retained.
