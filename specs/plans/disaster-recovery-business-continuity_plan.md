---
spec: disaster-recovery-business-continuity_spec.md
tier: 3
status: draft
estimated_effort: L
owner: engineering
last_updated: "2026-02-10"
prerequisites:
  - repository-structure_spec.md (Tier 0, APPROVED)
  - secrets-management_spec.md (Tier 0, IN_REVIEW)
  - k8s-deployment_spec.md (Tier 1, DRAFT)
  - observability-stack_spec.md (Tier 2, DRAFT)
  - mongodb-atlas-integration_spec.md (related)
---

# Implementation Plan: Disaster Recovery & Business Continuity

**Source Spec**: `specs/disaster-recovery-business-continuity_spec.md`
**Tier**: 3 -- Operational Resilience
**Blocks**: Enterprise audit compliance, SLA contractual commitments

## Summary

The DR/BC spec formalizes existing backup infrastructure (Velero schedules, Atlas snapshots, restore-test CronJobs, DR evidence bundles) into a machine-checkable contract with testable acceptance criteria. Much of the infrastructure already exists. This plan focuses on:

1. **Baseline hardening** -- verifying existing Velero schedules, Atlas backup config, and GCS bucket security match spec requirements; closing any gaps.
2. **Monitoring and alerting** -- deploying all alerts and dashboards defined in the Observability section.
3. **Cross-region readiness** -- documenting and validating failover procedures; configuring multi-region GCS and Artifact Registry replication.
4. **Compliance and evidence** -- hardening the DR evidence bundle workflow, configuring retention, and creating the enterprise compliance report template.
5. **Verification automation** -- building shell scripts that machine-check every acceptance criterion.

## Current State Analysis

The codebase already provides substantial coverage:

- **Velero schedules**: Three schedules (hourly-critical, daily-all-apps, weekly-full) deployed in the `velero` namespace.
- **Restore-test CronJob**: Exists at `infrastructure/k8s/velero/restore-test-script.sh` and the CronJob manifest.
- **DR evidence bundle**: Exists at `scripts/qa/build-dr-evidence-bundle.sh` with GitHub Actions workflow `.github/workflows/dr-evidence-bundle.yml`.
- **Audit scripts**: `scripts/qa/audit-velero.sh` and `scripts/qa/audit-velero-alert-pipeline.sh` exist.
- **Backup coverage matrix**: `docs/operations/BACKUP_COVERAGE_MATRIX.md` exists.
- **Monitoring**: Prometheus, Loki, Grafana operational per observability stack.
- **Atlas**: MongoDB Atlas cluster at `cluster-mereka-lms.2pjex4s.mongodb.net` with continuous backup.

### Gaps Identified

| Gap | AC(s) Affected | Severity |
|-----|---------------|----------|
| Velero schedule configs need verification against spec requirements (includeClusterResources, volumeSnapshotLocations) | AC-001, AC-002 | High |
| Backup-verification daily CronJob may not exist or may not check freshness thresholds | AC-008 | Medium |
| DR evidence bundle may not include all six required artifacts | AC-009, AC-010 | Medium |
| Alert rules for Velero backup failure, stale restore-test, snapshot mismatch need verification | AC-012, AC-013, AC-014 | High |
| No automated check for emptyDir critical data | AC-004 | Medium |
| Cross-region GCS bucket replication not configured | AC-022 | Low (Phase 3) |
| Secret rotation checklist may not exist | AC-017 | Medium |
| DR Health dashboard not created | Observability/Dashboards | Medium |
| No verification scripts mapping to all 22 ACs | All | High |

---

## Task Breakdown

### Phase 1: Baseline Hardening (Week 1-2)

#### Build

- [ ] **[M]** B-01: Verify and fix Velero schedule configurations -- ensure all three schedules (hourly-critical, daily-all-apps, weekly-full) have `includeClusterResources: true`, `volumeSnapshotLocations: ["default"]`, correct namespaces, correct retention (48h/30d/90d) (`infrastructure/k8s/velero/schedules/`) | AC: #001, #002 | Depends: None

- [ ] **[S]** B-02: Verify BackupStorageLocation phase is `Available` by adding check to existing `scripts/qa/audit-velero.sh` (`scripts/qa/audit-velero.sh`) | AC: #003 | Depends: None

