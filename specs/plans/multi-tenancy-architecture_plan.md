---
title: Multi-Tenancy Architecture - Implementation Plan
source_spec: specs/multi-tenancy-architecture_spec.md
created: '2026-02-10'
status: draft
spec: multi-tenancy-architecture_spec.md
last_updated: '2026-02-10'
---

# Implementation Tasks: Multi-Tenancy Architecture

**AC Coverage**: AC-MTA-001 through AC-MTA-028 (28 ACs from `specs/multi-tenancy-architecture_spec.md`)

**Source Spec**: `specs/multi-tenancy-architecture_spec.md`

**Acceptance Criteria Count**: 28 ACs
**Requirements Count**: 50+ functional requirements, 4 non-functional categories

---

## Summary

This plan implements a multi-tenancy architecture for MerekaAcademy Open edX, enabling a single deployment to serve multiple independent enterprise clients. The architecture uses `EnterpriseCustomer` as the tenant boundary with application-level isolation across all platform layers: LMS/CMS, enterprisemicroservices, MFEs, analytics (ClickHouse/Superset), and observability stack.

**Key architectural decisions from spec**:
- Shared-database model (no per-tenant database)
- Application-level isolation via Django queryset filtering
- MongoDB Atlas (no local MongoDB), with content access controlled by enterprise-catalog layer
- Per-tenant branding via SiteConfiguration JSON overlays onbase Mereka theme
- Tenant provisioning via automated scripts (not self-serviceportal at v1)

---

## Task Breakdown by Category

### Build

#### Phase 0: Foundation (Week 1-2)

**Tenant Data Model & Identity**

- [ ] **[M]** Audit existing `EnterpriseCustomer` model schema in Open edX (`infrastructure/tutor/patches/enterprise_customer_audit.py`) | AC: #1, #2 | Depends: None
  - Verify `enterprise_customer_uuid` (UUID primary key)
  - Verify `slug` field for URL routing
  - Verify `site_id` foreign key to Django `Site`
  - Verify `active` boolean flag
  - Verify `country`, `contact_email`, `identity_provider` fields
  - Document all enterprise feature flags supported by upstream

- [ ] **[M]** Create tenant configuration schema extension (`infrastructure/tutor/patches/tenant_config_schema.py`) | AC:#1 | Depends: EnterpriseCustomer audit
  - Define JSON schema for tenant configuration
  - Include: UUID, name, slug, active, site_id, country, contact_email, identity_provider, feature_flags
  - Validation rules: slug format (alphanumeric-hyphen), unique domain per site

- [ ] **[M]** Implement Django `Site` to `EnterpriseCustomer`mapping enforcement (`infrastructure/tutor/patches/site_enterprise_mapping.py`) | AC: #1 | Depends: Schema extension
  - Ensure one-to-one or one-to-many (Site → EnterpriseCustomer) relationship
  - Middleware to resolve current tenant from request `Host`header → Django Site → EnterpriseCustomer
  - Store `current_enterprise_customer` in request context for downstream use

**Data Segregation - Redis Cache Namespacing**

- [ ] **[M]** Implement Redis cache key namespacing for tenant-specific data (`infrastructure/tutor/patches/redis_tenant_namespace.py`) | Req: Data Isolation | Depends: None
  - Cache key format: `enterprise:{enterprise_customer_uuid}:{key_type}:{key_id}`
  - Patch enterprise-catalog cache layer to use namespaced keys
  - Patch license-manager cache layer to use namespaced keys
  - Verify shared platform cache keys (course metadata not scoped to tenant) do not include UUID

- [ ] **[S]** Document Redis cache key naming conventions (`docs/concepts/architecture/REDIS_TENANT_CACHE_KEYS.md`) | Depends: Redis namespacing
  - Naming pattern documentation
  - Examples of tenant-specific vs shared keys
  - Cache invalidation patterns per tenant

**Data Segregation - ClickHouse Analytics**

- [ ] **[M]** Add `enterprise_customer_uuid` column to ClickHouse xAPI events table (`scripts/analytics/add-enterprise-uuid-column.sql`) | Req: Analytics Isolation | Depends: None
  - Column type: `Nullable(UUID)`
  - Default: NULL (for non-enterprise learners)
  - Create migration script for schema change
  - Backfill strategy: tag existing events with NULL or Mereka default tenant UUID

- [ ] **[M]** Implement xAPI event tagging with `enterprise_customer_uuid` (`infrastructure/tutor/patches/xapi_enterprise_tagging.py`) | AC: #18 | Depends: ClickHouse column
  - Hook into Open edX event pipeline (tracking logs)
  - Extract `enterprise_customer_uuid` from learner's `EnterpriseCustomerUser` record
  - Tag events before writing to ClickHouse
  - Feature flag: `ENABLE_TENANT_ANALYTICS_SCOPING`

