# Purchase Gateway Architecture
_Audience: Developers, Site Operators • Owner: Platform Team • Last updated: 2026-02-24_

The Purchase Gateway is the canonical ecommerce engine for Mereka Academy. It replaces the deprecated Oscar ecommerce service with a purpose-built FastAPI application that handles Stripe payments, course enrollment fulfillment, and subscription billing.

**Status**: Deployed to live cluster as dark launch (`ENABLE_GATEWAY_FULFILLMENT=false`). Oscar is fully deprecated and no longer referenced as an active service.

---

## Why We Replaced Oscar

Oscar (django-oscar) was the original Open edX ecommerce solution. The decision to replace it was driven by:

| Problem | Impact |
|---------|--------|
| Django monolith tightly coupled to LMS | Deployments required coordinated LMS restarts |
| Heavy dependency footprint (~200+ packages) | Build times 40+ min; container image ~1.8 GB |
| Synchronous request model | Stripe webhook processing blocked LMS workers |
| No multi-tenant isolation | Tenant A could access tenant B's orders (data leak risk) |
| No async fulfillment | Enrollment happened inline in the request cycle |
| Stripe integration via plugin | `ecommerce-worker` Celery app added 3 additional K8s pods |

The replacement is a standalone FastAPI service that is:
- Independently deployable and scalable
- Async from end to end (webhook → fulfillment)
- Tenant-isolated at the data model level
- Stripe-native with no adapter layer

**ADR reference**: Replacing Oscar was accepted as part of the Tier 5 ecommerce specification (`specs/ecommerce-purchase-gateway_spec.md`).

---

## Architecture Overview

```
Browser / MFE
     │
     │  HTTPS  /api/v1/checkout/
     ▼
Caddy (ingress)
     │
     │  HTTP
     ▼
┌─────────────────────────────────────────────┐
│          Purchase Gateway (FastAPI)          │
│  Port 8080 — gunicorn + UvicornWorker x2    │
│                                             │
│  /api/v1/checkout/   — create order + Stripe session
│  /webhooks/stripe/   — receive Stripe events
│  /api/v1/admin/      — operator tooling
│  /metrics            — Prometheus scrape
│  /health/            — DB + Redis + Stripe key check
│  /ready/             — lightweight readiness probe
└──────────────┬────────────────┬─────────────┘
               │                │
        ┌──────┘         ┌──────┘
        ▼                ▼
  PostgreSQL 16       Redis DB 14
  (postgresql-        (shared cluster Redis,
   payments)           isolated by DB index)
        │
        │  Alembic migrations on startup
        │  (init container)
```

**External integrations**:
- **Stripe**: Checkout Sessions API, Webhooks, Billing/Subscriptions API
- **LMS enrollment API**: `POST /api/enrollment/v1/enrollment` (OAuth2 client credentials)
- **GCP Secret Manager** (via ExternalSecrets Operator): 6 secrets pulled at pod start

---

## Service Structure

