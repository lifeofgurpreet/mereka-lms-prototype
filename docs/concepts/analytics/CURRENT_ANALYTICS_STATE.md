# Current Analytics State
_Audience: Platform Eng + Data • Owner: Analytics Guild • Last verified: 2026-03-10 • Status: canonical_

This document records the analytics surfaces that are live now. It is the current-state truth doc for analytics.

## What is running

- Prometheus and Grafana for infrastructure and runtime monitoring.
- Open edX instructor reports for course-level exports and grade/enrollment reporting.
- Scripted reconciliation for migration work, where needed, from the reference analytics surfaces.
- Aspects analytics on shared nonprod:
  - dev (`mereka-lms-dev`) has ClickHouse, Ralph, Superset, and imported dashboards.
  - staging (`stg-mereka-lms`) has ClickHouse, Ralph, Superset, and imported dashboards.

## What is not running

- Production Aspects/Superset as an active tenant-admin analytics front door.
- Panorama or any other third-party analytics platform.
- A fully governed production analytics publish/promotion lane.

## Current operator guidance

- Use Grafana and Prometheus for service health, request rates, and cluster metrics.
- Use the LMS instructor dashboard for per-course enrollment, progress, and grade exports.
- Treat shared nonprod Aspects as operational, but keep production claims separate until production realization and runtime proof exist.
- Do not treat target-state analytics runbooks or setup references as a production release front door until the production lane is explicitly governed.

## Current access rules

- Shared nonprod Superset access is supported for operational validation and dashboard work.
- There is no supported production tenant-admin analytics access flow until production activation is realized and proved.
- Any local-only experimentation with Aspects stays local and does not change shared-environment truth.
- Any direct Tutor or `kubectl` rollout in a shared environment is still legacy/manual bootstrap unless it is captured in Git and realized through GitOps.

## Related docs

- [`ASPECTS_TARGET_STATE.md`](ASPECTS_TARGET_STATE.md)
- [`ANALYTICS_TOOL_COMPARISON.md`](ANALYTICS_TOOL_COMPARISON.md)
- [`../../programs/analytics/ANALYTICS_DEPLOYMENT_POLICY.md`](../../programs/analytics/ANALYTICS_DEPLOYMENT_POLICY.md)
