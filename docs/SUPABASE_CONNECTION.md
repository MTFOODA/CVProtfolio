# Supabase connection

The app uses `dart_defines.json` (ignored by Git). Start it with:

```powershell
flutter run --dart-define-from-file=dart_defines.json
```

VS Code also has a **CV: Supabase** launch configuration. **CV: Offline** uses
local storage. Supplying build-time values selects a backend; it does not prove
that its database has been deployed.

## Audit on 2026-10-21

Project: `shwjiytgrgbpleoljcnk`.

- Auth health/settings respond with HTTP 200; Google and email are enabled.
- Email confirmation is required. Signup now leaves the app signed out until a
  real session exists and tells the user to confirm their email.
- REST returns `PGRST205` for `profiles`, `documents`, `document_shares` and
  `cv_builder_drafts`, and `PGRST202` for the three share resolvers. The required
  objects are unavailable through the Data API. Apply the migrations, or inspect
  schema exposure/cache if they already exist in the dashboard.
- The `share-media` Edge Function returns `404 NOT_FOUND` and needs deployment.
- The CLI has no authenticated account. The anon key cannot deploy SQL or
  functions. No hosted data or schema was modified during this audit.
- Google being enabled does not verify its client secret, Android SHA-1, web
  redirect allowlist, or a complete interactive sign-in. `GOOGLE_WEB_CLIENT_ID`
  is still empty and is needed for native Android Google sign-in.
- Set `SHARE_BASE_URL` to the deployed Flutter web application's origin before
  publishing links. The fallback example domain is not a working public site.

## Complete deployment

**Follow-up:** after manual SQL setup, all four tables and all three resolvers
passed hosted checks. Live email login, confirmation, password update, session
refresh, sign-out, data access and private storage tests also passed. The public
Google client ID is now configured and the user confirmed successful interactive
Google sign-in and return to the app. `share-media` still needs deployment. See
[`AUTH_VERIFICATION.md`](AUTH_VERIFICATION.md) for the current verification record.

Run these locally from the repository. Keep tokens and database passwords out
of chat and source files; enter credentials only through the CLI prompts.

```powershell
npx.cmd supabase login
npx.cmd supabase link --project-ref shwjiytgrgbpleoljcnk
npx.cmd supabase db push --dry-run
npx.cmd supabase db push
npx.cmd supabase functions deploy share-media --project-ref shwjiytgrgbpleoljcnk --use-api
python tools/check_supabase.py
```

Review the dry-run output before applying. Apply all five migrations in order;
`0001` and `0004` contained SQL syntax errors and have been repaired. The token
resolver, null-password rejection, pgcrypto search path and explicit table
grants have also been repaired. If another deployment already recorded earlier
versions, create a forward repair migration for that database instead of
editing its migration history.

For manual setup, open the project's **SQL Editor > New query**, paste the entire
`supabase/setup.sql` file, and click **Run** using the `postgres` role. The last
result should say `Setup complete` with `application_tables = 4`. This file is
generated from the five migrations by `python tools/build_supabase_setup.py`;
it runs in one transaction and supports re-execution. SQL Editor execution does
not record CLI migration history, so reconcile history before later using
`db push` on this manually initialized database.

Tables: `profiles` stores reusable profile content, `documents` stores CVs and
portfolios, `document_shares` stores share links, and `cv_builder_drafts` stores
unfinished CVs. The script also installs their RLS policies, RPC functions and
the private `document-media` storage bucket.

The SQL file does not deploy `share-media`. For manual function deployment,
open **Edge Functions > Deploy a new function > Via Editor**, name it
`share-media`, and paste `supabase/functions/share-media/index.ts` into
`index.ts`. Deploy it and turn off **Verify JWT** in the function settings:
public viewers prove access through the share credentials. Server keys must
stay in the function environment. Alternatively, deploy using the CLI command
above. `supabase/config.toml` disables gateway JWT checks
only for that function: its own code verifies the share credentials before
signing private media. Supabase injects its server keys into the function;
never add a service-role key to Flutter configuration.

## Verification

```powershell
# Read-only hosted probes: no rows fetched and no accounts created.
python tools/check_supabase.py

# Fresh isolated PostgreSQL, real SQL and RLS; Auth/Storage interfaces are stubs.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/test_supabase_migrations.ps1

# Share media authorization boundary.
node --test supabase/functions/share-media/index_test.mjs
```

The read-only probe checks table availability and public RPC/Edge Function
paths. It accepts `42501` anonymous access denials for private tables; those do
not verify authenticated grants or the full schema. After deployment, also sign
in with a test account and exercise
profile/CV saves, media upload, public/password/token sharing and sign-out to
verify the complete authenticated flow. Web recovery now returns to the app
with `?auth=recovery` and opens the new-password form. Its callback event and
password update are covered by SDK integration tests. See
[`AUTH_VERIFICATION.md`](AUTH_VERIFICATION.md) for the follow-up live audit.
