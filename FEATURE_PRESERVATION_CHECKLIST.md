# Feature preservation and modernization

The Flutter implementation is authoritative. The approved reference is
https://swell-stick-89036913.figma.site/ . Its published JS/CSS and component data
were inspected in `build/modernization-reference/`; browser control is unavailable.
Original source is backed up in `build/modernization-baseline.zip`.

Statuses: **A** listed automated preservation checks passed; **P** further
live/platform interaction verification remains. Every row was inventoried before
modification. A does not claim every interaction was manually verified. Rows
retain P because full live/device acceptance is not complete; they must not be
reported as fully accepted screens.

## Interaction inventory and mapping

| Existing feature and subfeatures | Original screen/route | Dependencies | Modernized location | Status / verification |
| --- | --- | --- | --- | --- |
| Google login; configured/offline enablement; loading; cancellation; errors | `/login` | SessionController, SupabaseAuthService | Auth card | A/P; auth_config, supabase_auth, auth_session |
| Email mode; email/password validation; visibility toggle; keyboard submit; back to provider choices | `/login` | auth service, form validators | Auth card | A/P; auth tests + interaction audit |
| Explicit offline guest identity and restoration | `/login` | LocalAuthService, local store | Auth card | A/P; local_auth_service, persistence |
| Enrolled biometric/Windows Hello login; failures and owner checks | `/login` | biometric lock and secure storage | Auth card | A/P; biometric_lock, secure_session_storage |
| Registration: name/email/password/confirmation; visibility; validation; confirmation-required feedback; login link | `/register` | session, auth, validators | Auth card | A/P; supabase_auth, auth_redirect |
| Request reset; validation; sending/error/sent states; return navigation | `/forgot-password` | session, auth | Auth card | A/P; auth tests |
| Recovery session/expiry; new password and confirmation; save/error; return destination | `/reset-password` | recovery provider, auth redirect | Auth card | A/P; auth_session, auth_redirect |
| Deep links; sanitized login return; recovery gate; account-scoped retained routes | router | GoRouter, session providers | All original routes retained | A/P; app_flow_regression |
| Home/Build CV/Portfolio/Settings navigation; retained builder state; public route back | `/` | dashboardTabProvider | Adaptive rail / mobile navigation | A/P; portfolio_ui, app_flow_regression |
| Greeting/avatar/profile/settings actions; pull refresh | Home | profile/session/documents/shares providers | Geometric dashboard hero | A/P; account_statistics, presentation audit |
| Real CV/view/download statistics, account isolation and refresh | Home | statistics, export counter | Dashboard statistic cards | A/P; account_statistics |
| Create CV; preview first CV; manage portfolio; download information | Home quick actions | router, repositories | Dashboard quick actions | A/P; portfolio_ui, presentation audit |
| List CVs; title/update date; preview; edit; more menu; duplicate snapshot/selections privately; delete confirmation; failures | Home document list | DocumentRepository | Document cards with original actions | A/P; app_flow_regression, portfolio_ui |
| Empty/loading/error/retry document states | Home | documentsProvider | Shared loading/empty cards | A/P; UI audit |
| Portfolio creation/preview/edit; publication state and URL | Home | portfolio controller/repository | Portfolio summary card | A/P; portfolio_controller_race, portfolio_ui |
| Full profile fields: name, title, email, international phone, location, website/display label, summary, multiple links/labels, avatar retention | `/profile` | ProfileRepository, contact controllers | Profile form | A/P; app_flow_regression, contact_header |
| Profile read/retry; save/validation/errors; retain newly added entries | `/profile` | profile providers | Profile form | A/P; app_flow_regression |
| Browse every built-in template; descriptions; CV/portfolio type dialog; create/error | `/templates` | templates, DocumentRepository | Template gallery | A/P; presentation audit, layout |
| Seven wizard steps; Continue/Back/Skip; validation; draft auto-save; Home/back handling; retry | `/wizard`, `/wizard/:id`, embedded dashboard | CvDraftRepository, controllers | Step wizard | A/P; cv_builder_wizard, cv_drafts_validation |
| Personal fields, contact destinations/display labels and language-aware validation | Wizard personal | profile model, validators | Wizard personal | A/P; cv_builder_wizard |
| Experience add/edit; organization/position/location/dates/current role/descriptions; validation | Wizard experience dialog | ExperienceEntry, draft | Modernized dialog | A/P; cv_builder_wizard |
| Education add/edit; qualification/field/institution/dates/grade/description | Wizard education dialog | EducationEntry, draft | Modernized dialog | A/P; date_range, cv_builder_wizard |
| Project add/edit/delete confirmation; title/summary/description/technologies; independent demo/repository; media picking/upload/retry/removal | Wizard projects | ProjectEntryDialog, MediaRepository | Project editor | A/P; portfolio_content_editing |
| Skill add/edit/delete confirmation; category/proficiency/icon search/picker; existing identity | Wizard skills | SkillEntryDialog, skill icons | Skill editor | A/P; portfolio_content_editing |
| Language add/edit; proficiency; optional dates remain safe | Wizard languages | LanguageEntry | Language editor | A/P; cv_builder_wizard |
| Review all entries; Generate; independent snapshots; delta merge; pending generation journal; reopening and retry; clear completed new draft | Wizard review | document/profile/draft repositories | Wizard review | A/P; app_flow_regression, cv_drafts_validation |
| Document title/save/export; retry loading; single/two/mixed columns; preview/edit | `/doc/:id` | DocumentEditorScreen, design notifier | CV design workspace | A/P; cv_design_settings, layout |
| Section add/reorder/move/rename/hide/remove; custom sections; page breaks; slots and widths | Document layout panel | SectionConfig, resolved document | Original advanced panel retained | A/P; layout, cv_design_settings |
| All section kinds: personal/profile/experience/education/certificates/projects/courses/skills/languages/awards/volunteer/publications/references/custom/pageBreak | Document editor | SectionKind, profile models | Original section controls + portfolio | A/P; layout, rendering tests |
| Per-section field visibility; per-entry ordering/hiding | Document editor | SectionConfig | Advanced layout controls | A/P; layout, export_rendering |
| Fonts, colors, body/name/title/section/entry sizes; alignment; details arrangement; icons/style/size; letter/line/item/paragraph/section spacing; margins/page controls/reset | CV design settings | DocumentDesign, CvDesignValue | Modernized design controls | A/P; cv_design_settings, cv_design_options |
| Dirty changes; save/discard/keep-editing; failed save retention; export saves first | CV design workspace | design notifier, owner callbacks | Original exit dialog | A/P; cv_design_settings |
| Designed/ATS mode; validation findings; preview/PDF share; DOCX; preparing/progress/error/cancel/success; statistics | Export sheet | DocumentExporter, ExportDelivery | Modernized bottom sheet | A/P; export*, docx, contact_header |
| English/Arabic PDF shaping, fonts, page layouts and Word content | Export | shared resolution/export engine | Output preserved unchanged | A/P; arabic_pdf, bidi_and_shaping, export tests |
| Portfolio About/Projects/Skills/Settings; tab state; live saved data; theme colors | `/portfolio` | portfolio/profile providers | Portfolio workspace | A/P; portfolio_ui, app_flow_regression |
| Avatar/name/title/summary; visible extra sections and contacts; download CV; view work; edit CV builder | Portfolio About | resolved document | Portfolio hero and section cards | A/P; presentation audit, portfolio_ui |
| Contact icon tap/open once; long press copy; safe external schemes | Portfolio | portfolioContacts, URL launcher | Original contact actions | A/P; presentation audit, contact_header |
| Visible projects and technology tags; media fallback; repository/demo buttons; video play/pause/seek/fullscreen/lifecycle/error | Portfolio Projects | media and video controllers | Interactive project cards | A/P; portfolio_video, portfolio_content_editing |
| Individual skill cards; icons/proficiency; empty/hidden states; edit action | Portfolio Skills | skill models/icons | Skill cards | A/P; portfolio_ui |
| Ocean/Forest/Rose themes; all visibility toggles; section drag order; save rollback; publication/unpublish confirmation; URL copy; password set/remove/validation | Portfolio Settings | PortfolioController, share/password RPCs | Global Settings entry + original portfolio tab/route retained | A/P; portfolio_ui, portfolio_access |
| Public slug/token viewer; owner actions absent; unknown/password gate; wrong-password retry; expiry/revocation/publication enforcement | `/p/:slug`, `/s/:token` | ShareRepository, RPCs | Public portfolio/CV viewer | A/P; portfolio_access, share_view_count |
| Public authorized download; link opening errors; view count; protected media signing | Public viewer | exporter, share-media | Original viewer actions | A/P; share_view_count, Edge Function tests; live media deployment pending |
| System/light/dark persistence and rollback; English/Arabic persistence and RTL | `/settings` | preference controllers | Global Settings | A/P; presentation audit |
| Biometric capability/status; enable/disable/prompt/failure; Windows Hello | Settings | biometric controller | Account settings | A/P; biometric_lock |
| Sign out/lock encrypted session; delete account confirmation; cleanup/errors; owner switch isolation | Settings | SessionController, repositories | Account settings | A/P; account_statistics, biometric_lock, supabase_account_scope |

