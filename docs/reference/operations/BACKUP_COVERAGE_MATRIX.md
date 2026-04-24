# Backup Coverage Matrix (Reality-First)
_Audience: SRE + Platform Ops • Last updated: 2026-04-08_

This document answers one question: **if we lose a node/zone/cluster, what data do we lose, and how do we restore it?**

## One Command Posture Audit

```bash
./scripts/qa/audit-velero.sh --json | jq .
```

---

## Velero Schedule Names

Three Velero schedules protect the cluster:

| Schedule Name | Frequency | Namespaces | Purpose |
|---|---|---|---|
| `hourly-critical` | Every 1 hour | `mereka-lms`, `authentik`, `infisical` | Critical PVC snapshots (MySQL, payments PG, auth) |
| `daily-all-apps` | Daily 02:00 UTC | All non-system namespaces | Full app namespace resource + PVC backup |
| `weekly-full` | Weekly Sunday 03:00 UTC | All namespaces (including system) | Complete cluster-wide disaster recovery baseline |

---

## Data Stores — Full Coverage Table

### In-Cluster State (Protected by Velero)

| Data Store | Namespace | Storage | Backup Method | Schedule | Frequency | Retention | RPO | RTO | Proof Command |
|---|---|---|---|---|---|---|---|---|---|
| MySQL (LMS/CMS) | `mereka-lms` | PVC `mysql` | Velero VolumeSnapshot | `hourly-critical` | 1 hour | 72 hours | 1 hour | 30 min | `./scripts/qa/audit-velero.sh` |
| Redis (cache/Celery) | `mereka-lms` | PVC `redis` | Velero VolumeSnapshot | `hourly-critical` | 1 hour | 72 hours | 1 hour | 30 min | `./scripts/qa/list-critical-backup-pvcs.sh` |
| PostgreSQL (Purchase Gateway) | `mereka-lms` | PVC `postgresql-payments-data` | Velero VolumeSnapshot | `hourly-critical` | 1 hour | 72 hours | 1 hour | 30 min | `./scripts/qa/audit-velero.sh` |
| Authentik PostgreSQL | `authentik` | PVC | Velero VolumeSnapshot | `hourly-critical` | 1 hour | 72 hours | 1 hour | 30 min | `./scripts/qa/list-critical-backup-pvcs.sh` |
| Authentik Redis | `authentik` | PVC | Velero VolumeSnapshot | `hourly-critical` | 1 hour | 72 hours | 1 hour | 30 min | `./scripts/qa/list-critical-backup-pvcs.sh` |
| Infisical PostgreSQL | `infisical` | PVC | Velero VolumeSnapshot | `daily-all-apps` | 24 hours | 7 days | 24 hours | 1 hour | `./scripts/qa/list-critical-backup-pvcs.sh` |
| Infisical Redis | `infisical` | PVC | Velero VolumeSnapshot | `daily-all-apps` | 24 hours | 7 days | 24 hours | 1 hour | `./scripts/qa/list-critical-backup-pvcs.sh` |
| n8n PostgreSQL + data | `n8n` | PVCs | Velero VolumeSnapshot | `daily-all-apps` | 24 hours | 7 days | 24 hours | 2 hours | `./scripts/qa/list-critical-backup-pvcs.sh` |
| Meilisearch index | `mereka-lms` | PVC | Velero VolumeSnapshot | `daily-all-apps` | 24 hours | 7 days | 24 hours | 2 hours | `kubectl get pvc -n mereka-lms` |

### External / Managed (NOT Protected by Velero)

| Data Store | Backup Method | Frequency | Retention | RPO | RTO | Notes |
|---|---|---|---|---|---|---|
| MongoDB Atlas (forum + modulestore) | Atlas continuous cloud backup | Continuous (point-in-time) | 2 days continuous, 30 days snapshots | 1 hour | 2 hours | Atlas manages all snapshots. Velero cannot back up Atlas data. |
| Media files / S3 (Minio/GCS) | GCS bucket replication + object versioning | Continuous | Per GCS retention policy | Near-zero | 1 hour | Stored in GCS; not in PVCs. Velero not applicable. |
| DNS records (Cloudflare) | Git (`infrastructure/cloudflare/*.json`) | On every change | Git history | Minutes | 30 min | Restored by re-applying Cloudflare config from git. |
| Container images (GHCR) | GHCR registry retention policy | Per push | 90 days (tagged), 30 days (untagged) | N/A | N/A | Images not a Velero concern; required for full cluster rebuild. |
| Infisical secrets (source of truth) | Infisical SaaS HA + GCP Secret Manager mirror | Continuous | Indefinite | Near-zero | 30 min | Double-redundant: Infisical + GCP SM mirror. |

---

## PVC Snapshot Status

PVCs included in the `hourly-critical` Velero schedule:

