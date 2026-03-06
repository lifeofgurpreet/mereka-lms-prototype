# Monitoring Dashboard Remediation Plan Evidence

Date: 2026-02-26
Lane: runtime parity recovery planning
Owner: mereka-lms observability

## Objective
- Produce a deterministic, non-mutating remediation plan for missing GCP dashboard parity in dev/nonprod/prod.
- Capture exact commands that must be executed by env owner to restore dashboard objects.

## Command run
```bash
OFFLINE_PLAN=1 ./scripts/infra/apply-monitoring-configs.sh plan
```

## Plan output summary
- Exit code: `0`
- Generated commands: `62`
- Includes explicit create commands for all monitoring assets in:
  - `infrastructure/monitoring/uptime/*.json`
  - `infrastructure/monitoring/logging-metrics/*.json`
  - `infrastructure/monitoring/alerts/*.json` (excluding known legacy/unsupported templates per existing script logic)
  - `infrastructure/monitoring/dashboards/*.json` including:
    - `infrastructure/monitoring/dashboards/openedx-slo-dashboard.json`
    - `infrastructure/monitoring/dashboards/video-cost.json`
    - `infrastructure/monitoring/dashboards/video-operations.json`

## Evidence snippet (relevant lines)
- `gcloud monitoring dashboards create --config-from-file='/home/gurpreet/projects/k8s/mereka-lms/infrastructure/monitoring/dashboards/openedx-slo-dashboard.json' --project='mereka-lms'`
- `gcloud monitoring dashboards create --config-from-file='/home/gurpreet/projects/k8s/mereka-lms/infrastructure/monitoring/dashboards/video-cost.json' --project='mereka-lms'`
- `gcloud monitoring dashboards create --config-from-file='/home/gurpreet/projects/k8s/mereka-lms/infrastructure/monitoring/dashboards/video-operations.json' --project='mereka-lms'`

## Recommended execution sequence
1. Set explicit target lane context/project in CI or runbook (already documented in parity matrix).
2. Re-run in apply mode against the lane, with backups/approvals as required:
   ```bash
   ./scripts/infra/apply-monitoring-configs.sh apply
   ```
3. Run strict runtime parity for that lane:
   ```bash
   ./scripts/qa/audit-observability.sh --mode runtime --json
   ```
4. Mark `OBS-051` complete only after parity passes for all non-local lanes where missing object was reported.
