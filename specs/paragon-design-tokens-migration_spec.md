---
title: "Paragon Design Tokens Migration: SCSS Variable Overrides to JSON Token Pipeline"
type: "migration_spec"
status: "draft"
version: "1.0.0"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-27"
depends_on:
  - "specs/branding-system_spec.md"
  - "specs/design-tokens-system_spec.md"
links:
  related_docs:
    - "docs/BRANDING.md"
    - "assets/branding/tokens.css"
    - "assets/branding/tokens.provenance.json"
    - "infrastructure/tutor/themes/mereka/scss/_tokens.scss"
    - "infrastructure/tutor/themes/mereka/mfe/mereka.scss"
  related_specs:
    - "specs/cross-cutting-requirements_spec.md"
    - "specs/branding-system_spec.md"
    - "specs/design-tokens-system_spec.md"
    - "specs/multi-site-domains_spec.md"
---

# Human Summary

## What is changing

The Mereka Academy branding pipeline is migrating from SCSS variable overrides (`_tokens.scss` lines 77-136 with Bootstrap `$variable` overrides) and flat CSS custom properties (`tokens.css` with ~100+ `--mereka-*` variables) to the Paragon v23+ three-tier JSON design token system. This involves:

1. Creating a structured JSON token hierarchy (`global.json`, `alias.json`, `components/*.json`) that maps our existing brand values into the Paragon-native `tokens/src/core/` directory structure.
2. Setting up a style-dictionary pipeline that deep-merges our JSON overrides over Paragon core tokens, resolves `{references}`, applies `modify` transforms (darken, lighten, mix), and outputs CSS custom properties (`--pgn-*`).
3. Configuring `PARAGON_THEME_URLS` so all MFEs fetch compiled theme CSS at runtime from a CDN endpoint instead of compiling tokens at build time.
4. Integrating `tutor-contrib-paragon` to compile and serve the theme.
5. Systematically replacing the 28+ BEM selector overrides in `mereka.scss` (navbar, buttons, cards, alerts, modals, forms, tabs, dropdowns, authn surfaces, dashboard surfaces, discussions surfaces) with token-based equivalents that Paragon consumes natively.
6. Decommissioning the SCSS variable layer (`_tokens.scss` lines 77-136) and the `--mereka-*` CSS custom property bridge once all MFEs consume tokens via `PARAGON_THEME_URLS`.

**Files affected**:
- **New**: `tokens/src/core/global.json`, `tokens/src/core/alias.json`, `tokens/src/core/components/*.json`, `style-dictionary.config.js`, `scripts/branding/build-tokens.sh`
- **Modified**: `infrastructure/tutor/plugins/mereka_lms.py` (PARAGON_THEME_URLS config), Tutor plugin for `tutor-contrib-paragon`
- **Deprecated (Phase 4)**: `infrastructure/tutor/themes/mereka/scss/_tokens.scss` lines 77-136, bulk of `infrastructure/tutor/themes/mereka/mfe/mereka.scss`
- **Retained**: `assets/branding/tokens.css` (canonical reference), `assets/branding/tokens.provenance.json` (provenance tracking)

## Why

The current SCSS variable override approach (`$primary`, `$secondary`, `$font-family-sans-serif`, etc.) is deprecated in Paragon v23+. Paragon's upstream roadmap replaces Bootstrap SCSS variables with a JSON-based design token pipeline powered by style-dictionary. When Paragon v23 ships, our `_tokens.scss` overrides will silently stop applying because Paragon will read tokens from JSON files, not SCSS variables. This will cause:

- **Visual regression**: MFEs revert to Paragon default blue/purple palette instead of Mereka teal/magenta.
- **Build failures**: SCSS compilation may break if Paragon removes the `$variable` injection points.
- **BEM selector fragility**: The 28+ BEM overrides in `mereka.scss` (marked HIGH/MEDIUM risk with `expires: 2026-Q3`) target class names that Paragon may rename or remove. The token-based approach makes these overrides unnecessary because component appearance is controlled at the token level.

Additionally, `PARAGON_THEME_URLS` enables runtime theming. Instead of rebuilding every MFE Docker image when a brand color changes, the compiled theme CSS is fetched at page load. This reduces the branding update cycle from "rebuild all MFE images (15-20 min) + redeploy" to "rebuild token CSS (seconds) + CDN invalidation".

## Success looks like

- All 9 MFEs (authn, account, dashboard, learning, discussions, profile, course-authoring, gradebook, ora-grading) render with Mereka branding via `PARAGON_THEME_URLS` without any SCSS variable overrides.
- Brand color changes propagate to all MFEs by rebuilding the token CSS and updating the CDN endpoint, without rebuilding MFE Docker images.
- The `mereka.scss` file is reduced from 614 lines to fewer than 50 lines (only truly structural overrides that cannot be expressed as tokens remain).
- `_tokens.scss` lines 77-136 (Bootstrap `$variable` overrides) are removed entirely.
- Zero visual regressions confirmed by automated screenshot comparison against baseline.
- Token count validation passes: the compiled CSS output contains at least 100 `--pgn-*` custom properties.

