# Visual identity and motion

The approved reference is https://swell-stick-89036913.figma.site/ . The existing
product name remains unchanged. The current logo is the continuous CV monogram
(proposal 4), with sky blue `#6CABDD` on a graphite `#2D333B` tile. It replaces
the earlier document/rising-arrow mark; the UI palette below is independent.
The reference's sample user, product name, ATS scores and AI claims are not app data.

## Central design system

`lib/core/theme/app_tokens.dart` owns the palette, gradients, typography, spacing,
radii, shadows and responsive breakpoints. `app_theme.dart` applies them to all
Material controls. Portfolio Ocean/Forest/Rose choices remain available and build
on the same theme; document/export typography remains independent.

| Token | Value |
| --- | --- |
| Sky / Ice | `#6CABDD` / `#A9DDF5` |
| Graphite / Silver | `#202329` / `#777D86` |
| Signature gradient | 135 degrees: Graphite, Silver, Ice, Sky |
| Light canvas source layers | White, `#EDF7FB`, `#D9EDF7`, Ice, Sky |
| Dark canvas source layers | `#343A40`, `#49515A`, `#626C76`, `#87929D` |
| Accessible light-mode link | `#286D96` |
| UI fonts | Inter (English), Tajawal (Arabic); 400, 500, 600 |
| Spacing | 4, 8, 12, 16, 24, 32, 48 logical pixels |
| Form / content measure | 760 / 1120 logical pixels |
| Breakpoints | Compact below 600; desktop rail from 1100 |
| Desktop rail | 248 logical pixels; mirrored in RTL |
| Interactive targets | At least 48 logical pixels high |

Canvas layers are composited with a white veil in light mode and a base-gray
veil in dark mode so normal text and link colors remain readable across every
gradient stop. Hero surfaces use stronger blue/gray reflections with a scoped
foreground theme for labels and outlined actions. Contrast tests include the
decorative ice/silver layers, not just flat card backgrounds.

Licensed fonts are bundled for offline rendering. Tajawal's bundled Bold face
supplies weight 600 as well as existing 700 requests. Existing PDF/DOCX fonts and
saved document designs are preserved.

## Shared presentation inventory

| Source | Components and responsibility |
| --- | --- |
| `core/widgets/app_surfaces.dart` | AppBackdrop geometric canvas, AppGlassCard optional bounded blur, AppHeroSurface decorative scroll parallax, responsive AppAuthLayout, AppLoading |
| `core/widgets/app_navigation_shell.dart` | Adaptive desktop rail/mobile floating navigation; preserves the body subtree when changing breakpoints |
| `core/widgets/app_page_body.dart` | Consistent maximum content/form measure |
| `core/widgets/app_motion.dart` | Reusable motion tokens, page/tab transitions, reveal, spring feedback, interactive cards and skeleton |
| `core/theme/app_theme.dart` | Buttons, inputs, cards, menus, dialogs, typography, app bars, navigation and contrast |
| `features/portfolio/portfolio_theme.dart` | Existing user-selectable portfolio palettes composed with the shared theme |

## Motion system

Button feedback and interactive cards share a spring (mass 1, stiffness 420,
damping 34). Card pointer movement adds a small perspective tilt; pointer listeners
do not replace child tap actions. Routes and retained tabs use short fade/slide
transitions, and login/dashboard share the brand mark Hero.

Section reveals run once on entering the viewport, staggered by 35 ms with a
bounded delay. Hero parallax moves decoration only, capped at 24 logical pixels.
Theme gradients transition for 900 ms. Bottom sheets use 360 ms entrance and
160 ms exit. Loading skeleton shimmer runs only while loading and visible.
Reduced motion/accessible navigation disables these effects; disposal and
TickerMode stop inactive tickers. There is no permanent background animation.

## Assets

Android startup gradients mirror the shared light/dark palette in
`res/values/app_palette.xml` and `res/values-night/app_palette.xml`; the existing
activity, permissions and application ID remain intact.

The editable logo is `assets/branding/brand_mark.svg`. Regenerate its raster masters,
social preview, launchers, favicon and PWA icons with:

```sh
python tools/create_identity.py
dart run flutter_launcher_icons
```

The old JPEG extraction script `tools/generate_brand_assets.py` is retained for
historical reference. Running it replaces the current masters.

For feature preservation and executed QA evidence, see
[`FEATURE_PRESERVATION_CHECKLIST.md`](../FEATURE_PRESERVATION_CHECKLIST.md) and
[`UI_MODERNIZATION.md`](UI_MODERNIZATION.md).

## Follow-up icon and spacing vocabulary

App navigation/action symbols use the shared rounded `AppIcons` constants.
Career concepts use document, work, education, project/code and skill symbols;
Google sign-in uses the already bundled brand glyph. CV document design icon
choices remain independent of app chrome.

Skills reuse the licensed Font Awesome Brands 6.7.2 font already in the app,
with exact glyph mappings for supported brands, stable persisted IDs and name
aliases. Technologies not present in that bundled font use readable technical
lettermarks. Search suggestions and automatic exact-name selection avoid forcing
users into the full picker; manual overrides remain available.

Populated builder cards use 16px inter-card separation; review label/value fields
use a 16px desktop gap or an 8px stacked mobile gap. Date/entry dialogs follow the
same shared form spacing. Additional populated-flow captures are generated in
`build/flow-refinement-audit/` for English/Arabic and light/dark at 360 and 1440px.
