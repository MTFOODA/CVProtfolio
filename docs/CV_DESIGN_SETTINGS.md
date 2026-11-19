# CV Design Settings

Open a saved CV in the document editor and use **CV Design Settings** in the
app bar. The existing editor owns one `ValueNotifier<DocumentDesign>` draft.
The settings controls and `DocumentView` listen to that draft, and the existing
save operation persists the selected `CvDocument` through the current backend.
The Dashboard, Portfolio and authentication are unchanged. The CV Builder and
profile editor additionally support optional contact display names.

Save changes explicitly. Back navigation offers Save, Discard, or Keep editing.
Failed saves retain the draft and allow retry. Settings are scoped to document
IDs; the shared profile content and section visibility/order are preserved.

## Persisted fields

Existing typography, presentation and spacing fields are reused. Nullable name
font, professional-title size, entry-header size, horizontal margin and vertical
margin preserve legacy defaults. Header contact arrangement, icon treatment and
date/location position are additive JSON fields; no database migration is needed.
Margins are stored in points and displayed in millimeters (72 / 25.4 points/mm).
Body size, name/title/heading/entry sizes, line height, spacing and margins have
bounded controls; the editor never copies CV profile content into these settings.

## Preview and export behavior

- Flutter and PDF use bundled Inter, Lora, Roboto and Noto Naskh Arabic.
  The name can follow the body or use an independent font. Word packages embed
  the chosen fonts, including the Arabic fallback and Material contact glyphs.
- Date and location metadata reserves its measured width in Right mode, keeping
  the full date on one line. This applies to projects as well as work/education.
  A separate Date & Location Font Size control persists per CV. Below Title
  keeps dates under the title. RTL mirrors the trailing position to the left.
- School & Employer Position places the institution/company under the title
  by default, with alternatives beside the title or with the date. Supporting
  text keeps its lighter color. The Profile heading follows its saved name,
  casing and visibility in the preview, PDF and Word.
- Compact contacts wrap, Multi-row contacts stack, and Grid contacts use two
  columns. Long contact values and entry headings wrap without truncation.
- Word uses native paragraphs, tables, run styles, margins and line spacing.
  Circular and rounded contact treatments use the closest reliable Word run
  equivalent: a shaded bordered tile. Plain icons remain unframed.
- The on-screen preview reuses the existing continuous document renderer.
  PDF and Word paginate at export; page breaks can differ because the two
  engines measure fonts and line spacing differently.
- Export has one PDF presentation: the saved design. Preview, Save or share,
  Portfolio downloads and public CV downloads use it. Contact display names,
  icons and project link icons stay compact and clickable. Project demo, code
  and website actions appear inline beside the project name, without a separate
  link row under the description; full link targets
  remain PDF actions rather than extra visible text. The internal ATS renderer
  remains available to compatibility tests, but is not a separate user choice.
- The optional advanced control adjusts name letter spacing in all three
  renderers. No new photo, content, layout-column or unrelated controls are added.

Regression artifacts are generated under `build/cv_design_samples/` by
`test/cv_design_settings_test.dart`; they contain test fixtures, never account data.

## Files changed for this feature

- New `lib/core/design/cv_design_options.dart`: supported fonts and bounded controls.
- New `lib/features/cv_design/cv_design_settings_screen.dart` and
  `design_controls.dart`: settings, save guard, and live preview.
- `lib/features/editor/document_editor_screen.dart`: CV-only entry point and shared draft.
- `lib/core/domain/document_models.dart`: additive, backward-compatible design fields.
- `lib/core/render/document_view.dart`, `resolved_document.dart`,
  `section_titles.dart`, and new `contact_detail_icon.dart`: preview formatting.
- `lib/core/export/document_text.dart`, `docx_builder.dart`, `export_fonts.dart`,
  `export_service.dart`, `pdf_builder.dart`, `pdf_sections.dart`, and
  `pdf_style.dart`: shared settings applied to actual documents.
- `pubspec.yaml` and `assets/google_fonts/`: bundled fonts, contact glyphs, and
  redistribution licenses; no new package dependency.
- New `test/cv_design_settings_test.dart`, updated `test/export_rendering_test.dart`,
  and new `tools/verify_cv_design_exports.py`: regression and independent output checks.

## Verification

- `dart format lib test`: completed.
- `dart analyze lib test`: no issues.
- `flutter test`: 232 tests passed, including defaults, boundaries, per-document
  persistence, immediate preview changes, failed-save retention, and long entries.
- Actual default/custom English/Arabic PDF and DOCX fixtures were generated.
  PDFium checks font names/sizes, margins, RTL marker position, and final content.
  OOXML checks validate package parts, paragraph settings, and embedded font bytes.
- Custom Word files were rendered using LibreOffice and inspected across all pages;
  PDF pages were rendered for visual review. No export is a screenshot of the UI.
- Web release and Android debug builds passed. These checks compile the application;
  they do not constitute a physical-device interaction test.

Local persistence was exercised by closing and reopening repository instances.
Live Supabase writes were not exercised against an authenticated configured server.
The implementation uses the existing `saveDocument` abstraction and JSON design
column, so it requires no new schema, backend service, or credentials.

## Compact contact header

In Header settings, **Use compact header** applies side-by-side name/title,
values without category prefixes, plain contact icons, and the two-column Grid
layout. Typography stays under the existing font controls. Each choice can also
be changed separately: Compact/One row, Two rows, Multi-row, or Grid; icon size
from 8 to 24 pt; labels; and icons on/off. Rows wrap when content exceeds the
available paper width instead of overflowing or shrinking text beyond the bounds.

The CV Builder and profile editor accept a destination URL and optional display
name separately. `ProfileDetails.links` and `website` retain their destinations;
`linkLabels` stores visible text keyed by URL. Existing URLs still load without
labels. Website duplicates are filtered during resolution. Changing or clearing a
link does not delete other links or the profile photo.

GitHub and LinkedIn are identified using the URL host and use bundled Font Awesome
Free 6.7.2 brand glyphs in Flutter, PDF, and Word. Word embeds the font using its
actual family name and explicit script bindings, so it does not substitute
Wingdings. No network or icon package is required at runtime. PDF and DOCX include
real link actions/relationships behind the visible labels, including contact links
in compact and multi-row arrangements. Unsafe destinations remain noninteractive.
Internal ATS compatibility exports retain full contact URLs and category labels;
normal application exports preserve the saved presentation.

Regression tests: `test/contact_header_test.dart` and the CV Builder save test in
`test/cv_builder_wizard_test.dart`. Actual fixtures are written under
`build/contact_header_samples/`; `tools/verify_contact_header_exports.py` independently
checks displayed text, actual PDF URI actions, embedded font activation and sizes,
and Word hyperlink relationships. These files contain synthetic test data only.

Contact-header verification completed with 232 passing Flutter tests, clean
`dart analyze lib test`, and successful Web release / Android debug builds.
Seven PDF and seven DOCX contact-header fixtures cover icons/no icons, row/grid
arrangements, Arabic, and long display labels. PDFium verified real URI actions,
brand font activation and 14/18 pt glyph sizes; LibreOffice-rendered Word pages
verified both brand glyphs using FontAwesome6Brands-Regular. Arabic contact layout
mirrors columns and icons while phone numbers and email remain in their natural
left-to-right order. This was verified from rendered output and extraction.
