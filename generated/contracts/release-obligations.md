# Wave 6 Release Obligations

- Range: `origin/main...HEAD`
- Overall cross-repo verdict: `infra_counterpart_not_required`
- Required counterpart repos: none
- Required reviewers: none

## Service obligations

## Required infra follow-up


## Required evidence and runbook updates

- Evidence artifacts: none
- Runbook surfaces: none

## Required release and promotion notes

- Services requiring release-note treatment: none

## Reviewer checklist

- Confirm whether a counterpart `bbi-infrastructure` PR exists for every `infra_counterpart_required` service.
- Check all `manual_review_required` services for missing exact GitOps file paths before merge.
- Verify runbook and evidence surfaces moved with each deployment-affecting change.
- Treat secret-surface changes as blocked until security and platform review are present.

## Ignored surfaces

- `docs/meta/docs-program/WAVE_RUNBOOKS_ROOT_RESET_TRACKER.md`
