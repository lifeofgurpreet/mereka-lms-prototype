---
title: "Enterprise Microservices Deployment - Test Plan"
source_spec: "specs/enterprise-microservices_spec.md"
created: "2026-02-10"
status: "draft"
---

# Test Plan: Enterprise Microservices Deployment

**Source Spec**: `specs/enterprise-microservices_spec.md`

**Test Framework**: pytest (Python), shell scripts (verification), Locust (load tests)

**Acceptance Criteria**: 36 ACs mapped to test cases

---

## Test Coverage Matrix

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| **Service Deployment** |
| 1 | All five enterprise service Deployments listed with READY replicas >= 1 | integration | `tests/integration/enterprise/test_deployment.py` | Kind cluster with enterprise servicesdeployed |
| 2 | All enterprise service endpoints non-empty | integration | `tests/integration/enterprise/test_deployment.py` | Kindcluster |
| 3 | enterprise-catalog /health/ returns HTTP 200 with status=ok | integration | `tests/integration/enterprise/test_health_checks.py` | enterprise-catalog deployed |
| 4 | license-manager /health/ returns HTTP 200 | integration| `tests/integration/enterprise/test_health_checks.py` | license-manager deployed |
| 5 | enterprise-access /health/ returns HTTP 200 | integration | `tests/integration/enterprise/test_health_checks.py` | enterprise-access deployed |
| 6 | enterprise-subsidy /health/ returns HTTP 200 | integration | `tests/integration/enterprise/test_health_checks.py` |enterprise-subsidy deployed |
| 7 | admin.academyv2.mereka.io returns admin portal HTML with HTTP 200 | e2e | `tests/e2e/enterprise/test_mfe_deployment.py` | MFE deployed, DNS configured |
| 8 | enterprise.academyv2.mereka.io returns learner portal HTML with HTTP 200 | e2e | `tests/e2e/enterprise/test_mfe_deployment.py` | MFE deployed, DNS configured |
| **Tenant Isolation** |
| 9 | Admin A calls GET /api/v1/enterprise-catalogs/, only customer A catalogs returned | integration | `tests/integration/enterprise/test_tenant_isolation.py` | Two enterprise customers, separate catalogs, admin A authenticated |
| 10 | Admin B calls GET /api/v1/subscriptions/{plan_uuid_of_A}/, response is HTTP 403 | integration | `tests/integration/enterprise/test_tenant_isolation.py` | Admin B authenticated,customer A subscription plan UUID |
| 11 | Admin B calls enterprise-access API for customer A UUID, response is HTTP 403 | integration | `tests/integration/enterprise/test_tenant_isolation.py` | Admin B authenticated |
| 12 | Learner linked to customer A browses learner portal, only customer A catalog courses visible | e2e | `tests/e2e/enterprise/test_learner_portal_isolation.py` | Learner authenticated, customer A + B catalogs populated |
| 13 | Learner belonging to customer A and B selects customerA, no customer B data visible until context switch | e2e | `tests/e2e/enterprise/test_multi_org_learner.py` | Multi-org learner, both customer catalogs populated |
| **License Management** |
| 14 | Subscription plan with 100 licenses, 50 assigned, attempt to assign 51 more, request fails HTTP 422 | integration |`tests/integration/enterprise/test_license_assignment.py` |Subscription plan with 100 licenses, 50 already assigned |
| 15 | Subscription plan with should_auto_apply_licenses=true, learner requests enrollment, license auto-assigned and activated | integration | `tests/integration/enterprise/test_license_auto_apply.py` | Subscription plan, learner linked to enterprise customer |
| 16 | License in activated state, admin revokes, license state -> revoked, enrollment revocation event published | integration | `tests/integration/enterprise/test_license_revocation.py` | Activated license, enrollment exists, mock event bus |
| 17 | Subscription plan with revocation cap 10%, 100 licenses, admin attempts 11th revocation, request fails HTTP 422 | integration | `tests/integration/enterprise/test_license_revocation_cap.py` | Subscription plan with cap enabled, 10 licenses already revoked |
| 18 | Email already assigned license, admin assigns again, no duplicate license created, response indicates existing assignment | unit | `tests/unit/enterprise/test_license_idempotency.py` | Mock license database |
| **Enterprise Catalog** |
| 19 | Enterprise catalog with content filter subject="Technology", GET content_metadata, only "Technology" courses returned | integration | `tests/integration/enterprise/test_catalog_filters.py` | Catalog with filter, discovery service mock with mixed subjects |
| 20 | Catalog sync task not run in 6 hours, Celery beat fires, sync executes and updates content metadata | integration |`tests/integration/enterprise/test_catalog_sync.py` | Mock Celery beat, mock discovery service |
| 21 | GET /api/v1/enterprise-catalogs/{uuid}/contains_content_items/?course_run_ids=course-v1:Mereka+ENT101+2026, response indicates presence within 100ms | integration | `tests/integration/enterprise/test_catalog_contains.py` | Catalog with course, Redis cache enabled |
| **Enterprise Access and Subsidy** |
| 22 | Learner with PerLearnerEnrollmentCreditAccessPolicy limit 5, already 5 enrollments, requests 6th, can-redeem returns false with reason | integration | `tests/integration/enterprise/test_access_policy_limit.py` | Access policy, learner with 5 enrollments |
| 23 | Subsidy with starting balance 10000, 3000 spent, transaction for 8000 attempted, fails insufficient balance, balance remains 7000 | integration | `tests/integration/enterprise/test_subsidy_insufficient_balance.py` | Subsidy with balance|
| 24 | Committed transaction for enrollment in course X, admin revokes enrollment, reversal requested, subsidy balance restored | integration | `tests/integration/enterprise/test_transaction_reversal.py` | Committed transaction, subsidy |
| 25 | Reversal requested on already-reversed transaction, response HTTP 200 (idempotent), no balance change | unit | `tests/unit/enterprise/test_transaction_reversal_idempotency.py`| Mock transaction with reversed state |
| **SSO/SAML** |
| 26 | Enterprise customer "Acme Corp" with SAML IdP, user navigates to /enterprise/login/acme-corp, redirected to Acme IdP login page | e2e | `tests/e2e/enterprise/test_saml_login.py` | Mock SAML IdP or test Keycloak instance |
| 27 | SAML assertion from Acme IdP for user not in LMS, processed, new LMS user created and linked to Acme customer | integration | `tests/integration/enterprise/test_saml_jit_provisioning.py` | Mock SAML assertion, no existing user |
| 28 | SAML assertion with NotOnOrAfter in past, LMS processes, authentication rejected and user sees error message | integration | `tests/integration/enterprise/test_saml_expired_assertion.py` | Mock assertion with expired timestamp |
| 29 | Enterprise customer A with IdP "IdP-A", B with "IdP-B", user authenticates via IdP-A, linked to customer A only | integration | `tests/integration/enterprise/test_saml_tenant_isolation.py` | Two customers with separate IdPs, mock assertions |
| **Integrated Channels** |
| 30 | Degreed integration for customer A with valid credentials, sync task runs, course completion data transmitted to Degreed API | integration | `tests/integration/enterprise/test_channel_sync_degreed.py` | Mock Degreed API, learners with DSC, completion data |
| 31 | Channel sync in dry-run mode, sync task runs, no datatransmitted to external system, log indicates "dry-run" | integration | `tests/integration/enterprise/test_channel_sync_dryrun.py` | Mock channel API |
| 32 | Channel sync encounters HTTP 503, task retries up to 5times with exponential backoff before marking failed | integration | `tests/integration/enterprise/test_channel_sync_retry.py` | Mock channel API returning 503, track retry attempts|
| **Secrets and Configuration** |
| 33 | All enterprise secrets provisioned in Infisical, ExternalSecrets syncs, enterprise-secrets K8s Secret contains allexpected keys | integration | `tests/integration/enterprise/test_secrets_sync.py` | Infisical secrets, GCP SM, Kind cluster with ExternalSecrets |
| 34 | enterprise-catalog service starts, reads Django SECRET_KEY from env, value matches Infisical secret MEREKA_LMS_ENTERPRISE_CATALOG_SECRET_KEY | integration | `tests/integration/enterprise/test_secret_consumption.py` | enterprise-catalog deployed, secrets mounted |
| **Observability** |
| 35 | Enterprise services running, /metrics scraped by Prometheus, enterprise-specific metrics present | integration | `tests/integration/enterprise/test_metrics.py` | Prometheus deployed, enterprise services deployed |
| 36 | License assignment fails, log entry includes enterprise_customer_uuid, subscription_plan_uuid, error_type, user_email_hash (not raw email) | integration | `tests/integration/enterprise/test_logging_redaction.py` | Trigger license assignment error, parse logs |
| **Edge Cases (Negative Tests)** |
| EC-1 | Concurrent license assignment, two admins assign last available license simultaneously, exactly one succeeds, other receives HTTP 422 | integration | `tests/integration/enterprise/test_license_concurrency.py` | Subscription plan with 1license remaining, concurrent requests |
| EC-2 | Subscription plan expires (expiration_date in past),admin attempts new assignment, request fails, existing licenses remain active | integration | `tests/integration/enterprise/test_expired_subscription.py` | Expired subscription plan,activated licenses |
| EC-3 | License assigned to non-existent email, creates PendingEnterpriseCustomerUser, user registers, pending record resolved, license activated | integration | `tests/integration/enterprise/test_license_pending_user.py` | License assignmentto unregistered email |
| EC-4 | Batch license assignment of 500 emails, email #250 malformed, entire batch rejected with error indicating #250 |integration | `tests/integration/enterprise/test_batch_assignment_failure.py` | Batch with invalid email in middle |
| EC-5 | Learner already redeemed subsidy for course X, attempts redeem again, idempotent response (HTTP 200, existing transaction), no double deduction | integration | `tests/integration/enterprise/test_subsidy_double_redemption.py` | Existingtransaction for learner + course |
| EC-6 | Multiple concurrent redemptions against same subsidy, serialized at database level, only transactions fitting balance are committed | integration | `tests/integration/enterprise/test_subsidy_concurrency.py` | Subsidy with balance 5000,concurrent redemptions for 3000 each |
| EC-7 | Transaction reversal requested for pending transaction, transitions to failed without restoring balance (pendingnot yet deducted) | unit | `tests/unit/enterprise/test_reversal_pending_transaction.py` | Mock pending transaction |
| EC-8 | SAML IdP metadata refresh fails (endpoint down), system continues using cached metadata until next successful refresh | integration | `tests/integration/enterprise/test_saml_metadata_refresh_failure.py` | Mock IdP metadata endpoint timeout |
| EC-9 | SAML assertion missing email attribute, authentication rejected, log entry shows missing attributes without fullassertion | integration | `tests/integration/enterprise/test_saml_missing_attributes.py` | Mock assertion without email |
| EC-10 | SAML-authenticated user already in LMS but not linked to enterprise, auto-link on login, do not create duplicateaccount | integration | `tests/integration/enterprise/test_saml_existing_user_link.py` | Existing LMS user, first SAML auth |
| EC-11 | Course deleted from discovery service, next catalogsync marks content unavailable (soft delete), catalog remains valid | integration | `tests/integration/enterprise/test_catalog_sync_deleted_course.py` | Mock discovery service with course, then without |
| EC-12 | Enterprise catalog filter matches no courses, catalog valid (empty), admin portal displays "no content matches filter" message | e2e | `tests/e2e/enterprise/test_empty_catalog.py` | Catalog with overly restrictive filter |
| EC-13 | Discovery service unavailable during sync, sync task retries 3 times, all fail, logs error, emits alert, preserves last sync state | integration | `tests/integration/enterprise/test_catalog_sync_discovery_down.py` | Mock discovery service timeout |
| EC-14 | External channel API returns HTTP 429 (rate limit),sync task respects Retry-After header, reschedules batch, does not retry immediately | integration | `tests/integration/enterprise/test_channel_rate_limiting.py` | Mock channel API returning 429 with Retry-After |
| EC-15 | Client rotates Degreed API credentials, next sync fails with authentication error, clear log message, updating credentials in LMS admin fixes on next cycle | integration | `tests/integration/enterprise/test_channel_credential_rotation.py` | Mock channel API with new credentials, update config |
| EC-16 | Enterprise with >10,000 learners, channel sync paginates fetches (batch 500), no memory exhaustion | load | `tests/load/enterprise/test_channel_sync_large_learner_set.py` |Mock 10,000 learners, monitor memory usage |
| EC-17 | Learner revokes DSC mid-sync, excluded from currentsync payload, already-transmitted data unchanged (enterpriseDPA responsibility) | integration | `tests/integration/enterprise/test_dsc_revocation_mid_sync.py` | Mock DSC revocationduring sync |
| EC-18 | Enterprise service-to-service call (access -> catalog) uses higher rate limit tier (10k/min), not blocked by admin rate limits | integration | `tests/integration/enterprise/test_service_rate_limits.py` | Simulate 200 service calls/min, verify no 429 |
| **Performance (NFR Tests)** |
| NFR-1 | Enterprise catalog content metadata API paginated list (100 items), p95 latency <= 300ms | load | `tests/load/enterprise/test_catalog_list_latency.py` | 100 concurrent requests, measure p95 |
| NFR-2 | Enterprise catalog contains_content_items API, p95latency <= 100ms | load | `tests/load/enterprise/test_catalog_contains_latency.py` | 100 concurrent requests |
| NFR-3 | License manager batch assignment (500 emails), p95latency <= 5 seconds | load | `tests/load/enterprise/test_license_batch_latency.py` | 10 concurrent batches of 500 |
| NFR-4 | License manager single license lookup, p95 latency<= 200ms | load | `tests/load/enterprise/test_license_lookup_latency.py` | 100 concurrent lookups |
| NFR-5 | Enterprise access can-redeem API (cross-service calls), p95 latency <= 500ms | load | `tests/load/enterprise/test_access_can_redeem_latency.py` | 100 concurrent requests |
| NFR-6 | Enterprise subsidy transaction creation, p95 latency <= 1 second | load | `tests/load/enterprise/test_subsidy_transaction_latency.py` | 100 concurrent transactions |
| NFR-7 | SAML SSO login round-trip (redirect to authenticated session), completes within 5 seconds at p95 | load | `tests/load/enterprise/test_saml_login_latency.py` | 50 concurrentlogins, mock IdP with realistic latency |
| NFR-8 | Enterprise admin portal initial page load, <= 3 seconds at p95 | load | `tests/load/enterprise/test_admin_portal_load_time.py` | Agent Browser, 50 concurrent loads |
| NFR-9 | Integrated channel sync (10,000 learners), completes within 30 minutes | load | `tests/load/enterprise/test_channel_sync_large_scale.py` | Mock 10,000 learners with completion data |
| **Reliability (NFR Tests)** |
| NFR-10 | All enterprise services have readiness and liveness probes responding | integration | `tests/integration/enterprise/test_probes.py` | All services deployed |
| NFR-11 | Enterprise services available 99.9% measured overweek (exclude planned maintenance) | manual | Monitoring dashboard | Production environment, 1 week observation |
| NFR-12 | License assignment batch partial failure, all emails rolled back (all-or-nothing) | integration | `tests/integration/enterprise/test_license_batch_atomicity.py` | Batch with one invalid email at end |
| NFR-13 | Enterprise subsidy ledger eventually consistent within 30 seconds of transaction commit | integration | `tests/integration/enterprise/test_subsidy_eventual_consistency.py`| Commit transaction, poll balance endpoint |
| NFR-14 | Integrated channel sync transient failure, retrieswith exponential backoff (30s, 60s, 120s, ..., max 15min, max 5 retries) | integration | `tests/integration/enterprise/test_channel_retry_backoff.py` | Mock transient errors, track retry timing |
| **Security (NFR Tests)** |
| NFR-15 | Inter-service communication uses K8s Service DNS (no external egress for internal calls) | integration | `tests/integration/enterprise/test_internal_communication.py` | Network policy test, verify no external DNS lookups |
| NFR-16 | Enterprise service API (except health checks) requires JWT authentication, unauthenticated request returns HTTP| integration | `tests/integration/enterprise/test_jwt_enforcement.py` | Request without Authorization header |
| NFR-17 | Enterprise service API enforces enterprise_admin or enterprise_learner RBAC, wrong role returns HTTP 403 | integration | `tests/integration/enterprise/test_rbac_enforcement.py` | Authenticated learner attempts admin-only endpoint |
| NFR-18 | Enterprise catalog content filtered by enterprise_customer_uuid at queryset level, no cross-tenant data leakage| integration | `tests/integration/enterprise/test_queryset_filtering.py` | Two customers, query catalog for customer A,verify no customer B data |
| NFR-19 | License manager enforces admin can only view/modify own customer's subscription plans | integration | `tests/integration/enterprise/test_license_manager_rbac.py` | Admin Aattempts access to customer B plan |
| NFR-20 | SAML assertion signature validated against IdP certificate, invalid signature rejected | integration | `tests/integration/enterprise/test_saml_signature_validation.py` | Mock assertion with wrong signature |
| NFR-21 | SAML assertion NotOnOrAfter timestamp validated, expired assertion rejected (replay prevention) | integration |`tests/integration/enterprise/test_saml_replay_prevention.py` | Mock expired assertion |
| NFR-22 | SAML assertion audience restriction validated, wrong EntityID rejected | integration | `tests/integration/enterprise/test_saml_audience_validation.py` | Mock assertion withwrong audience |
| NFR-23 | System does not log SAML assertion XML (PII), onlymetadata (issuer, timestamp, status) | integration | `tests/integration/enterprise/test_saml_logging_redaction.py` | Trigger SAML auth, grep logs for assertion XML |
| NFR-24 | Database credentials unique per service, no sharedpasswords | manual | Check config files | Verify each service has distinct MYSQL_PASSWORD |
| NFR-25 | API rate limiting enforced: 100 req/min per adminuser, 1000 req/min per service account | integration | `tests/integration/enterprise/test_rate_limiting.py` | Exceed limits, verify HTTP 429 |

