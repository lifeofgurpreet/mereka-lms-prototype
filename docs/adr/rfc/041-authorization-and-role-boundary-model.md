---
title: Authorization and Role-Boundary Model
proposal_state: proposed
owner: auth-platform
created: 2026-03-07
last_reviewed: 2026-03-07
review_due: 2026-06-30
canonical_root: docs/adr/rfc
doc_class: rfc
summary: Proposes the authorization and role-boundary model for tenant-aware access.
tags:
  - auth.authorization.roles
  - tenant.isolation
decision_type: domain
decision_status: proposed
governs:
- auth.authorization.roles
- tenant.isolation
id: ADR-041
rollout_state: planned
supersedes: []
amends:
- ADR-029
- ADR-033
depends_on:
- ADR-029
- ADR-033
read_next: []
does_not_govern:
- identity-provider-protocol-selection
related_oep: []
related_tutor_docs:
- https://docs.openedx.org
- https://docs.tutor.edly.io
related_specs: []
related_runbooks: []
related_evidence: []
fitness_functions:
- scripts/qa/verify-org-role-ownership.sh both
expiry_date: null
removal_condition: null
---

# ADR-041: Authorization and Role-Boundary Model

## Decision
Authorization boundaries MUST be explicit across platform-admin, tenant-admin, staff, and learner scopes, with enforceable tenant isolation.

## Scope
Governs role boundary and authorization model contracts.

## Non-goals
Authentication protocol details.

## Context
True-tenancy requires role-scope guarantees beyond identity and domain routing.

## Decision details
- Role scopes MUST be mapped to tenant/domain boundaries.
- Cross-tenant admin operations MUST be auditable and minimized.

## Invariants
No tenant role may implicitly escalate to platform-admin scope.

## Verification
Role ownership checks and governance gate outputs.

## Failure modes
Cross-tenant privilege leakage.

## Consequences
Clearer security posture and safer operational delegation.

## Alternatives considered
Implicit role conventions without explicit architecture contract.
