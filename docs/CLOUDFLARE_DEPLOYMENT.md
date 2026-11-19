# Cloudflare web deployment

Production app: https://cvprotfolio.mohamed-fooda-mtf.workers.dev

`wrangler.jsonc` targets the existing `cvprotfolio` Worker and serves Flutter's
release output from `build/web`. SPA fallback lets shared routes open directly.
`web/_headers` prevents stale bootstrap/index caches and adds basic response
headers. Credentials stay in Wrangler's existing login; they are never tracked.
Deployment uses `--keep-vars` to retain existing dashboard-defined Worker variables.

From PowerShell:

```powershell
flutter test
flutter analyze
powershell -NoProfile -ExecutionPolicy Bypass -File tools/deploy_web.ps1 -ShareBaseUrl https://cvprotfolio.mohamed-fooda-mtf.workers.dev
```

The bundled public app settings also name this share host, so native app links
point to the same site. To use a different host, pass `SHARE_BASE_URL` at build
time. A portfolio must be published in global Settings → Portfolio settings before its `/p/slug`
URL is available to visitors. The app's home URL opens the builder/sign-in;
it is separate from a specific person's published portfolio.

The web entrypoint selects path routing before initializing Auth. It normalizes
old `#/...` bookmarks and leaves OAuth token fragments intact. Shared URLs use
the dedicated visitor routes; Cloudflare's SPA fallback handles cold path loads.
Private storage media also requires the `share-media` Edge Function; see
[SUPABASE_SHARE_MEDIA_SETUP.md](SUPABASE_SHARE_MEDIA_SETUP.md).

Authentication and stored profiles still use the configured Supabase project.
The site's origin must be allowed in Supabase Auth's redirect URLs for OAuth
and password recovery. No database or Auth settings are changed by deployment.

Useful checks:

```powershell
npx.cmd --yes wrangler deployments status --name cvprotfolio
```

Check `/`, `/p/a-sample-route`, `/flutter_bootstrap.js`, `/main.dart.js`,
`/manifest.json` and `/icons/Icon-192.png` after deployment. Deep links should
return the app shell; asset URLs must return their actual content types.

The deployment helper uses child-process IPv4-first Node DNS ordering. A later
deployment encountered an OAuth refresh `ETIMEDOUT` reaching the Cloudflare Auth
server; retrying with this option refreshed the existing session and deployed
successfully. Stored credentials and system-wide DNS/proxy settings were not
changed. The equivalent command is:

```powershell
npx.cmd --yes --node-options=--dns-result-order=ipv4first wrangler deploy --keep-vars
```
