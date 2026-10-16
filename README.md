# CV & Portfolio Studio

CV & Portfolio Studio is a Flutter app (Android, web, Windows) that builds CVs
and portfolios from one reusable profile, renders them live, and exports
designed/ATS PDFs plus editable DOCX files. Supabase provides auth, database,
storage and sharing; with no credentials configured the app runs fully offline
against local storage.

## Documentation

| Document | What it covers |
| --- | --- |
| [`PROJECT_ARCHITECTURE.md`](PROJECT_ARCHITECTURE.md) | Complete architecture: layers, data model, rendering/export, backend, limitations |
| [`GOOGLE_OAUTH_SETUP.md`](GOOGLE_OAUTH_SETUP.md) | Step-by-step Google Cloud → Supabase → Flutter sign-in setup |
| [`supabase/migrations/`](supabase/migrations) | SQL migrations that must be applied to a Supabase project |
| [`dart_defines.example.json`](dart_defines.example.json) | Template for build-time configuration (copy to `dart_defines.json`) |

## Run it

```sh
flutter pub get

# Offline mode: local identity, local JSON storage, no external services.
flutter run

# Supabase mode: copy the template and fill in your own values first.
cp dart_defines.example.json dart_defines.json   # PowerShell: Copy-Item
flutter run --dart-define-from-file=dart_defines.json
```

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
