---
spec: ecommerce-purchase-gateway_spec.md
tier: 5
status: draft
estimated_effort: "16-20 weeks (2 senior engineers)"
prerequisites:
  - "Tier 4 complete (multi-tenancy-architecture, auth-sso-enterprise, enterprise-microservices)"
  - "Observability stack operational (Tier 2)"
  - "K8s deployment base established (Tier 1)"
  - "Secrets management pipeline operational (Tier 0)"
last_updated: "2026-02-10"
---

# Implementation Plan: Ecommerce Purchase Gateway

**Source Spec**: `specs/ecommerce-purchase-gateway_spec.md`

## Summary

This plan covers the full implementation of a standalone Purchase Gateway service that replaces the deprecated Open edX Oscar/ecommerce service. The gateway is a FastAPI + PostgreSQL + Redis service deployed as two K8s Deployments (API server + async fulfillment worker) in the `mereka-lms` namespace.

The implementation is structured in 7 milestones matching the spec's rollout phases, with 60+ individual tasks grouped into Build, Test, Observability, Docs, and Rollout categories.

## Prerequisites

Before starting implementation, the following MUST be in place:

1. **Tier 4 complete**: `EnterpriseCustomer` model exists, OAuth2/JWT auth works, enterprise microservices are deployed
2. **Cloud SQL PostgreSQL instance** provisioned (or decision made on in-cluster PostgreSQL) -- see Open Question #1 in spec
3. **Stripe account** operational with test/live keys available in Infisical
4. **Redis** available in cluster with capacity for an additional queue namespace
5. **Artifact Registry** accessible for pushing gateway Docker images
6. **LMS OAuth2 application** registered for `payments-gateway` client

## Decisions Required Before Implementation

These map to the spec's Open Questions. Each MUST be resolved before starting the dependent task:

| # | Decision | Blocks | Default if Unresolved |
|---|----------|--------|-----------------------|
| OQ-1 | PostgreSQL: Cloud SQL vs in-cluster | Task 1.1 | Cloud SQL (spec prefers) |
| OQ-2 | Tech stack (confirmed FastAPI per IMPLEMENTATION_ORDER.md) | Task 2.1 | FastAPI (confirmed) |
| OQ-3 | Claim URL hosted on gateway vs LMS | Task 4.1 | Gateway with redirect chain |
| OQ-7 | Email delivery service | Task 4.3 | LMS email pipeline |
| OQ-10 | Free offering checkout bypass | Task 3.2 | Skip Stripe for price=0 |

---

## Task Breakdown

### Milestone 1: Project Scaffolding and Database (Week 1-2)

#### Build

- [ ] **[M]** 1.1 — Scaffold `services/purchase-gateway/` project structure: `api/`, `worker/`, `migrations/`, `tests/`, `pyproject.toml`, `Dockerfile` (`services/purchase-gateway/`) | AC: all | Depends: None
- [ ] **[M]** 1.2 — Configure FastAPI application skeleton with Uvicorn, Pydantic settings, structured logging (`services/purchase-gateway/api/main.py`, `api/config.py`, `api/logging.py`) | AC: AC-033 | Depends: 1.1
- [ ] **[L]** 1.3 — Define SQLAlchemy models for all 10 tables: `tenants`, `offerings`, `orders`, `line_items`, `fulfillments`, `entitlements`, `stripe_events`, `order_audit_log`, `subscriptions` (`services/purchase-gateway/api/models/`) | AC: all DB-dependent ACs | Depends: 1.1
- [ ] **[M]** 1.4 — Create Alembic migration infrastructure and initial migration for all tables with indexes on `tenant_id`, `buyer_email`, `stripe_checkout_session_id`, `stripe_payment_intent_id`, `stripe_event_id`, `status`, `created_at` (`services/purchase-gateway/migrations/`) | AC: all DB-dependent ACs | Depends: 1.3
- [ ] **[S]** 1.5 — Add unique constraints on `stripe_events.stripe_event_id`, `entitlements.claim_token`, `orders.stripe_checkout_session_id` (`services/purchase-gateway/migrations/`) | AC: AC-008, AC-013 | Depends: 1.4
- [ ] **[S]** 1.6 — Implement tenant-scoped query mixin/middleware (all ORM queries filter by `tenant_id`) (`services/purchase-gateway/api/db/tenant.py`) | AC: AC-024, AC-025, AC-026 | Depends: 1.3
- [ ] **[M]** 1.7 — Implement health (`/health/`) and readiness (`/ready/`) endpoints checking DB, Redis, Stripe connectivity (`services/purchase-gateway/api/routes/health.py`) | AC: AC-033 | Depends: 1.2
- [ ] **[S]** 1.8 — Implement Prometheus metrics endpoint (`/metrics/`) with `prometheus_client` (`services/purchase-gateway/api/routes/metrics.py`) | AC: AC-029 | Depends: 1.2

