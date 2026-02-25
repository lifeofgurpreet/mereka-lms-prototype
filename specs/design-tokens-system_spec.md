---
title: "Design Tokens System"
type: "feature_spec"
status: "completed"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-10"
version: "1.0.0"
depends_on:
  - "specs/branding-system_spec.md"
links:
  related_docs:
    - "assets/branding/tokens.css"
    - "assets/branding/tokens.provenance.json"
    - "scripts/branding/update-token-provenance.sh"
    - "scripts/branding/verify-token-drift.sh"
  related_specs:
    - "specs/branding-system_spec.md"
    - "specs/multi-site-domains_spec.md"
    - "specs/cross-cutting-requirements_spec.md"
---

# Human Summary

## What we're building

A design token system that manages the single source of truth for Mereka Academy's visual design language -- colors, typography, spacing, shadows, z-index layers, animation timings, and sizing scales. Tokens are defined as CSS custom properties (`--color-teal`, `--space-4`, `--shadow-lg`) in `assets/branding/tokens.css`, synced from the Figma design system via the upstream `bbbi-mereka-brand-assets` repository. A provenance tracking file (`tokens.provenance.json`) records the exact commit SHA, file SHA256, and sync timestamp to detect drift. The system includes automated verification scripts that ensure runtime SCSS overrides (`infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css`) stay in sync with canonical token definitions, preventing silent design regressions when tokens are updated in Figma.

## Why it matters

Without a design token system, designers and developers work from divergent color palettes and spacing scales. A designer updates the teal brand color in Figma, but the LMS continues using the old hex value hardcoded in SCSS files. Spacing values drift across components (one uses `16px`, another uses `18px` for the same semantic concept). Font family changes require search-and-replace across dozens of files. The token system solves this by establishing `assets/branding/tokens.css` as the canonical reference, with provenance tracking to detect when runtime overrides fall behind. This is not just about aesthetics -- inconsistent spacing breaks responsive layouts, incorrect color mappings violate WCAG contrast requirements, and font mismatches degrade readability.

## Success looks like

- `assets/branding/tokens.css` is the single source of truth for all design values (no hardcoded colors, spacing, or font names in SCSS).
- `verify-token-drift.sh` passes on every CI run, confirming runtime overrides match canonical tokens.
- When a designer updates the Figma design system, the change flow is: Figma → brand-assets repo → `tokens.css` update → provenance refresh → drift verification → SCSS override update.
- The provenance file accurately reflects the latest sync (commit SHA matches upstream, file SHA256 matches content).
- All required token pairs (`--color-teal` → `--mereka-color-teal`) are present and match byte-for-byte.

# Agent Contract

## Scope

This spec covers the design token system for Mereka Academy, including token categories, provenance tracking, drift detection, sync workflow, and verification gates.

## Non-goals

- Automatic token propagation from Figma to production (tokens are synced manually via `update-token-provenance.sh`)
- Multi-brand token switching (the system manages a single Mereka brand)
- Token aliases or semantic layering (tokens are flat, not nested)
- Runtime token hot-reloading (tokens are compiled at build time, not runtime)
- Token documentation generation (Figma is the design documentation source of truth)

## Requirements

### Functional

#### Token Categories (AC-001 to AC-003)

The token system MUST define tokens in the following categories:

**Colors**:
- Primary colors: `--color-black`, `--color-white`, `--color-teal`, `--color-magenta`, `--color-blue`
- Secondary colors: `--color-burgundy`, `--color-pink`, `--color-sky`, `--color-orange`, `--color-gold`, `--color-mint`, `--color-periwinkle`, `--color-forest`
- Semantic colors: `--color-success`, `--color-success-light`, `--color-warning`, `--color-warning-dark`, `--color-error`, `--color-error-light`, `--color-info`, `--color-info-light`
- Gray scale: `--gray-50` through `--gray-950` (11 shades)

**Typography**:
- Font families: `--font-heading` (Lato), `--font-body` (Poppins), `--font-video` (Open Sans)
- Font sizes: `--text-display`, `--text-h1`, `--text-h2`, `--text-h3`, `--text-h4`, `--text-body-lg`, `--text-body`, `--text-body-sm`, `--text-caption`
- Line heights: `--leading-display`, `--leading-heading`, `--leading-body`

**Spacing**:
- Scale: `--space-0` through `--space-24` (14 values using 4px base unit)

**Sizing**:
- Avatars: `--avatar-xs` through `--avatar-2xl` (6 sizes)
- Icons: `--icon-sm` through `--icon-xl` (4 sizes)
- Buttons: `--button-height-default`, `--button-height-large`, `--button-padding-default`, `--button-padding-large`

