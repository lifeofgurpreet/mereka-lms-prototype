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
- Favicon/App-icon set is still pending (`docs/BRANDING_PLAN.md` tracks the todo).

When new assets arrive, drop them into `assets/branding/`, re-sync the theme copy if needed, and update the tables above so the next engineer understands which files feed the build.