- [ ] **[L]** Implement Superset row-level security (RLS) fortenant analytics (`scripts/analytics/configure-superset-rls.py`) | AC: #19 | Depends: xAPI tagging
  - RLS policy: `WHERE enterprise_customer_uuid = :current_tenant_uuid`
  - Map Superset user → `EnterpriseCustomer` via custom authbackend
  - Ensure tenant admins see only their tenant's data
  - Platform operators (superuser) bypass RLS for cross-tenant reporting

- [ ] **[M]** Create per-tenant analytics dashboards in Superset (`scripts/analytics/create-tenant-dashboards.sh`) | AC: #19, #20 | Depends: RLS configuration
  - Enrollment count and trend dashboard
  - Course completion rate dashboard
  - License utilization dashboard
  - Learner engagement dashboard
  - Subsidy balance burn rate dashboard

**Tenant Branding System**

- [ ] **[M]** Create tenant branding directory structure (`infrastructure/tutor/themes/mereka/tenants/`) | AC: #8-11 | Depends: None
  - Directory per tenant: `infrastructure/tutor/themes/mereka/tenants/{tenant_slug}/`
  - Subdirectories: `logos/` (horizontal, square, white variants), `favicons/`, `css/` (color overrides)
  - README with branding asset requirements

- [ ] **[L]** Extend branding system to support per-tenant overrides (`infrastructure/tutor/patches/tenant_branding_override.py`) | AC: #8-11 | Depends: Directory structure
  - Read branding overrides from `SiteConfiguration.values` JSON field
  - Supported overrides: logo URLs, favicon URL, primary/secondary brand colors, footer content, login page branding, email sender alias
  - Fallback to base Mereka theme if tenant branding missing
  - Feature flag: `ENABLE_MULTI_TENANT_BRANDING`

- [ ] **[M]** Implement MFE branding configuration injection(`infrastructure/tutor/patches/mfe_tenant_branding.py`) | AC:#11 | Depends: Branding override system
  - Modify MFE `env.config.jsx` generation to read `SiteConfiguration` at runtime
  - Pass tenant branding variables to MFE via environment config endpoint
  - Support admin portal and learner portal MFE branding

- [ ] **[S]** Create branding asset deployment script (`scripts/branding/deploy-tenant-branding.sh`) | AC: #11 | Depends:Branding override system
  - Copy tenant assets from `infrastructure/tutor/themes/mereka/tenants/{slug}/` to static directory
  - Run `collectstatic` to publish assets
  - Invalidate CDN cache (if applicable)
  - No image rebuild required for branding updates

**Domain Routing & Site Configuration**

- [ ] **[M]** Extend Caddy configuration for multi-tenant domain routing (`deploy/k8s/base/apps/caddy/Caddyfile.multi-tenant`) | AC: #12-14 | Depends: None
  - Support wildcard pattern: `{tenant_slug}.academyv2.mereka.io`
  - Support client-owned CNAME domains: `learning.acmecorp.com` → LMS
  - Forward `Host` header correctly to Django for Site resolution
  - SSL certificate management via Let's Encrypt

- [ ] **[M]** Implement `ALLOWED_HOSTS` and `CSRF_TRUSTED_ORIGINS` dynamic management (`infrastructure/tutor/patches/dynamic_allowed_hosts.py`) | AC: #12 | Depends: None
  - Populate `ALLOWED_HOSTS` from all Django `Site.domain` records at startup
  - Populate `CSRF_TRUSTED_ORIGINS` from all `Site.domain` records at startup
  - Support hot-reload on tenant provisioning (or require LMSrestart)

- [ ] **[M]** Implement `SiteConfiguration` resolution middleware (`infrastructure/tutor/patches/site_config_middleware.py`) | AC: #14 | Depends: Site enterprise mapping
  - Resolve `SiteConfiguration` from request `Host` header
  - Store resolved config in request context
  - Theme resolution, feature flag resolution, branding resolution from `SiteConfiguration.values`

#### Phase 1: Tenant Provisioning Workflow (Week 3-4)

