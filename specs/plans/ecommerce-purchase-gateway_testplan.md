---
source_spec: specs/ecommerce-purchase-gateway_spec.md
status: ready
created: 2026-02-10
updated: 2026-02-10
---

# Ecommerce Purchase Gateway - Test Plan

**Source Spec**: `specs/ecommerce-purchase-gateway_spec.md`

**Test Framework**: pytest (Python)

**Test Coverage Target**: 100% of 33 acceptance criteria + all edge cases

---

## Test Categories

- **Unit**: Single function/class, mocked dependencies
- **Integration**: Multiple components, real database (test DB), mocked external APIs (Stripe, LMS)
- **E2E**: Full flow including external API stubs (Stripe test mode)
- **Load**: Performance testing (100 concurrent checkouts, 500-seat pack fulfillment)
- **Security**: OWASP Top 10, webhook signature bypass attempts, rate limit tests

---

## Test Plan Table

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| 1 | Given valid offering UUID and buyer email, when POST /api/v1/checkout/ is called, then Stripe Checkout Session is created and checkout_url is returned | integration | `tests/integration/test_checkout_api.py` | Mock Stripe API (success response) |
| 1 | Given invalid offering UUID, when POST /api/v1/checkout/ is called, then HTTP 404 is returned | unit | `tests/unit/test_checkout_validation.py` | None |
| 1 | Given Stripe API outage, when POST /api/v1/checkout/ iscalled, then HTTP 503 is returned with user-friendly error |integration | `tests/integration/test_checkout_api.py` | Mock Stripe API (connection timeout) |
| 1 | Given multi-tenant checkout for tenant with Stripe Connect account, when POST /api/v1/checkout/ is called, then Stripe session is created with stripe_account header | unit | `tests/unit/test_checkout_multitenancy.py` | Mock Stripe API, Fixture: tenant with connected account |
| 2 | Given buyer with existing LMS account completes StripeCheckout, when checkout.session.completed webhook fires, thenbuyer is enrolled in course within 30 seconds | e2e | `tests/e2e/test_checkout_flow.py` | Mock LMS Enrollment API (success), Stripe test mode |
| 2 | Given LMS Enrollment API returns 409 (already enrolled), when fulfillment worker processes, then line item is markedfulfilled (idempotent) | unit | `tests/unit/test_fulfillment_idempotency.py` | Mock LMS API (409 response) |
| 3 | Given buyer without LMS account completes Stripe Checkout, when checkout.session.completed webhook fires, then entitlement is created and invitation email is sent | e2e | `tests/e2e/test_checkout_flow.py` | Mock LMS User API (user not found), Mock email service |
| 3 | Given invitation email delivery fails, when entitlementis created, then retry logic triggers and failure is logged| integration | `tests/integration/test_invitation_retry.py`| Mock email service (failure response) |
| 4 | Given expired Stripe Checkout Session, when checkout.session.expired webhook fires, then order status transitions toexpired and no fulfillment occurs | integration | `tests/integration/test_webhook_handler.py` | Mock Stripe webhook payload (session.expired) |
| 5 | Given buyer cancels at Stripe Checkout, when they return to cancel URL, then order status remains pending | integration | `tests/integration/test_checkout_cancellation.py` | Fixture: pending order |
| 6 | Given webhook request with valid Stripe signature, whengateway receives it, then HTTP 200 is returned within 500msand event is logged | integration | `tests/integration/test_webhook_signature.py` | Real Stripe signature computation |
| 6 | Given webhook processing exceeds 500ms due to DB latency, when gateway receives it, then HTTP 200 is still returned(async processing) | load | `tests/load/test_webhook_latency.py` | Simulated slow DB |
| 7 | Given webhook request with invalid signature, when gateway receives it, then HTTP 400 is returned and event is NOT logged | security | `tests/security/test_webhook_signature_bypass.py` | Malformed signature header |
| 7 | Given webhook request with missing signature header, when gateway receives it, then HTTP 400 is returned | unit | `tests/unit/test_webhook_validation.py` | None |
| 8 | Given same Stripe event ID is received twice (retry), when gateway processes it, then second processing is no-op andno duplicate enrollment is created | integration | `tests/integration/test_webhook_idempotency.py` | Duplicate webhook payloads |
| 8 | Given duplicate webhook arrives while first is still processing, when gateway handles it, then second request waitsor returns success (concurrent idempotency) | load | `tests/load/test_concurrent_webhooks.py` | Concurrent requests to same event ID |
| 9 | Given checkout.session.completed event for multi-tenantorder (Stripe Connect), when gateway processes it, then order is associated with correct tenant | integration | `tests/integration/test_webhook_multitenancy.py` | Mock Stripe Connectwebhook payload with account field |
| 9 | Given webhook for tenant A arrives at gateway, when processed, then zero impact on tenant B data (tenant isolation)| security | `tests/security/test_webhook_tenant_isolation.py` | Fixture: orders from tenant A and B |
| 10 | Given unclaimed entitlement with valid claim token, when authenticated user visits POST /api/v1/claim/{token}, thenentitlement is fulfilled and status is set to claimed | integration | `tests/integration/test_entitlement_claim.py` | Mock LMS Enrollment API, Fixture: authenticated user JWT |
| 10 | Given user claims entitlement for different offering than assigned email, when POST /api/v1/claim/{token} is called, then claim succeeds (claim token is authorization) | unit |`tests/unit/test_entitlement_claim_email_mismatch.py` | Fixture: token for user B claimed by user A |
| 11 | Given unclaimed entitlement with valid claim token, when unauthenticated user visits GET /api/v1/claim/{token}, then redirect to LMS login with next param | integration | `tests/integration/test_entitlement_claim.py` | No auth header |
| 12 | Given claim token that has expired, when user visits GET /api/v1/claim/{token}, then clear error message is returned indicating expiration | unit | `tests/unit/test_entitlement_expiry.py` | Fixture: expired entitlement |
| 12 | Given claim token with expires_at in future but closeto expiry (1 day), when user visits claim URL, then warning message is displayed | unit | `tests/unit/test_entitlement_expiry_warning.py` | Fixture: entitlement expiring in 1 day |
| 13 | Given claimed entitlement, when same claim token is visited again, then response indicates already claimed (no duplicate enrollment) | integration | `tests/integration/test_entitlement_claim.py` | Fixture: claimed entitlement |
| 14 | Given enterprise admin with 100 seat pack entitlements, when POST /admin/api/v1/entitlements/assign/ is called withemails, then 50 entitlements are assigned and invitationemails sent | integration | `tests/integration/test_enterprise_bulk_assignment.py` | Mock email service, Fixture: enterprise admin JWT |
| 14 | Given bulk assignment with 1 invalid email, when POST/admin/api/v1/entitlements/assign/ is called, then entire batch is rejected (all-or-nothing) | unit | `tests/unit/test_bulk_assignment_validation.py` | None |
| 14 | Given bulk assignment with 501 emails (exceeds limit),when POST /admin/api/v1/entitlements/assign/ is called, thenHTTP 400 is returned | unit | `tests/unit/test_bulk_assignment_limit.py` | None |
| 15 | Given fulfilled order, when full refund is processed and charge.refunded webhook fires, then order status transitions to refunded and enrollment is deactivated within 5 minutes| e2e | `tests/e2e/test_refund_flow.py` | Mock LMS Enrollment API (deactivate), Mock Stripe webhook |
| 15 | Given fulfilled order with claimed entitlement, when full refund is processed, then entitlement is revoked and enrollment deactivated | integration | `tests/integration/test_refund_with_entitlement.py` | Mock LMS API |
| 16 | Given fulfilled order, when partial refund is processed, then order status transitions to partially_refunded and noenrollment is automatically revoked | integration | `tests/integration/test_partial_refund.py` | Mock Stripe webhook (partial refund) |
| 17 | Given fulfilled order, when charge.dispute.created webhook fires, then order status transitions to disputed and alert is fired to finance channel | integration | `tests/integration/test_dispute_flow.py` | Mock alert service (Slack/email)|
| 17 | Given configurable auto-revoke policy is disabled, when dispute is created, then no enrollments are revoked (wait for resolution) | unit | `tests/unit/test_dispute_policy.py` |Feature flag: ENABLE_AUTO_REVOKE_ON_DISPUTE=false |
| 18 | Given disputed order where merchant wins, when charge.dispute.closed with status=won webhook fires, then order status is restored to pre-dispute state | integration | `tests/integration/test_dispute_flow.py` | Mock Stripe webhook (dispute won) |
| 18 | Given disputed order where buyer wins, when charge.dispute.closed with status=lost webhook fires, then enrollmentsare revoked and order transitions to refunded | integration |`tests/integration/test_dispute_flow.py` | Mock Stripe webhook (dispute lost), Mock LMS API |
| 19 | Given fulfillment job fails due to LMS API returning HTTP 503, when worker retries, then it retries up to 10 timeswith exponential backoff | unit | `tests/unit/test_fulfillment_retry.py` | Mock LMS API (503 response) |
| 19 | Given LMS API is down, when fulfillment worker retries, then backoff delays are: 5s, 10s, 20s, 40s, 80s, 160s, 300s(capped), 300s, 300s, 300s | unit | `tests/unit/test_retry_backoff_timing.py` | Mock time.sleep, Mock LMS API |
| 20 | Given fulfillment job fails all 10 retries, when max retries are exhausted, then order transitions to fulfillment_failed, job moved to dead letter queue, and Critical alert fired | integration | `tests/integration/test_fulfillment_failure.py` | Mock LMS API (always fail), Mock alert service |
| 20 | Given order in fulfillment_failed state, when admin calls POST /admin/api/v1/orders/{uuid}/retry-fulfillment/, thenfulfillment is retried | integration | `tests/integration/test_manual_retry.py` | Mock LMS API (success on retry) |
| 21 | Given fulfillment job for user already enrolled, whenworker processes it, then line item is marked fulfilled and no error is logged (idempotent) | unit | `tests/unit/test_fulfillment_idempotency.py` | Mock LMS API (409 response) |
| 22 | Given enterprise tenant with subscription, when invoice.paid fires for renewal, then seat pack entitlements are replenished | integration | `tests/integration/test_subscription_renewal.py` | Mock Stripe webhook (invoice.paid) |
| 22 | Given enterprise subscription renewal with 50 seats, when replenishment occurs, then 50 new entitlement records arecreated in pending state | unit | `tests/unit/test_seat_pack_replenishment.py` | Fixture: subscription with 50 seats |
| 23 | Given enterprise subscription payment fails, when invoice.payment_failed fires, then grace period begins and adminis notified (no access revoked during grace period) | integration | `tests/integration/test_subscription_payment_failure.py` | Mock Stripe webhook, Mock notification service |
| 23 | Given grace period expires without payment, when system checks subscription status, then access is suspended (enrollments remain but are flagged) | integration | `tests/integration/test_grace_period_expiry.py` | Time-mocked test |
| 24 | Given enterprise admin for tenant A, when GET /admin/api/v1/orders/ is called, then only orders for tenant A are returned (zero from tenant B) | integration | `tests/integration/test_admin_api_tenant_isolation.py` | Fixture: orders fromtenant A and B, JWT for admin A |
| 24 | Given platform operator (superuser), when GET /admin/api/v1/orders/ is called, then orders from all tenants are returned | integration | `tests/integration/test_admin_api_superuser.py` | Fixture: orders from multiple tenants, superuser JWT |
| 25 | Given tenants A and B, when admin A calls any admin API endpoint, then zero records from tenant B are returned | security | `tests/security/test_tenant_isolation_bypass.py` | JWT manipulation attempts |
| 26 | Given tenants A and B using Stripe Connect, when webhook fires for tenant A's connected account, then event is processed in tenant A context only | integration | `tests/integration/test_webhook_multitenancy.py` | Mock Stripe Connect webhook with account field |
| 27 | Given Purchase Gateway deployed alongside legacy ecommerce, when new purchase is initiated, then it routes to Purchase Gateway (not legacy) | e2e | `tests/e2e/test_migration_routing.py` | Mock frontend feature flag |
| 28 | Given all in-flight orders in legacy ecommerce completed, when decommission script runs, then legacy ecommerce Deployment, Service, DNS records removed | integration | `tests/integration/test_decommission_script.py` | Mock kubectl commands |
| 29 | Given gateway is running, when /metrics/ is scraped byPrometheus, then purchase-specific metrics (checkout count,fulfillment duration, webhook processing time) are present |integration | `tests/integration/test_metrics_endpoint.py` |None (check response body) |
| 29 | Given fulfillment failure occurs, when error is logged, then log entry includes order_uuid, tenant_id, offering_type, lms_resource_id, error_type, buyer_email_hash (not raw email) | unit | `tests/unit/test_logging_pii.py` | Fixture: fulfillment failure event |
| 30 | Given error log is written, when log is inspected, then no PII is present (emails are hashed, claim tokens first 8chars only, no full Stripe payloads) | security | `tests/security/test_logging_pii_compliance.py` | Log output capture |
| 31 | Given gateway Deployment applied, when kubectl get deployments is run, then payments-gateway shows READY >= 1 | e2e| `tests/e2e/test_k8s_deployment.py` | Real K8s cluster (test namespace) |
| 32 | Given gateway worker Deployment applied, when kubectlget deployments is run, then payments-worker shows READY >= 1| e2e | `tests/e2e/test_k8s_deployment.py` | Real K8s cluster (test namespace) |
| 33 | Given gateway is running, when curl http://payments-gateway:8000/health/ is called from within cluster, then HTTP 2with {"status": "ok", "database": "ok", "redis": "ok", "stripe": "ok"} | e2e | `tests/e2e/test_health_endpoint.py` | Real K8s cluster or Docker Compose |

