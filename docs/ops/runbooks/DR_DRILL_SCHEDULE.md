# DR Drill Schedule

_Audience: SRE + Platform Ops · Owner: Engineering Lead · Last updated: 2026-02-24_

This document governs the recurring monthly disaster recovery drills for Mereka Academy. Drills verify that backup procedures, restore mechanics, and data integrity checks function correctly before they are needed in a real incident.

**Cross-repo note**: The K8s CronJob manifests that automate drills live in `infrastructure`. This repo contains the verification scripts, documentation, and evidence pipeline.

---

## Monthly Drill Schedule

Drills run on the **first Monday of each calendar month**, starting at **02:00 UTC** (10:00 MYT).

| Month | Target Date | Database Focus | Responsible |
|-------|-------------|----------------|-------------|
| January   | First Monday | Velero full-namespace restore    | SRE lead |
| February  | First Monday | Cloud SQL (MySQL) restore drill  | SRE lead |
| March     | First Monday | MongoDB Atlas restore validation | SRE lead |
| April     | First Monday | PostgreSQL (Purchase Gateway)    | SRE lead |
| May       | First Monday | Velero PVC-level restore         | SRE lead |
| June      | First Monday | Cloud SQL (MySQL) restore drill  | SRE lead |
| July      | First Monday | MongoDB Atlas restore validation | SRE lead |
| August    | First Monday | PostgreSQL (Purchase Gateway)    | SRE lead |
| September | First Monday | Velero full-namespace restore    | SRE lead |
| October   | First Monday | Cloud SQL (MySQL) restore drill  | SRE lead |
| November  | First Monday | MongoDB Atlas restore validation | SRE lead |
| December  | First Monday | Velero PVC-level restore         | SRE lead |

### Advance Notification

Post in `#mereka-operations` Slack channel at least **48 hours** before the scheduled drill:

```
[DR DRILL] Scheduled restore drill on <DATE> at 02:00 UTC.
Focus: <database type>. Expected duration: <N> hours.
All non-production access to <system> may be temporarily paused.
```

---

## Backup Sources

### MySQL (Cloud SQL)

| Property | Value |
|----------|-------|
| Instance | `mereka-lms-mysql` (GCP project `mereka-lms`) |
| Backup type | Cloud SQL automated daily backups |
| Backup window | 02:00 UTC |
| Retention | 7 days (automated), 30 days (on-demand) |
| Verify script | `./scripts/qa/verify-cloud-sql-snapshots.sh` |
| Drill runbook | `docs/runbooks/operations/CLOUD_SQL_RESTORE_DRILL.md` |

**Check backup freshness:**
```bash
gcloud sql backups list \
  --instance=mereka-lms-mysql \
  --project=mereka-lms \
  --limit=3 \
  --format="table(id,status,endTime,sizeGb)"
```

### MongoDB Atlas

| Property | Value |
|----------|-------|
| Cluster | `cluster-mereka-lms.2pjex4s.mongodb.net` |
| Databases | `openedx` (modulestore), `cs_comments_service` (forum) |
| Backup type | Atlas continuous cloud backup (automated) |
| RPO | 1 hour (point-in-time restore) |
| Retention | 2 days (continuous), 30 days (snapshots) |
| Verify | Atlas console → Backup → Snapshots |

**Check snapshot status (requires Atlas API key in environment):**
```bash
# List latest snapshots via Atlas CLI or API
# atlas backups snapshots list <cluster-name> --projectId <project-id>
# Or verify in: https://cloud.mongodb.com → Backup → Snapshots
```

### PostgreSQL (Purchase Gateway)

| Property | Value |
|----------|-------|
| Deployment | In-cluster `postgresql-payments` (`mereka-lms` namespace) |
| Storage | PVC `postgresql-payments-data` (5Gi) |
| Backup type | Velero VolumeSnapshot (included in `hourly-critical` schedule) |
| PVC label | `app.kubernetes.io/name=postgresql-payments` |
| Verify script | `./scripts/qa/verify-purchase-gateway.sh` |

**Confirm PVC is included in Velero backup:**
```bash
./scripts/qa/list-critical-backup-pvcs.sh | grep postgresql-payments
```

### K8s Resources (Velero)

| Property | Value |
|----------|-------|
| Schedules | `hourly-critical`, `daily-all-apps`, `weekly-full` |
| Storage | GCS bucket (multi-region) |
| Namespaces | `mereka-lms`, `authentik`, `infisical`, `monitoring`, `argocd`, and others |
| Verify script | `./scripts/qa/audit-velero.sh` |
| Alert | PrometheusRule `velero-alerts` → `VeleroBackupFailed` fires within 1 hour |

**Check Velero schedule status:**
```bash
kubectl get schedule -n velero
kubectl get backup -n velero --sort-by=.status.completionTimestamp | tail -5
```

---