---

# Agent Contract

## Scope

### In Scope

- JSON token file creation: three-tier hierarchy (`global.json`, `alias.json`, `components/*.json`) mapping all values from `assets/branding/tokens.css` and `_tokens.scss`
- style-dictionary pipeline: config file, custom transforms, output format targeting `--pgn-*` CSS custom properties
- `PARAGON_THEME_URLS` configuration in Tutor plugin (`mereka_lms.py`) for all environments (local, nonprod, production)
- `tutor-contrib-paragon` plugin integration for token compilation and CDN serving
- Token build script (`scripts/branding/build-tokens.sh`) for local and CI builds
- Backward compatibility layer: keeping `_tokens.scss` SCSS variables functional during transition (Phases 1-3)
- Migration of ~40 hardcoded `rgba()` values and 2 hex colors in `mereka.scss` to token references
- Replacement plan for 28+ BEM selector overrides with token-based equivalents
- Verification scripts: token count validation, drift detection between JSON source and CSS output, visual regression gates
- CDN endpoint configuration for serving compiled theme CSS
- CI pipeline integration: token build + validation in `.github/ci-scripts-static.txt`
- Documentation updates to `docs/BRANDING.md`

### Out of Scope

- Multi-tenant per-brand token sets (separate spec for multi-tenancy theming)
- Dark mode variant tokens (future enhancement)
- Automated Figma-to-JSON token sync pipeline (manual sync via provenance system)
- LMS/CMS comprehensive theme SCSS (`lms/static/sass/theme.scss`, `cms/static/sass/studio-main-v1.scss`) -- these are server-rendered, not MFE, and follow a different theming path
- Upstream Paragon contributions (we consume, not contribute)
- OEP-48 brand package spec (referenced as future dependency, not blocking)

## Non-goals

- We are NOT building a design token editor UI.
- We are NOT implementing real-time token hot-reloading (runtime fetch on page load is sufficient).
- We are NOT creating a token documentation site (Figma remains the design documentation source).
- We are NOT migrating LMS/CMS server-rendered theme SCSS to JSON tokens (only MFE theming).
- We are NOT building a token versioning system (git history provides version tracking).

## Requirements

### Functional

#### JSON Token Hierarchy

- The system MUST create JSON token files in the Paragon-compatible three-tier hierarchy:
  - `tokens/src/core/global.json`: primitive values (hex colors, px sizes, font stacks, timing values)
  - `tokens/src/core/alias.json`: semantic aliases that reference global tokens via `{global.color.teal}` syntax
  - `tokens/src/core/components/*.json`: per-component token overrides (button, card, alert, modal, navbar, form-control, dropdown, tabs, badge)
- Global tokens MUST include all values currently defined in `assets/branding/tokens.css` (100+ tokens across colors, typography, spacing, sizing, shadows, z-index, animation, breakpoints, containers).
- Alias tokens MUST map semantic names to global primitives (e.g., `color.primary` references `{global.color.magenta}`, `color.secondary` references `{global.color.teal}`).
- Component tokens MUST express the visual properties currently hardcoded in `mereka.scss` BEM overrides (border-radius, box-shadow, background gradients, focus rings).
- Token values MUST NOT contain hardcoded hex colors, px values, or rgba values that duplicate global tokens. All component and alias tokens MUST use `{references}` to global tokens.

#### style-dictionary Pipeline

- The system MUST include a `style-dictionary.config.js` (or `.json`) configuration file at the repository root (or `tokens/` directory).
- The pipeline MUST deep-merge Mereka token JSON files over Paragon core defaults.
- The pipeline MUST resolve `{reference}` syntax to final values.
- The pipeline MUST support `modify` transforms for derived colors (darken, lighten, mix, alpha).
- The pipeline MUST output a single CSS file with `--pgn-*` custom properties in a `:root` selector.
- The pipeline MUST be executable via `scripts/branding/build-tokens.sh` with no manual steps.
- The pipeline SHOULD complete in under 10 seconds for the current token set size.

#### PARAGON_THEME_URLS Configuration

- The Tutor plugin MUST configure `PARAGON_THEME_URLS` in MFE runtime config with the structure:
  ```json
  {
    "core": {
      "urls": {
        "default": "<cdn-url>/core.min.css",
        "brandOverride": "<cdn-url>/mereka-brand.min.css"
      }
    },
    "variants": {
      "light": {
        "urls": {
          "default": "<cdn-url>/light.min.css",
          "brandOverride": "<cdn-url>/mereka-brand-light.min.css"
        }
      }
    }
  }
  ```
