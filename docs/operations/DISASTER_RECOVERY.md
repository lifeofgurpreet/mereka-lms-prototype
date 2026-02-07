# Disaster Recovery (DR) Runbook
_Audience: Platform Eng + SRE • Owner: Infra Team • Last verified: 2026-02-03_

This runbook defines the backup schedule, restore drill cadence, and recovery procedures for Mereka LMS. It is aligned with the **production (GKE)** and **dev (kind)** environment model.
Legacy “staging” bucket names remain in GCS for production backups (there is no staging environment).

## Objectives

- **RPO (Recovery Point Objective):** ≤ 24 hours for LMS data
- **RTO (Recovery Time Objective):** ≤ 4 hours for core LMS availability

## Backup Inventory (Current Reality)

| Layer | Tooling | Schedule | Notes |
| --- | --- | --- | --- |
| In-cluster MySQL + Redis PVs | Velero VolumeSnapshots | Hourly + daily + weekly | This is the current source of truth for database state in prod (DB host is `mysql:3306`). |
| MongoDB Atlas (modulestore + forum) | Atlas + Open edX runtime | Continuous + Atlas snapshots policy | Production LMS/CMS modulestore now resolves Atlas host via `MONGODB_HOST` secret mapping; verify with `./scripts/qa/verify-atlas-modulestore-path.sh --mode all`. |
| Legacy in-cluster MongoDB deployment | Transitional (retire) | N/A | `mereka-lms/mongodb` may still exist with `emptyDir`; treat as cleanup target, not active data path. |
| Persistent volumes (general) | Velero | Hourly critical + daily all apps + weekly full | Use before any risky operation. |
| MongoDB Atlas (forum) | Atlas backups | TBD | Enable/verify snapshots if we move modulestore to Atlas or rely on forum retention. |
| Config + manifests | Git | Every change | Git is the source of truth for K8s + Tutor configs. |

Note: This repo contains a legacy Cloud SQL export workflow (`.github/workflows/cloud-sql-backup.yml`) and
`scripts/infra/backup-db.sh`. Those are only correct if/when MySQL runs in Cloud SQL. Today, production
services use the in-cluster `mysql` Service.

## Scheduled Backups (Required)

Production already has Velero schedules. Audit them (and restore drills) with:

```bash
./scripts/qa/audit-velero.sh --json | jq .
```

For full procedure and interpretation, see:
- `docs/operations/VELERO_BACKUP_AUDIT.md`
- `.github/workflows/dr-evidence-bundle.yml` (monthly evidence artifact automation)

## Atlas Backups (Only If/When Used)

Enable Atlas snapshots for `cluster-mereka-lms` before relying on MongoDB for DR:

```bash
atlas backups snapshots list cluster-mereka-lms --projectId <PROJECT_ID>
```

If the list is empty, enable backups in Atlas UI or via Terraform before the next restore drill.

## Mandatory Pre-Op Backup (Risky Actions)

Before any risky operation (PVC/PV deletions, StatefulSet scale-to-zero, storage changes), **always** create a Velero backup:

```bash
velero backup create pre-op-mereka-lms-$(date +%Y%m%d-%H%M) \
  --include-namespaces mereka-lms --wait
```

## Restore Drill Cadence

- **Monthly**: Restore into a throwaway namespace (`mereka-lms-dr`) and validate.
- **After major changes**: Run a drill following any domain/secret/migration cutover.
- **Monthly evidence artifact**: run `STRICT_RUNTIME=1 ./scripts/qa/build-dr-evidence-bundle.sh --tar` (or use the DR Evidence Bundle workflow artifact).

## Restore Drill Procedure (Monthly)

1. **Create namespace**
   ```bash
   kubectl create ns mereka-lms-dr
   ```
2. **Restore PVCs + core resources**
   ```bash
   velero restore create mereka-lms-dr-$(date +%Y%m%d) \
     --from-backup <latest-backup> \
     --namespace-mappings mereka-lms:mereka-lms-dr
   ```
   Preferred automated path for ongoing monthly drills:
   ```bash
   ./scripts/infra/fix-velero-restore-test.sh
   ```
3. **Verify**
   ```bash
   ./scripts/qa/public-health-check.sh prod
   ```
4. **Clean up**
   ```bash
   kubectl delete ns mereka-lms-dr
   ```

## Recovery (Production Incident)

1. **Stabilize**: Freeze deploys and announce incident.
2. **Recover PVs**: Restore via Velero.
3. **Recover DB**: If DB is in-cluster, it comes back with PV restore. If/when we migrate to Cloud SQL, update this section.
4. **Validate**: Use public health checks + Studio login.
5. **Postmortem**: Document root cause and preventive actions.

## Verification Checklist

- LMS homepage responds `200/302`
- Studio login loads
- Discovery + Ecommerce health endpoints return `200`
- Microsites (`academy.biji-biji.com`, `skillourfuture.academy.mereka.io`) respond `200`
- Course content visible for each org
