---
title: Commerce System of Record and Reconciliation
proposal_state: proposed
owner: commerce-platform
created: 2026-03-07
last_reviewed: 2026-03-07
review_due: 2026-06-30
canonical_root: docs/adr/rfc
doc_class: rfc
summary: Proposes commerce ownership and reconciliation rules for financial state.
tags:
- commerce
- reconciliation
decision_type: domain
decision_status: proposed
governs:
- commerce.system-of-record
- commerce.reconciliation
id: ADR-038
rollout_state: planned
supersedes: []
amends:
- ADR-018
depends_on:
- ADR-028
- ADR-033
read_next: []
does_not_govern:
- pricing-policy
related_oep: []
related_tutor_docs:
- https://docs.openedx.org
- https://docs.tutor.edly.io
related_specs:
- specs/ecommerce-purchase-gateway_spec.md
related_runbooks:
- docs/runbooks/operations/LEGACY_ECOMMERCE_REMOVAL_CHECKLIST.md
related_evidence: []
fitness_functions:
- scripts/qa/verify-ecommerce-worker-health.sh
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
