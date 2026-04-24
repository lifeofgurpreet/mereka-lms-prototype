---
id: ADR-034
title: Event Contract and Transport Independence
decision_status: proposed
decision_type: domain
rollout_state: planned
owner: platform-events
created: '2026-03-07'
last_reviewed: '2026-03-07'
review_due: '2026-06-30'
supersedes: []
amends:
- ADR-008
depends_on:
- ADR-028
read_next:
- ADR-037
governs:
- events.schema
- events.transport
does_not_govern:
- single-broker-implementation-details
related_oep: []
related_tutor_docs:
- https://docs.openedx.org
- https://docs.tutor.edly.io
related_specs: []
related_runbooks: []
related_evidence: []
fitness_functions:
- scripts/qa/verify-spec-tools-spec-lint.sh
expiry_date: null
removal_condition: null
---

# ADR-034: Event Contract and Transport Independence

## Decision
Define platform events by schema and semantics first, and treat broker/transport as replaceable infrastructure.

## Scope
Governs event payload contracts, versioning compatibility, and producer/consumer boundaries.

## Non-goals
Selecting one permanent broker technology.

## Context
Current eventing guidance is too close to Redis-specific implementation details.

## Decision details
- Event schemas MUST be versioned.
- Producers MUST emit schema-versioned payloads.
- Consumers MUST tolerate additive changes within compatibility rules.

## Invariants
Event meaning MUST remain valid when transport changes.

## Verification
Contract linting and compatibility checks in QA/spec pipelines.

## Failure modes
Semantic drift hidden behind broker-specific code.

## Consequences
Enables future broker migrations without domain-level rewrites.

## Alternatives considered
Hard-binding domain events to one transport.