- The CDN URL MUST be configurable per environment (local: relative path, nonprod: `apps.academyv2.mereka.dev`, production: `apps.academyv2.mereka.io`).
- The system MUST serve the compiled theme CSS from the Caddy static file server alongside MFE assets.
- MFEs MUST NOT require rebuild when `PARAGON_THEME_URLS` CSS files are updated.

#### tutor-contrib-paragon Integration

- The system SHOULD use `tutor-contrib-paragon` plugin if it supports Tutor 21 (Ulmo).
- If `tutor-contrib-paragon` is incompatible, the system MUST implement equivalent functionality in `mereka_lms.py` plugin:
  - Token compilation during `tutor images build mfe`
  - CSS output placement in the MFE static asset directory
  - `PARAGON_THEME_URLS` injection into MFE runtime config
- The integration MUST NOT break existing MFE builds.

#### Backward Compatibility

- During Phases 1-3, the system MUST maintain the existing `_tokens.scss` SCSS variable overrides so that any MFE not yet consuming `PARAGON_THEME_URLS` continues to render with Mereka branding.
- The `--mereka-*` CSS custom properties in `_tokens.scss` `:root` block MUST remain until Phase 4 decommission.
- The `--pgn-*` overrides currently in `_tokens.scss` (lines 59-74) MUST be preserved until `PARAGON_THEME_URLS` is confirmed working for all MFEs.

#### BEM Override Replacement

- Each BEM selector override in `mereka.scss` MUST be evaluated for token-based replacement:
  - Overrides that set `border-radius`, `box-shadow`, `background-color`, `color`, `border-color`, `font-family`, `font-weight`, `font-size` SHOULD be replaceable by component tokens.
  - Overrides that set `display`, `flex`, `gap`, `padding`, `margin`, `aspect-ratio`, `object-fit`, `min-width`, `max-width`, `min-height`, `max-height` are structural and MAY need to remain as CSS overrides.
- The migration MUST track which overrides are replaced by tokens and which must remain, with justification for each retained override.

#### Verification Gates

- The system MUST include a verification script that validates:
  - The compiled CSS output contains at least 100 `--pgn-*` custom properties.
  - All global token values from `assets/branding/tokens.css` appear in the compiled output (no token loss).
  - No `{unresolved.reference}` strings remain in the compiled CSS.
- The system MUST include a drift detection script comparing JSON token source values against compiled CSS output.
- The system SHOULD include visual regression testing comparing MFE screenshots before and after migration.

### Non-Functional Requirements

- [ ] AC-TKN-NFR-001: The token build pipeline MUST complete in under 30 seconds including style-dictionary compilation and CSS minification.
- [ ] AC-TKN-NFR-002: The compiled theme CSS file MUST be smaller than 50 KB (minified, uncompressed) to avoid impacting MFE page load time.
- [ ] AC-TKN-NFR-003: MFE page load time (First Contentful Paint) MUST NOT increase by more than 100ms compared to the SCSS-compiled baseline when using `PARAGON_THEME_URLS`.
- [ ] AC-TKN-NFR-004: The token pipeline MUST NOT introduce new runtime JavaScript dependencies (CSS-only theming).

**Cross-Cutting Inheritance**: This spec inherits requirements from `specs/cross-cutting-requirements_spec.md` including:
- Observability baseline (CI metrics for token build)
- Secrets management (CDN URLs are not secrets but environment-specific config)
- Common NFR thresholds

## Acceptance Criteria

### JSON Token File Creation

- [ ] AC-TKN-001: Given the repository, when `tokens/src/core/global.json` is parsed, then it contains at least 100 token entries covering colors (25+), typography (15+), spacing (14), sizing (16+), shadows (4), z-index (7), animation (9), border-radius (6).
- [ ] AC-TKN-002: Given `tokens/src/core/global.json`, when color token `color.teal` is read, then its value is `#237072` matching `assets/branding/tokens.css --color-teal`.
- [ ] AC-TKN-003: Given `tokens/src/core/alias.json`, when semantic token `color.primary` is read, then its value is `{global.color.magenta}` (a reference, not a hardcoded hex value).
- [ ] AC-TKN-004: Given `tokens/src/core/alias.json`, when semantic token `color.secondary` is read, then its value is `{global.color.teal}`.
- [ ] AC-TKN-005: Given `tokens/src/core/alias.json`, when all alias tokens are enumerated, then none contain raw hex values -- all use `{reference}` syntax.
- [ ] AC-TKN-006: Given `tokens/src/core/components/button.json`, when parsed, then it defines `border-radius` as `{global.radius.full}` (mapping the current `border-radius: 999px` override).
- [ ] AC-TKN-007: Given `tokens/src/core/components/card.json`, when parsed, then it defines `border-radius` with a value referencing a global radius token.
- [ ] AC-TKN-008: Given `tokens/src/core/components/`, when all component JSON files are listed, then at least 9 files exist: `button.json`, `card.json`, `alert.json`, `modal.json`, `navbar.json`, `form-control.json`, `dropdown.json`, `tabs.json`, `badge.json`.

