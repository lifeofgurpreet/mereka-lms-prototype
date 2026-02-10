---
source_spec: specs/data-privacy-gdpr-compliance_spec.md
status: ready
created: 2026-02-10
updated: 2026-02-10
---

# Data Privacy & GDPR Compliance - Test Plan

**Source Spec**: `specs/data-privacy-gdpr-compliance_spec.md`

**Test Framework**: pytest (Python)

**Test Coverage Target**: 100% of 30 acceptance criteria + all edge cases

---

## Test Categories

- **Unit**: Single function/class, mocked dependencies
- **Integration**: Multiple components, real database (test DB), mocked external APIs
- **E2E**: Full flow including external service stubs
- **Load**: Performance testing (deletion pipeline with 1M records, PII scan with 7 days of logs)
- **Security**: OWASP Top 10, PII leakage prevention, audit trail tampering attempts

---

## Test Plan Table

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| 1 | Given PII registry with all fields matching schema, when validation tool runs, then exit code 0 and zero drift warnings | integration | `tests/integration/test_pii_registry_validation.py` | Real test database schema |
| 1 | Given schema has new PII field not in registry, when validation tool runs, then exit code 1 and field flagged as unregistered | unit | `tests/unit/test_pii_registry_validation.py` | Mock schema with extra field |
| 2 | Given database migration adds PII field, when CI pipeline runs, then validation tool blocks merge if registry not updated | integration | `tests/integration/test_ci_pii_validation.py` | Mock CI environment |
| 3 | Given new user registration, when user completes form,then consent records created for all mandatory purposes withgranted=true | integration | `tests/integration/test_consent_registration.py` | Mock user registration form |
| 4 | Given authenticated user visits /account/privacy/, whenpage loads, then all consent purposes displayed with currentstatus and toggle controls | e2e | `tests/e2e/test_preference_center.py` | Real preference center UI |
| 5 | Given user withdraws consent for analytics, when withdrawal saved, then analytics event collection stops within 24 hours and consent_withdrawn audit entry created | integration| `tests/integration/test_consent_withdrawal_enforcement.py`| Mock analytics pipeline |
| 6 | Given user in EU visits LMS, when page loads, then cookie consent banner displayed and no non-essential cookies setuntil consent granted | e2e | `tests/e2e/test_cookie_banner.py` | Mock geo-detection (EU) |
| 7 | Given user grants cookie consent for analytics, when they revoke it, then analytics cookies cleared and tracking pixel deactivated on next page load | integration | `tests/integration/test_cookie_revocation.py` | Mock cookie service |
| 8 | Given authenticated user submits deletion request via POST /api/v1/privacy/deletion-request/, when request verified,then deletion pipeline begins within 48 hours | integration| `tests/integration/test_deletion_request_api.py` | Mock email verification |
| 9 | Given deletion pipeline runs for user X, when all stores processed successfully, then auth_user.email replaced withretired_email_{hash}@retired.invalid, username replaced withretired_user_{hash}, userprofile deleted, forum posts show [deleted], profile image deleted, Redis sessions invalidated, ClickHouse events deleted, Purchase Gateway buyer_email anonymized | e2e | `tests/e2e/test_deletion_pipeline_full.py` | Real test databases for all stores |
| 10 | Given deletion pipeline completes, when proof generated, then proof document contains deletion_request_id, each data store, action taken, timestamp, valid cryptographic signature | unit | `tests/unit/test_deletion_proof.py` | Mock signing key from Infisical |
| 11 | Given deletion request for user with financial recordswithin 7-year retention, when pipeline processes Purchase Gateway, then financial amounts retained (PII anonymized) and deletion proof notes legal retention basis | integration | `tests/integration/test_deletion_legal_retention.py` | Fixture:user with recent order |
| 12 | Given deletion pipeline fails for MongoDB Atlas (network error), when failure detected, then request transitions topartially_completed, remaining stores processed, and alert fired to privacy ops | integration | `tests/integration/test_deletion_partial_failure.py` | Mock MongoDB (connection error)|
| 13 | Given authenticated user submits export request via POST /api/v1/privacy/export-request/, when export generated, then ZIP archive produced containing profile.json, enrollments.json, grades.json, certificates.json, forum_posts.json, notes.json, purchases.json, consents.json, audit_log.json, README.md | e2e | `tests/e2e/test_export_pipeline_full.py` | Real test databases |
| 14 | Given export archive generated, when user accesses download link, then archive encrypted and download link expiresafter 48 hours | integration | `tests/integration/test_export_download_link.py` | Mock time for expiry check |
| 15 | Given user submitted 3 export requests in current 30-day period, when they submit 4th request, then request rejected with HTTP 429 and rate limit message | unit | `tests/unit/test_export_rate_limit.py` | Fixture: 3 existing requests |
| 16 | Given user account with no login for 18 months, when retention enforcement job runs, then reminder email sent warning of deletion at 24 months | integration | `tests/integration/test_retention_reminder.py` | Mock time (18 months) |
| 17 | Given user account with no login for 24 months and noresponse to reminder, when retention enforcement job runs, then account enters deletion pipeline | integration | `tests/integration/test_retention_deletion.py` | Mock time (24 months)|
| 18 | Given ClickHouse analytics events older than 365 days,when retention enforcement job runs, then partitions dropped| integration | `tests/integration/test_clickhouse_retention.py` | Mock ClickHouse with old partitions |
| 19 | Given Loki log entries older than 30 days, when Loki retention policy executes, then entries no longer queryable |integration | `tests/integration/test_loki_retention.py` | Mock Loki retention |
| 20 | Given any consent change, deletion request, export request, or breach event, when event occurs, then audit trail entry created within 1 second with valid integrity hash linkingto previous entry | integration | `tests/integration/test_audit_trail_creation.py` | Real audit trail database |
| 21 | Given auditor runs integrity verification tool, when no tampering occurred, then hash chain validates completely with zero broken links | unit | `tests/unit/test_audit_trail_integrity.py` | Fixture: audit trail with 100 entries |
| 22 | Given audit trail replicated to GCS, when entry tampered in database, then GCS copy provides evidence of original entry | integration | `tests/integration/test_audit_trail_gcs_replication.py` | Mock GCS |
| 23 | Given PII leakage scanner detects raw email in Loki logs, when scan completes, then breach_detected audit entry created and Warning alert fired | integration | `tests/integration/test_pii_leakage_detection_loki.py` | Mock Loki with raw email in logs |
| 24 | Given confirmed data breach affecting >100 users, whenincident commander classifies as high severity, then breachnotification template auto-populated and supervisory authority contact list retrieved | integration | `tests/integration/test_breach_notification_workflow.py` | Mock breach classification |
| 25 | Given Loki log query for raw email patterns, when PIIleakage scanner runs, then log lines matching pattern flaggedin scan results | unit | `tests/unit/test_pii_scanner_loki_regex.py` | Mock Loki log lines |
| 26 | Given ClickHouse xapi_events_all contains unhashed email in actor_mbox, when PII scanner runs, then field flagged as critical PII leakage | integration | `tests/integration/test_pii_scanner_clickhouse.py` | Mock ClickHouse with unhashedemail |
| 27 | Given privacy_admin user calls GET /api/v1/privacy/compliance/consent-coverage/, when response received, then percentage of active users with consent records for each purpose returned | integration | `tests/integration/test_compliance_api_consent_coverage.py` | Mock consent data |
| 28 | Given pending deletion requests, when compliance dashboard viewed, then each request shows status, elapsed time, SLA compliance (green if <30 days, red if overdue) | e2e | `tests/e2e/test_compliance_dashboard.py` | Real Grafana dashboard|
| 29 | Given analytics pipeline processes event, when user withdrawn analytics consent, then event dropped before reachingClickHouse | integration | `tests/integration/test_consent_enforcement_analytics.py` | Mock ClickHouse |
| 30 | Given tenant offboarding initiated per multi-tenancy spec, when offboarding completes, then all tenant user data processed through deletion or export pipeline per DPA terms | integration | `tests/integration/test_tenant_offboarding_deletion.py` | Mock tenant offboarding workflow |

