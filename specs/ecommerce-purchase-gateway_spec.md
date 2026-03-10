---
id: "SPEC-COM-001"
title: "Ecommerce Purchase Gateway (Stripe -> Open edX Integration)"
type: "feature_spec"
status: "approved"
spec_class: "integration"
owner: "engineering"
vehicle: "talent_platform"
created: "2026-02-10"
last_reviewed: "2026-03-09"
review_due: "2026-06-09"
last_updated: "2026-02-10"
version: "1.0.0"
domain: "commerce"
normativity: "normative"
depends_on:
  - "specs/enterprise-microservices_spec.md"
  - "specs/multi-tenancy-architecture_spec.md"
  - "specs/k8s-deployment_spec.md"
  - "specs/secrets-management_spec.md"
supersedes: []
superseded_by: null
verification_sources:
  - "scripts/qa/run-spec-integrity-gates.sh"
interfaces:
  - "Stripe"
  - "Open edX"
tags:
  - "commerce.reconciliation"
  - "build.gitops-promotion"
summary: "Defines the purchase gateway contract from Stripe checkout through fulfillment into Open edX commerce ownership."
links:
  related_docs:
    - "docs/ops/runbooks/STRIPE_WEBHOOKS_SETUP.md"
    - "docs/ops/runbooks/ECOMMERCE_OAUTH_TROUBLESHOOTING.md"
    - "docs/ops/runbooks/TROUBLESHOOTING.md"
    - "docs/concepts/architecture/purchase-gateway-overview.md"
    - "docs/ops/runbooks/TROUBLESHOOTING.md"
  related_specs:
    - "specs/enterprise-microservices_spec.md"
    - "specs/multi-tenancy-architecture_spec.md"
    - "specs/secrets-management_spec.md"
    - "specs/k8s-deployment_spec.md"
    - "specs/observability-stack_spec.md"
    - "specs/auth-sso-enterprise_spec.md"
    - "specs/cross-cutting-requirements_spec.md"
---

# Human Summary

## What we're building

A custom Purchase Gateway that completely replaces the deprecated Open edX Oscar/ecommerce service with a purpose-built Stripe-to-Open edX enrollment bridge. The system accepts payments from buyers who may or may not have an existing Open edX account, processes them through Stripe Checkout, and fulfills orders by creating enrollments, issuing entitlements, or provisioning seat packs in the LMS.

The gateway is a standalone service comprising four components: a `payments-gateway` API server (public endpoints for checkout initiation and Stripe webhook reception), a `payments-worker` (async fulfillment processor), a PostgreSQL database (orders, entitlements, Stripe event log, multi-tenant data), and a Redis queue (job dispatch between API and worker). It deploys into the existing `mereka-lms` GKE namespace alongside the current platform services.

The critical design decision is that purchases do NOT require a pre-existing Open edX account. A buyer provides an email address at checkout time. If they already have an LMS account, enrollment happens immediately upon payment confirmation. If they do not, the gateway creates an entitlement record and sends an invitation email with a registration link. Upon registration, the entitlement is automatically fulfilled (enrollment created). This "entitlement + invitation" pattern enables use cases like gift purchases, corporate bulk buys, and marketing-driven acquisition where the buyer is not yet a platform user.

The system is multi-tenant from day one, supporting the `EnterpriseCustomer` model defined in `specs/multi-tenancy-architecture_spec.md`. Each tenant can have its own Stripe Connect account (or use the platform Stripe account), its own product catalog (offerings), and its own billing configuration. Enterprise features like seat packs, subscription management, and bulk invoicing build on this multi-tenant foundation.

## Why it matters

The existing Oscar/ecommerce service is archived upstream by the Open edX community. It carries substantial technical debt: a complex Oscar-based order pipeline, PayPal/CyberSource integrations we do not use, a separate Django admin, its own MySQL database, its own OAuth2 client pair, and a Stripe integration that was bolted on after the fact. Every upgrade cycle requires patching an unmaintained codebase. Meanwhile, the ecommerce service is the only path to paid enrollment -- if it breaks, revenue stops.

Building a custom Purchase Gateway eliminates this dependency. It gives us direct control over the payment flow, simplifies the architecture (one service, one database, one integration), enables the "no account required" purchase flow that the Oscar stack cannot support without significant modification, and lays the foundation for enterprise billing features (seat packs, subscriptions, multi-tenant invoicing) that are core to Mereka Academy's growth strategy.

Revenue impact is direct: every course purchase, program enrollment, and enterprise seat pack flows through this gateway. Downtime or bugs mean lost revenue and damaged client trust.

## Success looks like

- A buyer can purchase a course in under 60 seconds from "Buy Now" click to enrollment confirmation, without needing a pre-existing LMS account
- Stripe webhook events are processed with exactly-once semantics: no duplicate enrollments, no missed payments
- The legacy ecommerce service is fully decommissioned: zero pods, zero DNS records, zero OAuth2 clients
- Enterprise clients can purchase seat packs and distribute them to employees who are not yet registered
- Refund processing automatically revokes the corresponding enrollment within 5 minutes
- The system handles 100 concurrent checkouts without degradation
- Financial audit trail is complete: every dollar in, every enrollment out, every refund, every dispute, all traceable by Stripe payment intent ID
- Zero PCI scope: all card data is handled by Stripe, never touches our infrastructure

---

# Agent Contract

## Scope

- In scope:
  - Purchase Gateway API service: checkout session creation, webhook handling, order management, entitlement management
  - Purchase Gateway worker service: async fulfillment, retry logic, dead letter handling
  - Stripe integration: Checkout Sessions, Payment Intents, Webhooks, Refunds, Disputes, Customer objects, Stripe Connect (multi-tenant)
  - Multi-tenant data model: tenants, offerings (products), orders, line items, fulfillments, entitlements, invitations, Stripe event log
  - PostgreSQL database schema and migrations
  - Redis-based job queue for async fulfillment
  - Open edX Enrollment API integration: course enrollment, program enrollment, entitlement creation
  - Open edX OAuth2/JWT service-to-service authentication
  - Entitlement and invitation flow for buyers without existing LMS accounts
  - Webhook signature verification and idempotent event processing
  - Refund and dispute handling with automatic enrollment revocation
  - Enterprise seat pack purchasing and distribution
  - Enterprise subscription management (recurring billing via Stripe)
  - Purchase UI flows: buy button, checkout redirect, confirmation page, receipt email
  - Secrets management for gateway credentials (Stripe keys, OAuth2 secrets, database credentials)
  - K8s deployment manifests (Deployment, Service, ConfigMap, ExternalSecret, HPA)
  - Observability: structured logging, Prometheus metrics, alerts, Grafana dashboards
  - Migration plan from legacy ecommerce service to Purchase Gateway
  - Rollback and dual-running strategy during migration

- Out of scope:
  - Credit card form or payment UI (Stripe Checkout handles all card UI -- zero PCI scope)
  - PayPal, CyberSource, or any non-Stripe payment processor
  - Course content creation or curriculum management
  - Open edX LMS/CMS core code changes (we consume APIs only)
  - Enterprise catalog management (handled by `enterprise-catalog` per `specs/enterprise-microservices_spec.md`)
  - Enterprise license management (handled by `license-manager` per `specs/enterprise-microservices_spec.md`)
  - Tax calculation (Stripe Tax or a future tax engine integration)
  - Invoicing PDF generation (Stripe Invoicing or a future integration)
  - Mobile app payment flows (App Store / Google Play -- separate spec)

## Non-goals

- Building a general-purpose e-commerce platform (this is purpose-built for Open edX enrollment fulfillment)
- Supporting multiple payment gateways simultaneously (Stripe-only by design; gateway abstraction adds complexity with no current need)
- Implementing a shopping cart with multiple items per checkout session (v1 supports single-offering checkout; multi-item is a future enhancement)
- Building a coupon/discount code engine (Stripe Checkout supports promotional codes natively; we pass them through)
- Replicating Oscar's fulfillment partner model (our fulfillment target is always the Open edX Enrollment API)
- Supporting cryptocurrency or alternative payment methods beyond what Stripe Checkout enables
- Building a custom payment form (we delegate all payment UI to Stripe Checkout for PCI compliance)

## Assumptions