### style-dictionary Pipeline

- [ ] AC-TKN-009: Given `style-dictionary.config.js` exists, when `./scripts/branding/build-tokens.sh` is run, then a CSS file is generated at the configured output path containing `--pgn-*` custom properties.
- [ ] AC-TKN-010: Given the generated CSS file, when `--pgn-color-primary` is extracted, then its value resolves to `#ab3b78` (Mereka magenta).
- [ ] AC-TKN-011: Given the generated CSS file, when `--pgn-color-secondary` is extracted, then its value resolves to `#237072` (Mereka teal).
- [ ] AC-TKN-012: Given the generated CSS file, when `--pgn-font-family-sans-serif` is extracted, then its value contains `Poppins`.
- [ ] AC-TKN-013: Given the generated CSS file, when all custom properties are counted, then there are at least 100 `--pgn-*` entries.
- [ ] AC-TKN-014: Given the generated CSS file, when searched for `{`, then zero unresolved reference strings are found (all references fully resolved).
- [ ] AC-TKN-015: Given style-dictionary config, when a `modify` transform is defined (e.g., `darken` on `color.primary` by 10%), then the output CSS contains the computed color value (not a reference or function call).

### PARAGON_THEME_URLS Configuration

- [ ] AC-TKN-016: Given the Tutor plugin `mereka_lms.py`, when MFE config is rendered, then `PARAGON_THEME_URLS` is present with `core.urls.default` and `core.urls.brandOverride` keys.
- [ ] AC-TKN-017: Given `PARAGON_THEME_URLS` is configured, when the authn MFE is loaded in a browser, then the page fetches the `brandOverride` CSS URL and applies Mereka branding (teal/magenta palette, Poppins/Lato fonts).
- [ ] AC-TKN-018: Given `PARAGON_THEME_URLS` is configured, when the compiled CSS file at the `brandOverride` URL is updated and the browser cache is cleared, then the MFE reflects the updated brand values without MFE image rebuild.
- [ ] AC-TKN-019: Given production environment, when `PARAGON_THEME_URLS` CDN URL is accessed, then the response includes `Content-Type: text/css`, has `Cache-Control` headers, and the file is served with HTTP 200.

### CDN Serving

- [ ] AC-TKN-020: Given the compiled theme CSS, when Caddy configuration is inspected, then a route serves the theme CSS from a stable URL path (e.g., `/theme/mereka-brand.min.css`).
- [ ] AC-TKN-021: Given the theme CSS is served via Caddy, when the URL is fetched, then the `Content-Type` header is `text/css` and the response body contains `--pgn-color-primary`.

### Backward Compatibility

- [ ] AC-TKN-022: Given Phase 1-3 (migration in progress), when an MFE is built without `PARAGON_THEME_URLS` support, then the SCSS `$primary`, `$secondary`, `$font-family-sans-serif` variables from `_tokens.scss` still apply Mereka branding.
- [ ] AC-TKN-023: Given Phase 1-3, when `_tokens.scss` is inspected, then both the SCSS variable block (lines 77-136) and the `:root` CSS custom property block (lines 37-74) are present.

### BEM Override Migration

- [ ] AC-TKN-024: Given the component token files, when compiled, then the `.pgn__btn--primary` background, border, and shadow are controlled by token values (not BEM CSS overrides in `mereka.scss`).
- [ ] AC-TKN-025: Given the component token files, when compiled, then `.pgn__card` border-radius and box-shadow are controlled by token values.
- [ ] AC-TKN-026: Given the component token files, when compiled, then `.pgn__alert` border-radius and variant background colors are controlled by token values.
- [ ] AC-TKN-027: Given `mereka.scss` after Phase 3 migration, when its line count is measured, then it is fewer than 100 lines (down from 614).
- [ ] AC-TKN-028: Given `mereka.scss` after Phase 3 migration, when parsed for hardcoded `rgba()` values, then fewer than 5 remain (down from ~40), with each justified as a structural override not expressible as a token.

### Verification Gates

- [ ] AC-TKN-029: Given `scripts/qa/verify-paragon-tokens.sh` exists, when run after a successful token build, then it validates: (a) token count >= 100, (b) zero unresolved references, (c) all canonical color values from `tokens.css` present in output.
- [ ] AC-TKN-030: Given `scripts/qa/verify-paragon-tokens.sh`, when the token build output is missing `--pgn-color-primary`, then the script exits non-zero with an error message identifying the missing token.
- [ ] AC-TKN-031: Given the verification script is added to `.github/ci-scripts-static.txt`, when CI runs, then token validation is part of the static-validation job.
- [ ] AC-TKN-032: Given visual regression testing is configured, when MFE screenshots are compared before and after token migration, then pixel difference is less than 1% for each of the 9 MFE landing pages.