---

## Test Execution Strategy

### Unit Tests
- Run with `pytest tests/unit/enterprise/`
- Mock all external dependencies (database, Redis, HTTP APIs,event bus)
- Fast execution (<5 minutes for full unit suite)
- Coverage target: >80% for enterprise service code

### Integration Tests
- Run with `pytest tests/integration/enterprise/`
- Use Kind cluster with test database and Redis
- Mock external APIs (discovery service, channel APIs, SAML IdPs)
- Execution time: 30-60 minutes for full integration suite
- Run on every PR (required for merge)

### End-to-End Tests
- Run with Agent Browser or Playwright
- Require live services in Kind or staging GKE cluster
- Use test enterprise customer and test users
- Execution time: 60-90 minutes for full E2E suite
- Run nightly in CI

### Load Tests
- Run with Locust or k6
- Target staging GKE cluster (production-like scale)
- Execution time: 2-4 hours for full load suite
- Run weekly or before major releases

### Manual Tests
- Verification scripts run as part of CI/CD pipeline
- Production observability monitoring (availability, latency)
- Run post-deployment

---

## Test Data Requirements

### Fixtures
- Two enterprise customers (Acme Corp SAML, Beta Inc OIDC) with distinct UUIDs
- Enterprise catalogs with content filters (subject, partner,skill filters)
- Subscription plans (active, expired, revocation cap enabled/disabled)
- Subsidies (various balances, expired, active)
- Access policies (PerLearnerEnrollment, PerLearnerSpend, Subscription)
- Mock courses and programs (various subjects, partners)
- Learners with/without DSC, linked to customers
- Admins for each customer
- Mock SAML assertions (valid, expired, wrong issuer, missingattributes)
- Mock OIDC tokens
- Mock channel API responses (Degreed, Cornerstone)