- Stripe account is already provisioned and operational (confirmed: webhook delivery probe accepted HTTP 200 per `docs/runbooks/operations/STRIPE_WEBHOOKS_SETUP.md`)
- The Open edX Enrollment API (`/api/enrollment/v1/enrollment`) is stable and available for programmatic enrollment creation
- The Open edX user creation API or registration flow supports account creation triggered by an invitation link
- The existing GKE cluster has capacity for 2 additional Deployments (gateway API + worker) with estimated 1 vCPU / 2 GB RAM total at baseline
- PostgreSQL can be provisioned as a Cloud SQL instance or as an in-cluster deployment (Cloud SQL preferred for production)
- Redis is already deployed in the cluster and can host an additional queue namespace
- The existing Caddy reverse proxy can route to the new gateway service
- Infisical is the secrets source of truth (per `specs/secrets-management_spec.md`)
- The LMS OAuth2 provider can issue service-to-service credentials for the gateway
- Artifact Registry (`asia-southeast1-docker.pkg.dev/mereka-lms/openedx`) can host gateway images
- The frontend checkout flow will use redirects to Stripe Checkout (not embedded Stripe Elements)
- The `EnterpriseCustomer` model and multi-tenant architecture from `specs/multi-tenancy-architecture_spec.md` are available

---

## Requirements

### Domain and SSL

| Property | Value |
|----------|-------|
| External URL | `https://shop.academyv2.mereka.io` |
| Cloudflare mode | DNS-only (gray cloud) |
| SSL provider | Let's Encrypt via cert-manager |
| Reason | Multi-level subdomain (`*.*.mereka.io`) not covered by Cloudflare Free SSL |

See `specs/cross-cutting-requirements_spec.md` for platform-wide TLS requirements.

### Functional

#### Offering (Product) Management

- The system MUST support the following offering types:
  - `course_seat`: enrollment in a single course run (identified by `course_run_key`, e.g., `course-v1:Mereka+BUS101+2026Q1`)
  - `program`: enrollment in all courses within a program (identified by `program_uuid`)
  - `seat_pack`: a bundle of N enrollment seats for a specific catalog, distributable by an enterprise admin
- Each offering MUST include: `uuid`, `tenant_id`, `offering_type`, `title`, `description`, `price_cents` (integer, smallest currency unit), `currency` (ISO 4217, 3-letter code), `stripe_price_id` (Stripe Price object reference), `lms_resource_id` (course_run_key, program_uuid, or catalog_uuid depending on type), `active` (boolean), `metadata` (JSON, type-specific data such as seat count for seat packs)
- The system MUST support creating, updating, and soft-deleting offerings via an admin API
- The system MUST validate that `stripe_price_id` references a valid Stripe Price object before activating an offering
- The system MUST support offerings priced at zero (free enrollments that still flow through the gateway for tracking and entitlement management)

#### Checkout Flow

- The system MUST expose a public API endpoint to create a Stripe Checkout Session for a given offering
- The checkout creation endpoint MUST accept: `offering_uuid`, `buyer_email`, `tenant_id` (optional, defaults to platform tenant), `success_url`, `cancel_url`, `metadata` (optional JSON, e.g., gift recipient email)
- The system MUST NOT require authentication to create a checkout session (public endpoint -- anyone can buy)
- The system MUST create a pending `Order` record in the database before redirecting to Stripe Checkout
- The system MUST pass the `order_uuid` as metadata on the Stripe Checkout Session for correlation
- The system MUST set `customer_email` on the Stripe Checkout Session to the `buyer_email` provided
- The system MUST create or reuse a Stripe Customer object for the `buyer_email` to enable receipt emails and purchase history
- The system MUST configure the Stripe Checkout Session with `payment_intent_data.capture_method = "automatic"` (immediate capture, not authorization-only)
- The system MUST support Stripe promotional codes on the Checkout Session when the offering or tenant is configured to allow them
- For multi-tenant deployments using Stripe Connect, the system MUST create the Checkout Session on behalf of the tenant's connected Stripe account using `stripe_account` header
- The system MUST redirect the buyer to the Stripe Checkout URL returned by the session creation
- After successful payment, Stripe MUST redirect the buyer to `success_url` with `session_id` appended as a query parameter
- After cancellation, Stripe MUST redirect the buyer to `cancel_url`

#### Webhook Handling

- The system MUST expose a webhook endpoint at `/webhooks/stripe/` to receive Stripe events
- The system MUST verify the Stripe webhook signature using the `Stripe-Signature` header and the configured webhook signing secret (`whsec_...`)
- The system MUST reject webhook requests with invalid signatures with HTTP 400
- The system MUST return HTTP 200 to Stripe within 5 seconds of receiving a webhook event (acknowledge receipt, then process asynchronously)
- The system MUST log every received Stripe event in the `stripe_events` table with: `stripe_event_id`, `event_type`, `payload` (full JSON), `received_at`, `processed_at`, `processing_status` (received, processing, processed, failed), `idempotency_key`
- The system MUST handle the following Stripe event types:
  - `checkout.session.completed` -- trigger order fulfillment
  - `checkout.session.expired` -- mark order as expired
  - `payment_intent.succeeded` -- confirm payment (redundant with checkout.session.completed but handles edge cases)
  - `payment_intent.payment_failed` -- mark order as payment_failed
  - `charge.refunded` -- trigger enrollment revocation
  - `charge.refund.updated` -- handle partial refund status changes
  - `charge.dispute.created` -- flag order for review, optionally auto-revoke
  - `charge.dispute.closed` -- update dispute status (won/lost)
  - `customer.subscription.created` -- create subscription record (enterprise recurring billing)
  - `customer.subscription.updated` -- update subscription status (active, past_due, canceled)
  - `customer.subscription.deleted` -- mark subscription as canceled, handle access revocation
  - `invoice.paid` -- renew enterprise seat packs or subscription periods
  - `invoice.payment_failed` -- flag subscription for grace period handling
- Webhook processing MUST be idempotent: processing the same `stripe_event_id` more than once MUST NOT create duplicate orders, enrollments, or financial records. The system MUST check `stripe_events.stripe_event_id` for existence before processing
- For multi-tenant Stripe Connect, the system MUST support separate webhook endpoints per connected account or use the `account` field in the event payload to route to the correct tenant context

#### Order Lifecycle

- The system MUST track orders through the following state machine:
  - `pending` -- checkout session created, awaiting payment
  - `paid` -- payment confirmed (checkout.session.completed received)
  - `fulfilling` -- fulfillment in progress (enrollment/entitlement being created)
  - `fulfilled` -- all line items successfully fulfilled
  - `partially_fulfilled` -- some line items fulfilled, others failed (seat packs where some seats fail)
  - `fulfillment_failed` -- fulfillment failed after all retries exhausted
  - `refunded` -- full refund processed, enrollments revoked
  - `partially_refunded` -- partial refund processed
  - `disputed` -- chargeback/dispute opened
  - `expired` -- checkout session expired without payment
  - `canceled` -- order explicitly canceled before payment
- Each `Order` record MUST include: `uuid`, `tenant_id`, `buyer_email`, `buyer_user_id` (nullable, resolved when LMS account is identified), `stripe_checkout_session_id`, `stripe_payment_intent_id`, `stripe_customer_id`, `status`, `total_cents`, `currency`, `created_at`, `updated_at`, `fulfilled_at`, `refunded_at`, `metadata` (JSON)
- Each order MUST have one or more `LineItem` records with: `uuid`, `order_uuid`, `offering_uuid`, `offering_type`, `lms_resource_id`, `quantity`, `unit_price_cents`, `total_price_cents`, `fulfillment_status` (pending, fulfilled, failed, revoked)
- Order state transitions MUST be logged in an `order_audit_log` table with: `uuid`, `order_uuid`, `old_status`, `new_status`, `triggered_by` (webhook event ID, admin user, system), `timestamp`, `details` (JSON)

#### Fulfillment Engine

- Upon receiving `checkout.session.completed`, the system MUST enqueue a fulfillment job to the Redis queue
- The fulfillment worker MUST resolve the buyer's LMS user account:
  1. Query the LMS user API by `buyer_email`
  2. If a user exists, record `buyer_user_id` on the order and proceed to enrollment
  3. If no user exists, create an entitlement record and trigger the invitation flow (see Entitlement and Invitation Flow)