```
services/purchase-gateway/
├── app/
│   ├── main.py           — FastAPI app factory, router mounts, lifespan
│   ├── config.py         — Pydantic BaseSettings (all config from env vars)
│   ├── database.py       — SQLAlchemy async engine + session factory
│   ├── models/
│   │   ├── order.py      — Order, LineItem, OrderAuditLog, OrderStatus enum
│   │   ├── entitlement.py — Entitlement (claim token for unknown users)
│   │   ├── stripe_event.py — Idempotency store for Stripe webhook events
│   │   ├── offering.py   — Course/program offering catalog
│   │   └── subscription.py — Subscription model (Stripe Billing)
│   ├── routers/
│   │   ├── checkout.py   — POST /api/v1/checkout/ (create order + Stripe session)
│   │   ├── webhooks.py   — POST /webhooks/stripe/ (Stripe event receiver)
│   │   ├── subscriptions.py — Subscription management endpoints
│   │   ├── admin.py      — Admin/operator endpoints
│   │   └── health.py     — /health/ and /ready/
│   ├── services/
│   │   ├── stripe_service.py — Stripe API interaction layer
│   │   ├── fulfillment.py    — Enroll user or create entitlement after payment
│   │   ├── lms_client.py     — LMS enrollment + user lookup (httpx, OAuth2)
│   │   ├── refund.py         — Refund processing + enrollment revocation
│   │   ├── dispute.py        — Dispute handling + optional auto-revoke
│   │   └── subscription.py   — Subscription lifecycle handlers
│   └── middleware/
│       └── tenant.py     — Tenant resolution from request context
├── alembic/
│   └── versions/001_initial_schema.py  — orders, line_items, entitlements,
│                                          stripe_events, order_audit_log
├── k8s/
│   ├── deployment.yaml       — Deployment + init container (alembic migrate)
│   ├── service.yaml          — ClusterIP service on port 8080
│   ├── external-secrets.yaml — 6 secrets from GCP Secret Manager (bbi-k8 project)
│   ├── hpa.yaml              — HPA: 1–3 replicas at 70% CPU
│   ├── postgresql-deployment.yaml — In-cluster PostgreSQL 16
│   ├── postgresql-pvc.yaml   — 5 Gi PVC for PostgreSQL data
│   └── postgresql-service.yaml — ClusterIP for postgresql-payments
├── Dockerfile                — python:3.12-slim, non-root user (gateway), port 8080
└── pyproject.toml
```

---

## Webhook Flow

Stripe sends webhook events to `POST /webhooks/stripe/`. The handler is fully idempotent.

```
Stripe
  │
  │  POST /webhooks/stripe/
  │  Header: Stripe-Signature: t=...,v1=...
  ▼
stripe.Webhook.construct_event(payload, signature, STRIPE_WEBHOOK_SECRET)
  │
  ├── SignatureVerificationError → HTTP 400
  ├── ValueError (bad payload)  → HTTP 400
  │
  ▼
Check stripe_events table for existing stripe_event_id
  │
  ├── status=processed → return {"status": "duplicate"}  [idempotent]
  ├── status=failed    → retry (re-process the event)
  └── not found        → INSERT stripe_event (status=received)
          │
          │  IntegrityError (concurrent duplicate) → return {"status": "duplicate"}
          ▼
  UPDATE stripe_event status=processing
          │
          ▼
  Dispatch by event_type:
  ┌─────────────────────────────────────────────────────────┐
  │ checkout.session.completed    → mark paid, fulfill_order │
  │ checkout.session.expired      → mark expired             │
  │ payment_intent.payment_failed → mark canceled            │
  │ charge.refunded               → process_refund           │
  │ charge.dispute.created        → handle_dispute_created   │
  │ charge.dispute.closed         → handle_dispute_closed    │
  │ customer.subscription.*       → subscription handlers    │
  │ invoice.paid / payment_failed → invoice handlers         │
  └─────────────────────────────────────────────────────────┘
          │
          ├── success → UPDATE stripe_event status=processed, processed_at=now()
          └── error   → UPDATE stripe_event status=failed, raise (Stripe retries)
```

Every order status transition is recorded in `order_audit_log` with `old_status`, `new_status`, `triggered_by` (the Stripe event type), and optional details JSON.

---

## Order Lifecycle

```
pending
  │
  │  checkout.session.completed
  ▼
paid
  │
  │  fulfill_order() (ENABLE_GATEWAY_FULFILLMENT=true)
  ▼
fulfilling
  │
  ├── all items OK    → fulfilled
  ├── some items fail → partially_fulfilled
  └── all items fail  → fulfillment_failed

paid / fulfilled
  │
  ├── charge.refunded (full)     → refunded  (enrollments revoked)
  ├── charge.refunded (partial)  → partially_refunded
  ├── charge.dispute.created     → disputed  (optional auto-revoke)
  └── checkout.session.expired   → expired
```

Orders are scoped by `tenant_id` (UUID). All queries filter by tenant. The `TenantMixin` base class enforces the `tenant_id` column on every tenant-scoped model.

---

## Fulfillment Flow

After a payment succeeds, `fulfill_order()` is called for each line item:

```
For each line_item in order:
  │
  ├── fulfillment_status=fulfilled → skip (idempotent)
  │
  ▼
  GET /api/user/v1/accounts/?email=<buyer_email>
  │
  ├── User found in LMS
  │     └── POST /api/enrollment/v1/enrollment
  │           ├── success → line_item.status = fulfilled
  │           └── failure → line_item.status = failed
  │
  └── User NOT found in LMS
        └── Create Entitlement record:
              claim_token = secrets.token_urlsafe(32)
              expires_at  = now() + ENTITLEMENT_CLAIM_EXPIRY_DAYS (default: 30)
              status      = pending
              → line_item.status = fulfilled
              [invitation email sent separately by ENABLE_ENTITLEMENT_INVITATIONS flow]
```

Fulfillment is gated by the feature flag `ENABLE_GATEWAY_FULFILLMENT`. When `false` (current dark launch state), `fulfill_order()` logs and returns immediately without touching the LMS.

---

## Refund Flow

```
charge.refunded received
  │
  ├── order not found           → log warning, return
  ├── order.status = refunded   → skip (idempotent)
  │
  ▼
  amount_refunded >= amount (full refund)?
  │
  ├── yes → order.status = refunded
  │         _revoke_order_enrollments()
  │           └── POST /api/enrollment/v1/enrollment (is_active=false) per line_item
  │
  └── no  → order.status = partially_refunded
              (no enrollment revocation for partial refunds)

  order.refunded_at = now()
  audit_log: triggered_by = "stripe.charge.refunded"
```

---

## Dispute Flow

```
charge.dispute.created
  │
  ├── order not found              → log warning
  ├── order.status = disputed      → skip (idempotent)
  │
  ▼
  order.status = disputed
  if ENABLE_AUTO_REVOKE_ON_DISPUTE → _revoke_order_enrollments()
  audit_log: triggered_by = "stripe.charge.dispute.created"

charge.dispute.closed
  │
  ├── outcome = "won"  → order.status = paid
  │                       _restore_order_enrollments()
  └── outcome != "won" → order.status = refunded
                          order.refunded_at = now()
                          _revoke_order_enrollments()
  audit_log: triggered_by = "stripe.charge.dispute.closed"
```

`ENABLE_AUTO_REVOKE_ON_DISPUTE` defaults to `false`. When enabled, access is revoked immediately on dispute creation (before resolution). Not recommended for low-fraud merchants.

---

## K8s Deployment Topology

```
Namespace: mereka-lms
─────────────────────────────────────────────────────────────────

Deployment: payments-gateway
  Image: asia-southeast1-docker.pkg.dev/mereka-lms/openedx/payments-gateway:0.1.1
  Replicas: 1 (HPA min=1, max=3, CPU target=70%)
  Security: runAsUser=1000, allowPrivilegeEscalation=false
  Port: 8080
  Probes:
    liveness:  GET /health/   (20s delay, 15s period)
    readiness: GET /ready/    (10s delay, 10s period)

  Init container: migrate
    Command: python -m alembic upgrade head
    Runs before main container starts on every pod start

  Env vars injected:
    DATABASE_URL         ← payments-gateway-secrets (secretKeyRef)
    STRIPE_SECRET_KEY    ← payments-gateway-secrets (secretKeyRef)
    STRIPE_WEBHOOK_SECRET← payments-gateway-secrets (secretKeyRef)
    LMS_OAUTH_CLIENT_SECRET ← payments-gateway-secrets (secretKeyRef)
    SECRET_KEY           ← payments-gateway-secrets (secretKeyRef)
    REDIS_URL            = redis://redis:6379/14  (hardcoded, Redis DB 14)
    LMS_BASE_URL         = http://lms:8000
    LMS_PUBLIC_URL       = https://academyv2.mereka.io
    ENABLE_GATEWAY_FULFILLMENT = false  (dark launch)
    TENANT_ISOLATION_ENABLED   = true

Service: payments-gateway
  Type: ClusterIP
  Port: 8080

Deployment: postgresql-payments
  Image: postgres:16
  PVC: postgresql-payments-data (5 Gi)
  Database: payments_gateway
  User: payments

HPA: payments-gateway
  minReplicas: 1 / maxReplicas: 3
  CPU target: 70% averageUtilization
  Scale-down stabilization: 300s
```

---

## Secret Management

