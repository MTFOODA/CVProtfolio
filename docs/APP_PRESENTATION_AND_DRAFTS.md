# App presentation and CV drafts

The app restores the saved theme and locale at startup. Its GoRouter instance
is retained while preferences change, so changing Arabic/English or light/dark
does not reset navigation. App chrome uses semantic Material colours, with the
bundled Arabic font as a fallback. CV paper keeps the document's selected colours
and language independently of the app theme.

Portfolio visitors use About, Projects and Skills, including the additional saved
About sections. They receive no settings tab or owner editing actions. Existing
slug, password, recipient-token, publication, expiry and revocation checks still
run before the visitor interface is built.

GitHub, LinkedIn, WhatsApp and email actions open on a tap and copy on a long
press. WhatsApp opens `wa.me` with international digits, while copying preserves
the phone number with its country prefix. See the official
[WhatsApp click-to-chat format](https://faq.whatsapp.com/5913398998672934).
Contacts represented by these icons are omitted from the Contact text card.
Clipboard feedback follows the completed clipboard operation.

## CV content and unfinished work

New CVs start with an empty `UserProfile` draft. Editing an existing CV loads
that CV's saved `profileSnapshot`. Drafts use the same profile model and repository
abstraction, with separate keys per owner and document (`new` for an unfinished
new CV). Text edits and section changes save the unfinished draft. The top Back
and system Back save it and return Home; the bottom Back changes wizard steps.

Generate saves the selected document's content, syncs changed content into the
live Portfolio profile, then removes its unfinished draft. A new CV does not erase
unrelated Portfolio projects or overwrite older CVs. Editing an older CV applies
only changed entries and explicit deletions, preserving unrelated newer profile
content. PDF, DOCX and previews resolve the document snapshot through the existing
shared resolver; Portfolio continues to read the live profile.

## Supabase deployment

Apply `supabase/migrations/0005_cv_drafts.sql` after migrations 0001–0004. It adds
`documents.profile_snapshot`, backfills existing CVs from their current profiles,
and creates owner-only `cv_builder_drafts` rows under RLS. Draft rows cascade on
account deletion. The migration also extends the existing share document payload
without returning password hashes. Redeploy the `share-media` function so saved
CV snapshots receive authorised temporary media links too.

The Flutter client reports backend/draft errors rather than reporting a save
that did not complete. These schema changes must be deployed before using the
updated CV Builder against Supabase. No migration is required in device-local
mode; existing CVs are preserved before replacing their shared profile.

## Validation and checks

Shared validators reject Arabic/Latin mixtures in names and descriptions, require
proper names, validate emails and web/social destinations, and require an
international country prefix for phone/WhatsApp numbers. Arabic and Persian digits
are accepted for phone input. Grade is a text field and accepts words, letter
grades, percentages and decimal scores. Invalid unfinished input can remain in
a draft; final submission validates it.

`test/app_presentation_audit_test.dart` walks the feature routes in both languages
and themes, checks preference restoration/navigation, visitor tabs, clipboard
gestures, narrow RTL layouts, keyboard insets and the new-CV lifecycle. Review
images are written to `build/app-audit/`. Theme role tests check active text
contrast. Local persistence/content isolation and input conditions are covered by
`test/cv_drafts_validation_test.dart`. Supabase media handler tests use mocked HTTP;
these checks do not replace deployment validation or physical-device video tests.