- [ ] **[M]** B-03: Create emptyDir critical data scanner -- script that inspects all Deployments/StatefulSets in production namespaces and flags any critical stateful service using `emptyDir` for persistent data (`scripts/qa/verify-no-emptydir-critical.sh`) | AC: #004 | Depends: None

- [ ] **[M]** B-04: Verify MongoDB Atlas backup configuration -- confirm continuous backup enabled, PITR window >= 7 days, snapshot policy active for `cluster-mereka-lms` (`scripts/qa/verify-atlas-backup.sh`) | AC: #002 (Atlas backup requirements) | Depends: None

- [ ] **[S]** B-05: Verify GCS backup bucket encryption and IAM -- confirm Google-managed encryption at rest, Velero service account is sole IAM principal with write access (`scripts/qa/verify-velero-gcs-security.sh`) | AC: Observability/Security NFRs | Depends: None

- [ ] **[M]** B-06: Update `docs/operations/BACKUP_COVERAGE_MATRIX.md` to match spec requirements -- map every stateful component to its backup mechanism and verification command (`docs/operations/BACKUP_COVERAGE_MATRIX.md`) | AC: #019 (data integrity) | Depends: None

- [ ] **[S]** B-07: Verify Cloud SQL backup workflow exists in disabled state at `.github/workflows/cloud-sql-backup.yml` with `ENABLE_CLOUD_SQL_BACKUPS` activation gate (`.github/workflows/cloud-sql-backup.yml`) | AC: Backup strategy (legacy Cloud SQL) | Depends: None

- [ ] **[S]** B-08: Verify pre-operation backup script exists or create one -- `scripts/infra/pre-op-backup.sh` that creates a named Velero backup with `--wait` before risky operations (`scripts/infra/pre-op-backup.sh`) | AC: Backup strategy (pre-op backup) | Depends: None

#### Test

- [ ] **[M]** T-01: Create `scripts/qa/verify-dr-baseline.sh` -- comprehensive baseline verification script that checks all Phase 1 ACs: Velero schedule health, BSL phase, emptyDir scan, Atlas backup config, GCS bucket security (`scripts/qa/verify-dr-baseline.sh`) | AC: #001-#004 | Depends: B-01 through B-05

---

### Phase 2: Monitoring and Alerting (Week 3-4)

#### Build

- [ ] **[M]** B-09: Deploy/verify Velero metrics exporter -- confirm Velero exposes Prometheus metrics (`velero_backup_success_total`, `velero_backup_failure_total`, `velero_backup_last_successful_timestamp`, `velero_restore_success_total`, `velero_restore_failure_total`, `velero_backup_items_total`, `velero_volume_snapshot_completed`); add ServiceMonitor if not present (`infrastructure/monitoring/velero-servicemonitor.yaml`) | AC: Observability/Metrics | Depends: None

- [ ] **[M]** B-10: Create/update PrometheusRule for all DR alerts -- `VeleroBackupFailed`, `VeleroBackupStale`, `VeleroRestoreTestStale`, `VeleroSnapshotMismatch`, `BackupVerificationFailed`, `DREvidenceBundleStale`, `EmptyDirCriticalData`, `AtlasBackupStale` (`infrastructure/monitoring/alerts/dr-alerts.yaml`) | AC: #012, #013, #014, Observability/Alerts | Depends: B-09

- [ ] **[S]** B-11: Create custom metrics exporter for DR evidence bundle age and restore drill age -- `dr_evidence_bundle_age_days`, `dr_restore_drill_age_days` gauges (`infrastructure/monitoring/exporters/dr-custom-exporter.yaml`) | AC: Observability/Metrics | Depends: B-09

- [ ] **[M]** B-12: Create or update backup-verification daily CronJob -- confirms backup freshness: <2 hours for hourly schedule, <26 hours for daily schedule; runs in `velero` namespace (`infrastructure/k8s/velero/backup-verification-cronjob.yaml`) | AC: #008 | Depends: None

- [ ] **[M]** B-13: Create Grafana dashboard "Mereka LMS - DR Health" -- backup freshness per schedule, restore drill history (12 months), volume snapshot count vs bound PVC count, evidence bundle freshness, alert pipeline health (`infrastructure/monitoring/dashboards/dr-health.json`) | AC: Observability/Dashboards | Depends: B-09, B-11

