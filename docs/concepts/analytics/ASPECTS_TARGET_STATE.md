# Aspects Target State
_Audience: Platform Eng + Data • Owner: Analytics Guild • Last verified: 2026-03-10 • Status: canonical_

This document describes the target-state architecture and deployment posture for Aspects. It does not claim that Aspects is deployed now.

## Decision boundary

- Aspects remains the preferred future-state path for platform-wide learning analytics.
- Production deployment stays gated by the analytics deployment policy and readiness checks.
- Any installation or access instructions below are target-state or local-only, not statements about current production.
- No governed shared-environment analytics publish or promotion lane exists
  today. Until one is defined, any Tutor or direct `kubectl` rollout sequence
  must be treated as legacy/manual bootstrap rather than the canonical
  production operator path.

## Target architecture

- Tutor plugin: `tutor-contrib-aspects`
- Services: ClickHouse, Ralph, Superset, worker, beat
- Access model: operator-managed Superset access after deployment
- Data sources: Open edX event streams and course activity data

## Current readiness

- Local plugin/config work exists.
- Production deployment is not complete.
- Production services are not running.
- The deployment/readiness contract lives in [`../../reference/architecture/ASPECTS_DEPLOYMENT_READINESS.md`](../../reference/architecture/ASPECTS_DEPLOYMENT_READINESS.md).

## Deployment shape

1. Define the shared-environment release authority truthfully.
2. Enable and configure the Tutor plugin.
3. Build required images.
4. Apply environment and secret configuration.
5. Deploy services.
6. Validate service health and dashboard availability.
7. Establish a supported access path and run smoke tests.

## Local-only or future-state access

- Local access uses port forwarding or local Tutor service URLs during development.
- Production access does not exist until the readiness gate is satisfied.
- Shared-environment release claims require more than readiness intent: they
  require an approved rollout front door, or an explicitly documented
  legacy/manual bootstrap exception.

## Related docs

- [`CURRENT_ANALYTICS_STATE.md`](CURRENT_ANALYTICS_STATE.md)
- [`ANALYTICS_TOOL_COMPARISON.md`](ANALYTICS_TOOL_COMPARISON.md)
- [`../../reference/architecture/ASPECTS_DEPLOYMENT_READINESS.md`](../../reference/architecture/ASPECTS_DEPLOYMENT_READINESS.md)
- [`../../programs/analytics/ANALYTICS_DEPLOYMENT_POLICY.md`](../../programs/analytics/ANALYTICS_DEPLOYMENT_POLICY.md)