- [ ] **[L]** Create tenant provisioning script (`scripts/tenants/provision-tenant.sh`) | AC: #21 | Depends: Foundation tasks
  - Step 1: Create Django `Site` record with primary domain
  - Step 2: Create `SiteConfiguration` with tenant-specific settings
  - Step 3: Create `EnterpriseCustomer` record linked to Site
  - Step 4: Create enterprise catalogs with content filters
  - Step 5: Create subscription plans and/or subsidy records
  - Step 6: Create access policies linking catalogs to subscriptions
  - Step 7: Configure SAML/OIDC identity provider (if applicable)
  - Step 8: Configure integrated channel connections (if applicable)
  - Step 9: Deploy tenant branding assets (call `scripts/branding/deploy-tenant-branding.sh`)
  - Step 10: Add tenant domain to Caddy config and restart
  - Step 11: Run isolation verification (`scripts/qa/verify-tenant-isolation.sh`)
  - Idempotent: re-running with same slug skips already-created records
  - Validation: fail-fast on invalid slug, duplicate domain,missing required inputs

- [ ] **[M]** Create Django management command wrappers for provisioning steps (`infrastructure/tutor/patches/management_commands/`) | AC: #21 | Depends: Provisioning script
  - `create_enterprise_site.py`: Create Site + SiteConfiguration
  - `create_enterprise_customer.py`: Create EnterpriseCustomer linked to Site
  - `create_enterprise_catalog.py`: Create catalogs with filters
  - `create_enterprise_subscriptions.py`: Create subscriptionplans
  - `configure_enterprise_idp.py`: Configure SAML/OIDC provider
  - All commands idempotent and return clear status messages

- [ ] **[S]** Create provisioning validation script (`scripts/tenants/validate-provisioning-inputs.sh`) | AC: #21 | Depends: None
  - Validate tenant slug format (alphanumeric-hyphen only)
  - Check for duplicate slug in existing `EnterpriseCustomer`records
  - Check for duplicate domain in existing `Site` records
  - Validate email format for contact_email
  - Exit with error code if validation fails

- [ ] **[M]** Implement provisioning rollback script (`scripts/tenants/rollback-provisioning.sh`) | Edge Case: Partial provisioning | Depends: Provisioning script
  - Delete records created during failed provisioning in reverse order
  - Option to preserve or delete based on --preserve-partialflag
  - Log all rollback actions for audit

#### Phase 2: Tenant Offboarding Workflow (Week 5-6)

- [ ] **[L]** Create tenant offboarding script (`scripts/tenants/offboard-tenant.sh`) | AC: #22-24 | Depends: Provisioningcomplete
  - Step 1: Data export (call `scripts/tenants/export-tenant-data.sh`)
  - Step 2: Deactivation (`EnterpriseCustomer.active = False`)
  - Step 3: SSO disablement (deactivate SAML/OIDC provider config)
  - Step 4: Integrated channel disablement (disable channel sync tasks)
  - Step 5: Grace period tracking (30 days from deactivationtimestamp)
  - Step 6: Data deletion (call `scripts/tenants/delete-tenant-data.sh`)
  - Step 7: Branding cleanup (remove assets from theme directory)
  - Step 8: Domain removal (remove from Caddy, restart)
  - All actions logged to audit log

- [ ] **[L]** Create tenant data export script (`scripts/tenants/export-tenant-data.sh`) | AC: #22 | Depends: None
  - Export from LMS database: learner records, enrollment data, completion data
  - Export from enterprise service databases: license assignments, subsidy transactions
  - Export from ClickHouse: analytics events tagged with tenant UUID
  - Output format: JSON or CSV (configurable)
  - PDPA/GDPR data portability compliance

- [ ] **[M]** Create tenant data deletion script (`scripts/tenants/delete-tenant-data.sh`) | AC: #22, #23 | Depends: Dataexport
  - Delete from enterprise service databases: `WHERE enterprise_customer_uuid = '{uuid}'`
  - Delete from ClickHouse: `WHERE enterprise_customer_uuid ='{uuid}'`
  - Delete from Redis: flush all keys matching `enterprise:{uuid}:*`
  - Preserve LMS user accounts (enrollments remain, enterprise membership removed)
  - Verification step: count remaining records, must be zero

- [ ] **[M]** Create post-deletion verification script (`scripts/tenants/verify-deletion.sh`) | AC: #22 | Depends: Data deletion
  - Query all enterprise service databases for tenant UUID
  - Query ClickHouse for tenant UUID
  - Query Redis for tenant UUID keys
  - Report: zero records = pass, any records = fail with details

#### Phase 3: Isolation Verification (Week 6-7)

- [ ] **[L]** Create cross-tenant isolation test suite (`scripts/qa/verify-tenant-isolation.sh`) | AC: #25, #26 | Depends:Provisioning complete
  - API isolation test: authenticate as tenant A admin, attempt tenant B API endpoints, expect HTTP 403
  - Portal isolation test: authenticate as tenant A admin inadmin portal, verify zero tenant B records in UI
  - Analytics isolation test: query ClickHouse as tenant A, verify zero tenant B events returned (via Superset or direct query)
  - Search isolation test: query enterprise catalog search astenant A, verify zero tenant B catalog results
  - Output: pass/fail per test, summary report
  - Return exit code 0 if all pass, 1 if any fail

