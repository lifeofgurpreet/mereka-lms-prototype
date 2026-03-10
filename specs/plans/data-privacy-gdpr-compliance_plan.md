---
spec: data-privacy-gdpr-compliance_spec.md
tier: 5
status: draft
estimated_effort: "26 weeks (6 months, 5 phases)"
last_updated: "2026-02-10"
prerequisites:
  - "Tier 4 complete (multi-tenancy, auth-sso, enterprise-microservices)"
  - "All other Tier 5 specs substantially complete (purchase-gateway, email, badges, content-libs, xqueue)"
  - "Observability stack operational (Tier 2: Loki, Tempo, Prometheus, Grafana)"
  - "Analytics pipeline operational (Tier 2: ClickHouse, Aspects)"
  - "Secrets management operational (Tier 0: Infisical pipeline)"
  - "Disaster recovery operational (Tier 3: backup/restore verified)"
---

# Implementation Plan: Data Privacy & GDPR Compliance

**Source Spec**: `specs/data-privacy-gdpr-compliance_spec.md`

## Summary

This plan implements a cross-platform data privacy and compliance framework for Mereka Academy covering GDPR, PDPA, and SOC 2 Type II. The work is organized into 5 phases over 26 weeks, matching the spec's rollout plan. This spec MUST be implemented LAST in Tier 5 because it audits and integrates with every other service (Purchase Gateway, analytics pipeline, forum, observability stack, auth/SSO, multi-tenancy).

The scope covers:
- **Phase 0 (Weeks 1-4)**: PII inventory, audit trail, consent data model, breach procedures
- **Phase 1 (Weeks 5-8)**: Consent management API, preference center UI, cookie banner, consent enforcement
- **Phase 2 (Weeks 9-14)**: Cross-service data deletion pipeline with 15-step orchestration
- **Phase 3 (Weeks 15-18)**: Data export pipeline (GDPR Article 20 portability)
- **Phase 4 (Weeks 19-22)**: PII leakage detection, retention enforcement automation
- **Phase 5 (Weeks 23-26)**: Compliance reporting API, Grafana dashboards, SOC 2 evidence collection

**Spec Requirements Count**: 80+ MUST requirements, 10+ SHOULD requirements
**Acceptance Criteria Count**: 30 (AC-001 through AC-030)
**Edge Cases Count**: 20+ documented edge cases across deletion, consent, retention, audit trail, rate limits

---

## Prerequisites

Before starting Phase 0, verify:

1. **Tier 4 complete**: `multi-tenancy-architecture`, `auth-sso-enterprise`, `enterprise-microservices` are deployed and operational
2. **Tier 5 peers substantially complete**:
   - Purchase Gateway deployed (PostgreSQL schema exists for `orders`, `entitlements`, `stripe_events`)
   - Analytics pipeline operational (ClickHouse with `xapi_events_all` table)
   - Email notifications pipeline operational (for sending deletion confirmations, inactivity reminders)
   - Badges/credentials service deployed (certificate records accessible)
3. **Observability stack operational**: Loki ingesting logs, Prometheus scraping metrics, Grafana accessible
4. **Secrets management pipeline**: Infisical -> GCP SM -> ExternalSecrets -> K8s Secrets working
5. **Open Questions resolved**: Items 1-14 from spec (DPO appointment, legal review of retention periods, UserRetirement pipeline status, consent UX, DPA statuses, etc.)

---

## Task Breakdown

### Phase 0: Foundation (Weeks 1-4)

#### Build

- [ ] **[L]** Create PII registry YAML at `specs/pii-registry.yml` by auditing all database schemas (MySQL, MongoDB Atlas, PostgreSQL, ClickHouse, Redis, Loki, GCS) | AC: #1 | Depends: None
  - Done: YAML file contains every PII field across all data stores with all required attributes (`data_store`, `field_name`, `pii_type`, `sensitivity_tier`, `legal_basis`, `retention_period`, `processing_purposes`, `services_with_access`, `deletion_method`, `export_included`)
  - Files: `specs/pii-registry.yml`

- [ ] **[M]** Create PII registry validation tool that checks registry against live database schemas | AC: #1, #2 | Depends: PII registry
  - Done: Python script exits non-zero when unregistered PII fields exist or registry entries reference deleted fields
  - Files: `services/privacy-tools/inventory/validate_pii_registry.py`, `services/privacy-tools/inventory/schema_introspectors/`

