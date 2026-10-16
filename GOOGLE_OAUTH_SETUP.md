# Google Sign-In Setup — Google Cloud → Supabase → Flutter

This guide connects the three pieces this app actually uses. It is written for
this repository as it exists: **Android + web** are the platforms that can use
Google sign-in today, and the Android flow uses an **ID token** (no browser, no
redirect, no deep link).

Everything below uses placeholders. Replace them with your own values and never
commit the filled-in file.

| Placeholder | What it is | Where you get it |
| --- | --- | --- |
| `YOUR_GOOGLE_WEB_CLIENT_ID` | Web OAuth client ID (`…apps.googleusercontent.com`) | Google Cloud → Credentials |
| `YOUR_GOOGLE_CLIENT_SECRET` | The Web client's secret | Google Cloud → the same client |
| `YOUR_SUPABASE_URL` | `https://<project-ref>.supabase.co` | Supabase → Project Settings → API |
| `YOUR_SUPABASE_PUBLISHABLE_KEY` | Publishable (anon) key | Supabase → Project Settings → API keys |
| `YOUR_ANDROID_SHA1` | SHA-1 of the keystore that signs your build | `gradlew signingReport` (see step 3) |

---

## 1. Which Google Cloud screens to open

1. Go to <https://console.cloud.google.com/> and select (or create) the project
   that will own your OAuth clients. One project for all platforms is fine.
2. Open **APIs & Services → OAuth consent screen** (in the current console this
   lives under *Google Auth Platform*). Choose **External** unless you have a
   Workspace organisation, fill in the app name, a support email and a developer
   contact email.
3. Add the scope `.../auth/userinfo.email`, `.../auth/userinfo.profile` and
   `openid` — these are the defaults needed to identify a user, and are the only
   ones this app requires.
4. While the app is in **Testing** mode, add your own Google account under
   **Test users**. Publishing to production is only necessary when other people
   must sign in.

You do **not** need any extra Google API enabled for this app: it only reads the
identity from the ID token.

## 2. Create the Web OAuth client (required — it is used twice)

**APIs & Services → Credentials → Create credentials → OAuth client ID →
Application type: Web application.**

- Name: anything, for example `CV & Portfolio Studio — web`.
- **Authorised JavaScript origins**: the origin you serve the Flutter web build
  from, e.g. `http://localhost:8080` and, later, `https://your-site.example`.
- **Authorised redirect URIs**: the Supabase callback (see step 4), i.e.
  `https://<project-ref>.supabase.co/auth/v1/callback`.

Copy the **Client ID** and **Client secret**.

This single Web client serves three purposes:

1. it is the **Android** `serverClientId` (the plugin requires a *web* client ID
   on Android);
2. it is the **web** login client;
3. it is the client the **Supabase Google provider** uses.

## 3. Create the Android OAuth client

**Credentials → Create credentials → OAuth client ID → Application type:
Android.**

- **Package name**: `com.mtfooda.cv_portfolio_maker`
  (fixed by `android/app/build.gradle.kts`; if you change it, you must create a
  new Android OAuth client).
- **SHA-1**: the fingerprint of the keystore that signs the build you install.

Get the SHA-1 from the project:

```sh
cd android
./gradlew signingReport          # Windows: gradlew.bat signingReport
```

Look for the `SHA1:` line of the `debug` variant. Today **every** build type is
signed with the debug keystore (`android/app/build.gradle.kts` `buildTypes`), so
this one fingerprint is all you need until you add a real release signing config.
When you do, run `keytool` against that keystore and add its SHA-1 as a second
Android OAuth client (or as an extra fingerprint on the same one):

```sh
keytool -list -v -keystore YOUR_RELEASE.jks -alias YOUR_ALIAS
```

The Android client ID itself is **not pasted anywhere in this project** — Google
Cloud only needs to know the package + fingerprint combination.

## 4. Enable Google in Supabase

Supabase Dashboard → **Authentication → Providers → Google**:

1. Toggle the provider on.
2. **Client ID**: `YOUR_GOOGLE_WEB_CLIENT_ID` (the Web client from step 2).
3. **Client Secret**: `YOUR_GOOGLE_CLIENT_SECRET`.
4. Save. The panel displays the **callback URL** —
   `https://<project-ref>.supabase.co/auth/v1/callback`. Make sure the same URL is
   listed under *Authorised redirect URIs* of the Google Web client (step 2).

## 5. Tell Supabase where to return the browser (web only)

Supabase Dashboard → **Authentication → URL Configuration**:

- **Site URL**: the origin you will serve the web build from, e.g.
  `http://localhost:8080`. This matters because the app calls
  `signInWithOAuth` **without** a `redirectTo`, so Supabase falls back to this
  value.
- **Redirect URLs**: add the same origin, plus any other origin you use
  (`http://localhost:8080/**`, `https://your-site.example/**`).

Android needs nothing here: it never leaves the app.

## 6. Apply the database migrations (needed for the app, not for sign-in)

Authentication itself works without them, but every screen needs the tables:

```sh
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

or paste `supabase/migrations/0001_init.sql`, `0002_sharing_functions.sql` and
`0003_storage.sql` into the SQL editor **in that order**. `0003` also creates the
private `document-media` bucket.

## 7. Put the values into Flutter — exact locations

The project has **one** configuration entry point: `AppConfig.fromEnvironment()`
in `lib/core/config/app_config.dart`. It reads compile-time constants, so the
values are supplied at build time — either as flags or through a JSON file.

### Option A — a JSON file (recommended for daily work)

```sh
# PowerShell
Copy-Item dart_defines.example.json dart_defines.json
# macOS/Linux
cp dart_defines.example.json dart_defines.json
```

Then edit `dart_defines.json` (root of the project — it is git-ignored):

```json
{
  "SUPABASE_URL": "https://YOUR_PROJECT_REF.supabase.co",
  "SUPABASE_ANON_KEY": "YOUR_SUPABASE_PUBLISHABLE_KEY",
  "GOOGLE_WEB_CLIENT_ID": "YOUR_GOOGLE_WEB_CLIENT_ID.apps.googleusercontent.com",
  "GOOGLE_IOS_CLIENT_ID": "",
  "SHARE_BASE_URL": "https://YOUR_PUBLIC_SITE_ORIGIN"
}
```

Run it:

```sh
flutter run --dart-define-from-file=dart_defines.json
```

### Option B — command-line flags

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY \
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_GOOGLE_WEB_CLIENT_ID.apps.googleusercontent.com
```

### Which value goes where

| Value | Exact location | Notes |
| --- | --- | --- |
| Google **Web** client ID | `GOOGLE_WEB_CLIENT_ID` in `dart_defines.json` → `AppConfig.googleWebClientId` → `GoogleSignIn.instance.initialize(serverClientId:)` in `lib/data/auth/supabase_auth_service.dart` | Read on Android and web |
| Same Web client ID | Supabase → Authentication → Providers → Google → *Client ID* | The provider verifies the token with it |
| Google **client secret** | Supabase → Authentication → Providers → Google → *Client Secret* | Never in the app, never in git |
| Google **Android** client | Only in Google Cloud (package + SHA-1) | No value is pasted into Flutter |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | `dart_defines.json` → `AppConfig` → `Supabase.initialize` in `lib/main.dart` | Passing only one of them keeps the app in offline mode |
| `GOOGLE_IOS_CLIENT_ID` | `dart_defines.json` (leave empty) | Only used when an `ios/` folder exists |

### Rebuild requirements

These values are **compiled in**. After changing them you must:

1. stop the app,
2. rebuild (`flutter run` / `flutter build apk`),
3. reinstall on the device if you built an APK (`flutter install`, or
   `adb install -r build/app/outputs/flutter-apk/app-debug.apk`).

Hot reload and hot restart **will not** pick up a new client ID, and a stale
install can make you believe the new value is wrong.

## 8. End-to-end test procedure

### Android

1. `flutter run --dart-define-from-file=dart_defines.json` with a device/emulator
   attached (or build and install the APK).
2. On the login screen tap **Sign in with Google**.
   - *Expected:* the native account picker appears.
   - *If nothing happens at all* → the SHA-1/package pair does not match this
     build (see §10; the plugin reports this as a cancellation).
3. Choose an account.
   - *Expected:* you land on the dashboard with your name/e-mail loaded.
4. Supabase → **Authentication → Users** should now list a new user with the
   Google e-mail.
5. Save the profile screen, then check Supabase → **Table editor → `profiles`**:
   a row keyed by that user id should exist.
6. Create a document, edit it, export PDF and DOCX — the files should open.
7. Kill the app and reopen it: you should land straight on the dashboard
   (session restored from storage).
8. Settings → **Sign out**: you should return to the login screen; navigating to
   `/doc/<id>` while signed out must bounce back to `/login`.

### Web

1. Pick a fixed port so the origin is stable:
   `flutter run -d chrome --web-port=8080 --dart-define-from-file=dart_defines.json`.
2. Make sure `http://localhost:8080` is the Supabase **Site URL** (or is in
   **Redirect URLs**) before testing.
3. Tap **Sign in with Google** → the browser goes to Google, then returns to
   `http://localhost:8080/?code=...`; the app exchanges the code and shows the
   dashboard.
4. Repeat the dashboard/user checks above.

### Cross-user isolation (worth doing once)

Sign in with a second Google account and confirm the first account's documents
are not listed. Then open `/p/<some-slug>` in a private window: a document that is
not published must show the "not found" state, because publication is enforced by
the `SECURITY DEFINER` function rather than by the client.

## 9. iOS and macOS

There is **no `ios/` or `macos/` folder** in this project, so nothing to do there
yet. If you add the platforms later you will additionally need:

- an **iOS** OAuth client ID in Google Cloud whose bundle id matches your new
  Xcode project;
- `GOOGLE_IOS_CLIENT_ID` in `dart_defines.json` (it is already wired to
  `GoogleSignIn.instance.initialize(clientId:)`);
- the reversed client ID as a `CFBundleURLSchemes` entry in
  `ios/Runner/Info.plist`;
