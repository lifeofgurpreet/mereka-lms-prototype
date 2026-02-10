---
title: "Disaster Recovery & Business Continuity"
type: "feature_spec"
status: "draft"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-10"
links:
  related_docs:
    - "docs/operations/DISASTER_RECOVERY.md"
    - "docs/operations/VELERO_BACKUP_AUDIT.md"
    - "docs/operations/BACKUP_COVERAGE_MATRIX.md"
    - "docs/operations/DR_TEST_RESULTS.md"
    - "docs/operations/COURSE_DATA_RECOVERY.md"
    - "docs/operations/ONCALL_OBSERVABILITY_PLAYBOOK.md"
    - "docs/operations/DEPLOYMENT_RUNBOOK.md"
  related_specs:
    - "specs/k8s-deployment_spec.md"
    - "specs/secrets-management_spec.md"
    - "specs/mongodb-atlas-integration_spec.md"
    - "specs/observability-stack_spec.md"
---

# Human Summary

## What we're building

A formal Disaster Recovery (DR) and Business Continuity (BC) framework for Mereka Academy (Open edX on GKE). This spec codifies RPO/RTO commitments, backup strategy, failover procedures, recovery validation, compliance evidence generation, and recovery testing cadences into machine-checkable requirements. It unifies the existing ad-hoc backup tooling (Velero schedules, Atlas snapshots, GCS exports, restore-test CronJobs, DR evidence bundles) into a single contractual specification that enterprise clients can audit.

## Why it matters

Enterprise clients require contractual SLA guarantees for data durability and service availability. Today, Mereka Academy has functional backup infrastructure (Velero hourly/daily/weekly schedules, MongoDB Atlas, automated restore drills) but no formal spec binding the pieces together with testable acceptance criteria. Without a spec, there is no enforceable contract for: (a) how quickly we recover (RTO), (b) how much data we can lose (RPO), (c) what scenarios are covered, (d) how we prove it works, (e) who is responsible for what. This gap creates compliance risk for enterprise sales and operational risk during real incidents.

## Success looks like

- RPO and RTO targets are defined per data tier and validated by monthly automated restore drills
- Every backup mechanism has a corresponding verification step that runs without human intervention
- DR evidence bundles are generated monthly and retained for 12 months for audit purposes
- Recovery from any single-component failure completes within the stated RTO without data loss beyond RPO
- Enterprise clients receive a DR compliance report on request, generated from automated evidence

# Agent Contract

## Scope

- In scope:
  - RPO/RTO definitions for all data tiers (MySQL, MongoDB Atlas, Redis, Elasticsearch, configuration)
  - Backup strategy for in-cluster stateful services (Velero VolumeSnapshots)
  - Backup strategy for managed services (MongoDB Atlas snapshots, GCS exports)
  - Backup strategy for configuration and secrets (Git, Infisical, GCP Secret Manager)
  - Disaster scenario classification and response procedures
  - Automated restore drill requirements and validation criteria
  - DR evidence generation, retention, and audit compliance
  - Backup monitoring, alerting, and freshness enforcement
  - Cross-region failover readiness requirements
  - Data integrity verification procedures
  - Secret recovery and rotation after DR events
  - Business continuity planning (communication, escalation, roles)
- Out of scope:
  - Network-level DDoS mitigation (Cloudflare responsibility)
  - GKE control plane HA (Google SLA)
  - MongoDB Atlas cluster management (Atlas SLA)
  - Application-level data validation (e.g., verifying course content correctness post-migration)
  - Cost optimization of backup storage
  - Development environment DR (kind/VPS local is best-effort)

## Non-goals

- Multi-region active-active deployment (future phase; this spec covers warm-standby readiness)
- Zero-downtime failover (target is bounded RTO, not zero)
- Automated failover without human approval for production (manual gate required)
- Backup of ephemeral caches (Redis session data loss within RPO is acceptable)
- DR for third-party SaaS integrations (HubSpot, Stripe) beyond secret recovery
- Replacing Atlas managed backups with self-managed MongoDB backup tooling

