---
spec: design-tokens-system_spec.md
tier: 2
status: draft
estimated_effort: "1-2 days (documentation and verification hardening; implementation already complete)"
owner: engineering
last_updated: "2026-02-10"
---

# Implementation Plan: Design Tokens System

**Source Spec**: `specs/design-tokens-system_spec.md`
**Tier**: 2 (Core Infrastructure - dependent on branding-system)
**Depends On**: Tier 0 (repository-structure, secrets-management, tutor-configuration, cross-cutting-requirements), Tier 1 (branding-system)
**Blocks**: multi-tenancy-architecture (tenant-specific token customization)

## Summary

The design tokens system is **fully implemented**. All token categories exist in `assets/branding/tokens.css`, provenance tracking is operational via `tokens.provenance.json`, drift detection works via `verify-token-drift.sh`, and sync workflow is automated via `update-token-provenance.sh`. Runtime token mapping exists in `mereka-overrides.css`.

This plan focuses on **documentation, verification hardening, and closing minor gaps** identified by the spec. The work is retrospective -- documenting what exists, ensuring all verification gates are comprehensive, and hardening CI integration.

## Prerequisites

1. Branding system spec complete (`specs/branding-system_spec.md`)
2. `assets/branding/tokens.css` exists with canonical design tokens
3. `assets/branding/tokens.provenance.json` exists with upstream sync metadata
4. `scripts/branding/verify-token-drift.sh` functional
5. `scripts/branding/update-token-provenance.sh` functional
6. Upstream brand assets repository cloned at `/home/gurpreet/projects/bbbi-mereka-brand-assets`

## Task Breakdown

### Build

- [ ] **[S]** Audit token categories against spec requirements (AC-001 to AC-003) | Depends: None
  - Verify `tokens.css` contains all required color tokens (primary, secondary, semantic, gray scale)
  - Verify typography tokens (font families, sizes, line heights)
  - Verify spacing tokens (--space-0 through --space-24 following 4px scale)
  - Verify sizing, border-radius, shadows, z-index, animation, container tokens
  - **Done**: Manual audit confirms all categories present; `grep -oP '^\s*--[a-z-]+:' assets/branding/tokens.css | wc -l` returns >= 80 tokens

- [ ] **[S]** Verify token file structure matches spec (AC-004) | Depends: None
  - Confirm all tokens within single `:root` selector
  - Confirm kebab-case naming (`--color-teal`, not `--colorTeal`)
  - Confirm section header comments group tokens by category
  - Confirm color values are lowercase hex codes
  - **Done**: Visual inspection of `tokens.css` structure matches spec requirements

- [ ] **[S]** Verify provenance file structure and fields (AC-005 to AC-007) | Depends: None
  - Confirm `tokens.provenance.json` contains all required fields
  - Verify `source_commit` matches 40-char SHA pattern
  - Verify `source_sha256` matches 64-char SHA256 pattern
  - **Done**: `jq -r '.source_commit' assets/branding/tokens.provenance.json | grep -E '^[0-9a-f]{40}$'` exits 0

- [ ] **[S]** Create comprehensive token validation script (AC-001 to AC-004) | Depends: Build tasks above
  - Create `scripts/branding/verify-design-tokens.sh` (phantom script referenced in testmap)
  - Validates all token categories are present (colors, typography, spacing, etc.)
  - Validates token value formats (hex colors, pixel values, font family strings)
  - Validates spacing scale follows 4px increments
  - Validates file structure (single :root selector, kebab-case naming)
  - **Done**: Script exits 0 when all token categories and formats are valid

### Test

- [ ] **[S]** Run drift detection script and document baseline (AC-008 to AC-010) | Depends: Build tasks
  - Execute `./scripts/branding/verify-token-drift.sh`
  - Confirm it exits 0 with message "✓ Token drift + provenance checks passed."
  - Document required token pairs it validates
  - **Done**: Script passes; all required pairs (--color-teal → --mereka-color-teal, etc.) verified

- [ ] **[S]** Verify provenance SHA256 validation (AC-010) | Depends: Build tasks
  - Manually modify `tokens.css` content
  - Run `verify-token-drift.sh` and confirm it detects SHA256 mismatch
  - Restore `tokens.css` and re-run to confirm pass
  - **Done**: SHA256 drift detection works correctly

- [ ] **[S]** Test token sync workflow (AC-011) | Depends: Build tasks
  - Run `SYNC_FILE=1 ./scripts/branding/update-token-provenance.sh`
  - Verify `tokens.css` is updated with upstream content
  - Verify `tokens.provenance.json` is updated with new commit SHA and file hash
  - **Done**: Sync workflow completes successfully; provenance updated