#### Test

- [ ] **[M]** 1.9 — Set up pytest infrastructure: `conftest.py` with async test client, test database fixtures, factory functions (`services/purchase-gateway/tests/conftest.py`, `tests/factories.py`) | AC: all | Depends: 1.3
- [ ] **[S]** 1.10 — Unit tests for SQLAlchemy models (field validation, relationships, constraints) (`services/purchase-gateway/tests/test_models.py`) | AC: all | Depends: 1.3, 1.9

---

### Milestone 2: Offering Management and Checkout Flow (Week 3-4)

#### Build

- [ ] **[M]** 2.1 — Implement Offering CRUD admin endpoints: `GET/POST/PATCH/DELETE /admin/api/v1/offerings/` with Stripe Price validation (`services/purchase-gateway/api/routes/admin/offerings.py`) | AC: AC-001 | Depends: 1.3, 1.6
- [ ] **[L]** 2.2 — Implement checkout session creation endpoint `POST /api/v1/checkout/`: create pending Order, create Stripe Checkout Session with metadata, return `checkout_url` (`services/purchase-gateway/api/routes/checkout.py`) | AC: AC-001, AC-005 | Depends: 1.3, 2.1
- [ ] **[M]** 2.3 — Implement Stripe Customer create-or-reuse logic for `buyer_email` (`services/purchase-gateway/api/services/stripe_service.py`) | AC: AC-001 | Depends: 2.2
- [ ] **[S]** 2.4 — Implement checkout status endpoint `GET /api/v1/checkout/{session_id}/status/` (`services/purchase-gateway/api/routes/checkout.py`) | AC: AC-002 | Depends: 2.2
- [ ] **[S]** 2.5 — Implement Stripe Connect support: create Checkout Session on connected account using `stripe_account` header (`services/purchase-gateway/api/services/stripe_service.py`) | AC: AC-009 | Depends: 2.2
- [ ] **[S]** 2.6 — Implement Stripe promotional code support on Checkout Session (`services/purchase-gateway/api/routes/checkout.py`) | AC: AC-001 | Depends: 2.2
- [ ] **[S]** 2.7 — Implement zero-amount checkout bypass (skip Stripe, create order as `paid` directly for price_cents=0) (`services/purchase-gateway/api/routes/checkout.py`) | AC: AC-001 | Depends: 2.2
- [ ] **[M]** 2.8 — Implement rate limiting middleware: 30 req/min per IP on checkout, 1000 req/min on webhook, 100 req/min per user on admin (`services/purchase-gateway/api/middleware/rate_limit.py`) | AC: AC-006 | Depends: 1.2
- [ ] **[S]** 2.9 — Implement CORS middleware with configurable allowed origins (`services/purchase-gateway/api/middleware/cors.py`) | AC: none (security NFR) | Depends: 1.2
- [ ] **[S]** 2.10 — Implement input validation and sanitization for all public endpoints (`services/purchase-gateway/api/schemas/`) | AC: AC-001 | Depends: 2.2

#### Test