## Assumptions

- Production runs on GKE in `asia-southeast1-c` with namespace `mereka-lms`
- MySQL, Redis, and Elasticsearch are in-cluster with PVC-backed storage
- MongoDB uses Atlas (`cluster-mereka-lms.2pjex4s.mongodb.net`) for modulestore and forum
- Velero is deployed in the `velero` namespace with GCS backend storage
- Infisical at `secrets.mereka.io` is the secrets source of truth
- Git repository is the source of truth for all K8s manifests and configurations
- DR evidence bundle automation exists via `.github/workflows/dr-evidence-bundle.yml`
- Restore-test script exists at `infrastructure/k8s/velero/restore-test-script.sh`
- GKE cluster has a single zone deployment (not regional) as of this writing

## Requirements

### Functional

#### RPO/RTO Definitions

- The system MUST define RPO and RTO targets per data tier as follows:

  | Data Tier | RPO | RTO | Backup Mechanism | Rationale |
  |-----------|-----|-----|------------------|-----------|
  | Tier 1: MySQL (user data, enrollments, grades, ecommerce) | 1 hour | 30 minutes | Velero hourly VolumeSnapshots | Core transactional data; most critical |
  | Tier 2: MongoDB Atlas (modulestore, forum) | 24 hours | 1 hour | Atlas continuous backup + daily snapshots | Managed service; content changes less frequently |
  | Tier 3: Redis (cache, sessions, Celery) | N/A (ephemeral) | 15 minutes | Velero hourly VolumeSnapshots (warm data) | Cache rebuild acceptable; persistent queues restored from snapshot |
  | Tier 4: Elasticsearch (search index) | N/A (rebuildable) | 1 hour | Velero daily snapshots + full reindex | Index rebuilt from MySQL/MongoDB source data |
  | Tier 5: Configuration (K8s manifests, Tutor config) | 0 (no loss) | 15 minutes | Git + Infisical + GCP Secret Manager | Declarative; apply from source control |
  | Tier 6: Container images | 0 (no loss) | 30 minutes | Artifact Registry (`asia-southeast1-docker.pkg.dev/mereka-lms/openedx`) | Immutable; tagged by git SHA |

- The system MUST guarantee a composite RPO of 1 hour for full platform recovery (bounded by Tier 1)
- The system MUST guarantee a composite RTO of 4 hours for full platform recovery from complete cluster loss
- The system MUST guarantee an RTO of 30 minutes for single-component failure recovery

#### Backup Strategy

- The system MUST maintain Velero backup schedules as follows:

  | Schedule | Frequency | Namespaces | Retention | Purpose |
  |----------|-----------|------------|-----------|---------|
  | `velero-local-hourly-critical-databases` | Every hour | `mereka-lms`, `authentik`, `infisical`, `n8n` | 48 hours (48 backups) | Tier 1 RPO compliance |
  | `velero-local-daily-all-apps` | Daily 18:00 UTC | All application namespaces | 30 days | Tier 2-4 RPO compliance |
  | `velero-local-weekly-full` | Weekly Sunday 19:00 UTC | All namespaces including infrastructure | 90 days | Full cluster rebuild capability |

- The system MUST verify that every Velero backup includes `volumeSnapshotsCompleted > 0` matching the bound PVC count for included namespaces
- The system MUST configure Velero schedules with `includeClusterResources: true` and `volumeSnapshotLocations: ["default"]`
- The system MUST NOT store critical stateful data on `emptyDir` volumes in any production namespace
- MongoDB Atlas MUST have continuous backup enabled for `cluster-mereka-lms`
- MongoDB Atlas SHOULD have point-in-time recovery (PITR) enabled with a minimum 7-day window
- The system MUST maintain a legacy Cloud SQL backup workflow (`.github/workflows/cloud-sql-backup.yml`) in disabled state, activatable via `ENABLE_CLOUD_SQL_BACKUPS=true` for future Cloud SQL migration
- The system MUST create a pre-operation Velero backup (`pre-op-mereka-lms-YYYYMMDD-HHMM`) before any risky operation (PVC/PV deletions, StatefulSet scale-to-zero, storage changes, major config changes)