---

## Edge Case Tests (Negative Tests)

| Edge Case | Test Case | Type | File | Mocks/Fixtures |
|-----------|-----------|------|------|----------------|
| User with active course enrollment requests deletion | Given deletion request while enrolled in active course, when pipeline runs, then enrollment deactivated and deletion proceeds(GDPR right overrides contract) | integration | `tests/integration/test_deletion_active_enrollment.py` | Fixture: enrolleduser |
| User with in-flight purchase requests deletion | Given deletion request while order in pending state, when pipeline runs, then wait for order terminal state before processing Purchase Gateway step | integration | `tests/integration/test_deletion_inflight_purchase.py` | Fixture: pending order |
| Deletion of user who is course author | Given user createdStudio content, when deletion runs, then course content retained (serves other learners), author attribution anonymized only | integration | `tests/integration/test_deletion_course_author.py` | Fixture: course with authored content |
| Re-registration after deletion | Given user data deleted and they register again with same email, when registration completes, then treated as new user, no re-linking to old anonymous records | integration | `tests/integration/test_reregistration_after_deletion.py` | Fixture: deleted user hash |
| Concurrent deletion and export requests | Given user submits deletion and export simultaneously, when both queued, thenexport completes before deletion begins | integration | `tests/integration/test_concurrent_deletion_export.py` | Mock jobqueue |
| Deletion request for enterprise admin | Given user is enterprise admin with active responsibilities, when deletion requested, then enterprise notified before proceeding, deletion not delayed >7 days | integration | `tests/integration/test_deletion_enterprise_admin.py` | Fixture: enterprise admin user |
| User registered before consent system deployed | Given existing user who registered before consent framework, when theylogin, then consent collection prompt displayed | integration| `tests/integration/test_consent_backfill.py` | Fixture: pre-consent user |
| Enterprise user with conflicting consent and DPA | Given enterprise DPA grants admin access but learner withdraws third_party_sharing consent, when conflict occurs, then DPA contract basis takes precedence and override logged | integration |`tests/integration/test_consent_dpa_conflict.py` | Fixture: enterprise user with DPA |
| Consent version migration | Given privacy policy updated, when existing consent records checked, then old version remains valid, user prompted to re-consent on next login | integration | `tests/integration/test_consent_version_migration.py` |Mock consent version change |
| Minor data subjects (under 16 EU) | Given enterprise tenantenrolls users under 16, when tenant config enables parentalconsent, then parental email required for consent | integration | `tests/integration/test_parental_consent.py` | Fixture:minor user |
| EU user data in Singapore infrastructure | Given EU data subject, when data stored in asia-southeast1, then Standard Contractual Clauses documented in processor inventory | unit | `tests/unit/test_cross_border_transfer_documentation.py` | Fixture: processor inventory |
| Stripe data residency | Given Stripe processes payment, when DPA reviewed, then Stripe data residency region documentedin DPIA | unit | `tests/unit/test_stripe_data_residency.py` |Fixture: DPIA template |
| Inactive account with outstanding financial obligation | Given account flagged for 24-month inactivity but has financialrecords within 7-year retention, when retention job runs, then account anonymized (not fully deleted), financial data retained | integration | `tests/integration/test_retention_financial_obligation.py` | Fixture: inactive + financial |
| Inactive account with active enterprise subscription | Given enterprise admin account flagged for inactivity but enterprise subscription active, when retention job runs, then no auto-delete | integration | `tests/integration/test_retention_active_enterprise.py` | Fixture: inactive enterprise admin |
| Backup retention and deletion right | Given user deletion completed, when backup restoration occurs within 90 days, thensystem re-runs pending deletions from deletion request log |integration | `tests/integration/test_deletion_backup_retention.py` | Mock backup restoration |
| Hash chain break after system recovery | Given audit traildatabase restored from backup and latest hash doesn't match,when system detects break, then chain break entry created andchain restarted | integration | `tests/integration/test_audit_chain_break_recovery.py` | Mock database restoration |
| High-volume audit events during bulk deletion | Given tenant offboarding triggers 1000 user deletions, when audit trailprocesses events, then no events lost (buffered writes with write-ahead log) | load | `tests/load/test_audit_trail_bulk_volume.py` | Mock bulk deletion |
| Deletion pipeline per-store timeout | Given data store doesnot respond within 30 minutes, when timeout occurs, then step marked failed and pipeline continues to next store | integration | `tests/integration/test_deletion_store_timeout.py` |Mock slow store |
| Export pipeline timeout | Given export generation exceeds 7hours, when timeout occurs, then export request marked failed and user notified with retry option | integration | `tests/integration/test_export_timeout.py` | Mock slow collector |
| Consent cache staleness | Given consent withdrawn but cachenot expired, when consent check occurs, then maximum staleness 24 hours (cache TTL), critical changes invalidate immediately | unit | `tests/unit/test_consent_cache_staleness.py` | Mock Redis cache |
| Deletion pipeline re-run idempotency | Given deletion pipeline re-run for already deleted user, when re-run executes, then completed stores are no-op, only failed stores retried | unit | `tests/unit/test_deletion_idempotency.py` | Fixture: partially completed deletion |
| Consent record duplication | Given consent granted for samepurpose multiple times, when grant API called, then no duplicate active records created | unit | `tests/unit/test_consent_duplication_prevention.py` | None |
| Export request duplication | Given export request submittedwhile previous still processing, when duplicate submitted, then existing request ID returned (no duplicate) | unit | `tests/unit/test_export_duplication_prevention.py` | Fixture: processing export |
| Deletion request rate limit | Given 11 deletion requests from same IP in 1 hour, when 11th arrives, then HTTP 429 returned (prevents abuse) | load | `tests/load/test_deletion_rate_limit.py` | Mock rate limiter |
| Compliance API rate limit | Given 61 compliance API requests in 1 minute, when 61st arrives, then HTTP 429 returned | load | `tests/load/test_compliance_api_rate_limit.py` | Mock rate limiter |
| Consent update rate limit | Given 31 consent changes in 1 hour, when 31st submitted, then HTTP 429 returned (prevents automated toggling) | load | `tests/load/test_consent_rate_limit.py` | Mock rate limiter |
| Deletion with >3 store failures | Given deletion pipeline with 4 stores failing, when failures detected, then pipeline pauses, Critical alert fired, manual intervention required | integration | `tests/integration/test_deletion_systemic_failure.py` | Mock multiple store failures |
| Consent service unavailable | Given consent management service unreachable, when processing requested, then fail-open for essential_service (contract), fail-closed for consent-based(analytics/marketing) | integration | `tests/integration/test_consent_service_failover.py` | Mock consent service down |