- [ ] **[S]** B-14: Verify existing Operations Signals dashboard includes Velero backup health panel (`infrastructure/monitoring/dashboards/operations-signals.json`) | AC: Observability/Dashboards | Depends: None

- [ ] **[S]** B-15: Create/verify alert routing reaches on-call -- `scripts/qa/verify-alert-routing.sh` validates that DR alerts route to the correct notification channel (`scripts/qa/verify-alert-routing.sh`) | AC: Phase 2 gate | Depends: B-10

#### Test

- [ ] **[M]** T-02: Create `scripts/qa/verify-dr-monitoring.sh` -- verification script checking all Phase 2 ACs: alert rules exist, dashboard loaded, metrics present, alert routing configured (`scripts/qa/verify-dr-monitoring.sh`) | AC: #012-#014, Observability | Depends: B-09 through B-15

---

### Phase 3: Restore Drills and Recovery Validation (Week 5-6)

#### Build

- [ ] **[M]** B-16: Harden restore-test CronJob -- verify it restores into throwaway namespace (`velero-restore-test` or `mereka-lms-dr`), validates PVC Bound state, runs MySQL `SELECT 1` probe, compares resource count within 10% tolerance, deletes throwaway namespace within 1 hour (`infrastructure/k8s/velero/restore-test-script.sh`) | AC: #005, #006, #007 | Depends: None

- [ ] **[M]** B-17: Create/harden `scripts/infra/fix-velero-restore-test.sh` -- fixes common restore-test failures (stuck namespace, wrong image, missing command) and runs the drill end-to-end (`scripts/infra/fix-velero-restore-test.sh`) | AC: #007 | Depends: B-16

- [ ] **[S]** B-18: Verify restore drill runs monthly via CronJob schedule -- confirm CronJob schedule expression triggers at least monthly (`infrastructure/k8s/velero/restore-test-cronjob.yaml`) | AC: #005 | Depends: None

- [ ] **[M]** B-19: Add user count comparison to restore-test -- after restore, run `SELECT COUNT(*) FROM openedx.auth_user` and compare against last known count (within 5% tolerance); log result (`infrastructure/k8s/velero/restore-test-script.sh`) | AC: #019 | Depends: B-16

- [ ] **[S]** B-20: Add public health check to restore-test flow -- after restore, run `scripts/qa/public-health-check.sh` against restored environment endpoints (LMS homepage, Studio login, Discovery, Ecommerce) (`infrastructure/k8s/velero/restore-test-script.sh`) | AC: #020 | Depends: B-16

#### Test

- [ ] **[M]** T-03: Create `scripts/qa/verify-dr-restore-drills.sh` -- verification script checking restore drill ACs: CronJob exists with monthly schedule, last job completed, PVC Bound count >= 1, MySQL probe succeeded (`scripts/qa/verify-dr-restore-drills.sh`) | AC: #005-#008, #019, #020 | Depends: B-16 through B-20

---

### Phase 4: DR Evidence and Compliance (Week 7-8)

#### Build

- [ ] **[M]** B-21: Harden DR evidence bundle -- ensure `./scripts/qa/build-dr-evidence-bundle.sh --tar` includes all six required artifacts: `audit-velero.json`, `audit-velero-alert-pipeline.json`, `audit-observability-runtime.json`, restore-test logs, PVC summary, MySQL probe result (`scripts/qa/build-dr-evidence-bundle.sh`) | AC: #009 | Depends: None

- [ ] **[S]** B-22: Verify GitHub Actions DR Evidence Bundle workflow -- runs monthly (1st of month at 02:30 UTC), uploads artifacts with 120-day retention (`.github/workflows/dr-evidence-bundle.yml`) | AC: #010 | Depends: None

- [ ] **[M]** B-23: Configure DR evidence retention for 12 months -- set up GCS bucket or GitHub artifact retention policy for evidence bundles; create retention management script (`scripts/infra/dr-evidence-retention.sh`) | AC: #011, Compliance NFRs | Depends: B-21