#### Disaster Scenario Coverage

- The system MUST define and maintain response procedures for the following scenarios:

  | Scenario ID | Scenario | Severity | Max RTO | Response Procedure |
  |-------------|----------|----------|---------|-------------------|
  | DR-001 | Single pod failure/crash | Low | 5 min | K8s self-healing (restart policy), verify via readiness probes |
  | DR-002 | Single PVC data corruption | Medium | 30 min | Velero PVC restore from hourly backup |
  | DR-003 | Namespace deletion/corruption | High | 1 hour | Velero full namespace restore |
  | DR-004 | MySQL data loss or corruption | Critical | 30 min | Velero PVC restore + data integrity verification |
  | DR-005 | MongoDB Atlas outage | High | Atlas SLA (99.995%) | Wait for Atlas recovery; read-only mode if extended |
  | DR-006 | Secret compromise/rotation | High | 1 hour | Rotate in Infisical, sync to GCP SM, restart pods |
  | DR-007 | Full cluster loss | Critical | 4 hours | Rebuild cluster, restore from Velero + Atlas + Git |
  | DR-008 | GCP region outage | Critical | 8 hours | Cross-region failover (see Cross-Region Readiness) |
  | DR-009 | DNS/Cloudflare outage | Medium | 30 min | Failover DNS provider or direct IP access |
  | DR-010 | Container registry unavailable | Medium | 30 min | Images cached on nodes; rebuild from Dockerfile if needed |
  | DR-011 | Secrets manager (Infisical) outage | Medium | 2 hours | ExternalSecrets cache (1h refresh); manual secret injection |

#### Recovery Validation

- The system MUST run automated restore drills monthly via the `restore-test` CronJob in the `velero` namespace
- The system MUST restore into a throwaway namespace (`velero-restore-test` or `mereka-lms-dr`) and MUST NOT restore into production
- Each restore drill MUST validate:
  - PVC resources are restored and in `Bound` state
  - MySQL pod starts and responds to a read-only `SELECT 1` probe
  - Restored resource count matches the source backup's resource count within 10% tolerance
- The system MUST run a `backup-verification` CronJob daily to confirm backup freshness and completeness
- The system MUST generate a DR evidence bundle monthly via `./scripts/qa/build-dr-evidence-bundle.sh --tar` or the GitHub Actions workflow `.github/workflows/dr-evidence-bundle.yml`
- Each DR evidence bundle MUST include:
  - `audit-velero.json` (backup schedule health)
  - `audit-velero-alert-pipeline.json` (alert pipeline health)
  - `audit-observability-runtime.json` (monitoring coverage)
  - Latest `restore-test` job logs and describe output
  - Restored PVC summary (bound count)
  - MySQL probe result from restore job log
- DR evidence bundles MUST be retained for 12 months
- The system SHOULD run a full-stack DR drill (complete namespace restore + application health check) quarterly

#### Data Integrity Verification

- The system MUST verify MySQL data integrity post-restore by running `SELECT 1` probe against the restored MySQL pod
- The system SHOULD verify MySQL data integrity post-restore by running `SELECT COUNT(*) FROM openedx.auth_user` and comparing against the last known user count (within 5% tolerance)
- The system MUST verify MongoDB Atlas data accessibility post-incident by confirming modulestore course count is non-zero: `sum(1 for _ in modulestore().get_courses()) > 0`
- The system SHOULD verify post-restore data consistency by running `./scripts/qa/public-health-check.sh prod` against the restored environment
- The system MUST maintain a backup coverage matrix (`docs/operations/BACKUP_COVERAGE_MATRIX.md`) that maps every stateful component to its backup mechanism and verification command