- For `course_seat` offerings, the fulfillment worker MUST call the Open edX Enrollment API (`POST /api/enrollment/v1/enrollment`) with the user's `username` and `course_id` to create an enrollment in `verified` mode
- For `program` offerings, the fulfillment worker MUST call the LMS program enrollment API or enroll the user in all active course runs within the program
- For `seat_pack` offerings, the fulfillment worker MUST create N entitlement records (one per seat) in `unassigned` state, linked to the order and the offering's catalog
- The fulfillment worker MUST retry failed enrollment API calls with exponential backoff: base 5 seconds, multiplier 2, max delay 5 minutes, max retries 10
- After all retries are exhausted, the order MUST transition to `fulfillment_failed` and an alert MUST be fired
- The fulfillment worker MUST update the order status to `fulfilled` only after all line items are successfully fulfilled
- Fulfillment MUST be idempotent: if the worker processes the same order twice (e.g., due to queue retry), it MUST NOT create duplicate enrollments. The worker MUST check existing enrollment status via the Enrollment API before creating

#### Entitlement and Invitation Flow

- When a buyer has no existing LMS account, the system MUST create an `Entitlement` record: `uuid`, `order_uuid`, `line_item_uuid`, `tenant_id`, `recipient_email`, `lms_resource_id`, `offering_type`, `status` (pending, claimed, expired, revoked), `claim_token` (unique URL-safe token), `claimed_by_user_id` (nullable), `created_at`, `expires_at`, `claimed_at`
- The system MUST send an invitation email to `recipient_email` containing a claim link: `https://{lms_domain}/purchase/claim/{claim_token}`
- The claim link MUST be valid for a configurable period (default: 30 days)
- When a user visits the claim link:
  1. If the user is authenticated and the claim token is valid, the entitlement MUST be immediately fulfilled (enrollment created) and the entitlement status set to `claimed`
  2. If the user is not authenticated, they MUST be redirected to the LMS registration/login page with a `next` parameter pointing back to the claim URL
  3. After registration/login, the system MUST automatically fulfill the entitlement
- Expired claim tokens MUST return a clear error page with instructions to contact support
- The system MUST support resending invitation emails for unclaimed entitlements
- For enterprise seat packs, an enterprise admin MUST be able to assign entitlements to specific email addresses via the admin API (bulk assignment, up to 500 emails per request)
- Entitlement assignment MUST be idempotent: assigning the same email to the same seat pack offering MUST NOT create a duplicate entitlement
- The system MUST support revoking unclaimed entitlements (returns the seat to the pool)

#### Open edX Integration

- The system MUST authenticate to the Open edX LMS using OAuth2 client credentials (service account)
- The system MUST have a dedicated OAuth2 application registered in the LMS Django admin with client ID `payments-gateway`
- The system MUST use internal K8s DNS (`http://lms:8000`) for all LMS API calls, not external URLs
- The system MUST cache the OAuth2 access token and refresh it when expired (token TTL is typically 3600 seconds)
- The system MUST call the following LMS APIs:
  - `POST /api/enrollment/v1/enrollment` -- create enrollment (course_seat fulfillment)
  - `GET /api/enrollment/v1/enrollment/{username},{course_id}` -- check existing enrollment (idempotency)
  - `GET /api/user/v1/accounts?email={email}` -- resolve email to user account
  - `POST /api/user/v1/account/registration/` -- (if available) create account programmatically for invitation flows
- The system MUST handle LMS API errors gracefully:
  - HTTP 400 (bad request): log error, mark line item as `failed`, do not retry
  - HTTP 401 (unauthorized): refresh OAuth2 token, retry once
  - HTTP 403 (forbidden): log error, mark line item as `failed`, alert (permissions misconfiguration)
  - HTTP 404 (course not found): log error, mark line item as `failed`, alert (course may have been unpublished)
  - HTTP 409 (already enrolled): treat as success (idempotent)
  - HTTP 429 (rate limited): respect `Retry-After` header, retry
  - HTTP 500/502/503 (server error): retry with exponential backoff

#### Refund and Dispute Handling

- Upon receiving `charge.refunded`, the system MUST:
  1. Identify the order by `stripe_payment_intent_id`
  2. Determine if the refund is full or partial (compare `amount_refunded` to order `total_cents`)
  3. For full refunds: transition order to `refunded` and revoke all fulfillments
  4. For partial refunds: transition order to `partially_refunded` and log the refund amount (do not auto-revoke; manual admin decision)
- Enrollment revocation MUST call the Open edX Enrollment API to deactivate the enrollment (`POST /api/enrollment/v1/enrollment` with `is_active: false`)
- Entitlement revocation MUST set the entitlement status to `revoked` and, if already claimed, also revoke the enrollment
- Upon receiving `charge.dispute.created`, the system MUST:
  1. Transition order to `disputed`
  2. Fire an alert to the finance/ops team
  3. Optionally auto-revoke access based on a configurable policy (default: do not auto-revoke on dispute, wait for resolution)
- Upon receiving `charge.dispute.closed` with `status=won` (merchant won), the system MUST restore the order to its pre-dispute status
- Upon receiving `charge.dispute.closed` with `status=lost` (buyer won), the system MUST revoke all fulfillments and transition order to `refunded`

#### Enterprise Billing and Subscriptions

- The system MUST support enterprise subscription plans using Stripe Subscriptions
- Each enterprise subscription MUST be linked to a `tenant_id` (EnterpriseCustomer UUID) and a `seat_pack` offering
- Subscription creation MUST create a Stripe Subscription with the appropriate Stripe Price and quantity
- Upon `invoice.paid` for a subscription renewal, the system MUST replenish seat pack entitlements for the next billing period
- Upon `invoice.payment_failed`, the system MUST enter a configurable grace period (default: 7 days) before suspending access
- The system MUST support metered billing: enterprise clients pay per active enrollment rather than a fixed seat count (future enhancement, SHOULD be architecturally supported but MAY NOT be implemented in v1)
- The system MUST support generating purchase reports per tenant: total revenue, order count, refund rate, seat utilization

#### Admin API

- The system MUST expose an authenticated admin API for platform operators:
  - `GET /admin/api/v1/orders/` -- list/filter orders (by tenant, status, date range, buyer email)
  - `GET /admin/api/v1/orders/{uuid}/` -- order detail with line items, fulfillments, audit log
  - `POST /admin/api/v1/orders/{uuid}/retry-fulfillment/` -- manually retry failed fulfillment
  - `POST /admin/api/v1/orders/{uuid}/refund/` -- initiate refund via Stripe Refunds API
  - `GET /admin/api/v1/offerings/` -- list offerings
  - `POST /admin/api/v1/offerings/` -- create offering
  - `PATCH /admin/api/v1/offerings/{uuid}/` -- update offering
  - `DELETE /admin/api/v1/offerings/{uuid}/` -- soft-delete offering
  - `GET /admin/api/v1/entitlements/` -- list entitlements (by tenant, status, recipient email)
  - `POST /admin/api/v1/entitlements/assign/` -- bulk assign seat pack entitlements to emails
  - `POST /admin/api/v1/entitlements/{uuid}/resend-invitation/` -- resend invitation email
  - `POST /admin/api/v1/entitlements/{uuid}/revoke/` -- revoke an entitlement
  - `GET /admin/api/v1/tenants/{uuid}/reports/` -- purchase reports for a tenant
  - `GET /admin/api/v1/stripe-events/` -- list/filter processed Stripe events (for debugging)
- Admin API endpoints MUST require JWT authentication with `payments_admin` or `enterprise_admin` role
- Enterprise admins MUST only see orders and entitlements for their own tenant (tenant isolation per `specs/multi-tenancy-architecture_spec.md`)
- Platform operators (superuser) MUST be able to see all tenants

#### Public API

- The system MUST expose the following public (unauthenticated) endpoints:
  - `POST /api/v1/checkout/` -- create checkout session (returns Stripe Checkout URL)
  - `GET /api/v1/checkout/{session_id}/status/` -- check order status after checkout (for the success page)
  - `POST /webhooks/stripe/` -- Stripe webhook receiver
  - `GET /api/v1/claim/{claim_token}/` -- validate and present entitlement claim page
  - `POST /api/v1/claim/{claim_token}/` -- claim an entitlement (requires authentication)
  - `GET /health/` -- health check
  - `GET /ready/` -- readiness probe
  - `GET /metrics/` -- Prometheus metrics endpoint

#### Database Schema (PostgreSQL)