**Border Radius**:
- Scale: `--radius-none`, `--radius-sm`, `--radius-md`, `--radius-lg`, `--radius-xl`, `--radius-full`

**Shadows**:
- Depth scale: `--shadow-sm`, `--shadow-md`, `--shadow-lg`, `--shadow-xl`

**Z-Index**:
- Stacking layers: `--z-dropdown` (100), `--z-sticky` (200), `--z-fixed` (300), `--z-modal-backdrop` (400), `--z-modal` (500), `--z-popover` (600), `--z-tooltip` (700)

**Animation**:
- Durations: `--duration-75` through `--duration-500` (6 values)
- Easings: `--ease-in`, `--ease-out`, `--ease-in-out`

**Breakpoints** (reference only, not used in CSS):
- Values: `--breakpoint-sm` through `--breakpoint-2xl`

**Container Widths**:
- Values: `--container-sm` through `--container-xl`, `--container-prose`

#### Token File Structure (AC-004)

- The canonical token file MUST be `assets/branding/tokens.css`.
- The file MUST define all tokens within a single `:root` selector.
- The file MUST include a header comment with source URL (`https://www.figma.com/design/jBO2FrTslM4wocrRzwQaPo/mereka.io-Design-System`) and generation date.
- The file MUST group tokens by category with section headers (`/* COLORS - Primary */`, etc.).
- Token names MUST use kebab-case (`--color-teal`, not `--colorTeal` or `--color_teal`).
- Color values MUST be lowercase hex codes (`#237072`, not `#237072` with uppercase letters).

#### Provenance Tracking (AC-005 to AC-007)

- The provenance file MUST be `assets/branding/tokens.provenance.json`.
- The file MUST contain the following fields:
  - `source_repo`: `"https://github.com/Biji-Biji-Initiative/bbbi-mereka-brand-assets"`
  - `source_path`: Path to the token file in the upstream repo (e.g., `"brands/mereka/tokens/tokens.css"`)
  - `source_branch`: Branch name (e.g., `"main"`)
  - `source_commit`: Full 40-character git commit SHA (lowercase)
  - `source_sha256`: SHA256 hash of the token file content (lowercase, 64 characters)
  - `synced_at_utc`: ISO 8601 timestamp (e.g., `"2026-02-10T19:59:25Z"`)
- The `source_commit` field MUST match the HEAD commit of the upstream repository at sync time.
- The `source_sha256` field MUST match the SHA256 hash of `assets/branding/tokens.css` content.
- The `update-token-provenance.sh` script MUST update the provenance file after syncing tokens from upstream.

#### Drift Detection (AC-008 to AC-010)

- The `verify-token-drift.sh` script MUST parse both `tokens.css` and `infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css` to extract `:root` variable definitions.
- The script MUST verify that all required token pairs are present and match:
  - `--color-black` → `--mereka-color-ink-900`
  - `--color-teal` → `--mereka-color-teal`
  - `--color-magenta` → `--mereka-color-magenta`
  - `--color-blue` → `--mereka-color-blue`
  - `--color-sky` → `--mereka-color-sky`
  - `--color-burgundy` → `--mereka-color-danger`
  - `--color-pink` → `--mereka-color-danger-soft`
  - `--color-gold` → `--mereka-color-warning`
  - `--color-forest` → `--mereka-color-success`
  - `--font-heading` → `--mereka-font-heading` (must contain "Lato")
  - `--font-body` → `--mereka-font-body` (must contain "Poppins")
- The script MUST normalize color values (lowercase, strip quotes, whitespace) before comparison.
- The script MUST verify that the SHA256 hash of `tokens.css` matches `tokens.provenance.json["source_sha256"]`.
- The script MUST exit 0 on success and non-zero on failure.
- The script MUST output a list of drift violations to stderr if any are detected.

#### Token Sync Workflow (AC-011)

- The `update-token-provenance.sh` script MUST:
  1. Read the upstream token file from `$BRAND_ASSETS_REPO/$UPSTREAM_TOKEN_PATH` (defaults: `/home/gurpreet/projects/bbbi-mereka-brand-assets/brands/mereka/tokens/tokens.css`)
  2. Compute the current git commit SHA and branch name from the upstream repo
  3. Compute the SHA256 hash of the upstream file
  4. Generate an ISO 8601 UTC timestamp
  5. Update `assets/branding/tokens.provenance.json` with the above values
  6. Optionally copy the upstream file to `assets/branding/tokens.css` if `SYNC_FILE=1` is set