- [ ] **[M]** Integrate PII registry validation into CI pipeline | AC: #2 | Depends: Validation tool
  - Done: GitHub Actions workflow runs on any PR that modifies `**/migrations/**` or `specs/pii-registry.yml`; blocks merge if validation fails
  - Files: `.github/workflows/pii-registry-check.yml`

- [ ] **[L]** Implement audit trail database model and hash chain mechanism | AC: #20, #21, #22 | Depends: None
  - Done: Django model `PrivacyAuditEntry` with fields: `event_id` (UUID), `event_type`, `user_id`, `actor_id`, `tenant_id`, `timestamp`, `details` (JSON), `integrity_hash` (SHA-256 chain). Append-only table with DB-level protections against UPDATE/DELETE
  - Files: `services/privacy-tools/audit/models.py`, `services/privacy-tools/audit/hash_chain.py`, `services/privacy-tools/audit/migrations/`

- [ ] **[M]** Implement audit trail integrity verification tool | AC: #21 | Depends: Audit trail model
  - Done: CLI tool that walks the hash chain and reports any broken links; exits non-zero on tampering
  - Files: `services/privacy-tools/audit/verify_integrity.py`

- [ ] **[M]** Implement audit trail GCS replication for tamper resistance | AC: #22 | Depends: Audit trail model
  - Done: Background worker replicates new audit entries to GCS bucket with object versioning and retention policy enabled
  - Files: `services/privacy-tools/audit/gcs_replicator.py`

- [ ] **[M]** Create `privacy_admin` and `compliance_officer` roles in LMS authorization system | AC: #27 | Depends: None
  - Done: Django permission groups created; management command to assign roles
  - Files: `services/privacy-tools/auth/roles.py`, `services/privacy-tools/management/commands/create_privacy_roles.py`

- [ ] **[S]** Create breach notification procedure document and contact list template | AC: #23, #24 | Depends: None
  - Done: Markdown procedure document with detection-through-remediation steps; contact list stored in Infisical
  - Files: `docs/runbooks/data-privacy-compliance-runbook.md`, `services/privacy-tools/breach/notification_template.md`, `services/privacy-tools/breach/contact_list.example.yml`

- [ ] **[S]** Create Data Processor Inventory document | AC: N/A (Req: Third-Party Processor Inventory) | Depends: None
  - Done: YAML file documenting all processors (GCP, MongoDB Atlas, Stripe, Infisical, Cloudflare, SendGrid) with DPA status
  - Files: `specs/data-processor-inventory.yml`

- [ ] **[S]** Create data residency documentation | AC: N/A (Req: Data Residency) | Depends: None
  - Done: Document mapping all data stores to geographic regions with SCC status
  - Files: `docs/concepts/architecture/data-residency-map.md`

- [ ] **[S]** Initialize `services/privacy-tools/` project structure | AC: N/A | Depends: None
  - Done: Python package with `pyproject.toml`, `requirements.txt`, `Dockerfile`, directory structure per spec monorepo layout
  - Files: `services/privacy-tools/pyproject.toml`, `services/privacy-tools/requirements.txt`, `services/privacy-tools/Dockerfile`, `services/privacy-tools/__init__.py`

#### Test

- [ ] **[M]** Unit tests for PII registry validation tool | AC: #1, #2 | Depends: Validation tool
  - Files: `services/privacy-tools/tests/test_pii_registry_validation.py`

- [ ] **[M]** Unit tests for audit trail hash chain creation and verification | AC: #20, #21 | Depends: Audit trail model
  - Files: `services/privacy-tools/tests/test_audit_trail.py`

- [ ] **[S]** Unit tests for audit trail GCS replication | AC: #22 | Depends: GCS replicator
  - Files: `services/privacy-tools/tests/test_gcs_replicator.py`

#### Docs

- [ ] **[S]** Create DPIA template document | AC: N/A (Req: Privacy by Design) | Depends: None
  - Files: `docs/operations/dpia-template.md`

---

### Phase 1: Consent Management (Weeks 5-8)

#### Build

- [ ] **[L]** Implement consent management data model (Django models, migrations) | AC: #3, #4, #5 | Depends: Phase 0 audit trail
  - Done: `ConsentRecord` model with all required fields (`user_id`, `purpose`, `granted`, `granted_at`, `withdrawn_at`, `consent_version`, `collection_method`, `ip_address_hash`, `tenant_id`). Append-only versioning
  - Files: `services/privacy-tools/consent/models.py`, `services/privacy-tools/consent/migrations/`

