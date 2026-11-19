# CV & Portfolio Builder

CV & Portfolio Builder is a Flutter app (Android, web, Windows) that builds CVs
and portfolios from one reusable profile, renders them live, and exports
designed/ATS PDFs plus editable DOCX files. Supabase provides auth, database,
storage and sharing. Normal startup loads the bundled public project settings;
an explicit offline mode uses local storage.

## Documentation

| Document | What it covers |
| --- | --- |
| [`PROJECT_ARCHITECTURE.md`](PROJECT_ARCHITECTURE.md) | Complete architecture: layers, data model, rendering/export, backend, limitations |
| [`GOOGLE_OAUTH_SETUP.md`](GOOGLE_OAUTH_SETUP.md) | Step-by-step Google Cloud → Supabase → Flutter sign-in setup |
| [`supabase/migrations/`](supabase/migrations) | SQL migrations that must be applied to a Supabase project |
| [`docs/SUPABASE_CONNECTION.md`](docs/SUPABASE_CONNECTION.md) | Connection audit, deployment steps and read-only verification |
| [`dart_defines.example.json`](dart_defines.example.json) | Template for build-time configuration (copy to `dart_defines.json`) |
| [`assets/branding/README.md`](assets/branding/README.md) | Logo assets, launcher-icon generation and where the display name lives |
| [`docs/VISUAL_IDENTITY.md`](docs/VISUAL_IDENTITY.md) | Gray/sky brand, spacing and accessible motion |
| [`docs/APP_FLOW_REVIEW.md`](docs/APP_FLOW_REVIEW.md) | Logic review, corrected flows, regression checks and live backend follow-up |
| [`docs/CLOUDFLARE_DEPLOYMENT.md`](docs/CLOUDFLARE_DEPLOYMENT.md) | Build, publish and verify the web app |

## Run it

```sh
flutter pub get

# Connected mode: uses assets/config/public_app_config.json automatically.
flutter run

# Explicit offline mode: local identity and local JSON storage.
flutter run --dart-define=OFFLINE_MODE=true

# Override the connection for another deployment.
cp dart_defines.example.json dart_defines.json   # PowerShell: Copy-Item
flutter run --dart-define-from-file=dart_defines.json
```

For an Android APK with real Supabase/Google authentication on Windows, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build_android.ps1
```

This validates the override settings and passes them to the release build.
VS Code's default build task does the same. A plain `flutter build apk` also
connects using the bundled public settings. Use **CV: Offline** only for explicit
guest access. See
[`docs/ANDROID_GOOGLE_LOGIN.md`](docs/ANDROID_GOOGLE_LOGIN.md) for the Android
OAuth package and certificate checks.

`dart_defines.json` is git-ignored. Only public client values belong in it; the
Supabase service-role key and the Google OAuth client secret must never be
placed in it (or anywhere else in this repository).

## Checks

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
```

## Getting Started with Flutter

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

## CV builder, portfolio and access control

The app now ships a guided eight-step CV builder (personal information,
experience, education, projects, skills, languages, custom entries, review), a portfolio
builder that renders the same saved profile with Ocean/Forest/Rose themes, and a
portfolio settings section inside global Settings for visibility, drag-and-drop ordering,
publishing, link sharing and password protection.

Experience, education and projects accept start/end dates and an ongoing option.
Custom sections have user-defined names, structured entries, links and optional
images; they persist in drafts, the shared profile and independent CV snapshots,
and appear in previews and exports. Legacy JSON and draft step indices remain
readable. Skill search suggests bundled brand icons and technical lettermarks.
Portfolio pages appear according to visible content: About, Experience, Projects,
Skills and Certificates/Courses. Additional entries have a type picker while
retaining user-defined section names. Contact details and website/portfolio icons
live in the profile hero; see [docs/PORTFOLIO_PAGES.md](docs/PORTFOLIO_PAGES.md).
Historical settings URLs
redirect to `/settings?section=portfolio`.

Visitor links use `/p/:slug` with the web path routing strategy and SPA fallback.
They open the visitor portfolio without owner navigation; protected links resolve
only after server-side password verification. Local-only profiles cannot create
cross-device links.

Data paths that matter when you deploy:

| Capability | Where it is enforced |
| --- | --- |
| Email/password auth, Google Sign-In, password reset | Supabase Auth when configured; a device-local identity otherwise |
| Portfolio visitor password | Postgres `crypt`/`gen_salt('bf')` inside `set_portfolio_password` and `resolve_share_with_password` (`supabase/migrations/0004_portfolio_access.sql`). Local mode hashes with salted SHA-256 in `lib/data/portfolio/password_hash.dart` and is a single-device feature, not server-enforced privacy |
| Public/private visibility | `documents.published` plus the `SECURITY DEFINER` share resolvers; `resolve_share_by_slug` refuses any document that carries a password hash |
| "Downloads" dashboard statistic | Successful PDF/Word deliveries counted per account on this device in `lib/data/local/export_counter.dart`; removed after account deletion. The unowned legacy device total is discarded |
| "Portfolio views" dashboard statistic | Successful authorized share opens recorded through the existing view-counter RPC; Home sums shares of the current account's portfolio documents and refreshes when Home is selected |

Apply all migrations in `supabase/migrations/` (including
`0004_portfolio_access.sql`) before enabling password-protected portfolios in a
Supabase deployment.

Visitor images use the deployed `share-media` Edge Function; see
[the share-media deployment steps](docs/SUPABASE_SHARE_MEDIA_SETUP.md). Project
and work experience descriptions support separate items with optional headings,
shown in bold in previews, shared pages, PDF and Word. The searchable heading
picker includes broad project/work suggestions and accepts custom headings
typed directly; saved custom headings can be reused within the same description.
Existing descriptions
remain readable, and these changes need no new database migration. For the
reported Android run problem, see [the ADB diagnostic handoff](docs/ANDROID_RUN_DIAGNOSTICS.md)
and `tools/run_android_debug.ps1` after connecting the phone.

Shared portfolio visitors can open the public [About page](https://cvprotfolio.mohamed-fooda-mtf.workers.dev/about)
through the circular information icon. Developer links and official Android/web
downloads are documented in [docs/ABOUT_APP.md](docs/ABOUT_APP.md).
