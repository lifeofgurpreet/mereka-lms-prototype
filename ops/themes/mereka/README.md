# Mereka Theme Kit

Shared palette, typography, and utility styles that bring Open edX surfaces closer to mereka.io without diverging from Paragon defaults. The goal is to keep colors, fonts, and spacing consistent across:

1. Legacy LMS/Studio (via Tutor’s custom theme pipeline).
2. Micro-frontends (by importing the same SCSS tokens).
3. Ancillary services (Discovery, AuthN, etc.) as they come online.

## Structure

```
ops/themes/mereka/
├── README.md
├── scss/                  # Source of truth for fonts/tokens/utilities
│   ├── _fonts.scss        # Font-face declarations (path overridable via $mereka-font-path)
│   ├── _tokens.scss       # Brand palette + Paragon variable bridge
│   └── theme.scss         # Minimal utility classes / gradient helpers
├── common/static/fonts/   # Compiled fonts used by LMS/Studio
├── lms/static/sass/       # Tutor theme entrypoint
└── cms/static/sass/       # Tutor theme entrypoint
```

## Using With Tutor (LMS/Studio)

```bash
# From the repo root
source ops/tutor-env.sh
tutor config save --set THEME_DIR=$(pwd)/ops/themes
tutor config save --set THEME_NAME=mereka
tutor images build openedx
tutor local start -d
```

Tutor copies everything under `ops/themes/` into `tutor_env/build/openedx/themes`, so the LMS/Studio entrypoints simply include the shared `scss/theme.scss`. Use `tutor local run lms ./manage.py lms collectstatic` if you need to force asset rebuilds during local development.

## Consuming In MFEs

Inside each `frontend-app-*` directory:

```scss
// src/styles/mereka.scss
$mereka-font-path: "~@mereka/theme/fonts"; // set to wherever the fonts live for that app
@import "../../ops/themes/mereka/scss/theme";
```

Then import `src/styles/mereka.scss` from the MFE’s `src/index.scss`. The `$mereka-font-path` variable ensures the compiled bundle points at the right font directory (e.g., `/public/fonts` when building MFEs, `/static/mereka/fonts` when running under Tutor).

## Keeping Assets In Sync

1. Drop updated fonts/logos/favicons into `assets/branding/`.
2. Run `cp assets/branding/fonts/*.woff2 ops/themes/mereka/common/static/fonts/` to refresh the theme copy (or symlink if preferred).
3. Commit both locations so MFEs (which read from `assets/branding/`) and LMS/Studio (which serve from `ops/themes/mereka/common/static/fonts`) stay consistent.

Add new global patterns (e.g., hero backgrounds, footer partials) under `ops/themes/mereka/common/` so they are easy to reuse across both LMS and Studio templates later in the rollout.