- [ ] **[M]** Integrate isolation tests into nightly CI job (`deploy/k8s/base/jobs/nightly-isolation-test.yaml`) | AC: #26| Depends: Isolation test suite
  - Kubernetes CronJob running isolation test suite
  - Schedule: nightly at 02:00 UTC
  - Alertmanager integration: fire Critical alert if any testfails
  - Results logged to centralized log aggregation

- [ ] **[M]** Create tenant isolation monitoring dashboard (`infrastructure/observability/dashboards/tenant-isolation.json`) | AC: #26 | Depends: Isolation test suite
  - Historical isolation test results (pass/fail over time)
  - Cross-tenant access denial events (from security logs)
  - Rate of access denied by endpoint and tenant pair

#### Phase 4: Performance & Scalability (Week 8-9)

- [ ] **[M]** Add database indexes for tenant filtering (`scripts/migrations/add-tenant-indexes.sql`) | NFR: Performance |Depends: None
  - Index on `enterprise_customer_uuid` in all enterprise service tables
  - Composite indexes where needed (e.g., `(enterprise_customer_uuid, created_at)` for time-range queries)
  - MySQL EXPLAIN analysis to verify index usage

- [ ] **[M]** Implement read replica support for enterprise services (optional, if needed) | NFR: Scalability | Depends: Index creation
  - Configure MySQL read replicas in Cloud SQL
  - Route read-only queries (analytics, catalog search) to read replicas
  - Document replica lag monitoring

- [ ] **[M]** Implement ClickHouse partitioning by tenant (optional, if needed) | NFR: Performance | Depends: xAPI tagging
  - Partition xAPI events table by `enterprise_customer_uuid`(if query performance degrades)
  - Test query performance with partitioned vs non-partitioned schema
  - Document partition pruning behavior

- [ ] **[M]** Conduct load testing with 50 simulated tenants(`scripts/qa/load-test-multi-tenant.sh`) | AC: #28 | Depends:All implementations
  - Simulate concurrent API requests from 50 tenant contexts
  - Measure p95 latency per endpoint
  - Verify no tenant exceeds 120% of single-tenant baseline latency
  - Document noisy neighbor detection and mitigation strategies

### Test

#### Unit Tests

- [ ] **[M]** Redis cache key namespacing unit tests (`tests/unit/test_redis_tenant_namespace.py`) | Depends: Redis namespacing
  - Test cache key format includes tenant UUID
  - Test shared keys do not include tenant UUID
  - Test cache invalidation per tenant does not affect othertenants

- [ ] **[M]** Tenant branding override unit tests (`tests/unit/test_tenant_branding_override.py`) | AC: #8-11 | Depends: Branding override system
  - Test branding resolution from `SiteConfiguration.values`
  - Test fallback to base Mereka theme when tenant branding missing
  - Test invalid JSON in `SiteConfiguration.values` falls back gracefully

- [ ] **[M]** `SiteConfiguration` resolution unit tests (`tests/unit/test_site_config_resolution.py`) | AC: #14 | Depends:Site config middleware
  - Test resolution from `Host` header → Django Site → SiteConfiguration
  - Test resolution with multiple domains pointing to same Site
  - Test default Site when `Host` header does not match any Site

- [ ] **[M]** Tenant provisioning validation unit tests (`tests/unit/test_provisioning_validation.py`) | AC: #21 | Depends: Validation script
  - Test slug format validation
  - Test duplicate slug rejection
  - Test duplicate domain rejection
  - Test email format validation

#### Integration Tests

- [ ] **[L]** Tenant provisioning integration test (`tests/integration/test_tenant_provisioning.py`) | AC: #1, #21 | Depends: Provisioning script
  - Provision test tenant "test-acme" end-to-end
  - Verify all records created: Site, SiteConfiguration, EnterpriseCustomer, catalogs, subscriptions, access policies
  - Verify idempotency: re-run provisioning, no duplicates created
  - Verify domain added to Caddy and resolves correctly
  - Cleanup: offboard test tenant after test

- [ ] **[L]** Tenant branding integration test (`tests/integration/test_tenant_branding.py`) | AC: #8-11 | Depends: Branding system
  - Deploy branding assets for test tenant
  - HTTP GET test tenant domain, verify custom logo in HTML
  - HTTP GET test tenant domain, verify custom brand colors in CSS
  - HTTP GET test tenant domain, verify custom footer content
  - Verify MFE loads tenant-specific branding

