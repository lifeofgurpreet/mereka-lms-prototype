# Issue #218 Implementation Packet - Theming Generated Artifact Governance

Issue: https://github.com/Biji-Biji-Initiative/mereka-lms/issues/218  
Parent: https://github.com/Biji-Biji-Initiative/mereka-lms/issues/214  
Status: audit-to-implementation handoff

## Goal

Reduce theming drift and maintenance debt by explicitly governing generated artifacts in the hybrid tokens+SCSS transition state.

## Confirmed Risks

- Theming currently spans:
  - canonical tokens (`assets/branding/tokens.css`)
  - SCSS bridge (`themes/mereka/scss/_tokens.scss`)
  - generated MFE runtime theme files (`themes/mereka/mfe/theme/*.min.css`)
- Generated `.min.css` files are tracked in git without explicit governance policy.
- Multiple scripts can update token layers (`generate-tokens-from-canonical.sh`, `build-tokens.sh`), increasing drift surface.

## Transition Reality

SCSS bridge remains necessary in near term for backward compatibility with legacy Open edX theming surfaces.  
The packet optimizes governance without forcing premature migration.

---

## PR Strategy (recommended 2 PRs)

1. `PR-218-A` artifact policy + determinism gate
2. `PR-218-B` optional move to untracked runtime artifacts (if approved)

---

## PR-218-A (Policy + Determinism)

### File Changes

1. Add policy doc:
- `docs/reference/architecture/THEMING_GENERATED_ARTIFACT_CONTRACT.md`
2. Add determinism verifier:
- `scripts/qa/verify-theme-consistency.sh`
3. Wire to CI:
   - `.github/workflows/ci.yml`
4. Optional doc cross-link:
   - `docs/reference/architecture/TOKEN_GENERATION_PIPELINE.md`

### Policy Requirements

Table must define for each artifact:
- file path
- source of truth
- generation command
- owner script
- tracking policy (`tracked` or `generated-at-build`)
- failure mode if stale.

### Determinism Verifier Contract

- Run:
  - `./scripts/branding/generate-tokens-from-canonical.sh`
  - `./scripts/branding/build-tokens.sh`
- Fail if git diff appears in files marked `tracked`.
- Print exact commands to reconcile.

### Acceptance Criteria

- `AC-218-A1`: all generated theming artifacts are explicitly classified.
- `AC-218-A2`: CI fails on drift for tracked generated artifacts.
- `AC-218-A3`: SCSS bridge retention is documented as transitional compatibility requirement.

### Verification Commands

```bash
./scripts/branding/generate-tokens-from-canonical.sh --check
./scripts/qa/verify-token-drift.sh
./scripts/qa/verify-theme-consistency.sh
```

---

## PR-218-B (Optional Policy Shift to Untracked Runtime CSS)

### Preconditions

- Only execute after `PR-218-A` is stable for at least one release cycle.
- Confirm MFE build pipeline can reliably generate runtime theme files on every build.

### File Changes (if approved)

1. Update `.gitignore` for runtime theme outputs (if moving untracked).
2. Ensure build scripts generate required files before image packaging.
3. Remove tracked runtime outputs from repo in one dedicated PR.

### Acceptance Criteria

- `AC-218-B1`: MFE image build fails fast if runtime theme files are absent after generation step.
- `AC-218-B2`: runtime `PARAGON_THEME_URLS` assets remain available in deployed image.

### Verification Commands

```bash
./scripts/qa/verify-mfe-image-branding.sh <image_ref>
./scripts/qa/verify-paragon-runtime.sh --require-runtime --require-slot-markers
```

---

## Rollback Plan

1. If untracked policy causes runtime misses:
   - immediately revert to tracked generated outputs (`PR-218-A` baseline).
2. Keep deterministic check regardless of tracked/untracked policy.
3. Do not rollback by bypassing token generation validation.

## Implementation Notes

- Keep this issue separate from visual branding changes.
- Do not mix this with multi-brand package sync refactors (`#217`) in same PR.