- [ ] **[L]** Implement consent management API endpoints | AC: #3, #4, #5, #27 | Depends: Consent data model
  - Done: REST API endpoints: `POST /api/v1/privacy/consent/`, `GET /api/v1/privacy/consent/{user_id}/`, `PUT /api/v1/privacy/consent/{user_id}/{purpose}/`, `GET /api/v1/privacy/compliance/consent-coverage/`
  - Files: `services/privacy-tools/consent/api.py`, `services/privacy-tools/consent/serializers.py`, `services/privacy-tools/consent/urls.py`

- [ ] **[M]** Implement consent enforcement middleware/hooks | AC: #5, #29 | Depends: Consent API
  - Done: Middleware that checks consent status before non-essential processing; fail-open for `essential_service`, fail-closed for `consent`-based purposes
  - Files: `services/privacy-tools/consent/enforcement.py`, `services/privacy-tools/consent/cache.py`

- [ ] **[M]** Implement consent preference center UI at `/account/privacy/` | AC: #4, #6, #7 | Depends: Consent API
  - Done: React component (MFE) showing all consent purposes with toggle switches; accessible to authenticated users
  - Files: `services/privacy-tools/consent/frontend/` (or integrated into existing MFE account settings)

- [ ] **[L]** Implement cookie consent banner for LMS and MFE surfaces | AC: #6, #7 | Depends: Consent API
  - Done: Cookie consent banner with categories (strictly_necessary, analytics, marketing, functional); no non-essential cookies set until consent granted; geo-detection for EU/UK vs ASEAN behavior
  - Files: `services/privacy-tools/consent/cookie_banner/`, `services/privacy-tools/consent/cookie_inventory.yml`

- [ ] **[S]** Create cookie inventory document | AC: #6 (Req: Cookie Consent) | Depends: None
  - Done: YAML documenting every cookie: name, purpose, category, duration, first-party vs third-party, associated service
  - Files: `services/privacy-tools/consent/cookie_inventory.yml`

- [ ] **[M]** Implement consent collection migration for existing users | AC: #3 (Edge Case: pre-consent users) | Depends: Consent API, preference center UI
  - Done: On next login, existing users without consent records see a consent collection prompt. Only `essential_service` and `legitimate_interest` processing allowed until consent collected
  - Files: `services/privacy-tools/consent/migration_prompt.py`

- [ ] **[S]** Implement per-tenant consent policy configuration | AC: N/A (Req: per-tenant consent) | Depends: Consent API, multi-tenancy
  - Done: Enterprise tenants can define additional consent purposes or modify consent text via admin API
  - Files: `services/privacy-tools/consent/tenant_policies.py`

#### Test

- [ ] **[M]** Unit tests for consent data model and versioning | AC: #3, #5 | Depends: Consent data model
  - Files: `services/privacy-tools/tests/test_consent_model.py`

- [ ] **[M]** Integration tests for consent API endpoints | AC: #3, #4, #5, #27 | Depends: Consent API
  - Files: `services/privacy-tools/tests/test_consent_api.py`

- [ ] **[M]** Integration tests for consent enforcement (analytics pipeline integration) | AC: #5, #29 | Depends: Consent enforcement middleware
  - Files: `services/privacy-tools/tests/test_consent_enforcement.py`

- [ ] **[S]** Unit tests for cookie consent behavior | AC: #6, #7 | Depends: Cookie banner
  - Files: `services/privacy-tools/tests/test_cookie_consent.py`

#### Rollout

- [ ] **[S]** Add feature flag `ENABLE_CONSENT_ENFORCEMENT` (default: off) | AC: #5 | Depends: None
  - Files: `services/privacy-tools/consent/feature_flags.py`

- [ ] **[S]** Add feature flag `ENABLE_COOKIE_CONSENT_BANNER` (default: off) | AC: #6 | Depends: None
  - Files: `services/privacy-tools/consent/feature_flags.py`

- [ ] **[S]** Add feature flag `ENABLE_CONSENT_GEO_DETECTION` (default: off) | AC: #6 | Depends: None
  - Files: `services/privacy-tools/consent/feature_flags.py`

---

### Phase 2: Data Deletion Pipeline (Weeks 9-14)

#### Build

