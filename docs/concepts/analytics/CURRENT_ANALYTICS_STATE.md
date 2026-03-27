# Current Analytics State
_Audience: Platform Eng + Data • Owner: Analytics Guild • Last verified: 2026-03-10 • Status: canonical_

This document records the analytics surfaces that are live now. It is the current-state truth doc for analytics.

## What is running

- Prometheus and Grafana for infrastructure and runtime monitoring.
- Open edX instructor reports for course-level exports and grade/enrollment reporting.
- Scripted reconciliation for migration work, where needed, from the reference analytics surfaces.

## What is not running

- Aspects and Superset for learning analytics.
- Panorama or any other third-party analytics platform.
- Public analytics endpoints or dashboards for tenant admins.

## Current operator guidance

- Use Grafana and Prometheus for service health, request rates, and cluster metrics.
- Use the LMS instructor dashboard for per-course enrollment, progress, and grade exports.
- Use migration reference docs under `docs/reference/analytics/**` only for reconciliation or migration analysis, not as the steady-state analytics front door.
- Do not treat target-state analytics runbooks or setup references as a
  shared-environment release front door; no governed analytics publish or
  promotion lane exists today.

## Current access rules

- There is no supported production access flow for Superset because Superset is not deployed.
- Any local-only experimentation with Aspects stays local and does not change production truth.
- Any direct Tutor or `kubectl` rollout in a shared environment would be a
  documented legacy/manual bootstrap exception, not the canonical operator
  path.

## Related docs

- [`ASPECTS_TARGET_STATE.md`](ASPECTS_TARGET_STATE.md)
- [`ANALYTICS_TOOL_COMPARISON.md`](ANALYTICS_TOOL_COMPARISON.md)
- [`../../programs/analytics/ANALYTICS_DEPLOYMENT_POLICY.md`](../../programs/analytics/ANALYTICS_DEPLOYMENT_POLICY.md)
