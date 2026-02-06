# Observability Quickstart
_Audience: On-call / Operators • Last updated: 2026-02-06_

Use this when you need a fast answer to: "Is Mereka LMS healthy right now?"

## 1) Fast Checks (2-3 minutes)

```bash
# Public surfaces + certs
CHECK_CERTS=1 ./scripts/qa/public-health-check.sh prod

# Monitoring config integrity (repo-local)
./scripts/qa/audit-observability.sh --mode local

# Runtime monitoring objects + synthetic cronjobs (requires cluster + gcloud auth)
./scripts/qa/audit-observability.sh --mode runtime
```

## 2) Core Dashboards

GCP Monitoring dashboards (managed from `infrastructure/monitoring/dashboards/`):
- `Mereka LMS - Public Endpoints`
- `Mereka LMS - Auth`
- `Mereka LMS - GKE`
- `Mereka LMS - Operations Signals`

Primary signals to watch first:
- Uptime dips on LMS/Studio/Apps or microsites
- `operations-signals` spikes for:
  - MySQL/Redis CPU and memory request utilization
  - Stateful storage errors
  - MySQL connection errors
  - Redis connection errors
  - Velero backup verification success/failure and restore-test success/failure
  - Velero backup verification failures
  - Velero restore-test failures

## 3) Alert Categories

Critical:
- TLS cert expiry
- Stateful storage errors
- Velero restore-test failures
- Velero backup verification failures
- Velero backup verification stale (no success in 30h)
- Velero restore-test stale (no success in 45d)

Warning:
- Pod restarts
- PVC utilization high
- MySQL saturation high
- Redis saturation high
- MySQL/Redis connection error spikes

## 4) Apply / Update Monitoring

```bash
./scripts/infra/apply-monitoring-configs.sh plan
./scripts/infra/apply-monitoring-configs.sh apply
```

Legacy-only templates (Cloud SQL) are skipped by default:

```bash
INCLUDE_LEGACY_MONITORING=1 ./scripts/infra/apply-monitoring-configs.sh apply
```

## 5) Incident Triage Order

1. Confirm public impact with `public-health-check.sh`.
2. Check Operations Signals dashboard for storage / DB / cache / Velero indicators.
3. Inspect pod restarts and service logs (`kubectl logs -n mereka-lms deployment/<svc>`).
4. If storage or data risk is involved, follow `docs/operations/DISASTER_RECOVERY.md` and `docs/operations/VELERO_BACKUP_AUDIT.md`.