- [ ] **[L]** Implement deletion request data model and state machine | AC: #8, #12 | Depends: Phase 0 audit trail
  - Done: `DeletionRequest` model with states: `pending_verification`, `verified`, `processing`, `completed`, `partially_completed`, `failed`, `rejected`
  - Files: `services/privacy-tools/deletion/models.py`, `services/privacy-tools/deletion/state_machine.py`, `services/privacy-tools/deletion/migrations/`

- [ ] **[M]** Implement deletion request API endpoint | AC: #8 | Depends: Deletion request model
  - Done: `POST /api/v1/privacy/deletion-request/`, `GET /api/v1/privacy/deletion-request/{id}/`, rate-limited (10/hour/IP)
  - Files: `services/privacy-tools/deletion/api.py`, `services/privacy-tools/deletion/urls.py`

- [ ] **[L]** Implement per-store deletion handlers (15 steps) | AC: #9, #11 | Depends: Deletion request model
  - Done: Individual handlers for: (1) Redis session invalidation, (2) account deactivation, (3) forum anonymization, (4) ClickHouse event deletion, (5) Purchase Gateway PII anonymization, (6) Notes deletion, (7) enrollment/grade deletion, (8) certificate revocation + GCS deletion, (9) profile data + image deletion, (10) auth_user anonymization, (11) SSO linkage deletion, (12) consent record anonymization, (13) audit trail identifier anonymization, (14) Redis cache cleanup, (15) log anonymization flag
  - Files: `services/privacy-tools/deletion/handlers/` (one file per store: `mysql_handler.py`, `mongodb_handler.py`, `redis_handler.py`, `clickhouse_handler.py`, `postgresql_handler.py`, `gcs_handler.py`, `loki_handler.py`)

- [ ] **[L]** Implement deletion orchestrator with retry and partial failure handling | AC: #8, #9, #12 | Depends: Per-store handlers
  - Done: Sequential execution with per-store 30-minute timeout, exponential backoff (base 30s, max 1h, max 20 retries), continues on failure, marks request as `partially_completed` if any store fails, fires alert on failure. Pauses if >3 stores fail (Critical alert, manual intervention required)
  - Files: `services/privacy-tools/deletion/orchestrator.py`

- [ ] **[M]** Implement deletion proof generation (cryptographic signing) | AC: #10 | Depends: Deletion orchestrator
  - Done: Signed document listing every data store, action taken, timestamp, hash of deletion manifest. Signing key stored in Infisical
  - Files: `services/privacy-tools/deletion/proof.py`

- [ ] **[M]** Implement deletion confirmation notification | AC: #9 | Depends: Deletion orchestrator
  - Done: Email sent to original address upon completion (address stored temporarily during deletion process)
  - Files: `services/privacy-tools/deletion/notification.py`

- [ ] **[M]** Implement re-run capability for partially completed deletions | AC: #12 | Depends: Deletion orchestrator
  - Done: `POST /api/v1/privacy/deletion-request/{id}/retry/` re-runs only failed stores. Idempotent: completed stores are no-ops
  - Files: `services/privacy-tools/deletion/retry.py`

- [ ] **[M]** Handle deletion edge cases: active enrollment, in-flight purchase, course author, concurrent export, enterprise admin | AC: #9, #11 (Edge Cases) | Depends: Deletion orchestrator
  - Done: Active enrollment proceeds with deactivation; in-flight purchase waits for terminal state; course author content preserved (author anonymized only); concurrent export completes before deletion starts; enterprise admin triggers 7-day handover notification
  - Files: `services/privacy-tools/deletion/edge_cases.py`

- [ ] **[S]** Implement legal retention check (reject deletion for legally retained data) | AC: #11 | Depends: Deletion orchestrator, PII registry
  - Done: Financial records within 7-year retention period are anonymized but retained; deletion proof notes legal basis
  - Files: `services/privacy-tools/deletion/retention_check.py`

#### Test

- [ ] **[L]** Integration tests for full deletion pipeline (all 15 store handlers) | AC: #9, #10, #11, #12 | Depends: Deletion orchestrator
  - Files: `services/privacy-tools/tests/test_deletion_pipeline.py`

- [ ] **[M]** Unit tests for deletion state machine transitions | AC: #8, #12 | Depends: Deletion request model
  - Files: `services/privacy-tools/tests/test_deletion_state_machine.py`

- [ ] **[M]** Unit tests for deletion proof generation and signature verification | AC: #10 | Depends: Deletion proof
  - Files: `services/privacy-tools/tests/test_deletion_proof.py`