- The system MUST use PostgreSQL as the primary data store (not MySQL, to avoid schema conflicts with the shared Cloud SQL MySQL instance used by Open edX services)
- The system MUST implement the following tables:
  - `tenants` -- tenant configuration (linked to EnterpriseCustomer UUID)
  - `offerings` -- product catalog
  - `orders` -- purchase records
  - `line_items` -- order line items
  - `fulfillments` -- fulfillment attempt records (links line item to LMS enrollment)
  - `entitlements` -- entitlement/invitation records
  - `stripe_events` -- Stripe webhook event log
  - `order_audit_log` -- order state change history
  - `subscriptions` -- enterprise subscription records
- All tables MUST include `tenant_id` (except `stripe_events` which derives tenant from the event payload)
- All queries MUST filter by `tenant_id` at the ORM level (application-level tenant isolation, consistent with `specs/multi-tenancy-architecture_spec.md`)
- Database migrations MUST be executed via init containers during deployment
- The system MUST enforce unique constraints on: `stripe_events.stripe_event_id`, `entitlements.claim_token`, `orders.stripe_checkout_session_id`
- The system MUST enforce foreign key constraints between orders, line items, fulfillments, and entitlements

#### Legacy Ecommerce Service Migration

- The system MUST support a dual-running period where both the legacy ecommerce service and the Purchase Gateway are operational
- During dual-running, new purchases MUST be routed to the Purchase Gateway
- Existing in-flight orders in the legacy system MUST be allowed to complete via the legacy service
- The system MUST support importing historical order data from the legacy ecommerce MySQL database for reporting continuity
- After the migration cutover, the system MUST provide a script to verify zero active orders remain in the legacy system
- After cutover verification, the legacy ecommerce service MUST be fully decommissioned: Deployment scaled to 0, DNS records removed, OAuth2 clients disabled, secrets archived

### Non-Functional Requirements

#### Performance

- Checkout session creation endpoint p95 latency MUST be <= 500ms (includes Stripe API call to create session)
- Webhook endpoint MUST return HTTP 200 within 500ms at p95 (async processing, not blocking)
- Fulfillment processing (from webhook receipt to enrollment confirmed in LMS) p95 latency MUST be <= 10 seconds for single course_seat orders
- Fulfillment processing for seat_pack orders (up to 500 seats) p95 latency MUST be <= 60 seconds
- Admin API list endpoints p95 latency MUST be <= 300ms with up to 1 million orders in the database
- The system MUST support at least 100 concurrent checkout sessions without degradation
- Database queries MUST use appropriate indexes on: `tenant_id`, `buyer_email`, `stripe_checkout_session_id`, `stripe_payment_intent_id`, `stripe_event_id`, `status`, `created_at`

#### Reliability

- The Purchase Gateway API MUST have a readiness probe (`/ready/`) and liveness probe (`/health/`)
- The system MUST be available 99.95% of the time (measured monthly, excluding planned maintenance)
- Webhook processing MUST guarantee at-least-once delivery with idempotent handling (exactly-once semantics from the business logic perspective)
- The fulfillment worker MUST process jobs from a durable Redis queue (not an in-memory queue) to survive worker restarts
- Failed fulfillment jobs MUST be moved to a dead letter queue after max retries are exhausted
- The system MUST recover from worker crashes without losing pending fulfillment jobs (Redis persistence)
- Database writes for order creation and fulfillment MUST use transactions to ensure atomicity

#### Security

- The system MUST NOT handle, store, or log credit card numbers, CVVs, or any PCI-scoped data (all card data handled by Stripe Checkout)
- Stripe webhook signatures MUST be verified on every webhook request using the HMAC-SHA256 algorithm
- The webhook signing secret MUST be stored in K8s secrets via ExternalSecrets (never hardcoded)
- Admin API endpoints MUST enforce JWT authentication and role-based access control
- Public API endpoints MUST implement rate limiting: 30 requests/minute per IP for checkout creation, 1000 requests/minute for webhook endpoint (Stripe sends bursts)
- Entitlement claim tokens MUST be cryptographically random, URL-safe, and at least 32 characters
- Claim tokens MUST NOT be guessable or enumerable
- The system MUST NOT log full Stripe event payloads in application logs (they contain PII); only event ID, type, and processing status MAY be logged. Full payloads are stored in the `stripe_events` database table only
- Database credentials MUST use a unique password for the gateway's PostgreSQL database
- All inter-service communication within the cluster MUST use K8s Service DNS
- The system MUST validate and sanitize all input parameters on public endpoints to prevent injection attacks
- The system MUST enforce CORS restrictions on public API endpoints (only allow configured origins)
- Stripe API keys MUST use restricted keys with only the permissions needed (Checkout Sessions, Payment Intents, Customers, Refunds, Webhooks)

#### Data Integrity

- The system MUST maintain the invariant: every `paid` order has a corresponding `stripe_payment_intent_id` that can be verified against Stripe
- The system MUST maintain the invariant: every `fulfilled` line item has a corresponding enrollment in the LMS (verifiable via Enrollment API)
- The system MUST maintain the invariant: every `refunded` order has a corresponding refund record in Stripe
- The system MUST support a reconciliation job that compares gateway orders against Stripe payment records and flags discrepancies
- The reconciliation job SHOULD run daily and report results to the finance dashboard

---

## Acceptance Criteria

### Checkout Flow

- [ ] AC-001: Given a valid offering UUID and buyer email, when `POST /api/v1/checkout/` is called, then a Stripe Checkout Session is created and the response includes a `checkout_url` that redirects to Stripe
- [ ] AC-002: Given a buyer with an existing LMS account completes Stripe Checkout, when the `checkout.session.completed` webhook fires, then the buyer is enrolled in the course within 30 seconds
- [ ] AC-003: Given a buyer without an LMS account completes Stripe Checkout, when the `checkout.session.completed` webhook fires, then an entitlement is created and an invitation email is sent to the buyer
- [ ] AC-004: Given an expired Stripe Checkout Session, when the `checkout.session.expired` webhook fires, then the order status transitions to `expired` and no fulfillment occurs
- [ ] AC-005: Given a buyer cancels at Stripe Checkout, when they return to the cancel URL, then the order status remains `pending` (Stripe may expire it later) and no fulfillment occurs

### Webhook Handling

- [ ] AC-006: Given a webhook request with a valid Stripe signature, when the gateway receives it, then HTTP 200 is returned within 500ms and the event is logged in `stripe_events`
- [ ] AC-007: Given a webhook request with an invalid signature, when the gateway receives it, then HTTP 400 is returned and the event is NOT logged
- [ ] AC-008: Given the same Stripe event ID is received twice (retry), when the gateway processes it, then the second processing is a no-op and no duplicate order or enrollment is created
- [ ] AC-009: Given a `checkout.session.completed` event for a multi-tenant order (Stripe Connect), when the gateway processes it, then the order is associated with the correct tenant

### Entitlement and Invitation

- [ ] AC-010: Given an unclaimed entitlement with a valid claim token, when an authenticated user visits `/api/v1/claim/{token}`, then the entitlement is fulfilled (enrollment created) and status is set to `claimed`
- [ ] AC-011: Given an unclaimed entitlement with a valid claim token, when an unauthenticated user visits `/api/v1/claim/{token}`, then they are redirected to the LMS login/registration page with a return URL to the claim endpoint
- [ ] AC-012: Given a claim token that has expired (past `expires_at`), when a user visits the claim URL, then a clear error message is returned indicating the entitlement has expired
- [ ] AC-013: Given a claimed entitlement, when the same claim token is visited again, then the response indicates the entitlement has already been claimed (no duplicate enrollment)
- [ ] AC-014: Given an enterprise admin with 100 seat pack entitlements, when `POST /admin/api/v1/entitlements/assign/` is called with 50 email addresses, then 50 entitlements are assigned and invitation emails are sent

### Refund and Dispute

- [ ] AC-015: Given a fulfilled order, when a full refund is processed in Stripe and the `charge.refunded` webhook fires, then the order status transitions to `refunded` and the enrollment is deactivated in the LMS within 5 minutes
- [ ] AC-016: Given a fulfilled order, when a partial refund is processed in Stripe, then the order status transitions to `partially_refunded` and no enrollment is automatically revoked
- [ ] AC-017: Given a fulfilled order, when a `charge.dispute.created` webhook fires, then the order status transitions to `disputed` and an alert is fired to the finance channel
- [ ] AC-018: Given a disputed order where the merchant wins (`charge.dispute.closed` with `status=won`), then the order status is restored to its pre-dispute state and no enrollments are revoked

