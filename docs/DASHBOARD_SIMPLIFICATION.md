# Home simplification — 2026-11-08

Home now presents the greeting, account statistics, saved CVs and then profile
completion as its final content card. The Quick actions group and bottom My
portfolio summary card were removed at the user's request. Their private
widgets and unused helper code were removed too. The portfolio remains reachable
from the hero and main navigation; CV preview remains on each saved CV row.

The existing preview navigation test now uses that row's Preview CV tooltip
instead of the removed quick-action label. All 21 portfolio UI/account statistics
tests passed. The existing 360 px dark presentation walkthrough also passed;
its Home screenshot was inspected. Static analysis reports no issues.

Evidence:

- `build/dashboard-simplification-tests.log`
- `build/dashboard-simplification-analyze.log`
- `build/dashboard-simplification-visual.log`
- `build/modernization-audit/360-en-dark-_.png`

The CV preview PageStorage fix is described in
[Android run diagnostics](ANDROID_RUN_DIAGNOSTICS.md). The user confirmed the
corrected preview/customize flow worked on the connected phone. The phone was
disconnected before the subsequent Home update could be installed on it.

Three new gray/sky-blue logo proposals were generated with ImageGen and displayed
for selection: folded CV monogram, profile frame, and portfolio panels. They are
preview concepts; the existing application logo has not been replaced.

## Verified delivery

Version `1.0.3+4` is published. The existing Android signing configuration was
retained. APK metadata reports versionName `1.0.3`, versionCode `4`, min SDK 24,
target SDK 36, and ARMv7/ARM64/x86_64 support.

- APK size: `75,013,361` bytes.
- APK SHA-256: `35787d7fd5f6abbe268ca9a15eabcef7f0470301a1015af215610f4121e59b5f`.
- [Android release](https://github.com/MTFOODA/CVProtfolio/releases/tag/v1.0.3).
- The stable latest APK URL returned HTTP 206 and the expected ZIP header;
  unauthenticated release metadata reports the matching digest.
- [Web app](https://cvprotfolio.mohamed-fooda-mtf.workers.dev).
- Cloudflare version: `b517b5fa-d554-46a4-8593-74274a7d5a17`.
- Hosted JavaScript SHA-256:
  `6698a7a8b228f62d90d51e3dcfe4209bbd72e963a20bbc027300ed253cdfe79b`.
- Eight HTTP delivery checks passed, including app shell routes, JavaScript and
  branding assets. The hosted shell and JavaScript match the local release.
  These are delivery checks, not an automated live authentication test.

Publication evidence is in `build/dashboard-android-release.json`,
`build/dashboard-android-public-verification.json`,
`build/dashboard-cloudflare-deployment.log` and
`build/dashboard-hosted-verification.json`. As disclosed in the release body,
the APK includes local workspace changes beyond the tagged repository baseline;
this publication does not claim those source changes were pushed to GitHub.