## Reference-only features

| Feature | Safe implementation/dependency |
| --- | --- |
| Sidebar, floating mobile navigation, geometric/glass surfaces, auth split layout | Shared presentation components; retain all four destinations and every original route. |
| Profile strength and progress | Use existing `profileCompletion`; never invent ATS scores or comparative candidate rankings. |
| Certificates and Courses management in global Settings | A: four credential tests pass for add/edit/delete/cancel, visibility, URL validation, retry, preserved projects/CV snapshots, isolated wizard draft and ordering. Reuses CertificateEntry/CourseEntry and ProfileRepository; no migration. P: native/live acceptance. |
| AI recommendations, ATS scoring, weekly growth comparisons | Require defined analytics/scoring/backend contracts. Documented dependency; no fake numbers or decorative actions. |
| Figma example identity/data and email/GitHub buttons | Preserve the actual product identity and real user data; keep original authentication rather than the reference's mock enter-workspace action. |

## Verification record

- Pre-modernization baseline: 311-test suite, then 30 affected route/account tests
  and the extra account-switch regression passed in the preceding logic review.
- Final modernization suite: **327 passed** with `flutter test --no-pub
  --concurrency=1 --reporter expanded` (05:29), recorded in
  `build/modernization-final-clean-suite.log`. This includes the 20-test
  presentation audit, four credential tests, shared components/motion,
  authentication, account isolation, persistence, CV drafts, PDF/DOCX, portfolio
  media and public/password sharing regression tests. Global Settings shortcut navigation
  to Portfolio Settings, Certificates and Courses is included in the route tests.
