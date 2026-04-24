# Evidence Retention Dry-Run 2026-03-06

_Audience: Docs Team • Owner: Platform Team • Last verified: 2026-03-06 • Status: supporting_

## Method (Policy-Safe Signals)
- Signal 1: type/status (`archive-candidate`/`superseded` inferred from path + metadata context).
- Signal 2: content role (`raw-evidence`, `evidence-report`, `transient-status`).
- Signal 3: recency (event date parsed from filename/path, then age in days).
- Signal 4: owner approval gate (all proposed moves remain pending owner approval).

## Inventory Summary
- Total evidence files scanned: 135
- Hot (<=30d): 87
- Warm (31-90d): 0
- Cold (>90d): 0
- Unknown date: 48

## Proposed Archive Move Candidates (Dry-Run Only)
- Rule: cold + non-tiered evidence path only.
- Candidate count: 0

| Source Path | Proposed Target Tier Path | Status | Role | Age (days) | Owner Approval |
|---|---|---|---|---:|---|

## Guardrails Applied
- No files moved in this dry-run.
- No deletions proposed.
- Tiering recommendation only; execution requires domain-owner approval + move ledger + link check.

## Decisions Needed
- Candidate move list approval: not required for this cycle (`0` candidates).
- Confirm duplicate-filename collision policy for quarter-tier folders (rename with scoped prefix when needed).

## Execution Status
- EVD-01 dry-run completed with policy-safe signal set and no cold non-tiered candidates.
- EVD-02 execution closed as no-op for this cycle (no approved moves required).
- Evidence tooling defaults now point to canonical archive path:
  - `scripts/qa/build-observability-tracing-pilot-bundle.sh` default output is `docs/archive/evidence/observability`.
  - Evidence policy scanners include canonical archive observability path for tracking and redaction checks.
