# Android run diagnostic handoff

The available VS Code Flutter daemon log contains both:

- `failed to start daemon`, `could not read ok from ADB Server`, and
  `cannot connect to daemon` on the default ADB server.
- Device-property requests failing with `device ... not found`, including a
  request for one device referring to a different disconnected device ID.

This is evidence of an ADB connection/daemon problem, not a diagnosis of a Dart
application exception. The saved output channel contains successful `pub get`
runs; it does not contain a current physical-phone application stack trace.
The previous emulator smoke test also ended with `device offline`.

VS Code launch profiles now explicitly select `lib/main.dart` and the workspace
directory. Both connected/offline profiles retain their existing build flags.
`tools/run_android_debug.ps1` validates the connected public-client configuration,
uses an explicitly selected device ID and captures a timestamped run log in
`build/phone-debug-*.log`.

Per the user's request, finish code checks and build first. Then ask the user to
connect their phone, enable USB debugging, unlock it, and accept the computer's
RSA prompt. Only after that:

1. Inspect `flutter devices` and the configured SDK's `platform-tools/adb.exe`
   device state. Do not reuse a historical serial from a previous phone.
2. If the ADB server cannot connect, identify the executable/process owning port
   5037, stop the conflicting/stale ADB instance and start the configured SDK's
   ADB. This disconnects active debug sessions temporarily.
3. Launch `tools/run_android_debug.ps1 -DeviceId <the-current-phone-id>`.
4. Read the actual startup log, fix any Dart/platform exception, and rerun the
   affected flow. Do not clear application data or uninstall the user's app as
   a connection troubleshooting shortcut.

## Connected-phone verification — 2026-11-07

The user connected and authorized a physical Android ARM64 phone, model
`2506BPN68G`, Android 17 / API 37. The configured SDK's ADB reported `device`,
and Flutter identified the same current device. The old daemon/device-not-found
failure did not reproduce; restarting ADB was unnecessary.

The connected debug build installed and launched successfully from `lib/main.dart`.
Supabase initialized and the login screen rendered. The initial log contained
`refresh_token_not_found`: the server no longer recognized an old saved session.
The installed SDK removes an invalid session and emits signed-out; no app-data
clear or uninstall was performed.

This revealed a real UI issue: the biometric gate intentionally keeps the routed
session null while locked, so a saved Auth session expiring could leave the
biometric button stale. `LoginScreen` now observes the underlying Auth stream as
well as the gate. A regression test expires the saved session while the routed
session stays null, verifies that the button disappears, and preserves biometric
enrollment and the normal login options.

**33 focused authentication tests passed**, including the new expiry regression,
and static analysis of both changed files reports no issues. Evidence:
`build/phone-auth-regression.log` and `build/phone-fix-analyze.log`.

The fixed debug build was installed on the same phone with data preserved. A real
hot restart completed in **2,520ms**, Supabase initialized again, and the old
refresh-token warning did not repeat. A screenshot showed the authenticated
dashboard. The operator did not select an identity provider or submit credentials;
this is not a claim that a particular Google/email flow was automated.
The app-process log contains no `Unhandled Exception`, `FATAL EXCEPTION` or
framework exception after this run. Evidence:
`build/phone-fixed-run.log`, `build/phone-fixed-logcat.log` and
`build/phone-fixed-startup.png` (local ignored diagnostic artifacts).

The initial noninteractive run did not accept hot-restart input, and an explicit
debug-URL attach did not connect. Those attempts are not counted as restart
passes. The subsequent interactive `flutter run` installed the fix and verified
the restart above; its debugger was detached with `d` to leave the app running.
The initial debugger's later disconnect was caused by replacing that debug
build, not evidence of another physical USB failure.

After detaching, ADB confirmed that the fixed application process remained alive.
The corresponding web update was published and HTTP/hash verified; the
distributable release APK was rebuilt successfully in 62.2s. See the final
publication hashes in [UI_MODERNIZATION.md](UI_MODERNIZATION.md).

For the next VS Code run, choose the connected physical phone and the
`CV: Supabase` launch configuration, then F5. No global SDK/ADB configuration,
account data, private storage policy or Google provider settings were changed.

## CV preview exception — 2026-11-08

The existing phone debugger was paused on `_ExpansibleState.initState`:
`type 'double' is not a subtype of type 'bool?' in type cast`. The unkeyed
document-layout expansion tile inherited the outer controls scroll view's
PageStorage identity. Its embedded reorderable list also inherited the same
identity, mixing boolean expansion state with double scroll offsets.

The tile, reorderable list, controls scroll and preview scroll now have separate
document-scoped PageStorage keys. Narrow section cards put their title above
wrapping controls, fixing a second RenderFlex overflow found by the regression.

The new regression reproduced the type mismatch before the fix, then passed
three preview/customize round trips after scrolling and expanding the real
editor controls. All 28 focused flow/design/export tests passed, and analysis
reported no issues. Evidence is in `build/cv-preview-repro-test.log`,
`build/cv-preview-regression-tests.log` and `build/cv-preview-fix-analyze.log`.

The corrected debug APK was installed on the connected phone without clearing
data. The user manually repeated the flow and confirmed it worked without an
error. Android rejected automated taps with `INJECT_EVENTS` permission denied;
no device security setting was changed. The original paused app had already
exited before a draft backup could be read; no recovery of unsaved changes is
claimed. This fix alone did not publish a new web or public Android release.