#### Cross-Region Failover Readiness

- The system MUST maintain infrastructure-as-code (Terraform, Kustomize) capable of deploying a secondary GKE cluster in a different GCP region
- The system SHOULD store Velero backups in a multi-region GCS bucket (or replicate to a secondary region bucket)
- The system MUST ensure MongoDB Atlas cluster is accessible from multiple GCP regions (Atlas networking/peering)
- The system SHOULD maintain a documented procedure for cross-region DNS cutover via Cloudflare
- The system MUST maintain container images in Artifact Registry with multi-region replication enabled (`asia-southeast1` primary)
- The system MAY implement automated GKE cluster provisioning in a secondary region triggered by primary region health check failure

#### Secrets Recovery

- The system MUST be able to restore all K8s secrets from Infisical + GCP Secret Manager without relying on in-cluster secret state
- The system MUST rotate all secrets after a security-related DR event (compromise scenario DR-006)
- The system MUST document the secret rotation checklist in `docs/operations/SECRET_ROTATION_CHECKLIST.md`
- The system SHOULD complete full secret rotation within 1 hour of incident declaration

#### Business Continuity

- The system MUST define an incident communication plan with the following escalation tiers:

  | Tier | Trigger | Response Time | Notification Channel |
  |------|---------|---------------|---------------------|
  | P1 (Critical) | Full outage, data loss confirmed | 15 minutes | Phone + Slack + Email to all stakeholders |
  | P2 (High) | Partial outage, degraded service | 30 minutes | Slack + Email to engineering + account managers |
  | P3 (Medium) | Single component failure, self-healing | 1 hour | Slack engineering channel |
  | P4 (Low) | Monitoring gap, backup warning | Next business day | Slack engineering channel |

- The system MUST designate primary and secondary DR coordinators with documented contact information
- The system MUST maintain a status page at `https://status.mereka.dev` (Upptime) reflecting real-time platform status
- The system MUST publish incident postmortems within 5 business days of P1/P2 incidents
- The system SHOULD conduct a tabletop DR exercise semi-annually covering scenario DR-007 (full cluster loss)

### Non-functional (NFRs)

#### Performance

- Velero backup completion time MUST be under 30 minutes for hourly critical schedule
- Velero restore completion time MUST be under 15 minutes for single-namespace restore
- Full cluster rebuild from scratch MUST complete within 4 hours including image pulls and data restoration
- Pre-operation backup (`--wait`) MUST complete within 10 minutes

#### Reliability

- Backup success rate MUST be >= 99% over a 30-day rolling window (no more than 1 failed backup per 100)
- Restore drill success rate MUST be >= 95% over a 12-month rolling window
- Backup monitoring MUST detect and alert on failures within 1 hour of occurrence

#### Security

- Velero backup storage (GCS) MUST be encrypted at rest using Google-managed encryption keys (minimum)
- Velero backup storage MUST have IAM access restricted to the Velero service account only
- DR evidence bundles MUST NOT contain plaintext secrets (sanitize before upload)
- Cross-region backup replication MUST use encrypted transport (TLS)
- Restored namespaces MUST be deleted within 1 hour of drill completion to prevent secret exposure

#### Compliance

- The system MUST generate audit-ready DR evidence on demand (within 1 business day)
- The system MUST retain DR evidence bundles for a minimum of 12 months
- The system MUST track DR drill history with dates, results, and remediation actions
- The system SHOULD maintain a DR compliance dashboard showing backup freshness, drill results, and evidence bundle age

#### Observability

- The system MUST emit metrics for backup success/failure, restore drill success/failure, and backup age
- The system MUST alert when backup age exceeds 2x the scheduled interval (e.g., >2 hours for hourly backups)
- The system MUST alert when restore drill has not succeeded in >45 days

