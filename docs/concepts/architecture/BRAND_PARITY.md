# Brand Parity Architecture (WhiteCliff Lane)

_Last updated: 2026-02-27_

> **Spec**: `specs/branding-system_spec.md`
> **Verification**: `scripts/qa/verify-brand-parity.sh`
> **Related**: `docs/concepts/architecture/FOOTER_PARITY.md`, `docs/guides/branding/BRANDING.md`

## Overview

WhiteCliff is the Mereka LMS branding parity lane. It ensures that every rendered
surface — the Django-rendered LMS, Studio (CMS), and all React micro-frontends (MFEs) —
carries consistent Mereka Academy visual identity with zero Open edX default leakage.

The lane has three implementation concerns:

1. **Brand token inventory** — colors, fonts, logos, favicons defined in one place.
2. **Surface delivery** — how tokens reach each surface at build and runtime.
3. **Automated verification** — `verify-brand-parity.sh` (superset of
   `verify-footer-parity.sh`) as the CI gate.

---

## Brand Token Inventory

### Colors

Defined in `infrastructure/tutor/themes/mereka/scss/_tokens.scss` as both SCSS variables
and CSS custom properties:

| Token (CSS custom property) | Value | Purpose |
|---|---|---|
| `--mereka-color-teal` | `#297F81` | Primary actions, links hover |
| `--mereka-color-magenta` | `#ab3b78` | Primary brand / Bootstrap `$primary` |
| `--mereka-color-blue` | `#295cad` | Links, info states |
| `--mereka-color-sky` | `#94d1e4` | Info soft |
| `--mereka-color-ink-900` | `#000000` | Body text |
| `--mereka-color-ink-700` | `#4A494A` | Secondary text |
| `--mereka-color-ink-500` | `#737373` | Muted text |
| `--mereka-color-surface-primary` | `#FBFAFB` | Page background |
| `--mereka-color-surface-secondary` | `#F5F5F5` | Card/input background |
| `--mereka-color-border` | `#DDDDDE` | Default borders |
| `--mereka-shadow-card` | `0 20px 60px rgba(26,22,35,0.08)` | Elevation shadow |
| `--mereka-gradient-primary` | teal→blue linear-gradient | CTA gradients |

Semantic state tokens (success/warning/danger/info) are mapped from the brand palette
in `_tokens.scss` and bridge to Paragon's `--pgn-color-*` custom properties for MFE
component compatibility.

### Fonts

Self-hosted in `infrastructure/tutor/themes/mereka/{lms,cms,mfe}/fonts/` as `.woff2`.
No Google Fonts dependency. Declared via `@font-face` in
`infrastructure/tutor/themes/mereka/scss/_fonts.scss`.

| Font family | Weights | Role |
|---|---|---|
| **Poppins** | 400, 600, 700 | Body text (`--mereka-font-body`) |
| **Lato** | 400, 400i, 700, 700i, 900, 900i | Headings (`--mereka-font-heading`) |

The `$mereka-font-path` SCSS variable controls the relative URL path baked into
`@font-face` declarations. MFEs override this to `../fonts` so the compiled CSS
resolves correctly relative to the MFE app's asset directory.

### Logos

All logo variants are stored in each surface's `static/images/` directory:

| File | Purpose |
|---|---|
| `logo.png` | Canonical LMS header and footer |
| `logo.svg` | High-DPI / scalable contexts |
| `logo-horizontal.png` | Wide-format navbar contexts |
| `logo-horizontal-white.png` | Dark-background headers |
| `logo-square.png` | Square crop (e.g., thumbnail, avatar) |
| `logo-square-white.png` | Square, dark background |
| `logo-white.png` | Full logo, white variant |

Each surface (LMS, Studio/CMS, MFE) has its own copy so assets can be served from
each surface's static root without cross-service file resolution.

### Favicons

All favicon sizes are present on each surface:

| File | Purpose |
|---|---|
| `favicon.ico` | Universal browser fallback |
| `favicon.svg` | Modern browsers (scalable) |
| `favicon-16x16.png` | Browser tab legacy |
| `favicon-32x32.png` | Browser tab standard |
| `favicon-256x256.png` | PWA homescreen / high-DPI |

