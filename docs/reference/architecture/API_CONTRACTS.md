# API Contracts
_Audience: Developers, Integrators • Owner: Platform Team • Last updated: 2026-02-25_

Custom API surfaces for Mereka Academy. Standard Open edX REST APIs are not documented here — see [docs.openedx.org REST API reference](https://docs.openedx.org/en/latest/developers/references/internal_data_formats/index.html).

---

## 1. Purchase Gateway (FastAPI)

**Base URL**: `https://payments.academyv2.mereka.io`
**OpenAPI docs**: `GET /docs` (enabled when `DEBUG=true` — staging only; disabled in production)
**OpenAPI schema**: `GET /openapi.json` (always available, regardless of DEBUG)
**Auth**: Admin endpoints require `X-API-Key` header (HMAC-compared against `ADMIN_API_KEY` secret).
**Rate limits**: None configured at service layer; enforce via Cloudflare/ingress if needed.

### Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/health/` | None | Liveness: checks DB, Redis, Stripe key presence |
| `GET` | `/ready/` | None | Readiness probe (lightweight) |
| `POST` | `/api/v1/checkout/` | None | Create Stripe Checkout Session |
| `GET` | `/api/v1/checkout/{session_id}/status/` | None | Poll order status after checkout |
| `POST` | `/api/v1/subscriptions/` | Admin | Create enterprise subscription via Stripe |
| `GET` | `/api/v1/subscriptions/` | None (tenant-scoped) | List subscriptions |
| `GET` | `/api/v1/subscriptions/{id}` | None (tenant-scoped) | Get subscription detail |
| `PATCH` | `/api/v1/subscriptions/{id}` | Admin | Cancel or update seat count |
| `POST` | `/api/v1/admin/offerings/` | Admin | Create offering (course seat / program / seat pack) |
| `PATCH` | `/api/v1/admin/offerings/{id}` | Admin | Update offering metadata or price |
| `POST` | `/api/v1/admin/entitlements/assign` | Admin | Bulk assign entitlements (max 500 emails) |
| `GET` | `/api/v1/admin/orders/` | Admin | List orders with filters |
| `POST` | `/webhooks/stripe/` | Stripe-Signature header | Stripe event ingestion (idempotent) |
| `GET` | `/metrics` | None (cluster-internal) | Prometheus metrics |

### Stripe Webhook Events Handled

`checkout.session.completed` · `checkout.session.expired` · `payment_intent.payment_failed` · `charge.refunded` · `charge.dispute.created` · `charge.dispute.closed` · `customer.subscription.created` · `customer.subscription.updated` · `customer.subscription.deleted` · `invoice.paid` · `invoice.payment_failed`

### Feature Flags

| Flag | Default | Effect |
|------|---------|--------|
| `ENABLE_GATEWAY_FULFILLMENT` | `false` | Dark launch guard — enrollment not triggered until true |
| `ENABLE_ENTERPRISE_SUBSCRIPTIONS` | `false` | Subscription endpoints return 403 when false |
| `TENANT_ISOLATION_ENABLED` | `true` | Offering/order access gated by tenant_id |

---

## 2. HubSpot Webhook (Firebase Cloud Function)

**Status**: Legacy. Runs on Firebase (not K8s). Migration to K8s-native is deferred until MCT goes live.
**Spec**: `specs/proposals/external-registration-hubspot_spec.md`
**Source**: `services/hubspot-webhook/functions/index.js`

**Base URL**: Firebase function URL (configured in Firebase Console / Infisical)
**Auth**: `x-hubspot-signature-v3` header (HMAC-SHA256, verified against `HUBSPOT_WEBHOOK_SECRET`).

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/createUser` | HubSpot form submission → Open edX user creation + welcome email |

**Data flow**: HubSpot form → webhook POST → fetch HubSpot contact → map 16 profile fields → create Open edX user via LMS REST API → send welcome email (SendGrid, 5 language templates).

---

## 3. Open edX Standard APIs

These are upstream Open edX APIs, not custom code. See official docs for schemas.

| API | Docs |
|-----|------|
| LMS REST API | https://docs.openedx.org/en/latest/developers/references/internal_data_formats/index.html |
| Studio (CMS) REST API | https://studio.readthedocs.io/ |
| Open edX Events (openedx-events) | https://openedx-events.readthedocs.io/ |
| Enterprise REST APIs | https://github.com/openedx/edx-enterprise |

---

## 4. Event Payload Contracts (openedx-events)

The Purchase Gateway listens for and emits standard Open edX events via Redis Streams.

| Signal | Direction | When |
|--------|-----------|------|
| `org.openedx.learning.course.enrollment.changed.v1` | Emitted by LMS | After fulfillment triggers enrollment |

See `specs/cross-cutting-requirements_spec.md` for platform-wide event bus policy (Redis Streams, not Kafka).

---

## 5. Breaking Change Policy

**Versioning**: All custom APIs follow semver. The URL prefix (`/api/v1/`) is the API version.

**Deprecation process**:
1. Announce in `docs/adr/` with migration guidance.
2. Maintain old version for **minimum 30 days** alongside new version.
3. Remove old version only after confirming zero active consumers (check Prometheus request metrics).

**What constitutes a breaking change**:
- Removing or renaming a field in a response body.
- Changing a field's type.
- Adding a required request field without a default.
- Changing HTTP method or status code for an existing endpoint.

**Non-breaking** (no notice needed):
- Adding optional request fields with defaults.
- Adding new response fields.
- Adding new endpoints.

---

## 6. Accessing OpenAPI Docs Locally

```bash
# Forward purchase-gateway port from cluster
kubectl port-forward -n mereka-lms svc/purchase-gateway 8080:8000

# Then open in browser (requires DEBUG=true in pod env)
open http://localhost:8080/docs

# Or fetch raw schema (always available)
curl http://localhost:8080/openapi.json | python3 -m json.tool
```

For production schema without enabling DEBUG, use the always-available `/openapi.json` endpoint.
