---
title: Enterprise Microservices Deployment Test Plan
spec: enterprise-microservices_spec.md
last_updated: '2026-02-13'
plan: enterprise-microservices_plan.md
status: draft
---

# Enterprise Microservices Deployment Test Plan

## Test Strategy

This test plan covers the deployment and operation of five enterprise microservices (enterprise-catalog, license-manager, enterprise-access, enterprise-subsidy, enterprise-integrated-channels) and two MFEs (admin portal, learner portal). Testing emphasizes tenant isolation, service-to-service communication, database isolation, and multi-tenant workflows.

**Note**: As of 2026-02-10, license-manager is NOT deployed (no upstream image). Tests marked with license-manager are deferred.

## Test Matrix

| AC ID | Description | Method | Priority | Automation |
|-------|-------------|--------|----------|------------|
| AC-001 | Enterprise deployments exist with READY replicas >= 1 | integration | P0 | automated |
| AC-002 | All enterprise services have non-empty endpoints | integration | P0 | automated |
| AC-003 | enterprise-catalog health check returns HTTP 200 | integration | P0 | automated |
| AC-004 | license-manager health check returns HTTP 200 | integration | P1 | automated (deferred) |
| AC-005 | enterprise-access health check returns HTTP 200 | integration | P0 | automated |
| AC-006 | enterprise-subsidy health check returns HTTP 200 | integration | P0 | automated |
| AC-007 | Enterprise admin portal loads (HTTP 200) | integration | P0 | automated |
| AC-008 | Enterprise learner portal loads (HTTP 200) | integration | P0 | automated |
| AC-009 | Domain uses DNS-only Cloudflare mode with Let's Encrypt SSL | manual | P0 | manual |
| AC-010 | Tenant A admin sees only tenant A's catalogs | integration | P0 | automated |
| AC-011 | Tenant B admin cannot access tenant A's subscription (HTTP 403) | integration | P0 | automated |
| AC-012 | Tenant B admin cannot access tenant A's enterprise-access API (HTTP 403) | integration | P0 | automated |
| AC-013 | Dual-tenant learner sees only selected tenant's catalog | e2e | P1 | semi |
| AC-014 | Dual-tenant learner context switch updates catalog view | e2e | P1 | semi |
| AC-015 | License assignment fails with HTTP 422 when seats exhausted | integration | P1 | automated (deferred) |
| AC-016 | Auto-apply license grants license on enrollment request | integration | P1 | automated (deferred) |
| AC-017 | License revocation triggers enrollment revocation | integration | P1 | automated (deferred) |
| AC-018 | Revocation cap enforcement prevents excess revocations | integration | P2 | automated (deferred) |
| AC-019 | Duplicate license assignment is idempotent | integration | P1 | automated (deferred) |
| AC-020 | Catalog filter (subject=Technology) returns only matching courses | integration | P1 | automated |
| AC-021 | Catalog sync task executes on 6-hour interval | integration | P1 | automated |
| AC-022 | contains_content_items API responds within 100ms | integration | P1 | automated |
| AC-023 | Per-learner enrollment limit enforced | integration | P1 | automated |
| AC-024 | Subsidy transaction fails with insufficient balance | integration | P1 | automated |
| AC-025 | Transaction reversal restores subsidy balance | integration | P1 | automated |
| AC-026 | Duplicate transaction reversal is idempotent | integration | P1 | automated |
| AC-027 | Enterprise slug-based login redirects to SAML IdP | integration | P1 | automated |
| AC-028 | SAML assertion creates new user and links to enterprise | integration | P1 | automated |
| AC-029 | Expired SAML assertion rejected | integration | P1 | automated |
| AC-030 | Cross-tenant SAML linking prevented | integration | P0 | automated |
| AC-031 | Degreed integration syncs completion data | integration | P1 | automated |
| AC-032 | Dry-run channel sync transmits no data | integration | P1 | automated |
| AC-033 | Channel sync retries with exponential backoff on HTTP 503 | integration | P1 | automated |
| AC-034 | ExternalSecrets syncs all enterprise secrets to K8s | integration | P0 | automated |
| AC-035 | enterprise-catalog reads SECRET_KEY from Infisical-synced secret | integration | P0 | automated |
| AC-036 | Prometheus scrapes enterprise service metrics | integration | P0 | automated |
| AC-037 | License assignment failure logs include enterprise_customer_uuid | integration | P1 | automated |