### Fulfillment Retry

- [ ] AC-019: Given a fulfillment job that fails due to LMS API returning HTTP 503, when the worker retries, then it retries up to 10 times with exponential backoff (5s, 10s, 20s, 40s, ...)
- [ ] AC-020: Given a fulfillment job that fails all 10 retries, when the max retries are exhausted, then the order transitions to `fulfillment_failed`, the job is moved to the dead letter queue, and a Critical alert is fired
- [ ] AC-021: Given a fulfillment job for a user already enrolled in the course (LMS returns 409), when the worker processes it, then the line item is marked as `fulfilled` (idempotent) and no error is logged

### Enterprise Features

- [ ] AC-022: Given an enterprise tenant with a subscription, when `invoice.paid` fires for a renewal, then seat pack entitlements are replenished for the new billing period
- [ ] AC-023: Given an enterprise tenant whose subscription payment fails, when `invoice.payment_failed` fires, then a grace period begins and the admin is notified. No access is revoked during the grace period
- [ ] AC-024: Given an enterprise admin for tenant A, when they call `GET /admin/api/v1/orders/`, then only orders for tenant A are returned (zero orders from tenant B)

### Multi-Tenant Isolation

- [ ] AC-025: Given tenants A and B, when admin A calls any admin API endpoint, then zero records from tenant B are returned
- [ ] AC-026: Given tenants A and B using Stripe Connect, when a webhook fires for tenant A's connected account, then the event is processed in tenant A's context only

### Migration

- [ ] AC-027: Given the Purchase Gateway is deployed alongside the legacy ecommerce service, when a new purchase is initiated, then it routes to the Purchase Gateway (not the legacy service)
- [ ] AC-028: Given all in-flight orders in the legacy ecommerce system have completed, when the decommission script runs, then the legacy ecommerce Deployment, Service, DNS records, and OAuth2 clients are removed

### Observability

- [ ] AC-029: Given the gateway is running, when `/metrics/` is scraped by Prometheus, then purchase-specific metrics (checkout count, fulfillment duration, webhook processing time) are present
- [ ] AC-030: Given a fulfillment failure occurs, when the error is logged, then the log entry includes `order_uuid`, `tenant_id`, `offering_type`, `lms_resource_id`, `error_type`, and `buyer_email_hash` (not raw email)

### Health and Deployment

- [ ] AC-031: Given the gateway Deployment is applied, when `kubectl get deployments -n mereka-lms -l app.kubernetes.io/name=payments-gateway` is run, then the deployment shows READY replicas >= 1
- [ ] AC-032: Given the gateway worker Deployment is applied, when `kubectl get deployments -n mereka-lms -l app.kubernetes.io/name=payments-worker` is run, then the deployment shows READY replicas >= 1
- [ ] AC-033: Given the gateway is running, when `curl http://payments-gateway:8000/health/` is called from within the cluster, then the response is HTTP 200 with `{"status": "ok", "database": "ok", "redis": "ok", "stripe": "ok"}`
- [ ] AC-034: Given the service is deployed, its domain MUST use DNS-only Cloudflare mode with Let's Encrypt SSL (not Cloudflare proxy)

---

## Edge Cases

### Payment Edge Cases

- **Checkout session created but user never completes**: Stripe Checkout Sessions expire after a configurable period (default: 24 hours). The `checkout.session.expired` event MUST transition the order to `expired`. No fulfillment occurs. The offering seat/inventory is not reserved during checkout (Stripe handles this scenario by design)
- **Duplicate webhook delivery**: Stripe may deliver the same event multiple times (network retry). The system MUST use `stripe_event_id` as an idempotency key. The `stripe_events` table has a unique constraint on `stripe_event_id`. Processing an already-processed event MUST be a no-op (return HTTP 200 to Stripe, skip fulfillment)
- **Webhook arrives before checkout redirect completes**: In rare cases, the Stripe webhook may arrive at the gateway before the buyer's browser is redirected to the success URL. The system MUST handle this gracefully: the order status is updated asynchronously regardless of whether the buyer has reached the success page. The success page polls `/api/v1/checkout/{session_id}/status/` to display the current order state
- **Stripe API outage during checkout creation**: If the Stripe API is unreachable when creating a Checkout Session, the system MUST return HTTP 503 to the buyer with a user-friendly error message. The pending order record is NOT created (fail before creating state). The buyer can retry
- **Currency mismatch**: If the offering currency does not match the Stripe account's default currency, Stripe handles multi-currency natively. The system MUST store the actual charged amount and currency from the Stripe event payload, not the offering's configured price (handles conversion differences)
- **Zero-amount checkout**: For free offerings (price_cents = 0), the system MUST use Stripe Checkout in `payment` mode with a zero-amount Price or skip Stripe Checkout entirely and create the order as `paid` immediately, proceeding directly to fulfillment

### Fulfillment Edge Cases

- **LMS user lookup race condition**: Between webhook receipt and fulfillment processing, the user may register or be deleted. The fulfillment worker MUST perform the user lookup at fulfillment time (not at checkout creation time). If the user exists at fulfillment time, proceed with enrollment. If not, create an entitlement
- **Course unpublished between purchase and fulfillment**: If the LMS Enrollment API returns 404 for the course, the system MUST mark the line item as `failed`, transition the order to `fulfillment_failed`, and alert the ops team. An automatic refund SHOULD NOT be issued (admin decision required -- the course may be temporarily unavailable)
- **Program with zero active course runs**: If a program offering is purchased but the program has no active course runs at fulfillment time, the system MUST create an entitlement for the program (not individual course enrollments) and notify the buyer that enrollment will occur when course runs become available
- **Worker crash mid-fulfillment**: If the worker crashes after enrolling in 2 of 3 courses in a program, the retry logic MUST check each course enrollment individually (idempotent per-course check via Enrollment API) and only attempt enrollments that have not yet been created
- **Redis queue full**: If the Redis queue reaches capacity (configurable max length), new fulfillment jobs MUST be rejected and the order MUST remain in `paid` state. An alert MUST fire. A cron job SHOULD periodically scan for `paid` orders older than 5 minutes and re-enqueue their fulfillment

### Entitlement Edge Cases

- **Claim token used by wrong email**: If user A claims a token that was sent to user B's email, the system MUST allow it (the claim token is the authorization, not the email). This enables forwarding of purchase links. The entitlement record MUST log both `recipient_email` (original) and `claimed_by_user_id` (actual claimer)
- **Claim token claimed during registration**: If a user clicks the claim link, gets redirected to registration, and the registration takes several minutes, the claim token MUST remain valid. The `expires_at` MUST be checked at claim time (POST), not at redirect time (GET)
- **Multiple entitlements for same email and offering**: For seat packs, the same email MAY be assigned multiple entitlements for different offerings. For the same offering, assigning the same email MUST be idempotent (same entitlement returned, not a duplicate)
- **Entitlement expires with user registered but not claimed**: If a user registered independently (not via the claim link) and has an entitlement that expires, the system MUST NOT auto-fulfill. The entitlement requires explicit claiming. However, a reconciliation job SHOULD identify these cases and notify the buyer before expiration (7-day warning email)
- **Bulk assignment with mixed valid and invalid emails**: For enterprise bulk assignment, the system MUST validate all email addresses before creating any entitlements. If any email is malformed, the entire batch MUST be rejected (all-or-nothing)

### Refund Edge Cases

- **Refund for order with claimed entitlements**: If a full refund is processed for an order with claimed entitlements, the system MUST revoke the entitlements and deactivate the corresponding enrollments. Unclaimed entitlements are simply revoked (no enrollment to deactivate)
- **Partial refund ambiguity**: For orders with multiple line items, a partial refund from Stripe does not specify which line item is refunded. The system MUST NOT auto-revoke any specific enrollment on partial refund. Instead, it MUST transition the order to `partially_refunded` and require admin intervention to determine which enrollment (if any) to revoke
- **Refund after course completion**: If a refund is processed after the learner has completed the course and received a certificate, the enrollment MUST still be deactivated but the certificate record in the LMS MUST NOT be deleted (certificates are managed by the LMS, not the gateway). The system MUST log a warning for admin review
- **Dispute on Stripe Connect order**: Disputes on Stripe Connect must be handled on the connected account. The webhook MUST route the dispute to the correct tenant. The connected account's dispute liability (per Stripe Connect configuration) determines financial responsibility

