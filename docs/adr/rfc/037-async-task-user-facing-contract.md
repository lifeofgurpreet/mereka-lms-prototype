---
id: ADR-037
title: Async Task User-Facing Contract
decision_status: proposed
decision_type: domain
rollout_state: planned
owner: platform-runtime
created: 2026-03-07
last_reviewed: 2026-03-07
review_due: 2026-06-30
supersedes: []
amends: []
depends_on: ["ADR-034"]
read_next: []
governs: ["async-task-state-model", "user-visible-status", "retry-compensation"]
does_not_govern: ["internal-task-runner-selection"]
related_oep: []
related_tutor_docs: ["https://docs.openedx.org", "https://docs.tutor.edly.io"]
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