```bash
# List all Bound PVCs covered by the hourly-critical schedule:
./scripts/qa/list-critical-backup-pvcs.sh

# Verify the latest backup snapshot count matches expected PVC count:
kubectl -n velero get backup -o json | jq -r '
  [.items[]
   | select(.metadata.labels["velero.io/schedule-name"]=="velero-local-hourly-critical-databases")
   | select(.status.phase=="Completed")]
  | sort_by(.status.completionTimestamp)
  | last
  | {name:.metadata.name, completed:.status.completionTimestamp, snapshots_completed:(.status.volumeSnapshotsCompleted//0)}
'
```

If `volumeSnapshotsCompleted` is less than the expected PVC count, treat it as a backup coverage incident.

---

## What IS Covered

- All stateful in-cluster workloads with PVCs in `mereka-lms`, `authentik`, `infisical`, `n8n`
- K8s resource definitions (Deployments, Services, ConfigMaps, Secrets) for all namespaces
- MySQL course + user data (hourly RPO)
- PostgreSQL payments data (hourly RPO)
- Redis state (hourly RPO — primarily a cache; loss is tolerated)
- Auth (Authentik) state (hourly RPO)
- Secrets management state (Infisical, hourly RPO)

## What is NOT Covered

| Gap | Reason | Mitigation |
|---|---|---|
| MongoDB Atlas data | External managed service; Velero cannot reach Atlas | Atlas automated continuous backup (managed by Atlas) |
| Media/S3 files | Stored in GCS object storage, not PVCs | GCS bucket replication + object versioning |
| Cloudflare DNS | External provider | Declarative config in git; re-apply from `infrastructure/cloudflare/` |
| In-kind (local dev) MongoDB | Dev-only; not a production concern | Atlas-only in production (ADR-001) |
| Logs (Loki) | Ephemeral observability data | Acceptable loss; logs have no DR requirement |
| Tracing data (Tempo) | Ephemeral observability data | Acceptable loss; traces have no DR requirement |

---

## Critical State Inventory (Production)

### In-cluster (should be protected by Velero snapshots)

| Component | Namespace | Storage | Source of truth | Backup mechanism | How to prove it |
|---|---|---|---|---|---|
| MySQL | `mereka-lms` | PVC (`mysql`) | In-cluster MySQL | Velero VolumeSnapshots (hourly critical schedule) | `./scripts/qa/audit-velero.sh` shows snapshots; `./scripts/qa/list-critical-backup-pvcs.sh` lists PVC |
| Redis | `mereka-lms` | PVC (`redis`) | In-cluster Redis | Velero VolumeSnapshots | Same as above |
| Meilisearch | `mereka-lms` | PVC | In-cluster Meilisearch | Velero VolumeSnapshots (daily/weekly) | Same as above |
| Authentik Postgres | `authentik` | PVC | Authentik DB | Velero VolumeSnapshots | `./scripts/qa/list-critical-backup-pvcs.sh` |
| Authentik Redis | `authentik` | PVC | Authentik sessions/cache | Velero VolumeSnapshots | `./scripts/qa/list-critical-backup-pvcs.sh` |
| Infisical Postgres | `infisical` | PVC | Secrets DB | Velero VolumeSnapshots | `./scripts/qa/list-critical-backup-pvcs.sh` |
| Infisical Redis | `infisical` | PVC | Cache/queues | Velero VolumeSnapshots | `./scripts/qa/list-critical-backup-pvcs.sh` |
| n8n Postgres + storage | `n8n` | PVCs | n8n DB + data | Velero VolumeSnapshots | `./scripts/qa/list-critical-backup-pvcs.sh` |

### External / managed (not protected by Velero)

| Component | Source of truth | Backup mechanism | Notes |
|---|---|---|---|
| MongoDB Atlas (forum + modulestore) | Atlas | Atlas snapshots (must be enabled + verified) | Velero does not back up Atlas data. |
| Media / S3 (GCS) | GCS bucket | GCS replication + versioning | Object storage, not PVC-backed. |
| DNS (Cloudflare) | `infrastructure/cloudflare/*.json` + provider | Git (config) | Restored by re-applying config + verifying. |
| Container images | Artifact Registry / GHCR | Registry retention policy | Not a Velero concern; but required for full rebuild. |

---

## Known Gaps (As Of 2026-04-08)

1. **Accidental local MongoDB risk (dev-only):** kind dev may still run in-cluster MongoDB for forum testing.
   - Production is Atlas-only (see `docs/adr/historical/001-mongodb-atlas.md`) and should not keep `mongodb` service/deployment active.
   - In kind dev, do not rely on in-cluster MongoDB for durable course content.
2. **DR process discipline still required:** restore drill mechanics are fixed, but monthly evidence review and restore-drill artifacts must stay on schedule.
   - Run: `STRICT_RUNTIME=1 ./scripts/qa/build-dr-evidence-bundle.sh --tar`
3. **Meilisearch index is rebuildable:** Meilisearch index can be fully reconstructed from MySQL source data via `tutor k8s run lms -- python manage.py lms reindex_course_search`. Backup is for convenience; not strictly required for DR.

---

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

If the numbers don't line up, treat it as a backup coverage incident until explained.
