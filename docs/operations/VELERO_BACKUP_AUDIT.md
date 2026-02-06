# Velero Backup Audit (End-to-End)
_Audience: SRE + Platform Ops • Owner: Infra • Last updated: 2026-02-06_

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

For a PVC inventory of the hourly critical schedule:
```bash
./scripts/qa/list-critical-backup-pvcs.sh
```

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
- `CronJob/restore-test` uses image `velero/velero:*` but tries to execute `/bin/bash`.
- The `velero/velero` image does not ship `/bin/bash`, so the job fails with StartError.

Fix options:
1. Use an image that includes a shell + tooling and can run a script (recommended).
2. Rewrite the restore drill to be “no-shell” (pure `velero` CLI, no `bash/jq`), and keep it extremely small.

Note: Velero itself is GitOps-managed outside this repo. Capture the fix as a PR in the infra repo that owns Velero.

### 3) DBs on `emptyDir` (no persistence)
Velero cannot protect app data that isn’t on a PV.

Example: in **kind dev** we may run an in-cluster MongoDB for the forum to avoid Atlas allowlist drift.
If you deploy MongoDB without a PVC (e.g., `emptyDir`), any data is **ephemeral** and not protected by Velero snapshots.

Fix:
- Prefer: move modulestore to Atlas (target architecture).
- Alternative (dev-only): attach a PVC-backed volume to MongoDB before importing anything you care about.

## Recommended Cadence

- Daily: `backup-verification` CronJob in `velero` namespace.
- Monthly: restore drill into a throwaway namespace and validate (must be green).
- Before any risky operation (storage changes): `pre-op` backup with `--wait`.

## Related Docs

- DR overview: `docs/operations/DISASTER_RECOVERY.md`
- Coverage matrix: `docs/operations/BACKUP_COVERAGE_MATRIX.md`
- Platform auth audit: `scripts/qa/audit-auth-access.sh`
