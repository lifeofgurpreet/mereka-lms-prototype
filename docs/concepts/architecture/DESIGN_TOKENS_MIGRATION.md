# Design Tokens Migration

**Status**: Phase 3 Complete (CI enforcement active)
**Last updated**: 2026-02-25

---

## Overview

This document describes the end-to-end migration of Mereka Academy theming to a single-source design token pipeline. All color, typography, spacing, and effect values flow from one canonical file to all consumers.

---

## Current State: 3-Layer Architecture

```
Layer 1 (canonical)                 Layer 2 (SCSS bridge)            Layer 3 (runtime CSS)
assets/branding/                    infrastructure/tutor/themes/     infrastructure/tutor/themes/
  tokens.css                          mereka/scss/                     mereka/*/static/css/
  (Figma export)                        _tokens.scss                     mereka-overrides.css
                                                                        mereka-design-tokens.css
```

### What each layer does

**Layer 1 — `assets/branding/tokens.css`**

The canonical source. Contains 110+ CSS custom properties inside a single `:root` block, grouped by category (colors, typography, spacing, radius, shadows, z-index, animation, breakpoints, containers). This file is exported from the Figma design system via the upstream `bbbi-mereka-brand-assets` repository. It is the only file that may contain raw hex color values.

Provenance is tracked in `assets/branding/tokens.provenance.json` (source repo URL, commit SHA, file SHA256, sync timestamp).

**Layer 2 — `infrastructure/tutor/themes/mereka/scss/_tokens.scss`**

The SCSS bridge. Contains:
- SCSS variable declarations (`$color-teal: #237072;`) — 24 variables total
- A `:root { --mereka-*, --pgn-* }` block — 37 CSS custom properties
- Bootstrap variable overrides (`$primary`, `$font-family-sans-serif`, etc.) — preserved, not generated
- Global CSS rules (`body {}`, `h1-h6 {}`, `a {}`, `.btn-primary {}`, `.card {}`) — preserved, not generated

The SCSS vars section and `:root` block are enclosed in `// BEGIN GENERATED` / `// END GENERATED` markers. Everything after `// END GENERATED` is preserved by the generator.

This file is compiled by Tutor's SASS pipeline (`npm run compile-sass`) when building LMS/CMS themes. It is also imported by MFE builds via `mereka.scss`.

**Layer 3 — `mereka-overrides.css` (common, lms, cms)**

Runtime CSS loaded via `head-extra.html` on every LMS and Studio page. Provides:
- A full `:root` block with `--mereka-*` (Mereka namespace), `--pgn-*` (Paragon bridge), and `--color-*` (design-system aliases)
- All post-`:root` CSS rules — component overrides for Open edX LMS/Studio HTML

The `:root` block is enclosed in `/* BEGIN GENERATED */` / `/* END GENERATED */` markers. All post-`:root` CSS rules are preserved by the generator.

`mereka-design-tokens.css` (under `common/static/css/`) is a verbatim copy of `tokens.css` regenerated wholesale — no hand-written sections.

---

## Token Namespace

### Layer 1 to Layer 2 (SCSS Variables)

| Layer 1 (`tokens.css`) | Layer 2 (`$scss-var`) | Rule |
|------------------------|------------------------|------|
| `--color-teal` | `$color-teal` | Strip `--`, add `$` |
| `--color-magenta` | `$color-magenta` | Strip `--`, add `$` |
| `--color-blue` | `$color-blue` | Strip `--`, add `$` |
| `--color-sky` | `$color-sky` | Strip `--`, add `$` |
| `--color-forest` | `$color-forest` | Strip `--`, add `$` |
| `--color-gold` | `$color-gold` | Strip `--`, add `$` |
| `--color-burgundy` | `$color-burgundy` | Strip `--`, add `$` |
| `--color-pink` | `$color-pink` | Strip `--`, add `$` |

Additional SCSS vars not in `tokens.css` (Mereka-specific ink and neutral scale): `$color-ink-{900,700,500,300}`, `$color-neutral-{100,75}`, `$color-border`, `$color-border-strong`.

### Layer 1 to Layer 2 (CSS Custom Properties)

