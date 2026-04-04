# Release Rollout And Removal
_Audience: Engineering Team • Owner: Platform Team • Last verified: 2026-04-04 • Status: detailed-reference_

> **Classification**: policy/reference detail.
>
> Canonical build→promotion→realization→proof workflow is owned by:
> [../../architecture/PROMOTION_REALIZATION_AND_INCIDENT_FLOW.md](../../architecture/PROMOTION_REALIZATION_AND_INCIDENT_FLOW.md)
>
> This file remains useful for rollout/removal policy standards and fitness checks.

## Governs

- platform.change-policy
- build.gitops-promotion

## Non-goals

- backlog prioritization
- incident triage procedures

## Standard

- Feature flags must declare owner, rollout intent, rollback path, and removal condition.
- Deprecated paths must carry explicit sunset and removal tracking.
- Temporary exceptions require expiry and removal evidence.
- Release changes must leave proof in evidence artifacts rather than inside decision bodies.

## Fitness Functions

- `scripts/qa/verify_exception_expiry.py`
- `tools/docs/verify/verify-docs-policy.sh`

## Source ADRs

- `ADR-030`
- `ADR-031`