- a Google Cloud **macOS** client if you add macOS (or client secrets for a
  server flow).

Until then, the app reports Google sign-in as unsupported on desktop platforms
instead of failing silently.

## 10. Common errors and their fixes

| What you see | Cause | Fix |
| --- | --- | --- |
| The button does nothing on Android, no error | The plugin returns `canceled` for several configuration failures, and the app treats a cancellation as "stay on login" | Re-check: package name, the SHA-1 of the **installed** build's keystore, that `GOOGLE_WEB_CLIENT_ID` was passed at build time, and that you rebuilt (not hot-reloaded) |
| `Google sign-in is not configured: GOOGLE_WEB_CLIENT_ID is empty` | Value not supplied to the build | Pass `--dart-define=GOOGLE_WEB_CLIENT_ID=…` or the JSON file |
| `Google sign-in is not supported on this platform` | Windows/Linux build | Use Android or web |
| `redirect_uri_mismatch` (Google page) | Missing Supabase callback in the Web client | Add `https://<ref>.supabase.co/auth/v1/callback` under Authorised redirect URIs |
| Web returns to the page but you are still logged out | Site URL / Redirect URL mismatch, or the PKCE code was used in another tab | Align the Supabase Site URL with the served origin; test in one tab |
| `unsupported provider` | Google provider disabled | Enable it in Supabase and paste ID + secret |
| `Invalid API key` | Wrong publishable key, or only one of the two Supabase values supplied | Re-copy both values from Project Settings → API |
| `new row violates row-level security policy` | No session, or the row belongs to another user | Sign in; verify you are writing your own `id`/`owner_id` |
| 403 on storage | `0003_storage.sql` not applied, or the path is not prefixed by your user id | Apply the migration; use `uploadBytes`, which prefixes the path |
| Sign-in works, then the app "forgets" you | The session was revoked/expired and nothing watches `onAuthStateChange` | Sign in again; see PROJECT_ARCHITECTURE.md limitation #6 |

## 11. Security — what must never be shipped in the app

| Value | Ship in the app? | Where it belongs |
| --- | --- | --- |
| Google **Web client ID** (`…apps.googleusercontent.com`) | **Yes** — it is public | `dart_defines.json` + Supabase provider |
| Google **Android client ID** | Not used by the app at all | Google Cloud only |
| `SUPABASE_URL` | **Yes** | `dart_defines.json` |
| Supabase **publishable (anon) key** | **Yes** — public by design; RLS protects the data | `dart_defines.json` |
| Supabase **service-role key** | **Never** — it bypasses every RLS policy | Server-side only (Edge Functions, admin scripts) |
| Google **OAuth client secret** | **Never** | Supabase → Authentication → Providers → Google |
| Release keystore, `key.properties`, `*.jks` | **Never** | Your machine + CI secret store |

Practically:

- `dart_defines.json`, `.env*`, `google-services.json`, `*.jks`, `*.keystore`,
  `key.properties` and `*.pem` are already listed in `.gitignore` (added during
  this audit). Verify with `git status --porcelain` before your first commit.
- `--dart-define` values are embedded in the compiled app, which is fine for the
  public client values above and unacceptable for anything else.
- Only **public** client configuration belongs in this repository; a test asserts
  that `AppConfig.toString()` cannot print the key or client ID.

## 12. What could not be verified here and what you must copy yourself

This guide was written by reading the installed packages and this repository.
The following were **not** verified because no live project, credentials, device
or emulator were available:

- Whether the Supabase project has Google enabled, and with which client
  ID/secret.
- The **Site URL** and **Redirect URLs** values configured in your project — this
  guide deliberately does not invent them. Open
  **Authentication → URL Configuration** and copy the Site URL verbatim; it is the
  URL the browser is returned to, because the app sends no `redirect_to`
  (`gotrue` only includes that parameter when `redirectTo` is passed, and this app
  passes none).
- The `/auth/v1/callback` value — copy it from **Authentication → Providers →
  Google**, then paste it into the Google Web client's Authorised redirect URIs.
- Whether an Android OAuth client exists for package
  `com.mtfooda.cv_portfolio_maker` with your SHA-1.
- Any real sign-in, token refresh, storage upload or public-share resolution.

Once those dashboard values exist and the app has been rebuilt with
`GOOGLE_WEB_CLIENT_ID`, follow §8 to test the flow end to end.

## 13. The one-paragraph summary

Google Cloud issues a **Web** client (used by Supabase, and by Android as
`serverClientId`) and an **Android** client (package + SHA-1, never pasted into
code). Supabase stores the Web client ID **and secret** and returns the user to
its configured **Site URL** on web. The Flutter app reads only
`SUPABASE_URL`, `SUPABASE_ANON_KEY` and `GOOGLE_WEB_CLIENT_ID` — all supplied at
build time through `--dart-define` or `dart_defines.json` and consumed in
`lib/core/config/app_config.dart` — then either exchanges a native Google **ID
token** on Android (`signInWithIdToken`) or the PKCE **code** on web
(`signInWithOAuth`).