---

## Edge Case Tests (Negative Tests)

| Edge Case | Test Case | Type | File | Mocks/Fixtures |
|-----------|-----------|------|------|----------------|
| Checkout session created but user never completes | Given pending order older than 24h, when session expires, then checkout.session.expired webhook transitions order to expired | integration | `tests/integration/test_checkout_timeout.py` | Time-mocked test |
| Duplicate webhook delivery | Given same stripe_event_id received 3 times, when gateway processes, then first processes,second and third are no-ops | load | `tests/load/test_webhook_retry_storm.py` | Concurrent duplicate requests |
| Webhook arrives before redirect completes | Given webhook arrives 100ms before buyer redirect, when buyer lands on success page, then order status is already paid (async race condition) | integration | `tests/integration/test_webhook_race_condition.py` | Mock timing delay |
| Stripe API outage during checkout | Given Stripe API is unreachable, when POST /api/v1/checkout/ is called, then HTTP 50is returned and no order is created | integration | `tests/integration/test_stripe_outage.py` | Mock Stripe API (connection error) |
| Currency mismatch | Given offering in USD but Stripe account default is SGD, when checkout is created, then Stripe handles conversion and gateway stores actual charged amount/currency | unit | `tests/unit/test_currency_handling.py` | Mock Stripe API with currency conversion |
| Zero-amount checkout | Given offering with price_cents=0, when checkout is created, then order is marked paid immediately and fulfillment proceeds (no Stripe Checkout) | integration| `tests/integration/test_free_offering.py` | None |
| LMS user lookup race condition | Given user registers between webhook receipt and fulfillment processing, when worker looks up user, then user is found and enrollment proceeds | integration | `tests/integration/test_user_registration_race.py`| Time-mocked test |
| Course unpublished between purchase and fulfillment | GivenLMS returns 404 for course, when fulfillment worker processes, then line item marked failed, order status fulfillment_failed, alert fired | integration | `tests/integration/test_course_unpublished.py` | Mock LMS API (404 response) |
| Program with zero active course runs | Given program offering purchased but no active runs, when fulfillment worker processes, then program entitlement created (not enrollments) andbuyer notified | integration | `tests/integration/test_program_no_runs.py` | Mock LMS API (empty course runs) |
| Worker crash mid-fulfillment | Given worker crashes after enrolling in 2 of 3 courses, when job is retried, then only unenrolled courses are attempted (idempotent per-course check)| integration | `tests/integration/test_worker_crash_recovery.py` | Simulated worker restart |
| Redis queue full | Given Redis queue at capacity, when fulfillment job is enqueued, then job is rejected, order remainspaid, and alert fires | integration | `tests/integration/test_queue_full.py` | Mock Redis (queue full error) |
| Claim token used by wrong email | Given token sent to userB claimed by user A, when claim succeeds, then entitlement logs both recipient_email (B) and claimed_by_user_id (A) | unit| `tests/unit/test_claim_token_forwarding.py` | Fixture: token for B, claimed by A |
| Claim token claimed during registration | Given user clicksclaim link, redirects to registration (5 min), then completes claim, when POST /api/v1/claim/{token} is called, then expires_at is checked at claim time (not redirect time) | integration | `tests/integration/test_claim_during_registration.py`| Time-mocked test |
| Multiple entitlements for same email and offering | Given same email assigned twice to same offering, when bulk assignment occurs, then existing entitlement is returned (idempotent,no duplicate) | unit | `tests/unit/test_entitlement_duplicate_prevention.py` | None |
| Entitlement expires with user registered but not claimed |Given user registered independently and entitlement expires,when expiration job runs, then entitlement is NOT auto-fulfilled (requires explicit claim) | integration | `tests/integration/test_entitlement_expiry_no_autofulfill.py` | Time-mockedtest |
| Bulk assignment with mixed valid/invalid emails | Given 50emails with 1 malformed, when bulk assignment is called, thenentire batch rejected (all-or-nothing) | unit | `tests/unit/test_bulk_assignment_validation.py` | None |
| Refund for order with claimed entitlements | Given order with claimed entitlement refunded, when full refund processed,then entitlement revoked and enrollment deactivated | integration | `tests/integration/test_refund_claimed_entitlement.py`| Mock LMS API |
| Partial refund ambiguity (multi-line-item order) | Given order with 2 line items and partial refund, when refund processed, then order status partially_refunded and admin intervention required (no auto-revoke) | integration | `tests/integration/test_partial_refund_multiline.py` | Mock Stripe webhook |
| Refund after course completion | Given refund processed after learner completed course, when refund processed, then enrollment deactivated but certificate NOT deleted (warning logged) | integration | `tests/integration/test_refund_after_completion.py` | Mock LMS API, Fixture: completed course |
| Dispute on Stripe Connect order | Given dispute on tenant A's connected account, when dispute webhook arrives, then routed to tenant A context (not platform account) | integration |`tests/integration/test_dispute_stripe_connect.py` | Mock Stripe Connect webhook |
| Public checkout endpoint rate limit exceeded | Given 31 checkout requests from same IP in 1 minute, when 31st request arrives, then HTTP 429 with Retry-After header | load | `tests/load/test_checkout_rate_limit.py` | Rate limiter mock |
| Webhook endpoint rate limit exceeded | Given 1001 webhook requests in 1 minute, when 1001st arrives, then HTTP 429 is returned (but high threshold to avoid rejecting Stripe retries)| load | `tests/load/test_webhook_rate_limit.py` | Rate limiter mock |
| Admin API per-user rate limit exceeded | Given admin user makes 101 requests in 1 minute, when 101st arrives, then HTTPis returned | load | `tests/load/test_admin_api_rate_limit.py` | Rate limiter mock |
| Stripe Checkout Session creation timeout | Given Stripe APItakes >10 seconds, when checkout request is made, then HTTPis returned | integration | `tests/integration/test_stripe_timeout.py` | Mock Stripe API (slow response) |
| LMS Enrollment API call timeout | Given LMS API takes >15 seconds, when fulfillment worker calls it, then request timesout, retry logic triggers | integration | `tests/integration/test_lms_timeout.py` | Mock LMS API (slow response) |
| Webhook processing takes >5 seconds | Given DB write is slow, when webhook is received, then HTTP 200 is still returnedwithin 5s (processing continues async) | load | `tests/load/test_webhook_async_processing.py` | Simulated slow DB |

