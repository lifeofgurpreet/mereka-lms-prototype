# Monitoring-as-Code
_Last updated: 2026-02-08_

This directory is the source of truth for GCP Monitoring templates used by Mereka LMS.

## Structure

- `uptime/`: public endpoint uptime checks (one JSON per check)
- `logging-metrics/`: log-based metric definitions
- `alerts/`: alert policies
- `dashboards/`: GCP Monitoring dashboards and Grafana-only dashboard artifacts used for legacy video signals.
  - GCP dashboards are expected by runtime parity (`OBSERVABILITY_ENV_LABEL=nonprod OBSERVABILITY_DISPATCH_PROFILE=nonprod ./scripts/qa/run-observability-first-class.sh --mode runtime --strict`).
  - Grafana-only files are intentionally excluded from parity parity checks unless explicitly opted in.
- `grafana/`: Grafana dashboard coverage contracts (for parity/audit automation)

## Apply Flow

```bash
./scripts/infra/apply-monitoring-configs.sh plan
./scripts/infra/apply-monitoring-configs.sh apply
```

Offline dry-run (no cloud discovery/API calls):

```bash
OFFLINE_PLAN=1 ./scripts/infra/apply-monitoring-configs.sh plan
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
./scripts/qa/run-observability-first-class.sh --mode runtime
```

DB exporter telemetry contract and runtime checks:

```bash
./scripts/qa/audit-db-exporter-telemetry.sh --mode local
STRICT_RUNTIME=1 ./scripts/qa/audit-db-exporter-telemetry.sh --mode runtime
```

Grafana dashboard coverage check:

```bash
./scripts/qa/audit-grafana-dashboard.sh
./scripts/qa/audit-grafana-dashboard.sh --strict-required
./scripts/qa/audit-grafana-dashboard.sh --strict-required --strict-recommended
```

Use strict mode when you want runtime freshness checks to fail hard (for CI gates or audits):

```bash
STRICT_RUNTIME=1 ./scripts/qa/run-observability-first-class.sh --mode runtime --strict
```

## Key Signals Added

- PVC utilization alerting for stateful pods.
- MySQL and Redis saturation alerts (CPU/memory request utilization).
- MySQL/Redis exporter deep telemetry:
  - `threads_connected/max_connections` saturation
  - MySQL slow query spikes
  - Redis rejected connections and eviction spikes
- Velero success/failure log metrics and stale-success alerts.
- `operations-signals` dashboard panels for stateful saturation and backup posture.
- PrometheusRule coverage for CrashLoopBackOff, Pending pods, critical deployment availability, and synthetic/backup job failures.