## Restore Verification Steps

### MySQL (Cloud SQL)

Full procedure: `docs/runbooks/operations/CLOUD_SQL_RESTORE_DRILL.md`

1. List available backups:
   ```bash
   gcloud sql backups list --instance=mereka-lms-mysql --project=mereka-lms --limit=5
   ```
2. Create drill instance from latest backup (NOT production):
   ```bash
   DRILL_INSTANCE="mereka-lms-mysql-drill-$(date +%Y%m%d)"
   gcloud sql backups restore "$LATEST_BACKUP_ID" \
     --backup-instance=mereka-lms-mysql \
     --restore-instance="$DRILL_INSTANCE" \
     --project=mereka-lms
   ```
3. Verify data integrity:
   ```bash
   gcloud sql connect "$DRILL_INSTANCE" --user=root --project=mereka-lms
   # Inside MySQL:
   SELECT COUNT(*) FROM openedx.auth_user;
   SELECT COUNT(*) FROM openedx.student_courseenrollment;
   SHOW DATABASES;
   ```
4. Confirm record counts are within 5% of production baseline.
5. Delete drill instance:
   ```bash
   gcloud sql instances delete "$DRILL_INSTANCE" --project=mereka-lms
   ```

### MongoDB Atlas

1. In Atlas console, navigate to **Backup → Snapshots** for `cluster-mereka-lms`.
2. Select the most recent snapshot.
3. Click **Restore** → **Restore to new cluster** (never restore over production).
4. After restore completes, connect and verify:
   ```
   use openedx
   db.modulestore.find().limit(1)
   db.getCollection('auth_user').countDocuments()

   use cs_comments_service
   db.contents.countDocuments()
   ```
5. Confirm document counts are within 5% of production.
6. Terminate the drill cluster.

### PostgreSQL (Purchase Gateway)

1. Identify the Velero backup to use:
   ```bash
   kubectl get backup -n velero | grep hourly-critical | tail -3
   ```
2. Create a restore into a throwaway namespace:
   ```bash
   kubectl apply -f - <<EOF
   apiVersion: velero.io/v1
   kind: Restore
   metadata:
     name: pg-payments-drill-$(date +%Y%m%d)
     namespace: velero
   spec:
     backupName: <BACKUP_NAME>
     includedNamespaces:
       - mereka-lms
     includedResources:
       - persistentvolumeclaims
       - persistentvolumes
     labelSelector:
       matchLabels:
         app.kubernetes.io/name: postgresql-payments
     namespaceMapping:
       mereka-lms: pg-drill-$(date +%Y%m%d)
     restorePVs: true
   EOF
   ```
3. Spin up a temporary PostgreSQL pod against the restored PVC and probe:
   ```bash
   kubectl exec -n pg-drill-<DATE> <pg-pod> -- \
     psql -U payments -c "SELECT COUNT(*) FROM orders;"
   ```
4. Confirm row counts and delete the drill namespace:
   ```bash
   kubectl delete ns pg-drill-$(date +%Y%m%d)
   ```

### K8s Resources (Velero)

Full DR test results from the last one-off drill: `docs/status/readiness/DR_TEST_RESULTS.md`

1. Identify the most recent `daily-all-apps` backup:
   ```bash
   kubectl get backup -n velero | grep daily-all-apps | sort | tail -1
   ```
2. Restore `mereka-lms` namespace to a throwaway namespace:
   ```bash
   kubectl apply -f - <<EOF
   apiVersion: velero.io/v1
   kind: Restore
   metadata:
     name: mereka-lms-drill-$(date +%Y%m%d%H%M)
     namespace: velero
   spec:
     backupName: <BACKUP_NAME>
     includedNamespaces:
       - mereka-lms
     namespaceMapping:
       mereka-lms: mereka-lms-dr-test
     restorePVs: true
   EOF
   ```
3. Verify PVCs reach Bound state:
   ```bash
   kubectl get pvc -n mereka-lms-dr-test
   ```
4. Run MySQL data probe:
   ```bash
   kubectl exec -n mereka-lms-dr-test <mysql-pod> -- \
     mysql -e "SELECT COUNT(*) FROM openedx.auth_user;"
   ```
5. Delete drill namespace:
   ```bash
   kubectl delete ns mereka-lms-dr-test
   ```

---

## Drill Pass/Fail Criteria

A drill **passes** when ALL of the following are true:

| Criterion | Requirement |
|-----------|-------------|
| Restore completes | Within the RTO for the scenario (see table below) |
| Data accessible | Database probe returns results (no connection errors) |
| Row counts match | Within 5% of production baseline at time of backup |
| PVCs bound | All restored PVCs reach `Bound` phase |
| No data corruption | No MySQL InnoDB errors, no Atlas document check failures |
| Evidence archived | JSON evidence file written with timestamp, pass/fail status, counts |

