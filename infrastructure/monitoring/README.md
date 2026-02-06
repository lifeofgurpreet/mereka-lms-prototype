# Monitoring-as-Code
_Last updated: 2026-02-06_

This directory is the source of truth for GCP Monitoring templates used by Mereka LMS.

## Structure

- `uptime/`: public endpoint uptime checks (one JSON per check)
- `logging-metrics/`: log-based metric definitions
- `alerts/`: alert policies
- `dashboards/`: GCP Monitoring dashboards

## Apply Flow

```bash
./scripts/infra/apply-monitoring-configs.sh plan
./scripts/infra/apply-monitoring-configs.sh apply
```

Legacy Cloud SQL templates are excluded by default. Include only when intentionally needed:

```bash
INCLUDE_LEGACY_MONITORING=1 ./scripts/infra/apply-monitoring-configs.sh apply
```

## Validation

Repo integrity check:

```bash
./scripts/qa/audit-observability.sh --mode local
```

Runtime deployment coverage check:

```bash
./scripts/qa/audit-observability.sh --mode runtime
```
