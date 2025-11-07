# Mereka.io Theme Reference

This document captures the brand tokens we apply across LMS/Studio and all MFEs so every surface feels like mereka.io while still leaning on Paragon.

## Palette

| Token | Hex | Usage |
| --- | --- | --- |
| `ink-900` | `#1A1623` | Primary text, CTA backgrounds, dark surfaces |
| `ink-700` | `#4A494A` | Secondary text, subdued icons |
| `ink-500` | `#7B7B7B` | Tertiary text, placeholders |
| `ink-300` | `#AFADB2` | Disabled labels, dividers on dark backgrounds |
| `neutral-100` | `#FBFAFB` | Default page background |
| `neutral-75` | `#F5F5F5` | Cards + inset blocks |
| `info` | `#276EF1` | Links, accent icons, focus rings |
| `info-soft` | `#5B91F4` | Badges, subtle highlights |
| `success` | `#3AA76D` | Positive affordances |
| `warning` | `#FFC043` | Warn/delay states |
| `danger` | `#D44333` | Errors + destructive actions |
| `danger-soft` | `#FDF0EF` | Error backgrounds |

See `ops/themes/mereka/scss/_tokens.scss` for the Paragon/Bootstrap variable mapping and custom CSS variables exported to `:root`.

## Typography

| Family | Weights | Source |
| --- | --- | --- |
| Poppins | 400 / 600 / 700 | `assets/branding/fonts/Poppins-*.woff2` |
| Lato | 400 / 400 italic / 700 / 700 italic / 900 / 900 italic | `assets/branding/fonts/Lato-*.woff2` |

`_fonts.scss` exposes a `$mereka-font-path` variable (defaults to `/static/mereka/fonts`) so MFEs can override the asset path without duplicating the declarations. Tutor builds copy the fonts into `ops/themes/mereka/common/static/fonts/` which collectstatic will serve at `/static/mereka/fonts/…`.

## Using The Tokens

1. Import `ops/themes/mereka/scss/theme.scss` wherever you need brand styles (LMS/Studio theme, MFEs, and any React micro-apps).
2. Override `$mereka-font-path` **before** importing if the fonts should be loaded from a different directory (e.g., `public/fonts` in MFEs).
3. Keep per-app overrides minimal—prefer using the `.bg-mereka-gradient`, `.badge-mereka`, `.shadow-mereka-card`, and `.textbox-mereka` helpers baked into `theme.scss` or extend Paragon components with utility classes rather than writing bespoke CSS.

### MFE Integration Quickstart

```bash
source ops/tutor-env.sh
tutor dev start mfe --detach
cd tutor_env/dev/frontend-app-learning   # repeat per app
mkdir -p public/fonts
cp ../../../assets/branding/fonts/*.woff2 public/fonts/
cat <<'SCSS' > src/styles/mereka.scss
$mereka-font-path: "/fonts";
@import "../../../ops/themes/mereka/scss/theme";
SCSS
echo '@import "./styles/mereka.scss";' >> src/index.scss
npm install
npm start
```

Adjust the relative import path depending on the app layout (gradebook/auth/account follow the same pattern under `tutor_env/dev`). Use `npm start` for interactive review, then rebuild via `tutor images build mfe` once approved.

## Asset Checklist

- Logos live at `assets/branding/logo-horizontal.png` and `assets/branding/logo-square.png`.
- Web fonts are vendored under `assets/branding/fonts/` and duplicated to `ops/themes/mereka/common/static/fonts/` for LMS/Studio.
- Favicon/App-icon set ships as `ops/themes/mereka/common/static/images/favicon.svg` (export more sizes via `tools/sync-brand-assets.sh` if required).

When new assets arrive, drop them into `assets/branding/`, re-sync the theme copy if needed, and update the tables above so the next engineer understands which files feed the build.

## LMS/Studio Implementation

- `ops/themes/mereka/lms/templates/header/brand.html` swaps the default Open edX logo strip with the Mereka wordmark plus an org/course pill so every course page feels bespoke.
- `ops/themes/mereka/lms/templates/index_overlay.html` introduces a gradient hero, CTA buttons, and KPI badges on the anonymous home page.
- `ops/themes/mereka/lms/templates/footer.html` adds a four-column footer (Explore, Support, Partners, and contact emails) while preserving Open edX attribution.
- Global styling lives in `ops/themes/mereka/scss/theme.scss` (nav chrome, hero, course cards, chips, footer utilities). Studio automatically inherits the same palette/fonts because `cms/static/sass/theme.scss` imports the shared bundle.
- The theme expects logos/favicons at `/static/mereka/images/*`; run `./tools/sync-brand-assets.sh` whenever you refresh files under `assets/branding/`.

To preview locally:

```bash
source ops/tutor-env.sh
./tools/sync-brand-assets.sh
tutor config save --set THEME_DIR="$(pwd)/ops/themes" --set THEME_NAME=mereka
./ops/tutor/apply-patches.sh
tutor local start -d && tutor local run lms ./manage.py lms collectstatic --noinput
```

## Micro-Frontend Plug-in

- `ops/themes/mereka/mfe/mereka.scss` reuses the same tokens/fonts, then layers on navbar/button/card tweaks tailored to Paragon components. Fonts are bundled with each MFE, so there are no cross-origin font requests.
- `ops/tutor/apply-patches.sh` copies the SCSS + fonts into `tutor_env/env/plugins/mfe/build/mfe/indigo/mereka/` and injects `import './mereka/mereka.scss';` into `env.config.jsx` every time you run the script.
- The Indigo theme’s React plugin now renders a bespoke Mereka footer (links + contact info) by way of the `MerekaFooter` component injected ahead of the `footer_slot` widgets.
- To rebuild MFEs with the branding baked in: `source ops/tutor-env.sh && ./ops/tutor/apply-patches.sh && tutor images build mfe --no-cache`.

## Favicons & Meta

- Primary favicon: `ops/themes/mereka/common/static/images/favicon.svg`. Browsers that need raster fallbacks can use `logo-square.png` converted to `.ico` via `npx svg2img` or macOS Preview.
- Set `INDIGO_FAVICON_URL=https://<lms-host>/static/mereka/images/favicon.svg` via `tutor config save` so Django advertises the correct icon and MFEs reuse it from their config.