All secrets flow through the standard pipeline:

```
Infisical (source of truth)
  └── GCP Secret Manager (project: bbi-k8, NOT mereka-lms)
        └── ExternalSecrets Operator (ClusterSecretStore: gcp-secret-manager)
              └── K8s Secret: payments-gateway-secrets (namespace: mereka-lms)
                    └── Pods (via secretKeyRef in deployment.yaml)
```

The 6 GCP secrets (all prefixed `MEREKA_LMS_`):

| GCP Secret Manager Key | K8s Secret Key | Purpose |
|------------------------|----------------|---------|
| `MEREKA_LMS_PAYMENTS_GATEWAY_SECRET_KEY` | `SECRET_KEY` | FastAPI session signing |
| `MEREKA_LMS_PAYMENTS_GATEWAY_DATABASE_URL` | `DATABASE_URL` | PostgreSQL connection |
| `MEREKA_LMS_STRIPE_SECRET_KEY` | `STRIPE_SECRET_KEY` | Stripe API auth |
| `MEREKA_LMS_STRIPE_WEBHOOK_SECRET_GATEWAY` | `STRIPE_WEBHOOK_SECRET` | Webhook signature verification |
| `MEREKA_LMS_PAYMENTS_GATEWAY_OAUTH2_SECRET` | `LMS_OAUTH_CLIENT_SECRET` | LMS OAuth2 enrollment API |
| `MEREKA_LMS_PAYMENTS_GATEWAY_POSTGRESQL_PASSWORD` | `POSTGRESQL_PASSWORD` | PostgreSQL password |

**Important**: Secrets live in the `bbi-k8` GCP project, not `mereka-lms`. The ClusterSecretStore is configured with `projectID: bbi-k8`.

---

## Health Checks

`GET /health/` — comprehensive, used by liveness probe:
```json
{
  "status": "ok",
  "database": "ok",
  "redis": "ok",
  "stripe": "ok"
}
```
Returns HTTP 200 when all checks pass, HTTP 503 when any check is degraded. Stripe check only verifies key presence (no API call).

`GET /ready/` — lightweight, used by readiness probe:
```json
{"status": "ready"}
```
Always returns HTTP 200 if the process is alive.

`GET /metrics` — Prometheus scrape endpoint (prometheus-client ASGI app).

---

## Activating Production Mode

Purchase Gateway is deployed as a dark launch. To activate:

1. Set real Stripe live keys in GCP Secret Manager (`bbi-k8` project):
   - `MEREKA_LMS_STRIPE_SECRET_KEY` → `sk_live_...`
   - `MEREKA_LMS_STRIPE_WEBHOOK_SECRET_GATEWAY` → `whsec_...` (from Stripe dashboard)

2. Update the deployment to enable fulfillment:
   ```yaml
   - name: ENABLE_GATEWAY_FULFILLMENT
     value: "true"
   ```

3. Register a Stripe webhook endpoint pointing to:
   `https://academyv2.mereka.io/webhooks/stripe/`

   Required events:
   - `checkout.session.completed`
   - `checkout.session.expired`
   - `payment_intent.payment_failed`
   - `charge.refunded`
   - `charge.dispute.created`
   - `charge.dispute.closed`
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.paid`
   - `invoice.payment_failed`

4. Register LMS OAuth2 client for `payments-gateway` with the enrollment API scope.

5. Add Caddy route for external webhook access (if not already routing through ingress).

---

## Verification

Run the Stripe integration verification script:

```bash
# Offline (code + manifest checks)
./scripts/qa/verify-purchase-gateway-stripe.sh

# Online (includes live cluster health checks)
./scripts/qa/verify-purchase-gateway-stripe.sh --online
```

Related verification scripts:
- `scripts/qa/verify-purchase-gateway.sh` — comprehensive AC coverage
- `scripts/qa/verify-purchase-gateway-scaffold.sh` — file structure
- `scripts/qa/verify-purchase-gateway-models.sh` — data model fields
- `scripts/qa/verify-purchase-gateway-security.sh` — secrets hygiene + container security
- `scripts/qa/verify-purchase-gateway-k8s.sh` — K8s manifest validity