### tutor-contrib-paragon Integration

- [ ] AC-TKN-033: Given `tutor-contrib-paragon` is installed (or equivalent in `mereka_lms.py`), when `tutor images build mfe` is run, then the token compilation step executes and the compiled CSS is included in the MFE image.
- [ ] AC-TKN-034: Given the Tutor plugin, when `tutor config save` is run followed by `apply-patches.sh`, then `PARAGON_THEME_URLS` is present in the rendered MFE environment configuration.

### Cross-Spec Integration

#### Design Tokens System (design-tokens-system_spec.md)

- [ ] AC-TKN-INT-001: Given the JSON token pipeline is active, when `assets/branding/tokens.css` is updated via the provenance sync workflow, then the JSON global tokens MUST be regenerated to match (via `scripts/branding/sync-tokens-to-json.sh` or equivalent).
- [ ] AC-TKN-INT-002: Given drift detection from `design-tokens-system_spec.md` (AC-008 through AC-010), when both the old CSS drift check and the new JSON-to-CSS drift check are run, then both pass.

#### Branding System (branding-system_spec.md)

- [ ] AC-TKN-INT-003: Given the branding system asset pipeline, when Mereka brand assets are synced, then the JSON token hierarchy is updated as part of the sync workflow.

## Dependencies

### Upstream

- **specs/design-tokens-system_spec.md**: The canonical `tokens.css` and provenance tracking system must be operational. JSON tokens are derived from these canonical values.
- **specs/branding-system_spec.md**: The brand asset pipeline and theme directory structure must be stable.
- **Paragon v23+ release**: The JSON token system must be available in the Paragon version used by our MFE images. If Paragon v23 is not yet released, Phase 1 (JSON creation + pipeline) can proceed but Phase 2 (PARAGON_THEME_URLS) is blocked.
- **tutor-contrib-paragon compatibility**: Must be compatible with Tutor 21 (Ulmo). If not, equivalent functionality must be implemented in `mereka_lms.py`.

### Downstream

- **Multi-tenant theming (future spec)**: Per-tenant brand tokens will build on this pipeline. The JSON hierarchy and style-dictionary config established here become the foundation.
- **Dark mode (future)**: The `variants.light` / `variants.dark` structure in `PARAGON_THEME_URLS` is prepared by this spec but dark mode tokens are out of scope.
- **OEP-48 brand package (future spec)**: The upstream OEP-48 standard for distributing brand packages as npm modules will consume the JSON tokens created by this spec.

## Verification

### Automated Verification

Add verification scripts to `scripts/qa/` with `@covers` annotations:

```bash
#!/usr/bin/env bash
# @covers AC-TKN-001, AC-TKN-002, AC-TKN-003, AC-TKN-004, AC-TKN-005, AC-TKN-008
# @spec: paragon-design-tokens-migration_spec

set -euo pipefail
# Validate JSON token file structure and content
```

```bash
#!/usr/bin/env bash
# @covers AC-TKN-009, AC-TKN-010, AC-TKN-011, AC-TKN-012, AC-TKN-013, AC-TKN-014
# @spec: paragon-design-tokens-migration_spec

set -euo pipefail
# Run style-dictionary build and validate output
```

```bash
#!/usr/bin/env bash
# @covers AC-TKN-029, AC-TKN-030, AC-TKN-031
# @spec: paragon-design-tokens-migration_spec

set -euo pipefail
# Token count validation, drift detection, CI gate
```

Run coverage report:
```bash
scripts/qa/spec-tools/ac-coverage-report.py
```

### Manual Verification

1. **Visual regression (AC-TKN-032)**: Load each of the 9 MFEs in a browser after enabling `PARAGON_THEME_URLS`, compare against baseline screenshots. Verify teal/magenta palette, Poppins/Lato fonts, rounded buttons, branded cards.
2. **CDN cache invalidation (AC-TKN-018)**: Update a color token, rebuild CSS, verify MFEs reflect the change after cache clear without MFE image rebuild.
3. **Backward compatibility (AC-TKN-022)**: Disable `PARAGON_THEME_URLS`, verify MFEs still render with Mereka branding via SCSS path.

Add to `specs/manual_verifications.yaml`:
```yaml
- id: "AC-TKN-032"
  spec: "paragon-design-tokens-migration_spec.md"
  verify:
    - type: manual
      runbook: "docs/BRANDING.md"
      section: "Visual Regression Testing"
      justification: "Pixel-level visual comparison requires human judgment for acceptable differences"
```

### Test Plan

