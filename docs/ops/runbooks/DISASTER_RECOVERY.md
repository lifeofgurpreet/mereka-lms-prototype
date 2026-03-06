# Disaster Recovery (DR) Runbook
_Audience: Platform Eng + SRE • Owner: Infra Team • Last verified: 2026-02-07_

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
| Legacy in-cluster MongoDB runtime | Retired (prod) | N/A | `Deployment/mongodb` removed in prod after backup verification; keep `Service/mongodb` removal enforced via production overlay GitOps patch. |
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

## DR Evidence Generation

Generate a DR evidence bundle on demand for enterprise audit requests:

```bash
# Preferred: full evidence bundle with tarball output
STRICT_RUNTIME=1 ./scripts/qa/build-dr-evidence-bundle.sh --tar

# Alternative: trigger via GitHub Actions (monthly automated + manual dispatch)
gh workflow run dr-evidence-bundle.yml
```

**Required artifacts** (must all be present in the bundle):
1. `audit-velero.json` — backup schedule health
2. `audit-velero-alert-pipeline.json` — alert pipeline health
3. `observability-compliance-runtime.json` — runtime observability compliance evidence
4. `observability-first-class-runtime-evidence-index.json` — normalized runtime evidence index
5. `observability-correlation-headers-runtime.txt` — ingress-to-runtime correlation header propagation report
6. `audit-observability-runtime.json` — monitoring coverage (legacy compatibility alias)
7. Latest `restore-test` job logs and `kubectl describe` output
8. Restored PVC summary (bound count)
9. MySQL probe result from restore job log

**SLA**: Complete evidence bundle generated within 1 business day of request.

**Retention**: Evidence bundles retained for 12 months. GitHub Actions artifacts set to 120-day retention; for longer retention archive to GCS.

---

## Disaster Scenario Response Procedures

### DR-002: Single PVC Data Corruption

**Severity**: Medium | **Max RTO**: 30 minutes | **Trigger**: Single PVC data corruption detected

**Procedure**:

1. **Identify** the affected PVC:
   ```bash
   kubectl get pvc -n mereka-lms
   kubectl describe pvc <affected-pvc> -n mereka-lms
   ```

2. **Create pre-op backup** (if the rest of the namespace is healthy):
   ```bash
   velero backup create pre-op-mereka-lms-$(date +%Y%m%d-%H%M) \
     --include-namespaces mereka-lms --wait
   ```

3. **Find the latest hourly backup** with volume snapshots:
   ```bash
   kubectl -n velero get backup -o json | jq -r '
     [.items[]
      | select(.metadata.labels["velero.io/schedule-name"]=="velero-local-hourly-critical-databases")
      | select(.status.phase=="Completed")
      | select(.status.volumeSnapshotsCompleted > 0)]
     | sort_by(.status.completionTimestamp) | last | .metadata.name'
   ```

4. **Scale down** the workload using the affected PVC:
   ```bash
   kubectl scale deploy/<workload> -n mereka-lms --replicas=0
   ```

5. **Delete the corrupted PVC** and restore from backup:
   ```bash
   kubectl delete pvc <affected-pvc> -n mereka-lms
   velero restore create pvc-restore-$(date +%s) \
     --from-backup <backup-name> \
     --include-resources persistentvolumeclaims,persistentvolumes \
     --include-namespaces mereka-lms \
     --selector "app=<affected-app>"
   ```

6. **Scale up** and verify:
   ```bash
   kubectl scale deploy/<workload> -n mereka-lms --replicas=1
   kubectl get pvc -n mereka-lms  # Confirm Bound
   ./scripts/qa/public-health-check.sh prod
   ```

**Success criteria**: PVC restored to Bound state, workload healthy, data loss within 1-hour RPO.

---

### DR-003: Namespace Deletion/Corruption

**Severity**: High | **Max RTO**: 1 hour | **Trigger**: Namespace deleted or resources corrupted beyond repair

**Procedure**:

1. **Assess scope** — confirm the namespace is gone or corrupted:
   ```bash
   kubectl get ns mereka-lms
   kubectl get all -n mereka-lms
   ```

2. **Find the latest backup** that includes the namespace:
   ```bash
   velero backup get --selector velero.io/schedule-name=velero-local-hourly-critical-databases \
     -o json | jq -r '[.items[] | select(.status.phase=="Completed")] | sort_by(.status.completionTimestamp) | last | .metadata.name'
   ```

3. **Restore full namespace** with PVCs and all resources:
   ```bash
   velero restore create ns-restore-$(date +%s) \
     --from-backup <backup-name> \
     --include-namespaces mereka-lms
   ```
   If restoring to a different namespace for safety:
   ```bash
   velero restore create ns-restore-$(date +%s) \
     --from-backup <backup-name> \
     --namespace-mappings mereka-lms:mereka-lms-restored
   ```

4. **Wait for restore** and monitor:
   ```bash
   velero restore describe ns-restore-<id>
   kubectl get pods -n mereka-lms -w
   ```

5. **Force ExternalSecrets resync** (secrets may be stale):
   ```bash
   kubectl -n mereka-lms delete secret openedx-secrets database-secrets --ignore-not-found
   # ExternalSecrets operator recreates within refreshInterval or after delete
   ```

6. **Verify**:
   ```bash
   kubectl get pvc -n mereka-lms  # All PVCs Bound
   ./scripts/qa/public-health-check.sh prod
   ```

**Success criteria**: All resources restored, PVCs bound, LMS/Studio/MFE responding, data loss within RPO.

---

### DR-007: Full Cluster Loss

