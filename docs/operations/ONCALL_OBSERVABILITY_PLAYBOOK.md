# On-Call Observability Playbook
_Audience: Incident responders • Last updated: 2026-02-06_

Use this sequence to understand platform health quickly.

## Step 1: External Impact

```bash
CHECK_CERTS=1 ./scripts/qa/public-health-check.sh prod
```

If this fails, user-facing impact is likely.

## Step 2: Monitoring Coverage Sanity

```bash
./scripts/qa/audit-observability.sh --mode runtime
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
- MySQL/Redis connection errors:
  - check pod readiness/restarts
  - confirm service endpoints
  - verify config drift (hosts/ports)
- Velero verification/restore-test failures:
  - inspect `velero` CronJob/job logs
  - run `./scripts/qa/audit-velero.sh`
- Auth/TLS synthetic failures:
  - run auth/cert verify scripts and check redirect/cert drift

## Step 5: Evidence Bundle

Attach:
- `audit-observability` JSON output
- `public-health-check` output
- relevant dashboard screenshots
- any `audit-velero` output if data-risk