- `flutter analyze --no-pub`: no issues. Final result is in
  `build/modernization-final-analyze.log`.
- Full screen matrix: 360x800, 412x915 and 1440x900, English/Arabic, light/dark.
  All 12 combinations passed after the final gradient contrast correction. 144 rendered Flutter screenshots are retained in
  `build/modernization-audit/`; selected captures were visually inspected.
- Real share-media handler tests: **5 passed**, Node test runner, in
  `build/modernization-media-tests.log`.
- Source preservation: all **34** existing data/domain/export files are byte
  identical to the pre-modernization backup; evidence in
  `build/modernization-data-preservation.json`. No schema migration is introduced.
- Build configuration: valid connected configuration accepted; placeholder share
  host rejected. Local ignored settings now explicitly use the existing
  Cloudflare share host, matching the bundled public configuration.
- Final read-only Supabase audit: **9 passed, 1 failed**. The only failure is
  `share-media` deployment HTTP 404. No user rows were fetched or changed.
  `build/modernization-live-backend.log` records the results.

### Outstanding acceptance checks

The native Android smoke test built and installed successfully, but the emulator
repeatedly disconnected (`device offline`) before completing its assertions,
including after a lower-memory/software-rendering retry. This is not a native
interaction pass. `integration_test/modernization_smoke_test.dart` is retained
for a stable emulator or physical device; final attempt is logged in
`build/modernization-native-verified.log`.

The Edge Flutter test runner started headless Chromium but stalled before test
results; it is not counted as passed. Native browser control is unavailable.
Live Figma screenshot comparison has not been performed; published component
source/CSS was inspected instead. No pixel-parity or physical-device performance
claim is made.

Hosted Google/email sign-in, biometric enrollment, file pickers and OS share/save
dialogs, and live authenticated publication/password/media flows require platform
acceptance. Deploying `share-media` requires local Supabase CLI authentication.
The reference's AI/ATS/ranking/growth features require backend contracts and are
not replaced with fabricated values.

Platform build, deployment and final navigation follow-up results are collected in
[docs/UI_MODERNIZATION.md](docs/UI_MODERNIZATION.md).

