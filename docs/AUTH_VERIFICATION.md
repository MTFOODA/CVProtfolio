# Authentication verification — 2026-10-21

Project: `shwjiytgrgbpleoljcnk`. Tests used a separate Gmail alias, a generated
password stored only under git-ignored `.dart_tool/`, and synthetic records.
No real CV/profile data was modified. All synthetic database rows and the test
storage object were removed after testing. The disposable Auth account was then
deleted through `delete_own_account` after revoking its sessions; its generated
credential file was also removed.

## Verified against the hosted project

- Signup accepted; the user clicked the confirmation email. The server returned
  `email_confirmed_at` and accepted a real password login.
- A wrong password was rejected. `GET /auth/v1/user` validated the session.
- Authenticated profile save/read, document save, CV draft save and share save.
- Anonymous reads could not see the test profile. Inserting another owner's
  profile was rejected with HTTP 403.
- Public slug, recipient token and password-protected share resolution. Null,
  empty and incorrect passwords could not retrieve the protected document.
- Private media upload, owner-signed URL generation and downloading the exact
  uploaded bytes. Unsigned public access was rejected.
- Refreshing the session and validating the refreshed access token.
- Updating the test password, rejecting the old password and accepting the new
  password.
- Signing out and rejecting the revoked refresh token.
- Google authorization returned a 302 to `accounts.google.com`, with the correct
  Supabase callback and `email profile` scopes. The Google authorization entry
  page returned HTTP 200 without `invalid_client` or `redirect_uri_mismatch`.
- Simulating Google cancellation returned to `http://localhost:8080/`. The web
  recovery redirect including `?auth=recovery` was also accepted.
- The user then completed the real Google sign-in in their browser and confirmed
  that the app returned to its dashboard with the account shown. This interactive
  result is user-verified; it was not observed through browser automation.

## Code fixes and automated checks

- OAuth, confirmation and recovery explicitly return to the current web app;
  stale authorization codes and tokens are excluded from new redirect URLs.
- The public Google client ID advertised by the configured provider is now in
  the ignored build configuration, enabling native Android initialization.
- Provider-driven sign-out, refresh and recovery reach the application session
  controller. Recovery events are retained even when the user object is equal.
- A recovery callback opens a new-password form. Completing it clears recovery
  state and the URL marker so a refresh does not reopen the form.
- Successful registration with an active session leaves the registration route.
- Google configuration errors are no longer misreported as user cancellation.
  Concurrent initialization shares one initialization attempt.
- Errors distinguish bad credentials, unconfirmed email, rate limits, Google
  configuration and unavailable email delivery. Offline mode no longer claims
  to send recovery emails; the guest button is hidden for Supabase mode.
- 37 targeted Flutter tests passed, including the real Dart SDK against a local
  HTTP Auth stub, recovery/session events and affected portfolio/wizard screens.
- `flutter analyze --no-pub` completed without issues and the configured
  `flutter build web --no-pub --dart-define-from-file=dart_defines.json` succeeded.

## Checks still requiring interaction or deployment

- Browser automation was unavailable. The completed Google sign-in is confirmed
  by the user's interactive test, alongside the protocol and SDK checks above.
- Android Google sign-in requires a device/emulator and an Android OAuth client
  matching `com.mtfooda.cv_portfolio_maker` plus its signing SHA-1. No Android
  target was connected. Windows native Google sign-in remains unsupported by
  the current plugin; email sign-in is supported there.
- The new recovery callback/form was tested with the SDK and local HTTP stubs;
  clicking a real recovery email and completing the form is still a manual check.
- `share-media` still returns HTTP 404 and must be deployed separately. Owner
  storage access and signed downloads passed, but visitor media signing through
  that Edge Function remains unverified.
- Configure `SHARE_BASE_URL` with the deployed Flutter web origin before sharing
  links outside this local test.

Repeat read-only deployment checks with `python tools/check_supabase.py`.
`tools/live_auth_audit.py begin --email ADDRESS` creates one disposable test
account and sends its confirmation email; `verify` requires that account to
have been confirmed and exercises only its synthetic data. `cleanup` revokes
the disposable account's sessions, removes that account and deletes the local
generated credentials. It refuses to remove accounts outside a `+cv-audit-`
alias. The tool never prints passwords or tokens.
