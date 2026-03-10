# Analytics Concepts
_Audience: Platform Eng + Data • Owner: Analytics Guild • Last verified: 2026-03-10 • Status: canonical_

This root explains the analytics model and the difference between current runtime truth and future analytics deployment work.

## Current truth

- Prometheus and Grafana are the active observability surfaces for platform metrics.
- Open edX built-in instructor reports are the active course-level analytics surface.
- Aspects and Superset are not deployed in production.
- Panorama is not deployed or selected as the platform analytics winner.

## Read in this order

1. [`CURRENT_ANALYTICS_STATE.md`](CURRENT_ANALYTICS_STATE.md)
2. [`ASPECTS_TARGET_STATE.md`](ASPECTS_TARGET_STATE.md)
3. [`ANALYTICS_TOOL_COMPARISON.md`](ANALYTICS_TOOL_COMPARISON.md)

## Supporting reference

- [`../../reference/analytics/DATA_SOURCES_EXPLAINED.md`](../../reference/analytics/DATA_SOURCES_EXPLAINED.md)
- [`../../reference/analytics/ENROLLMENT_COMPARISON_QUICKSTART.md`](../../reference/analytics/ENROLLMENT_COMPARISON_QUICKSTART.md)
- `docs/ops/runbooks/migrations/kajabi/**` for the migration execution path that feeds reconciliation work