## Follow-up: sharing, structured entries and spacing — 2026-11-07

This user-requested follow-up supersedes the earlier seven-step/four-portfolio-tab
mapping above. Its source backup is `build/flow-refinement-baseline.zip`.

| Request | Implemented behavior |
| --- | --- |
| Share only the portfolio | Web path routing supports cold `/p/:slug` and `/s/:token` visitor routes; historical hash bookmarks normalize without rewriting OAuth fragments. Owner navigation/actions remain outside visitor views. Publication/password enforcement stays in the backend. |
| Appropriate app/skill icons | Shared rounded `AppIcons` vocabulary; bundled brand glyphs and technical lettermarks in a searchable catalogue of more than 130 choices. Name aliases, live suggestions and automatic exact matches retain existing saved IDs/manual choices. |
| Repeated items and review spacing | Wizard entry cards have 16px separation, padded rows and longer wrapping titles. Review uses separate label/value columns on desktop and stacked fields on narrow screens. Hero/contact spacing and mobile theme selection were corrected following screenshot inspection. |
| Additional entries after Languages | Eight-step wizard includes user-named sections and multiple add/edit/delete entries. Title, issuer, dates/current, credential ID, description, website and optional image persist in the isolated draft. Generate saves the CV snapshot and merges the profile without replacing another CV. |
| Preserve old credentials | Certificates/Courses buttons are removed from Review. Existing stored credentials and their Settings management routes remain available. |
| Start/end/current dates | Shared date input with picker, historical text compatibility and reversed-range validation covers experience, education, projects and custom entries. No time-of-day fields. |
| One settings page | Portfolio visibility/order/publishing/password/link controls live inside global Settings. Old settings paths redirect there; About/Projects/Skills remain as the three owner portfolio tabs. |
| All content targets | Custom sections resolve automatically with visibility/order filtering; authored names follow the profile unless a document explicitly overrides its heading. Preview, portfolio, PDF and DOCX include metadata/links and optional images. ATS PDF remains text-only. |
| Backward compatibility | New fields use existing JSON columns. Legacy Review draft index 6 migrates to 7; v2 step 6 remains Additional entries. No new SQL/schema change. |

The `share-media` handler additionally validates custom-section/entry visibility
before signing owner-scoped image paths; six server tests cover authorization.
Live function publication is still required and is documented in
[SUPABASE_SHARE_MEDIA_SETUP.md](docs/SUPABASE_SHARE_MEDIA_SETUP.md).

Physical-phone debugging requested by the user is tracked separately in
[ANDROID_RUN_DIAGNOSTICS.md](docs/ANDROID_RUN_DIAGNOSTICS.md): available editor
logs show ADB daemon/disconnected-device errors. No physical-phone run is claimed
before the user connects the device after code verification and builds.

The later connected-phone follow-up verified a real debug install/launch, an
authenticated dashboard, a 2,520ms hot restart and a running process after debugger
detach. An expired session exposed a stale biometric-button subscription; this
was corrected with a new regression case. **33 affected auth tests passed** and
the changed files analyze cleanly. This does not claim a fresh full 344-test run
or manual acceptance of every phone interaction. Precise evidence and updated
web/release details are in the two linked reports.

## Requested public About replacement

The visitor portfolio's PDF-download app-bar button is replaced, as explicitly
requested, by a circular information icon linking to a public developer/app About
page. This page uses MOHAMED TAREK FOODA and the supplied social profiles with
official bundled glyphs, plus Android APK and official web links. Owner exports
and shared CV download permissions retain their behavior. Public password checks
remain unchanged; navigation Back retains the original portfolio state.
See [docs/ABOUT_APP.md](docs/ABOUT_APP.md) for verification and distribution details.

## Content-driven pages follow-up

As requested later, Experience and Certificates/Courses move into their own
portfolio pages. All optional pages, including Projects and Skills, now depend
on resolved visible content. A typed custom section can supply a page even when
its native section is empty; removing/hiding its last entry removes that page.
Page identity/scroll state is retained while the available list changes.

Additional entries now have a category picker and editable names. Existing JSON
remains readable, and explicitly typed entries persist with drafts, profile merges
and CV snapshots. Contact content moves into the hero, with portfolio/website
links represented as icons. See [docs/PORTFOLIO_PAGES.md](docs/PORTFOLIO_PAGES.md).
