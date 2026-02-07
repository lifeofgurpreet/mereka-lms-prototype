# On-Call Observability Playbook
_Audience: Incident responders • Last updated: 2026-02-07_

Use this sequence to understand platform health quickly.

## Step 1: External Impact

```bash
CHECK_CERTS=1 ./scripts/qa/public-health-check.sh prod
```

If this fails, user-facing impact is likely.

## Step 2: Monitoring Coverage Sanity

```bash
./scripts/qa/audit-observability.sh --mode runtime
./scripts/qa/audit-velero-alert-pipeline.sh
./scripts/qa/audit-grafana-dashboard.sh --strict-required
./scripts/qa/run-operations-gates.sh --env both
```

If this fails, monitoring blind spots may exist; fix coverage first.

## Step 3: Core Dashboards

Open in order:
1. `Mereka LMS - Public Endpoints`
2. `Mereka LMS - Operations Signals`
3. `Mereka LMS - GKE`
4. `Mereka LMS - Auth`

## Step 4: Fast Branching by Signal

- Storage signal (`stateful-storage-errors`):
  - inspect MySQL/Redis/Elasticsearch logs
  - check PVC status and free capacity
  - follow DR runbook if data-risk
- Saturation signal (`mysql-saturation-high` / `redis-saturation-high`):
  - inspect CPU/memory request utilization trends in `operations-signals`
  - correlate with pod restarts and connection-error spikes
  - scale resources or reduce pressure before user-facing failures
- MySQL/Redis connection errors:
  - check pod readiness/restarts
  - confirm service endpoints
  - verify config drift (hosts/ports)
- Velero verification/restore-test failures:
  - inspect `velero` CronJob/job logs
  - run `./scripts/qa/audit-velero.sh`
  - run `./scripts/qa/audit-velero-alert-pipeline.sh`
- Atlas allowlist drift (dev/forum risk):
  - run `./scripts/qa/audit-atlas-allowlist-monitor.sh`
  - run strict routing check: `STRICT_WEBHOOK=1 ./scripts/qa/audit-atlas-allowlist-monitor.sh`
  - remediate with `./scripts/infra/ensure-atlas-allowlist-vps.sh` and re-run monitor/audit
- Velero stale-success signal (`velero-*-stale`):
  - confirm `lastSuccessfulTime` for `backup-verification` and `restore-test`
  - run strict freshness checks: `STRICT_RUNTIME=1 ./scripts/qa/audit-velero-alert-pipeline.sh`
  - inspect `velero` CronJob history and recent job logs
  - treat as data-risk until success signal is restored
- CrashLoopBackOff / Pending pods / unavailable critical deployments:
  - check `kubectl get pods -n mereka-lms` for stuck/pending pods
  - check `kubectl get deploy -n mereka-lms` and unavailable replicas
  - inspect rollout history/events and recent image/config changes
- Synthetic/backup job failures (`auth-verify-prod`, `cert-verify-prod`, `backup-verification`, `restore-test`):
  - inspect failed jobs: `kubectl get jobs -A | rg 'auth-verify|cert-verify|backup-verification|restore-test'`
  - inspect logs for latest failed run in owning namespace
  - restore success signals before closing incident
- Auth/TLS synthetic failures:
  - run auth/cert verify scripts and check redirect/cert drift

## Step 5: Evidence Bundle

Attach:
- `audit-observability` JSON output
- `audit-velero-alert-pipeline` output
- `public-health-check` output
- relevant dashboard screenshots
- any `audit-velero` output if data-risk
