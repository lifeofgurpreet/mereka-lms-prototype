# Disaster Recovery (DR) Runbook
_Audience: Platform Eng + SRE • Owner: Infra Team • Last verified: 2026-02-03_

This runbook defines the backup schedule, restore drill cadence, and recovery procedures for Mereka LMS. It is aligned with the **production (GKE)** and **dev (kind)** environment model.

## Objectives

- **RPO (Recovery Point Objective):** ≤ 24 hours for LMS data
- **RTO (Recovery Time Objective):** ≤ 4 hours for core LMS availability

## Backup Inventory

| Layer | Tooling | Schedule | Notes |
| --- | --- | --- | --- |
| Cloud SQL | Automated backups | Daily | Managed by Cloud SQL. Verify in console. |
| Cloud SQL exports | `cloud-sql-backup.yml` + `scripts/infra/backup-db.sh` | Every 3 days | Writes to `gs://staging-academy-mereka-io-backup/sql/` (legacy bucket name). |
| Persistent volumes | Velero | Weekly full + ad-hoc | Use before any risky operation. |
| MongoDB Atlas | Atlas continuous backups | Continuous | Managed by Atlas (M10). |
| Config + manifests | Git | Every change | Git is the source of truth for K8s + Tutor configs. |

## Mandatory Pre-Op Backup (Risky Actions)

Before any risky operation (PVC/PV deletions, StatefulSet scale-to-zero, storage changes), **always** create a Velero backup:

```bash
velero backup create pre-op-mereka-lms-$(date +%Y%m%d-%H%M) \
  --include-namespaces mereka-lms --wait
```

## Restore Drill Cadence

- **Monthly**: Restore into a throwaway namespace (`mereka-lms-dr`) and validate.
- **After major changes**: Run a drill following any domain/secret/migration cutover.

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
3. **Restore Cloud SQL snapshot** (if needed)
   - Use a recent automated backup or the latest export in GCS.
4. **Point DR pods to the restored database**
   - Set DB host/credentials via temporary `config.yml` overrides.
5. **Verify**
   ```bash
   ./scripts/qa/public-health-check.sh prod
   ```
6. **Clean up**
   ```bash
   kubectl delete ns mereka-lms-dr
   ```

## Recovery (Production Incident)

1. **Stabilize**: Freeze deploys and announce incident.
2. **Recover DB**: Restore Cloud SQL from backup/export.
3. **Recover PVs**: Restore via Velero.
4. **Validate**: Use public health checks + Studio login.
5. **Postmortem**: Document root cause and preventive actions.

## Verification Checklist

- LMS homepage responds `200/302`
- Studio login loads
- Discovery + Ecommerce health endpoints return `200`
- Microsites (`academy.biji-biji.com`, `skillourfuture.academy.mereka.io`) respond `200`
- Course content visible for each org