---

## Load Tests

| Test Case | Type | File | Target |
|-----------|------|------|--------|
| Deletion pipeline with 1M user records across all stores |load | `tests/load/test_deletion_scale.py` | Completes withinhours, no degradation |
| PII scan with 7 days of Loki logs (10GB) | load | `tests/load/test_pii_scan_scale_loki.py` | Completes within 4 hours |
| Consent check API with 1000 req/sec | load | `tests/load/test_consent_check_latency.py` | p95 latency <=10ms |
| Audit trail write under burst load (100 events/sec) | load| `tests/load/test_audit_trail_write_burst.py` | All events written, no dropped events |
| Export pipeline for user with 100,000 learning events | load | `tests/load/test_export_large_user.py` | Completes withinhours |

---

## Security Tests

| Test Case | Type | File | Target |
|-----------|------|------|--------|
| OWASP Top 10 audit for privacy service | security | `tests/security/test_privacy_service_owasp.py` | Zero Critical/Highfindings |
| JWT authentication bypass attempts (expired, malformed, wrong signature) | security | `tests/security/test_jwt_bypass_privacy.py` | All attempts rejected (HTTP 401) |
| Tenant isolation bypass (deletion request for user in different tenant) | security | `tests/security/test_tenant_isolation_privacy.py` | Cross-tenant deletion blocked |
| Audit trail tampering attempts (UPDATE/DELETE audit log entries) | security | `tests/security/test_audit_trail_tampering.py` | Append-only constraint enforced |
| PII exposure in Prometheus metrics labels | security | `tests/security/test_metrics_pii.py` | Zero raw PII in metric labels |
| Secrets exposure in privacy service error messages | security | `tests/security/test_secrets_in_errors_privacy.py` | Nosecrets in HTTP responses or logs |
| Deletion proof signature forgery attempts | security | `tests/security/test_deletion_proof_forgery.py` | Invalid signatures rejected |
| Export archive encryption strength | security | `tests/security/test_export_encryption.py` | AES-256 encryption verified|

---

## Test Fixtures

### Common Fixtures (`tests/conftest.py`)

- `db_session`: Test database session (PostgreSQL for privacyservice)
- `mysql_session`: Test MySQL session (Open edX tables)
- `mongodb_client`: Test MongoDB Atlas client
- `clickhouse_client`: Test ClickHouse client
- `redis_client`: Test Redis instance
- `mock_lms_api`: Mock LMS API client
- `mock_email_service`: Mock email sending service
- `mock_alert_service`: Mock alert notification service
- `privacy_admin_jwt`: JWT for privacy_admin role
- `compliance_officer_jwt`: JWT for compliance_officer role
- `test_tenant_a`: Fixture for tenant A data
- `test_user_with_data`: Fixture for user with enrollments, grades, forum posts, purchases
- `test_user_minimal`: Fixture for user with minimal data (just account)
- `test_user_inactive_18mo`: Fixture for user with last loginmonths ago
- `test_user_inactive_24mo`: Fixture for user with last loginmonths ago
- `test_deletion_request_pending`: Fixture for pending deletion request
- `test_deletion_request_completed`: Fixture for completed deletion request
- `test_export_request_pending`: Fixture for pending export request
- `test_consent_records`: Fixture for consent records (granted/withdrawn)
- `test_audit_trail_100_entries`: Fixture for audit trail with 100 valid entries
- `pii_registry`: Fixture for PII registry YAML

---

## Test Coverage Verification

After implementing all tests, verify coverage:

```bash
pytest --cov=services/privacy-service/src --cov-report=html --cov-report=term tests/
```

**Target**: >=90% coverage for all critical paths (deletion,export, consent, audit trail, PII scanning)

**Exclusions**: External service clients (LMS, MongoDB, ClickHouse) are mocked, internal logic not covered

---

## CI/CD Integration

Add to CI pipeline:

```yaml
test:
  stage: test
  script:
    - pytest tests/unit/ tests/integration/ --cov=services/privacy-service/src --cov-report=xml
    - pytest tests/security/ --strict
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml
```

**Security tests MUST pass** (no bypass vulnerabilities allowed)

**Load tests run nightly** (not on every commit)

**E2E tests run pre-deployment** (staging environment)

---

## Manual Test Cases (Not Automated)

Some tests require manual verification:

1. **GDPR Data Subject Request E2E**: Submit real deletion request in staging, verify all stores processed, receive deletion proof email
2. **Consent Banner Geo-Detection**: Test from EU IP and non-EU IP, verify different banner behavior
3. **Grafana Dashboard Verification**: After metrics test, verify compliance dashboard displays correct data
4. **Alert Firing Verification**: Trigger PII leakage alert (inject raw email into logs), verify Slack/email alert received
5. **DPA Verification with Processors**: Verify signed DPAs with Google Cloud, MongoDB, Stripe, Cloudflare
6. **SOC 2 Audit Trail Evidence**: Pull evidence package fromcompliance API, verify auditor can validate

