# Issue #215 Implementation Packet - Evidence Pipeline Hardening

Issue: https://github.com/Biji-Biji-Initiative/mereka-lms/issues/215  
Parent: https://github.com/Biji-Biji-Initiative/mereka-lms/issues/214  
Status: audit-to-implementation handoff

## Goal

Prevent sensitive operational artifacts from entering git history while preserving compliance evidence quality.

## Confirmed Risks

- `docs/archive/evidence/operations/evidence/router-smoke/prod-route-health-20260219-1214.md` contains raw `set-cookie` headers with `sessionid` and `csrftoken`.
- `.githooks/pre-commit` currently skips `*.md`, so evidence markdown is not scanned pre-commit.
- Existing evidence schema docs focus on path conventions and retention, not redaction enforcement.

## PR Strategy (recommended 3 PRs)

1. `PR-215-A` enforcement scaffold (non-destructive)
2. `PR-215-B` workflow migration to summary-in-git, raw-in-artifact
3. `PR-215-C` targeted historical evidence scrubbing for known unsafe files

---

## PR-215-A (Enforcement Scaffold)

### File Changes

1. Add new script:
   - `scripts/qa/verify-evidence-redaction.sh`
2. Update pre-commit hook:
   - `.githooks/pre-commit`
3. Update CI:
   - `.github/workflows/ci.yml`
4. Add policy doc:
   - `docs/policies/operations/EVIDENCE_REDACTION_POLICY.md`
5. Cross-link docs:
   - `docs/meta/templates/EVIDENCE_SCHEMA.md`
   - `docs/ops/runbooks/DEPLOY_EVIDENCE_GATES.md`

### Script Contract (`verify-evidence-redaction.sh`)

- Scan scope:
  - `docs/archive/evidence/operations/**`
  - `docs/archive/evidence/observability/**`
  - optional future: any `docs/**/evidence/**`
- Fail patterns (case-insensitive):
  - `set-cookie:`
  - `sessionid=`
  - `csrftoken=`
  - `authorization:\s*bearer`
  - `x-api-key:`
  - JWT-like tokens (`eyJ...`)
- Output format:
  - `FAIL <file>:<line> <pattern>`
- Support mode flags:
  - `STRICT=1` (default in CI)
  - `STRICT=0` (warn-only local mode)

### Pre-commit Hook Update

Current behavior skips markdown files entirely.  
Required change:
- keep existing general secret scan behavior
- add targeted call for staged evidence markdown files:
  - run `verify-evidence-redaction.sh --staged-only`
- block commit on findings

### CI Update

In `static-validation` job of `.github/workflows/ci.yml`, add:
- syntax check: `bash -n scripts/qa/verify-evidence-redaction.sh`
- execution: `STRICT=1 ./scripts/qa/verify-evidence-redaction.sh`

### Acceptance Criteria

- `AC-215-A1`: CI fails when a file in evidence paths contains cookie/session/bearer artifacts.
- `AC-215-A2`: pre-commit fails for staged evidence files with same patterns.
- `AC-215-A3`: policy doc defines allowed redaction format and prohibited raw headers/tokens.

### Verification Commands

```bash
bash -n scripts/qa/verify-evidence-redaction.sh
STRICT=1 ./scripts/qa/verify-evidence-redaction.sh
rg -n "set-cookie|sessionid=|csrftoken=|authorization:\\s*bearer" docs/archive/evidence/operations docs/archive/evidence/observability
```

---

## PR-215-B (Evidence Pipeline Migration)

### File Changes

1. Update release evidence workflows:
   - `.github/workflows/release-evidence.yml`
   - other evidence-heavy workflows under `.github/workflows/` that currently materialize raw payloads intended for docs
2. Update docs:
   - `docs/reference/operations/RELEASE_EVIDENCE.md`
   - `docs/meta/templates/EVIDENCE_SCHEMA.md`

### Required Behavior

- Raw outputs (headers, full HTML, screenshots, raw logs) go to `var/ci/**` or `var/evidence/**` only.
- Raw outputs are uploaded via `actions/upload-artifact`.
- Committed docs hold:
  - summary decisions
  - pass/fail status
  - artifact names/IDs
  - hashes/checksums (optional but recommended)

### Acceptance Criteria

- `AC-215-B1`: no workflow requires committing raw HTTP headers into `docs/**`.
- `AC-215-B2`: evidence docs contain summary + artifact pointer, not raw secret-bearing payload.

### Verification Commands

```bash
rg -n "set-cookie|authorization: bearer|sessionid=|csrftoken=" docs/archive/evidence/operations docs/archive/evidence/observability
rg -n "upload-artifact" .github/workflows
```

---

## PR-215-C (Known Unsafe File Cleanup)

### File Changes

- Redact known unsafe files, starting with:
  - `docs/archive/evidence/operations/evidence/router-smoke/prod-route-health-20260219-1214.md`

### Redaction Rules

- Replace cookie/token values with `<REDACTED>`.
- Keep header keys and structural context.
- Preserve timestamps, endpoints, status codes.

### Acceptance Criteria

- `AC-215-C1`: known unsafe evidence files no longer contain raw session/token values.
- `AC-215-C2`: redaction is deterministic and reviewable (no semantic loss in summary intent).

### Verification Commands

```bash
rg -n "sessionid=|csrftoken=|authorization:\\s*bearer" docs/archive/evidence/operations docs/archive/evidence/observability
```

---

## Rollback Plan

1. If hook/CI false positives are excessive:
   - switch local hook to warn-only while keeping CI strict.
2. If CI blocks release-critical PRs:
   - temporary controlled bypass via env var (`EVIDENCE_REDACTION_STRICT=0`) with mandatory follow-up issue.
3. Never rollback by re-allowing raw secrets into evidence docs.

## Implementation Notes

- Keep this narrowly scoped to evidence redaction; do not mix with general secret scanner refactors.
- Reuse existing script style (`#!/usr/bin/env bash`, `set -euo pipefail`, pass/fail counters).
