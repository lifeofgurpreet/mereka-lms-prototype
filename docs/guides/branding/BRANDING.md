# Mereka.io Theme Reference
_Audience: Design + Platform Eng • Owner: Branding Guild • Last verified: 2026-02-07 • Status: canonical_

This document captures the brand tokens we apply across LMS/Studio and all MFEs so every surface feels like mereka.io while still leaning on Paragon.

Quick operational entrypoint (read this before changing anything):
- `docs/guides/branding/BRANDING_GUARDRAILS.md`
- `docs/guides/branding/BRANDING_OPERATING_MODEL.md`
- `docs/status/active/BRANDING_ROADMAP_2026-02-08.md`

## Palette

| Token | Hex | Usage |
| --- | --- | --- |
| `black` | `#000000` | Primary text |
| `white` | `#ffffff` | Backgrounds, negative space |
| `teal` | `#2d898b` | Primary accent, hover states |
| `magenta` | `#ab3b78` | CTA buttons |
| `blue` | `#295cad` | Links, info states |
| `forest` | `#2c6e49` | Success |
| `gold` | `#996b00` | Warnings |
| `burgundy` | `#8c002f` | Errors |
| `pink` | `#cd89ae` | Error backgrounds |
| `sky` | `#94d1e4` | Info backgrounds |

See `infrastructure/tutor/themes/mereka/scss/_tokens.scss` for the Paragon/Bootstrap mapping. Source of truth is `bbbi-mereka-brand-assets/brands/mereka/tokens/tokens.css` (vendored into this repo as `assets/branding/tokens.css`).

## Typography

| Family | Weights | Usage | Source |
| --- | --- | --- | --- |
| Lato | 400 / 700 / 900 (+ italics) | Headings | `assets/branding/fonts/Lato-*.woff2` |
| Poppins | 400 / 600 / 700 | Body text | `assets/branding/fonts/Poppins-*.woff2` |

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
- Design tokens (Figma export) are vendored as `assets/branding/tokens.css` and synced to
  `infrastructure/tutor/themes/mereka/common/static/css/mereka-design-tokens.css` for operator inspection on live hosts.
- Non-default OEP-48 package sources live under `assets/branding/tenants/`:
  - `assets/branding/tenants/biji-biji/` -> `infrastructure/tutor/brand-biji-biji/`
  - `assets/branding/tenants/skillourfuture/` -> `infrastructure/tutor/brand-skillourfuture/`

When new assets arrive, drop them into `assets/branding/`, re-sync the theme copy if needed, and update the tables above so the next engineer understands which files feed the build.

## LMS/Studio Implementation

- `infrastructure/tutor/themes/mereka/lms/templates/header/brand.html` swaps the default Open edX logo strip with the Mereka wordmark plus an org/course pill so every course page feels bespoke.
- `infrastructure/tutor/themes/mereka/lms/templates/index_overlay.html` introduces a gradient hero, CTA buttons, and KPI badges on the anonymous home page.
- `infrastructure/tutor/themes/mereka/lms/templates/footer.html` adds a four-column footer (Explore, Support, Partners, and contact emails) while preserving Open edX attribution.
- Shared styling source lives in `infrastructure/tutor/themes/mereka/scss/theme.scss` (nav chrome, hero, course cards, courseware, footer utilities). Studio imports the shared bundle via `cms/static/sass/theme.scss`.
- Runtime delivery is via `mereka-overrides.css`, loaded by `infrastructure/tutor/themes/mereka/*/templates/head-extra.html`. This CSS is intentionally self-contained (no runtime build step) and is the most deterministic "brand signal carrier" we verify in production.
  - `infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css` is the canonical copy.
  - `infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css` must stay identical to avoid drift.
- The theme expects logos/favicons at `/static/mereka/images/*`; run `./scripts/branding/sync-brand-assets.sh` whenever you refresh files under `assets/branding/`.
  - `sync-brand-assets.sh` also syncs the runtime override CSS from common -> LMS to prevent drift.
  - Upstream token refresh is explicit: use `BRAND_REPO_TOKENS=/absolute/path/to/tokens.css ./scripts/branding/sync-brand-assets.sh` when pulling new design-token exports.

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

To ensure the runtime CSS carries the full branded experience (course cards, courseware chrome), run:

```bash
BRANDING_LEVEL=deep ./scripts/branding/verify-branding-health.sh
```

This health gate also enforces that our canonical design token export (`assets/branding/tokens.css`)
has not drifted from what we export at runtime in `mereka-overrides.css`.

Canonical end-to-end gate (source + live):