- [ ] **[L]** Cross-tenant isolation integration test (`tests/integration/test_cross_tenant_isolation.py`) | AC: #3-5, #25| Depends: Provisioning + isolation test suite
  - Provision two test tenants: A and B
  - Authenticate as tenant A admin, call `/api/v1/enterprise-catalogs/`, verify zero tenant B catalogs returned
  - Authenticate as tenant A admin, call `/api/v1/subscriptions/{tenant_b_uuid}/`, verify HTTP 403
  - Authenticate as tenant A learner, access learner portal,verify zero tenant B catalog items
  - Cleanup: offboard both test tenants

- [ ] **[M]** Tenant analytics isolation integration test (`tests/integration/test_analytics_isolation.py`) | AC: #5, #18-| Depends: xAPI tagging + RLS
  - Provision test tenant with enrolled learners
  - Generate test xAPI events tagged with tenant UUID
  - Query ClickHouse as tenant admin (via Superset or directquery)
  - Verify only tenant's events returned (RLS enforced)
  - Query as platform operator, verify cross-tenant visibility (RLS bypassed)

- [ ] **[M]** Tenant offboarding integration test (`tests/integration/test_tenant_offboarding.py`) | AC: #22-24 | Depends:Offboarding script
  - Provision test tenant with sample data
  - Run data export, verify export file contains expected records
  - Run offboarding script, verify deactivation
  - Wait for grace period (or mock time), run data deletion
  - Run verification script, verify zero records remain

- [ ] **[M]** Multi-tenant domain routing integration test (`tests/integration/test_multi_tenant_routing.py`) | AC: #12-14| Depends: Caddy config + Site resolution
  - HTTP GET `https://test-acme.academyv2.mereka.io`, verifyresolves to test tenant
  - HTTP GET `https://test-beta.academyv2.mereka.io`, verifyresolves to different tenant
  - Verify each request resolves correct `SiteConfiguration`

#### End-to-End Tests

- [ ] **[L]** Full tenant lifecycle E2E test (`tests/e2e/test_tenant_lifecycle.py`) | AC: All | Depends: All implementations
  - Provision new tenant "e2e-test-tenant" via provisioning script
  - Deploy tenant branding assets
  - Create test enterprise admin and learner users
  - Authenticate as admin, access admin portal, verify tenant-specific UI
  - Authenticate as learner, access learner portal, verify tenant catalog
  - Generate analytics events, verify Superset dashboard shows correct data
  - Run isolation test suite, verify pass
  - Offboard tenant, verify data export and deletion
  - Cleanup

- [ ] **[M]** Multi-tenant concurrent access E2E test (`tests/e2e/test_concurrent_tenant_access.py`) | AC: #27, #28 | Depends: All implementations
  - Provision 5 test tenants
  - Simulate concurrent API requests from all 5 tenants
  - Verify p95 latency within acceptable thresholds
  - Verify no cross-tenant data leakage under concurrent load
  - Cleanup: offboard all test tenants

#### Performance Tests

- [ ] **[M]** Tenant API latency benchmark (`tests/performance/test_tenant_api_latency.py`) | AC: #27 | Depends: All implementations
  - Benchmark enterprise catalog API queries with 10 active tenants
  - Measure p95 latency, verify <= 300ms (per enterprise-microservices spec)
  - Compare to single-tenant baseline

- [ ] **[L]** 50-tenant scale test (`tests/performance/test_50_tenant_scale.py`) | AC: #28 | Depends: All implementations
  - Provision 50 test tenants (or simulate with test fixtures)
  - Concurrent API requests from all 50 tenant contexts
  - Measure p95 latency per tenant, verify no tenant exceeds120% of baseline
  - Identify noisy neighbor patterns (if any)
  - Cleanup: offboard all test tenants

### Observability

- [ ] **[M]** Implement tenant-scoped logging (`infrastructure/tutor/patches/tenant_logging.py`) | Req: Observability | Depends: None
  - Add `enterprise_customer_uuid` field to all enterprise service logs
  - Add `site_id` field to LMS logs for tenant-scoped requests
  - Omit `enterprise_customer_uuid` from platform-level logs(non-tenant-scoped)
  - Sensitive data redaction: no raw emails, SAML assertions,API keys

- [ ] **[M]** Implement tenant provisioning audit logging (`infrastructure/tutor/patches/provisioning_audit_log.py`) | AC:#24 | Depends: Provisioning script
  - Log all provisioning actions with: action (provision, update, deactivate, offboard, delete), enterprise_customer_uuid,enterprise_slug, actor_user_id, timestamp, details (JSON), outcome (success, failure, partial)
  - Store in dedicated audit log table or structured log stream