- The script MUST NOT modify `tokens.css` by default (provenance update only).
- The script MUST fail if the upstream repo or file does not exist.

#### Runtime Token Mapping (AC-012)

- The `infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css` file MUST define Open edX-specific token aliases that reference canonical tokens.
- Aliases MUST use the `--mereka-*` prefix to distinguish them from Open edX defaults.
- Aliases MUST NOT duplicate token definitions (they reference canonical tokens via CSS variable inheritance).
- The file MUST NOT contain hardcoded color or spacing values (all values MUST reference `--color-*`, `--space-*`, or other canonical tokens).

### Non-Functional Requirements

#### Performance

- Token parsing in `verify-token-drift.sh` MUST complete in under 5 seconds for the current token file size (~190 lines).
- The provenance update script MUST complete in under 2 seconds.
- CSS custom property lookups MUST have negligible performance impact (browser-native feature).

#### Security

- The token files MUST NOT contain secrets (API keys, tokens, credentials).
- The upstream brand assets repository MUST be treated as a trusted source (no untrusted forks).
- The SHA256 provenance hash prevents tampering (if tokens are modified outside the sync workflow, drift verification will fail).

#### Availability

- If the upstream repository is unavailable, token sync SHOULD be retried manually (no automated fallback).
- If drift verification fails, CI SHOULD block the merge but MUST NOT block local development.

#### Compliance

- Color tokens SHOULD meet WCAG 2.1 AA contrast ratios when used as foreground/background pairs (verified manually in Figma, not automated).
- Font tokens MUST reference web-safe fonts or self-hosted WOFF2 files (no external CDN dependencies like Google Fonts).

## Acceptance Criteria

### Token Categories

- [ ] AC-001: Given `assets/branding/tokens.css`, when parsed, then all primary color tokens (`--color-black`, `--color-white`, `--color-teal`, `--color-magenta`, `--color-blue`) are defined with valid hex values.
- [ ] AC-002: Given `assets/branding/tokens.css`, when parsed, then all typography tokens (`--font-heading`, `--font-body`, `--text-h1`, etc.) are defined with valid CSS values.
- [ ] AC-003: Given `assets/branding/tokens.css`, when parsed, then all spacing tokens (`--space-0` through `--space-24`) are defined with pixel values following the 4px base unit scale.

### Token File Structure

- [ ] AC-004: Given `assets/branding/tokens.css`, when inspected, then all tokens are defined within a single `:root` selector, use kebab-case naming, and include section header comments grouping tokens by category.

### Provenance Tracking

- [ ] AC-005: Given `assets/branding/tokens.provenance.json`, when loaded, then all required fields (`source_repo`, `source_path`, `source_branch`, `source_commit`, `source_sha256`, `synced_at_utc`) are present and non-empty.
- [ ] AC-006: Given `assets/branding/tokens.provenance.json["source_commit"]`, when validated, then it matches the 40-character lowercase git SHA pattern `[0-9a-f]{40}`.
- [ ] AC-007: Given `assets/branding/tokens.provenance.json["source_sha256"]`, when validated, then it matches the 64-character lowercase SHA256 pattern `[0-9a-f]{64}`.

### Drift Detection

- [ ] AC-008: Given `verify-token-drift.sh` is run, when `tokens.css` and `mereka-overrides.css` are in sync, then the script exits 0 with message "✓ Token drift + provenance checks passed."
- [ ] AC-009: Given `tokens.css` defines `--color-teal: #237072` and `mereka-overrides.css` defines `--mereka-color-teal: #FFFFFF`, when `verify-token-drift.sh` is run, then the script exits non-zero with error "drift: --color-teal=#237072 != --mereka-color-teal=#FFFFFF".
- [ ] AC-010: Given `tokens.css` content is modified but `tokens.provenance.json["source_sha256"]` is stale, when `verify-token-drift.sh` is run, then the script exits non-zero with error "tokens.css sha256 drift: provenance=<old> actual=<new>".

### Token Sync Workflow

- [ ] AC-011: Given the upstream repository at `/home/gurpreet/projects/bbbi-mereka-brand-assets` with updated tokens, when `SYNC_FILE=1 ./scripts/branding/update-token-provenance.sh` is run, then `assets/branding/tokens.css` is overwritten with the upstream file and `tokens.provenance.json` is updated with the new commit SHA and file hash.

### Runtime Token Mapping

- [ ] AC-012: Given `infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css`, when parsed, then it contains `--mereka-color-teal` defined as a value (direct assignment or CSS variable reference), and the value matches `--color-teal` from `tokens.css`.

