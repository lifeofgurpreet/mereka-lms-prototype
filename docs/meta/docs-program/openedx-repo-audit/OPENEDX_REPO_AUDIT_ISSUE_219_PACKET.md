# Issue #219 Implementation Packet - Verification Suite Consolidation

Issue: https://github.com/Biji-Biji-Initiative/mereka-lms/issues/219  
Parent: https://github.com/Biji-Biji-Initiative/mereka-lms/issues/214  
Status: audit-to-implementation handoff

## Goal

Make the verify-script ecosystem operable by introducing classification, ownership, and enforceable workflow mapping.

## Confirmed Risks

- `verify-*.sh` count is very high (`490`), making coverage and reliability hard to reason about.
- Only subset is directly workflow-invoked; many scripts are discoverable but not clearly lane-bound.
- Current model increases maintenance overhead and raises silent drift risk.

---

## PR Strategy (recommended 3 PRs)

1. `PR-219-A` inventory + classification manifest
2. `PR-219-B` lane entrypoints and workflow binding
3. `PR-219-C` deprecation wrappers for redundant scripts

---

## PR-219-A (Inventory + Classification)

### File Changes

1. Add machine-readable manifest:
   - `scripts/qa/verify-manifest-integrity.sh`
2. Add validator:
   - `scripts/qa/verify-manifest-integrity.sh`
3. Add doc:
   - Internal operating model for lane ownership and maintenance cadence (to be documented separately)

### Manifest Contract

Per script:
- `path`
- `class` (`blocking`, `scheduled`, `manual`, `deprecated`)
- `owner`
- `workflow_refs` (list)
- `spec_refs` (optional).

### Acceptance Criteria

- `AC-219-A1`: every `verify-*.sh` script has a manifest record.
- `AC-219-A2`: no script is unclassified.
- `AC-219-A3`: blocking checks have at least one workflow binding.

### Verification Commands

```bash
./scripts/qa/verify-manifest-integrity.sh
find scripts -type f -name 'verify-*.sh' | wc -l
```

---

## PR-219-B (Lane Runners + Workflow Simplification)

### File Changes

1. Add lane-style execution groups:
   - group verify scripts by domain (infra, branding, auth, observability) and execute via shared entrypoints
2. Update CI/workflows:
   - `.github/workflows/ci.yml`
   - other scheduled workflows to use lane runners where possible.

### Acceptance Criteria

- `AC-219-B1`: major workflows invoke lane runners for grouped checks.
- `AC-219-B2`: lane runners report per-script pass/fail in deterministic format.
- `AC-219-B3`: failure triage output points back to individual underlying script.

### Verification Commands

```bash
bash -n scripts/qa/verify-manifest-integrity.sh
rg -n "verify-.*\.sh" .github/workflows
./scripts/qa/verify-manifest-integrity.sh
```

---

## PR-219-C (Deprecation + Compatibility Wrappers)

### File Changes

- For scripts marked `deprecated`, replace body with wrapper that:
  - prints deprecation notice
  - calls canonical lane/command
  - preserves exit code.

### Acceptance Criteria

- `AC-219-C1`: deprecated scripts remain callable but no longer maintain duplicate logic.
- `AC-219-C2`: deprecation output includes removal date/version target.

### Rollback Plan

1. If lane wrapper breaks critical gate:
   - temporarily restore direct script invocation in affected workflow.
2. Keep compatibility wrappers until two stable release cycles pass.

### Verification Commands

```bash
./scripts/qa/verify-manifest-integrity.sh
rg -n "deprecated|lane" scripts/qa
```
