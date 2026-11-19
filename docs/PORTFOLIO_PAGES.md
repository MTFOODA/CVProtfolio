# Content-driven portfolio pages

Owner previews and shared visitor portfolios use the same `PortfolioContent`
page model. About remains available. Experience, Projects, Skills and the combined
Credentials page appear only when their resolved sections contain visible data.
Section visibility, per-entry hidden IDs, model visibility and project selection
are applied before deciding page availability. Removing the last visible entry
removes its page; removing the selected page falls back to About.

Selection uses a page identity rather than a numeric index, so inserting a page
before the current one does not change the current content. Retained pages are
keyed to preserve their scroll/media state. Legacy owner `initialTab` values
still identify About, Projects and Skills.

## Content placement

- **About:** profile hero, contact icons/metadata, education, languages and other
  custom content that does not belong to the dedicated pages.
- **Experience:** native professional experience plus custom sections explicitly
  categorized as experience.
- **Projects:** native projects plus any number of user-named project sections.
- **Skills:** visible native skill entries.
- **Credentials:** native certificates/courses and custom sections categorized as
  certificates or courses. Credential dates, IDs and verification links remain
  available through the shared structured-entry renderer.

The separate Contact card is removed. Valid websites, portfolio links and other
web links join the existing social/email/WhatsApp icons inside the profile hero.
Location and remaining plain contact values appear there with an appropriate
icon. Long press retains copy behavior, exact destinations remain separate from
labels, unsafe URLs are not opened, and hiding personal details hides this group.

## Categorized entries

The Additional entries dialog now starts with a section-type picker: custom,
certificates, courses, projects, experience, education, awards, volunteer,
publications and references. Choosing a type supplies an editable suggested
section name. Manually supplied names remain unchanged when switching types.
Editing a section preserves its identity and other entries.

`CustomSection.category` is serialized inside the existing JSON payload. No SQL
migration is needed. Older JSON without a category recognizes familiar certificate,
course and project headings; other headings remain custom. An explicit custom
category remains custom even when its title resembles one of those headings.
CV snapshots, draft saves, profile merging, previews and exports retain the data.

Visibility filtering for native entry models is now applied in the shared document
resolver as well as section/hidden-ID filtering, preventing empty navigation pages
when all records in a section are individually hidden. Stored profile rows are
not deleted by these presentation changes.

Focused tests cover category/legacy JSON, custom-only projects, hidden entries,
selection while pages are added/removed, header contact destinations, category
editor retry and existing owner flows. The full presentation audit now exercises
all five pages in both owner and visitor views across its responsive/locale/theme
matrix; Experience and Credentials captures are retained with the other audit images.

## Portfolio appearance

Portfolio settings are always visible as a normal section of global Settings.
The owner and visitor About pages omit the Edit profile and Download CV footer.
The CV builder continues to provide editing and export.

Ocean, Forest, Rose and Sky blue apply to the page background, profile hero and
content cards. The colored palettes reuse the graphite gradient stops and match
their luminance in light and dark modes. Foreground colors remain unchanged.
Palette previews wrap into two columns on phones and four on wider screens.

Profile photos are uploaded in Portfolio settings and saved with that portfolio's
design, independently of the CV snapshot. Visibility and a 64–144px diameter are
saved per portfolio. CV previews and exports never read this photo setting.
Portrait uploads are bounded to 512px; new project images to 1600px, with JPEG
compression for opaque images and preserved transparency for artwork. Existing
stored originals are retained. Owner media URLs reuse a 45-minute in-memory cache;
visitor media is authorized again and signed in one Storage batch request.
Project images start loading on their first visit to the Projects tab.

## Executed verification

- Full suite: **358 tests passed**, 05:02, in
  `build/portfolio-pages-final-tests.log`.
- Static analysis: no issues in `build/portfolio-pages-final-analyze.log`.
- Focused owner/category/navigation checks: **21 passed** before the full suite,
  in `build/portfolio-pages-focused-tests.log`.
- Presentation matrix: all 12 combinations of 360/412/1440px, English/Arabic and
  light/dark passed with all five pages in both owner and visitor views. Extra
  Experience/Credentials captures are in `build/modernization-audit/`; selected
  phone-sized English and Arabic captures were visually inspected.
- Native model visibility, custom-section visibility, hidden entry IDs and
  category/legacy JSON are covered by `test/portfolio_sections_test.dart`.

The full suite also covers PDF/DOCX exports, account isolation, drafts, sharing,
password protections and reduced motion. This is not a new physical-phone or
full browser interaction acceptance run.

## Android distribution

Version `1.0.2+3` built successfully in 134.4s using the validated Android helper.
The APK retains package `com.mtfooda.cv_portfolio_maker`, the existing signing
identity and minimum SDK 24. The public release is
[v1.0.2](https://github.com/MTFOODA/CVProtfolio/releases/tag/v1.0.2), available through
the same stable `releases/latest/download/cv-portfolio-builder.apk` destination
used by About.

APK size: 75,029,829 bytes; SHA-256:
`a44d65f8c15b3a4fd4d72c166e2d7ac1699bc19daf3274279f50740fd660ac8b`.
GitHub's asset digest matches the local APK; anonymous range download returned
HTTP 206 and a valid APK/ZIP signature. Evidence:
`build/portfolio-pages-android-build.log`, `build/portfolio-pages-android-release.json`
and `build/portfolio-pages-download-verification.json`.

No new physical-phone installation was performed for this version. Earlier
native startup/restart verification is documented separately; the Android
distribution above contains this follow-up's tested source.

## Web publication

Web build succeeded in 57.5s. Cloudflare version:
`01a8045c-efa5-4fd9-821a-f0ba8d30137b`, with existing Worker variables preserved.
All eight hosted route/asset checks passed at
`2026-11-07T21:54:46.303597+00:00`, including About and slug/token SPA fallbacks.
Hosted main JS matches the local build, SHA-256:
`2ed1903768f920a68d1c950a041adc89cea3fd7ce943767b3d3d3161002b405f`.
Evidence: `build/portfolio-pages-web-build.log`,
`build/portfolio-pages-cloudflare-retry.log`,
`build/portfolio-pages-hosted-verification.json` and `.log`.

The first deployment failed during OAuth refresh with a network `ETIMEDOUT`.
IPv4-first DNS resolution for the Wrangler child process recovered the existing
session and deployed successfully. The deployment helper now includes that
option; no credentials or system-wide network settings were replaced.