| Layer 1 (`tokens.css`) | Layer 2 (`--mereka-*`) | Note |
|------------------------|------------------------|------|
| `--color-teal` | `--mereka-color-teal` | Namespace prefix |
| `--color-magenta` | `--mereka-color-magenta` | Namespace prefix |
| `--color-blue` | `--mereka-color-blue` | Namespace prefix |
| `--color-sky` | `--mereka-color-sky` | Namespace prefix |
| `--color-forest` | `--mereka-color-success` | Semantic alias |
| `--color-gold` | `--mereka-color-warning` | Semantic alias |
| `--color-burgundy` | `--mereka-color-danger` | Semantic alias |
| `--color-pink` | `--mereka-color-danger-soft` | Semantic alias |
| `--color-black` | `--mereka-color-ink-900` | Semantic rename |

### Layer 2 to Paragon Bridge (`--pgn-*`)

| `--mereka-*` | `--pgn-*` |
|--------------|-----------|
| `--mereka-color-magenta` | `--pgn-color-primary-base` |
| `--mereka-color-teal` | `--pgn-color-secondary-base` |
| `--mereka-color-success` | `--pgn-color-success-base` |
| `--mereka-color-info` | `--pgn-color-info-base` |
| `--mereka-color-warning` | `--pgn-color-warning-base` |
| `--mereka-color-danger` | `--pgn-color-danger-base` |
| `--mereka-color-surface-primary` | `--pgn-body-bg` |
| `--mereka-color-ink-900` | `--pgn-body-color` |
| `--mereka-color-info` | `--pgn-link-color` |
| `--mereka-color-teal` | `--pgn-link-hover-color` |
| `--mereka-font-body` | `--pgn-typography-font-family-sans-serif` |
| `--mereka-font-heading` | `--pgn-typography-headings-font-family` |
| `--mereka-color-border` | `--pgn-border-color` |

---

## Target State: Single-Source Pipeline (Achieved)

```
assets/branding/tokens.css   (Figma export — ONLY file with raw hex values)
         |
         | generate-tokens-from-canonical.sh
         |
         +---> _tokens.scss          (SCSS vars + :root block — GENERATED)
         |      Bootstrap overrides  (PRESERVED)
         |      CSS rules            (PRESERVED)
         |
         +---> mereka-design-tokens.css   (verbatim copy — GENERATED)
         |
         +---> common/mereka-overrides.css  (:root block — GENERATED)
         |      post-:root CSS rules        (PRESERVED)
         |
         +---> lms/mereka-overrides.css    (:root block — GENERATED)
         |      post-:root CSS rules        (PRESERVED)
         |
         +---> cms/mereka-overrides.css    (:root block — GENERATED)
                post-:root CSS rules        (PRESERVED)
```

**Principle**: `tokens.css` is the only file that contains raw hex values. All downstream files contain either generated blocks (bounded by markers) or references via CSS `var()`.

---

## MFE Token Consumption

### How MFEs Receive Tokens

MFEs (authn, account, learning, learner-dashboard, discussions, etc.) receive tokens through two mechanisms:

**Build-time (SCSS compilation)**

`infrastructure/tutor/themes/mereka/mfe/mereka.scss` imports the `_tokens.scss` bridge via:

```scss
$mereka-font-path: "../fonts";
@import "./scss/tokens";
@import "./scss/base";
```

The split `./scss/tokens` + `./scss/base` imports resolve through the Indigo theme system. This makes all SCSS variables (`$color-teal`, `$mereka-body-font`) and CSS custom properties (`--mereka-*`, `--pgn-*`) available during SCSS compilation.

The Tutor plugin (`infrastructure/tutor/plugins/mereka_lms.py`) injects this import into every MFE build via the `mfe-env-config-buildtime-imports` patch:

```javascript
// Import Mereka theme SCSS
import './mereka/mereka.scss';
```

This runs at build time — the SCSS is compiled into the MFE's CSS bundle by webpack.

**Runtime (CSS custom properties)**

The compiled CSS bundle includes the `:root { --mereka-*, --pgn-* }` block from `_tokens.scss`. These CSS custom properties are then available at runtime in the browser. `mereka.scss` also adds MFE-specific runtime tokens (`--mereka-mfe-gradient`, `--mereka-mfe-card-shadow`, etc.) in its own `:root` block.

### MFE Token Reference Pattern