- [ ] **[M]** Implement tenant isolation violation logging (`infrastructure/tutor/patches/isolation_violation_log.py`) | Req: Observability | Depends: None
  - Log cross-tenant access denials with: requesting_user_id_hash, requesting_enterprise_uuid, target_enterprise_uuid, endpoint, method, timestamp
  - Log at CRITICAL severity for security monitoring

- [ ] **[M]** Implement Prometheus metrics for multi-tenancy(`infrastructure/tutor/patches/tenant_metrics.py`) | Req: Observability | Depends: None
  - `tenant_count_active` (gauge): number of active tenants
  - `tenant_count_total` (gauge): total tenants including deactivated
  - `tenant_user_count` (gauge, label: enterprise_customer_uuid): users per tenant
  - `tenant_api_requests_total` (counter, labels: enterprise_customer_uuid, service_name, endpoint, status_code)
  - `tenant_api_latency_seconds` (histogram, labels: enterprise_customer_uuid, service_name, endpoint)
  - `tenant_isolation_check_result` (gauge, labels: test_name, outcome): latest isolation test results
  - `tenant_provisioning_duration_seconds` (histogram): provisioning time
  - `tenant_offboarding_duration_seconds` (histogram): offboarding time
  - `tenant_branding_fallback_total` (counter, label: enterprise_customer_uuid): branding fallback count

- [ ] **[M]** Configure Alertmanager alerts for multi-tenancy(`infrastructure/observability/alerts/multi-tenancy-alerts.yml`) | Req: Observability | Depends: Metrics
  - Critical: `tenant_isolation_check_result{outcome="fail"}`for any test
  - Critical: `tenant_api_requests_total{status_code=403}` cross-tenant pattern > 10 in 5min
  - Warning: `tenant_branding_fallback_total` increases for any tenant
  - Warning: `tenant_api_latency_seconds` p95 > 120% baselinefor any tenant
  - Info: `tenant_count_active` changes (new tenant provisioned or deactivated)

- [ ] **[M]** Create Grafana dashboards for multi-tenancy (`infrastructure/observability/dashboards/multi-tenancy.json`) |Req: Observability | Depends: Metrics
  - Multi-Tenancy Overview: active tenant count, users per tenant, API request volume per tenant, latest isolation test results
  - Tenant Health: per-tenant API latency, error rate, cachehit rate, branding fallback count
  - Noisy Neighbor Detection: API request volume and latencydistributions across tenants
  - Isolation Compliance: historical isolation test results,cross-tenant access denial log, provisioning/offboarding audit trail

### Docs

- [ ] **[M]** Write tenant provisioning runbook (`docs/runbooks/tenant-provisioning-runbook.md`) | Depends: Provisioning script
  - Prerequisites: domain DNS setup, branding assets prepared
  - Step-by-step provisioning procedure with script invocation
  - Validation checklist after provisioning
  - Troubleshooting common provisioning failures
  - Rollback procedure for failed provisioning

- [ ] **[M]** Write tenant offboarding runbook (`docs/runbooks/tenant-offboarding-runbook.md`) | Depends: Offboarding script
  - Prerequisites: client agreement, data export destination
  - Step-by-step offboarding procedure
  - Grace period management
  - Data deletion verification
  - Compliance checklist (PDPA/GDPR)

- [ ] **[M]** Write multi-tenancy architecture overview (`docs/concepts/architecture/multi-tenancy-overview.md`) | Depends: All implementations
  - Tenant data model (EnterpriseCustomer as tenant boundary)
  - Isolation strategy (application-level, shared database)
  - Branding system architecture
  - Analytics isolation (ClickHouse RLS)
  - Domain routing (Caddy + Django Sites)
  - Provisioning and offboarding workflows
  - Integration with enterprise microservices, branding, multi-site domains, analytics, secrets, K8s, observability specs

- [ ] **[S]** Update architecture decision records (`docs/adr/`) | Depends: All implementations
  - ADR: Why shared-database instead of per-tenant-database
  - ADR: Why MongoDB Atlas (no local MongoDB)
  - ADR: Why application-level isolation instead of database-level
  - ADR: Why `EnterpriseCustomer` as tenant boundary (not custom model)

- [ ] **[S]** Update troubleshooting guide (`docs/runbooks/operations/TROUBLESHOOTING.md`) | Depends: All implementations
  - Section: Multi-tenancy troubleshooting
  - Symptom: Tenant sees wrong branding → Check SiteConfiguration resolution
  - Symptom: Tenant admin sees other tenant's data → Check isolation test results, RLS configuration
  - Symptom: Tenant domain not resolving → Check Caddy config, DNS records, ALLOWED_HOSTS

### Rollout

**Feature Flags**

