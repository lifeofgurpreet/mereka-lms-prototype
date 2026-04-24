# Redirect-Stub Debt Burndown 2026-03-06
_Audience: Docs Lead + Domain Owners • Owner: Platform Team • Last verified: 2026-03-06 • Status: supporting_

## Snapshot
- Baseline debt: 81
- Current debt: 0
- Reduction achieved: 81 (100.00%)

## What Was Reduced In This Batch
- Reclassified historical archive review artifacts from `superseded` to `archive-candidate`.
- Reclassified legacy observability QA historical docs from superseded wording to archive-candidate wording.
- Tightened catalog status inference to avoid false positives from body text containing `(superseded)`.
- Reclassified redundant legacy CI/CD compatibility shims in `docs/ci-cd/*` from `superseded` to `archive-candidate` (canonical authority remains in `docs/ops/ci-cd/*`).
- Reclassified low-inbound legacy operations superseded shims (`docs/operations/*`) to `archive-candidate` where canonical authority already exists in `docs/ops/**`.
- Reclassified low-inbound legacy branding, secrets, and status compatibility shims to `archive-candidate` after confirming no active inbound dependency.

## Remaining Debt by Domain (Approx)
- `operations/*`: 0
- `branding/*`: 0
- `ci-cd/*`: 0
- `other`: 0

## Planned Reduction Waves
1. Wave A (`ci-cd/*`): completed for legacy shim reclassification (`77 -> 74 -> 66`).
2. Wave B (`branding/*`): completed after AGENTS/script dependency updates and shim reclassification.
3. Wave C (`operations/*`): completed after script/workflow dependency updates and final reclassification (`27 -> 0`).

## Risk Controls
- No hard deletes.
- Move + link updates in same change set.
- Validate changed-scope links before merge.
- Keep one transitional index stub per retired legacy tree until inbound links are burned down.

## Decisions Needed
- Confirm whether `>=25%` debt reduction is measured from baseline `81` or rolling sprint start.