### Test Secrets
- Test database passwords for each enterprise service
- Test Django SECRET_KEY for each service
- Test OAuth2 client secrets
- Test SAML signing keys (per tenant)
- Test Algolia credentials (if using Algolia)
- Test Degreed/Cornerstone API keys

### Mock Services
- Mock discovery service (returns course metadata)
- Mock SAML IdP (returns assertions)
- Mock Degreed API
- Mock Cornerstone API
- Mock event bus (Redis or Kafka)

---

## Negative Test Cases Summary

| Negative Scenario | Test Case | Type | File |
|-------------------|-----------|------|------|
| Concurrent license assignment race | Exactly one succeeds |integration | `tests/integration/enterprise/test_license_concurrency.py` |
| Expired subscription assignment | Request fails, existing licenses active | integration | `tests/integration/enterprise/test_expired_subscription.py` |
| Batch assignment partial failure | All-or-nothing rollback| integration | `tests/integration/enterprise/test_batch_assignment_failure.py` |
| Double subsidy redemption | Idempotent, no double deduction| integration | `tests/integration/enterprise/test_subsidy_double_redemption.py` |
| Concurrent subsidy redemption | Serialized, only fitting committed | integration | `tests/integration/enterprise/test_subsidy_concurrency.py` |
| SAML IdP metadata refresh failure | Continue using cached metadata | integration | `tests/integration/enterprise/test_saml_metadata_refresh_failure.py` |
| SAML assertion missing email | Rejected, log missing attributes | integration | `tests/integration/enterprise/test_saml_missing_attributes.py` |
| Discovery service unavailable | Retry, log error, alert, preserve state | integration | `tests/integration/enterprise/test_catalog_sync_discovery_down.py` |
| External API rate limiting (HTTP 429) | Respect Retry-After, reschedule | integration | `tests/integration/enterprise/test_channel_rate_limiting.py` |
| Channel credential rotation | Auth failure, clear log, fixon next cycle | integration | `tests/integration/enterprise/test_channel_credential_rotation.py` |
| DSC revocation mid-sync | Excluded from payload | integration | `tests/integration/enterprise/test_dsc_revocation_mid_sync.py` |
| Invalid SAML signature | Rejected | integration | `tests/integration/enterprise/test_saml_signature_validation.py` |
| Expired SAML assertion | Rejected (replay prevention) | integration | `tests/integration/enterprise/test_saml_replay_prevention.py` |
| Cross-tenant data access | HTTP 403 | integration | `tests/integration/enterprise/test_tenant_isolation.py` |
| Unauthenticated API request | HTTP 401 | integration | `tests/integration/enterprise/test_jwt_enforcement.py` |
| Wrong role for endpoint | HTTP 403 | integration | `tests/integration/enterprise/test_rbac_enforcement.py` |
| API rate limit exceeded | HTTP 429 | integration | `tests/integration/enterprise/test_rate_limiting.py` |

