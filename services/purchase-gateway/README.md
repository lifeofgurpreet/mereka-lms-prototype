# Purchase Gateway

Stripe-to-Open edX enrollment bridge. Replaces the deprecated Oscar/ecommerce service with a purpose-built payment and fulfillment gateway.

## Architecture

```
Browser → Stripe Checkout → Webhook → Purchase Gateway → Open edX Enrollment API
                                            │
                                            ├── PostgreSQL (orders, entitlements, events)
                                            └── Redis (fulfillment job queue)
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

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/v1/checkout/` | Public | Create Stripe Checkout Session |
| POST | `/webhooks/stripe/` | Stripe Signature | Receive Stripe webhook events |
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