## Acceptance Criteria

### Backup Infrastructure

- [ ] AC-001: Given production is running, when `./scripts/qa/audit-velero.sh --json` executes, then it reports all three schedules (hourly-critical, daily-all-apps, weekly-full) as active with recent Completed backups
- [ ] AC-002: Given the hourly-critical schedule runs, when the backup completes, then `volumeSnapshotsCompleted` equals the number of Bound PVCs reported by `./scripts/qa/list-critical-backup-pvcs.sh`
- [ ] AC-003: Given a Velero backup exists, when `BackupStorageLocation` is queried, then its phase is `Available`
- [ ] AC-004: Given production namespaces, when all Deployments/StatefulSets are inspected, then no critical stateful service uses `emptyDir` for persistent data

### Restore Drills

- [ ] AC-005: Given the monthly restore-test CronJob runs, when it completes, then a throwaway namespace is created, PVCs are restored to Bound state, and a MySQL `SELECT 1` probe succeeds
- [ ] AC-006: Given a restore drill completes, when the throwaway namespace is inspected, then at least 1 PVC is in Bound state matching the source backup
- [ ] AC-007: Given a restore drill, when `./scripts/infra/fix-velero-restore-test.sh` executes, then the drill passes end-to-end including PV validation and MySQL probe
- [ ] AC-008: Given the backup-verification CronJob, when it runs daily, then it confirms backup freshness within the last 2 hours for hourly schedule and 26 hours for daily schedule

### DR Evidence

- [ ] AC-009: Given the DR evidence bundle workflow runs, when `STRICT_RUNTIME=1 ./scripts/qa/build-dr-evidence-bundle.sh --tar` executes, then it produces a tarball containing audit-velero.json, audit-velero-alert-pipeline.json, audit-observability-runtime.json, restore-test logs, and PVC summary
- [ ] AC-010: Given GitHub Actions DR Evidence Bundle workflow, when it runs monthly (1st of month at 02:30 UTC), then artifacts are uploaded with 120-day retention
- [ ] AC-011: Given an enterprise audit request, when DR evidence is requested, then a complete evidence bundle can be generated within 1 business day

### Alert Pipeline

- [ ] AC-012: Given Velero backup fails, when the failure is detected, then an alert fires within 1 hour
- [ ] AC-013: Given restore-test has not succeeded in 45+ days, when `STRICT_RUNTIME=1 ./scripts/qa/audit-velero-alert-pipeline.sh` runs, then it reports a stale-restore-test failure
- [ ] AC-014: Given `./scripts/qa/audit-velero-alert-pipeline.sh` runs, then it validates both backup-verification and restore-test freshness signals

### Recovery Procedures

- [ ] AC-015: Given a single PVC failure (DR-002), when the documented restore procedure is followed, then the PVC is restored from the latest hourly backup within 30 minutes
- [ ] AC-016: Given a full namespace loss (DR-003), when `velero restore create` is executed with `--namespace-mappings`, then all resources including PVCs are restored within 1 hour
- [ ] AC-017: Given a secret compromise (DR-006), when the secret rotation checklist is followed, then all affected secrets are rotated in Infisical, synced to GCP SM, and pods restarted within 1 hour
- [ ] AC-018: Given complete cluster loss (DR-007), when the cluster rebuild procedure is followed, then platform availability is restored within 4 hours with data loss not exceeding 1 hour (Tier 1 RPO)

### Data Integrity

- [ ] AC-019: Given a restore completes, when `kubectl exec mysql-pod -- mysql -e "SELECT COUNT(*) FROM openedx.auth_user"` is run, then the count is within 5% of the pre-incident count
- [ ] AC-020: Given a restore completes, when `./scripts/qa/public-health-check.sh prod` runs, then LMS homepage, Studio login, Discovery, and Ecommerce health endpoints all return 200/302