## Edge Cases

### Provenance SHA Mismatch After Manual Edit

**Symptom**: `verify-token-drift.sh` fails with SHA256 mismatch even though tokens appear correct.

**Cause**: Tokens were edited manually in `tokens.css` without updating the provenance file.

**Recovery**:
```bash
# Re-sync from upstream to reset provenance
cd /path/to/bbbi-mereka-brand-assets
git pull origin main
cd /path/to/mereka-lms
SYNC_FILE=1 ./scripts/branding/update-token-provenance.sh

# OR manually update provenance if the edit was intentional
./scripts/branding/update-token-provenance.sh
# (This updates the SHA256 hash to match current tokens.css content)
```

### Upstream Repository Moved or Renamed

**Symptom**: `update-token-provenance.sh` fails with "Upstream repo not found".

**Cause**: The `BRAND_ASSETS_REPO` path no longer points to a valid git repository.

**Recovery**:
```bash
# Update the path
export BRAND_ASSETS_REPO=/new/path/to/bbbi-mereka-brand-assets
./scripts/branding/update-token-provenance.sh

# OR update the default in the script
vim scripts/branding/update-token-provenance.sh
# Change: UPSTREAM_REPO="${BRAND_ASSETS_REPO:-/new/path}"
```

### Font Family Substring Match Failure

**Symptom**: `verify-token-drift.sh` fails with "missing 'Lato' (got: 'Lato, sans-serif')".

**Cause**: The verification uses substring matching (`if "lato" not in value.lower()`), which should pass for `"Lato, sans-serif"`. This indicates a bug in the verification logic.

**Recovery**: This should not happen with the current implementation. If it does, file a bug with the exact token values.

### Token Drift in Production Without CI Failure

**Symptom**: Production uses outdated tokens, but CI passed.

**Cause**: `verify-token-drift.sh` is not included in the CI pipeline.

**Recovery**:
```bash
# Add to CI workflow (e.g., .github/workflows/verify-branding.yml)
- name: Verify Token Drift
  run: ./scripts/branding/verify-token-drift.sh
```

### Missing Token in Overrides

**Symptom**: `verify-token-drift.sh` fails with "missing --mereka-color-teal in overrides.css".

**Cause**: A new token was added to `tokens.css` but the corresponding override was not added to `mereka-overrides.css`.

**Recovery**:
```bash
# Add the missing override
vim infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css
# Add: --mereka-color-teal: var(--color-teal);

# Re-verify
./scripts/branding/verify-token-drift.sh
```

### Whitespace Normalization False Positive

**Symptom**: `verify-token-drift.sh` reports drift for `--color-teal: #237072` vs `--mereka-color-teal: #237072` (visually identical).

**Cause**: The verification script uses `re.sub(r"\s+", " ", value.strip())` to normalize whitespace, which should catch this. If it doesn't, there may be non-visible characters (tabs, zero-width spaces).

**Recovery**:
```bash
# Inspect the raw bytes
hexdump -C assets/branding/tokens.css | grep "color-teal"
hexdump -C infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css | grep "mereka-color-teal"
# Look for 0x09 (tab), 0x0D (CR), or other unexpected bytes
```

## Observability

### Logs

- The `update-token-provenance.sh` script MUST log:
  - Upstream repository path and current commit
  - SHA256 hash of the upstream file
  - Whether the file was synced (`SYNC_FILE=1`) or skipped
  - Path to the updated provenance file
- The `verify-token-drift.sh` script MUST log:
  - Number of tokens parsed from each file
  - List of missing or mismatched tokens
  - Provenance validation results (SHA256 match/mismatch)

### Metrics

- CI SHOULD track the number of token drift failures over time (as a proxy for design system stability).
- Token sync frequency SHOULD be monitored (manual process, no automated metrics).

### Alerts

- CI SHOULD fail the build if `verify-token-drift.sh` exits non-zero (blocking merge).
- An alert SHOULD fire if tokens have not been synced in over 90 days (stale design system).

### Dashboards

- A dashboard panel SHOULD display:
  - Last token sync timestamp (from `tokens.provenance.json["synced_at_utc"]`)
  - Current token count by category
  - Drift verification status (pass/fail)

## Rollout & Rollback

### Syncing New Tokens from Figma

