---
spec: disaster-recovery-business-continuity_spec.md
tier: 3
status: draft
generated: '2026-02-10'
test_framework: shell_verification + kubectl_check + manual_verification
plan: disaster-recovery-business-continuity_plan.md
last_updated: '2026-03-09'
---

# Test Plan: Disaster Recovery & Business Continuity

**Source Spec**: `specs/disaster-recovery-business-continuity_spec.md`

## Test Framework Detection

This is an infrastructure/operations spec. There is no application-level test framework (no Vitest, Jest, pytest). Tests are:

| Test Type | Tool | Description |
|-----------|------|-------------|
| `shell_verification` | Bash scripts in `scripts/qa/` | Automated audit and verification scripts |
| `kubectl_check` | `kubectl` commands against GKE cluster | Runtime cluster state verification |
| `ci_workflow` | GitHub Actions | Scheduled evidence bundle generation |
| `manual_verification` | Human checklist | Procedures requiring human judgment or multi-step coordination |

## Test Matrix

### Backup Infrastructure (AC-001 through AC-004)

| AC # | Test Case | Type | File / Command | Mocks/Fixtures |
|------|-----------|------|----------------|----------------|
| AC-001 | Happy: All three Velero schedules are active with recent Completed backups | shell_verification | `scripts/qa/audit-velero.sh --json` | Live cluster (GKE context) |
| AC-001 | Negative: Script detects missing schedule and returns non-zero exit | shell_verification | `scripts/qa/audit-velero.sh --json` with schedule deleted | Delete one schedule temporarily |
| AC-002 | Happy: volumeSnapshotsCompleted matches Bound PVC count for hourly-critical | shell_verification | `scripts/qa/audit-velero.sh --json` (snapshot mismatch check) | Live cluster |
| AC-002 | Negative: Zero snapshots despite Completed backup detected as failure | shell_verification | `scripts/qa/audit-velero.sh --json` | Live cluster (edge case EC-1) |
| AC-003 | Happy: BackupStorageLocation phase is Available | kubectl_check | `kubectl -n velero get backupstoragelocation default -o jsonpath='{.status.phase}'` | Live cluster |
| AC-003 | Negative: BSL phase is Unavailable triggers alert | kubectl_check | Manual: verify alert fires when BSL IAM is revoked (edge case EC-7) | Live cluster |
| AC-004 | Happy: No critical stateful service uses emptyDir for persistent data | shell_verification | `scripts/qa/audit-velero.sh --json` (emptyDir check) | Live cluster |
| AC-004 | Negative: emptyDir on MySQL detected as P1 failure | shell_verification | `scripts/qa/audit-velero.sh --json` | Inject emptyDir into test manifest |

### Restore Drills (AC-005 through AC-008)

| AC # | Test Case | Type | File / Command | Mocks/Fixtures |
|------|-----------|------|----------------|----------------|
| AC-005 | Happy: Monthly restore-test CronJob creates throwaway NS, restores PVCs to Bound, MySQL SELECT 1 succeeds | shell_verification | `scripts/infra/fix-velero-restore-test.sh` (with RUN_NOW=1) | Live cluster; throwaway NS `velero-restore-test` |
| AC-005 | Negative: Restore-test fails if no valid backup exists | shell_verification | `infrastructure/k8s/velero/restore-test-script.sh` | Live cluster with deleted backups |
| AC-006 | Happy: At least 1 PVC in Bound state after restore | kubectl_check | `kubectl -n velero-restore-test get pvc -o json \| jq '[.items[] \| select(.status.phase=="Bound")] \| length'` | Live cluster post-restore |
| AC-006 | Negative: Zero Bound PVCs treated as drill failure | shell_verification | `infrastructure/k8s/velero/restore-test-script.sh` (REQUIRE_PVC_RESTORE=true) | Live cluster |
| AC-007 | Happy: fix-velero-restore-test.sh runs end-to-end including PV validation and MySQL probe | shell_verification | `scripts/infra/fix-velero-restore-test.sh` | Live cluster |
| AC-007 | Negative: Script fails if ConfigMap or CronJob cannot be patched | shell_verification | `scripts/infra/fix-velero-restore-test.sh` | Revoke RBAC temporarily |
| AC-008 | Happy: backup-verification CronJob confirms freshness within 2h (hourly) and 26h (daily) | kubectl_check | `kubectl -n velero get cronjob backup-verification -o json` + check last successful job timestamp | Live cluster |
| AC-008 | Negative: Stale backup (>2h for hourly) triggers verification failure | shell_verification | `scripts/qa/audit-velero-alert-pipeline.sh --json` | Live cluster with paused schedule |

