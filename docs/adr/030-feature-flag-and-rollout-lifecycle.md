---
id: ADR-030
title: Feature Flag and Rollout Lifecycle
decision_status: accepted
decision_type: foundation
rollout_state: active
owner: platform-team
created: 2026-03-07
last_reviewed: 2026-03-07
review_due: 2026-06-30
supersedes: []
amends: []
depends_on: ["ADR-028"]
read_next: ["ADR-031"]
governs: ["feature-flag-lifecycle", "rollout-safety", "flag-removal"]
does_not_govern: ["product-prioritization"]
related_oep: []
related_tutor_docs: ["https://docs.openedx.org"]
related_specs: []
related_runbooks: ["docs/reference/operations/RELEASE_EVIDENCE.md"]
related_evidence: []
fitness_functions: ["tools/docs/verify/verify-docs-policy.sh"]
expiry_date: null
removal_condition: null
---

# ADR-030: Feature Flag and Rollout Lifecycle

## Decision

Feature flags MUST declare lifecycle intent at creation time: owner, rollout plan, rollback plan, and removal condition.

## Scope

Governs all new or changed runtime flags in platform services and MFEs.

## Non-goals

- Defining default product behavior.

## Context

Flags without lifecycle metadata become hidden architecture debt and block safe deprecation.

## Decision details

- Every flag MUST define: enable criteria, disable criteria, and sunset criteria.
- Temporary rollout flags MUST include a review_due and removal condition.
- Rollout evidence MUST be attached to release evidence artifacts.

## Invariants

- No permanent "temporary" flags.
- A flag without owner metadata MUST NOT be considered production-ready.

## Verification

- PR checklist verification (owner/rollback/remove present).
- Release evidence review against declared rollout plan.

## Failure modes

- Zombie flags remaining active after rollout completes.
- Flags used as permanent environment forks.

## Consequences

- Teams need to maintain flag inventories and review cadence.

## Alternatives considered

- Best-effort lifecycle without required metadata.
  - Rejected: repeated unresolved toggles.