These manual tests are documented in the runbook (`docs/runbooks/data-privacy-compliance-runbook.md`)

---

## Test Data Management

**Test Database**: Separate PostgreSQL instance for privacy service tests, reset between runs

**Test MySQL**: Separate MySQL instance for Open edX tables,reset between runs

**Test MongoDB**: Separate MongoDB instance for forum data, reset between runs

**Test ClickHouse**: Separate ClickHouse instance for analytics, reset between runs

**Test Redis**: Separate Redis instance, flushed between runs

**Test GCS**: Mock GCS for profile images and certificates

**Cleanup**: All test data ephemeral, deleted after test run

---

## Summary

**Total Test Cases**: 87

**By Type**:
- Unit: 23 tests
- Integration: 48 tests
- E2E: 7 tests
- Load: 5 tests
- Security: 8 tests

**By AC Coverage**:
- All 30 acceptance criteria have at least one test
- All edge cases have negative tests
- All security requirements have security tests

**Test Execution Time**: <15 minutes (unit + integration), ~4minutes (all tests including E2E)

**Test Stability**: All tests MUST be deterministic (no flakytests allowed)

**Test Maintenance**: Testmap YAML tracks AC → test mapping for automated coverage verification└ specs/plans/disaster-recovery-business-continuity_plan.md (+0
# Disaster Recovery & Business Continuity - Implementation Plan

**Source Spec**: `specs/disaster-recovery-business-continuity_spec.md`

**Generated**: 2026-02-10

**Total Acceptance Criteria**: 22

**Spec Status**: draft → approved (after review) → implemented

---

## Summary

This plan converts the DR/BC spec into actionable implementation tasks grouped by category. The spec formalizes existing infrastructure (Velero schedules, Atlas backups, restore drills, DR evidence automation) and adds missing pieces (cross-region readiness, DR dashboard, compliance reporting, secret rotation checklist). Most tasks are verification/documentation work; few require new code.

**Key Dependencies**:
- Phase 1 (Baseline) must complete before Phase 2 (Monitoring)
- Phase 3 (Cross-Region) can run parallel to Phase 2
- Phase 4 (Compliance) depends on Phases 1-3

---

## Build Tasks

### Phase 1 - Baseline Hardening (Week 1-2)

- [ ] **[S]** Verify Velero schedules match spec requirements(`infrastructure/k8s/velero/schedules/`) | AC: #1, #2 | Depends: None
  - Verify hourly-critical, daily-all-apps, weekly-full schedules exist and are active
  - Verify `includeClusterResources: true` and `volumeSnapshotLocations: ["default"]`
  - Verify retention policies match spec (48h, 30d, 90d)
  - Verify no critical services use `emptyDir` for persistentdata
  - Command: `./scripts/qa/audit-velero.sh --json | jq .`
  - Done: audit-velero.sh returns zero failures for all schedule checks

- [ ] **[M]** Enable and verify MongoDB Atlas continuous backup + PITR (`docs/operations/MONGODB_ATLAS_BACKUP.md`) | AC: #| Depends: None
  - Check current Atlas cluster tier (M0/M10/M20) — M0 does not support continuous backup
  - Enable continuous backup in Atlas UI or via Terraform
  - Enable point-in-time recovery with 7-day minimum window
  - Verify snapshot policy is active: `atlas backups snapshots list cluster-mereka-lms`
  - Document Atlas backup verification procedure
  - Done: Atlas snapshot list is non-empty and PITR is enabled (screenshot or CLI output)

- [ ] **[S]** Verify GCS backup bucket encryption and IAM restrictions (`infrastructure/gcs/backup-bucket.tf`) | Req: Security NFR | Depends: None
  - Verify bucket is encrypted at rest with Google-managed keys (minimum)
  - Verify IAM access is restricted to Velero service accountonly
  - Document bucket name, region, and storage class in BACKUP_COVERAGE_MATRIX.md
  - Command: `gsutil iam get gs://BUCKET_NAME`
  - Done: IAM policy shows only Velero SA with write permissions, encryption enabled

- [ ] **[M]** Update BACKUP_COVERAGE_MATRIX.md to match specrequirements (`docs/operations/BACKUP_COVERAGE_MATRIX.md`) |AC: #4 | Depends: Build tasks above
  - Add Tier 1-6 data classification from spec
  - Map every stateful component to backup mechanism
  - Add verification command for each component
  - Add Atlas backup row with verification procedure
  - Add Artifact Registry row
  - Done: Matrix includes all components from spec with verification commands

- [ ] **[S]** Create SECRET_ROTATION_CHECKLIST.md runbook (`docs/operations/SECRET_ROTATION_CHECKLIST.md`) | AC: #17 | Depends: None
  - List all secrets that must be rotated after compromise (Infisical, GCP SM, K8s)
  - Add step-by-step rotation procedure for each secret type
  - Add verification steps (ExternalSecrets sync, pod restarts)
  - Add estimated time for full rotation (target: 1 hour)
  - Template: Use `docs/operations/DEPLOYMENT_RUNBOOK.md` asreference
  - Done: Checklist covers all secret types with commands andverification

### Phase 2 - Monitoring and Alerting (Week 3-4)

- [ ] **[M]** Deploy Velero metrics exporter if not present (`deploy/k8s/base/monitoring/velero-exporter.yaml`) | Observability Req | Depends: Phase 1 complete
  - Check if Velero already exports Prometheus metrics (port8085)
  - If not, deploy velero-prometheus-exporter sidecar
  - Verify metrics are scraped: `curl http://velero:8085/metrics | grep velero_backup_`
  - Document metrics endpoint in MONITORING.md
  - Done: Velero metrics visible in Prometheus targets

- [ ] **[L]** Create/update PrometheusRule for all DR alerts(`deploy/k8s/base/monitoring/prometheusrule-dr.yaml`) | AC: #12, #13, #14 | Depends: Metrics exporter deployed
  - `VeleroBackupFailed`: backup fails → alert within 1h
  - `VeleroBackupStale`: hourly backup >2h stale
  - `VeleroRestoreTestStale`: restore-test not succeeded in >45d (manual check via script)
  - `VeleroSnapshotMismatch`: volumeSnapshotsCompleted < bound PVC count
  - `BackupVerificationFailed`: daily verification job fails
  - `DREvidenceBundleStale`: evidence bundle >35d old (custommetric)
  - `EmptyDirCriticalData`: critical data on emptyDir detected (audit script)
  - `AtlasBackupStale`: Atlas snapshot >48h stale (manual check via script)
  - Template: Use `deploy/k8s/base/monitoring/prometheusrule-lms.yaml` as reference
  - Done: All 8 alerts defined, applied to cluster, visible in Alertmanager

- [ ] **[M]** Create DR Health dashboard in Grafana (`infrastructure/monitoring/dashboards/dr-health.json`) | Observability Req | Depends: Alerts deployed
  - Panel: Backup freshness per schedule (time since last successful backup)
  - Panel: Restore drill history (last 12 months) — custom metric from Job completion
  - Panel: Volume snapshot count vs. bound PVC count
  - Panel: Evidence bundle freshness (custom metric)
  - Panel: Alert pipeline health status
  - Export JSON to `infrastructure/monitoring/dashboards/dr-health.json`
  - Done: Dashboard deployed, all panels rendering data

- [ ] **[M]** Update Operations Signals dashboard with Veleropanel (`infrastructure/monitoring/dashboards/operations-signals.json`) | Observability Req | Depends: Metrics exporter deployed
  - Add Velero backup success rate panel (30-day rolling window)
  - Add backup age panel (time since last hourly/daily/weeklybackup)
  - Deploy updated dashboard
  - Done: Operations Signals dashboard includes Velero panels

- [ ] **[S]** Verify alert routing to on-call (`scripts/qa/verify-alert-routing.sh`) | AC: #12 | Depends: Alerts deployed
  - Test Alertmanager routes reach Slack/Email/Phone per severity (P1/P2/P3/P4)
  - Update verify-alert-routing.sh to include DR alerts
  - Document escalation tiers in ALERT_SEVERITY_MATRIX.md
  - Done: All DR alerts route correctly, test alerts delivered

### Phase 3 - Cross-Region Readiness (Week 5-8)

- [ ] **[M]** Configure GCS backup bucket for multi-region replication (`infrastructure/gcs/backup-bucket.tf`) | AC: #22 |Depends: Phase 1 complete
  - Check current bucket storage class (single-region or multi-region)
  - If single-region, migrate to multi-region or configure cross-region replication
  - Document replication configuration in DISASTER_RECOVERY.md
  - Verify replicated bucket is accessible from secondary region
  - Done: GCS bucket is multi-region or cross-region replication is active

- [ ] **[M]** Enable Artifact Registry multi-region replication (`infrastructure/terraform/artifact-registry.tf`) | AC: #2| Depends: None
  - Enable multi-region replication for `asia-southeast1-docker.pkg.dev/mereka-lms/openedx`
  - Document registry regions in DISASTER_RECOVERY.md
  - Verify images are replicated to secondary region
  - Done: Artifact Registry shows replicated repositories insecondary region

- [ ] **[L]** Document cross-region cluster provisioning procedure (`docs/operations/CROSS_REGION_FAILOVER.md`) | AC: #21| Depends: None
  - Terraform/Kustomize commands to deploy secondary GKE cluster
  - GCP region selection (e.g., asia-southeast2 for Singaporebackup)
  - MongoDB Atlas networking/peering verification for multi-region
  - Velero restore-to-new-cluster procedure
  - Git-based config restoration procedure
  - Estimated time to provision secondary cluster (part of 8hRTO)
  - Done: Runbook tested in tabletop exercise, all commands validated

- [ ] **[M]** Document DNS failover procedure via Cloudflare(`docs/operations/DNS_FAILOVER_PROCEDURE.md`) | Req: Cross-Region Failover | Depends: None
  - Cloudflare DNS A/CNAME record updates for LMS/Studio/MFE
  - LoadBalancer IP change procedure
  - DNS propagation time estimate (part of RTO)
  - Rollback procedure (revert DNS to primary region)
  - Done: Runbook includes copy-paste commands with placeholders

- [ ] **[S]** Conduct tabletop DR exercise for cross-region failover (`docs/operations/DR_TEST_RESULTS.md`) | Req: Cross-Region Readiness | Depends: Runbooks complete
  - Walkthrough cross-region failover procedure (DR-007, DR-008)
  - Identify gaps in runbooks
  - Update runbooks based on findings
  - Document exercise results in DR_TEST_RESULTS.md
  - Done: Tabletop complete, all gaps resolved, runbooks updated

### Phase 4 - Compliance and Evidence (Week 9-10)

- [ ] **[M]** Verify DR evidence bundle workflow produces complete output (`scripts/qa/build-dr-evidence-bundle.sh`, `.github/workflows/dr-evidence-bundle.yml`) | AC: #9, #10 | Depends: Phases 1-2 complete
  - Run: `STRICT_RUNTIME=1 ./scripts/qa/build-dr-evidence-bundle.sh --tar`
  - Verify tarball includes: audit-velero.json, audit-velero-alert-pipeline.json, audit-observability-runtime.json, restore-test logs, PVC summary
  - Verify GitHub Actions workflow runs monthly (1st at 02:30UTC) with 120-day retention
  - Done: Evidence bundle contains all required artifacts, workflow runs successfully

- [ ] **[S]** Configure 12-month evidence retention (`infrastructure/gcs/dr-evidence-bucket.tf`) | Req: Compliance | Depends: Evidence workflow verified
  - Create GCS bucket for DR evidence archives (separate frombackup bucket)
  - Configure lifecycle policy for 12-month retention (365 days)
  - Update GitHub Actions workflow to upload to GCS bucket
  - Done: Evidence archives uploaded to GCS with 12-month retention policy

- [ ] **[M]** Create DR compliance report template for enterprise clients (`docs/operations/DR_COMPLIANCE_REPORT_TEMPLATE.md`) | AC: #11 | Depends: Evidence workflow verified
  - Template sections: Executive Summary, RPO/RTO Commitments, Backup Strategy, Restore Drill Results, Incident History, Evidence Availability
  - Placeholders for latest evidence bundle artifacts
  - Procedure to generate report from evidence bundle withinbusiness day
  - Done: Template tested with sample evidence bundle, reportgenerated in <1 day

- [ ] **[S]** Document primary/secondary DR coordinators (`docs/operations/DR_COORDINATOR_CONTACTS.md`) | Req: Business Continuity | Depends: None
  - List primary and secondary DR coordinator names
  - Contact information (phone, email, Slack)
  - Escalation procedure for P1/P2 incidents
  - On-call rotation schedule (if applicable)
  - Done: Document approved by leadership, contacts verified

- [ ] **[S]** Verify Upptime status page reflects DR events (`infrastructure/upptime/.upptimerc.yml`) | Req: Business Continuity | Depends: None
  - Add LMS, Studio, Discovery, Ecommerce endpoints to Upptime config
  - Verify status page at `https://status.mereka.dev` reflects real-time status
  - Document manual status update procedure for planned DR events
  - Done: Status page shows all endpoints, manual update procedure documented

### Phase 5 - Rollout Validation

- [ ] **[M]** Run comprehensive DR evidence bundle and verifyall gates pass (`scripts/qa/run-operations-gates.sh`) | AC:#1-22 | Depends: Phases 1-4 complete
  - Run: `STRICT_RUNTIME=1 ./scripts/qa/build-dr-evidence-bundle.sh --tar`
  - Run: `./scripts/qa/audit-velero.sh --json | jq '.checks.failures'` → must be 0
  - Run: `./scripts/qa/audit-velero-alert-pipeline.sh --json`→ must pass
  - Run: `./scripts/qa/audit-observability.sh --mode runtime--json` → must pass
  - Verify all 22 acceptance criteria are met
  - Done: All audits pass, evidence bundle complete, spec status → implemented

---

## Test Tasks

### Unit Tests

- [ ] **[S]** Test backup schedule validation logic (`tests/qa/test_audit_velero.py`) | AC: #1, #2 | Depends: None
  - Test parsing of Velero schedule JSON
  - Test detection of missing volumeSnapshotLocations
  - Test detection of emptyDir volumes in critical services
  - Test snapshot count vs. bound PVC count mismatch detection
  - Framework: pytest
  - Done: All test cases pass

### Integration Tests

- [ ] **[M]** Test restore drill end-to-end in throwaway namespace (`tests/qa/test_restore_drill.sh`) | AC: #5, #6, #7 | Depends: Build Phase 1 complete
  - Create test namespace
  - Run restore from latest hourly backup
  - Verify PVCs are restored and Bound
  - Verify MySQL pod starts and SELECT 1 probe succeeds
  - Cleanup test namespace
  - Framework: Bash script with kubectl
  - Done: Restore drill passes, PVCs Bound, MySQL probe succeeds

- [ ] **[M]** Test backup-verification CronJob freshness check (`tests/qa/test_backup_verification.sh`) | AC: #8 | Depends: Build Phase 2 complete
  - Trigger backup-verification CronJob manually
  - Verify job completes successfully
  - Verify backup age is within freshness threshold (2h for hourly, 26h for daily)
  - Framework: Bash script with kubectl
  - Done: Job succeeds, freshness check passes

- [ ] **[M]** Test DR evidence bundle generation end-to-end (`tests/qa/test_dr_evidence_bundle.sh`) | AC: #9, #10 | Depends: Build Phase 4 complete
  - Run: `STRICT_RUNTIME=1 ./scripts/qa/build-dr-evidence-bundle.sh --tar`
  - Verify tarball exists and contains all required artifacts
  - Verify artifact sizes are non-zero
  - Verify JSON artifacts are valid JSON
  - Framework: Bash script with tar/jq
  - Done: Evidence bundle complete, all artifacts valid

### End-to-End Tests

- [ ] **[L]** Test full namespace restore from backup (`tests/e2e/test_full_restore.sh`) | AC: #16 | Depends: Build Phasecomplete
  - Select latest daily backup
  - Restore into throwaway namespace with namespace-mappings
  - Wait for all pods to reach Running/Completed
  - Run public health checks against restored environment
  - Cleanup throwaway namespace
  - Framework: Bash script with kubectl + curl
  - Done: Full restore completes within 1h RTO, health checkspass

- [ ] **[L]** Test cross-region cluster provisioning (tabletop) (`tests/e2e/test_cross_region_failover.md`) | AC: #21 | Depends: Build Phase 3 complete
  - Follow CROSS_REGION_FAILOVER.md runbook step-by-step
  - Provision secondary GKE cluster in different region
  - Restore Velero backup to secondary cluster
  - Verify MongoDB Atlas connectivity from secondary region
  - Verify DNS failover procedure
  - Document time taken for each step
  - Framework: Manual tabletop exercise with documentation
  - Done: Tabletop complete, all steps validated, RTO estimate confirmed

### Load Tests

- [ ] **[M]** Test Velero backup completion time under load (`tests/load/test_backup_performance.sh`) | NFR: Performance |Depends: Build Phase 1 complete
  - Trigger hourly critical backup manually
  - Measure completion time from start to Completed phase
  - Verify completion time is under 30 minutes
  - Measure restore completion time from start to Completed phase
  - Verify restore time is under 15 minutes for single-namespace
  - Framework: Bash script with time measurement
  - Done: Backup <30min, restore <15min, meets performance NFR

### Security Tests

- [ ] **[M]** Test GCS backup bucket IAM restrictions (`tests/security/test_gcs_backup_iam.sh`) | NFR: Security | Depends:Build Phase 1 complete
  - Verify only Velero service account has write permissions
  - Verify encryption at rest is enabled
  - Attempt access with non-Velero SA (should fail)
  - Verify cross-region replication uses encrypted transport(TLS)
  - Framework: gcloud commands + assertions
  - Done: IAM restrictions verified, encryption enabled, unauthorized access blocked

- [ ] **[S]** Test DR evidence bundle secret sanitization (`tests/security/test_evidence_sanitization.py`) | NFR: Security| Depends: Build Phase 4 complete
  - Generate evidence bundle
  - Scan all JSON files for plaintext secrets (regex patterns)
  - Verify no secrets in evidence bundle
  - Framework: Python with regex secret detection
  - Done: No secrets found in evidence bundle

### Negative Tests (Edge Cases)

- [ ] **[M]** Test restore with zero volume snapshots (`tests/negative/test_zero_snapshots.sh`) | Edge Case: Zero Snapshots | Depends: Build Phase 1 complete
  - Create backup with volumeSnapshotLocations misconfigured
  - Verify audit-velero.sh detects critical failure
  - Verify alert fires
  - Framework: Bash script with kubectl + assertions
  - Done: Audit detects failure, alert fires within 1h

- [ ] **[M]** Test restore drill with stuck namespace (`tests/negative/test_stuck_namespace.sh`) | Edge Case: Stuck Terminating | Depends: Build Phase 1 complete
  - Create restore drill with namespace that has finalizers
  - Verify restore-test script handles stuck namespace gracefully
  - Verify cleanup completes without blocking
  - Framework: Bash script with kubectl + finalizer manipulation
  - Done: Restore-test completes, stuck namespace detected and cleaned

- [ ] **[M]** Test Atlas backup verification when snapshots are stale (`tests/negative/test_atlas_stale.sh`) | Edge Case:Atlas Stale | Depends: Build Phase 1 complete
  - Mock Atlas snapshots list returning empty or stale data
  - Verify audit script detects stale Atlas backups
  - Verify alert fires
  - Framework: Python mock + audit script
  - Done: Stale Atlas backup detected, alert fires

- [ ] **[M]** Test partial restore with acceptable errors (`tests/negative/test_partial_restore.sh`) | Edge Case: PartialRestore | Depends: Build Phase 1 complete
  - Trigger restore that will have CRD version mismatches
  - Verify restore completes with PartiallyFailed status
  - Verify restore-test script accepts partial failure when errors <= MAX_PARTIAL_ERRORS (10)
  - Verify restore rejects when errors > 10
  - Framework: Bash script with kubectl + error injection
  - Done: Partial restore accepted when errors <=10, rejectedwhen >10

- [ ] **[M]** Test secrets desync after restore (`tests/negative/test_secrets_desync.sh`) | Edge Case: Secrets Desync | Depends: Build Phase 1 complete
  - Restore namespace with outdated secrets
  - Verify ExternalSecrets operator re-syncs within 1h refresh interval
  - Document manual resync procedure (delete secrets to forcerefresh)
  - Framework: Bash script with kubectl + time measurement
  - Done: ExternalSecrets re-syncs within 1h, manual resync tested

- [ ] **[M]** Test concurrent backup and restore operations (`tests/negative/test_concurrent_ops.sh`) | Edge Case: Concurrent Ops | Depends: Build Phase 1 complete
  - Trigger backup in one namespace
  - Attempt restore in same namespace before backup completes
  - Verify restore fails or produces error
  - Document mitigation: pre-op backup must complete (--wait)before restore
  - Framework: Bash script with kubectl + concurrency testing
  - Done: Concurrent ops detected, mitigation documented

---

## Observability Tasks

### Logs

- [ ] **[S]** Configure Velero controller logs export to Loki(`deploy/k8s/base/monitoring/logging/velero-logs.yaml`) | Observability Req | Depends: Phase 2 complete
  - Add PodLogs CRD or Promtail config for velero namespace
  - Verify logs are indexed in Loki
  - Add example LogQL queries to ONCALL_OBSERVABILITY_PLAYBOOK.md
  - Done: Velero logs searchable in Grafana Explore

- [ ] **[S]** Configure restore-test and backup-verificationjob logs export (`deploy/k8s/base/monitoring/logging/velero-jobs-logs.yaml`) | Observability Req | Depends: Logs task above
  - Add PodLogs CRD for velero namespace jobs with component=restore-test,backup-verification labels
  - Verify job logs are indexed in Loki
  - Done: Job logs searchable in Grafana Explore

### Metrics

- [ ] **[M]** Create custom metrics for DR evidence bundle age (`infrastructure/monitoring/logging-metrics/dr-evidence-bundle-age.json`) | Observability Req | Depends: Build Phase 4 complete
  - Log-based metric: extract evidence bundle generation timestamp from logs
  - Metric: `dr_evidence_bundle_age_days` (gauge)
  - Alert: `DREvidenceBundleStale` when age >35 days
  - Done: Metric visible in Prometheus, alert fires when stale

- [ ] **[M]** Create custom metrics for restore drill age (`infrastructure/monitoring/logging-metrics/restore-drill-age.json`) | Observability Req | Depends: Build Phase 2 complete
  - Log-based metric: extract restore-test job completion timestamp
  - Metric: `dr_restore_drill_age_days` (gauge)
  - Alert: `VeleroRestoreTestStale` when age >45 days
  - Done: Metric visible in Prometheus, alert fires when stale

### Dashboards

- [ ] **[S]** Add Velero backup health panel to Operations Signals dashboard (`infrastructure/monitoring/dashboards/operations-signals.json`) | Observability Req | Depends: Build Phase 2 complete
  - Panel: Backup success rate (30-day rolling window)
  - Panel: Backup age (time since last successful backup perschedule)
  - Deploy updated dashboard
  - Done: Panels rendering in Operations Signals dashboard

---

## Documentation Tasks

- [ ] **[M]** Update DISASTER_RECOVERY.md with RPO/RTO commitments from spec (`docs/operations/DISASTER_RECOVERY.md`) | AC: #1 | Depends: None
  - Add Tier 1-6 RPO/RTO table from spec
  - Update recovery procedures for each disaster scenario (DR-001 to DR-011)
  - Add cross-region failover reference
  - Done: DISASTER_RECOVERY.md matches spec requirements

- [ ] **[M]** Update VELERO_BACKUP_AUDIT.md with new validation steps (`docs/operations/VELERO_BACKUP_AUDIT.md`) | AC: #1,#2, #3 | Depends: Build Phase 1 complete
  - Add volumeSnapshotsCompleted validation
  - Add BackupStorageLocation phase validation
  - Add emptyDir detection validation
  - Add cross-reference to audit-velero.sh script
  - Done: VELERO_BACKUP_AUDIT.md includes all validation steps

- [ ] **[S]** Create MONGODB_ATLAS_BACKUP.md runbook (`docs/operations/MONGODB_ATLAS_BACKUP.md`) | AC: #22 | Depends: Build Phase 1 complete
  - Document Atlas cluster tier requirements
  - Document continuous backup enablement procedure
  - Document PITR enablement procedure
  - Document snapshot verification procedure
  - Document restore procedure from Atlas snapshot
  - Done: Runbook tested, all procedures validated

- [ ] **[M]** Create CROSS_REGION_FAILOVER.md runbook (`docs/operations/CROSS_REGION_FAILOVER.md`) | AC: #21 | Depends: Build Phase 3 complete
  - Document secondary cluster provisioning procedure
  - Document Velero restore-to-new-cluster procedure
  - Document DNS failover procedure
  - Document MongoDB Atlas multi-region connectivity verification
  - Document rollback procedure
  - Done: Runbook tested in tabletop exercise

- [ ] **[S]** Create DNS_FAILOVER_PROCEDURE.md runbook (`docs/operations/DNS_FAILOVER_PROCEDURE.md`) | Req: Cross-Region |Depends: Build Phase 3 complete
  - Document Cloudflare DNS record updates
  - Document LoadBalancer IP change procedure
  - Document DNS propagation verification
  - Document rollback procedure
  - Done: Runbook includes copy-paste commands

- [ ] **[S]** Create SECRET_ROTATION_CHECKLIST.md runbook (`docs/operations/SECRET_ROTATION_CHECKLIST.md`) | AC: #17 | Depends: Build Phase 1 complete
  - Document secret rotation procedure for all secret types
  - Document verification steps (ExternalSecrets sync, pod restarts)
  - Document estimated time for full rotation (1h target)
  - Done: Checklist covers all secret types

- [ ] **[S]** Create DR_COMPLIANCE_REPORT_TEMPLATE.md (`docs/operations/DR_COMPLIANCE_REPORT_TEMPLATE.md`) | AC: #11 | Depends: Build Phase 4 complete
  - Template for enterprise client DR compliance reporting
  - Placeholders for evidence bundle artifacts
  - Procedure to generate report within 1 business day
  - Done: Template tested with sample evidence bundle

- [ ] **[S]** Create DR_COORDINATOR_CONTACTS.md (`docs/operations/DR_COORDINATOR_CONTACTS.md`) | Req: Business Continuity| Depends: None
  - List primary and secondary DR coordinator names and contact info
  - Document escalation procedure for P1/P2 incidents
  - Done: Document approved by leadership

- [ ] **[S]** Update ONCALL_OBSERVABILITY_PLAYBOOK.md with DRalerts (`docs/operations/ONCALL_OBSERVABILITY_PLAYBOOK.md`)| AC: #12, #13, #14 | Depends: Build Phase 2 complete
  - Add DR alert playbook entries for all 8 alerts
  - Add symptom → investigation → resolution steps
  - Add cross-references to runbooks
  - Done: Playbook includes all DR alerts

---

## Rollout Tasks

- [ ] **[S]** Enable feature flag for Cloud SQL backups (optional) (`.github/workflows/cloud-sql-backup.yml`) | Feature Flag | Depends: MySQL Cloud SQL migration (future)
  - Set GitHub Actions repo variable: `ENABLE_CLOUD_SQL_BACKUPS=true`
  - Verify workflow runs successfully
  - Document activation in DISASTER_RECOVERY.md
  - Done: Feature flag enabled, workflow runs (only if CloudSQL is active)

- [ ] **[S]** Conduct tabletop DR exercise for full cluster loss scenario (DR-007) (`docs/operations/DR_TEST_RESULTS.md`)| Rollout Validation | Depends: Phases 1-4 complete
  - Assemble participants (engineering, SRE, product)
  - Walkthrough full cluster rebuild procedure
  - Identify gaps in runbooks
  - Update runbooks based on findings
  - Document exercise results in DR_TEST_RESULTS.md
  - Done: Tabletop complete, gaps resolved, spec status → implemented

---

## Self-Check

- [ ] Every acceptance criterion (AC-001 to AC-022) has at least one build task
- [ ] Every acceptance criterion has at least one test case
- [ ] All edge cases have negative test cases
- [ ] Test tasks cover both happy path and edge cases
- [ ] File paths specified for each task
- [ ] Dependencies identified (or marked "None")
- [ ] Complexity estimated (S/M/L) for each task
- [ ] Test type (unit/integration/e2e) is appropriate
- [ ] Mocks/fixtures specified for tests requiring external services (Atlas, GCS, Infisical)
- [ ] Testmap YAML generated with full AC coverage
- [ ] Source spec linked in all outputs

---

## Completion Criteria

This spec is considered **implemented** when:
1. All build tasks are complete
2. All test tasks pass
3. All observability tasks are complete
4. All documentation tasks are complete
5. All rollout tasks are complete
6. `STRICT_RUNTIME=1 ./scripts/qa/build-dr-evidence-bundle.sh--tar` returns zero failures
7. DR evidence bundle uploaded to GCS with 12-month retention
8. Tabletop exercise for full cluster loss (DR-007) is complete and documented
9. Spec status updated to "implemented"

---

## Estimated Effort

| Phase | Tasks | Complexity | Estimated Duration |
|-------|-------|------------|--------------------|
| Phase 1 - Baseline | 5 build | 2S + 3M | 5-7 days |
| Phase 2 - Monitoring | 5 build | 1S + 3M + 1L | 7-10 days |
| Phase 3 - Cross-Region | 5 build | 1S + 3M + 1L | 10-14 days |
| Phase 4 - Compliance | 5 build | 3S + 2M | 5-7 days |
| Phase 5 - Validation | 1 build | 1M | 2-3 days |
| Test Tasks | 17 tests | 3S + 10M + 4L | 15-20 days |
| Observability Tasks | 5 tasks | 4S + 1M | 3-5 days |
| Documentation Tasks | 9 docs | 8S + 2M | 5-7 days |
| Rollout Tasks | 2 tasks | 2S | 2-3 days |
| **Total** | **52 tasks** | **23S + 20M + 9L** | **54-76 days (10-15 weeks)** |

Note: Most build tasks are verification/documentation work, not new code. Actual implementation time may be faster with parallel work.

---

## Notes

- This spec formalizes existing infrastructure; most tasks are verification and documentation
- Critical path: Phase 1 → Phase 2 → Phase 5 (validation)
- Phase 3 (Cross-Region) can run parallel to Phase 2
- Phase 4 (Compliance) depends on Phases 1-3
- Some test tasks require GCP project access and Velero namespace access
- Cross-region failover tests are tabletop exercises (no actual regional outage simulation)
- Atlas backup tier upgrade may have cost implications (M0 →M10/M20)
- GCS multi-region storage and Artifact Registry replicationhave recurring cost implications

---

## Open Questions (from spec)

1. **Atlas backup tier**: What Atlas cluster tier is currently active (M0/M10/M20)? M0 free tier does not support continuous backup or PITR. If M0, must upgrade before Atlas requirements can be met.
2. **GCS backup bucket name and region**: What is the currentVelero GCS bucket name, region, and storage class? Is it single-region or multi-region?
3. **Enterprise SLA contractual language**: What specific uptime and data durability percentages are promised in enterprise contracts? This spec proposes 99.9% availability and 1-hourRPO.
4. **DR coordinator assignment**: Who are the primary and secondary DR coordinators? Names and contact information are required.
5. **Budget for cross-region**: Is there budget approved formulti-region GCS storage and Artifact Registry replication?
6. **Atlas snapshot retention**: What is the desired Atlas snapshot retention period? This spec proposes 7-day PITR minimum.
7. **Compliance frameworks**: Are there specific compliance frameworks (ISO 27001, SOC 2, PDPA) that the DR evidence mustsatisfy?
8. **Tabletop exercise participants**: Who should participatein semi-annual DR tabletop exercises?
9. **Status page integration**: Should the Upptime status page automatically reflect DR events, or is manual update acceptable?
10. **MySQL migration to Cloud SQL timeline**: When is MySQLexpected to migrate to Cloud SQL? This affects Tier 1 backupstrategy.