---

## Performance Test Targets (from NFRs)

| Metric | Target | Test |
|--------|--------|------|
| Catalog content metadata API (paginated) | p95 <= 300ms | `test_catalog_list_latency.py` |
| Catalog contains_content_items API | p95 <= 100ms | `test_catalog_contains_latency.py` |
| License batch assignment (500 emails) | p95 <= 5s | `test_license_batch_latency.py` |
| License single lookup | p95 <= 200ms | `test_license_lookup_latency.py` |
| Enterprise access can-redeem API | p95 <= 500ms | `test_access_can_redeem_latency.py` |
| Subsidy transaction creation | p95 <= 1s | `test_subsidy_transaction_latency.py` |
| SAML SSO login round-trip | p95 <= 5s | `test_saml_login_latency.py` |
| Admin portal initial page load | p95 <= 3s | `test_admin_portal_load_time.py` |
| Channel sync (10k learners) | <= 30 minutes | `test_channel_sync_large_scale.py` |

---

## CI/CD Integration

### Pre-merge (Pull Request)
- Run unit tests: `pytest tests/unit/enterprise/`
- Run integration tests: `pytest tests/integration/enterprise/`
- Run linting: `ruff check`, `shellcheck scripts/`
- Coverage report: >80% required for merge

### Post-merge (Main Branch)
- Run E2E tests: `pytest tests/e2e/enterprise/`
- Run verification scripts: `./scripts/infra/verify-enterprise-deployment.sh --env=dev`