- [ ] **[M]** 2.11 — Unit tests for checkout session creation (valid offering, missing fields, invalid offering UUID, Stripe API error, Stripe timeout, zero-amount) (`services/purchase-gateway/tests/test_checkout.py`) | AC: AC-001, AC-005 | Depends: 2.2
- [ ] **[S]** 2.12 — Unit tests for rate limiting (exceed limit returns 429 with Retry-After header) (`services/purchase-gateway/tests/test_rate_limit.py`) | AC: AC-006 | Depends: 2.8
- [ ] **[S]** 2.13 — Unit tests for Stripe Connect checkout session creation (`services/purchase-gateway/tests/test_stripe_connect.py`) | AC: AC-009 | Depends: 2.5

---

### Milestone 3: Webhook Handling and Order Lifecycle (Week 5-6)

#### Build

- [ ] **[L]** 3.1 — Implement webhook endpoint `POST /webhooks/stripe/`: signature verification, event logging in `stripe_events`, async dispatch to Redis queue (`services/purchase-gateway/api/routes/webhooks.py`) | AC: AC-006, AC-007, AC-008 | Depends: 1.3
- [ ] **[L]** 3.2 — Implement order state machine with all transitions (pending -> paid -> fulfilling -> fulfilled/partially_fulfilled/fulfillment_failed, refunded, partially_refunded, disputed, expired, canceled) and audit log (`services/purchase-gateway/api/services/order_service.py`) | AC: AC-002, AC-004, AC-015, AC-016, AC-017, AC-018 | Depends: 1.3
- [ ] **[M]** 3.3 — Implement webhook event handlers for all 13 Stripe event types: checkout.session.completed/expired, payment_intent.succeeded/payment_failed, charge.refunded/refund.updated, charge.dispute.created/closed, customer.subscription.created/updated/deleted, invoice.paid/payment_failed (`services/purchase-gateway/api/services/webhook_handlers.py`) | AC: AC-002, AC-003, AC-004, AC-015, AC-016, AC-017, AC-018, AC-022, AC-023 | Depends: 3.1, 3.2
- [ ] **[S]** 3.4 — Implement idempotent webhook processing: check `stripe_events.stripe_event_id` existence before processing (`services/purchase-gateway/api/routes/webhooks.py`) | AC: AC-008 | Depends: 3.1
- [ ] **[S]** 3.5 — Implement multi-tenant webhook routing: use `account` field in event payload for Stripe Connect events (`services/purchase-gateway/api/services/webhook_handlers.py`) | AC: AC-009, AC-026 | Depends: 3.3

#### Test

- [ ] **[M]** 3.6 — Unit tests for webhook signature verification (valid signature, invalid signature, missing header) (`services/purchase-gateway/tests/test_webhooks.py`) | AC: AC-006, AC-007 | Depends: 3.1
- [ ] **[M]** 3.7 — Unit tests for idempotent webhook processing (duplicate event ID is no-op) (`services/purchase-gateway/tests/test_webhooks.py`) | AC: AC-008 | Depends: 3.4
- [ ] **[M]** 3.8 — Unit tests for order state machine (all valid transitions, reject invalid transitions) (`services/purchase-gateway/tests/test_order_lifecycle.py`) | AC: AC-002, AC-004, AC-015, AC-016, AC-017, AC-018 | Depends: 3.2
- [ ] **[S]** 3.9 — Unit tests for multi-tenant webhook routing (`services/purchase-gateway/tests/test_webhooks.py`) | AC: AC-009, AC-026 | Depends: 3.5

---

### Milestone 4: Fulfillment Engine and Entitlements (Week 7-9)

#### Build