See `specs/plans/paragon-design-tokens-migration_test_plan.md` for comprehensive test scenarios (to be created during implementation).

## Data Model

### JSON Token Structure (global.json)

```json
{
  "global": {
    "color": {
      "black": { "value": "#000000" },
      "white": { "value": "#ffffff" },
      "teal": { "value": "#237072" },
      "magenta": { "value": "#ab3b78" },
      "blue": { "value": "#295cad" },
      "burgundy": { "value": "#8c002f" },
      "pink": { "value": "#cd89ae" },
      "sky": { "value": "#94d1e4" },
      "forest": { "value": "#2c6e49" },
      "gold": { "value": "#f4be48" }
    },
    "font": {
      "body": { "value": "'Poppins', 'Lato', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif" },
      "heading": { "value": "'Lato', 'Poppins', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif" }
    },
    "radius": {
      "none": { "value": "0px" },
      "sm": { "value": "4px" },
      "md": { "value": "8px" },
      "lg": { "value": "12px" },
      "xl": { "value": "16px" },
      "full": { "value": "9999px" }
    }
  }
}
```

### JSON Token Structure (alias.json)

```json
{
  "color": {
    "primary": { "value": "{global.color.magenta}" },
    "secondary": { "value": "{global.color.teal}" },
    "success": { "value": "{global.color.forest}" },
    "info": { "value": "{global.color.blue}" },
    "warning": { "value": "{global.color.gold}" },
    "danger": { "value": "{global.color.burgundy}" },
    "body": { "value": "{global.color.black}" },
    "link": { "value": "{global.color.blue}" },
    "link-hover": { "value": "{global.color.teal}" }
  },
  "font": {
    "family-sans-serif": { "value": "{global.font.body}" },
    "family-heading": { "value": "{global.font.heading}" }
  }
}
```

### JSON Token Structure (components/button.json)