### Pre-release (Release Branch)
- Run load tests: `pytest tests/load/enterprise/` (staging cluster)
- Run performance tests: verify all NFR targets met
- Run security tests: RBAC, tenant isolation, SAML validation

### Post-deployment (Production)
- Run verification scripts: `./scripts/infra/verify-enterprise-deployment.sh --env=prod`
- Run onboarding verification: `./scripts/infra/verify-enterprise-onboarding.sh --customer={uuid}`
- Verify observability: check metrics in Grafana, verify no alerts firing
- Monitor availability: target 99.9% uptime

---

## Test Environment Setup

### Local Development (Kind Cluster)
- Kind cluster with LMS, Redis, MySQL, all enterprise services
- Mock discovery service
- Mock SAML IdP (test Keycloak instance)
- Mock channel APIs
- Seed test enterprise customers and data

### CI Environment (GitHub Actions)
- Kind cluster provisioned per workflow run
- Ephemeral test databases
- Mock external services
- Test secrets from GitHub Secrets

### Staging Environment (GKE)
- Full production-like cluster
- Separate test database
- Test SAML IdP (sandbox Okta or Keycloak)
- Test channel integrations (sandbox accounts)
- Load testing with realistic data volumes

---

## Success Criteria

- [ ] All 36 acceptance criteria have at least one passing test case
- [ ] All 18 edge cases have negative test coverage
- [ ] Unit test coverage >80% for enterprise service code
- [ ] Integration tests cover all cross-service interactions
- [ ] E2E tests cover full enterprise onboarding, license lifecycle, subsidy exhaustion
- [ ] Performance tests meet all NFR targets (catalog <300ms,license batch <5s, etc.)
- [ ] Reliability tests verify atomicity, eventual consistency, retry logic
- [ ] Security tests verify JWT enforcement, RBAC, tenant isolation, SAML validation
- [ ] All verification scripts pass in CI and production
- [ ] Observability tests confirm metrics, logs, alerts functioning
- [ ] No sensitive data (SAML assertions, raw emails, passwords) found in logs