## Unit Tests

- EnterpriseCatalog content filter rule evaluation (subject, partner, skill, level)
- SubscriptionPlan license pool limit validation
- License state machine transitions (unassigned → assigned → activated → revoked)
- PerLearnerEnrollmentCreditAccessPolicy limit calculation
- Subsidy transaction balance calculation (starting_balance + SUM(transactions))
- Transaction reversal idempotency key generation
- SAML assertion validation (signature, issuer, audience, timestamps)
- OIDC token validation (signature, iss, aud, exp, nonce)
- Data sharing consent (DSC) enforcement logic
- EnterpriseCustomerUser queryset filtering by enterprise_customer_uuid
- Integrated channel payload construction (Degreed, CSOD)
- Integrated channel dry-run mode (no external API calls)
- OAuth2 client credentials token generation
- ExternalSecrets key mapping validation
- Catalog sync content metadata diff (added, removed, updated)

## Integration Tests

- All 7 enterprise K8s deployments exist with READY replicas
- All 5 enterprise ClusterIP services have non-empty endpoints
- Health check endpoints (enterprise-catalog, enterprise-access, enterprise-subsidy) return HTTP 200
- MFE admin portal loads at admin.academyv2.mereka.io (HTTP 200)
- MFE learner portal loads at learner.academyv2.mereka.io (HTTP 200)
- enterprise-catalog to LMS internal API call (http://lms:8000)
- enterprise-catalog to Cloud SQL connection (enterprise_catalog database)
- enterprise-access to Redis connection (cache)
- enterprise-subsidy to Cloud SQL connection (enterprise_subsidy database)
- enterprise-catalog Celery worker processes async indexing tasks
- enterprise-access Celery worker processes async enrollment tasks
- Catalog API: GET /api/v1/enterprise-catalogs/ (list catalogs for tenant A)
- Catalog API: GET /api/v1/enterprise-catalogs/{uuid}/get_content_metadata/ (paginated content)
- Catalog API: GET /api/v1/enterprise-catalogs/{uuid}/contains_content_items/ (content membership check)
- License API: GET /api/v1/subscriptions/ (list subscription plans for tenant A) [deferred]
- License API: POST /api/v1/subscriptions/{uuid}/licenses/assign/ (batch license assignment) [deferred]
- License API: POST /api/v1/subscriptions/{uuid}/licenses/revoke/ (batch license revocation) [deferred]
- Access API: GET /api/v1/policy-allocation/{uuid}/can-redeem/ (check if learner can redeem)
- Access API: POST /api/v1/policy-redemption/{uuid}/redeem/ (trigger enrollment)
- Subsidy API: GET /api/v1/subsidies/ (list subsidies for tenant A)
- Subsidy API: POST /api/v1/transactions/ (create transaction)
- Subsidy API: POST /api/v1/transactions/{uuid}/reverse/ (reverse transaction)
- Integrated channels sync task execution (Celery periodic task)
- SAML SSO flow: /enterprise/login/{slug} → IdP → ACS → session creation
- OIDC SSO flow: /auth/login/oidc/ → token exchange → session creation
- Cross-tenant API access denial (tenant B admin calls tenant A API → HTTP 403)
- Catalog sync periodic task (every 6 hours)
- ExternalSecrets sync (Infisical → GCP SM → K8s Secret)
- Prometheus metrics scraping (/metrics endpoints)
- Grafana dashboard rendering (Enterprise Overview, License Utilization, Catalog Health)

## E2E Tests

- Enterprise admin creates catalog with subject filter → learner sees only filtered courses
- Enterprise admin creates subscription plan with 100 licenses → assigns 50 → utilization shows 50% [deferred]
- Learner requests enrollment → access policy evaluated → license consumed → enrollment created [deferred]
- Learner with PerLearnerEnrollmentCreditAccessPolicy completes 4 enrollments → 5th enrollment succeeds → 6th denied
- Enterprise admin creates subsidy with $1000 balance → learner redeems $300 → balance shows $700
- Admin revokes enrollment → subsidy transaction reversed → balance restored
- Enterprise user logs in via SAML IdP for first time → JIT provisioning → user created → linked to enterprise
- Dual-tenant learner selects enterprise A → sees only enterprise A catalog → switches to enterprise B → sees only enterprise B catalog
- Degreed integration configured → course completion event → channel sync runs → completion data transmitted to Degreed
- Channel sync encounters HTTP 503 from CSOD → retries 3 times with exponential backoff → marks sync as failed
- License pool exhausted (100/100 assigned) → admin attempts to assign 101st → HTTP 422 (insufficient seats) [deferred]
- Subscription plan expires → new assignments blocked → existing enrollments remain active [deferred]
- Enterprise admin views analytics dashboard → sees tenant-specific enrollment/completion/license metrics
- Site operator checks Prometheus → sees enterprise_catalog_sync_duration_seconds metric

## Manual Verification

- DNS-only Cloudflare mode for admin.academyv2.mereka.io (gray cloud icon)
- Let's Encrypt certificate validity (not Cloudflare Universal SSL)
- MFE admin portal UX (dashboard, learner management, catalog management, subscription management)
- MFE learner portal UX (catalog browsing, self-enrollment, license status, DSC acceptance)
- SAML metadata exchange with pilot enterprise client (XML format, entity ID, ACS URL)
- OIDC discovery endpoint accessibility (.well-known/openid-configuration)
- Integrated channel configuration in LMS admin (Degreed, CSOD credentials)
- Data sharing consent flow (learner prompted for DSC before enterprise data visible)
- Enterprise onboarding script usage (scripts/infra/enterprise/onboard-tenant.sh)
- OAuth2 client application registration in LMS Django admin (for each enterprise service)
- ExternalSecrets key names match Infisical secrets (MEREKA_LMS_ENTERPRISE_CATALOG_SECRET_KEY, etc.)
- Grafana dashboard "Enterprise Overview" displays active customers, total licenses, subsidy balance
- Grafana dashboard "License Utilization" displays per-customer utilization trending over 30 days
- Grafana dashboard "Catalog Health" displays sync success rate, last sync time
- Catalog query latency (verify p95 < 300ms via Prometheus)
- License assignment latency (verify p95 < 5s for 500 emails via Prometheus) [deferred]

## Monitoring Verification

- Alert fires when any enterprise service health check fails for >3 consecutive checks
- Alert fires when subsidy balance drops below 10% for any active subsidy
- Alert fires when license utilization exceeds 95% for any subscription [deferred]
- Warning fires when catalog sync duration exceeds 30 minutes
- Warning fires when integrated channels sync duration exceeds 60 minutes
- Warning fires when SAML auth failure rate exceeds 10% over 15 minutes
- Warning fires when access policy denial rate exceeds 50% over 1 hour
- Info alert when license assignment activity is zero for 30 days for any subscription [deferred]
- Grafana dashboard "Enterprise Overview" displays expected panels
- Grafana dashboard "License Utilization" displays per-customer metrics [deferred]
- Grafana dashboard "Subsidy Ledger" displays balance burn rate and transaction volume
- Grafana dashboard "Integrated Channels" displays sync success/failure rate per channel type
- Prometheus scrapes enterprise-specific metrics (catalog_sync_duration_seconds, license_utilization_ratio, subsidy_balance_remaining)
- ServiceMonitor resources deployed (enterprise-catalog-metrics, enterprise-access-metrics, enterprise-subsidy-metrics)
- PrometheusRule deployed (enterprise-alerts) with 12 alert rules