- [ ] **[M]** Unit tests for deletion edge cases (active enrollment, in-flight purchase, course author, concurrent export, enterprise admin) | AC: #9, #11 | Depends: Edge case handlers
  - Files: `services/privacy-tools/tests/test_deletion_edge_cases.py`

- [ ] **[M]** Unit tests for idempotent re-run behavior | AC: #12 (Edge Case: Idempotency) | Depends: Retry capability
  - Files: `services/privacy-tools/tests/test_deletion_idempotency.py`

- [ ] **[S]** Unit tests for partial failure handling (>3 store failures triggers pause) | AC: #12 (Edge Case: Partial Failures) | Depends: Deletion orchestrator
  - Files: `services/privacy-tools/tests/test_deletion_partial_failure.py`

#### Rollout

- [ ] **[S]** Add feature flag `ENABLE_DELETION_PIPELINE` (default: off; queue requests only) | AC: #8 | Depends: None
  - Files: `services/privacy-tools/deletion/feature_flags.py`

---

### Phase 3: Data Export Pipeline (Weeks 15-18)

#### Build

- [ ] **[L]** Implement export request data model and API endpoint | AC: #13, #14, #15 | Depends: Phase 0 audit trail
  - Done: `ExportRequest` model with states: `pending`, `processing`, `completed`, `failed`, `expired`. API: `POST /api/v1/privacy/export-request/`. Rate-limited: 1 pending + max 3 per 30 days per user
  - Files: `services/privacy-tools/export/models.py`, `services/privacy-tools/export/api.py`, `services/privacy-tools/export/urls.py`, `services/privacy-tools/export/migrations/`

- [ ] **[L]** Implement per-store data extractors | AC: #13 | Depends: Export request model
  - Done: Extractors for: `profile.json` (auth_user + auth_userprofile), `enrollments.json`, `grades.json`, `certificates.json`, `forum_posts.json` (MongoDB), `notes.json`, `purchases.json` (PostgreSQL), `consents.json`, `audit_log.json`. Plus `README.md` generator
  - Files: `services/privacy-tools/export/extractors/` (one file per data source: `mysql_extractor.py`, `mongodb_extractor.py`, `postgresql_extractor.py`, `clickhouse_extractor.py`)

- [ ] **[M]** Implement archive assembly (ZIP packaging, AES-256 encryption) | AC: #13, #14 | Depends: Per-store extractors
  - Done: Assemble JSON files into ZIP archive, encrypt with AES-256 (user-provided password or generated key for one-time download link)
  - Files: `services/privacy-tools/export/archive.py`, `services/privacy-tools/export/encryption.py`

- [ ] **[M]** Implement download link generation with 48-hour expiry | AC: #14 | Depends: Archive assembly
  - Done: Signed URL with 48-hour TTL; archive deleted from server after download or after 7 days
  - Files: `services/privacy-tools/export/download.py`

- [ ] **[S]** Implement export background worker (off request path) | AC: #13 (NFR: Reliability) | Depends: Archive assembly
  - Done: Celery task for export generation; does not degrade LMS request latency
  - Files: `services/privacy-tools/export/tasks.py`

- [ ] **[S]** Implement export archive cleanup (delete after download or 7-day expiry) | AC: #14 | Depends: Download link
  - Done: Scheduled job cleans up expired archives from GCS
  - Files: `services/privacy-tools/export/cleanup.py`

#### Test

- [ ] **[M]** Integration tests for full export pipeline (all extractors + archive assembly) | AC: #13, #14 | Depends: Archive assembly
  - Files: `services/privacy-tools/tests/test_export_pipeline.py`

- [ ] **[S]** Unit tests for rate limiting (reject 4th request in 30 days) | AC: #15 | Depends: Export API
  - Files: `services/privacy-tools/tests/test_export_rate_limit.py`

- [ ] **[S]** Unit tests for archive encryption and download link expiry | AC: #14 | Depends: Encryption + download
  - Files: `services/privacy-tools/tests/test_export_encryption.py`

#### Rollout

- [ ] **[S]** Add feature flag `ENABLE_SELF_SERVICE_EXPORT` (default: off) | AC: #13 | Depends: None
  - Files: `services/privacy-tools/export/feature_flags.py`

---

### Phase 4: PII Leakage Detection and Retention Enforcement (Weeks 19-22)

#### Build