MFEs use tokens via CSS custom properties in `mereka.scss`:

```scss
/* Uses --mereka-* tokens defined in _tokens.scss */
.navbar .navbar-brand {
  font-family: var(--mereka-font-heading);
  color: var(--mereka-color-ink-900);
}

.pgn__form-control:focus {
  border-color: var(--mereka-color-teal);
}
```

The Paragon bridge tokens (`--pgn-color-primary-base: var(--mereka-color-magenta)`) mean that Paragon's own internal CSS (which uses `--pgn-*`) automatically picks up the Mereka brand colors without any additional overrides.

---

## LMS/CMS Token Consumption

### How LMS/CMS Receive Tokens

**Build-time (SASS compilation)**

Tutor compiles `_tokens.scss` during theme compilation:

```bash
npm run compile-sass -- --skip-default --theme-dir /openedx/themes --theme mereka
```

This produces compiled CSS that bakes in the SCSS variable values (hex literals) from `_tokens.scss`.

**Runtime (CSS custom properties)**

`mereka-overrides.css` is served as a static asset and loaded via `head-extra.html` on every LMS and Studio page. This injects the `:root { --mereka-*, --pgn-* }` block, making CSS custom properties available to all page CSS regardless of what the SASS compilation produced.

This means: even if `collectstatic` or SASS compilation produces stale CSS, the runtime overrides ensure the correct brand tokens are active.

### Template Injection

`head-extra.html` (under `infrastructure/tutor/themes/mereka/lms/templates/`) loads `mereka-overrides.css` via a `<link>` tag. The Tutor build system copies theme templates and static assets into the running Open edX container.

---

## Migration Phases

### Phase 1 — Contract + Drift Detection (COMPLETE 2026-02-17)

Deliverables:
- `docs/concepts/architecture/TOKEN_GENERATION_PIPELINE.md` — pipeline contract
- `docs/concepts/architecture/TOKEN_REFERENCE_INTEGRITY.md` — reference integrity rules
- `scripts/branding/verify-token-drift.sh` — drift detection (9 color pairs)
- `scripts/qa/verify-token-generation-pipeline.sh` — comprehensive drift check
- CI gate: `design-token-validation` job (syntax checks)

### Phase 2 — Generator Script (COMPLETE 2026-02-25)

Deliverables:
- `scripts/branding/generate-tokens-from-canonical.sh` — idempotent generator
  - `--check` mode exits 1 if any layer is out of sync (used by CI)
  - Resolves the confirmed teal and ink-500 drift present before this phase
- All 5 output files regenerated and aligned with `tokens.css`
- Marker-based preservation: generated blocks are bounded so manual sections survive re-runs

### Phase 3 — CI Enforcement (COMPLETE 2026-02-25)

Deliverables:
- `design-token-validation` CI job executes `generate-tokens-from-canonical.sh --check`
- Build fails if any generated token layer drifts from `tokens.css`
- `scripts/branding/validate-token-consumers.sh` — consumer-level validation
- `scripts/qa/verify-design-tokens-migration.sh` — migration completeness check

---

## Generator Script Reference

**File**: `scripts/branding/generate-tokens-from-canonical.sh`

**Usage**:

```bash
# Regenerate all consumer files from tokens.css
./scripts/branding/generate-tokens-from-canonical.sh

# Check mode (CI): exit 1 if any file is out of sync, without modifying files
./scripts/branding/generate-tokens-from-canonical.sh --check
```

**Input**: `assets/branding/tokens.css`

**Outputs**:
1. `infrastructure/tutor/themes/mereka/scss/_tokens.scss` — SCSS bridge (generated block replaced, preserved block kept)
2. `infrastructure/tutor/themes/mereka/common/static/css/mereka-design-tokens.css` — full regeneration
3. `infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css` — `:root` block replaced
4. `infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css` — `:root` block replaced
5. `infrastructure/tutor/themes/mereka/cms/static/css/mereka-overrides.css` — `:root` block replaced

**Preservation strategy**:

| File | Generated (replaced) | Preserved |
|------|----------------------|-----------|
| `_tokens.scss` | SCSS vars + `:root` block (between `// BEGIN GENERATED` / `// END GENERATED`) | Bootstrap overrides + CSS rules |
| `mereka-design-tokens.css` | Entire file | Nothing (full regeneration) |
| `mereka-overrides.css` (×3) | `:root { }` block (between `/* BEGIN GENERATED */` / `/* END GENERATED */` inside `:root`) | Header comment + all post-`:root` CSS |

---

## Deprecation

### Old Theming Paths to Remove

The following patterns represent the pre-migration state and should be eliminated when encountered:

1. **Hardcoded hex values in `_tokens.scss` outside the generated block**: All color hex values in the generated section must come from `tokens.css`. The only hex values permitted outside the generated block are in CSS rules (e.g., `rgba(26, 22, 35, 0.08)` in `.card`), where they are structural, not brand values.

2. **Hardcoded hex values in `mereka-overrides.css` inside the `:root` block**: The `:root` block is entirely generated. Any hex values inside it must match `tokens.css`.

3. **Duplicate color definitions across layers**: Token values must not be defined independently in multiple files. Only `tokens.css` holds raw values; all other files reference generated blocks or use `var()`.

4. **Manual edits inside `// BEGIN GENERATED` / `// END GENERATED` markers**: These blocks are overwritten on every generator run. Edits must be made to the generator script or to `tokens.css`.

### What Remains Manual

- `tokens.css` itself (Figma export, updated quarterly or on brand changes)
- Bootstrap overrides in `_tokens.scss` (after `// END GENERATED`)
- Global CSS rules in `_tokens.scss` (`body {}`, `h1-h6 {}`, `a {}`, `.card {}`)
- All post-`:root` CSS rules in `mereka-overrides.css` files (component overrides)
- MFE-specific `:root` block in `mereka.scss` (`--mereka-mfe-*` tokens)

---

## CI Enforcement

### design-token-validation Job

The `design-token-validation` job in `.github/workflows/ci.yml` runs:

```yaml
- name: Verify generated token layers are in sync
  run: ./scripts/branding/generate-tokens-from-canonical.sh --check

- name: Validate token consumers reference canonical values
  run: ./scripts/branding/validate-token-consumers.sh

- name: Verify design tokens migration completeness
  run: ./scripts/qa/verify-design-tokens-migration.sh
```

**Exit criteria**: CI fails if any check exits non-zero.

### token-drift Job

A separate `token-drift` job runs `scripts/qa/verify-token-drift.sh`, which checks 9 canonical color pairs between `tokens.css` and `mereka-overrides.css`.

### What CI Cannot Detect

- Drift in MFE-specific `--mereka-mfe-*` tokens (not derived from `tokens.css`)
- Hardcoded values in post-`:root` CSS rules (structural, not brand values)
- Figma design system changes not yet synced to `tokens.css`

---

## Developer Workflow: Updating Tokens

When the Figma design system changes and `tokens.css` is updated:

```bash
# 1. Update tokens.css (from Figma export or brand-assets sync)
SYNC_FILE=1 ./scripts/branding/update-token-provenance.sh

# 2. Regenerate all consumer files
./scripts/branding/generate-tokens-from-canonical.sh

# 3. Validate consumers are consistent
./scripts/branding/validate-token-consumers.sh

# 4. Run full migration check
./scripts/qa/verify-design-tokens-migration.sh

# 5. Commit all changed files
git add assets/branding/tokens.css assets/branding/tokens.provenance.json
git add infrastructure/tutor/themes/mereka/scss/_tokens.scss
git add infrastructure/tutor/themes/mereka/common/static/css/
git add infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css
git add infrastructure/tutor/themes/mereka/cms/static/css/mereka-overrides.css
git commit -m "feat(branding): sync design tokens from Figma (<short-sha>)"
```

---

## Related Documentation

- `docs/concepts/architecture/TOKEN_GENERATION_PIPELINE.md` — pipeline contract and phase history
- `docs/concepts/architecture/TOKEN_REFERENCE_INTEGRITY.md` — reference integrity rules and token inventory
- `docs/concepts/architecture/WCAG_CONTRAST_POLICY_V2.md` — WCAG AA contrast compliance for token values
- `specs/design-tokens-system_spec.md` — acceptance criteria (AC-001..AC-012)
- `assets/branding/tokens.provenance.json` — upstream sync metadata