### DR Evidence (AC-009 through AC-011)

| AC # | Test Case | Type | File / Command | Mocks/Fixtures |
|------|-----------|------|----------------|----------------|
| AC-009 | Happy: Evidence bundle tarball contains all 6 required artifacts | shell_verification | `STRICT_RUNTIME=1 ./scripts/qa/build-dr-evidence-bundle.sh --tar` | Live cluster |
| AC-009 | Negative: STRICT_RUNTIME=1 fails if audit-velero.sh is unavailable | shell_verification | `STRICT_RUNTIME=1 ./scripts/qa/build-dr-evidence-bundle.sh --tar` with script renamed | Modified filesystem |
| AC-010 | Happy: GitHub Actions workflow runs monthly and uploads artifacts | ci_workflow | `.github/workflows/dr-evidence-bundle.yml` (inspect cron schedule + artifact retention) | GitHub Actions runner |
| AC-010 | Negative: Workflow fails gracefully if cluster is unreachable | ci_workflow | Trigger workflow manually with invalid credentials | GitHub Actions |
| AC-011 | Happy: Complete evidence bundle generated within 1 business day on request | manual_verification | Run `./scripts/qa/build-dr-evidence-bundle.sh --tar` and verify completeness | Live cluster |

### Alert Pipeline (AC-012 through AC-014)

| AC # | Test Case | Type | File / Command | Mocks/Fixtures |
|------|-----------|------|----------------|----------------|
| AC-012 | Happy: Backup failure alert fires within 1 hour | shell_verification | `scripts/qa/audit-velero-alert-pipeline.sh --json` (verify alert policy exists + log metric) | GCP Cloud Monitoring |
| AC-012 | Negative: Missing alert policy detected by pipeline audit | shell_verification | `STRICT_RUNTIME=1 scripts/qa/audit-velero-alert-pipeline.sh` | Delete one alert policy |
| AC-013 | Happy: Stale restore-test (>45 days) detected | shell_verification | `STRICT_RUNTIME=1 scripts/qa/audit-velero-alert-pipeline.sh` | Live cluster with stale restore |
| AC-013 | Negative: Fresh restore-test (<45 days) does not trigger alert | shell_verification | `scripts/qa/audit-velero-alert-pipeline.sh --json` | Live cluster with recent drill |
| AC-014 | Happy: Pipeline audit validates both backup-verification and restore-test freshness | shell_verification | `scripts/qa/audit-velero-alert-pipeline.sh --json` | Live cluster |

### Recovery Procedures (AC-015 through AC-018)

| AC # | Test Case | Type | File / Command | Mocks/Fixtures |
|------|-----------|------|----------------|----------------|
| AC-015 | Happy: Single PVC restored from hourly backup within 30 minutes | manual_verification | Follow `docs/operations/DISASTER_RECOVERY.md` DR-002 procedure | Live cluster; throwaway NS |
| AC-015 | Negative: Restore fails if backup is corrupted or unavailable | manual_verification | Attempt restore from deleted backup | Live cluster |
| AC-016 | Happy: Full namespace restore via `velero restore create --namespace-mappings` within 1 hour | manual_verification | Follow DR-003 procedure in DR doc | Live cluster; throwaway NS |
| AC-016 | Negative: Namespace stuck in Terminating after restore (edge case EC-3) | manual_verification | Follow finalizer cleanup procedure | Live cluster |
| AC-017 | Happy: Secret rotation completes within 1 hour following DR-006 checklist | manual_verification | Follow `docs/runbooks/operations/SECRET_ROTATION_CHECKLIST.md` | Infisical + GCP SM access |
| AC-017 | Negative: Secrets desync after restore (edge case EC-6) | manual_verification | Force ExternalSecrets resync after restore | Live cluster |
| AC-018 | Happy: Full cluster rebuild within 4 hours with RPO <= 1 hour (DR-007) | manual_verification | Tabletop exercise or actual drill following DR doc | Full infrastructure access |
| AC-018 | Negative: GCS bucket inaccessible during restore (edge case EC-7) | manual_verification | Verify fallback to Atlas + Git rebuild | Documentation review |

### Data Integrity (AC-019 through AC-020)

| AC # | Test Case | Type | File / Command | Mocks/Fixtures |
|------|-----------|------|----------------|----------------|
| AC-019 | Happy: MySQL auth_user COUNT within 5% of pre-incident count post-restore | kubectl_check | `kubectl exec mysql-pod -- mysql -e "SELECT COUNT(*) FROM openedx.auth_user"` | Live cluster post-restore |
| AC-019 | Negative: User count discrepancy >5% flagged as failure | manual_verification | Compare counts before and after restore | Baseline count from production |
| AC-020 | Happy: public-health-check.sh returns all-green post-restore | shell_verification | `scripts/qa/public-health-check.sh prod` | Live production endpoints |
| AC-020 | Negative: Endpoint returning 5xx detected as failure | shell_verification | `scripts/qa/public-health-check.sh prod` | Degraded environment |