### Rate Limiting

- Public checkout endpoint MUST return HTTP 429 with `Retry-After` header when rate limits are exceeded
- Webhook endpoint rate limiting MUST be generous (1000 req/min) to avoid rejecting legitimate Stripe retries. If rate limited, Stripe will retry with exponential backoff
- Admin API MUST use per-user rate limiting: 100 requests/minute per authenticated user

### Timeout

- Stripe Checkout Session creation timeout: 10 seconds. If exceeded, return HTTP 504 to the buyer
- LMS Enrollment API call timeout: 15 seconds per call. If exceeded, retry (counts as a failure for backoff purposes)
- Webhook processing acknowledgment: MUST return HTTP 200 within 5 seconds. If processing takes longer, acknowledge first and process in the background (which is the standard async architecture)

### Idempotency Summary

| Operation | Idempotency Key | Behavior on Duplicate |
|-----------|----------------|-----------------------|
| Webhook processing | `stripe_event_id` | Skip (no-op, return HTTP 200) |
| Enrollment creation | `(user_id, course_id)` | LMS returns 409, treat as success |
| Entitlement creation | `(order_uuid, line_item_uuid)` | Return existing entitlement |
| Entitlement claim | `claim_token` | Return "already claimed" |
| Entitlement assignment (bulk) | `(email, offering_uuid)` | Return existing entitlement |
| Refund initiation | `(order_uuid, stripe_refund_id)` | Skip (refund already recorded) |
| Order creation | `stripe_checkout_session_id` | Return existing order |

### Partial Failures

- **Fulfillment of multi-course program**: If 2 of 5 course enrollments succeed and the 3rd fails, the order transitions to `partially_fulfilled`. The worker MUST continue attempting remaining enrollments. After all retries for failed enrollments are exhausted, the final state reflects the partial fulfillment. The admin can manually retry individual line items
- **Bulk entitlement assignment**: All-or-nothing within a single batch. If any email validation fails, zero entitlements are created. The response MUST include the specific validation errors

---

## Observability

### Logs

- **Gateway API**: Structured JSON logs to stdout, captured by Promtail and shipped to Loki. Every log line MUST include: `service_name: "payments-gateway"`, `tenant_id` (when in request context), `request_id` (correlation ID from X-Request-ID header or generated UUID), `log_level`, `timestamp`
- **Gateway Worker**: Structured JSON logs to stdout. Every log line MUST include: `service_name: "payments-worker"`, `tenant_id`, `job_id`, `order_uuid` (when processing a fulfillment), `log_level`, `timestamp`
- **Checkout events**: MUST log: `event: "checkout_created"`, `order_uuid`, `tenant_id`, `offering_uuid`, `buyer_email_hash` (SHA-256 of email), `offering_type`
- **Webhook events**: MUST log: `event: "webhook_received"`, `stripe_event_id`, `event_type`, `processing_status`. MUST NOT log: webhook payload, Stripe customer details, email addresses
- **Fulfillment events**: MUST log: `event: "fulfillment_attempt"`, `order_uuid`, `line_item_uuid`, `offering_type`, `lms_resource_id`, `attempt_number`, `outcome` (success, retry, failed), `error_message` (if failed), `duration_ms`
- **Entitlement events**: MUST log: `event: "entitlement_created"/"entitlement_claimed"/"entitlement_revoked"`, `entitlement_uuid`, `order_uuid`, `tenant_id`, `offering_type`, `recipient_email_hash`
- **Refund events**: MUST log: `event: "refund_processed"`, `order_uuid`, `stripe_refund_id`, `refund_type` (full, partial), `amount_cents`, `enrollment_revoked` (boolean)
- **Sensitive data rule**: MUST NOT log: raw email addresses (use SHA-256 hash), Stripe API keys, webhook signing secrets, claim tokens (log first 8 characters only for debugging), full webhook payloads, credit card data (should never exist in the system)

### Metrics

- `purchase_gateway_checkouts_total` (counter, labels: `tenant_id`, `offering_type`, `outcome` [created, stripe_error, validation_error])
- `purchase_gateway_checkout_latency_seconds` (histogram, labels: `tenant_id`)
- `purchase_gateway_webhooks_received_total` (counter, labels: `event_type`, `tenant_id`, `processing_status` [processed, duplicate, failed, signature_invalid])
- `purchase_gateway_webhook_processing_duration_seconds` (histogram, labels: `event_type`)
- `purchase_gateway_fulfillments_total` (counter, labels: `tenant_id`, `offering_type`, `outcome` [success, retry, failed, idempotent])
- `purchase_gateway_fulfillment_duration_seconds` (histogram, labels: `offering_type`)
- `purchase_gateway_fulfillment_retries_total` (counter, labels: `tenant_id`, `offering_type`)
- `purchase_gateway_orders_total` (counter, labels: `tenant_id`, `status`)
- `purchase_gateway_orders_by_status` (gauge, labels: `tenant_id`, `status`) -- current count per status
- `purchase_gateway_entitlements_total` (counter, labels: `tenant_id`, `status` [pending, claimed, expired, revoked])
- `purchase_gateway_entitlements_unclaimed` (gauge, labels: `tenant_id`) -- current unclaimed count
- `purchase_gateway_refunds_total` (counter, labels: `tenant_id`, `refund_type` [full, partial])
- `purchase_gateway_disputes_total` (counter, labels: `tenant_id`, `outcome` [created, won, lost])
- `purchase_gateway_revenue_cents_total` (counter, labels: `tenant_id`, `currency`) -- total revenue processed
- `purchase_gateway_lms_api_requests_total` (counter, labels: `endpoint`, `status_code`)
- `purchase_gateway_lms_api_latency_seconds` (histogram, labels: `endpoint`)
- `purchase_gateway_stripe_api_requests_total` (counter, labels: `endpoint`, `status_code`)
- `purchase_gateway_stripe_api_latency_seconds` (histogram, labels: `endpoint`)
- `purchase_gateway_queue_depth` (gauge) -- current number of pending fulfillment jobs in Redis
- `purchase_gateway_dead_letter_queue_depth` (gauge) -- current number of jobs in the dead letter queue
- `purchase_gateway_reconciliation_discrepancies` (gauge, labels: `discrepancy_type` [missing_enrollment, missing_refund, status_mismatch])

### Alerts

- **Critical**: `purchase_gateway_dead_letter_queue_depth` > 0 -- page oncall (fulfillment failures requiring manual intervention)
- **Critical**: Gateway health check fails for > 2 consecutive checks (30 seconds) -- page oncall
- **Critical**: `purchase_gateway_webhooks_received_total{processing_status="signature_invalid"}` > 5 in 5 minutes -- potential attack or misconfigured webhook secret
- **Critical**: `purchase_gateway_fulfillments_total{outcome="failed"}` rate exceeds 5% of total fulfillments over 15 minutes -- systemic fulfillment failure
- **Warning**: `purchase_gateway_queue_depth` > 100 -- fulfillment backlog building up
- **Warning**: `purchase_gateway_fulfillment_duration_seconds` p95 > 30 seconds -- LMS API degradation
- **Warning**: `purchase_gateway_lms_api_requests_total{status_code=~"5.."}` rate exceeds 10% over 5 minutes -- LMS service issues
- **Warning**: `purchase_gateway_entitlements_unclaimed` > 500 for any tenant -- possible email delivery issues
- **Warning**: `purchase_gateway_disputes_total{outcome="created"}` > 2 in 24 hours for any tenant -- elevated dispute rate
- **Info**: `purchase_gateway_reconciliation_discrepancies` > 0 -- daily reconciliation found issues (notify finance team)
- **Info**: `purchase_gateway_orders_by_status{status="fulfillment_failed"}` > 0 -- orders stuck in failed state

### Dashboards

- **Purchase Gateway Overview**: Total orders by status, revenue by tenant, checkout success rate, fulfillment success rate, webhook processing rate, queue depth, dead letter queue depth
- **Fulfillment Health**: Fulfillment latency percentiles (p50, p95, p99), retry rate, failure rate by offering type, LMS API response time, LMS API error rate
- **Revenue Dashboard**: Revenue by tenant (daily, weekly, monthly), refund rate, dispute rate, average order value, top offerings by revenue
- **Entitlement Tracker**: Unclaimed entitlements by tenant, claim rate, expiring entitlements (next 7 days), invitation email delivery success rate
- **Webhook Monitor**: Events received by type, processing latency, duplicate event rate, signature failure count, event processing queue depth
- **Reconciliation Report**: Daily discrepancy count, discrepancy types, last reconciliation run timestamp, trend over 30 days

