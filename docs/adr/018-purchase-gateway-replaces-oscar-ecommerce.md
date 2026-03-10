---
id: ADR-018
title: Purchase Gateway Replaces Legacy Oscar Ecommerce
decision_status: accepted
decision_type: migration
rollout_state: active
owner: commerce-platform
created: '2026-02-16'
last_reviewed: '2026-03-07'
review_due: '2026-06-30'
supersedes: []
amends: []
depends_on:
- ADR-028
- ADR-033
read_next:
- ADR-028
- ADR-031
governs:
- commerce.system-of-record
- commerce.reconciliation
- platform.change-policy
does_not_govern:
- pricing-strategy
- catalog-content-authoring
related_oep: []
related_tutor_docs:
- https://docs.openedx.org
- https://docs.tutor.edly.io
related_specs:
- specs/ecommerce-purchase-gateway_spec.md
related_runbooks:
- docs/runbooks/operations/LEGACY_ECOMMERCE_REMOVAL_CHECKLIST.md
- docs/runbooks/operations/ECOMMERCE_WORKER_TROUBLESHOOTING.md
related_evidence: []
fitness_functions:
- scripts/qa/verify-ecommerce-worker-health.sh
- scripts/qa/verify-repo-structure.sh
expiry_date: null
removal_condition: null
---

# ADR-018: Purchase Gateway Replaces Legacy Oscar Ecommerce

## Decision

Purchase Gateway is the canonical commerce path for new purchase workflows.  
Legacy Oscar ecommerce remains migration-only and MUST NOT receive new feature development.

## Scope

This ADR governs purchase execution and migration boundaries between legacy Oscar and Purchase Gateway.

## Non-goals

- Product pricing and campaign policy.
- Enterprise contract/legal policy.

## Context

Legacy Oscar is archived upstream, operationally expensive, and misaligned with current Stripe-only multi-tenant requirements.

## Decision details

- Technology baseline: FastAPI + PostgreSQL + Redis at `services/purchase-gateway/`.
- Payment baseline: Stripe Checkout Sessions + webhook-driven fulfillment.
- During migration, legacy service may run in parallel for controlled fallback.
- New commerce integrations MUST target Purchase Gateway APIs.

## Invariants

- New purchase behavior MUST NOT be implemented in legacy Oscar paths.
- Commerce reconciliation MUST have a deterministic source of truth in Purchase Gateway records.
- Retirement criteria for legacy Oscar MUST be explicit and verifiable.

## Verification

- `scripts/qa/verify-ecommerce-worker-health.sh`
- service-level tests under `services/purchase-gateway/tests`
- retirement checklist evidence in `docs/runbooks/operations/LEGACY_ECOMMERCE_REMOVAL_CHECKLIST.md`

## Failure modes

- Split-brain order state across legacy and Purchase Gateway.
- Webhook processing drift causing enrollment/fulfillment mismatch.
- Tenant-boundary leakage in commerce configuration.

## Consequences

### Positive

- Reduced complexity compared with Oscar stack.
- Clear Stripe-first model aligned to current product needs.
- Better path toward domain-specific reconciliation controls.

### Negative

- Migration period carries dual-path operational overhead.
- Requires explicit decommission discipline for legacy service artifacts.

## Alternatives considered

1. Keep Oscar as primary commerce service.
   - Rejected: archived upstream, high maintenance burden.
2. Hybrid long-term dual system.
   - Rejected: persistent split-brain risk and unclear source of truth.
