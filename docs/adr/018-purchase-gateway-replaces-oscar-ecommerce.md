# ADR 018: Purchase Gateway Replaces Legacy Oscar Ecommerce

## Status
ACCEPTED

## Date
2026-02-16

## Context
The Open edX platform ships with an Oscar-based ecommerce service (`openedx-ecommerce`) that provides course purchasing, payment processing, and order management. This service:
- Is archived upstream (moved to `openedx-unsupported` GitHub org)
- Carries substantial technical debt (complex Oscar pipeline, unused PayPal/CyberSource integrations)
- Requires a separate MySQL database, OAuth2 client pair, and Django admin
- Uses a separate Celery worker for async processing

Mereka Academy's purchase flow is simpler: Stripe-only payments for course enrollment, with multi-tenant support via Stripe Connect.

## Decision
Replace the legacy Oscar ecommerce with a purpose-built Purchase Gateway service:
- **Technology**: FastAPI + PostgreSQL + Redis
- **Payment**: Stripe-only (Checkout Sessions + webhooks)
- **Location**: `services/purchase-gateway/`
- **Spec**: `specs/ecommerce-purchase-gateway_spec.md`

The legacy service runs in parallel during the transition period. Decommission criteria (from spec):
- Zero pods, zero DNS records, zero OAuth2 clients for legacy service
- All purchase flows verified on purchase-gateway
- Enterprise onboarding validated

## Consequences
- Legacy ecommerce docs/configs are marked deprecated but retained during transition
- K8s deployments for legacy ecommerce remain active until AC-027/AC-028 close
- New purchase flows must use the purchase-gateway API exclusively
- No new features or bug fixes will be applied to the legacy Oscar service

## References
- **Spec**: `specs/ecommerce-purchase-gateway_spec.md`
- **Service**: `services/purchase-gateway/`
- **Related Beads**: `mereka-lms-bpr3` (retirement docs/config cleanup)