A drill **fails** when ANY of the following is true:

- Restore does not complete within RTO
- Database is unreachable after restore
- Row count deviation exceeds 5%
- A PVC remains `Pending` or `Failed` after 10 minutes
- Evidence file cannot be written

### RTO Targets per Scenario

| Scenario | RTO | RPO |
|----------|-----|-----|
| Single PVC restore (Velero) | 30 minutes | 1 hour |
| Full namespace restore (Velero) | 1 hour | 1 hour |
| Cloud SQL instance restore | 4 hours | 24 hours |
| MongoDB Atlas cluster restore | 2 hours | 1 hour (point-in-time) |
| Full cluster rebuild | 4 hours | 1 hour (Tier 1 RPO) |

---

## Evidence Archival

After each drill, produce a JSON evidence file and store it under `var/dr-evidence/drills/`:

```bash
EVIDENCE_DIR="${REPO_ROOT}/var/dr-evidence/drills"
mkdir -p "$EVIDENCE_DIR"

cat > "$EVIDENCE_DIR/drill-$(date -u +%Y%m%dT%H%M%SZ).json" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "drill_type": "<mysql|mongodb|postgresql|velero>",
  "backup_name": "<backup id or snapshot name>",
  "restore_target": "<instance or namespace>",
  "rto_target_minutes": <N>,
  "actual_duration_minutes": <M>,
  "row_count_baseline": <N>,
  "row_count_restored": <N>,
  "pvcs_bound": <true|false>,
  "db_probe_result": "<PASS|FAIL>",
  "overall_status": "<PASS|FAIL>",
  "operator": "<name>",
  "notes": "<any deviations or observations>"
}
EOF
```

The monthly GitHub Actions workflow (`dr-evidence-bundle.yml`) automatically collects and uploads drill evidence as a 120-day retention artifact.

To generate the full evidence bundle on demand:
```bash
STRICT_RUNTIME=1 ./scripts/qa/build-dr-evidence-bundle.sh --tar
```

---

## Release Gate Integration

A failed or overdue drill **blocks production releases** as follows:

- If no drill evidence exists for the current calendar month, the `check-error-budget-gate.sh` and `verify-deployment-gate.sh` gates return a warning.
- If a drill returned `FAIL` status within the last 30 days, a production release requires explicit sign-off from the Engineering Lead.
- The `verify-dr-drill-schedule.sh` script is run as part of `run-operations-gates.sh` and must pass before a release is promoted.

To check drill gate status before a release:
```bash
./scripts/qa/verify-dr-drill-schedule.sh
./scripts/qa/run-operations-gates.sh
```

If a drill is blocked due to environment access, an Engineering Lead can approve a waiver by appending to `var/dr-evidence/waivers.log`:
```
<ISO8601 timestamp> | WAIVER | <drill type> | <reason> | <approver>
```

---

## Escalation Path for Failed Drills

1. **Immediate**: Post in `#mereka-operations` Slack with `[DR DRILL FAILED]` prefix. Include the error from the evidence JSON file.

2. **Within 1 hour**: Engineering Lead reviews the failure. If the failure indicates a real backup integrity problem, create a P0 incident.

3. **Within 1 business day**: Root cause identified and documented in `docs/status/incidents/`.

4. **Before next release**: Fix is implemented and drill is re-run successfully.

**Escalation contacts**:
- On-call SRE: check `docs/policies/operations/ONCALL_ROTATION.md`
- Engineering Lead: see `AGENTS.md` team contact list
- Backup infrastructure issue: raise in `infrastructure` repo

### Common Failure Modes

| Symptom | Likely Cause | Action |
|---------|--------------|--------|
| Restore times out | Network issue or snapshot not found | Check `kubectl get restore -n velero` events |
| PVC stays Pending | StorageClass mismatch in target namespace | Verify StorageClass exists in drill namespace |
| MySQL unreachable | InnoDB crash recovery required | Check pod logs; re-run with `--skip-grant-tables` |
| Atlas restore fails | Snapshot expired or cluster tier mismatch | Create new snapshot manually; check Atlas tier |
| Row count off >5% | Backup captured during active writes | Document in evidence; acceptable if within 10% at off-peak |

---

## Verification

Run the DR drill schedule verification script at any time:

```bash
# Offline checks (repo state only):
./scripts/qa/verify-dr-drill-schedule.sh

# Online checks (live cluster required):
./scripts/qa/verify-dr-drill-schedule.sh --online

# Broader DR compliance check:
./scripts/qa/verify-disaster-recovery.sh --skip-cluster
```

This script validates:
- Documentation completeness (this file, BACKUP_COVERAGE_MATRIX.md)
- Evidence bundle script coverage
- GitHub Actions monthly schedule configuration
- Live Velero schedule status (online mode)
- BackupStorageLocation availability (online mode)
- backup-verification CronJob active status (online mode)