- [ ] **[S]** Verify runtime token mapping (AC-012) | Depends: Build tasks
  - Run `verify-token-drift.sh` to check required token pairs
  - Confirm `mereka-overrides.css` contains `--mereka-color-teal` with value matching `--color-teal`
  - Confirm all required pairs from spec are present and match
  - **Done**: All token pairs verified; no drift detected

- [ ] **[S]** Test negative cases (AC-009) | Depends: Test tasks above
  - Temporarily modify `--color-teal` in `tokens.css` to a different value
  - Run `verify-token-drift.sh` and confirm it exits non-zero with drift error
  - Restore `tokens.css` and verify pass
  - **Done**: Negative test confirms drift detection works

### Observability

- [ ] **[S]** Verify drift detection script logs clearly (Req: OBS-logs) | Depends: Test tasks
  - Run `verify-token-drift.sh` and confirm it outputs:
    - Number of tokens parsed from each file
    - List of missing or mismatched tokens (if any)
    - Provenance validation results
  - **Done**: Log output is clear and actionable

- [ ] **[S]** Document token sync frequency monitoring (Req: OBS-metrics) | Depends: None
  - Add note to operating model doc: manual sync process, no automated metrics
  - Recommend alert if tokens not synced in 90 days (stale design system)
  - **Done**: Monitoring recommendations documented

### Docs

- [ ] **[S]** Verify spec edge cases match script recovery procedures | Depends: None
  - Review spec edge cases section (6 scenarios)
  - Confirm each has documented recovery procedure
  - Verify scripts handle edge cases gracefully
  - **Done**: All edge cases documented with recovery steps

- [ ] **[S]** Document token sync workflow in branding docs | Depends: None
  - Update `docs/guides/branding/BRANDING.md` with token sync workflow (7-step sequence from spec)
  - Document rollback procedure
  - Document emergency recovery (provenance lost/corrupted)
  - **Done**: Workflow documented with examples

- [ ] **[S]** Create token system operating model doc | Depends: None
  - Document when to sync tokens (after Figma updates)
  - Document verification steps before/after sync
  - Document rollback procedure
  - **Done**: Operating model documented in `docs/guides/branding/BRANDING_OPERATING_MODEL.md`

### CI Integration

- [ ] **[M]** Add token drift verification to CI workflow | Depends: Test tasks
  - Add job to `.github/workflows/verify-branding.yml` that runs `verify-token-drift.sh`
  - Job should fail build if drift detected
  - Job should run on every push to `main` and every PR
  - **Done**: CI job added; builds fail on token drift

- [ ] **[S]** Add token validation to branding gates | Depends: Build tasks
  - Ensure `verify-token-drift.sh` is called by `run-branding-gates.sh`
  - Verify it's included in both source and live gate suites
  - **Done**: Token drift check integrated into branding gate pipeline

### Rollout

- [ ] **[S]** Run full verification suite from spec Verification section | Depends: All build + test tasks
  - Execute all 8 verification commands from spec
  - Document results as evidence
  - **Done**: All verification commands pass

## Milestones

| Milestone | Tasks | Target |
|-----------|-------|--------|
| M1: Audit & Documentation | Build tasks (audit tokens, verify structure, docs) | Day 1 |
| M2: Verification Hardening | Test tasks (drift detection, sync workflow, negative tests) | Day 1 |
| M3: CI Integration | CI tasks (add token drift to CI, integrate with branding gates) | Day 2 |
| M4: Sign-off | Rollout task (full verification suite passes) | Day 2 |

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Token sync workflow breaks if upstream repo moves | Low | Medium | Script uses configurable `BRAND_ASSETS_REPO` path; document path update procedure |
| CI fails to catch token drift if `verify-token-drift.sh` not integrated | Medium | High | Explicitly add to `.github/workflows/verify-branding.yml` in this plan |
| Provenance file becomes stale without detection | Medium | Medium | Add 90-day staleness alert to observability plan |
| Font family substring matching logic in drift script is fragile | Low | Low | Current implementation uses `if "lato" not in value.lower()` which is robust for substring matching |
| Token drift occurs in production without CI enforcement | Medium | High | CI integration task makes drift checks mandatory on every build |
| Manual token edits bypass provenance tracking | Medium | Medium | Document that all token changes MUST go through sync workflow; drift detection will catch manual edits |

## Dependencies on Other Specs

| Spec | Dependency Type |
|------|----------------|
| `branding-system_spec.md` | Parent spec - defines theme structure and asset sync workflow |
| `repository-structure_spec.md` | Defines directory layout for assets and scripts |
| `multi-tenancy-architecture_spec.md` | Future - will need per-tenant token customization |
| `cross-cutting-requirements_spec.md` | Inherits NFR patterns (performance, security, availability) |