### Cross-Region Readiness

- [ ] AC-021: Given Terraform/Kustomize configs exist, when `kubectl kustomize deploy/k8s/overlays/production` is run, then it produces valid manifests deployable to any GKE cluster
- [ ] AC-022: Given Velero backups are stored in GCS, when the backup bucket is inspected, then it is configured for multi-region storage or cross-region replication

## Edge Cases

### Velero Backup Succeeds but Volume Snapshots are Zero

**Symptom**: Backup shows `Completed` but `volumeSnapshotsCompleted: 0`

**Cause**: Backup only captured K8s objects, not PV data. Missing `volumeSnapshotLocations` config or CSI driver issue.

**Detection**: `./scripts/qa/audit-velero.sh` flags this as a critical failure.

**Recovery**:
```bash
# Verify schedule config
kubectl -n velero get schedule <name> -o yaml | grep -A5 volumeSnapshot
# Fix: ensure includeClusterResources: true and volumeSnapshotLocations: ["default"]
```

### Restore Drill CronJob Silently Broken

**Symptom**: CronJob exists but jobs fail with `StartError` or never complete.

**Cause**: Wrong image, missing command, or stuck namespace from previous run.

**Detection**: `STRICT_RUNTIME=1 ./scripts/qa/audit-velero-alert-pipeline.sh` detects stale restore-test.

**Recovery**:
```bash
./scripts/infra/fix-velero-restore-test.sh
```

### Backup-Restore Namespace Stuck in Terminating

**Symptom**: `velero-restore-test` namespace stuck in `Terminating` for hours.

**Cause**: Finalizers on restored resources preventing namespace deletion.

**Recovery**:
```bash
# Remove finalizers from stuck resources
kubectl get all -n velero-restore-test -o name | xargs -I{} kubectl -n velero-restore-test patch {} --type merge -p '{"metadata":{"finalizers":null}}'
# Force delete namespace
kubectl delete ns velero-restore-test --force --grace-period=0
```

### Atlas Backup Verification Failure

**Symptom**: Atlas snapshots list is empty or snapshots are stale.

**Cause**: Atlas backup policy not enabled, or cluster tier does not support backups (M0 free tier).

**Recovery**:
```bash
# Check Atlas snapshots
atlas backups snapshots list cluster-mereka-lms --projectId <PROJECT_ID>
# Enable backups in Atlas UI or upgrade cluster tier
```

### Partial Restore with Acceptable Errors

**Symptom**: Restore completes with `PartiallyFailed` status, some resources have errors.

**Cause**: CRD version mismatches, immutable fields, or resources that cannot be restored (e.g., bound PVs with conflicting names).

**Detection**: Restore-test script accepts partial failures when `errors <= MAX_PARTIAL_ERRORS (10)`.

**Acceptable**: Warnings from namespace-scoped resources that already exist.
**Not acceptable**: PVC restore failures or core deployment restore failures.

### Secrets Desync After Restore

**Symptom**: Pods fail to start after restore because secrets reference stale ExternalSecrets.

**Cause**: ExternalSecrets operator re-syncs on a 1-hour interval; restored secrets may be from a different point in time.

**Recovery**:
```bash
# Force ExternalSecrets resync
kubectl -n mereka-lms delete secret openedx-secrets database-secrets
# ExternalSecrets operator recreates within refreshInterval (1h) or immediately after delete
# Or restart ESO
kubectl -n external-secrets rollout restart deployment external-secrets
```

### GCS Bucket Inaccessible During Restore

**Symptom**: Velero cannot read backups from GCS.

**Cause**: IAM permissions revoked, bucket deleted, or GCS regional outage.

**Recovery**:
- Verify IAM: `gcloud storage buckets get-iam-policy gs://BUCKET_NAME`
- If bucket is in the same region as the outage, rely on multi-region replication (if configured) or Atlas + Git for rebuild