### Payment-Specific Metrics

- `gateway_payment_duration_seconds` (histogram, labels: `provider`, `status`) -- Payment processing latency by provider and outcome
- `gateway_payment_total` (counter, labels: `provider`, `currency`, `status`) -- Payment attempt count by provider, currency, and status
- `gateway_payment_amount_usd` (counter, labels: `provider`, `currency`) -- Payment amount in USD equivalent
- `gateway_webhook_processing_duration_seconds` (histogram, labels: `event_type`) -- Webhook processing latency by event type
- `gateway_refund_total` (counter, labels: `provider`, `reason`, `status`) -- Refund count by provider, reason, and status
- `gateway_active_subscriptions` (gauge, labels: `plan_type`) -- Active subscription count by plan type
- `payment_success_rate` (gauge, labels: `tenant_id`, `offering_type`) -- successful payments / total payment attempts
- `payment_processing_duration_seconds` (histogram, labels: `tenant_id`, `currency`) -- time from checkout creation to payment confirmation
- `refund_processing_duration_seconds` (histogram, labels: `tenant_id`, `refund_type`) -- time from refund initiation to enrollment revocation
- `cart_abandonment_rate` (gauge, labels: `tenant_id`, `offering_type`) -- checkout sessions created but not completed
- `revenue_per_tenant` (gauge, labels: `tenant_id`, `currency`) -- total revenue by tenant (rolling 30 days)

### Payment-Specific Alerts

- **Critical**: `payment_success_rate` < 98% for any tenant over 15 minutes -- page oncall (payment processing failure)
- **Critical**: `purchase_gateway_webhooks_received_total{processing_status="failed"}` > 0 for Stripe webhook delivery failures sustained over 10 minutes -- page oncall (revenue loss risk)
- **Warning**: `refund_processing_duration_seconds` p95 > 24 hours -- notify finance team (slow refund processing)
- **Info**: `cart_abandonment_rate` > 50% for any tenant over 7 days -- notify product team (UX friction in checkout)

### Payment Health Dashboard

- **Payment Processing**: Request latency (p50/p95/p99), success rate by provider, error rate breakdown
- **Webhook Processing**: Delivery rate by event type, processing latency, failure count with reasons
- **Payment Success Rate**: 7-day rolling success rate by tenant, offering type, and payment method
- **Processing Times**: Checkout latency, payment confirmation latency, refund processing time percentiles
- **Revenue Tracking**: Daily revenue by tenant, currency breakdown, top-performing offerings, refund rate trend
- **Stripe Webhook Health**: Delivery success rate, processing latency, event types received, signature validation failures

Logs MUST be structured JSON and MUST NOT log card numbers or unmasked card data. Card last 4 digits MUST be masked with `****` in logs.

---

## Rollout & Rollback

### Rollout Plan

#### Phase 0: Infrastructure Preparation (Week 1-2)

1. Provision PostgreSQL database (Cloud SQL PostgreSQL instance or in-cluster PostgreSQL)
2. Create database user with grants limited to the `payments_gateway` database
3. Provision all gateway secrets in Infisical at `/k8s/mereka-lms`:
   - `MEREKA_LMS_PAYMENTS_GATEWAY_SECRET_KEY` (application secret key)
   - `MEREKA_LMS_PAYMENTS_GATEWAY_DB_PASSWORD` (PostgreSQL password)
   - `MEREKA_LMS_PAYMENTS_GATEWAY_OAUTH2_SECRET` (LMS OAuth2 client secret)
   - `MEREKA_LMS_STRIPE_SECRET_KEY` (existing, used by gateway; see `specs/secrets-management_spec.md`)
   - `MEREKA_LMS_STRIPE_PUBLISHABLE_KEY` (existing, used by frontend; see `specs/secrets-management_spec.md`)
   - `MEREKA_LMS_STRIPE_WEBHOOK_SECRET` (existing, used by gateway; see `specs/secrets-management_spec.md`)
4. Sync secrets to GCP Secret Manager
5. Create ExternalSecret manifest (`payments-gateway-secrets`)
6. Register OAuth2 client application in LMS Django admin: client ID `payments-gateway`, grant type `client-credentials`
7. Build gateway Docker images and push to Artifact Registry
8. Create K8s manifests: Deployment (API), Deployment (worker), Service, ConfigMap, HPA, PodDisruptionBudget

#### Phase 1: Gateway Deployment (Shadow Mode) (Week 3-4)

1. Deploy `payments-gateway` API and `payments-worker` Deployments
2. Run database migrations via init container
3. Verify health endpoint and Prometheus scraping
4. Configure Stripe webhook endpoint for the gateway URL (`/webhooks/stripe/`)
5. Run the gateway in shadow mode: receiving webhooks and logging events but NOT performing fulfillment (feature flag `ENABLE_GATEWAY_FULFILLMENT=false`)
6. Verify webhook signature verification is working (test with Stripe CLI or test-stripe-webhook-delivery.sh adapted for the new endpoint)
7. Verify Stripe event logging in the `stripe_events` table
8. Create test offerings pointing to test courses

#### Phase 2: Internal Testing (Week 5-6)

1. Enable fulfillment for test offerings only (feature flag `GATEWAY_ALLOWED_OFFERINGS` whitelist)
2. Complete end-to-end test: create checkout, complete payment (Stripe test mode), verify enrollment in LMS
3. Test the entitlement/invitation flow: purchase as non-registered user, receive invitation email, claim entitlement
4. Test refund flow: process refund in Stripe dashboard, verify enrollment revocation
5. Test enterprise seat pack: create seat pack offering, purchase, bulk assign entitlements, verify claims
6. Load test: 50 concurrent checkouts, verify no race conditions or duplicate enrollments
7. Test failure scenarios: LMS API down, webhook signature mismatch, expired checkout, claim token expiry
8. Run reconciliation job and verify zero discrepancies

#### Phase 3: Soft Launch (Week 7-8)

1. Enable fulfillment for all offerings (`ENABLE_GATEWAY_FULFILLMENT=true`)
2. Configure Caddy routing: new purchase URLs (`/purchase/*`) route to the gateway
3. Update frontend buy buttons to use the new gateway checkout endpoint (behind feature flag `ENABLE_NEW_CHECKOUT`)
4. Roll out `ENABLE_NEW_CHECKOUT` to 10% of users (A/B test via frontend feature flag)
5. Monitor: checkout success rate, fulfillment latency, error rate, revenue match between gateway and Stripe dashboard
6. If metrics are healthy after 48 hours, increase to 50%, then 100%

#### Phase 4: Legacy Ecommerce Decommission (Week 9-10)

1. Stop routing new purchases to the legacy ecommerce service
2. Monitor legacy ecommerce for in-flight orders (orders in `pending` or `fulfilling` state)
3. Wait for all in-flight orders to complete (or manually resolve stuck orders)
4. Run decommission verification script: confirm zero active orders in legacy system
5. Scale legacy ecommerce Deployment to 0 replicas
6. Remove legacy ecommerce DNS records from Caddy configuration
7. Disable legacy ecommerce OAuth2 clients in LMS Django admin
8. Archive legacy ecommerce secrets in Infisical (mark as deprecated, do not delete for 90 days)
9. Remove legacy ecommerce K8s manifests from deploy/k8s/base/
10. Import historical order data from legacy MySQL database into gateway PostgreSQL (for reporting continuity)
11. Update `scripts/shared/config.sh` to remove `ECOMMERCE_DOMAIN` and `DEV_ECOMMERCE_DOMAIN`
12. Update all documentation referencing the legacy ecommerce service

#### Phase 5: Production Hardening (Week 11-12)

1. Enable all alerts and dashboards
2. Enable daily reconciliation job
3. Load test: 100 concurrent checkouts in production (Stripe live mode with test amounts and immediate refunds)
4. Security review: OWASP Top 10 audit on gateway API, webhook signature bypass attempts, rate limit bypass attempts
5. Enable enterprise features: seat packs, subscriptions, multi-tenant Stripe Connect
6. Onboard first enterprise tenant with a subscription
7. Document operational runbook (`docs/runbooks/purchase-gateway-runbook.md`)