---

## Surface Coverage Matrix

| Surface | Brand delivery mechanism | Tokens | Fonts | Logo | Favicon | Footer |
|---|---|---|---|---|---|---|
| **LMS** | Tutor comprehensive theme (`mereka/`) | SCSS + CSS vars | `head-extra.html` preload | `header/brand.html` | Via Open edX `<link rel="icon">` | Custom `footer.html` Mako |
| **Studio (CMS)** | Tutor comprehensive theme (`mereka/`) | SCSS + CSS vars | `head-extra.html` preload | Open edX default nav (CSS override) | Via Open edX `<link rel="icon">` | Custom `widgets/footer.html` Mako |
| **MFEs (all)** | `mereka.scss` injected by `footer-component.sh` via `apply-patches.sh` | CSS vars (`:root`) | `@font-face` in compiled SCSS | `MerekaFooter` component logo | MFE `<link rel="icon">` via env.config | `MerekaFooter` React component |
| **Enterprise MFEs** | `enterprise-mfe-env.js` ConfigMap | Partial (CSS vars via SCSS) | Not injected | Not injected | Not injected | Open edX default (P4 gap) |

---

## How Branding Flows: Build → Runtime

### 1. Token definition (source of truth)

```
infrastructure/tutor/themes/mereka/scss/
  _tokens.scss    → SCSS vars + CSS custom properties (:root)
  _fonts.scss     → @font-face declarations (self-hosted)
  theme.scss      → imports tokens + fonts, adds utility classes
```

`theme.scss` is the shared entrypoint imported by all three surface-specific SCSS
entrypoints:

```
lms/static/sass/theme.scss     → @import "../../../scss/theme"
cms/static/sass/theme.scss     → @import "../../../scss/theme"
cms/static/sass/studio-main-v1.scss  → @import "../../../scss/theme"
mfe/mereka.scss                → $mereka-font-path override; @import "./scss/theme"
```

### 2. LMS and Studio: Tutor comprehensive theme

Tutor's comprehensive theming system (enabled via `ENABLE_COMPREHENSIVE_THEMING=True`
and `THEME_NAME=mereka`) causes edx-platform to resolve templates and static files from
`infrastructure/tutor/themes/mereka/lms/` and `cms/` directories first, falling back to
Open edX defaults.

Key template overrides:

- `lms/templates/header/brand.html` — Renders the LMS navbar logo.
- `lms/templates/head-extra.html` — Injected into every LMS `<head>`: preloads Poppins
  and Lato fonts, loads `mereka-overrides.css`.
- `cms/templates/head-extra.html` — Same for Studio.
- `lms/templates/footer.html` — Full custom Mereka footer (4 structural zones,
  copyright, legal links).
- `cms/templates/widgets/footer.html` — White-label Studio footer (copyright only,
  no Open edX attribution).

### 3. MFEs: env.config.jsx injection via apply-patches.sh

MFEs are independent React apps that do not use Tutor's Django theming system. Branding
is injected via `apply-patches.sh → footer-component.sh`:

```
apply-patches.sh
  └── source footer-component.sh
        └── apply_footer_component_patch()
              ├── Injects `import mereka/mereka.scss` into env.config.jsx
              └── Appends MerekaFooter React component definition
```

`mereka.scss` is copied into each MFE's build context so the import resolves at
webpack build time. The footer component uses `SITE_VARIANTS` (keyed by hostname)
to serve domain-specific copyright, brand name, and support links.

**Critical**: `apply-patches.sh` must be run after every `tutor config save` because
`tutor config save` regenerates `env/` templates from scratch, discarding patches.
Use `scripts/infra/tutor-config-save.sh` which runs patches automatically.

### 4. Enterprise MFEs (known gap)

Enterprise admin portal and learner portal are deployed via K8s ConfigMap
(`deploy/k8s/base/apps/enterprise/mfe/enterprise-mfe-env.js`). They do not receive
the `MerekaFooter` component or `mereka.scss` injection. This is a P4 backlog item
documented in `docs/concepts/architecture/FOOTER_PARITY.md` (WARN-001).

---

## Verification Script

