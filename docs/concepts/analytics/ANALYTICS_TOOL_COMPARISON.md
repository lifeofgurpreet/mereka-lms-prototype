# Analytics Tool Comparison
_Audience: Leadership + Platform Eng • Owner: Analytics Guild • Last verified: 2026-03-10 • Status: canonical_

This document compares the candidate learning-analytics paths without pretending that any future-state tool is already deployed.

## Current winner

- Current live analytics for learning operations: built-in Open edX instructor reporting.
- Current live observability for platform health: Prometheus and Grafana.
- Preferred future-state learning analytics candidate: Aspects.
- Panorama remains an optional comparison point, not an active platform commitment.

## Comparison summary

| Need | Current answer | Preferred future-state | Notes |
| --- | --- | --- | --- |
| Per-course reports | Open edX instructor reports | Open edX instructor reports + Aspects | Current production path already exists |
| Platform-wide learning analytics | Not deployed | Aspects | Native Open edX option |
| Commercial analytics overlay | Not used | Panorama only if Aspects proves insufficient | Not currently selected |
| Infrastructure monitoring | Prometheus/Grafana | Prometheus/Grafana | Separate from learner analytics |

## Decision guidance

- Use built-in Open edX reports when the question is course-specific and current-state.
- Use Aspects as the target-state planning baseline for platform-wide learning analytics.
- Treat Panorama as a comparison option only if Aspects cannot satisfy the product requirement.

## Related docs

- [`CURRENT_ANALYTICS_STATE.md`](CURRENT_ANALYTICS_STATE.md)
- [`ASPECTS_TARGET_STATE.md`](ASPECTS_TARGET_STATE.md)
- [`../../programs/analytics/ANALYTICS_DEPLOYMENT_POLICY.md`](../../programs/analytics/ANALYTICS_DEPLOYMENT_POLICY.md)