- [ ] **[L]** 4.1 — Implement fulfillment worker with Redis queue consumer: job dequeue, LMS user lookup, enrollment creation, entitlement creation, retry with exponential backoff (5s base, 2x multiplier, 5min max, 10 retries), dead letter queue (`services/purchase-gateway/worker/fulfillment.py`, `worker/main.py`) | AC: AC-002, AC-003, AC-019, AC-020 | Depends: 3.2, 1.3
- [ ] **[M]** 4.2 — Implement Open edX LMS API client: OAuth2 token management (cache + refresh), enrollment creation/check, user lookup, enrollment deactivation with per-status-code error handling (400/401/403/404/409/429/5xx) (`services/purchase-gateway/api/services/lms_client.py`) | AC: AC-002, AC-019, AC-021 | Depends: 1.2
- [ ] **[M]** 4.3 — Implement entitlement and invitation flow: create Entitlement record, generate cryptographically random claim token (32+ chars, URL-safe), send invitation email via LMS email pipeline (`services/purchase-gateway/api/services/entitlement_service.py`) | AC: AC-003, AC-010, AC-011, AC-012, AC-013 | Depends: 1.3, 4.2
- [ ] **[M]** 4.4 — Implement claim endpoints: `GET /api/v1/claim/{token}` (validate + redirect) and `POST /api/v1/claim/{token}` (fulfill authenticated claim) (`services/purchase-gateway/api/routes/claims.py`) | AC: AC-010, AC-011, AC-012, AC-013 | Depends: 4.3
- [ ] **[S]** 4.5 — Implement idempotent enrollment creation: check existing enrollment via Enrollment API before creating, treat 409 as success (`services/purchase-gateway/worker/fulfillment.py`) | AC: AC-021 | Depends: 4.1, 4.2
- [ ] **[M]** 4.6 — Implement seat pack fulfillment: create N unassigned entitlements for seat_pack offerings (`services/purchase-gateway/worker/fulfillment.py`) | AC: AC-014, AC-022 | Depends: 4.1, 4.3
- [ ] **[M]** 4.7 — Implement program fulfillment: enroll user in all active course runs within a program, handle partial failure per-course (`services/purchase-gateway/worker/fulfillment.py`) | AC: AC-002 | Depends: 4.1, 4.2
- [ ] **[S]** 4.8 — Implement stuck-order recovery cron: scan for `paid` orders older than 5 minutes and re-enqueue fulfillment (`services/purchase-gateway/worker/recovery.py`) | AC: AC-019 | Depends: 4.1

#### Test

- [ ] **[L]** 4.9 — Integration tests for fulfillment worker: happy path (course_seat enrolled), user not found (entitlement created), LMS 503 (retry), LMS 409 (idempotent success), all retries exhausted (dead letter), worker crash mid-program (resume) (`services/purchase-gateway/tests/test_fulfillment.py`) | AC: AC-002, AC-003, AC-019, AC-020, AC-021 | Depends: 4.1
- [ ] **[M]** 4.10 — Integration tests for entitlement claim flow: authenticated claim (enrollment created), unauthenticated (redirect), expired token (error), already claimed (no-op), wrong email (allowed) (`services/purchase-gateway/tests/test_claims.py`) | AC: AC-010, AC-011, AC-012, AC-013 | Depends: 4.4
- [ ] **[M]** 4.11 — Integration tests for LMS API client: token refresh on 401, rate limit handling, timeout handling, all error codes (`services/purchase-gateway/tests/test_lms_client.py`) | AC: AC-019, AC-021 | Depends: 4.2
- [ ] **[S]** 4.12 — Unit tests for seat pack fulfillment and bulk assignment (`services/purchase-gateway/tests/test_seat_packs.py`) | AC: AC-014, AC-022 | Depends: 4.6

---

### Milestone 5: Refund, Dispute, and Enterprise Features (Week 10-11)

#### Build