```json
{
  "button": {
    "border-radius": { "value": "{global.radius.full}" },
    "primary": {
      "background": { "value": "linear-gradient(120deg, {global.color.magenta} 0%, {global.color.teal} 60%, {global.color.blue} 100%)" },
      "border": { "value": "none" },
      "font-weight": { "value": "700" }
    }
  }
}
```

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PARAGON_THEME_URLS` | Yes (Phase 2+) | N/A | JSON object with CDN URLs for core and brand override CSS |
| `MEREKA_TOKEN_BUILD_DIR` | No | `tokens/build/` | Output directory for compiled token CSS |
| `MEREKA_TOKEN_CDN_BASE` | No | `/theme/` | Base URL path for serving compiled theme CSS |

### Feature Flags

| Flag | Default | Description |
|------|---------|-------------|
| `ENABLE_PARAGON_TOKEN_PIPELINE` | false | Enable JSON token compilation during MFE image build |
| `ENABLE_PARAGON_THEME_URLS` | false | Enable runtime CDN theming for MFEs (set true in Phase 2) |

## Observability

### Metrics

- `mereka_token_build_duration_seconds`: Time taken for style-dictionary compilation (histogram, recorded in CI).
- `mereka_token_count_total`: Number of `--pgn-*` properties in compiled output (gauge, recorded in CI).
- `mereka_theme_css_size_bytes`: Size of compiled theme CSS file (gauge, recorded in CI).

### Alerts

- **Token Build Failure**: Fires when `scripts/branding/build-tokens.sh` exits non-zero in CI, severity=high.
- **Token Count Regression**: Fires when compiled token count drops below 100 (indicating lost tokens), severity=high.
- **Theme CSS Size Spike**: Fires when compiled CSS exceeds 50 KB, severity=medium.

### Dashboards

- CI job metrics in GitHub Actions summary: build duration, token count, CSS size, drift check result.

## Migration Strategy

### Phase 1 -- Create JSON Tokens and Pipeline (No Runtime Impact)

**What happens**: Create the JSON token hierarchy and style-dictionary pipeline. The pipeline compiles tokens locally but does not affect any deployed MFE. The existing SCSS path continues to serve all branding.

**Deliverables**:
1. `tokens/src/core/global.json` -- all primitive values from `tokens.css`
2. `tokens/src/core/alias.json` -- semantic mappings (primary, secondary, success, info, warning, danger, link colors, font families)
3. `tokens/src/core/components/*.json` -- 9 component token files
4. `style-dictionary.config.js` -- pipeline configuration
5. `scripts/branding/build-tokens.sh` -- build script
6. `scripts/branding/sync-tokens-to-json.sh` -- sync canonical `tokens.css` values into JSON
7. `scripts/qa/verify-paragon-tokens.sh` -- verification gate
8. Token build added to `.github/ci-scripts-static.txt`

**Acceptance**: AC-TKN-001 through AC-TKN-015, AC-TKN-029 through AC-TKN-031.

**Risk**: None. No production impact. Additive only.

### Phase 2 -- Enable PARAGON_THEME_URLS (Runtime CDN Theming)

**What happens**: Configure `PARAGON_THEME_URLS` in the Tutor plugin. Compiled theme CSS is served from Caddy. MFEs fetch brand CSS at page load. Both SCSS and JSON paths are active (dual-running).

**Deliverables**:
1. `mereka_lms.py` plugin updated with `PARAGON_THEME_URLS` config
2. Caddy route for serving theme CSS
3. `tutor-contrib-paragon` installed (or equivalent in plugin)
4. Token CSS included in MFE image build
5. Feature flag `ENABLE_PARAGON_THEME_URLS=true`

**Acceptance**: AC-TKN-016 through AC-TKN-021, AC-TKN-033, AC-TKN-034.

**Risk**: Medium. Visual regression possible if token-to-CSS compilation produces different values than SCSS path. Mitigated by dual-running and visual comparison.

**Rollback**: Set `ENABLE_PARAGON_THEME_URLS=false` in Tutor config. MFEs fall back to SCSS-compiled branding. No rebuild needed (MFEs check for `PARAGON_THEME_URLS` at runtime).

### Phase 3 -- Replace BEM Overrides with Tokens

**What happens**: Systematically replace BEM selector overrides in `mereka.scss` with component token equivalents. Each override is evaluated: if expressible as a token, the BEM rule is removed and the component JSON token is added. Structural overrides (flex layout, aspect-ratio, gap) are retained with justification.

**Deliverables**:
1. Updated component JSON tokens covering button, card, alert, modal, navbar, form, dropdown, tabs, badge appearance
2. `mereka.scss` reduced from 614 lines to <100 lines
3. Hardcoded `rgba()` values reduced from ~40 to <5
4. Migration tracking document listing each override and its disposition (replaced/retained/justification)

**Acceptance**: AC-TKN-024 through AC-TKN-028, AC-TKN-032.

**Risk**: High. Visual regression on specific MFE pages where BEM overrides provided critical layout fixes. Mitigated by per-override testing and visual regression screenshots.

**Rollback**: Revert `mereka.scss` to pre-Phase-3 version via `git checkout`. The SCSS and token paths are both active, so reverting the SCSS file restores the BEM overrides.

### Phase 4 -- Decommission SCSS Layer

**What happens**: Remove the SCSS variable override block from `_tokens.scss` (lines 77-136). Remove the `--mereka-*` CSS custom property bridge from the `:root` block (lines 37-74). Remove `mereka.scss` BEM overrides that were replaced by tokens. The JSON token pipeline is now the sole source of MFE branding.

**Deliverables**:
1. `_tokens.scss` reduced to only the Mereka-specific palette variables (lines 1-36) and the `:root` block with only structural `--mereka-*` properties not covered by Paragon tokens
2. `mereka.scss` contains only structural overrides that cannot be expressed as tokens
3. Verification that no MFE renders with default Paragon branding
4. Updated `docs/BRANDING.md` documenting the new token-based workflow

**Acceptance**: AC-TKN-022 and AC-TKN-023 are no longer applicable (backward compat removed). All other ACs still pass.

**Risk**: Medium. If any MFE does not support `PARAGON_THEME_URLS`, it will lose Mereka branding. Mitigated by Phase 2 verification that all 9 MFEs work with runtime theming before decommissioning.

**Rollback**: Restore `_tokens.scss` and `mereka.scss` from git history. Re-enable SCSS path.

### Rollback Plan

**Phase 1**: No rollback needed (additive, no runtime impact). Delete `tokens/` directory if abandoning.

**Phase 2**: Set `ENABLE_PARAGON_THEME_URLS=false` in Tutor config, run `tutor config save && apply-patches.sh && tutor local restart`. MFEs revert to SCSS-compiled branding. No image rebuild required.

**Phase 3**: `git checkout HEAD~N -- infrastructure/tutor/themes/mereka/mfe/mereka.scss` to restore BEM overrides. Rebuild MFE image. Both token and SCSS paths remain active.

**Phase 4**: `git checkout HEAD~N -- infrastructure/tutor/themes/mereka/scss/_tokens.scss infrastructure/tutor/themes/mereka/mfe/mereka.scss`. Rebuild MFE image. Full restoration of SCSS path.

### Data Preservation

- `assets/branding/tokens.css` is preserved throughout all phases (canonical reference, not modified by this migration).
- `assets/branding/tokens.provenance.json` continues tracking upstream sync regardless of token pipeline.
- All SCSS files are version-controlled; git history provides full rollback capability.
- JSON token files are new artifacts, not replacing existing data.

## Risks and Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Visual regression during migration | High | Medium | Per-MFE screenshot comparison at each phase. Dual-running SCSS + token paths until Phase 4. |
| Paragon version mismatch across MFEs | High | Medium | Pin Paragon version in MFE build. Verify all 9 MFEs use same Paragon version before enabling PARAGON_THEME_URLS. |
| style-dictionary breaks on Paragon token schema changes | Medium | Low | Pin style-dictionary version. Validate output in CI. |
| tutor-contrib-paragon incompatible with Tutor 21 | Medium | Medium | Fallback: implement equivalent in mereka_lms.py plugin (already scoped in requirements). |
| CDN cache serves stale theme CSS after update | Medium | Medium | Include content hash in CSS filename (e.g., `mereka-brand.[hash].min.css`). Configure Caddy `Cache-Control` with short max-age + `must-revalidate`. |
| BEM overrides provide structural layout fixes that tokens cannot replace | Medium | High | Track each override individually. Retain structural overrides with justification. Target <100 lines, not zero. |
| MFE does not read PARAGON_THEME_URLS at runtime | High | Low | Verify each MFE's `@edx/frontend-platform` version supports runtime theme URLs. Upgrade if needed. |
| Increased page load time from CDN CSS fetch | Low | Low | Measure FCP delta. Theme CSS is small (<50 KB) and cacheable. Preload hint in HTML. |

## Edge Cases

### Token Reference Cycle

**Symptom**: style-dictionary build fails with "circular reference" error.

**Cause**: Alias token A references alias token B which references A.

**Recovery**: Ensure alias tokens only reference global tokens, never other aliases. The three-tier hierarchy (global -> alias -> component) prevents cycles by convention. Add a lint rule to `scripts/qa/verify-paragon-tokens.sh` that detects reference cycles.

### Paragon Core Token Renamed

**Symptom**: Compiled CSS is missing expected `--pgn-*` property after Paragon upgrade.

**Cause**: Upstream Paragon renamed or removed a token that our alias/component tokens reference.

**Recovery**: Compare Paragon core token list before and after upgrade. Update alias/component JSON to reference new token names. The drift detection script (AC-TKN-029) catches this.

### MFE Ignores PARAGON_THEME_URLS

**Symptom**: Specific MFE renders with default Paragon blue/purple palette despite `PARAGON_THEME_URLS` being configured.

**Cause**: MFE's `@edx/frontend-platform` version does not support runtime theme URLs, or the config injection is malformed.

**Recovery**: Check MFE's `package.json` for `@edx/frontend-platform` version. Upgrade to version that supports `PARAGON_THEME_URLS`. Verify config injection by inspecting the MFE's rendered HTML for the config script tag.

### Partial Token Build Failure

**Symptom**: style-dictionary produces output but some tokens are missing.

**Cause**: Malformed JSON in one of the token files (missing comma, unmatched brace).

**Recovery**: style-dictionary reports the parse error with file path and line number. Fix the JSON syntax. The CI gate (AC-TKN-031) prevents merging broken tokens.

### CDN Serves 404 for Theme CSS

**Symptom**: MFEs render without branding. Browser console shows 404 for `brandOverride` URL.

**Cause**: Theme CSS not built into MFE image, or Caddy route not configured.

**Recovery**: Verify Caddy config includes the theme CSS route. Verify the CSS file exists at the expected path in the MFE container. Rebuild MFE image if CSS was not included.

### rgba Values Not Expressible as Tokens

**Symptom**: Some `mereka.scss` overrides use `rgba(26, 22, 35, 0.08)` which cannot be a simple token reference.

**Cause**: rgba values with specific alpha channels are derived values, not primitives.

**Recovery**: Use style-dictionary `modify` transform with `alpha` modifier on the base color token. Example: `{ "value": "{global.color.ink-900}", "modify": [{ "type": "alpha", "amount": 0.08 }] }`. For values that cannot be expressed this way, retain as hardcoded CSS with justification.

## Open Questions

- [ ] Is Paragon v23 (with JSON token support) available in the Paragon version bundled with our current Tutor 21 (Ulmo) MFE images, or do we need to upgrade Paragon first?
- [ ] Does `tutor-contrib-paragon` support Tutor 21, or must we implement token compilation in `mereka_lms.py` directly?
- [ ] Should the compiled theme CSS filename include a content hash for cache busting, or should we rely on Caddy `ETag` / `Last-Modified` headers?
- [ ] Which of the 9 MFEs have `@edx/frontend-platform` versions that support `PARAGON_THEME_URLS`? Do any require upgrades?
- [ ] Should we use the same `tokens.css` provenance tracking system for the JSON token files, or is git history sufficient?
- [ ] What is the maximum acceptable number of retained structural BEM overrides in `mereka.scss` after Phase 3 (target <100 lines, but should we be more aggressive)?
- [ ] Should the JSON token files be committed to this repo or published as an npm package for reuse across other Mereka properties?

---

## Implementation Notes

<!--
Fill this section only when status=completed.
-->