- [ ] **[S]** Create feature flags for multi-tenancy (`infrastructure/tutor/config.yml`) | Depends: None
  - `ENABLE_MULTI_TENANT_BRANDING` (default: false)
  - `ENABLE_TENANT_ANALYTICS_SCOPING` (default: false)
  - `ENABLE_TENANT_PROVISIONING_SCRIPT` (default: false)
  - `ENABLE_NIGHTLY_ISOLATION_TESTS` (default: false)

**Phase 0: Foundation Deployment (Week 1-2)**

- [ ] **[M]** Deploy Redis cache namespacing to dev environment | Depends: Redis namespacing implementation
  - Enable in dev, monitor for cache-related errors
  - Verify cache hit rates remain stable

- [ ] **[M]** Add `enterprise_customer_uuid` column to ClickHouse in dev | Depends: ClickHouse schema change
  - Run migration, verify no query breakage
  - Backfill NULL for existing events (or tag with Mereka default tenant UUID)

- [ ] **[M]** Deploy tenant branding directory structure to dev | Depends: Directory structure creation
  - Create directory, deploy test branding assets for defaultMereka tenant

**Phase 1: First Tenant - Mereka Default (Week 3-4)**

- [ ] **[L]** Provision "Mereka Academy" as first tenant in dev | AC: #1 | Depends: Phase 0 + provisioning script
  - Run `./scripts/tenants/provision-tenant.sh --slug=mereka-academy --name="Mereka Academy" --domain=academyv2.mereka.io`
  - Link existing Django Site to Mereka `EnterpriseCustomer`
  - Verify existing functionality unchanged (regression test)
  - Tag existing ClickHouse events with Mereka enterprise customer UUID (backfill migration)
  - Run isolation test suite (single-tenant baseline, no cross-tenant checks yet)

**Phase 2: Second Tenant - Pilot Client (Week 5-7)**

- [ ] **[L]** Provision first external client tenant in dev |AC: All | Depends: Phase 1 + all foundation implementations
  - Select pilot client (e.g., "Acme Corp")
  - Deploy client branding assets
  - Configure client SSO/SAML integration (per `specs/auth-sso-enterprise_spec.md`)
  - Create client catalog with content filters
  - Create client subscription plan and access policies
  - Run isolation test suite with two tenants (full cross-tenant verification)
  - Verify per-tenant analytics in Superset
  - Verify per-tenant admin portal and learner portal
  - User acceptance testing with pilot client

- [ ] **[M]** Enable multi-tenancy feature flags in dev | Depends: Pilot client provisioned
  - `ENABLE_MULTI_TENANT_BRANDING=true`
  - `ENABLE_TENANT_ANALYTICS_SCOPING=true`
  - Monitor for 1 week, verify no regressions

**Phase 3: Operational Hardening (Week 8-10)**

- [ ] **[M]** Deploy to staging environment | Depends: Dev pilot success
  - Provision Mereka default tenant and pilot client in staging
  - Run full regression test suite
  - Load test with 10 simulated tenants
  - Enable nightly isolation test job in staging
  - Monitor for 1 week

- [ ] **[M]** Deploy to production | Depends: Staging success
  - Provision Mereka default tenant in production
  - Enable multi-tenancy feature flags in production
  - Monitor observability dashboards and alerts
  - No external client tenants yet (only Mereka default)

- [ ] **[L]** Onboard pilot client to production | Depends: Production deployment stable
  - Provision pilot client tenant in production
  - Run isolation test suite in production
  - User acceptance testing with pilot client in production
  - Monitor for 2 weeks

**Phase 4: Scale (Week 11+)**

- [ ] **[L]** Onboard 2-3 additional clients to production |Depends: Pilot client stable
  - Provision additional client tenants
  - Run cross-tenant isolation tests
  - Load test with 5+ active tenants
  - Enable all observability alerts

- [ ] **[M]** Enable nightly isolation tests in production |Depends: Multiple tenants stable
  - `ENABLE_NIGHTLY_ISOLATION_TESTS=true`
  - Configure Alertmanager integration for test failures

- [ ] **[L]** Load test with 50 simulated tenants | AC: #28 |Depends: Multiple tenants stable
  - Provision 50 test tenants in staging or dedicated load test environment
  - Run concurrent API request simulation
  - Measure p95 latency, identify bottlenecks
  - Tune database indexes, Redis caching, ClickHouse partitioning if needed
  - Consider read replicas if query latency degrades

### Verification Scripts

- [ ] **[M]** Create tenant provisioning verification script(`scripts/qa/verify-tenant-provisioning.sh`) | AC: #21 | Depends: Provisioning script
  - Verify all records created for tenant: Site, SiteConfiguration, EnterpriseCustomer, catalogs, subscriptions, access policies
  - Verify domain resolves and returns correct branding
  - Verify tenant appears in admin portal tenant list
  - Return exit code 0 if all checks pass, 1 if any fail

