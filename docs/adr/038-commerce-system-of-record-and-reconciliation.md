---
id: ADR-038
title: Commerce System of Record and Reconciliation
decision_status: proposed
decision_type: domain
rollout_state: planned
owner: commerce-platform
created: 2026-03-07
last_reviewed: 2026-03-07
review_due: 2026-06-30
supersedes: []
amends: ["ADR-018"]
depends_on: ["ADR-028", "ADR-033"]
read_next: []
governs: ["commerce-ledger-source-of-truth", "reconciliation-contract", "financial-auditability"]
does_not_govern: ["pricing-policy"]
related_oep: []
related_tutor_docs: ["https://docs.openedx.org", "https://docs.tutor.edly.io"]
related_specs: ["specs/ecommerce-purchase-gateway_spec.md"]
related_runbooks: ["docs/operations/LEGACY_ECOMMERCE_REMOVAL_CHECKLIST.md"]
related_evidence: []
fitness_functions: ["scripts/qa/verify-ecommerce-worker-health.sh"]
expiry_date: null
removal_condition: null
---

# ADR-038: Commerce System of Record and Reconciliation

## Decision
Purchase Gateway ledger records are the commerce system of record for modern purchase flows, and reconciliation MUST be deterministic across payment provider, gateway, and enrollment state.

## Scope
Covers commerce state ownership and reconciliation requirements.

## Non-goals
Catalog merchandising policy.

## Context
Migration from legacy Oscar requires explicit SoR and reconciliation policy to avoid split-brain financial state.

## Decision details
- Order/payment/enrollment links MUST be traceable through stable identifiers.
- Reconciliation windows and mismatch handling MUST be explicit.

## Invariants
No order may be considered final without reconcilable provider and internal state.

## Verification
Scheduled reconciliation checks and mismatch alerting.

## Failure modes
Revenue leakage or duplicate fulfillment.

## Consequences
Raises auditability and de-risks retirement of legacy commerce paths.

## Alternatives considered
Implicit reconciliation through ad-hoc operational scripts.
