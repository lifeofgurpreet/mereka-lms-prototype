# Purchase Gateway Architecture Overview
_Audience: Engineering + Architecture • Last updated: 2026-02-10_

## System Overview

The Purchase Gateway is a custom Stripe-to-Open edX enrollment bridge that replaces the deprecated Oscar/ecommerce service. It processes payments through Stripe Checkout, handles fulfillment by creating enrollments in the LMS, and supports the "entitlement + invitation" pattern for buyers without pre-existing Open edX accounts. The system is multi-tenant from day one, supporting per-enterprise Stripe Connect accounts and billing configurations.

**Key differentiator**: Purpose-built for Open edX enrollment fulfillment, eliminating Oscar's complexity while enabling the "no account required" purchase flow.

---

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    Frontend (Buy Button)                        │
│  - Course detail page                                           │
│  - "Buy Now" button → POST /api/checkout/create-session         │
└─────────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│              Purchase Gateway API (payments-gateway)            │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ FastAPI Service (Python 3.12)                            │   │
│  │ - POST /api/checkout/create-session                      │   │
│  │ - POST /api/webhooks/stripe (signature verification)     │   │
│  │ - GET /api/orders/{order-id}                             │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                        │
           ┌────────────┼────────────┐
           ▼            ▼            ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│   Stripe     │ │ PostgreSQL   │ │ Redis Queue  │
│   Checkout   │ │ (Orders DB)  │ │ (Job Queue)  │
│              │ │ - Orders     │ │              │
│ - Payment UI │ │ - Entitlemnts│ │              │
│ - Webhooks   │ │ - Events log │ │              │
└──────┬───────┘ └──────────────┘ └──────┬───────┘
       │                                  │
       │ webhook: payment_succeeded       │
       └──────────────┬───────────────────┘
                      ▼
         ┌──────────────────────────────┐
         │   Purchase Gateway Worker    │
         │   (payments-worker)          │
         │   - Async fulfillment        │
         │   - Retry logic (max 3)      │
         │   - Dead letter queue        │
         └──────────┬───────────────────┘
                    │
                    ▼
         ┌──────────────────────────────┐
         │   LMS Enrollment API         │
         │   POST /api/enrollment/v1/   │
         │   - Creates enrollment       │
         │   - Or creates entitlement   │
         └──────────────────────────────┘
```

---

## Data Flow

### Purchase Flow (User Has Account)
1. **Learner** clicks "Buy Now" on course page
2. **Frontend** calls `POST /api/checkout/create-session` with `course_id`, `email`
3. **Gateway API** checks if user exists in LMS (via email lookup)
4. **Gateway API** creates Stripe Checkout session:
   - Line items: course offering (price, currency)
   - Success URL: `https://academyv2.mereka.io/checkout/success?session_id={CHECKOUT_SESSION_ID}`
   - Cancel URL: `https://academyv2.mereka.io/courses/{course_id}`
5. **Gateway API** creates `Order` record (status: `pending`)
6. **Frontend** redirects to Stripe Checkout URL
7. **Learner** completes payment on Stripe's hosted page
8. **Stripe** sends webhook: `checkout.session.completed` → `POST /webhooks/stripe`
9. **Gateway API** verifies webhook signature, updates order (status: `payment_succeeded`)
10. **Gateway API** enqueues fulfillment job in Redis
11. **Worker** picks up job, calls LMS enrollment API: `POST /api/enrollment/v1/enrollment`
12. **LMS** creates enrollment (status: `active`)
13. **Worker** updates order (status: `fulfilled`)
14. **Gateway** sends confirmation email to learner

### Purchase Flow (User Does NOT Have Account)
1. **Steps 1-9** same as above (payment succeeds)
2. **Worker** checks if user exists → **NO**
3. **Worker** creates `Entitlement` record (status: `pending`)
4. **Worker** sends invitation email with registration link:
   - Link: `https://academyv2.mereka.io/register?entitlement_token={token}`
5. **Learner** clicks link, completes registration
6. **LMS** post-registration hook checks for entitlements by email
7. **LMS** auto-enrolls user in entitled courses
8. **Entitlement** status → `fulfilled`

### Refund Flow
1. **Customer** requests refund (support ticket or Stripe dashboard)
2. **Admin** processes refund in Stripe dashboard
3. **Stripe** sends webhook: `charge.refunded` → `POST /webhooks/stripe`
4. **Gateway API** verifies webhook, updates order (status: `refunded`)
5. **Gateway API** enqueues revocation job in Redis
6. **Worker** calls LMS enrollment API: `DELETE /api/enrollment/v1/enrollment`
7. **LMS** revokes enrollment (status: `inactive`)
8. **Worker** updates order (status: `refunded_and_revoked`)
9. **Gateway** sends refund confirmation email

---

## Integration Points

### Stripe Checkout
- **API Version**: 2023-10-16
- **Endpoints**:
  - `POST /v1/checkout/sessions` - Create checkout session
  - `GET /v1/checkout/sessions/{id}` - Retrieve session details
- **Webhooks**:
  - `checkout.session.completed` - Payment succeeded
  - `charge.refunded` - Refund processed
  - `customer.subscription.updated` - Subscription renewed (for seat packs)

