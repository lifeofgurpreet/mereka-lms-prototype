# Aspects Analytics Setup Reference
_Audience: Platform Operators • Owner: Platform Team • Last verified: 2026-03-10 • Status: canonical_

This reference records the current setup truth for the Aspects analytics stack.

## Current state

- The repo carries manifests under `deploy/k8s/base/plugins/aspects/`.
- Those manifests are intentionally not wired into the active base kustomization.
- Shared nonprod environments consume the Aspects package via environment overlays / GitOps realization.
- Dev and staging currently run ClickHouse, Ralph, and Superset.
- Production rollout remains gated by [`../../concepts/analytics/ASPECTS_TARGET_STATE.md`](../../concepts/analytics/ASPECTS_TARGET_STATE.md) and [`../../policies/architecture/ANALYTICS_DECISION_GATE.md`](../../policies/architecture/ANALYTICS_DECISION_GATE.md).
- No governed production analytics publish or promotion lane exists today.

## What exists already

- ClickHouse, Superset, Superset worker, init jobs, recurring sync jobs, ingress, and config manifests exist in the repo.
- Repo/static prerequisites are checked by:
  - `scripts/qa/verify-aspects-analytics.sh`
  - `scripts/qa/verify-aspects-wiring.sh`
- Live data-path proof is checked by:
  - `scripts/aspects/verify-aspects-data-pipeline.sh`
- Target-state rollout procedures, once the decision gate changes and release authority is explicitly defined, are documented in
  [`../../ops/runbooks/architecture/SUPERSET_DEPLOYMENT_RUNBOOK.md`](../../ops/runbooks/architecture/SUPERSET_DEPLOYMENT_RUNBOOK.md).

## What is missing for deployment

- Durable production activation and production runtime proof.
- Shared-environment release authority and a governed production publish/promotion front door.
- Continuous verification that `event_sink.*` dimensional tables stay fresh without manual backfills.
- An explicit production decision change if the current deferred posture changes.

Until those gaps are closed, any direct Tutor or `kubectl` rollout sequence in
a shared environment is legacy/manual bootstrap rather than the canonical
operator path.

## Read next

- [`../../concepts/analytics/CURRENT_ANALYTICS_STATE.md`](../../concepts/analytics/CURRENT_ANALYTICS_STATE.md)
- [`../../concepts/analytics/ASPECTS_TARGET_STATE.md`](../../concepts/analytics/ASPECTS_TARGET_STATE.md)
- [`../../ops/runbooks/ASPECTS_WIRING_CHECKLIST.md`](../../ops/runbooks/ASPECTS_WIRING_CHECKLIST.md)
- [`../../ops/runbooks/architecture/SUPERSET_DEPLOYMENT_RUNBOOK.md`](../../ops/runbooks/architecture/SUPERSET_DEPLOYMENT_RUNBOOK.md)