---

## Test Ownership

- **Unit Tests**: Backend engineers implementing each service
- **Integration Tests**: Backend engineers + QA engineers
- **E2E Tests**: QA engineers + Product team (user acceptance)
- **Load Tests**: DevOps/SRE engineers
- **Security Tests**: Security engineers
- **Verification Scripts**: DevOps engineers
- **Observability Tests**: SRE engineers

---

## Rollback Test Cases

| Rollback Scenario | Test Case | Type | File |
|-------------------|-----------|------|------|
| Disable enterprise catalog service | Set feature flag false, verify fallback to LMS discovery | integration | `tests/integration/enterprise/test_rollback_catalog.py` |
| Scale enterprise service to 0 replicas | LMS continues operating, enterprise features unavailable | integration | `tests/integration/enterprise/test_rollback_scale_zero.py` |
| Restore enterprise service database from backup | Service reconnects, data consistent | manual | Runbook procedure | Production backup/restore |
| Disable SAML for specific enterprise customer | Customer falls back to standard LMS login | integration | `tests/integration/enterprise/test_rollback_saml.py` |

---

## Open Questions for Testing

1. **Mock IdP choice**: Use Keycloak (full-featured, heavy) or custom mock server (lightweight, faster) for SAML integration tests?
2. **Load test scale**: What is realistic concurrent user volume for sizing load tests (50? 100? 500 concurrent users)?
3. **Test data refresh**: How often to reset test enterprisecustomers and data in staging (daily? weekly?)?
4. **Performance test duration**: How long to run load testsfor stable p95 measurements (1 min? 5 min? 10 min?)?
5. **Security test scope**: Do we need full OWASP ASVS validation or focus on enterprise-specific controls (RBAC, tenant isolation)?
6. **Channel API sandboxes**: Do Degreed and Cornerstone provide sandbox accounts for testing, or do we mock entirely?
7. **Test SAML keys**: Generate fresh keys per test run or use static test keys committed to repo?

---

**Source Spec**: `specs/enterprise-microservices_spec.md`
