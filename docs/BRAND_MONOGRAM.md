# CV monogram identity — 2026-11-08

The approved modern logo direction is proposal 4: a continuous lowercase CV
ligature in sky blue (`#6CABDD`) on a rounded graphite tile (`#2D333B`).
It replaces the document/arrow identity. Product name and application IDs remain
unchanged.

`tools/create_identity.py` defines one vector contour shared by the generated
SVG and supersampled PNG masters. The app uses a rounded PNG with transparent
corners; platform launchers receive full-bleed masters with safe padding.
This is an editable implementation of the concept, without its presentation
number, wordmark or raster texture baked into the application icon.

Regenerated surfaces: in-app logo (sign-in, Home, navigation and About), Android
legacy/adaptive icons, Windows ICO, web loader/favicon/PWA icons and social
preview. The previous identity is retained locally in
`build/identity-before-monogram.zip`.

## Verification

- 12 About/component tests passed, including English/Arabic and small/desktop
  viewports. The 360 px light presentation walkthrough also passed.
- The new Home screenshot and social preview were visually inspected.
- Artwork radius is 314.17 px inside Android's 337.92 px safe radius and
  367.85 px inside the PWA's 409.60 px safe radius (1024 px master canvas).
- Actual 16/24/32/48/192 px icons were visually inspected.
- The generator uses only Pillow, with no added application dependency.

Evidence: `build/monogram-branding-tests.log`,
`build/monogram-presentation-audit.log`, `build/monogram-icon-validation.json`,
`build/monogram-platform-icons.log` and
`build/brand_assets_preview/cv-monogram-sizes.png`.

## Verified delivery

Version `1.0.4+5` is published on the existing web host and public Android download.
The installed-package metadata reports versionName `1.0.4`, versionCode `5`,
min SDK 24 and target SDK 36. The existing signing configuration is retained.

- [Web app](https://cvprotfolio.mohamed-fooda-mtf.workers.dev).
- Cloudflare version: `a87ff459-b1a1-4a06-8553-7ea670a61ee8`.
- All 14 HTTP delivery checks passed. Hosted PNG branding assets,
  app shell and JavaScript match the local release byte for byte.
- JavaScript SHA-256: `6698a7a8b228f62d90d51e3dcfe4209bbd72e963a20bbc027300ed253cdfe79b`.
- [Android release](https://github.com/MTFOODA/CVProtfolio/releases/tag/v1.0.4).
- APK size: `75,041,721` bytes; SHA-256: `5754b85c723f3dc2e882d7cfe02cc7a3a71092a3403f7ff2cba617efd22d6b8d`.
- Packaged Flutter logo and native legacy/adaptive icons match the new masters.
- The stable latest APK URL returned HTTP 206 with the expected ZIP header;
  public release metadata reports the matching artifact digest.

Evidence: `build/monogram-hosted-verification.json`,
`build/monogram-android-release.json`, `build/monogram-apk-verification.json`,
`build/monogram-android-public-verification.json`, and
`build/monogram-cloudflare-deployment.log`.

These checks do not claim a new physical-device installation. The Android
release body discloses local source changes beyond the tagged repository
baseline; publishing these builds does not claim a source push to GitHub.
