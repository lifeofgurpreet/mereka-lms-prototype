# Aspects Analytics Setup Reference
_Audience: Platform Operators • Owner: Platform Team • Last verified: 2026-03-10 • Status: canonical_

This reference records the current setup truth for the Aspects analytics stack.

## Current state

- Aspects is not deployed in production.
- The repo carries manifests under `deploy/k8s/base/plugins/aspects/`.
- Those manifests are intentionally not wired into the active base kustomization.
- Production rollout remains gated by [`../../concepts/analytics/ASPECTS_TARGET_STATE.md`](../../concepts/analytics/ASPECTS_TARGET_STATE.md) and [`../../policies/architecture/ANALYTICS_DECISION_GATE.md`](../../policies/architecture/ANALYTICS_DECISION_GATE.md).
- No governed shared-environment analytics publish or promotion lane exists
  today.

## What exists already

- ClickHouse, Superset, Superset worker, jobs, ingress, and config manifests exist in the repo.
- Wiring prerequisites are checked by:
  - `scripts/qa/verify-aspects-analytics.sh`
  - `scripts/qa/verify-aspects-wiring.sh`
- Target-state rollout procedures, once the decision gate changes and release
  authority is explicitly defined, are documented in
  [`../../ops/runbooks/architecture/SUPERSET_DEPLOYMENT_RUNBOOK.md`](../../ops/runbooks/architecture/SUPERSET_DEPLOYMENT_RUNBOOK.md).

## What is missing for deployment

- ExternalSecret wiring for the Aspects secret set.
- Overlay wiring into the chosen environment.
- Runtime validation for ClickHouse, Superset, and dashboard access.
- Shared-environment release authority and a governed publish/promotion front
  door.
- An explicit decision change if the current deferred posture changes.

Until those gaps are closed, any direct Tutor or `kubectl` rollout sequence in
a shared environment is legacy/manual bootstrap rather than the canonical
operator path.

## Read next

- [`../../concepts/analytics/CURRENT_ANALYTICS_STATE.md`](../../concepts/analytics/CURRENT_ANALYTICS_STATE.md)
- [`../../concepts/analytics/ASPECTS_TARGET_STATE.md`](../../concepts/analytics/ASPECTS_TARGET_STATE.md)
- [`../../ops/runbooks/ASPECTS_WIRING_CHECKLIST.md`](../../ops/runbooks/ASPECTS_WIRING_CHECKLIST.md)
- [`../../ops/runbooks/architecture/SUPERSET_DEPLOYMENT_RUNBOOK.md`](../../ops/runbooks/architecture/SUPERSET_DEPLOYMENT_RUNBOOK.md)
