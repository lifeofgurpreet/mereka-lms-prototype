# Docs Program Scorecard 2026-03-06

_Audience: Docs Lead + Domain Owners • Owner: Platform Team • Last verified: 2026-03-06 • Status: supporting_

## KPI Snapshot
- Classification coverage: 100.00% (953/953)
- Duplicate canonical topics: 0
- Broken links (changed scope): 0 (per consolidation closeout 2026-03-06)
- Root policy violations: 0
- Stale canonical docs >90d: 0.00% (0/18)
- Redirect-stub debt: 0 superseded markdown docs outside `docs/archive/superseded/**` (down from 81; see `docs/archive/reports/redirect-stub-debt-burndown-20260306.md`)

## Risks and Blocks
- No duplicate canonical topics detected by current conflict-group policy.
- Stale canonical ratio is within target (<10%).
- Redirect-stub debt target is met (`81 -> 0`) after script/workflow dependency cleanup.
- Blocker matrix now reports no active dependency blockers for superseded stub retirement.
- Detailed path-level remediation map is published in `docs/archive/reports/redirect-stub-dependency-remediation-map-20260306.md`.
- Script/workflow execution sequencing is published in `docs/archive/reports/redirect-stub-remediation-batch-plan-20260306.md`.
- Evidence lifecycle workstream is active and passing dry-run controls (`docs/archive/reports/evidence-retention-dry-run-20260306.md`); this cycle had `0` approved move candidates.
- Major-cluster canonical approval remains pending; sign-off matrix is published at `docs/archive/reports/canonical-authority-approval-matrix-20260306.md`.
- Primary index still includes 11 transitional `docs/operations/**` links; queued migration register is published at `docs/archive/reports/transitional-operations-link-gap-20260306.md`.
- Transitional-tree retirement is now scheduled; see `docs/archive/reports/transitional-path-deprecation-timeline-20260306.md`.
- Canonical metadata audit is clean (`18/18` canonical docs with required markers, `0` stale >90d): `docs/archive/reports/canonical-metadata-audit-20260306.md`.
- Contradiction audits are now documented for major clusters:
  - onboarding: `docs/archive/reports/onboarding-contradiction-audit-20260306.md`
  - access: `docs/archive/reports/access-contradiction-audit-20260306.md`
  - branding: `docs/archive/reports/branding-contradiction-audit-20260306.md`
  - runbooks: `docs/archive/reports/runbooks-contradiction-audit-20260306.md`
  - evidence: `docs/archive/reports/evidence-contradiction-audit-20260306.md`
- Repository-wide markdown link audit now has `0` hard failures and `0` warnings in `docs/**`.

## Decisions Needed
- Review and sign governance packet: `docs/archive/reports/governance-approval-note-20260306.md`.
- Acknowledge escalation routing appendix: `docs/archive/reports/escalation-appendix-20260306.md`.
- Approve canonical authority map for each major topic cluster.
- Confirm whether `>=25%` debt reduction is measured from original baseline (`81`) or rolling sprint start.
- Use `docs/archive/reports/program-closure-readiness-20260306.md` as closure gate checklist for `CLS-02`.
- Execute approvals via `docs/archive/reports/approval-execution-runbook-20260306.md`.
- Publish second-cycle KPI at `docs/archive/reports/docs-program-scorecard-20260313.md` (template: `docs/archive/reports/docs-program-scorecard-20260313-template.md`).
- Approve migration sequencing for `docs/archive/reports/transitional-operations-link-gap-20260306.md`.
- Acknowledge and approve `docs/archive/reports/transitional-path-deprecation-timeline-20260306.md`.