- [ ] **[M]** B-24: Create DR compliance report template for enterprise clients -- Markdown/PDF template that aggregates evidence bundle data into an audit-ready report (`docs/operations/DR_COMPLIANCE_REPORT_TEMPLATE.md`) | AC: #011 | Depends: B-21

- [ ] **[S]** B-25: Create DR drill history tracker -- log file or database tracking drill dates, results, and remediation actions (`docs/operations/DR_DRILL_HISTORY.md`) | AC: Compliance NFRs | Depends: None

#### Test

- [ ] **[M]** T-04: Create `scripts/qa/verify-dr-evidence.sh` -- verification script checking evidence ACs: bundle produces all artifacts, STRICT_RUNTIME=1 passes, evidence retention configured, evidence can be generated within 1 business day (`scripts/qa/verify-dr-evidence.sh`) | AC: #009-#011 | Depends: B-21 through B-25

---

### Phase 5: Recovery Procedures and Cross-Region Readiness (Week 9-12)

#### Build

- [ ] **[L]** B-26: Document and validate all disaster scenario response procedures (DR-001 through DR-011) -- create or update runbook entries for each scenario with step-by-step recovery commands, expected RTO, and verification commands (`docs/operations/DISASTER_RECOVERY.md`) | AC: #015-#018 | Depends: None

- [ ] **[M]** B-27: Create secret rotation checklist -- document the full rotation procedure for all K8s secrets via Infisical + GCP SM, including post-rotation pod restart verification (`docs/operations/SECRET_ROTATION_CHECKLIST.md`) | AC: #017 | Depends: None

- [ ] **[M]** B-28: Verify Terraform/Kustomize IaC is deployable to any GKE cluster -- run `kubectl kustomize deploy/k8s/overlays/production` and validate manifests are self-contained (`scripts/qa/verify-cross-region-iac.sh`) | AC: #021 | Depends: None

- [ ] **[M]** B-29: Configure GCS backup bucket for multi-region storage or cross-region replication (`infrastructure/terraform/gcs-velero-bucket.tf`) | AC: #022 | Depends: None

- [ ] **[S]** B-30: Verify Artifact Registry multi-region replication is enabled for `ghcr.io/biji-biji-initiative/mereka-lms` (`scripts/qa/verify-artifact-registry-replication.sh`) | AC: Cross-region readiness | Depends: None

- [ ] **[M]** B-31: Document cross-region DNS failover procedure via Cloudflare (`docs/operations/CROSS_REGION_FAILOVER.md`) | AC: Cross-region readiness | Depends: None

- [ ] **[M]** B-32: Define incident communication plan and escalation tiers (P1-P4) -- designate DR coordinators, document contact information, configure status page integration (`docs/operations/INCIDENT_COMMUNICATION_PLAN.md`) | AC: Business continuity | Depends: None

- [ ] **[S]** B-33: Verify status page at `https://status.mereka.dev` reflects real-time platform status (`scripts/qa/verify-status-page.sh`) | AC: Business continuity | Depends: None

- [ ] **[S]** B-34: Create tabletop DR exercise template -- structured exercise covering DR-007 (full cluster loss) for semi-annual execution (`docs/operations/DR_TABLETOP_EXERCISE_TEMPLATE.md`) | AC: Business continuity | Depends: None

#### Test

- [ ] **[M]** T-05: Create `scripts/qa/verify-dr-procedures.sh` -- verification script checking recovery procedure ACs: runbook completeness, secret rotation checklist exists, IaC renders valid manifests, GCS bucket config, DNS failover documented (`scripts/qa/verify-dr-procedures.sh`) | AC: #015-#018, #021-#022 | Depends: B-26 through B-34

---

### Phase 6: Comprehensive Verification (Week 13)

#### Test

- [ ] **[L]** T-06: Create `scripts/qa/verify-dr-spec-full.sh` -- comprehensive verification script that runs all DR sub-verifiers (baseline, monitoring, restore drills, evidence, procedures) and produces a pass/fail report for all 22 ACs (`scripts/qa/verify-dr-spec-full.sh`) | AC: #001-#022 | Depends: T-01 through T-05

- [ ] **[M]** T-07: Run full DR spec verification against production and generate gap report (`scripts/qa/verify-dr-spec-full.sh`) | AC: all | Depends: T-06

#### Observability