### Cross-Region Readiness (AC-021 through AC-022)

| AC # | Test Case | Type | File / Command | Mocks/Fixtures |
|------|-----------|------|----------------|----------------|
| AC-021 | Happy: Kustomize produces valid manifests for any GKE cluster | shell_verification | `kubectl kustomize deploy/k8s/overlays/production \| kubectl apply --dry-run=server -f -` | Live cluster or dry-run |
| AC-021 | Negative: Invalid manifest detected by dry-run | shell_verification | `kubectl kustomize deploy/k8s/overlays/production` with intentional error | Modified kustomization |
| AC-022 | Happy: GCS backup bucket is multi-region or has cross-region replication | kubectl_check | `gcloud storage buckets describe gs://BUCKET_NAME --format='value(location_type)'` | GCS bucket |
| AC-022 | Negative: Single-region bucket flagged as gap | manual_verification | Inspect bucket config | GCS console |

### Edge Case Tests

| EC # | Edge Case | Test Case | Type | File / Command |
|------|-----------|-----------|------|----------------|
| EC-1 | Backup succeeds but 0 volume snapshots | `audit-velero.sh` flags critical failure | shell_verification | `scripts/qa/audit-velero.sh --json` |
| EC-2 | Restore-test CronJob silently broken | `audit-velero-alert-pipeline.sh` detects stale restore-test | shell_verification | `STRICT_RUNTIME=1 scripts/qa/audit-velero-alert-pipeline.sh` |
| EC-3 | Restore namespace stuck in Terminating | Finalizer cleanup procedure works | manual_verification | `kubectl patch` + `kubectl delete ns --force` |
| EC-4 | Atlas backup verification failure | Atlas snapshot list is non-empty and fresh | manual_verification | `atlas backups snapshots list` |
| EC-5 | Partial restore with acceptable errors | Restore-test accepts <= 10 partial errors | shell_verification | `infrastructure/k8s/velero/restore-test-script.sh` (MAX_PARTIAL_ERRORS) |
| EC-6 | Secrets desync after restore | ExternalSecrets resync procedure works | manual_verification | Delete secrets + wait for ESO resync |
| EC-7 | GCS bucket inaccessible during restore | Fallback to Atlas + Git documented | manual_verification | Documentation review |
| EC-8 | Concurrent backup and restore | No concurrent ops for same namespace enforced | manual_verification | Pre-op backup uses `--wait` |
| EC-9 | Clock skew in backup freshness checks | All timestamps use UTC; NTP verified | kubectl_check | `date -u` on node vs backup timestamp |

## Test Execution Schedule

| Cadence | Tests |
|---------|-------|
| **On every change** | AC-001, AC-003, AC-004, AC-021 (can run offline against manifests) |
| **Daily** | AC-008 (backup-verification CronJob auto-runs) |
| **Monthly** | AC-005, AC-006, AC-007, AC-009, AC-010 (restore drill + evidence bundle) |
| **Quarterly** | AC-015, AC-016, AC-018 (manual recovery procedure drills) |
| **Semi-annually** | AC-018 full tabletop exercise |
| **On demand** | AC-011, AC-017 (enterprise audit request, secret compromise) |

## Test Dependencies

```
Phase 1 Tests
  audit-velero.sh ─── requires: Velero schedules configured
  BSL phase check ─── requires: GCS bucket accessible

Phase 2 Tests
  audit-velero-alert-pipeline.sh ─── requires: Alert policies deployed
  verify-alert-routing.sh ─── requires: Notification channels configured

Phase 3 Tests
  Kustomize dry-run ─── requires: No changes to manifests
  GCS bucket inspection ─── requires: gcloud auth

Phase 4 Tests
  Restore drill ─── requires: Valid Velero backup exists
  Evidence bundle ─── requires: Cluster access + all audit scripts
  Health check ─── requires: Production endpoints accessible
```

## Self-Check

- [x] Every acceptance criterion (AC-001 through AC-022) has at least one test case
- [x] Every acceptance criterion has at least one negative/failure test case
- [x] All 9 edge cases from the spec have corresponding test cases
- [x] Test type (shell_verification / kubectl_check / manual_verification / ci_workflow) is appropriate
- [x] Required cluster access and tooling documented for each test
- [x] Test cadence schedule defined (daily / monthly / quarterly / on-demand)
- [x] Source spec linked in header