```bash
./scripts/branding/run-branding-gates.sh prod
```

To validate that the branding is actually visible on live domains manually, run:

```bash
./scripts/qa/verify-public-branding.sh prod
```

For strict verification of deep surfaces on live domains:

```bash
BRANDING_LEVEL=deep ./scripts/qa/verify-public-branding.sh prod
```

For strict MFE revision parity (live CSS must match current source marker):

```bash
STRICT_MFE_BRANDING_REV=1 ./scripts/branding/run-branding-gates.sh prod
```

To verify MFE image branding before push/deploy:

```bash
./scripts/qa/verify-mfe-image-branding.sh tutor_local/openedx-mfe:latest
```

If authn index points to an unbranded CSS bundle, repair image deterministically:

```bash
./scripts/branding/repair-mfe-authn-branding.sh <source_image> <target_image>
```

`verify-public-branding.sh` also validates Credentials and forum integration surfaces:
- `https://credentials.<domain>/admin/login/` is reachable
- `https://credentials.<domain>/health/` includes `overall_status` and `database_status`
- `https://credentials.<domain>/` may be API-first and redirect to `/health/` (accepted)
- `https://forum.<domain>/heartbeat` returns `200`

## Subsites (Different Clients)

Production includes additional client hostnames:
- `skillourfuture.academy.mereka.io`
- `academy.biji-biji.com`

These should still load the brand fonts + themed logo assets. `verify-public-branding.sh` checks those
hosts in production (logo + local fonts), and `capture-branding-screenshots.sh` captures snapshots for
those hosts (plus the Biji studio/MFEs where applicable).

Note: LMS pages reference fingerprinted (hashed) CSS assets. If an edge cache briefly serves
an older HTML page after a deploy, it may reference an older hash that no longer exists in the
new image. `verify-public-branding.sh` uses cache-busting for the homepage fetch to avoid
false negatives; if you see real user impact, purge the CDN cache for `/` and retry.

## Ecommerce Branding (Legacy)

**Note**: The legacy Oscar-based ecommerce service is being replaced by the custom Purchase Gateway (`services/purchase-gateway/`). Legacy ecommerce theming (Oscar template overrides) is being phased out in favor of the purchase-gateway's own frontend. See `specs/ecommerce-purchase-gateway_spec.md` for the migration plan and `docs/adr/018-purchase-gateway-replaces-oscar-ecommerce.md` for the architectural decision.

## Visual Snapshot (Screenshots)

To avoid "HTML checks pass but UI regressed" problems, capture periodic screenshots of the key
public surfaces (LMS/Studio/MFE login/ecommerce/credentials + microsites).

This writes to `var/screenshots/` (gitignored):

```bash
./scripts/qa/capture-branding-screenshots.sh prod
./scripts/qa/capture-branding-screenshots.sh dev
```

Run visual regression against two capture runs:

```bash
# Auto-picks previous run as baseline and latest run as candidate
./scripts/qa/visual-regression-branding.sh prod --threshold 0.06

# Explicit directories + strict file-set matching
./scripts/qa/visual-regression-branding.sh prod \
  --baseline var/screenshots/prod/<older_ts> \
  --candidate var/screenshots/prod/<newer_ts> \
  --strict

# Bootstrap-friendly run (first capture won't fail)
./scripts/qa/visual-regression-branding.sh prod --allow-bootstrap
```

Diff images are written to `var/screenshots-diff/<env>/<timestamp>/`.

You can run screenshot capture + visual diff in one command through the canonical branding gate:

```bash
RUN_SCREENSHOTS=1 \
RUN_VISUAL_REGRESSION=1 \
VISUAL_ALLOW_BOOTSTRAP=1 \
./scripts/branding/run-branding-gates.sh prod
```

To enforce branded authn assets for service-domain login entrypoints (`ecommerce.*`/`credentials.*`):

```bash
STRICT_PROXY_AUTHN_BRANDING=1 ./scripts/branding/run-branding-gates.sh prod
```

For periodic VPS execution (recommended), install the cron wrapper:

```bash
./scripts/infra/setup-vps-branding-visual-regression-cron.sh
```

The cron wrapper uses a default exclude regex for noisy dynamic/authenticated pages.
Tune it via `VISUAL_EXCLUDE_REGEX` in `var/branding-visual-regression.env`.

## Micro-Frontend Plug-in

