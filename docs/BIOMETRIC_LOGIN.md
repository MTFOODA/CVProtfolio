# Biometric login

Enable **Sign in with biometrics** in Settings after signing in to a Supabase
account. The device must have biometrics enrolled, and enrollment requires a
successful native authentication prompt. Windows uses Windows Hello, which can
include a device PIN. The option is unavailable on the web and in offline mode.

When enabled, a cold start or leaving the application returns to Login. The
fingerprint button unlocks the same existing account after native verification.
Email and Google sign-in remain available as fallback. Cancelled/failed prompts,
token refreshes and late prompt results after backgrounding cannot unlock it.
An opaque cover hides private content while the application is inactive.

Closing or backgrounding the app locks its local interface while retaining its
encrypted Supabase session. The Settings **Sign out** action now does the same
for an enrolled account: it returns to Login and keeps the fingerprint button
available, including after a restart. The stored session can be exposed to the
interface only after successful native verification or fresh email/Google login.
Refresh events and failed/cancelled biometric prompts leave the interface locked.

Without enrollment, **Sign out** revokes the session normally. To remove a saved
biometric session, disable the option in Settings and then sign out. Account
deletion still uses complete sign-out and clears enrollment. Signing in as a
different account clears the previous account's enrollment. A previously revoked
or expired session requires normal sign-in; biometrics cannot recreate one.
Users whose earlier logout cleared enrollment need to sign in and enable it once
after this update.

Android uses `FlutterFragmentActivity`, `USE_BIOMETRIC`, AppCompat themes and
requires Android API 24+. Native Supabase sessions use `flutter_secure_storage`;
the prior SharedPreferences session is migrated and removed only after the
encrypted write succeeds. The opt-in owner ID is a separate local preference.
Passwords and biometric samples are never stored by this feature. This is a
local session gate, not a replacement for Supabase server authentication.

Automated tests cover native prompt success/cancellation through a fake device,
startup and lifecycle routing in the actual root widget, stale prompt results,
refresh/cancellation bypass prevention, logout/account changes, unavailable
hardware and encrypted-session migration. Sensor verification still requires a
physical supported device with an enrolled fingerprint/biometric, or Windows
Hello.
