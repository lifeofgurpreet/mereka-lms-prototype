# Mereka.io Theme Reference
_Audience: Design + Platform Eng • Owner: Branding Guild • Last verified: 2025-11-08_

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

See `infrastructure/tutor/themes/mereka/scss/_tokens.scss` for the Paragon/Bootstrap variable mapping and custom CSS variables exported to `:root`.

## Typography

| Family | Weights | Source |
| --- | --- | --- |
| Poppins | 400 / 600 / 700 | `assets/branding/fonts/Poppins-*.woff2` |
| Lato | 400 / 400 italic / 700 / 700 italic / 900 / 900 italic | `assets/branding/fonts/Lato-*.woff2` |

`_fonts.scss` exposes a `$mereka-font-path` variable (defaults to `/static/mereka/fonts`) so MFEs can override the asset path without duplicating the declarations. Tutor builds copy the fonts into `infrastructure/tutor/themes/mereka/common/static/fonts/` which collectstatic will serve at `/static/mereka/fonts/…`.

## Using The Tokens

1. Import `infrastructure/tutor/themes/mereka/scss/theme.scss` wherever you need brand styles (LMS/Studio theme, MFEs, and any React micro-apps).
2. Override `$mereka-font-path` **before** importing if the fonts should be loaded from a different directory (e.g., `public/fonts` in MFEs).
3. Keep per-app overrides minimal—prefer using the `.bg-mereka-gradient`, `.badge-mereka`, `.shadow-mereka-card`, and `.textbox-mereka` helpers baked into `theme.scss` or extend Paragon components with utility classes rather than writing bespoke CSS.

### MFE Integration Quickstart

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
source infrastructure/tutor/tutor-env.sh
tutor dev start mfe --detach
./scripts/branding/setup-mfe-branding.sh    # clones + wires fonts/SCSS
cd tutor_env/dev/frontend-app-learning      # repeat per app
npm install
npm start
```

`scripts/branding/setup-mfe-branding.sh` clones the key MFEs into `tutor_env/dev/`, drops the shared fonts into each `public/fonts/` directory, copies the Mereka logos/favicons into `public/` + `public/images/`, writes `src/styles/mereka.scss`, and prepends `@import "./styles/mereka.scss";` to `src/index.scss`. The SCSS import points back to the shared tokens at `../../../../../infrastructure/tutor/themes/mereka/scss/theme`, so edits remain centralized. Use `npm start` for interactive review, then rebuild via `tutor images build mfe` once approved.

## Asset Checklist

- Logos live at `assets/branding/logo-horizontal.png`, `assets/branding/logo-horizontal-white.png`,
  `assets/branding/logo-square.png`, and the header-safe `assets/branding/logo.png`.
- Web fonts are vendored under `assets/branding/fonts/` and duplicated to `infrastructure/tutor/themes/mereka/common/static/fonts/` for LMS/Studio.
- Favicons ship as `assets/branding/favicon.ico` plus PNG sizes (`favicon-16x16.png`, `favicon-32x32.png`,
  `favicon-256x256.png`) and optional `favicon.svg`. `scripts/branding/sync-brand-assets.sh` syncs all of
  them into the theme images directory.

When new assets arrive, drop them into `assets/branding/`, re-sync the theme copy if needed, and update the tables above so the next engineer understands which files feed the build.

## LMS/Studio Implementation

- `infrastructure/tutor/themes/mereka/lms/templates/header/brand.html` swaps the default Open edX logo strip with the Mereka wordmark plus an org/course pill so every course page feels bespoke.
- `infrastructure/tutor/themes/mereka/lms/templates/index_overlay.html` introduces a gradient hero, CTA buttons, and KPI badges on the anonymous home page.
- `infrastructure/tutor/themes/mereka/lms/templates/footer.html` adds a four-column footer (Explore, Support, Partners, and contact emails) while preserving Open edX attribution.
- Global styling lives in `infrastructure/tutor/themes/mereka/scss/theme.scss` (nav chrome, hero, course cards, chips, footer utilities). Studio automatically inherits the same palette/fonts because `cms/static/sass/theme.scss` imports the shared bundle.
- The theme expects logos/favicons at `/static/mereka/images/*`; run `./scripts/branding/sync-brand-assets.sh` whenever you refresh files under `assets/branding/`.

To preview locally:

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
source infrastructure/tutor/tutor-env.sh
./scripts/branding/sync-brand-assets.sh
tutor config save --set THEME_DIR="$(pwd)/infrastructure/tutor/themes" --set THEME_NAME=mereka
./infrastructure/tutor/apply-patches.sh
tutor local start -d
tutor local run lms ./manage.py lms collectstatic --noinput
```

## Branding Health Gate

Run `./scripts/branding/verify-branding-health.sh` before building or deploying images. It enforces
the presence of required logos, fonts, SCSS imports, and favicon assets. `./infrastructure/tutor/apply-patches.sh`
and `./scripts/branding/deploy-branded-image.sh` now execute this check automatically and fail fast if any
asset is missing.

To validate that the branding is actually visible on live domains, run:

```bash
./scripts/qa/verify-public-branding.sh prod
```

## Micro-Frontend Plug-in

- `infrastructure/tutor/themes/mereka/mfe/mereka.scss` reuses the same tokens/fonts, then layers on navbar/button/card tweaks tailored to Paragon components. Fonts are bundled with each MFE, so there are no cross-origin font requests.
- `scripts/branding/setup-mfe-branding.sh` is the one-stop helper for local development: it clones the upstream MFEs under `tutor_env/dev/`, copies the fonts into each `public/fonts/`, writes `src/styles/mereka.scss`, and ensures `src/index.scss` imports it.
- The Indigo theme’s React plugin now renders a bespoke Mereka footer (links + contact info) by way of the `MerekaFooter` component injected ahead of the `footer_slot` widgets.
- To bake the branding into Tutor’s production MFE image: `export TUTOR_ROOT="$(pwd)/tutor_env" && source infrastructure/tutor/tutor-env.sh && tutor images build mfe`.

## Favicons & Meta

- Primary favicon: `infrastructure/tutor/themes/mereka/common/static/images/favicon.ico` (synced from `assets/branding/favicon.ico`).
- Optional SVG: `infrastructure/tutor/themes/mereka/common/static/images/favicon.svg` if you want crisp scaling.
- Set `INDIGO_FAVICON_URL=https://<lms-host>/static/mereka/images/favicon.ico` via `tutor config save` so Django advertises the correct icon and MFEs reuse it from their config.