### Feature Flags

- `ENABLE_GATEWAY_FULFILLMENT` -- gate whether the worker actually performs enrollments (default: off during shadow mode)
- `GATEWAY_ALLOWED_OFFERINGS` -- whitelist of offering UUIDs allowed for fulfillment (empty = all allowed; used during testing)
- `ENABLE_NEW_CHECKOUT` -- gate frontend routing to the new gateway checkout (default: off; percentage rollout)
- `ENABLE_ENTITLEMENT_INVITATIONS` -- gate invitation email sending (default: on; disable if email delivery issues)
- `ENABLE_ENTERPRISE_SUBSCRIPTIONS` -- gate Stripe Subscription handling (default: off until Phase 5)
- `ENABLE_AUTO_REVOKE_ON_DISPUTE` -- gate automatic enrollment revocation on dispute (default: off; admin manual action)
- `ENABLE_RECONCILIATION_JOB` -- gate daily reconciliation cron job (default: off until Phase 5)

### Backward Compatibility

- During the dual-running period, both the legacy ecommerce service and the Purchase Gateway MUST be operational
- Existing bookmarks and links to the legacy ecommerce dashboard MUST redirect to a "service migrated" page with a link to the new admin UI
- Existing Stripe webhooks configured for the legacy endpoint MUST continue to function until the legacy service is decommissioned
- A new Stripe webhook endpoint MUST be configured for the gateway (separate endpoint, separate signing secret) -- NOT shared with the legacy endpoint
- Historical order data from the legacy system MUST be importable for reporting continuity
- Existing course catalogs and pricing configured in the legacy ecommerce admin MUST be re-created as offerings in the gateway (migration script required)

### Rollback Steps

#### Gateway API Rollback

1. Scale `payments-gateway` Deployment to 0 replicas: `kubectl scale deployment payments-gateway -n mereka-lms --replicas=0`
2. If the legacy ecommerce service is still running, re-enable routing to it (update Caddy config or feature flag)
3. If the legacy ecommerce service has been decommissioned, scale it back up: `kubectl scale deployment ecommerce -n mereka-lms --replicas=1`
4. Re-enable legacy ecommerce DNS records in Caddy
5. Switch frontend buy buttons back to legacy checkout (toggle `ENABLE_NEW_CHECKOUT=false`)
6. Investigate the issue using Loki logs and Grafana dashboards
7. Fix and redeploy when ready

#### Gateway Worker Rollback

1. Scale `payments-worker` Deployment to 0 replicas
2. Pending fulfillment jobs remain in the Redis queue (durable)
3. Orders in `paid` state are not fulfilled until the worker is restored
4. Monitor `purchase_gateway_queue_depth` metric -- it will grow
5. When the worker is restored, it resumes processing from the queue
6. For urgent fulfillments during worker downtime, manually enroll via LMS Django admin

#### Database Rollback

1. Gateway PostgreSQL is independent of the LMS MySQL database
2. If the gateway database is corrupted, restore from the latest Cloud SQL backup
3. Orders may need reconciliation against Stripe records after restoration
4. The LMS continues operating normally during gateway database restoration

#### Stripe Webhook Rollback

1. In the Stripe Dashboard, disable the gateway webhook endpoint
2. If the legacy ecommerce webhook is still active, Stripe delivers to that endpoint
3. If both are disabled, Stripe queues events for up to 3 days and retries
4. Re-enable the appropriate webhook endpoint when the issue is resolved

#### Full Stack Rollback (Emergency)

1. Scale both `payments-gateway` and `payments-worker` to 0
2. Re-enable legacy ecommerce service if available
3. Toggle `ENABLE_NEW_CHECKOUT=false` in frontend
4. All pending fulfillments in the gateway are paused
5. New purchases route to legacy ecommerce
6. After fix, scale gateway back up -- pending jobs in Redis are processed
7. Run reconciliation to verify no orders were lost during the outage

---

## Monorepo Location

All source code for the Purchase Gateway lives within this repository:

| Component | Path | Notes |
|-----------|------|-------|
| Gateway API server | `services/purchase-gateway/api/` | FastAPI application (Python) |
| Fulfillment worker | `services/purchase-gateway/worker/` | Async job processor |
| Database migrations | `services/purchase-gateway/migrations/` | Alembic (PostgreSQL) |
| Tests | `services/purchase-gateway/tests/` | pytest (unit + integration) |
| Dockerfile | `services/purchase-gateway/Dockerfile` | Multi-stage build |
| K8s manifests | `deploy/k8s/base/apps/purchase-gateway/` | Deployment, Service, HPA |
| ExternalSecrets | `deploy/k8s/base/secrets/external-secrets.yaml` | Stripe keys, DB credentials |

**Database**: PostgreSQL (Cloud SQL) — confirmed platform decision for new services requiring financial data integrity (see `specs/cross-cutting-requirements_spec.md`, Section 5: Technology Decisions).

---

## Open Questions

1. **PostgreSQL provisioning strategy**: Should we use Cloud SQL PostgreSQL (managed, higher cost, separate from the MySQL instance) or deploy PostgreSQL in-cluster (lower cost, requires ops burden)? Cloud SQL is preferred for production reliability but adds another managed database to the infrastructure. Need cost estimate and ops capacity assessment.

2. **Technology stack for the gateway service**: Should the gateway be built in Python/Django (consistent with Open edX ecosystem, team familiarity), Python/FastAPI (modern async, better performance for webhook handling), or Node.js/TypeScript (strong Stripe SDK support, excellent async primitives)? The choice affects developer velocity, hiring, and maintenance. Need team input.

3. **Claim URL UX**: Should the claim URL (`/purchase/claim/{token}`) be hosted on the gateway service or on the LMS? Hosting on the LMS provides a seamless registration-to-claim experience but requires an LMS plugin/middleware. Hosting on the gateway is simpler but creates a redirect chain (gateway -> LMS registration -> gateway claim). Need UX team input.

4. **Historical order import scope**: How much historical order data from the legacy ecommerce system should be imported? Options: (a) all orders ever, (b) last 12 months, (c) only active/uncompleted orders. Full import provides complete history but may include irrelevant data. Need finance team input on reporting requirements.

5. **Stripe Connect architecture**: For multi-tenant billing, should each tenant have a Stripe Connect Standard account (tenant manages their own Stripe dashboard) or Express account (platform manages, simpler)? Or should all tenants use the platform Stripe account with application fees and transfers? Each option has different compliance, revenue share, and operational implications. Need business/finance input.

6. **Enterprise subscription renewal UX**: When a subscription renews and new seat pack entitlements are created, should existing unclaimed entitlements from the previous period be rolled over or expired? Need product decision.

7. **Email delivery service**: Which service should send invitation emails? Options: (a) the LMS email pipeline (already configured, consistent branding), (b) a separate transactional email service (SendGrid, Postmark) from the gateway, (c) Stripe's built-in receipts for purchase confirmation + separate service for invitations. Need infrastructure/cost assessment.

8. **Admin UI**: Should the gateway have its own admin UI (React SPA), use Django admin (simpler but less polished), or integrate into the existing enterprise admin portal MFE? Need product/UX input.

9. **Coupon and discount strategy**: Stripe Checkout natively supports Promotion Codes (fixed or percentage discounts). Should we additionally support custom discount logic beyond what Stripe provides (e.g., enterprise-specific pricing tiers, volume discounts)? Or is Stripe's native promotion code system sufficient? Need product input.

10. **Free offering checkout bypass**: For offerings with `price_cents = 0`, should the system skip Stripe Checkout entirely (direct enrollment) or still route through Stripe Checkout (consistent UX, tracking, receipt)? Stripe Checkout requires `mode: "payment"` with at least one price > 0 unless using `setup` mode. Need product/engineering decision.

11. **Webhook retry window**: Stripe retries failed webhook deliveries for up to 3 days with exponential backoff. Should we implement our own event polling as a safety net (periodically query the Stripe Events API for events we may have missed)? This adds complexity but increases reliability. Need reliability assessment.

12. **Multi-item checkout (v2)**: The spec explicitly excludes multi-item shopping cart as a non-goal for v1. Should the database schema be designed to support it from day one (multiple line items per order) even if the v1 checkout only allows single-offering purchases? This is a schema design question that affects migration complexity later.