- `infrastructure/tutor/themes/mereka/mfe/mereka.scss` reuses the same tokens/fonts, then layers on navbar/button/card tweaks tailored to Paragon components. Fonts are bundled with each MFE, so there are no cross-origin font requests.
- `scripts/branding/setup-mfe-branding.sh` is the one-stop helper for local development: it clones the upstream MFEs under `tutor_env/dev/`, copies the fonts into each `public/fonts/`, writes `src/styles/mereka.scss`, and ensures `src/index.scss` imports it.

### MFE Footer Component

The custom Mereka footer is currently implemented via **hardcoded JavaScript in `env.config.jsx`** (injected via Tutor plugin hook):

- The Tutor plugin (`infrastructure/tutor/plugins/mereka_lms.py`) injects the `MerekaFooter` React component directly into MFE build config via the `mfe-dockerfile-post-npm-install` hook.
- Implementation uses hardcoded JS in `env.config.jsx` that defines the footer component inline.

**Recommended migration path** (plugin-first, per ADR-014):

The target approach uses `tutormfe.hooks.PLUGIN_SLOTS` to register a **Direct plugin** (not iFrame) for `footer_slot`. This eliminates raw JS string injection in the Python plugin and lets the footer component live in a proper JSX module.

| Decision | Rule |
|----------|------|
| Direct plugin | Component needs MFE theme/auth context, <50 KB bundle |
| iFrame plugin | Sandboxed third-party code, separate framework |

**Operator workflow** for slot-based customization:
1. **Discover slot** — `grep -r "PluginSlot" node_modules/@openedx/*/src/`
2. **Inject config** — add `PLUGIN_SLOTS` entry in `mereka_lms.py`
3. **Rebuild image** — `tutor images build mfe`
4. **Deploy** — `tutor k8s restart mfe`
5. **Verify** — confirm component renders on all MFE routes

**Verification**: `./scripts/qa/verify-mfe-footer-slot.sh` (16 PASS — checks plugin definition, slot registration, fallback wiring, FPF dependency)

See `docs/programs/frontend/MFE_BRANDING_MIGRATION_DECISION.md` § "Plugin-First Migration" for full migration steps and available slots.

- To bake the branding into Tutor's production MFE image: `export TUTOR_ROOT="$(pwd)/tutor_env" && source infrastructure/tutor/tutor-env.sh && tutor images build mfe`.
- Always run `./infrastructure/tutor/apply-patches.sh` immediately before `tutor images build mfe` (ensures idempotent theming copy and npm retry/timeouts).
- Never run parallel `tutor images build mfe` commands; a single active build is the supported path.

## Favicons & Meta

- Primary favicon: `infrastructure/tutor/themes/mereka/common/static/images/favicon.ico` (synced from `assets/branding/favicon.ico`).
- Optional SVG: `infrastructure/tutor/themes/mereka/common/static/images/favicon.svg` if you want crisp scaling.
- Set `INDIGO_FAVICON_URL=https://<lms-host>/static/mereka/images/favicon.ico` via `tutor config save` so Django advertises the correct icon and MFEs reuse it from their config.

---

## Quick Reference

### Update Branding Assets

```bash
# 1. Update assets
cp new-logo.png assets/branding/logo-horizontal.png
cp new-font.woff2 assets/branding/fonts/

# 2. Sync to theme
./scripts/branding/sync-brand-assets.sh

# 3. Rebuild and deploy
./scripts/branding/deploy-branded-image.sh
```

### Verify Branding

```bash
# Local
./scripts/branding/verify-branding-health.sh

# Production
./scripts/branding/run-branding-gates.sh prod
```

### Common Commands

```bash
# Sync assets after changes
./scripts/branding/sync-brand-assets.sh

# Verify all brand package + theme asset drift
./scripts/qa/verify-brand-asset-drift.sh

# Verify branding health (CI gate)
./scripts/branding/verify-branding-health.sh

# Check logo setup
./scripts/branding/verify-logo-setup.sh

# Verify CSS loading
./scripts/branding/verify-branding-css.sh

# Check design token drift
./scripts/branding/verify-token-drift.sh

# Deploy branded image to production
./scripts/branding/deploy-branded-image.sh
```

---

## Troubleshooting

### Logo Not Showing

**Symptom**: Default Open edX logo appears instead of Mereka logo.

**Causes**:
1. **Assets not synced**:
   ```bash
   ./scripts/branding/sync-brand-assets.sh
   tutor local run lms ./manage.py lms collectstatic --noinput
   ```

2. **Theme not configured**:
   ```bash
   tutor config save --set THEME_NAME=mereka --set THEME_DIR="$(pwd)/infrastructure/tutor/themes"
   ./infrastructure/tutor/apply-patches.sh
   tutor local restart
   ```

