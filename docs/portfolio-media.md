# Portfolio project media and skill icons

Projects use the existing `ProjectEntry.media`, `demoUrl` and `sourceUrl` fields.
Uploads go to the private owner-scoped `document-media` bucket through the
existing media repository. Images are limited to 10 MB and videos to 100 MB;
the Supabase project/bucket upload limit must also permit the selected size.
MP4 with H.264/AAC provides the broadest Android/browser compatibility. MOV and
WebM playback depends on the device codecs. Playback is on demand and pauses
when switching Portfolio tabs or backgrounding the app. PDF/DOCX exports retain
project text and repository links; video bytes are never embedded as images.

Skill icon identifiers live alongside each saved `SkillEntry` in the existing
profile JSON. Old or unknown identifiers use the General icon. The fixed catalog
uses Material icons and does not need external images or another data table.

## Supabase deployment

Keep `document-media` private and apply the existing sharing/storage migrations.
Deploy the media resolver from this repository:

```sh
supabase functions deploy share-media --no-verify-jwt
```

The function uses Supabase's standard `SUPABASE_URL`, `SUPABASE_ANON_KEY` and
`SUPABASE_SERVICE_ROLE_KEY` server environment. Never put the service role key
in Flutter defines. Anonymous invocation is intentional: the function verifies
the existing slug/password/token RPC before signing owner-prefixed media from
visible, included projects. No storage policy is relaxed. Signed links expire
after one hour; reopening the shared page renews them after checking access.
Revocation prevents new resolutions; already issued links remain valid until
their expiry. If the function is not deployed, shared text remains available,
but private media cannot play. Owner previews continue to use owner-authorised
signed URLs.

## Checks

```sh
node --test supabase/functions/share-media/index_test.mjs
flutter test test/portfolio_content_editing_test.dart test/portfolio_video_test.dart
```

The server handler tests use Node 24's native TypeScript support and mocked
Supabase HTTP responses. They are not a live deployment or real-device codec
test. Local mode stores media on the current device and cannot publish it to
another device without the configured Supabase backend.