- [ ] **[L]** Implement PII leakage scanner for Loki logs | AC: #23, #25 | Depends: Phase 0
  - Done: Python script queries Loki for regex patterns matching raw email, IP address, names in log lines; flags matches; creates `breach_detected` audit entry on findings
  - Files: `services/privacy-tools/inventory/pii_scanner_loki.py`, `scripts/qa/audit-pii-loki.sh`

- [ ] **[M]** Implement PII leakage scanner for ClickHouse | AC: #26 | Depends: Phase 0
  - Done: Python script queries ClickHouse `xapi_events_all` for unhashed email fields; flags as critical PII leakage
  - Files: `services/privacy-tools/inventory/pii_scanner_clickhouse.py`, `scripts/qa/audit-pii-clickhouse.sh`

- [ ] **[M]** Implement retention enforcement job (weekly CronJob) | AC: #16, #17, #18, #19 | Depends: Deletion pipeline (Phase 2)
  - Done: K8s CronJob runs weekly: (a) detect inactive accounts at 18 months, send reminder email; (b) trigger deletion pipeline for 24-month inactive accounts; (c) drop ClickHouse partitions >365 days; (d) verify Loki retention policy (30 days); log all actions in audit trail
  - Files: `services/privacy-tools/retention/enforcement.py`, `services/privacy-tools/retention/inactive_account_detector.py`, `deploy/k8s/base/apps/privacy-tools/retention-cronjob.yaml`

- [ ] **[M]** Implement inactive account detection with edge case handling | AC: #16, #17 (Edge Cases: financial obligations, enterprise admin) | Depends: Retention enforcement job
  - Done: Skip auto-deletion for accounts with (a) financial records in 7-year retention, (b) active enterprise admin roles. Anonymize instead of full delete when financial obligations exist
  - Files: `services/privacy-tools/retention/edge_cases.py`

- [ ] **[S]** Schedule weekly PII scans as CronJob | AC: #25, #26 | Depends: PII scanners
  - Done: K8s CronJob runs PII scanner weekly; results stored; alerts fired on findings
  - Files: `deploy/k8s/base/apps/privacy-tools/pii-scan-cronjob.yaml`

#### Test

- [ ] **[M]** Unit tests for PII leakage scanner (Loki and ClickHouse) | AC: #25, #26 | Depends: PII scanners
  - Files: `services/privacy-tools/tests/test_pii_scanner.py`

- [ ] **[M]** Unit tests for retention enforcement (inactive account detection, partition dropping) | AC: #16, #17, #18 | Depends: Retention enforcement job
  - Files: `services/privacy-tools/tests/test_retention_enforcement.py`

- [ ] **[S]** Unit tests for retention edge cases (financial obligation, enterprise admin) | AC: #16, #17 | Depends: Edge case handlers
  - Files: `services/privacy-tools/tests/test_retention_edge_cases.py`

#### Rollout

- [ ] **[S]** Add feature flag `ENABLE_RETENTION_ENFORCEMENT` (default: off) | AC: #16 | Depends: None
  - Files: `services/privacy-tools/retention/feature_flags.py`

- [ ] **[S]** Add feature flag `ENABLE_PII_SCAN_ALERTS` (default: off) | AC: #25 | Depends: None
  - Files: `services/privacy-tools/inventory/feature_flags.py`

---

### Phase 5: Compliance Reporting and Hardening (Weeks 23-26)

#### Build

- [ ] **[L]** Implement compliance reporting API endpoints | AC: #27, #28 | Depends: Phases 0-4
  - Done: 7 endpoints: consent-coverage, deletion-requests, export-requests, pii-scan-results, retention-status, processor-inventory, audit-trail. All require `privacy_admin` or `compliance_officer` role. Rate-limited at 60 req/min
  - Files: `services/privacy-tools/compliance/api.py`, `services/privacy-tools/compliance/urls.py`, `services/privacy-tools/compliance/serializers.py`

- [ ] **[M]** Implement Grafana compliance dashboards | AC: #28 | Depends: Compliance API, metrics
  - Done: 5 dashboards: Privacy Compliance Overview, Deletion Pipeline Monitor, Consent Analytics, PII Leakage Tracker, Audit Trail Dashboard
  - Files: `infrastructure/monitoring/dashboards/privacy-compliance-overview.json`, `infrastructure/monitoring/dashboards/deletion-pipeline-monitor.json`, `infrastructure/monitoring/dashboards/consent-analytics.json`, `infrastructure/monitoring/dashboards/pii-leakage-tracker.json`, `infrastructure/monitoring/dashboards/audit-trail-dashboard.json`

