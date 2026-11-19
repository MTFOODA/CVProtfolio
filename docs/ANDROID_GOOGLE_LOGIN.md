# Android Google sign-in

## Cause of the reported behavior

The reported immediate transition to Dashboard without a Google account picker
matches the previous `LocalAuthService.signInWithGoogle()` implementation: it
called `signInLocally()`. This service is selected when the APK was compiled
without both Supabase URL and public key. Web was launched with the configuration
file, so its successful sign-in did not validate the Android APK configuration.

Hiding the Google button when build settings were absent obscured that problem.
Normal startup now calls `AppConfig.load()` to read the bundled public client
settings in `assets/config/public_app_config.json`. Plain `flutter run` and
`flutter build apk` therefore connect to this project without additional flags.
Build-time settings remain available for alternate deployments; a partial URL/key
override is rejected so credentials from two projects cannot be mixed.

The Google button stays visible. In explicit offline mode
(`--dart-define=OFFLINE_MODE=true`) it is disabled, with an explanation and a guest
action. Google requests never create a guest identity.

## Build and run with the connection settings

From the project root in PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build_android.ps1
# Optional development APK:
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build_android.ps1 -Mode Debug
# Run with the bundled connection on a connected Android device:
flutter run
# Build with bundled settings:
flutter build apk --release
```

The script refuses missing/placeholder required settings and invokes Flutter
with the configuration file. The release artifact is
`build/app/outputs/flutter-apk/app-release.apk`. VS Code offers the same command
as its default build task, **CV: Build connected Android APK**. Select
**CV: Supabase** for debugging. **CV: Offline** explicitly sets `OFFLINE_MODE=true`.
Rebuild and restart after this startup change; hot reload does not rerun `main()`.

The local file `dart_defines.json` contains only public client values. Android
uses `GOOGLE_WEB_CLIENT_ID` as `serverClientId`, currently:

```text
869804643203-3brq8bs5010ngfoqpsr9lm4sv5q5i70p.apps.googleusercontent.com
```

The client supplied in `google/` has the different ID ending in
`t2g98bujbh3498den9p4kmrg3dobb664.apps.googleusercontent.com`. Its downloaded
`installed` metadata contains no package name or certificate, so those values
cannot be verified from that file. It must not replace the Web server client
ID just because it is intended for Android. The directory is git-ignored and
is not bundled into the app.

## Google Cloud registration

For native Google authentication, Google Cloud also needs an **Android** OAuth
client in the same project as the Web client, matching the installed build:

```text
Project: infra-triumph-456221-b9
Package: com.mtfooda.cv_portfolio_maker
Signing SHA-1: 8E:87:F9:9A:02:C5:D7:50:A1:66:AD:75:0E:58:53:E6:8A:76:95:DD
```

The SHA-1 was read from this machine's debug keystore. Both current debug and
release build types use that keystore. A Play-distributed or differently signed
APK needs its own matching certificate registration. Android gets a Google ID
token and exchanges it with Supabase; no browser callback/deep link is involved.

## Verification

Regression checks cover refusal of offline Google requests (with and without an
existing local session), explicit guest access, and the actual offline login
screen. The startup regression also loads the actual bundled settings with no
build overrides and verifies that Google is visible and enabled in Login.
Existing Supabase session and biometric tests cover the connected flow's
session handling separately. All 33 selected authentication/biometric tests passed,
and `flutter analyze --no-pub` reported no issues. The connected release APK built
successfully without any `--dart-define` flags (67.6 MiB). The APK was inspected to
confirm that the public configuration asset is present, references the correct
Supabase project and Google client, and contains an `anon` public key. The signing
certificate was verified in the preceding build. Supabase's public Auth settings
also confirmed that the Google provider is enabled.

Android OAuth still requires an interactive account
selection on a device. No device was connected during this investigation and
the Google Cloud package/SHA-1 registration cannot be confirmed from the supplied
downloaded JSON.

References: [Flutter Android Google plugin setup](https://pub.dev/packages/google_sign_in_android),
[Google Android client setup](https://codelabs.developers.google.com/sign-in-with-google-android),
[Supabase Google authentication](https://supabase.com/docs/guides/auth/social-login/auth-google).
