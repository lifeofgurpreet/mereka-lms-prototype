# Purchase Gateway

Stripe-to-Open edX enrollment bridge. Replaces the deprecated Oscar/ecommerce service with a purpose-built payment and fulfillment gateway.

## Architecture

```
Browser → Stripe Checkout → Webhook ACK
                                 │
                                 └── PostgreSQL durable outbox (fulfillment_jobs)
                                               │
                                               └── Background worker → Open edX Enrollment API
```

## Quick Start (Local)

```bash
cd services/purchase-gateway
docker compose up -d
```

The gateway will be available at `http://localhost:8080`.

## Configuration

All configuration via environment variables (see `app/config.py`):

| Variable | Required | Description |
|----------|----------|-------------|
| `DATABASE_URL` | Yes | PostgreSQL connection string |
| `REDIS_URL` | Yes | Redis connection string |
| `STRIPE_SECRET_KEY` | Yes | Stripe API secret key |
| `STRIPE_WEBHOOK_SECRET` | Yes | Stripe webhook signing secret |
| `LMS_BASE_URL` | Yes | Open edX LMS internal URL |
| `LMS_OAUTH_CLIENT_ID` | Yes | OAuth2 client ID for LMS |
| `LMS_OAUTH_CLIENT_SECRET` | Yes | OAuth2 client secret for LMS |
| `SECRET_KEY` | Yes | Application secret key |
| `ENABLE_GATEWAY_FULFILLMENT` | No | Enable fulfillment processing (default: false) |
| `TENANT_ISOLATION_ENABLED` | No | Enable multi-tenant isolation (default: true) |
| `FULFILLMENT_WORKER_ENABLED` | No | Run background outbox worker (default: true) |
| `FULFILLMENT_WORKER_POLL_SECONDS` | No | Poll cadence for pending jobs (default: 5s) |
| `FULFILLMENT_MAX_RETRIES` | No | Maximum durable retries per order (default: 10) |
| `FULFILLMENT_BASE_DELAY_SECONDS` | No | Exponential backoff base delay (default: 5s) |
| `ENABLE_RECONCILIATION_JOB` | No | Auto-detect paid-but-unfulfilled drift (default: false) |

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/v1/checkout/` | Public | Create Stripe Checkout Session |
| POST | `/webhooks/stripe/` | Stripe Signature | Receive Stripe webhook events |
| GET | `/api/v1/admin/stripe-events/` | `X-API-Key` | List/filter processed Stripe events for debugging |
| GET | `/api/v1/admin/offerings/` | `X-API-Key` | List/filter offerings by tenant, type, and active state |
| POST | `/api/v1/admin/entitlements/{entitlement_id}/resend-invitation/` | `X-API-Key` | Record invitation resend for pending entitlement |
| GET | `/api/v1/admin/orders/{order_id}/` | `X-API-Key` | Get detailed order view with line items, audit timeline, and fulfillment job |
| POST | `/api/v1/admin/orders/{order_id}/retry-fulfillment/` | `X-API-Key` | Force requeue fulfillment job for retryable orders |
| POST | `/api/v1/admin/orders/{order_id}/refund/` | `X-API-Key` | Initiate Stripe refund (order state updates asynchronously via webhook) |
| GET | `/api/v1/admin/entitlements/` | `X-API-Key` | List/filter entitlements by tenant, status, and recipient email |
| POST | `/api/v1/admin/entitlements/{entitlement_id}/revoke/` | `X-API-Key` | Revoke entitlement (idempotent) |
| GET | `/health/` | None | Liveness probe |
| GET | `/ready/` | None | Readiness probe |
| GET | `/metrics/` | None | Prometheus metrics |

## Database Migrations

```bash
# Run migrations
alembic upgrade head

# Create new migration
alembic revision --autogenerate -m "description"
```

## K8s Deployment

Manifests in `k8s/`:
- `deployment.yaml` — API server with init container for migrations
- `service.yaml` — ClusterIP service on port 8080
- `external-secrets.yaml` — Secrets from GCP Secret Manager
- `hpa.yaml` — Horizontal Pod Autoscaler (2-10 replicas, 70% CPU)

## Spec

Full specification: `specs/ecommerce-purchase-gateway_spec.md`

## Fulfillment Recovery Runbook

Operational replay and reconciliation procedures are documented in:

- `docs/operations/PURCHASE_GATEWAY_FULFILLMENT_RECOVERY.md`