- [ ] **[M]** Implement cross-service integration: analytics consent enforcement | AC: #29 | Depends: Consent enforcement (Phase 1), analytics pipeline
  - Done: Analytics pipeline checks user consent for `analytics` purpose before forwarding events to ClickHouse; events are dropped for users who have withdrawn consent
  - Files: `services/privacy-tools/consent/analytics_integration.py`

- [ ] **[M]** Implement cross-service integration: tenant offboarding data processing | AC: #30 | Depends: Deletion pipeline (Phase 2), multi-tenancy
  - Done: Tenant offboarding triggers deletion or export pipeline for all tenant users per DPA terms
  - Files: `services/privacy-tools/deletion/tenant_offboarding.py`

- [ ] **[M]** Implement breach notification automation (template auto-population, contact list retrieval) | AC: #24 | Depends: Breach procedure (Phase 0), PII scanner (Phase 4)
  - Done: When incident commander classifies breach as high severity, system auto-populates notification template with breach details and retrieves supervisory authority contacts
  - Files: `services/privacy-tools/breach/automation.py`

- [ ] **[S]** Implement Stripe event field-level encryption for PII in `stripe_events.payload` | AC: N/A (NFR: Security) | Depends: Secrets management
  - Done: AES-256 field-level encryption for `payload` column in Purchase Gateway `stripe_events` table; key managed via Infisical
  - Files: `services/privacy-tools/encryption/stripe_field_encryption.py`

#### Test

- [ ] **[M]** Integration tests for compliance reporting API | AC: #27, #28 | Depends: Compliance API
  - Files: `services/privacy-tools/tests/test_compliance_api.py`

- [ ] **[M]** Integration tests for cross-service consent enforcement (analytics + tenant offboarding) | AC: #29, #30 | Depends: Cross-service integrations
  - Files: `services/privacy-tools/tests/test_cross_service_integration.py`

- [ ] **[S]** Unit tests for breach notification automation | AC: #24 | Depends: Breach automation
  - Files: `services/privacy-tools/tests/test_breach_automation.py`

#### Observability

- [ ] **[M]** Implement Prometheus metrics for all privacy service operations | AC: N/A (Req: Observability) | Depends: All build tasks
  - Done: All 13 metrics from spec exposed: `privacy_deletion_requests_total`, `privacy_deletion_duration_seconds`, `privacy_deletion_sla_compliance`, `privacy_export_requests_total`, `privacy_export_duration_seconds`, `privacy_consent_changes_total`, `privacy_consent_coverage_ratio`, `privacy_pii_leakage_findings_total`, `privacy_retention_enforcement_deletions_total`, `privacy_audit_trail_entries_total`, `privacy_audit_trail_write_latency_seconds`, `privacy_consent_check_latency_seconds`, `privacy_processor_dpa_status`
  - Files: `services/privacy-tools/observability/metrics.py`

- [ ] **[M]** Implement alert rules for privacy service | AC: N/A (Req: Observability) | Depends: Prometheus metrics
  - Done: All alert rules from spec: Critical (deletion SLA <95%, PII leakage critical, health check failure), Warning (deletion failures, consent coverage <90%, export approaching SLA, audit trail latency, DPA expired), Info (retention deletions, elevated consent withdrawal)
  - Files: `infrastructure/monitoring/alerts/privacy-deletion-sla.json`, `infrastructure/monitoring/alerts/privacy-pii-leakage.json`, `infrastructure/monitoring/alerts/privacy-consent-coverage.json`, `infrastructure/monitoring/alerts/privacy-service-health.json`

- [ ] **[S]** Implement structured JSON logging for all privacy service operations | AC: N/A (Req: Observability) | Depends: All build tasks
  - Done: Every log line includes `service_name`, `tenant_id`, `request_id`, `log_level`, `timestamp`. No raw PII in log lines (SHA-256 hashes only)
  - Files: `services/privacy-tools/observability/logging.py`

#### Docs

- [ ] **[M]** Write privacy compliance runbook | AC: N/A | Depends: All phases
  - Files: `docs/runbooks/data-privacy-compliance-runbook.md`

- [ ] **[S]** Write troubleshooting guide for privacy service | AC: N/A | Depends: All phases
  - Files: `docs/operations/privacy-troubleshooting.md`

