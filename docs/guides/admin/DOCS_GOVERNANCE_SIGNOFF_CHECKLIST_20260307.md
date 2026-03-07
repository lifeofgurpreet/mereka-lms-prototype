# Docs Governance Sign-Off Checklist (2026-03-07)

## Scope

Use this checklist to close remaining governance gates for docs remediation and first-class docs hardening.

## Current Status Snapshot

- Branch: `docs/docs-first-class-20260307-followup-7`
- Command/path reference drift: `0 missing` (`docs/qa/verify-doc-command-refs.sh --include-baseline ...`)
- World-class docs gates: `PASS` (`docs/qa/run-docs-world-class-gates.sh --sync --max-age-seconds 0`)
- Remaining closure dependency: governance approvals

## Required Governance Gates

### GOV-01 — Canonical Authority Sign-Off

- [ ] Docs Lead confirms canonical owners for updated docs surfaces.
- [ ] Canonical authority matrix is approved and timestamped.
- [ ] Any open owner conflicts are resolved in writing.

Evidence to attach:
- `docs/archive/reports/canonical-authority-approval-matrix-20260306.md`
- PR #718 comment with approval links/screenshots

### GOV-02 — Policy/Structure Compliance Acceptance

- [ ] Docs Lead confirms policy and structure checks are accepted as closure evidence.
- [ ] Final acceptance note is posted on PR #718.

Evidence to attach:
- Output snippet from:
  - `docs/qa/verify-docs-policy.sh`
  - `scripts/qa/verify-repo-structure.sh`
  - `docs/qa/run-docs-world-class-gates.sh --sync --max-age-seconds 0`

### CLS-02 — Program Closure Authorization

- [ ] Governance owners confirm remediation program can move from blocked to done.
- [ ] Tracker/status artifacts are updated with final approval timestamps.
- [ ] PR #718 is approved for merge.

Evidence to attach:
- Updated tracker status with `GOV-01`, `GOV-02`, `CLS-02` marked complete.
- Final closure comment on PR #718.

## Final Closure Procedure

1. Run final checks:
   - `docs/qa/verify-docs-policy.sh`
   - `scripts/qa/verify-repo-structure.sh`
   - `docs/qa/run-docs-world-class-gates.sh --sync --max-age-seconds 0`
2. Post evidence summary to PR #718.
3. Obtain explicit governance approvals for `GOV-01`, `GOV-02`, `CLS-02`.
4. Merge PR #718.

## Post-Merge Follow-Through

- [ ] Regenerate/refresh docs scorecard artifacts if required by policy cadence.
- [ ] Confirm `origin/main` remains `DOCS_CMDREF_OK` for changed range in next docs PR.
- [ ] Keep future `docs-compliance` workflow edits batched into one PR per session.