- [ ] **[M]** Create tenant health check script (`scripts/qa/check-tenant-health.sh`) | Depends: All implementations
  - Per-tenant health check: API latency, cache hit rate, analytics events count, branding assets present
  - Output: health status per tenant (healthy, degraded, unhealthy)
  - Can be run in CI or on-demand

---

## Dependencies Summary

### Critical Path
1. Foundation (tenant data model, cache namespacing, ClickHouse column, branding structure) → Tenant provisioning script →Isolation test suite → Pilot tenant deployment → Productionrollout

### Parallel Tracks
- Branding system (can proceed alongside provisioning workflow)
- Analytics isolation (can proceed alongside provisioning workflow)
- Observability (can proceed alongside implementations)
- Documentation (can proceed alongside implementations)

### Gating Tasks for Each Phase
- **Phase 0**: Redis namespacing, ClickHouse column, brandingdirectory structure, feature flags
- **Phase 1**: Provisioning script, management commands, validation script, isolation test suite
- **Phase 2**: All Phase 1 + branding override system, MFE branding injection, Superset RLS, domain routing
- **Phase 3**: All Phase 2 + offboarding script, data export,data deletion, nightly isolation tests
- **Phase 4**: All Phase 3 + load testing, read replicas (ifneeded), ClickHouse partitioning (if needed)

---

## Complexity Estimates

- **S (Small)**: <2 hours - Configuration, simple scripts, documentation updates
- **M (Medium)**: 2-8 hours - Feature implementation, middleware, integration tests
- **L (Large)**: >8 hours - Complex workflows (provisioning,offboarding), E2E tests, multi-service coordination

---

## Risk Mitigation

1. **Risk**: Cross-tenant data leakage
   - **Mitigation**: Automated isolation test suite run nightly, alerts on any failure
   - **Task**: Isolation test suite + nightly CI job

2. **Risk**: Performance degradation with high tenant count
   - **Mitigation**: Database indexes, load testing, read replicas as escape hatch
   - **Task**: Index creation + 50-tenant load test

3. **Risk**: Branding cache staleness
   - **Mitigation**: Cache invalidation on branding updates,fallback to default theme
   - **Task**: Branding deployment script with cache invalidation

4. **Risk**: Partial provisioning failures
   - **Mitigation**: Idempotent provisioning script, rollbackscript
   - **Task**: Provisioning script idempotency + rollback script

5. **Risk**: Data retention compliance (PDPA/GDPR)
   - **Mitigation**: Data export before deletion, verification script, audit logging
   - **Task**: Data export + deletion + verification scripts

---

## Open Questions to Resolve Before Implementation

1. **ClickHouse partitioning strategy**: Partition by `enterprise_customer_uuid` or by date? → Performance benchmarking with realistic tenant counts needed
2. **Tenant branding delivery**: `SiteConfiguration` JSON atruntime vs separate static asset bundles vs tenant-config APIendpoint? → UX and engineering input
3. **MongoDB courseware isolation**: Per-tenant partitioningneeded? → Business requirement clarification (shared contentvs tenant-specific content)
4. **Forum thread isolation**: Tenant-scoped forum threads for shared courses? → Product decision
5. **Tenant admin self-service branding**: Self-service via admin portal or operator-mediated? → Product decision
6. **Data residency**: Multi-region support needed? → Compliance team input
7. **Tenant SLA tiers**: Different SLA tiers for premium vs standard tenants? → Commercial input
8. **Cost attribution**: How to attribute infrastructure costs to tenants for billing? → Finance input
9. **Tenant-level backup and restore**: Per-tenant logical backups needed? → Disaster recovery requirements
10. **Cross-tenant superuser audit**: Break-glass procedure for platform operators accessing tenant data? → Security policy input

---

## Self-Check (Before Implementation Begins)

- [ ] Every acceptance criterion (1-28) has at least one build task
- [ ] Every acceptance criterion has at least one test task (unit/integration/e2e)
- [ ] Edge cases from spec have negative test tasks
- [ ] File paths specified for each implementation task
- [ ] Dependencies identified (or marked "None")
- [ ] Complexity estimated (S/M/L) for each task
- [ ] Observability tasks cover logs, metrics, alerts, dashboards
- [ ] Rollout tasks include feature flags, phased deployment,verification
- [ ] Docs tasks include provisioning runbook, offboarding runbook, architecture overview
- [ ] Source spec linked: `specs/multi-tenancy-architecture_spec.md`