- [ ] **[M]** 5.1 — Implement refund handling: identify order by `stripe_payment_intent_id`, full refund (revoke all enrollments), partial refund (log only, no auto-revoke) (`services/purchase-gateway/api/services/refund_service.py`) | AC: AC-015, AC-016 | Depends: 3.3, 4.2
- [ ] **[M]** 5.2 — Implement dispute handling: transition to `disputed`, alert fire, dispute resolution (won: restore, lost: revoke), configurable auto-revoke policy (`services/purchase-gateway/api/services/dispute_service.py`) | AC: AC-017, AC-018 | Depends: 3.3, 4.2
- [ ] **[M]** 5.3 — Implement enterprise subscription management: Stripe Subscription creation, renewal handling (replenish seat packs on `invoice.paid`), grace period on `invoice.payment_failed` (`services/purchase-gateway/api/services/subscription_service.py`) | AC: AC-022, AC-023 | Depends: 3.3, 4.6
- [ ] **[M]** 5.4 — Implement admin API: orders list/detail/retry-fulfillment/refund, entitlements list/assign/resend/revoke, tenant reports, stripe-events list (`services/purchase-gateway/api/routes/admin/`) | AC: AC-014, AC-024 | Depends: 1.3, 1.6
- [ ] **[M]** 5.5 — Implement JWT authentication middleware for admin API with role-based access control (`payments_admin`, `enterprise_admin`, superuser) (`services/purchase-gateway/api/middleware/auth.py`) | AC: AC-024, AC-025 | Depends: 1.2
- [ ] **[M]** 5.6 — Implement bulk entitlement assignment: validate all emails, all-or-nothing batch, up to 500 per request (`services/purchase-gateway/api/routes/admin/entitlements.py`) | AC: AC-014 | Depends: 4.3, 5.4
- [ ] **[S]** 5.7 — Implement tenant purchase reports: total revenue, order count, refund rate, seat utilization (`services/purchase-gateway/api/routes/admin/reports.py`) | AC: AC-024 | Depends: 5.4
- [ ] **[S]** 5.8 — Implement reconciliation job: compare gateway orders against Stripe payment records, flag discrepancies (`services/purchase-gateway/worker/reconciliation.py`) | AC: AC-029 | Depends: 4.2

#### Test

- [ ] **[M]** 5.9 — Integration tests for refund flow: full refund (enrollment deactivated), partial refund (no auto-revoke), refund after course completion (warning logged) (`services/purchase-gateway/tests/test_refunds.py`) | AC: AC-015, AC-016 | Depends: 5.1
- [ ] **[M]** 5.10 — Integration tests for dispute flow: dispute created (alert fired), dispute won (restored), dispute lost (revoked) (`services/purchase-gateway/tests/test_disputes.py`) | AC: AC-017, AC-018 | Depends: 5.2
- [ ] **[M]** 5.11 — Integration tests for enterprise subscriptions: renewal replenishes seats, payment failure triggers grace period (`services/purchase-gateway/tests/test_subscriptions.py`) | AC: AC-022, AC-023 | Depends: 5.3
- [ ] **[M]** 5.12 — Integration tests for admin API tenant isolation: admin A sees only tenant A data (`services/purchase-gateway/tests/test_admin_api.py`) | AC: AC-024, AC-025 | Depends: 5.4, 5.5
- [ ] **[S]** 5.13 — Unit tests for bulk entitlement assignment: valid batch, mixed valid/invalid (all rejected), duplicate email idempotent (`services/purchase-gateway/tests/test_bulk_assign.py`) | AC: AC-014 | Depends: 5.6
- [ ] **[S]** 5.14 — Unit tests for reconciliation job (`services/purchase-gateway/tests/test_reconciliation.py`) | AC: AC-029 | Depends: 5.8

---

### Milestone 6: Kubernetes Deployment and Infrastructure (Week 12-13)

#### Build

