# Issue #222 Implementation Packet - Authn Submodule Path Canonicalization

Issue: https://github.com/Biji-Biji-Initiative/mereka-lms/issues/222  
Parent: https://github.com/Biji-Biji-Initiative/mereka-lms/issues/214  
Status: audit-to-implementation handoff

## Goal

Resolve path contract drift for `frontend-app-authn` submodule and enforce one canonical repository location.

## Confirmed Risks

- `.gitmodules` currently uses `tmp/frontend-app-authn`.
- Some docs/specs reference `apps/frontend-app-authn`.
- Mixed references create onboarding and automation ambiguity.

---

## Decision Gate

Choose one canonical path:

- Option A: keep `tmp/frontend-app-authn` (minimal operational change)
- Option B: migrate to `apps/frontend-app-authn` (spec alignment friendly, higher migration risk)

Recommended: Option A first (stabilize docs/contracts), then revisit structural migration if needed.

---

## PR Strategy (recommended 2 PRs)

1. `PR-222-A` contract normalization (no submodule move)
2. `PR-222-B` optional physical path migration (only if approved)

---

## PR-222-A (Contract Normalization)

### File Changes

1. Update docs/specs to canonical path:
   - `docs/onboarding/REPOSITORY_GUIDE.md`
   - `specs/repository-structure_spec.md`
   - any other active references.
2. Add path contract checker:
   - `scripts/qa/verify-authn-submodule-path-contract.sh`
3. Wire checker to CI:
   - `.github/workflows/ci.yml`

### Acceptance Criteria

- `AC-222-A1`: all active docs/specs use same canonical path string.
- `AC-222-A2`: CI fails on reintroduction of non-canonical references.

### Verification Commands

```bash
git config -f .gitmodules --get-regexp '^submodule\\..*\\.path$'
./scripts/qa/verify-authn-submodule-path-contract.sh
rg -n "apps/frontend-app-authn|tmp/frontend-app-authn" README.md docs specs scripts .gitmodules
```

---

## PR-222-B (Optional Submodule Move)

### Preconditions

- Only if team explicitly approves path migration.
- Ensure all scripts and docs that consume path are updated atomically.

### File Changes

1. Update `.gitmodules` path.
2. Move submodule location in repo.
3. Update all path references in docs/scripts/specs.
4. Add migration note for local clones.

### Migration Steps (if executed)

1. Update `.gitmodules`.
2. Run:
   - `git submodule sync --recursive`
   - `git submodule update --init --recursive`
3. Verify tooling/scripts with canonical checker.

### Rollback Plan

1. If local dev or CI breaks due to path move:
   - revert submodule path move commit.
2. Keep PR-222-A checker and docs normalization even if move reverted.

### Acceptance Criteria

- `AC-222-B1`: submodule path and all references converge to chosen location.
- `AC-222-B2`: `git submodule status` clean on fresh clone with documented bootstrap steps.
