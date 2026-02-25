# OEP-48 Brand Package: Mereka Academy

**Status**: Audit complete — see Gap Analysis below
**Last updated**: 2026-02-25
**Tracker task**: T110

---

## What is OEP-48?

[OEP-48](https://open-edx-proposals.readthedocs.io/en/latest/architectural-decisions/oep-0048-brand-customization.html) defines how Open edX operators deliver brand customization. The key requirement is a single **brand package** — an npm package installed as `@edx/brand` — that provides the canonical set of logos, colors, typography, and UI shell components (header/footer) for a deployment.

The package exposes a defined interface:

| Asset type | Expected export |
|-----------|----------------|
| Logo (light bg) | `logo.png`, `logo.svg` |
| Logo (dark bg / white) | `logo_white.png` |
| Favicon | `favicon.ico`, `favicon.png` |
| Colors | SCSS / CSS custom property variables |
| Typography | Font declarations |
| Header component | React component override (optional) |
| Footer component | React component override (optional) |

MFE builds install the brand package via:
```
npm install --legacy-peer-deps '@edx/brand@npm:<your-package>'
```

Mereka currently installs: `@edly-io/indigo-brand-openedx@^2.4.3` aliased as `@edx/brand`.

---

## Current Brand Asset Inventory

### 1. Canonical Source — `assets/branding/`

The authoritative source of truth for all brand assets. Synced from the upstream `bbbi-mereka-brand-assets` repository.

| Asset | Present | Notes |
|-------|---------|-------|
| `logo.svg` | YES | Primary logo, vector |
| `logo.png` | YES | Primary logo, raster |
| `logo-horizontal.svg/png` | YES | Horizontal lockup |
| `logo-horizontal-white.svg/png` | YES | White variant for dark backgrounds |
| `logo-square.svg/png` | YES | Square/icon lockup |
| `logo-square-white.svg/png` | YES | White square variant |
| `logo-white.svg/png` | YES | Full white variant |
| `favicon.ico` | YES | Universal fallback |
| `favicon.svg` | YES | Modern SVG favicon |
| `favicon-16x16.png` | YES | Browser tab icon |
| `favicon-32x32.png` | YES | Browser tab icon (retina) |
| `favicon-256x256.png` | YES | PWA / homescreen icon |
| `tokens.css` | YES | CSS custom properties (110+ tokens) |
| `tokens.provenance.json` | YES | Upstream sync metadata |

Fonts referenced in `tokens.css`: **Poppins** (body), **Lato** (headings), **Open Sans** (video subtitles).

---

### 2. LMS Comprehensive Theme — `infrastructure/tutor/themes/mereka/`

The Open edX LMS/Studio comprehensive theming layer. Tutor compiles this via `npm run compile-sass`.

#### SCSS Token Stack

| File | Role | Present |
|------|------|---------|
| `scss/_tokens.scss` | SCSS vars + `--mereka-*`/`--pgn-*` CSS custom properties | YES |
| `scss/_fonts.scss` | `@font-face` declarations for Poppins + Lato | YES |
| `scss/theme.scss` | Entry point — imports `_fonts` + `_tokens`, adds component rules | YES |
| `lms/static/sass/theme.scss` | LMS SASS entrypoint | YES |
| `cms/static/sass/theme.scss` | Studio SASS entrypoint | YES |

#### Static Assets (LMS + Studio)

All logo and favicon variants from `assets/branding/` are replicated into:
- `lms/static/images/` — 17 files (logos + favicons, all variants)
- `cms/static/images/` — 17 files (same set)
- `lms/static/fonts/` — 9 `.woff2` files (Poppins Regular/Bold/SemiBold, Lato Regular/Bold/Black + Italic variants)
- `cms/static/fonts/` — 9 `.woff2` files (same set)

#### Runtime CSS (no build step required)

| File | Role |
|------|------|
| `common/static/css/mereka-design-tokens.css` | Verbatim copy of `tokens.css` (verbatim, fully generated) |
| `common/static/css/mereka-overrides.css` | `--mereka-*` + `--pgn-*` custom properties + component overrides |
| `lms/static/css/mereka-overrides.css` | LMS-specific overrides (same `:root` block) |
| `cms/static/css/mereka-overrides.css` | Studio-specific overrides |

`head-extra.html` (LMS and Studio) loads `mereka-overrides.css` via `<link>` and preloads Poppins + Lato fonts.

#### Templates

| File | Role |
|------|------|
| `lms/templates/head-extra.html` | Font preload + CSS override injection |
| `lms/templates/header/brand.html` | Mereka logo + tagline in LMS header |
| `lms/templates/footer.html` | Full Mereka footer (4-column layout, dynamic copyright) |
| `cms/templates/head-extra.html` | Font preload + CSS override injection for Studio |
| `cms/templates/widgets/footer.html` | White-label Studio footer |

---

### 3. MFE Theme — `infrastructure/tutor/themes/mereka/mfe/`

The SCSS layer injected into every MFE build.

| Asset | Present | Notes |
|-------|---------|-------|
| `mereka.scss` | YES | MFE SCSS entry: imports `./scss/theme` + MFE-specific `:root` tokens |
| `fonts/` | YES | 9 `.woff2` files (same set as LMS) |
| `images/` | YES | 17 logo + favicon files (same set as LMS) |

`mereka.scss` is injected into every MFE build via the Tutor plugin (`mereka_lms.py`) using the `mfe-env-config-buildtime-imports` patch. The shared `scss/theme.scss` → `_tokens.scss` → `_fonts.scss` chain is imported, making all `--mereka-*` and `--pgn-*` tokens available at compile time.

---

### 4. MFE Brand Package (npm) — `@edx/brand`

Installed in the MFE Dockerfile as:
```
npm install --legacy-peer-deps '@edx/brand@npm:@edly-io/indigo-brand-openedx@^2.4.3'
```

This installs `@edly-io/indigo-brand-openedx` aliased as `@edx/brand`. The Indigo brand provides the Open edX Indigo theme's default brand assets. **Mereka overrides this entirely at the SCSS layer via `mereka.scss`**, which re-declares all `--mereka-*` and `--pgn-*` CSS custom properties, overriding anything Indigo sets.

The logo/favicon assets used by MFEs come from the `mfe/images/` directory (copied into the Docker image), not from the npm brand package.

---

### 5. Design Token Pipeline

Full documentation: `docs/architecture/DESIGN_TOKENS_MIGRATION.md`

```
assets/branding/tokens.css   (Figma export — ONLY file with raw hex values)
         |
         | scripts/branding/generate-tokens-from-canonical.sh
         |
         +---> scss/_tokens.scss          (SCSS vars + :root block)
         +---> common/mereka-design-tokens.css
         +---> common/mereka-overrides.css
         +---> lms/mereka-overrides.css
         +---> cms/mereka-overrides.css
```

CI enforces no drift between layers via the `design-token-validation` job.

---

### 6. Footer and Header Components

**LMS header**: `lms/templates/header/brand.html` — Mereka logo + tagline, uses `branding_api.get_home_url()` for the home link. No hardcoded URLs.

**LMS footer**: `lms/templates/footer.html` — custom 4-column Mereka footer. Dynamic copyright year. No "Powered by Open edX" marker. White-label clean.

**MFE footer**: Injected via the Tutor plugin (`mereka_lms.py`) using the `mfe-env-config-buildtime-imports` and plugin slot system. Supports per-tenant variant selection (`SITE_VARIANTS` map). Three variants: Mereka Academy, Biji-Biji Academy, Skill Our Future Academy.

**Studio footer**: `cms/templates/widgets/footer.html` — white-label Studio footer. Dynamic copyright year.

---

## OEP-48 Asset Map

| OEP-48 requirement | Mereka delivery | Status |
|--------------------|----------------|--------|
| Single brand package installed as `@edx/brand` | `@edly-io/indigo-brand-openedx@^2.4.3` aliased as `@edx/brand` | PARTIAL — upstream Indigo, overridden by `mereka.scss` |
| `logo.png` (primary logo) | `mfe/images/logo.png`, `lms/static/images/logo.png`, `cms/static/images/logo.png` | YES — all surfaces |
| `logo.svg` | Same paths, `.svg` variant | YES |
| `logo_white.png` (dark bg) | `logo-white.png` (OEP-48 name differs) | YES — present, naming differs |
| `favicon.ico` | All three surfaces | YES |
| `favicon.png` (256×256) | `favicon-256x256.png` (name differs) | YES — present, naming differs |
| Colors / SCSS variables | `scss/_tokens.scss` — `$color-teal`, `$color-magenta`, etc. | YES |
| CSS custom properties | `--mereka-*` + `--pgn-*` via `_tokens.scss` and `mereka-overrides.css` | YES |
| Typography / font declarations | `scss/_fonts.scss` (woff2, no Google Fonts dependency) | YES |
| Header component | `lms/templates/header/brand.html` (LMS); MFE header via Paragon/navbar overrides in `mereka.scss` | PARTIAL — LMS has Mako template; MFE uses CSS-only header overrides, no React header component |
| Footer component | `lms/templates/footer.html` (LMS); MFE footer React component via plugin slot | YES — both surfaces |
| Package manifest (`package.json`) | Not present | GAP — see Gap Analysis |
| OEP-48 `logo.js` exports | Not present | GAP — see Gap Analysis |
| Automated build packaging | `scripts/branding/generate-tokens-from-canonical.sh` handles token sync; no tar/npm pack step | GAP — see Gap Analysis |

---

## Gap Analysis

### GAP-1: No standalone npm-publishable brand package

**What OEP-48 expects**: A `package.json` at the root of a brand directory so the package can be published to npm and installed as `@edx/brand`.

**Current state**: Mereka brand assets are organized across `assets/branding/` (canonical), `infrastructure/tutor/themes/mereka/mfe/` (MFE-ready), and `infrastructure/tutor/themes/mereka/lms|cms/` (LMS/Studio). There is no single `package.json` that would let this be published to npm.

**Impact**: We cannot install Mereka assets as a native `@edx/brand` replacement. Instead, we use `@edly-io/indigo-brand-openedx` as the base and override it with `mereka.scss`. This is functionally equivalent for our deployment but does not satisfy the OEP-48 "single publishable package" model.

**Priority**: Low for current deployment. Would become necessary if we wanted to publish the brand package to npm or the [Open edX package registry](https://github.com/openedx-unsupported/frontend-build).

---

### GAP-2: No `logo.js` / JavaScript exports

**What OEP-48 expects**: A `logo.js` file (or ESM equivalent) that exports logo assets for consumption by React MFE components:
```js
export { default as logo } from './logo.png';
export { default as logoWhite } from './logo_white.png';
export { default as favicon } from './favicon.ico';
```

**Current state**: Logo files are present in `mfe/images/` but there is no JavaScript module that exports them. MFE Paragon `Brand` component cannot resolve `@edx/brand/logo.js` from Mereka assets — it resolves from `@edly-io/indigo-brand-openedx` instead.

**Workaround in place**: `mereka.scss` overrides `.navbar .navbar-brand img` height and the MFE Dockerfile copies `mfe/images/` into the container, making the assets reachable via static URLs. The actual image `src` values in MFE components come from the MFE runtime config (`LOGO_URL`, `LOGO_WHITE_URL`) injected via `env.config.jsx`, not from `@edx/brand/logo.js`.

**Impact**: Medium. Brand images in MFEs (navbar logo, footer logo) render correctly via runtime config. However, any MFE component that imports directly from `@edx/brand` receives the Indigo logo, not the Mereka logo.

---

### GAP-3: No automated brand package build / packaging step

**What OEP-48 envisions**: A CI job that assembles the brand package (logos, fonts, SCSS, JS exports) into a publishable artifact.

**Current state**: Token sync is automated via `scripts/branding/generate-tokens-from-canonical.sh` (run in CI). Logo/font sync from `assets/branding/` into the three theme surfaces (`lms/`, `cms/`, `mfe/`) is currently a manual step (`scripts/branding/sync-brand-assets.sh`). There is no `npm pack` or GitHub release step that produces a versioned brand package artifact.

**Impact**: Manual sync risk — logo/font files could drift between `assets/branding/` (canonical) and the three theme surfaces. The token pipeline is automated and CI-enforced; the logo/font sync is not.

---

### GAP-4: `logo_white.png` naming mismatch

**What OEP-48 expects**: File named `logo_white.png` (underscore).

**Current state**: File is named `logo-white.png` (hyphen) in all surfaces.

**Impact**: Low. This only matters if code imports by the exact OEP-48 filename. Our current codebase uses the hyphen convention consistently, and MFE runtime config passes URLs explicitly, so the filename does not need to match OEP-48 exactly.

---

### GAP-5: MFE header — CSS-only, no React component override

**What OEP-48 expects**: An optional React header component exported from the brand package to replace the default Open edX header.

**Current state**: Mereka MFE header branding is achieved via CSS overrides in `mereka.scss` (navbar background, logo height, typography). There is no Mereka React header component. The MFE runtime config passes `LOGO_URL` which Paragon's default header renders.

**Impact**: Low-medium. The current approach is visually correct and functionally equivalent for learner-facing MFEs. An operator who wants a structurally different MFE header (e.g., different nav items, different layout) would need a React header component. Not required for current use cases.

---

## What We Have vs What OEP-48 Needs (Summary)

| Category | Have | Need for full OEP-48 compliance | Gap severity |
|----------|------|--------------------------------|-------------|
| Logo assets (all variants) | YES — 7 logo files × 3 surfaces | Same files in an npm package | LOW |
| Favicon assets | YES — 5 favicon files × 3 surfaces | Same files in an npm package | LOW |
| Self-hosted fonts | YES — 9 woff2 files × 3 surfaces | Same fonts in an npm package | LOW |
| CSS custom properties (colors, typography) | YES — 110+ tokens, CI-enforced, no drift | Same token file in an npm package | LOW |
| SCSS variables | YES — `_tokens.scss` with all brand colors | Same SCSS file in an npm package | LOW |
| Design token pipeline (automated) | YES — `generate-tokens-from-canonical.sh`, CI gate | Extend to cover logo/font sync | MEDIUM |
| LMS header branding | YES — `brand.html` Mako template | Same (Mako is correct for LMS) | NONE |
| LMS footer branding | YES — custom `footer.html` with logo | Same (Mako is correct for LMS) | NONE |
| MFE footer component | YES — React plugin slot component | Same | NONE |
| MFE header component (React) | NO — CSS-only | Optional React header export | LOW |
| npm brand package (`package.json`) | NO | `package.json` + publish pipeline | MEDIUM |
| JS logo exports (`logo.js`) | NO | ESM exports for React component imports | MEDIUM |
| Automated brand package versioning | NO | CI job: `npm pack` or GitHub release | MEDIUM |
| Naming conventions (logo_white vs logo-white) | Partial mismatch | Rename or alias | LOW |

---

## Recommended Next Steps (for full OEP-48 compliance)

These are improvements beyond the current T110 scope, listed for completeness:

1. **Create `brand/package.json`** in `assets/branding/` (or a new `brand/` directory) with the OEP-48 package shape. Reference: [openedx-unsupported/brand-openedx](https://github.com/openedx-unsupported/brand-openedx).

2. **Add `logo.js` ESM exports** that re-export all logo/favicon files from the package root.

3. **Add logo/font sync to CI** (extend `generate-tokens-from-canonical.sh` or create a separate `sync-brand-assets.sh` CI job) so that `assets/branding/` → `lms/`, `cms/`, `mfe/` image sync is automated and verified.

4. **Add `npm pack` step to release pipeline** to produce a versioned brand package artifact.

5. **Rename `logo-white.png` → `logo_white.png`** across all surfaces to match OEP-48 convention (low urgency).

---

## Related Documentation

- `docs/architecture/DESIGN_TOKENS_MIGRATION.md` — token pipeline architecture (Phase 3 complete)
- `docs/architecture/TOKEN_GENERATION_PIPELINE.md` — pipeline contract
- `docs/architecture/WCAG_CONTRAST_POLICY_V2.md` — contrast compliance
- `docs/architecture/BRAND_PARITY.md` — brand parity across surfaces
- `specs/design-tokens-system_spec.md` — acceptance criteria for token system
- `assets/branding/tokens.provenance.json` — upstream sync metadata
- `infrastructure/tutor/mfe-build/README.md` — MFE Dockerfile notes including brand migration pending
- `scripts/qa/verify-brand-parity.sh` — comprehensive brand parity verifier
- `scripts/qa/verify-oep48-brand-package.sh` — OEP-48 specific verifier (this task)