- [ ] **[M]** 6.1 — Write multi-stage Dockerfile: build stage (pip install), runtime stage (slim Python, non-root user, health check) (`services/purchase-gateway/Dockerfile`) | AC: AC-031, AC-032 | Depends: 1.1
- [ ] **[M]** 6.2 — Create K8s manifests: `payments-gateway` Deployment (API), `payments-worker` Deployment (worker), Service, ConfigMap, HPA, PodDisruptionBudget (`deploy/k8s/base/apps/purchase-gateway/`) | AC: AC-031, AC-032, AC-033 | Depends: 6.1
- [ ] **[M]** 6.3 — Create ExternalSecret manifest for gateway secrets: `PAYMENTS_GATEWAY_SECRET_KEY`, `PAYMENTS_GATEWAY_DB_PASSWORD`, `PAYMENTS_GATEWAY_OAUTH2_SECRET`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET_GATEWAY` (`deploy/k8s/base/secrets/external-secrets.yaml`) | AC: AC-031 | Depends: None
- [ ] **[S]** 6.4 — Configure init container for Alembic database migrations in the gateway Deployment (`deploy/k8s/base/apps/purchase-gateway/deployment.yaml`) | AC: AC-031 | Depends: 6.2
- [ ] **[S]** 6.5 — Add Caddy reverse proxy route for `/purchase/*`, `/api/v1/checkout/*`, `/api/v1/claim/*`, `/webhooks/stripe/` to `payments-gateway` service (`deploy/k8s/base/apps/caddy/Caddyfile`) | AC: AC-001, AC-033 | Depends: 6.2
- [ ] **[S]** 6.6 — Add Prometheus scrape config for the gateway metrics endpoint (`infrastructure/monitoring/` or annotations in Deployment) | AC: AC-029 | Depends: 6.2
- [ ] **[S]** 6.7 — Provision secrets in Infisical and sync to GCP Secret Manager (`scripts/infra/`) | AC: AC-031 | Depends: None
- [ ] **[S]** 6.8 — Build and push Docker images to Artifact Registry (`asia-southeast1-docker.pkg.dev/mereka-lms/openedx`) (`scripts/infra/build-gateway.sh`) | AC: AC-031 | Depends: 6.1

#### Test

- [ ] **[S]** 6.9 — Shell verification: `kubectl get deployments -n mereka-lms -l app.kubernetes.io/name=payments-gateway` shows READY >= 1 (`scripts/qa/verify-purchase-gateway.sh`) | AC: AC-031 | Depends: 6.2
- [ ] **[S]** 6.10 — Shell verification: `kubectl get deployments -n mereka-lms -l app.kubernetes.io/name=payments-worker` shows READY >= 1 (`scripts/qa/verify-purchase-gateway.sh`) | AC: AC-032 | Depends: 6.2
- [ ] **[S]** 6.11 — Shell verification: `curl http://payments-gateway:8000/health/` returns HTTP 200 with all checks OK (`scripts/qa/verify-purchase-gateway.sh`) | AC: AC-033 | Depends: 6.2
- [ ] **[S]** 6.12 — Shell verification: ExternalSecret syncs successfully, `kubectl get externalsecret payments-gateway-secrets -n mereka-lms` shows Ready (`scripts/qa/verify-purchase-gateway.sh`) | AC: AC-031 | Depends: 6.3

---

### Milestone 7: End-to-End Testing, Migration, and Hardening (Week 14-16)

#### Build

- [ ] **[M]** 7.1 — Implement legacy ecommerce migration routing: new purchases go to gateway, legacy in-flight orders complete on legacy service (`services/purchase-gateway/api/middleware/migration.py`) | AC: AC-027 | Depends: 2.2, 6.5
- [ ] **[M]** 7.2 — Implement decommission verification script: check zero active orders in legacy system, then remove Deployment/Service/DNS/OAuth2 clients (`scripts/infra/decommission-legacy-ecommerce.sh`) | AC: AC-028 | Depends: 7.1
- [ ] **[M]** 7.3 — Implement historical order import script: read from legacy MySQL, write to gateway PostgreSQL (`scripts/migrations/import-legacy-orders.py`) | AC: AC-028 | Depends: 1.3

#### Test

- [ ] **[L]** 7.4 — End-to-end smoke test: full purchase flow from checkout creation to enrollment confirmation (Stripe test mode) (`scripts/qa/smoke-purchase-gateway.sh`) | AC: AC-001, AC-002 | Depends: All Milestone 1-6
- [ ] **[M]** 7.5 — End-to-end smoke test: entitlement flow (purchase without account, invitation email, claim) (`scripts/qa/smoke-purchase-gateway.sh`) | AC: AC-003, AC-010, AC-011 | Depends: All Milestone 1-6
- [ ] **[M]** 7.6 — End-to-end smoke test: refund flow (Stripe refund, enrollment revocation) (`scripts/qa/smoke-purchase-gateway.sh`) | AC: AC-015 | Depends: All Milestone 1-6
- [ ] **[M]** 7.7 — Load test: 100 concurrent checkouts, verify no race conditions or duplicates (`scripts/qa/load-test-purchase-gateway.py`) | AC: AC-001 (NFR: 100 concurrent) | Depends: All Milestone 1-6
- [ ] **[S]** 7.8 — Migration verification: legacy routing to gateway works, dual-running is stable (`scripts/qa/verify-purchase-gateway.sh`) | AC: AC-027 | Depends: 7.1
- [ ] **[S]** 7.9 — Migration verification: decommission script removes legacy cleanly (`scripts/qa/verify-purchase-gateway.sh`) | AC: AC-028 | Depends: 7.2

---

### Observability (Ongoing, starting Milestone 1)

- [ ] **[M]** O.1 — Implement structured JSON logging for both gateway API and worker with required fields (`service_name`, `tenant_id`, `request_id`, `log_level`, `timestamp`) and sensitive data filtering (email -> SHA-256 hash, no full webhook payloads) (`services/purchase-gateway/api/logging.py`) | AC: AC-030 | Depends: 1.2
- [ ] **[L]** O.2 — Register all 20+ Prometheus metrics (counters, histograms, gauges) for checkouts, webhooks, fulfillments, orders, entitlements, refunds, disputes, revenue, LMS API, Stripe API, queue depth, dead letter queue, reconciliation (`services/purchase-gateway/api/metrics.py`) | AC: AC-029 | Depends: 1.8
- [ ] **[M]** O.3 — Create Prometheus alerting rules for all 11 alerts (4 Critical, 4 Warning, 3 Info) (`infrastructure/monitoring/alerts/purchase-gateway.yml`) | AC: AC-020, AC-029 | Depends: O.2
- [ ] **[L]** O.4 — Create 6 Grafana dashboards: Overview, Fulfillment Health, Revenue, Entitlement Tracker, Webhook Monitor, Reconciliation Report (`infrastructure/monitoring/dashboards/purchase-gateway/`) | AC: AC-029 | Depends: O.2
- [ ] **[S]** O.5 — Verify fulfillment failure logs include required fields: `order_uuid`, `tenant_id`, `offering_type`, `lms_resource_id`, `error_type`, `buyer_email_hash` (`services/purchase-gateway/tests/test_logging.py`) | AC: AC-030 | Depends: O.1

---

### Docs

- [ ] **[M]** D.1 — Write Stripe webhook setup guide for the gateway endpoint (`docs/operations/STRIPE_WEBHOOKS_SETUP.md` -- update existing) | Depends: 3.1
- [ ] **[M]** D.2 — Write operational runbook: startup, health checks, troubleshooting, manual enrollment, manual refund (`docs/runbooks/purchase-gateway-runbook.md`) | Depends: All Milestone 1-6
- [ ] **[M]** D.3 — Write architecture overview: component diagram, data flow, integration points (`docs/architecture/purchase-gateway-overview.md`) | Depends: None
- [ ] **[S]** D.4 — Write OAuth2 troubleshooting guide for gateway <-> LMS authentication (`docs/operations/ECOMMERCE_OAUTH_TROUBLESHOOTING.md` -- update existing) | Depends: 4.2
- [ ] **[S]** D.5 — Update `CLAUDE.md` with gateway service details, ports, PM2/K8s references | Depends: 6.2

---

### Rollout

- [ ] **[S]** R.1 — Create feature flag `ENABLE_GATEWAY_FULFILLMENT` (default: off) (`services/purchase-gateway/api/config.py`) | Depends: None
- [ ] **[S]** R.2 — Create feature flag `GATEWAY_ALLOWED_OFFERINGS` (whitelist, empty = all) (`services/purchase-gateway/api/config.py`) | Depends: None
- [ ] **[S]** R.3 — Create feature flag `ENABLE_NEW_CHECKOUT` (frontend routing gate) (`services/purchase-gateway/api/config.py`) | Depends: None
- [ ] **[S]** R.4 — Create feature flag `ENABLE_ENTITLEMENT_INVITATIONS` (default: on) (`services/purchase-gateway/api/config.py`) | Depends: None
- [ ] **[S]** R.5 — Create feature flag `ENABLE_ENTERPRISE_SUBSCRIPTIONS` (default: off) (`services/purchase-gateway/api/config.py`) | Depends: None
- [ ] **[S]** R.6 — Create feature flag `ENABLE_AUTO_REVOKE_ON_DISPUTE` (default: off) (`services/purchase-gateway/api/config.py`) | Depends: None
- [ ] **[S]** R.7 — Create feature flag `ENABLE_RECONCILIATION_JOB` (default: off) (`services/purchase-gateway/api/config.py`) | Depends: None

---

## Milestone Summary

| Milestone | Weeks | Tasks | Effort | Key Deliverable |
|-----------|-------|-------|--------|-----------------|
| 1. Scaffolding + DB | 1-2 | 10 | L | Running FastAPI app with all tables, health check, test infra |
| 2. Offerings + Checkout | 3-4 | 13 | L | Checkout session creation, Stripe Connect, rate limiting |
| 3. Webhooks + Orders | 5-6 | 9 | L | All 13 webhook handlers, order state machine, idempotency |
| 4. Fulfillment + Entitlements | 7-9 | 12 | XL | Worker, LMS integration, entitlement/claim flow, seat packs |
| 5. Refund + Enterprise | 10-11 | 14 | L | Refunds, disputes, subscriptions, admin API, tenant isolation |
| 6. K8s Deployment | 12-13 | 12 | M | Docker image, K8s manifests, secrets, Caddy routing |
| 7. E2E + Migration | 14-16 | 6 | L | E2E tests, load tests, legacy migration, decommission |
| Observability | Ongoing | 5 | L | Metrics, alerts, dashboards, logging |
| Docs | Ongoing | 5 | M | Runbook, architecture doc, setup guides |
| Rollout | Week 1 | 7 | S | All feature flags defined |
| **Total** | **16 weeks** | **93 tasks** | | |

---

## Risks and Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Cloud SQL PostgreSQL provisioning delays | Blocks all DB work | Medium | Prepare in-cluster PostgreSQL as fallback for dev/test |
| LMS Enrollment API instability | Blocks fulfillment testing | Medium | Build comprehensive mocks; test against staging LMS first |
| Stripe Connect complexity | Delays multi-tenant billing | Medium | Implement single-tenant first, add Connect as a separate milestone |
| Legacy ecommerce has undocumented dependencies | Delays decommission | High | Audit all references to legacy ecommerce URLs/APIs before cutover |
| Redis queue data loss during cluster maintenance | Lost fulfillment jobs | Low | Enable Redis persistence (AOF), test recovery cron job |
| Email delivery failures for invitations | Entitlements never claimed | Medium | Monitor unclaimed entitlement count, implement resend UI |
| Open Questions unresolved | Blocks dependent tasks | Medium | Use defaults noted above; escalate blockers weekly |

---

## Self-Check

- [x] Every acceptance criterion (AC-001 through AC-033) has at least one build task
- [x] Every acceptance criterion has at least one test task
- [x] Edge cases are covered by integration tests (Milestone 4, 5)
- [x] File paths specified for every task
- [x] Dependencies identified for every task
- [x] Complexity estimated (S/M/L) for every task
- [x] Observability tasks cover metrics, alerts, dashboards, logging
- [x] Rollout tasks define all 7 feature flags from the spec
- [x] Docs tasks cover all 5 linked documents from spec frontmatter
- [x] Migration tasks cover dual-running and decommission
- [x] Source spec linked in header
