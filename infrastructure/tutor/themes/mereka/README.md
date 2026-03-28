# Mereka Theme Kit
_Last updated: 2026-02-27_

Shared palette, typography, and utility styles that bring Open edX surfaces closer to mereka.io without diverging from Paragon defaults. The goal is to keep colors, fonts, and spacing consistent across:

1. Legacy LMS/Studio (via Tutor's comprehensive theme pipeline).
2. Micro-frontends (by importing the same SCSS tokens).
3. Ancillary services (Discovery, AuthN, etc.) as they come online.

> **Tutor plugin**: All theme integration (Dockerfile hooks, config defaults, FPF slots) is managed by `infrastructure/tutor/plugins/mereka_lms.py`. The plugin copies this theme directory into the Docker image at build time via the `openedx-dockerfile-pre-assets` hook.

## Structure

```
infrastructure/tutor/themes/mereka/
├── README.md                    # This file
├── scss/                        # Source of truth for fonts/tokens/utilities
│   ├── _fonts.scss              # Font-face declarations (path overridable via $mereka-font-path)
│   ├── _tokens.scss             # Brand palette + Paragon variable bridge
│   └── theme.scss               # Minimal utility classes / gradient helpers
├── common/
│   ├── static/
│   │   ├── css/
│   │   │   ├── mereka-design-tokens.css  # CSS custom properties (proto-tokens)
│   │   │   └── mereka-overrides.css      # Global CSS overrides
│   │   ├── fonts/               # Poppins + Lato WOFF2 (shared by LMS/Studio)
│   │   └── images/              # Logos, favicons (all variants)
│   └── templates/
│       └── head-extra.html      # Common runtime shim (fonts + prebuilt runtime CSS)
├── lms/
│   ├── static/
│   │   ├── css/mereka-overrides.css  # LMS-specific CSS overrides
│   │   ├── fonts/               # LMS font copies
│   │   ├── images/              # LMS logo/favicon copies
│   │   └── sass/
│   │       ├── lms-main-v1.scss      # LMS SCSS entry point (REQUIRED)
│   │       ├── lms-main-v1-rtl.scss  # LMS RTL entry point
│   │       ├── theme.scss            # LMS theme SCSS
│   │       └── partials/
│   │           ├── _variables.scss   # Paragon variable overrides
│   │           └── _custom.scss      # Custom LMS rules
│   └── templates/
│       ├── footer.html           # LMS footer template
│       ├── head-extra.html       # LMS runtime shim copy
│       ├── header/brand.html     # Header logo/brand block
│       └── index_overlay.html    # Homepage hero overlay
├── cms/
│   ├── static/
│   │   ├── css/mereka-overrides.css  # CMS-specific CSS overrides
│   │   ├── fonts/               # CMS font copies
│   │   ├── images/              # CMS logo/favicon copies
│   │   └── sass/
│   │       ├── studio-main-v1.scss      # CMS SCSS entry point (REQUIRED)
│   │       ├── studio-main-v1-rtl.scss  # CMS RTL entry point
│   │       └── theme.scss               # CMS theme SCSS
│   └── templates/
│       ├── footer.html           # CMS footer template
│       ├── head-extra.html       # CMS runtime shim copy
│       └── widgets/footer.html   # CMS widget footer
├── mfe/                          # MFE-specific brand assets
│   ├── fonts/                    # Font copies for MFE builds
│   ├── images/                   # Logo/favicon copies for MFE builds
│   └── mereka.scss               # MFE SCSS import entry point
└── tenants/                      # Multi-tenant overrides (future)
    ├── README.md
    └── _template/                # Template for new tenant brands
        ├── css/.gitkeep
        ├── favicons/.gitkeep
        └── logos/.gitkeep
```

## SCSS Entry Points (Critical)

The LMS and CMS **require** specific SCSS entry points for `compile-sass --theme mereka` to work:
- **LMS**: `lms/static/sass/lms-main-v1.scss` (and `-rtl` variant)
- **CMS**: `cms/static/sass/studio-main-v1.scss` (and `-rtl` variant)

Without these files, `compile-sass` silently skips the theme. The `mereka_lms.py` plugin creates them if missing via the `openedx-dockerfile-pre-assets` hook.

## Canonical Ownership

The current theming stack has multiple runtime surfaces, but they do not share
the same ownership role.

1. `assets/branding/tokens.css` is the canonical design-token source.
2. `scripts/branding/generate-tokens-from-canonical.sh` owns deterministic
   generation of:
   - `scss/_tokens.scss`
   - `common/static/css/mereka-design-tokens.css`
   - the generated token blocks inside `mereka-overrides.css`
3. `scripts/branding/sync-brand-assets.sh` is the propagation step:
   - it regenerates token outputs
   - it syncs assets
   - it mirrors `common/static/css/mereka-overrides.css` into LMS/CMS runtime copies
4. `head-extra.html` templates are runtime loader shims only:
   - they preload fonts
   - they load prebuilt runtime CSS
   - they are not a token or override source of truth
5. MFE shell ownership is split by responsibility, not by route:
   - `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js` owns shell composition and copy
   - `infrastructure/tutor/themes/mereka/mfe/mereka.scss` owns authored shell styling
   - LMS templates under `lms/templates/` adapt that shell for legacy surfaces and should not invent a second shell language

If you need to change token values, start in `tokens.css`. If you need to change
runtime override selectors, change the curated parts of
`common/static/css/mereka-overrides.css` and then sync it. If you need to change
how CSS/fonts are loaded, update the relevant `head-extra.html` runtime shims
without turning them into a second styling authority.

## Using With Tutor (LMS/Studio)

```bash
# From the repo root
export TUTOR_ROOT="$(pwd)/tutor_env"
source infrastructure/tutor/tutor-env.sh
tutor config save --set THEME_DIR="$(pwd)/infrastructure/tutor/themes"
tutor config save --set THEME_NAME=mereka
./infrastructure/tutor/apply-patches.sh   # CRITICAL: always run after config save
tutor images build openedx
tutor local start -d
```

Tutor copies everything under `infrastructure/tutor/themes/` into `tutor_env/build/openedx/themes`, so the LMS/Studio entry points simply include the shared `scss/theme.scss`. Use `tutor local run lms ./manage.py lms collectstatic` if you need to force asset rebuilds during local development.

## Consuming In MFEs

MFE branding is handled via the `mereka_lms.py` plugin which:
1. Copies fonts/images from `mfe/` into the MFE Docker image
2. Injects SCSS overrides via the `mfe-dockerfile-post-npm-install` hook
3. Wires the `MerekaFooter` component via Frontend Plugin Framework slots

For development, run `./scripts/branding/setup-mfe-branding.sh` to set up local MFE branding.

## Future: OEP-48 Brand Package

The current approach (SCSS overrides + build-time injection) will be superseded by an OEP-48 compliant `@edx/brand` package at `infrastructure/tutor/brand-mereka/`. See:
- [oep48-brand-package_spec.md](../../../../specs/oep48-brand-package_spec.md)
- [paragon-design-tokens-migration_spec.md](../../../../specs/plans/paragon-design-tokens-migration_spec.md)

## Keeping Assets In Sync

1. Drop updated fonts/logos/favicons into `assets/branding/`.
2. Run `./scripts/branding/sync-brand-assets.sh` (or `make branding-sync`) to regenerate token outputs and refresh the theme copies.
3. Commit both locations so MFEs (which read from `assets/branding/`) and LMS/Studio (which serve from theme directories) stay consistent.
