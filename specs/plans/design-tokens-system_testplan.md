---
spec: design-tokens-system_spec.md
plan: design-tokens-system_plan.md
last_updated: '2026-02-10'
status: draft
---

# Test Plan: Design Tokens System

**Source Spec**: `specs/design-tokens-system_spec.md`
**Source Plan**: `specs/plans/design-tokens-system_plan.md`

## Test Framework

This spec covers design token infrastructure and verification tooling. All tests are shell-based verification scripts, consistent with the branding system test infrastructure:

| Test Type | Tool | Location Pattern |
|-----------|------|-----------------|
| `shell_verification` | Bash scripts (`set -euo pipefail`) | `scripts/branding/verify-*.sh` |
| `manual_verification` | Human-executed checklist | Documented inline |

---

## Test Matrix

| AC | Description | Test Type | Test File / Location | Mocks/Fixtures | Priority |
|----|-------------|-----------|---------------------|----------------|----------|
| AC-001 | All primary color tokens (--color-black, --color-white, --color-teal, --color-magenta, --color-blue) are defined with valid hex values | `shell_verification` | `scripts/branding/verify-token-drift.sh` | None (parses tokens.css) | P1 |
| AC-001 | Token categories completeness validation | `shell_verification` | `scripts/branding/verify-design-tokens.sh` | None (parses tokens.css) | P1 |
| AC-002 | All typography tokens (--font-heading, --font-body, --text-h1, etc.) are defined with valid CSS values | `shell_verification` | `scripts/branding/verify-token-drift.sh` | None (parses tokens.css) | P1 |
| AC-002 | Typography token format validation | `shell_verification` | `scripts/branding/verify-design-tokens.sh` | None (parses tokens.css) | P1 |
| AC-003 | All spacing tokens (--space-0 through --space-24) follow 4px base unit scale | `shell_verification` | `scripts/branding/verify-design-tokens.sh` | None (parses tokens.css) | P1 |
| AC-004 | Token file structure validation (single :root selector, kebab-case naming, section headers) | `shell_verification` | `scripts/branding/verify-design-tokens.sh` | None (parses tokens.css) | P1 |
| AC-004 | Existing health check includes token file validation | `shell_verification` | `scripts/branding/verify-branding-health.sh` | None (parses tokens.css) | P1 |
| AC-005 | Provenance file contains all required fields (source_repo, source_path, source_branch, source_commit, source_sha256, synced_at_utc) | `shell_verification` | `scripts/branding/verify-token-drift.sh` | None (parses tokens.provenance.json) | P1 |
| AC-006 | Provenance source_commit matches 40-character lowercase git SHA pattern [0-9a-f]{40} | `shell_verification` | `scripts/branding/verify-token-drift.sh` | None (parses tokens.provenance.json) | P1 |
| AC-007 | Provenance source_sha256 matches 64-character lowercase SHA256 pattern [0-9a-f]{64} | `shell_verification` | `scripts/branding/verify-token-drift.sh` | None (parses tokens.provenance.json) | P1 |
| AC-008 | verify-token-drift.sh exits 0 when tokens.css and mereka-overrides.css are in sync | `shell_verification` | `scripts/branding/verify-token-drift.sh` | None | P1 |
| AC-009 | verify-token-drift.sh exits non-zero when token values mismatch (negative test) | `shell_verification` | `scripts/branding/verify-token-drift.sh` | Manual: temporarily modify --color-teal in tokens.css | P1 |
| AC-010 | verify-token-drift.sh exits non-zero when tokens.css content is modified but provenance SHA256 is stale | `shell_verification` | `scripts/branding/verify-token-drift.sh` | Manual: modify tokens.css without updating provenance | P1 |
| AC-011 | update-token-provenance.sh syncs tokens from upstream and updates provenance metadata when SYNC_FILE=1 | `shell_verification` | `scripts/branding/update-token-provenance.sh` | Requires upstream bbbi-mereka-brand-assets repo | P1 |
| AC-011 | Full sync workflow verification | `manual_verification` | Follow "Syncing New Tokens from Figma" in spec Rollout section | Requires upstream repo access | P2 |
| AC-012 | mereka-overrides.css contains --mereka-color-teal defined with value matching --color-teal from tokens.css | `shell_verification` | `scripts/branding/verify-token-drift.sh` | None (parses both CSS files) | P1 |
| AC-012 | CSS override validation checks override file references canonical tokens | `shell_verification` | `scripts/branding/verify-branding-css.sh` | None (parses override files) | P1 |

---

## Edge Case Tests

| Edge Case | Test Description | Test Type | Location | Priority |
|-----------|-----------------|-----------|----------|----------|
| EC-1: Provenance SHA mismatch after manual edit | Manually edit tokens.css without updating provenance; verify verify-token-drift.sh detects mismatch and exits non-zero | `shell_verification` | `scripts/branding/verify-token-drift.sh` | P1 |
| EC-2: Upstream repository moved or renamed | Update `BRAND_ASSETS_REPO` environment variable and verify update-token-provenance.sh works with new path | `manual_verification` | `scripts/branding/update-token-provenance.sh` | P2 |
| EC-3: Font family substring match failure | Verify script handles font stacks like "Lato, sans-serif" correctly (substring matching should pass) | `shell_verification` | `scripts/branding/verify-token-drift.sh` | P2 |
| EC-4: Token drift in production without CI failure | Simulate scenario where tokens drift but CI passes; verify CI integration catches drift | `manual_verification` | `.github/workflows/verify-branding.yml` | P1 |
| EC-5: Missing token in overrides | Remove required token pair from mereka-overrides.css; verify verify-token-drift.sh detects missing token and exits non-zero | `shell_verification` | `scripts/branding/verify-token-drift.sh` | P1 |
| EC-6: Whitespace normalization false positive | Test tokens with different whitespace (tabs, multiple spaces); verify normalization prevents false positives | `shell_verification` | `scripts/branding/verify-token-drift.sh` | P2 |