- [ ] **[S]** O-01: Verify Promtail captures Velero controller logs, restore-test job logs, and backup-verification job logs (`deploy/k8s/base/logging/promtail-configmap.yaml`) | AC: Observability/Logs | Depends: None

- [ ] **[S]** O-02: Verify DR evidence bundle output directory is gitignored (`var/dr-evidence/`) | AC: Observability/Logs | Depends: None

#### Docs

- [ ] **[M]** D-01: Update `docs/operations/TROUBLESHOOTING.md` with all edge cases from spec (zero-snapshot backup, broken CronJob, stuck namespace, Atlas verification, partial restore, secrets desync, GCS inaccessible, concurrent backup/restore, clock skew) (`docs/operations/TROUBLESHOOTING.md`) | Depends: None

- [ ] **[S]** D-02: Update `docs/operations/DEPLOYMENT_RUNBOOK.md` to reference pre-operation backup procedure (`docs/operations/DEPLOYMENT_RUNBOOK.md`) | Depends: B-08

- [ ] **[S]** D-03: Create postmortem template for P1/P2 incidents -- to be completed within 5 business days per spec (`docs/operations/POSTMORTEM_TEMPLATE.md`) | AC: Business continuity | Depends: None

#### Rollout

- [ ] **[S]** R-01: Run `verify-dr-baseline.sh` against current cluster and file issues (beads) for any remaining gaps | Depends: T-01

- [ ] **[M]** R-02: Apply all infrastructure changes via standard rollout procedure (dry run, apply, verify, smoke test) | Depends: All Build tasks

- [ ] **[S]** R-03: Run full verification (`verify-dr-spec-full.sh`) post-apply and capture results | Depends: R-02, T-06

- [ ] **[S]** R-04: Conduct first tabletop DR exercise using the template | Depends: B-34, R-02

---

## Milestones

| Milestone | Tasks | Target |
|-----------|-------|--------|
| M1: Baseline hardened | B-01 through B-08, T-01 | Week 2 |
| M2: Monitoring and alerting live | B-09 through B-15, T-02 | Week 4 |
| M3: Restore drills validated | B-16 through B-20, T-03 | Week 6 |
| M4: Evidence and compliance ready | B-21 through B-25, T-04 | Week 8 |
| M5: Recovery procedures documented, cross-region ready | B-26 through B-34, T-05 | Week 12 |
| M6: Full verification pass | T-06, T-07, R-01 through R-04 | Week 13 |

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Atlas cluster is M0 free tier (no continuous backup / PITR) | AC-002 Atlas requirements cannot be met without upgrade | Resolve open question #1 before Phase 1; budget for Atlas tier upgrade |
| GCS backup bucket is single-region | Cross-region readiness (AC-022) requires multi-region migration | B-29 configures multi-region; resolve open question #2 for bucket details |
| Restore-test CronJob silently broken | Restore drill ACs fail; compliance risk | B-16/B-17 harden the CronJob; B-10 deploys `VeleroRestoreTestStale` alert |
| DR evidence bundle missing artifacts | Enterprise audit fails | B-21 hardens the bundle; T-04 verifies completeness |
| No budget approved for cross-region GCS and Artifact Registry replication | Phase 5 cross-region tasks blocked | Resolve open question #5 before Phase 5 |
| Velero backup succeeds but volume snapshots are zero | Data not actually backed up despite Completed status | B-01 verifies schedule config; B-10 deploys `VeleroSnapshotMismatch` alert |
| DR coordinator not assigned | Business continuity plan incomplete | Resolve open question #4 before Phase 5 |
| Clock skew causes false backup freshness alerts | Operational noise, alert fatigue | All timestamps use UTC; verify NTP on GKE nodes per spec |
| Concurrent backup and restore operations cause inconsistent state | Data integrity risk during drills | Pre-op backup uses `--wait`; document in runbook |

---

## Self-Check

- [x] Every acceptance criterion (AC-001 through AC-022) has at least one build or verification task
- [x] Every acceptance criterion has at least one test/verification script
- [x] Edge cases from spec mapped to troubleshooting docs (D-01)
- [x] File paths specified for every task
- [x] Dependencies identified for all tasks
- [x] Complexity estimated (S/M/L) for each task
- [x] Source spec linked in header