**Severity**: Critical | **Max RTO**: 4 hours | **Trigger**: Complete GKE cluster loss (deletion, region outage)

**Procedure**:

1. **Provision new GKE cluster** (manual or Terraform):
   ```bash
   # Using Terraform (preferred)
   cd infrastructure/terraform
   terraform apply -var="cluster_name=mereka-lms-recovery"

   # Or manual GKE creation
   gcloud container clusters create mereka-lms-recovery \
     --zone asia-southeast1-c --num-nodes=3 --machine-type=e2-standard-4
   ```

2. **Install Velero** on the new cluster pointing to the same GCS backup bucket:
   ```bash
   velero install \
     --provider gcp \
     --plugins velero/velero-plugin-for-gcp:v1.9.0 \
     --bucket <velero-gcs-bucket> \
     --secret-file ./credentials-velero
   ```

3. **Verify Velero can see backups**:
   ```bash
   velero backup get
   kubectl -n velero get backupstorelocation default -o jsonpath='{.status.phase}'
   # Must show: Available
   ```

4. **Restore critical namespaces** in order:
   ```bash
   # a) Infrastructure first (secrets, cert-manager, external-secrets)
   velero restore create infra-restore-$(date +%s) \
     --from-backup <latest-weekly-full> \
     --include-namespaces external-secrets,cert-manager

   # b) Application namespaces
   velero restore create app-restore-$(date +%s) \
     --from-backup <latest-hourly-critical> \
     --include-namespaces mereka-lms,authentik,infisical,n8n
   ```

5. **Restore configuration from Git**:
   ```bash
   kubectl apply -k deploy/k8s/overlays/production
   ```

6. **Force ExternalSecrets resync** and verify secrets:
   ```bash
   kubectl -n external-secrets rollout restart deployment external-secrets
   # Wait for secrets to sync from Infisical/GCP SM
   ```

7. **Update DNS** (if cluster IP changed):
   ```bash
   # Update Cloudflare DNS A records to point to new LoadBalancer IP
   kubectl get svc caddy -n mereka-lms -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
   ```

8. **Verify full platform**:
   ```bash
   ./scripts/qa/public-health-check.sh prod
   ```

**Success criteria**: Platform available within 4 hours, data loss not exceeding 1 hour (Tier 1 RPO), all health checks green.

**Semi-annual tabletop exercise**: Walk through this procedure with engineering team to validate readiness and identify gaps.

---

## Data Integrity Verification

Post-restore data integrity checks:

1. **MySQL user count** (should be within 5% of pre-incident count):
   ```bash
   kubectl exec -n mereka-lms deploy/mysql -- \
     mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -Nse "SELECT COUNT(*) FROM openedx.auth_user"
   ```

2. **MongoDB course count** (must be non-zero):
   ```bash
   # Via LMS Django shell
   kubectl exec -n mereka-lms deploy/lms -- \
     python -c "from xmodule.modulestore.django import modulestore; print(sum(1 for _ in modulestore().get_courses()))"
   ```

3. **Full health check**:
   ```bash
   ./scripts/qa/public-health-check.sh prod
   ```

4. **Spot-check content**:
   - LMS homepage loads with courses listed
   - Studio login returns course outlines
   - Discovery API returns catalog data
   - Microsites respond (`academy.biji-biji.com`, `skillourfuture.academy.mereka.io`)

---

## Cross-Region Readiness Verification

Verify cross-region DR readiness:

1. **Kustomize manifests are portable** (deployable to any GKE cluster):
   ```bash
   kubectl kustomize deploy/k8s/overlays/production | kubectl apply --dry-run=server -f -
   ```

2. **GCS backup bucket storage class** (should be multi-region or dual-region):
   ```bash
   gcloud storage buckets describe gs://<velero-bucket-name> --format='value(location,locationType,storageClass)'
   # Target: locationType=multi-region or dual-region
   ```

3. **Artifact Registry replication** (images accessible from secondary region):
   ```bash
   gcloud artifacts repositories describe openedx \
     --project=mereka-lms --location=asia-southeast1 \
     --format='value(mode)'
   ```

4. **MongoDB Atlas network access** (accessible from multiple regions):
   ```bash
   atlas accessList list --projectId <PROJECT_ID>
   # Verify both primary and secondary region CIDRs are allowed
   ```

5. **DNS failover readiness** (Cloudflare can point to secondary):
   - Verify DNS records exist for all production domains
   - Confirm TTL is low enough for fast cutover (300s or less)
   - Document the IP/CNAME for secondary cluster

**Verification**: Run during Phase 3 implementation and re-verify quarterly.

---

## Recovery (Production Incident)

1. **Stabilize**: Freeze deploys and announce incident.
2. **Classify**: Match to disaster scenario (DR-001 through DR-011) — see spec.
3. **Execute**: Follow the matching scenario procedure above.
4. **Recover PVs**: Restore via Velero.
5. **Recover DB**: If DB is in-cluster, it comes back with PV restore. If/when we migrate to Cloud SQL, update this section.
6. **Validate**: Use public health checks + Studio login + data integrity verification.
7. **Postmortem**: Document root cause and preventive actions within 5 business days for P1/P2.

## Verification Checklist

- LMS homepage responds `200/302`
- Studio login loads
- Discovery + Ecommerce health endpoints return `200`
- Microsites (`academy.biji-biji.com`, `skillourfuture.academy.mereka.io`) respond `200`
- Course content visible for each org
- MySQL user count within expected range (see Data Integrity Verification)
- DR evidence bundle generates without errors