### Concurrent Backup and Restore Operations

**Symptom**: Restore fails or produces inconsistent state.

**Cause**: Running a restore while a backup is in progress for the same namespace.

**Mitigation**: The system MUST NOT run restore operations concurrently with backup operations for the same namespace. Pre-op backup should complete (`--wait`) before any restore.

### Clock Skew in Backup Freshness Checks

**Symptom**: Audit scripts report stale backups despite backups running on schedule.

**Cause**: Node clock skew or timezone mismatch between GKE nodes and monitoring.

**Detection**: Compare `status.completionTimestamp` against `date -u` on audit host.

**Mitigation**: All timestamps MUST use UTC. NTP MUST be configured on GKE nodes (GKE default).

## Observability

### Logs

- Velero controller logs: `kubectl logs -n velero -l app.kubernetes.io/name=velero`
- Restore-test job logs: `kubectl logs -n velero -l component=restore-test`
- Backup-verification job logs: `kubectl logs -n velero -l component=backup-verification`
- DR evidence bundle output: `var/dr-evidence/` (gitignored)

### Metrics

| Metric | Type | Source | Alert Threshold |
|--------|------|--------|-----------------|
| `velero_backup_success_total` | Counter | Velero | Increments on every successful backup |
| `velero_backup_failure_total` | Counter | Velero | Alert if > 0 in 2-hour window |
| `velero_backup_last_successful_timestamp` | Gauge | Velero | Alert if > 2 hours stale for hourly schedule |
| `velero_restore_success_total` | Counter | Velero | Increments on restore drill success |
| `velero_restore_failure_total` | Counter | Velero | Alert if > 0 |
| `velero_backup_items_total` | Gauge | Velero | Sudden drops indicate backup scope regression |
| `velero_volume_snapshot_completed` | Gauge | Velero | Must match bound PVC count |
| `dr_evidence_bundle_age_days` | Gauge | Custom | Alert if > 35 days |
| `dr_restore_drill_age_days` | Gauge | Custom | Alert if > 45 days |

### Alerts

| Alert Name | Severity | Condition | Response |
|------------|----------|-----------|----------|
| `VeleroBackupFailed` | P2 | Any backup fails | Investigate Velero logs, check BSL phase, verify GCS access |
| `VeleroBackupStale` | P2 | Hourly backup >2h stale | Check Velero controller, CronJob status |
| `VeleroRestoreTestStale` | P2 | Restore-test not succeeded in >45 days | Run `./scripts/infra/fix-velero-restore-test.sh` |
| `VeleroSnapshotMismatch` | P1 | `volumeSnapshotsCompleted` < bound PVC count | Investigate CSI driver, snapshot provider |
| `BackupVerificationFailed` | P2 | Daily verification job fails | Check backup-verification CronJob logs |
| `DREvidenceBundleStale` | P3 | Evidence bundle >35 days old | Run evidence bundle workflow manually |
| `EmptyDirCriticalData` | P1 | Critical data on emptyDir detected | Migrate to PVC immediately |
| `AtlasBackupStale` | P2 | Atlas snapshot >48h stale | Check Atlas backup policy, cluster tier |

### Dashboards

- `Mereka LMS - Operations Signals` dashboard MUST include a Velero backup health panel
- A dedicated `Mereka LMS - DR Health` dashboard SHOULD be created showing:
  - Backup freshness per schedule (time since last successful backup)
  - Restore drill history (last 12 months)
  - Volume snapshot count vs. bound PVC count
  - Evidence bundle freshness
  - Alert pipeline health status

## Rollout & Rollback

### Rollout Plan

This spec formalizes existing infrastructure. Rollout is incremental:

**Phase 1 -- Baseline Hardening (Week 1-2)**
1. Verify all existing Velero schedules match the requirements in this spec
2. Enable Atlas continuous backup + verify snapshot policy
3. Verify GCS backup bucket encryption and IAM restrictions
4. Update `docs/operations/BACKUP_COVERAGE_MATRIX.md` to match spec requirements
5. Gate: `./scripts/qa/audit-velero.sh` returns all-green

