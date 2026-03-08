# Approval Execution Runbook 2026-03-06
_Audience: Docs Lead + Domain Owners • Owner: Platform Team • Last verified: 2026-03-06 • Status: supporting_

## Goal
Close the remaining governance gates with deterministic approvals and evidence updates.

## Inputs
- `docs/archive/reports/governance-approval-note-20260306.md`
- `docs/archive/reports/escalation-appendix-20260306.md`
- `docs/archive/reports/canonical-authority-approval-matrix-20260306.md`
- `docs/archive/reports/program-closure-readiness-20260306.md`
- `docs/archive/reports/transitional-path-deprecation-timeline-20260306.md`
- `docs/archive/reports/transitional-operations-link-gap-20260306.md`

## Approval Steps
1. Docs Lead reviews governance packet and records decision in approval table.
2. Domain owners fill ownership map and approve/waive each domain row.
3. Docs Lead acknowledges escalation appendix.
4. Domain owners + Docs Lead approve major-cluster canonical matrix rows.
5. Docs Lead + Ops Domain Owner approve transitional migration sequencing and deprecation timeline.
6. Update tracker statuses:
   - `GOV-01` -> `DONE`
   - `GOV-02` -> `DONE`

## Second-Cycle KPI Step (2026-03-13)
1. Create/update `docs/archive/reports/docs-program-scorecard-20260313.md` from template.
2. Recompute KPI snapshot (classification, duplicate canonicals, broken links, stale canonical ratio, stub debt).
3. If targets still hold, update:
   - `CLS-01` -> `DONE`
   - `CLS-02` -> `DONE`
   - `M1` and `M4` -> `DONE`

## Verification Commands
```bash
./tools/docs/verify/verify-docs-policy.sh
jq '[.[] | select((.path|startswith("archive/superseded/")|not) and .status=="superseded")] | length' generated/catalogs/docs-catalog.json
rg -n "\| GOV-01|\| GOV-02|\| CLS-01|\| CLS-02" docs/DOCS_REMEDIATION_PLAN_AND_TRACKER.md
```

## Exit Condition
All approvals recorded + second-cycle scorecard published with KPI targets in range.
