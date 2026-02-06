# Backup Coverage Matrix (Reality-First)
_Audience: SRE + Platform Ops • Last updated: 2026-02-06_

This document answers one question: **if we lose a node/zone/cluster, what data do we lose, and how do we restore it?**

## One Command Posture Audit

```bash
./scripts/qa/audit-velero.sh --json | jq .
```

## Critical State Inventory (Production)

### In-cluster (should be protected by Velero snapshots)

| Component | Namespace | Storage | Source of truth | Backup mechanism | How to prove it |
|---|---|---|---|---|---|
| MySQL | `mereka-lms` | PVC (`mysql`) | In-cluster MySQL | Velero VolumeSnapshots (hourly critical schedule) | `./scripts/qa/audit-velero.sh` shows snapshots; `./scripts/qa/list-critical-backup-pvcs.sh` lists PVC |
| Redis | `mereka-lms` | PVC (`redis`) | In-cluster Redis | Velero VolumeSnapshots | Same as above |
| Elasticsearch | `mereka-lms` | PVC (`elasticsearch`) | In-cluster ES | Velero VolumeSnapshots (daily/weekly) | Same as above |
| Authentik Postgres | `authentik` | PVC | Authentik DB | Velero VolumeSnapshots | `./scripts/qa/list-critical-backup-pvcs.sh` |
| Authentik Redis | `authentik` | PVC | Authentik sessions/cache | Velero VolumeSnapshots | `./scripts/qa/list-critical-backup-pvcs.sh` |
| Infisical Postgres | `infisical` | PVC | Secrets DB | Velero VolumeSnapshots | `./scripts/qa/list-critical-backup-pvcs.sh` |
| Infisical Redis | `infisical` | PVC | Cache/queues | Velero VolumeSnapshots | `./scripts/qa/list-critical-backup-pvcs.sh` |
| n8n Postgres + storage | `n8n` | PVCs | n8n DB + data | Velero VolumeSnapshots | `./scripts/qa/list-critical-backup-pvcs.sh` |

### External / managed (not protected by Velero)

| Component | Source of truth | Backup mechanism | Notes |
|---|---|---|---|
| MongoDB Atlas (forum) | Atlas | Atlas snapshots (must be enabled + verified) | Velero does not back up Atlas data. |
| DNS (Cloudflare) | `infrastructure/cloudflare/*.json` + provider | Git (config) | Restored by re-applying config + verifying. |
| Container images | Artifact Registry | Registry retention policy | Not a Velero concern; but required for full rebuild. |

## Known Gaps (As Of 2026-02-06)

1. **Accidental local MongoDB risk (dev-only):** We have legacy/optional in-cluster MongoDB manifests and a `mongodb` Service.
   - Production should use Atlas (see `docs/adr/001-mongodb-atlas.md`).
   - In kind dev, the forum may target in-cluster MongoDB; do not rely on it for durable course content.
2. **Restore drill broken:** `velero/restore-test` CronJob uses `velero/velero:*` but tries `/bin/bash`, causing StartError.

## Proof: What Must Match

1. List Bound PVCs included in the hourly critical schedule:
```bash
./scripts/qa/list-critical-backup-pvcs.sh
```

2. The latest hourly backup should have `volumeSnapshotsCompleted` at least as large as the Bound PVC count above:
```bash
kubectl -n velero get backup -o json | jq -r '
  [.items[]
   | select(.metadata.labels["velero.io/schedule-name"]=="velero-local-hourly-critical-databases")
   | select(.status.phase=="Completed")]
  | sort_by(.status.completionTimestamp)
  | last
  | {name:.metadata.name, completed:.status.completionTimestamp, snapshots_completed:(.status.volumeSnapshotsCompleted//0)}
'
```

If the numbers don’t line up, treat it as a backup coverage incident until explained.