#### Rollout (K8s Deployment)

- [ ] **[M]** Create K8s manifests for privacy-tools service | AC: N/A | Depends: Dockerfile
  - Done: Deployment, Service, CronJobs (retention enforcement, PII scan), ExternalSecrets for signing key and encryption keys
  - Files: `deploy/k8s/base/apps/privacy-tools/deployment.yaml`, `deploy/k8s/base/apps/privacy-tools/service.yaml`, `deploy/k8s/base/apps/privacy-tools/retention-cronjob.yaml`, `deploy/k8s/base/apps/privacy-tools/pii-scan-cronjob.yaml`, `deploy/k8s/base/apps/privacy-tools/external-secrets.yaml`

- [ ] **[S]** Add privacy-tools to production Kustomize overlay | AC: N/A | Depends: K8s manifests
  - Files: `deploy/k8s/overlays/production/kustomization.yaml`

---

## Milestones

| Milestone | Target | Exit Criteria |
|-----------|--------|---------------|
| **M0: Foundation Complete** | Week 4 | PII registry exists and validates in CI; audit trail recording events with intact hash chain; breach procedure documented |
| **M1: Consent Live** | Week 8 | Consent records being collected for new registrations; preference center accessible; cookie banner displayed; consent enforcement enabled after 2-week data collection |
| **M2: Deletion Pipeline Operational** | Week 14 | First batch of deletion requests processed with cryptographic proof; all 15 store handlers tested; partial failure handling verified |
| **M3: Export Pipeline Live** | Week 18 | Self-service export produces encrypted ZIP within 72 hours; download links expire correctly; rate limiting enforced |
| **M4: PII Scanning Active** | Week 22 | Weekly PII scans running; retention enforcement processing inactive accounts; no unresolved critical PII leakage findings |
| **M5: Compliance Ready** | Week 26 | All 7 compliance API endpoints operational; Grafana dashboards deployed; SOC 2 evidence packages extractable; first EU enterprise tenant onboarded with DPA + DPIA |

---

## Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Open Questions 1-14 unresolved (DPO, legal review, DPA status) | Blocks Phase 0 start | High | Escalate to legal counsel before Week 1; designate interim DPO |
| Open edX UserRetirement pipeline status unknown | May require building parallel deletion system instead of extending existing | Medium | Audit UserRetirementStatus model in first week; decide extend vs replace |
| MongoDB Atlas deletion handler complexity (document-level anonymization) | Extends Phase 2 timeline | Medium | Prototype MongoDB handler first; use Atlas Data API if shell commands insufficient |
| ClickHouse event volume makes deletion slow | Deletion SLA at risk for high-volume users | Medium | Use ClickHouse ALTER TABLE DELETE (async); monitor deletion duration metric |
| Consent UX friction causes user complaints | Business impact from consent collection prompts | Medium | Use non-blocking banner (not modal) for existing users; monitor consent collection rate before enabling enforcement |
| PII leakage scanner false positives | Alert fatigue; scanner disabled prematurely | Medium | Tune scanner with `ENABLE_PII_SCAN_ALERTS=false` initially; review findings before enabling alerts |
| Cross-border transfer legal complexity (SCCs for Singapore-EU) | Legal review may delay Phase 5 EU tenant onboarding | Medium | Engage legal counsel for SCC review in Phase 0; do not block technical implementation |
| Insufficient engineering capacity for 26-week timeline | Phases slip; compliance deadlines missed | Medium | Identify minimum viable compliance posture (Phases 0-2) and prioritize those if capacity is constrained |
| Backup restoration re-introduces deleted user data | Compliance violation after backup restore | Low | Deletion pipeline re-runs pending deletions on backup restoration (documented in edge cases) |

---

## Self-Check

- [x] Every acceptance criterion (AC-001 through AC-030) has at least one build task
- [x] Every acceptance criterion has at least one test case (see testplan)
- [x] Every edge case from spec has a corresponding task or is handled within a parent task
- [x] Test tasks cover both happy path and edge cases
- [x] File paths specified for every task
- [x] Dependencies identified for all tasks
- [x] Complexity estimated (S/M/L) for every task
- [x] Observability tasks included (metrics, alerts, logging, dashboards)
- [x] Rollout tasks included (feature flags, K8s manifests, Kustomize)
- [x] Documentation tasks included (runbook, troubleshooting, DPIA template)
- [x] Source spec linked in header
