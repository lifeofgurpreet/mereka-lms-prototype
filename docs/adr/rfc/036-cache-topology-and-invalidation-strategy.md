---
id: ADR-036
title: Cache Topology and Invalidation Strategy
decision_status: proposed
decision_type: domain
rollout_state: planned
owner: platform-runtime
created: '2026-03-07'
last_reviewed: '2026-03-07'
review_due: '2026-06-30'
supersedes: []
amends: []
depends_on:
- ADR-028
- ADR-033
read_next: []
governs:
- runtime.cache
does_not_govern:
- business-feature-priorities
related_oep: []
related_tutor_docs:
- https://docs.openedx.org
- https://docs.tutor.edly.io
related_specs: []
related_runbooks:
- docs/ops/runbooks/TROUBLESHOOTING.md
related_evidence: []
fitness_functions:
- scripts/qa/verify-mfe-config-contract.sh --env prod
expiry_date: null
removal_condition: null
---

# ADR-036: Cache Topology and Invalidation Strategy

## Decision
Cache layers MUST have explicit ownership, TTL/invalidation rules, and stale-read fallback behavior.

## Scope
Covers application, session, and frontend config/cache pathways.

## Non-goals
Replacing all cache implementations at once.

## Context
Cache issues currently surface as operational incidents without a single topology contract.

## Decision details
- Each cache MUST declare key namespace and invalidation trigger.
- Stale tolerance MUST be explicit per cache class.

## Invariants
No cache may be introduced without invalidation semantics.

## Verification
Runtime checks and canary probes for stale config/session issues.

## Failure modes
Silent stale-state drift and inconsistent user behavior.

## Consequences
Improves reliability and operability under drift.

## Alternatives considered
Implicit cache behavior by implementation convention only.