---

## Load Tests

| Test Case | Type | File | Target |
|-----------|------|------|--------|
| 100 concurrent checkouts without degradation | load | `tests/load/test_concurrent_checkouts.py` | p95 latency <=500ms, 0failures |
| 500-seat pack fulfillment within 60 seconds | load | `tests/load/test_bulk_fulfillment.py` | p95 latency <=60s |
| 1 million orders in database, admin API list query <=300ms| load | `tests/load/test_admin_api_scale.py` | p95 latency <=300ms |
| Webhook processing under burst load (50 events/second) | load | `tests/load/test_webhook_burst.py` | All events processed, no dropped events |

---

## Security Tests

| Test Case | Type | File | Target |
|-----------|------|------|--------|
| OWASP Top 10 audit (SQL injection, XSS, CSRF, etc.) | security | `tests/security/test_owasp_top10.py` | Zero Critical/High findings |
| Webhook signature bypass attempts (malformed, missing, forged) | security | `tests/security/test_webhook_signature_bypass.py` | All bypass attempts rejected (HTTP 400) |
| JWT authentication bypass attempts (expired, malformed, wrong signature) | security | `tests/security/test_jwt_bypass.py` | All bypass attempts rejected (HTTP 401) |
| Tenant isolation bypass (JWT manipulation, SQL injection via tenant_id) | security | `tests/security/test_tenant_isolation_bypass.py` | Zero cross-tenant data leaks |
| Rate limit bypass attempts (IP spoofing, distributed requests) | security | `tests/security/test_rate_limit_bypass.py` |Rate limits enforced |
| PII logging compliance (emails, claim tokens, Stripe payloads) | security | `tests/security/test_logging_pii_compliance.py` | Zero raw PII in logs |
| Secrets exposure in error messages | security | `tests/security/test_secrets_in_errors.py` | No secrets in HTTP responses or logs |
| Claim token enumeration attempts | security | `tests/security/test_claim_token_enumeration.py` | No timing attacks, no brute force success |