```bash
# 1. Designer updates Figma design system
# 2. Designer exports tokens to bbbi-mereka-brand-assets repo
cd /home/gurpreet/projects/bbbi-mereka-brand-assets
git pull origin main

# 3. Sync tokens to mereka-lms
cd /home/gurpreet/projects/k8s/mereka-lms
SYNC_FILE=1 ./scripts/branding/update-token-provenance.sh

# 4. Verify drift
./scripts/branding/verify-token-drift.sh

# 5. Update overrides if needed
vim infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css
# Add/update --mereka-* aliases for new tokens

# 6. Re-verify
./scripts/branding/verify-token-drift.sh

# 7. Commit and push
git add assets/branding/tokens.css assets/branding/tokens.provenance.json
git add infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css
git commit -m "feat(branding): sync design tokens from Figma (commit <SHA>)"
git push
```

### Rolling Back a Token Change

```bash
# 1. Revert tokens.css to previous version
git checkout HEAD~1 -- assets/branding/tokens.css

# 2. Update provenance to match reverted content
./scripts/branding/update-token-provenance.sh

# 3. Verify
./scripts/branding/verify-token-drift.sh

# 4. Commit
git commit -m "revert(branding): roll back design tokens to <previous commit>"
git push
```

### Adding a New Token Category

```bash
# 1. Add tokens to tokens.css
vim assets/branding/tokens.css
# Add new category section (e.g., /* ANIMATIONS - Transitions */)

# 2. Update provenance
./scripts/branding/update-token-provenance.sh

# 3. Add overrides if needed
vim infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css

# 4. Verify
./scripts/branding/verify-token-drift.sh

# 5. Update verification script if required pairs changed
vim scripts/branding/verify-token-drift.sh
# Add new pairs to required_pairs list
```

### Emergency: Provenance Lost or Corrupted

```bash
# 1. Restore from git history
git checkout HEAD~1 -- assets/branding/tokens.provenance.json

# OR regenerate from upstream
cd /home/gurpreet/projects/bbbi-mereka-brand-assets
git log -1 --format="%H" -- brands/mereka/tokens/tokens.css
# Note the commit SHA

cd /home/gurpreet/projects/k8s/mereka-lms
# Manually edit tokens.provenance.json with the correct commit SHA and file hash
./scripts/branding/verify-token-drift.sh
```

## Verification

```bash
# 1. Token categories are complete
grep -oP '^\s*--[a-z-]+:' assets/branding/tokens.css | wc -l
# MUST be >= 80 (current count is ~100+ tokens)

# 2. Provenance fields are valid
jq -r '.source_commit' assets/branding/tokens.provenance.json | grep -E '^[0-9a-f]{40}$'
# MUST exit 0 (40-char SHA)

jq -r '.source_sha256' assets/branding/tokens.provenance.json | grep -E '^[0-9a-f]{64}$'
# MUST exit 0 (64-char SHA256)

# 3. SHA256 matches content
sha256sum assets/branding/tokens.css | awk '{print $1}'
# MUST match tokens.provenance.json["source_sha256"]

# 4. Drift verification passes
./scripts/branding/verify-token-drift.sh
# MUST exit 0 with "✓ Token drift + provenance checks passed."

# 5. Required token pairs exist
./scripts/branding/verify-token-drift.sh 2>&1 | grep -i "drift:"
# MUST return empty (no drift violations)

# 6. Font family mappings are correct
grep -oP '(?<=--font-heading:\s).*' assets/branding/tokens.css
# MUST contain "Lato"

grep -oP '(?<=--font-body:\s).*' assets/branding/tokens.css
# MUST contain "Poppins"

# 7. Overrides reference canonical tokens
grep -E '^[^/]*--mereka-' infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css | head -5
# SHOULD show --mereka-* variables (not hardcoded values)

# 8. No hardcoded colors in overrides
grep -i '#[0-9a-f]\{6\}' infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css | grep -v '/\*' | grep -v 'color-'
# SHOULD return empty (all colors use tokens)
```

## Open Questions

1. Should token sync be automated via CI/CD (e.g., GitHub Actions cron job that polls the upstream repo for changes)?
2. Should we version tokens (e.g., `tokens-v2.css`) to support A/B testing of design changes?
3. Should we generate TypeScript/JavaScript token exports for MFE usage (e.g., `tokens.ts` with `export const colorTeal = "#237072"`)?
4. Should we add semantic token layers (e.g., `--semantic-primary` → `var(--color-teal)`) to decouple usage from implementation?
5. Should we enforce WCAG contrast ratio verification in the drift script (requires color pair testing, not just individual token validation)?
6. Should we extract provenance tracking to a separate JSON schema with validation?
7. Should we support multiple token themes (light mode, dark mode) via separate token files?
8. How should we handle token deprecation (e.g., renaming `--color-teal` to `--color-primary-500` while maintaining backward compatibility)?