**Phase 2 -- Monitoring and Alerting (Week 3-4)**
1. Deploy Velero metrics exporter (if not already present)
2. Create/update alert rules for all alerts defined in Observability section
3. Create DR Health dashboard in Grafana
4. Verify alert routing reaches on-call via `./scripts/qa/verify-alert-routing.sh`
5. Gate: All alerts defined in this spec are active and testable

**Phase 3 -- Cross-Region Readiness (Week 5-8)**
1. Configure GCS backup bucket for multi-region or cross-region replication
2. Enable Artifact Registry multi-region replication
3. Document cross-region cluster provisioning procedure
4. Document DNS failover procedure via Cloudflare
5. Gate: Documented procedure tested in tabletop exercise

**Phase 4 -- Compliance and Evidence (Week 9-10)**
1. Verify DR evidence bundle workflow produces complete output
2. Configure evidence retention for 12 months
3. Create DR compliance report template for enterprise clients
4. Conduct first formal tabletop DR exercise
5. Gate: Evidence bundle passes audit review

### Feature Flags

- `ENABLE_CLOUD_SQL_BACKUPS` (GitHub Actions repo variable): Activates Cloud SQL backup workflow when MySQL migrates to Cloud SQL
- `STRICT_RUNTIME` (environment variable): When set to `1`, DR evidence scripts fail on missing runtime dependencies instead of warning

### Backward Compatibility

- This spec does not change any existing backup behavior
- All existing Velero schedules, CronJobs, and scripts are preserved
- New requirements are additive (additional alerts, dashboards, evidence retention)

### Rollback Steps

If any phase introduces issues:

1. **Phase 1**: No rollback needed (verification only)
2. **Phase 2**: Delete new alert rules via `kubectl delete prometheusrule <name> -n mereka-lms`; dashboard deletion in Grafana UI
3. **Phase 3**: GCS bucket config is non-destructive; Artifact Registry replication can be disabled; no cluster changes
4. **Phase 4**: Evidence workflow is additive; can be disabled by removing the GitHub Actions schedule

## Open Questions

1. **Atlas backup tier**: What Atlas cluster tier is currently active (M0/M10/M20)? M0 free tier does not support continuous backup or PITR. If M0, must upgrade before this spec's Atlas requirements can be met.
2. **GCS backup bucket name and region**: What is the current Velero GCS bucket name, region, and storage class? Is it single-region or multi-region? This determines cross-region readiness baseline.
3. **Enterprise SLA contractual language**: What specific uptime and data durability percentages are promised in enterprise contracts? This spec proposes 99.9% availability and 1-hour RPO; these numbers need validation against actual contract language.
4. **DR coordinator assignment**: Who are the primary and secondary DR coordinators? Names and contact information are required for the business continuity plan.
5. **Budget for cross-region**: Is there budget approved for multi-region GCS storage and Artifact Registry replication? These have recurring cost implications.
6. **Atlas snapshot retention**: What is the desired Atlas snapshot retention period? This spec proposes 7-day PITR minimum; Atlas pricing varies by retention.
7. **Compliance frameworks**: Are there specific compliance frameworks (ISO 27001, SOC 2, PDPA) that the DR evidence must satisfy? This affects evidence format and retention requirements.
8. **Tabletop exercise participants**: Who should participate in semi-annual DR tabletop exercises? Engineering only, or including product/business stakeholders?
9. **Status page integration**: Should the Upptime status page at `status.mereka.dev` automatically reflect DR events, or is manual update acceptable?
10. **MySQL migration to Cloud SQL timeline**: When is MySQL expected to migrate to Cloud SQL? This affects whether the Cloud SQL backup workflow needs activation and changes the Tier 1 backup strategy.
