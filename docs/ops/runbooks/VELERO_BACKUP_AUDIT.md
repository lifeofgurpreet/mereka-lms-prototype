# Velero Backup Audit (End-to-End)
_Audience: SRE + Platform Ops • Owner: Infra • Last updated: 2026-02-07_

This document defines the **backup posture audit** we run to ensure:
- backups are actually being created (not just manifests)
- backups include the critical namespaces
- restore drills are not silently broken
- app-level storage configs are not defeating backups (e.g., DBs on `emptyDir`)

## One Command Audit

Run this from the repo root (prod by default):
```bash
./scripts/qa/audit-velero.sh --json | jq .
```

Non-JSON:
```bash
./scripts/qa/audit-velero.sh
```

Velero alert pipeline + runtime freshness/recency coverage:
```bash
./scripts/qa/audit-velero-alert-pipeline.sh
STRICT_RUNTIME=1 ./scripts/qa/audit-velero-alert-pipeline.sh --json | jq .
```

For a PVC inventory of the hourly critical schedule:
```bash
./scripts/qa/list-critical-backup-pvcs.sh
```

To collect an evidence bundle (files under `var/`, gitignored):
```bash
./scripts/qa/collect-velero-evidence.sh
```

Preferred monthly evidence bundle command (includes strict runtime audits + tarball):
```bash
STRICT_RUNTIME=1 ./scripts/qa/build-dr-evidence-bundle.sh --tar
```

GitHub Actions automation:
- `.github/workflows/dr-evidence-bundle.yml` (monthly schedule + manual dispatch, uploads bundle artifact)

## What “Good” Looks Like

1. `BackupStorageLocation` phase is `Available`.
2. Schedules exist for:
   - **hourly critical databases** (`mereka-lms`, `authentik`, etc.)
   - **daily all apps**
   - **weekly full**
3. Recent Completed backups show:
   - `status.volumeSnapshotsAttempted > 0`
   - `status.volumeSnapshotsCompleted > 0`
   - Snapshot count is consistent with the Bound PVC inventory of the included namespaces
4. Restore drill CronJob exists and actually runs successfully (no StartError).
5. Restore drill is configured for PV validation:
   - `RESTORE_PERSISTENT_RESOURCES=true`
   - `REQUIRE_PVC_RESTORE=true`
   - `VERIFY_RESTORED_MYSQL=true`
5. Critical data services do not store state in `emptyDir`.

## Critical Failure Modes We Explicitly Detect

### 1) “Backups succeeded” but volume snapshots are 0
This means you only backed up K8s objects, not PV data.

Fix: ensure schedules have:
- `includeClusterResources: true`
- `volumeSnapshotLocations: ["default"]`

### 2) Restore drill CronJob silently broken
If the restore drill job cannot start (wrong image/command), you will only discover it during a real incident.

In this cluster we observed:
- `CronJob/restore-test` used image `velero/velero:*` but tried to execute `/bin/bash`.
- Cleanup blocked on namespace deletion (`velero-restore-test` stuck `Terminating`), causing long-running jobs.

Fix path (implemented in this repo):
1. Use the repo-managed restore script (`infrastructure/k8s/velero/restore-test-script.sh`) that only depends on `kubectl + jq`.
2. Use non-blocking cleanup in the script so namespace teardown does not wedge the job.
3. Enforce PV-aware restore validation:
   - restore PVC/PV resources (no manifest-only exclusions)
   - fail when no PVC is restored/bound
   - run read-only `SELECT 1` probe against restored MySQL pod when present
4. Repair the restore-test CronJob + ConfigMap in the GitOps repo that owns
   Velero, then run a verification drill and inspect it from this repo:
   ```bash
   STRICT_RUNTIME=1 ./scripts/qa/audit-velero-alert-pipeline.sh
   STRICT=1 ./scripts/qa/verify-restore-drill.sh --namespace velero-restore-test
   ```
5. Confirm freshness:
   ```bash
   OBSERVABILITY_ENV_LABEL=prod OBSERVABILITY_DISPATCH_PROFILE=prod OBSERVABILITY_K8S_CONTEXT=$OBS_PARITY_PROD_K8S_CONTEXT ./scripts/qa/run-observability-first-class.sh --mode runtime --strict
   ```
6. Confirm restore-test config contract:
   ```bash
   ./scripts/qa/audit-velero.sh
   ```

Note: Velero itself is GitOps-managed outside this repo. Capture the fix as a PR in the infra repo that owns Velero.

### 3) DBs on `emptyDir` (no persistence)
Velero cannot protect app data that isn’t on a PV.

Example: in **kind dev** we may run an in-cluster MongoDB for the forum to avoid Atlas allowlist drift.
If you deploy MongoDB without a PVC (e.g., `emptyDir`), any data is **ephemeral** and not protected by Velero snapshots.

Fix:
- Preferred (prod): keep modulestore on Atlas and ensure in-cluster MongoDB is never in the active data path.
- Alternative (dev-only / temporary): attach a PVC-backed volume to MongoDB before importing anything you care about.

`audit-velero.sh` behavior:
- `emptyDir` + modulestore on in-cluster MongoDB => **critical** (fails gate)
- `emptyDir` + modulestore verified on Atlas => **warning** (cleanup still required)

### 4) Restore stale alert window mismatch in Cloud Monitoring
Cloud Monitoring threshold/absence alert conditions are limited to roughly 24h lookback windows.
That means a direct `restore-test success < 1 over 45d` policy is not deployable as a standard
condition.

Current enforcement model:
- `backup-verification` stale signal is handled by GCP policy + runtime checks.
- `restore-test` stale signal is enforced by runtime freshness checks in:
  - `OBSERVABILITY_ENV_LABEL=prod OBSERVABILITY_DISPATCH_PROFILE=prod OBSERVABILITY_K8S_CONTEXT=$OBS_PARITY_PROD_K8S_CONTEXT ./scripts/qa/run-observability-first-class.sh --mode runtime --strict`
  - `./scripts/qa/audit-velero-alert-pipeline.sh`

## Recommended Cadence

- Daily: `backup-verification` CronJob in `velero` namespace.
- Monthly: restore drill into a throwaway namespace and validate (must be green).
- Before any risky operation (storage changes): `pre-op` backup with `--wait`.

Monthly restore-drill evidence checklist:
- `STRICT_RUNTIME=1 ./scripts/qa/build-dr-evidence-bundle.sh --tar`
- attach:
  - `audit-velero.json`
  - `audit-velero-alert-pipeline.json`
  - `observability-compliance-runtime.json`
  - `observability-first-class-runtime-evidence-index.json`
  - `observability-correlation-headers-runtime.txt`
  - `audit-observability-runtime.json` (legacy compatibility alias)
  - latest `restore-test` job logs/describe
  - restored PVC summary (bound count)
  - MySQL probe result from restore job log

## Related Docs

- DR overview: `docs/ops/runbooks/DISASTER_RECOVERY.md`
- Coverage matrix: `docs/reference/operations/BACKUP_COVERAGE_MATRIX.md`
- Platform auth audit: `scripts/qa/audit-auth-access.sh`
