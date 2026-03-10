# Aspects Target State
_Audience: Platform Eng + Data • Owner: Analytics Guild • Last verified: 2026-03-10 • Status: canonical_

This document describes the target-state architecture and deployment posture for Aspects. It does not claim that Aspects is deployed now.

## Decision boundary

- Aspects remains the preferred future-state path for platform-wide learning analytics.
- Production deployment stays gated by the analytics deployment policy and readiness checks.
- Any installation or access instructions below are target-state or local-only, not statements about current production.

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

1. Enable and configure the Tutor plugin.
2. Build required images.
3. Apply environment and secret configuration.
4. Deploy services.
5. Validate service health and dashboard availability.
6. Establish a supported access path and run smoke tests.

## Local-only or future-state access

- Local access uses port forwarding or local Tutor service URLs during development.
- Production access does not exist until the readiness gate is satisfied.

## Related docs

- [`CURRENT_ANALYTICS_STATE.md`](CURRENT_ANALYTICS_STATE.md)
- [`ANALYTICS_TOOL_COMPARISON.md`](ANALYTICS_TOOL_COMPARISON.md)
- [`../../reference/architecture/ASPECTS_DEPLOYMENT_READINESS.md`](../../reference/architecture/ASPECTS_DEPLOYMENT_READINESS.md)
- [`../../programs/analytics/ANALYTICS_DEPLOYMENT_POLICY.md`](../../programs/analytics/ANALYTICS_DEPLOYMENT_POLICY.md)
