# Public About and Android download

Shared **portfolio** pages now show a circular information icon in the app bar,
replacing their PDF-download action. The icon opens `/about?theme=<palette>`.
It appears independently of the document's PDF-download permission; CV document
viewers and owner exports keep their existing download behavior.

About is a public route with no profile/backend dependency. It displays the app
logo, the requested developer name **MOHAMED TAREK FOODA**, official bundled
LinkedIn/GitHub brand glyphs and the exact supplied profile URLs. Android download
and the official web-app destination are centralized in
`lib/core/branding/app_branding.dart`. The page uses the portfolio palette and
shared surfaces/spacing, supports Arabic/English and light/dark, and preserves
the original viewer's state when returning with Back.

- Developer GitHub: https://github.com/MTFOODA
- Developer LinkedIn: https://www.linkedin.com/in/mohamed-fooda-08b00132a/
- Web app: https://cvprotfolio.mohamed-fooda-mtf.workers.dev
- Stable APK link: https://github.com/MTFOODA/CVProtfolio/releases/latest/download/cv-portfolio-builder.apk

The APK is hosted as a GitHub Release asset. The helper
`tools/publish_android_release.py` reads the existing Git Credential Manager login
in memory, creates a draft release, verifies the uploaded asset's SHA-256 and
publishes only when called with `--publish`. It does not replace assets on an
existing published release or print credentials. Release notes identify that the
binary includes local workspace changes not yet committed to the tagged baseline.
The existing Android signing identity is preserved. This About feature initially
shipped as `1.0.1+2`; the later content-driven pages update is documented in
[PORTFOLIO_PAGES.md](PORTFOLIO_PAGES.md).

Verification:

- **28 focused tests pass** for About destinations, unauthenticated direct access,
  visitor navigation/Back, account flows and existing password protections:
  `build/about-final-tests.log`.
- **9 About tests pass** after the final full-height background/website icon
  correction: `build/about-visual-final-tests.log`.
- Changed source/tests analyze without issues: `build/about-final-analyze.log`.
- Eight responsive captures cover 320/1440px, English/Arabic and light/dark in
  `build/about-audit/`; selected captures were visually inspected.

This follow-up does not alter sharing RPCs, database schema, user profile data or
the pending private-media Edge Function deployment described separately.

## Android publication

Release [v1.0.1](https://github.com/MTFOODA/CVProtfolio/releases/tag/v1.0.1) is public.
The APK reports package `com.mtfooda.cv_portfolio_maker`, version name `1.0.1`,
version code `2` and minimum SDK 24. It is 75,013,249 bytes; SHA-256:
`2e8808333dcd075dd8c021d0178efc66e33d1143cdf9ea3e379d2b3bc246c71d`.
GitHub's uploaded-asset digest matches the local APK. The stable latest-download
URL was checked anonymously and returned HTTP 206 with a valid ZIP/APK signature.
Evidence: `build/about-android-release.json`,
`build/about-download-verification.json` and `build/about-android-publish.log`.

The initial `--no-pub` Android build failed because a generated plugin registrant
still referenced the integration-test development plugin. Regenerating metadata
with `flutter pub get --offline` and using the validated Android build helper
removed that development plugin from the release registrant. The final release
built successfully in 39.8s; `build/about-android-retry.log`. No generated Java
file or dependency was manually patched. Future production Android builds should
use `tools/build_android.ps1` after tests.

## Hosted verification

Web release built in 58.3s and was deployed to the existing Cloudflare Worker
with preserved variables, version `4dab6c16-a338-4a46-a4c0-3e13d5d98748`.
Eight HTTP checks passed at `2026-11-07T16:39:11.161483+00:00`, including a cold
`/about` request and the slug/token fallbacks. Hosted JS matches the local build;
SHA-256 `49d295b6fcbe047cd252adf4765f38b0936c4bf592f2d49b928aaae285924f1e`.
Evidence: `build/about-web-build.log`, `build/about-cloudflare-deploy.log`,
`build/about-hosted-verification.log` and the current
`build/flow-refinement-hosted-verification.json`. Earlier hosted metadata was
retained as `build/pre-about-hosted-verification.json`.

These are widget-rendering and HTTP/artifact checks; a new physical-phone
interaction or full browser acceptance run is not claimed for this follow-up.