### LMS Enrollment API
- **Endpoint**: `POST /api/enrollment/v1/enrollment`
- **Authentication**: OAuth2 service-to-service (JWT token)
- **Payload**:
  ```json
  {
    "user": "username",
    "course_id": "course-v1:Org+Course+Run",
    "mode": "verified",
    "is_active": true
  }
  ```

### PostgreSQL Database
- **Tables**:
  - `orders` (id, payment_intent_id, user_email, offering_id, amount, currency, status, created_at, fulfilled_at)
  - `entitlements` (id, order_id, user_email, course_id, status, token, expires_at)
  - `stripe_events` (id, event_id, event_type, payload, processed_at)
  - `tenants` (id, enterprise_customer_uuid, stripe_account_id, config)

### Redis Queue
- **Queue**: `purchase_gateway:fulfillment`
- **Job Payload**: `{"order_id": 123, "action": "enroll", "retry_count": 0}`
- **Dead Letter Queue**: `purchase_gateway:dlq` (after 3 failed attempts)

---

## Key Design Decisions

### 1. Stripe Checkout vs. Custom Payment Form
**Decision**: Use Stripe Checkout (hosted payment page)

**Rationale**:
- **Zero PCI scope**: Stripe handles all card data, never touches our infrastructure.
- **Trust**: Learners trust Stripe's payment form (familiar UX).
- **Maintenance**: Stripe maintains payment form compliance (PCI-DSS, Strong Customer Authentication).

**Trade-offs**:
- Less control over payment UX (redirects off-site).
- Cannot customize payment form beyond Stripe's options.

### 2. Fulfillment: Sync vs. Async
**Decision**: Async fulfillment via Redis queue

**Rationale**:
- **Webhook response time**: Must respond to Stripe webhooks within 2 seconds (Stripe retries if >30s).
- **Retry logic**: If LMS API fails, job retries without blocking webhook handler.
- **Observability**: Jobs in queue are visible, trackable, replayable.

**Trade-offs**:
- Enrollment not instant (1-60 seconds delay).
- Requires Redis for job queue (additional dependency).

### 3. Entitlement Pattern: Immediate vs. Invitation
**Decision**: Invitation-based entitlement (user registers later)

**Rationale**:
- **Use case**: Gift purchases, corporate bulk buys, marketing-driven acquisition.
- **Conversion**: Enables purchase without friction of upfront registration.
- **Flexibility**: Entitlements can be transferred (future feature).

**Trade-offs**:
- Abandoned entitlements (user never registers).
- Entitlement expiration logic required (default: 1 year).

### 4. Multi-Tenancy: Stripe Connect vs. Single Account
**Decision**: Support Stripe Connect (per-tenant accounts) + platform account

**Rationale**:
- **Enterprise feature**: Large clients may require payments to flow to their Stripe account.
- **Revenue split**: Stripe Connect supports platform fees (Mereka takes % of transaction).
- **Compliance**: Some clients require direct payment for regulatory reasons.

**Trade-offs**:
- Stripe Connect setup is complex (OAuth flow for onboarding).
- Webhook signature verification is per-account (not global).

### 5. Database: PostgreSQL vs. MySQL
**Decision**: PostgreSQL (separate from LMS's MySQL)

**Rationale**:
- **Independence**: Gateway can be deployed/scaled independently of LMS.
- **Features**: PostgreSQL's JSONB for flexible `config` and `metadata` fields.
- **Data model**: Financial data (orders, payments) benefits from ACID guarantees.

**Trade-offs**:
- Additional database to manage (backups, monitoring, failover).
- Cannot use LMS's existing Cloud SQL MySQL (different RDBMS).

---

## Security Considerations

### Webhook Signature Verification
- **Algorithm**: HMAC-SHA256
- **Secret**: Stored in Infisical → ExternalSecret → pod env var
- **Verification**: Every webhook request MUST pass signature check (reject 401 if invalid)

### Idempotency
- **Stripe Event ID**: De-duplicate webhook events using `event_id` (store in `stripe_events` table)
- **Order Status**: Check order status before fulfillment (prevent double-enrollment)

### Secrets Management
- **Stripe API Keys**: Stored in Infisical, synced to K8s ExternalSecret
- **OAuth2 Token**: LMS service account token (rotation: 90 days)
- **Database Credentials**: Cloud SQL proxy with IAM authentication

---

## Performance Targets

| Metric | Target |
|--------|--------|
| Checkout session creation | p95 <1s |
| Webhook response time | p95 <2s |
| Fulfillment latency | p95 <10s |
| Concurrent checkouts | 100 (no degradation) |
| Webhook success rate | >99.5% |
| Dead letter queue size | <10 messages |

---

## Related Specs and ADRs
- **Spec**: `specs/ecommerce-purchase-gateway_spec.md`
- **Runbook**: `docs/archive/superseded/runbooks/purchase-gateway-runbook.md`
- **Stripe Webhooks Setup**: `docs/ops/runbooks/STRIPE_WEBHOOKS_SETUP.md`
- **Multi-Tenancy**: `specs/multi-tenancy-architecture_spec.md`
- **Secrets Management**: `specs/secrets-management_spec.md`
