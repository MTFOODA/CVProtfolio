# Application flow review — 2026-11-06

This pass changes application logic and regression coverage. Visual design is
held for the forthcoming Figma reference. No production deployment, database
migration, user-account creation or deletion was performed during the review.

## Flow and fixes

| Flow | Corrected behavior |
| --- | --- |
| Protected deep link → login → editor | Retains a validated app-relative `from` destination, including through registration, OAuth and password recovery. External and recursive auth destinations are rejected. |
| Account A → account B without a signed-out event | Owner routes watch session identity directly and recreate retained forms. A's unfinished content cannot remain in B's editor. |
| CV A → CV B; public slug A → slug B | Distinct widget keys reload the requested content instead of reusing the previous screen state. |
| Portfolio → `/portfolio/settings` | Updates the selected tab when the same routed screen receives changed query parameters. |
| Duplicate CV | Copies the saved profile snapshot, design and project selection. The duplicate starts private with a fresh ID, version and timestamps; public identifiers and password hashes are cleared. |
| Generate CV → sync shared profile | Retains the original merge baseline when the document write succeeds but profile synchronization fails. The draft journals the pending document and baseline, so reopening retries the same document and delta. |
| Save contact details | Loads the latest profile before saving, preserving projects, skills and the current avatar added while the form was open. |
| Document/profile read failure | Ends loading, prevents saving an empty replacement, and offers retry. |
| Portfolio creation and save races | Reuses in-flight initial creation; a previous account's write cannot replace the active account's portfolio state. |
| Account deletion during an account switch | Rechecks the intended Supabase owner after storage cleanup. Completion of A's deletion cannot sign B out. |
| Export validation/delivery | Ignores superseded validation results, prevents duplicate export actions, waits for validation, and keeps a successful delivery successful if local statistics fail. |

The CV snapshot remains the source for its preview, PDF and Word export.
Each CV now has an independent portfolio sourced from its saved snapshot. Portfolio styling, visibility, passwords and share links belong to that CV only. Sharing remains
behind the existing publication, password, expiry and revocation boundaries.

## Verification

- Full Flutter suite: 311 tests passed with `--concurrency=1` before the last
  account-identity regression was added. All 30 affected routing, portfolio,
  auth and account tests passed afterward, including that new regression.
- Flutter analyzer: no issues.
- Final release web compilation succeeded with the route-scoping changes.
- Share-media server tests: all 5 passed using Node's test runner.
- The suite covers Arabic/English, dark/light, draft recovery, exports,
  owner isolation and public access. UI behavior is checked in Flutter tests;
  a real browser/device sign-in remains a separate live check.

Commands:

```powershell
flutter test --no-pub --concurrency=1
flutter analyze --no-pub
flutter build web --release --no-wasm-dry-run
node --test supabase/functions/share-media/index_test.mjs
```

## Live backend follow-up

The configured project remains `shwjiytgrgbpleoljcnk`. Independent DNS resolves
it; the local resolver intermittently failed. A read-only audit using the
verified address and normal TLS certificate verification initially returned
HTTP 521 from Auth/REST. After restoration, the final audit passed 9 checks:
Auth health/settings, all four required tables/columns, and all three share
resolvers. Google and email are enabled; email confirmation is required.
`share-media` still returns HTTP 404 `NOT_FOUND`. Table checks request zero rows;
resolver checks use nonexistent identifiers. No user rows were fetched or
changed, and authenticated RLS policies were not exercised against the host.

Supabase CLI reports `AccessTokenRequiredError`. Authenticate the CLI locally
to deploy the existing media function. Do
not paste tokens in chat or source files. The current CLI's help confirms:

```powershell
npx.cmd --yes supabase login
npx.cmd --yes supabase functions deploy share-media --remote=shwjiytgrgbpleoljcnk --use-api --yes
python tools/check_supabase.py assets/config/public_app_config.json
```

The checked-in function configuration uses share credentials instead of an
owner session. Its server handler revalidates publication/password/token access
before signing only authorized owner media. A successful live recheck is still
required before claiming public image/video delivery works in production.