3. **Cached static files**:
   ```bash
   # Clear browser cache
   # Or hard refresh: Ctrl+Shift+R (Linux/Win) / Cmd+Shift+R (Mac)
   ```

### Google Fonts Still Loading

**Symptom**: Network tab shows requests to `fonts.googleapis.com`

**Cause**: Font references not replaced with local fonts.

**Fix**:
```bash
# Verify fonts synced
ls -lh infrastructure/tutor/themes/mereka/common/static/fonts/

# Check SCSS imports
grep -r "google" infrastructure/tutor/themes/mereka/scss/
# Should return nothing

# Rebuild with patches
./infrastructure/tutor/apply-patches.sh
tutor images build openedx
```

### MFE Shows Default Theme

**Symptom**: MFE not using Mereka branding.

**Causes**:
1. **Branding not set up in dev**:
   ```bash
   ./scripts/branding/setup-mfe-branding.sh
   cd tutor_env/dev/frontend-app-learning
   npm start
   ```

2. **Production MFE image not rebuilt**:
   ```bash
   ./infrastructure/tutor/apply-patches.sh
   tutor images build mfe
   kubectl rollout restart deployment/mfe -n mereka-lms
   ```

### Branding Health Check Fails

**Symptom**: `verify-branding-health.sh` exits with errors.

**Debug**:
```bash
# Run with verbose output
./scripts/branding/verify-branding-health.sh

# Check specific assets
ls -lh infrastructure/tutor/themes/mereka/lms/static/images/logo*.png
ls -lh infrastructure/tutor/themes/mereka/lms/static/fonts/*.woff2

# Verify SCSS structure
find infrastructure/tutor/themes/mereka -name "*.scss"
```

### CSS Not Applying

**Symptom**: Branding colors/styles not showing.

**Causes**:
1. **CSS not loaded**:
   ```bash
   # Check head-extra template
   grep "mereka-overrides.css" infrastructure/tutor/themes/mereka/lms/templates/head-extra.html

   # Verify CSS exists
   ls -lh infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css
   ```

2. **Collectstatic not run**:
   ```bash
   tutor local run lms ./manage.py lms collectstatic --noinput
   tutor local restart
   ```

---

## Related Resources

**Spec**: `specs/branding-system_spec.md` (10 ACs, 100% complete)

**Operations Docs**:
- `docs/guides/branding/BRANDING_OPERATING_MODEL.md` - Branding workflow and ownership
- `docs/guides/branding/BRANDING_GUARDRAILS.md` - What NOT to change
- `docs/status/active/BRANDING_ROADMAP_2026-02-08.md` - Future branding plans
- `docs/guides/branding/BRANDING_VERIFICATION_CHECKLIST.md` - Pre-deploy checklist
- `docs/status/active/BRANDING_PLAN_2026-03-03.md` - Active rollout/status tracker
- `docs/reference/architecture/THEMING_GENERATED_ARTIFACT_CONTRACT.md` - Source vs generated theming contract

**Scripts**:
- `scripts/branding/sync-brand-assets.sh` - Sync assets to theme
- `scripts/branding/sync-brand-package.sh` - Sync all `brand-*` OEP-48 packages from canonical asset sources
- `scripts/qa/verify-brand-asset-drift.sh` - Verify theme + brand package asset drift
- `scripts/qa/verify-branding-script-portability.sh` - Block workstation-specific paths in branding automation scripts
- `scripts/branding/build-tokens.sh` - Generate/check runtime `/theme/*.min.css` artifacts
- `scripts/branding/verify-branding-health.sh` - CI gate
- `scripts/branding/verify-logo-setup.sh` - Logo verification
- `scripts/branding/verify-branding-css.sh` - CSS loading check
- `scripts/branding/verify-token-drift.sh` - Design token drift detection
- `scripts/branding/deploy-branded-image.sh` - Production deployment
- `scripts/branding/setup-mfe-branding.sh` - MFE dev setup
- `scripts/branding/run-branding-gates.sh` - Full gate suite
- `scripts/qa/verify-theming-generated-artifacts.sh` - Generated-theming governance gate

**Assets**:
- `assets/branding/` - Source assets (logos, fonts, tokens)
- `assets/branding/tenants/` - Source assets for non-default tenant brand packages
- `infrastructure/tutor/themes/mereka/` - Theme directory
- `infrastructure/tutor/themes/mereka/scss/theme.scss` - Shared SCSS
- `infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css` - Runtime CSS

**Design System**:
- `bbbi-mereka-brand-assets` (external repo) - Design source of truth
- `assets/branding/tokens.css` - Design tokens (vendored from Figma)
