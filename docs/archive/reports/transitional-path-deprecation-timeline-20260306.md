# Transitional Path Deprecation Timeline 2026-03-06
_Audience: Docs Lead + Domain Owners • Owner: Platform Team • Last verified: 2026-03-06 • Status: supporting_

## Scope
This timeline governs staged retirement of transitional docs trees:
- `docs/operations/**`
- `docs/onboarding/**`
- `docs/runbooks/**`

Canonical destinations:
- `docs/ops/**`
- `docs/guides/**`
- `docs/archive/**`

## Current Snapshot (2026-03-06)
- `docs/operations/**` files (depth<=2): 250
- `docs/onboarding/**` files (depth<=2): 0
- `docs/runbooks/**` files (depth<=2): 0

## Deprecation Phases

| Window | Scope | Exit Criteria | Owner |
|---|---|---|---|
| 2026-03-06 to 2026-03-13 | Queue approval and canonical target assignment for `docs/README.md` transitional links (`20` queued items) | Approved migration sequencing for queue in `transitional-operations-link-gap-20260306.md` | Docs Lead + Ops Domain Owner |
| 2026-03-13 to 2026-03-27 | Execute low-risk link+move batches from `docs/operations/**` to `docs/ops/**`/`docs/guides/**` with stubs where required | At least first migration batch completed with move ledger + policy checks passing | Agent Operator + Domain Owners |
| 2026-03-27 to 2026-04-10 | Retire or archive residual transitional docs not needed in active navigation | No primary-index links pointing to transitional paths unless explicitly waived | Docs Lead |

## Waiver Policy
- Transitional files may remain only when one of the following is true:
  - unresolved domain-owner canonical decision,
  - active external dependency on legacy path,
  - historical/audit value requiring archive staging.
- Every waiver must include owner, reason, and target removal/review date.

## Governance Links
- Migration queue: `docs/archive/reports/transitional-operations-link-gap-20260306.md`
- Approval runbook: `docs/archive/reports/approval-execution-runbook-20260306.md`
- Master tracker: `docs/DOCS_REMEDIATION_PLAN_AND_TRACKER.md`