---

## NFR Tests

| NFR | Test Description | Test Type | Method | Priority |
|-----|-----------------|-----------|--------|----------|
| Performance: Token parsing < 5 seconds | Run verify-token-drift.sh with time measurement; verify completion under 5 seconds | `shell_verification` | `time scripts/branding/verify-token-drift.sh` | P2 |
| Performance: Provenance update < 2 seconds | Run update-token-provenance.sh with time measurement; verify completion under 2 seconds | `shell_verification` | `time scripts/branding/update-token-provenance.sh` | P2 |
| Security: No secrets in token files | Scan tokens.css and tokens.provenance.json for common secret patterns | `shell_verification` | `grep -E '(api_key|password|secret)' assets/branding/tokens.*` (should return empty) | P1 |
| Security: SHA256 provenance hash prevents tampering | Manually tamper with tokens.css; verify drift detection catches the change | `shell_verification` | `scripts/branding/verify-token-drift.sh` | P1 |
| Availability: Token sync works with offline upstream | Test behavior when upstream repo is unavailable; verify graceful error handling | `manual_verification` | Temporarily move upstream repo; run update-token-provenance.sh | P2 |
| Compliance: Color tokens meet basic format requirements | Verify all color tokens use lowercase hex format | `shell_verification` | `scripts/branding/verify-design-tokens.sh` | P1 |

---

## Test Execution Strategy

### Phase 1: Static Verification (CI-safe, no external dependencies)

These tests run on every push to `main` and every PR:

```bash
# Token drift detection (primary gate)
./scripts/branding/verify-token-drift.sh

# Token completeness and format validation
./scripts/branding/verify-design-tokens.sh

# CSS override validation
./scripts/branding/verify-branding-css.sh

# Integrated branding health check
./scripts/branding/verify-branding-health.sh
```

### Phase 2: Sync Workflow Testing (requires upstream repo access)

These tests are run by operators during token updates:

```bash
# Provenance-only update (no file sync)
./scripts/branding/update-token-provenance.sh

# Full sync (copies upstream file + updates provenance)
SYNC_FILE=1 ./scripts/branding/update-token-provenance.sh

# Verify sync results
./scripts/branding/verify-token-drift.sh
```

### Phase 3: Negative Testing (manual execution)

| Test | Procedure | Expected Result |
|------|-----------|----------------|
| AC-009: Detect token value mismatch | Temporarily modify `--color-teal: #2d898b` to `--color-teal: #FFFFFF` in tokens.css | verify-token-drift.sh exits non-zero with error message "drift: --color-teal=#2d898b != --mereka-color-teal=#FFFFFF" |
| AC-010: Detect provenance SHA256 mismatch | Modify tokens.css content without running update-token-provenance.sh | verify-token-drift.sh exits non-zero with error "tokens.css sha256 drift: provenance=<old> actual=<new>" |
| EC-1: Recovery from manual edit | Follow spec edge case recovery procedure: re-sync from upstream or manually update provenance | verify-token-drift.sh exits 0 after recovery |
| EC-5: Missing token in overrides | Comment out `--mereka-color-teal` line in mereka-overrides.css | verify-token-drift.sh exits non-zero with error "missing --mereka-color-teal in overrides.css" |

### Phase 4: CI Integration Verification

```bash
# Verify CI workflow includes token drift check
grep -A10 'verify-token-drift' .github/workflows/verify-branding.yml

# Verify branding gates call token verification
grep 'verify-token-drift' scripts/branding/run-branding-gates.sh
```

---

## Test Coverage Summary

| Category | Total ACs | Automated | Manual | Coverage |
|----------|-----------|-----------|--------|----------|
| Token Categories | 3 (AC-001 to AC-003) | 3 | 0 | 100% |
| Token File Structure | 1 (AC-004) | 1 | 0 | 100% |
| Provenance Tracking | 3 (AC-005 to AC-007) | 3 | 0 | 100% |
| Drift Detection | 3 (AC-008 to AC-010) | 3 (including negative tests) | 0 | 100% |
| Token Sync Workflow | 1 (AC-011) | 1 | 1 manual verification | 100% |
| Runtime Token Mapping | 1 (AC-012) | 1 | 0 | 100% |
| **Total** | **12** | **12** | **1** | **100%** |
| Edge Cases | 6 | 4 | 2 | 100% |
| NFRs | 6 | 4 | 2 | 100% |

All 12 acceptance criteria are covered. 12 have fully automated verification scripts. 1 has manual verification for the full upstream sync workflow (requires access to bbbi-mereka-brand-assets repository).

---

## Pass Criteria

All acceptance criteria are met when:
- `scripts/branding/verify-token-drift.sh` exits 0 with message "✓ Token drift + provenance checks passed."
- `scripts/branding/verify-design-tokens.sh` exits 0 (validates all token categories and formats)
- `scripts/branding/verify-branding-health.sh` exits 0 (includes token file validation)
- Manual provenance update test succeeds: `SYNC_FILE=1 ./scripts/branding/update-token-provenance.sh` followed by drift verification passes
- Negative tests correctly detect drift violations and exit non-zero with actionable error messages
- CI integration includes token drift verification and fails builds on drift detection
