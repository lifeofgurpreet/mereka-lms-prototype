# Canonical Authority Approval Matrix 2026-03-06

_Audience: Docs Lead + Domain Owners • Owner: Platform Team • Last verified: 2026-03-06 • Status: supporting_

## Scope
This matrix narrows canonical approval to the major remediation clusters required by Phase 3 acceptance:
- onboarding
- access URLs
- branding
- runbooks
- evidence

Reference source for broader topic-level nominations:
- `docs/archive/reports/canonical-resolution-map-20260306.md`

## Approval Matrix

| Cluster | Proposed Canonical Authority | Supporting / Transitional References | Domain Owner Approval | Docs Lead Approval | Status |
|---|---|---|---|---|---|
| onboarding | `docs/guides/onboarding/README.md` | `docs/onboarding/**` (transitional), onboarding deep guides under `docs/guides/onboarding/**` | PENDING | PENDING | IN_REVIEW |
| access URLs | `docs/ops/quickref/access-urls.md` | `docs/operations/ACCESS_URLS.md` (`archive-candidate` shim) | PENDING | PENDING | IN_REVIEW |
| branding | `docs/guides/branding/README.md` | `docs/branding/**` transitional shim set + `docs/concepts/components/branding.md` index pack | PENDING | PENDING | IN_REVIEW |
| runbooks | `docs/ops/runbooks/**` | legacy `docs/operations/*RUNBOOK*.md` and `docs/runbooks/**` retained as transitional/archive stubs | PENDING | PENDING | IN_REVIEW |
| evidence | `docs/archive/evidence/**` | legacy generators/scanners now canonical-path aware; dry-run report at `docs/archive/reports/evidence-retention-dry-run-20260306.md` | PENDING | PENDING | IN_REVIEW |

## Notes
- This document does not self-approve authority decisions.
- Once all rows are approved, update:
  - tracker gap checklist item "Canonical authority map published and approved for every major topic cluster"
  - milestone/closure notes for final program decision.