`scripts/qa/verify-brand-parity.sh` is the WhiteCliff CI gate. It is a superset of
`verify-footer-parity.sh`, which covers the footer lane only.

### Offline mode (default, CI-safe)

Checks source files without requiring a running cluster:

- Token stack completeness (`_tokens.scss` required properties)
- Logo and favicon presence on all three surfaces (LMS, CMS, MFE)
- Self-hosted font files (Poppins + Lato `.woff2`) on all three surfaces
- No Google Fonts references anywhere in the theme directory
- LMS `brand.html`, `head-extra.html` wiring
- Studio `head-extra.html`, `studio-main-v1.scss` wiring
- Studio footer widget white-label status
- LMS footer Mereka branding and no "Powered by Open edX"
- `apply-patches.sh` wiring of footer-component patch
- Cross-surface asset consistency (canonical files present on all surfaces)

### Live mode (`--live`)

Probes production endpoints with curl:

- LMS homepage: logo src, `mereka-footer` class, no "Powered by Open edX", favicon
- Studio signin page: Mereka brand name, Mereka CSS, no "Powered by Open edX", favicon
- MFE authn login: Mereka branding, no Google Fonts, no "Powered by Open edX", favicon
- Multi-domain: `academyv2.mereka.io` and `academy.biji-biji.com`

### AC coverage

| AC ID | Description |
|---|---|
| AC-BRAND-001 | `_tokens.scss` defines required CSS custom properties |
| AC-BRAND-002 | Logo assets on LMS, Studio, MFE |
| AC-BRAND-003 | Favicon assets on LMS, Studio, MFE |
| AC-BRAND-004 | Self-hosted Poppins + Lato fonts on all surfaces |
| AC-BRAND-005 | LMS `header/brand.html` uses branding API |
| AC-BRAND-006 | Studio `head-extra.html` loads Mereka overrides |
| AC-BRAND-007 | LMS `head-extra.html` loads Mereka overrides |
| AC-BRAND-008 | MFE `mereka.scss` CSS custom properties present |
| AC-BRAND-009 | No Google Fonts in theme files |
| AC-BRAND-010 | Shared token stack (`_tokens.scss`, `_fonts.scss`, `theme.scss`) intact |
| AC-BRAND-011 | LMS footer Mereka branding, no Open edX leakage |
| AC-BRAND-012 | Studio footer widget white-label |
| AC-BRAND-013 | Studio SCSS imports shared token stack |
| AC-BRAND-014 | `apply-patches.sh` wires footer and SCSS patches |
| AC-BRAND-015 | Live LMS page: Mereka logo present |
| AC-BRAND-016 | Live Studio page: Mereka branding present |
| AC-BRAND-017 | Live MFE authn page: Mereka branding, no Google Fonts |

---

## Known Gaps and Accepted Deviations

| Gap | Severity | Reference |
|---|---|---|
| Enterprise MFE portals use Open edX default footer | P4 / WARN | `FOOTER_PARITY.md` WARN-001 |
| Studio logo rendered via CSS override, not template swap | P3 / cosmetic | ADR-014 note |
| MFE font preload not in HTML `<head>` (loaded via SCSS) | P3 / perf | `WARN-003` in verify script |
| `favicon.ico` not explicitly referenced in MFE `index.html` template | P3 | Tutor-generated, not overridable without plugin |

---

## Operational Checklist

After any branding asset change:

```bash
# 1. Verify offline (fast, no cluster needed)
./scripts/qa/verify-brand-parity.sh

# 2. Re-apply patches (after any tutor config save)
./infrastructure/tutor/apply-patches.sh

# 3. Rebuild images if LMS/Studio SCSS or templates changed
tutor images build openedx
tutor images build mfe

# 4. Verify live (requires deployed cluster)
./scripts/qa/verify-brand-parity.sh --live

# 5. Run footer parity as well (complementary check)
./scripts/qa/verify-footer-parity.sh --live
```

If the MFE `mereka.scss` or `MerekaFooter` component changes, rebuild the MFE image and
force a rolling restart of MFE pods:

```bash
tutor images build mfe
# Push to registry and update image tag in kustomization.yaml, then ArgoCD syncs
```