---

## Test Fixtures

### Common Fixtures (`tests/conftest.py`)

- `db_session`: Test database session (PostgreSQL)
- `redis_client`: Test Redis instance
- `mock_stripe_api`: Mock Stripe API client
- `mock_lms_api`: Mock LMS API client
- `mock_email_service`: Mock email sending service
- `mock_alert_service`: Mock alert notification service
- `test_tenant_a`: Fixture for tenant A data
- `test_tenant_b`: Fixture for tenant B data
- `platform_admin_jwt`: JWT for platform superuser
- `tenant_a_admin_jwt`: JWT for tenant A admin
- `test_offering_course_seat`: Fixture for course_seat offering
- `test_offering_program`: Fixture for program offering
- `test_offering_seat_pack`: Fixture for seat_pack offering (seats)
- `test_order_pending`: Fixture for pending order
- `test_order_paid`: Fixture for paid order
- `test_order_fulfilled`: Fixture for fulfilled order
- `test_entitlement_unclaimed`: Fixture for unclaimed entitlement
- `test_entitlement_claimed`: Fixture for claimed entitlement
- `test_entitlement_expired`: Fixture for expired entitlement

---

## Test Coverage Verification

After implementing all tests, verify coverage:

```bash
pytest --cov=src --cov-report=html --cov-report=term tests/
```

