---
title: Async Task User-Facing Contract
proposal_state: proposed
owner: platform-runtime
created: 2026-03-07
last_reviewed: 2026-03-07
review_due: 2026-06-30
canonical_root: docs/adr/rfc
doc_class: rfc
summary: Proposes the user-facing contract for async task status, retry, and recovery.
tags:
- async
- tasks
- runtime
decision_type: domain
decision_status: proposed
governs:
- runtime.async-task
id: ADR-037
rollout_state: planned
supersedes: []
amends: []
depends_on:
- ADR-034
read_next: []
does_not_govern:
- internal-task-runner-selection
related_oep: []
related_tutor_docs:
- https://docs.openedx.org
- https://docs.tutor.edly.io
related_specs: []
related_runbooks: []
related_evidence: []
fitness_functions: []
expiry_date: null
removal_condition: null
---

# ADR-037: Async Task User-Facing Contract

## Decision
Long-running operations MUST expose a consistent user-facing state model (queued, running, completed, failed) with traceable retries and compensations.

## Scope
Governs user-visible behavior for asynchronous operations across services.

## Non-goals
Choosing one task runner implementation.

## Context
Async behaviors are currently implementation-led and inconsistently represented to users/operators.

## Decision details
- Async APIs MUST return correlation IDs.
- Retry policy and terminal failure semantics MUST be documented.

## Invariants
User-facing state transitions MUST be deterministic.

## Verification
Service tests and operational trace checks.

## Failure modes
Duplicate processing and ambiguous completion state.

## Consequences
Improves supportability and incident triage.

## Alternatives considered
Best-effort async state with no unified contract.