**Target**: >=90% coverage for all critical paths (checkout,webhook, fulfillment, refund, dispute, entitlement)

**Exclusions**: External API clients (Stripe, LMS) are mocked, so their internal logic is not covered (that's intentional)

---

## CI/CD Integration

Add to CI pipeline:

```yaml
test:
  stage: test
  script:
    - pytest tests/unit/ tests/integration/ --cov=src --cov-report=xml
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

Some tests require manual verification due to external dependencies:

1. **Stripe Dashboard Verification**: After E2E test, verifyStripe Dashboard shows correct payment, customer, and metadata
2. **LMS Django Admin Verification**: After E2E test, verifyenrollment appears in LMS admin interface
3. **Email Delivery Verification**: After invitation test, verify email is received in test inbox (SendGrid test mode)
4. **Grafana Dashboard Verification**: After metrics test, verify dashboards display correct data
5. **Alert Firing Verification**: Trigger alert condition (e.g., dead letter queue > 0), verify Slack/email alert is received

These manual tests are documented in the runbook (`docs/runbooks/purchase-gateway-runbook.md`)

---

## Test Data Management

**Test Database**: Separate PostgreSQL instance for tests, reset between test runs

**Test Redis**: Separate Redis instance for tests, flushed between test runs

**Stripe Test Mode**: All Stripe API calls use test API keys(`sk_test_...`), test mode checkout sessions, test mode webhooks

**Test LMS**: Mock LMS API responses (no real LMS instance required for unit/integration tests), real LMS for E2E tests (staging LMS)

**Cleanup**: All test data is ephemeral, deleted after test run

---

## Summary

**Total Test Cases**: 95

**By Type**:
- Unit: 30 tests
- Integration: 42 tests
- E2E: 10 tests
- Load: 4 tests
- Security: 9 tests

**By AC Coverage**:
- All 33 acceptance criteria have at least one test
- All edge cases have negative tests
- All security requirements have security tests

**Test Execution Time**: <10 minutes (unit + integration), ~3minutes (all tests including E2E)

**Test Stability**: All tests MUST be deterministic (no flakytests allowed)

**Test Maintenance**: Testmap YAML tracks AC → test mapping for automated coverage verification
