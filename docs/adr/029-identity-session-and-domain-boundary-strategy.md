---
title: Identity, Session, and Domain-Boundary Strategy
owner: auth-platform
created: 2026-03-07
last_reviewed: 2026-03-07
review_due: 2026-06-30
canonical_root: docs/adr
doc_class: adr
summary: Defines OIDC, cookie, and tenant/domain boundary rules for session handling.
tags:
- auth
- tenant
- boundary
decision_type: foundation
decision_status: accepted
governs:
- auth.oidc
- auth.cookie-boundary
- tenant.domain-boundary
id: ADR-029
rollout_state: active
supersedes: []
amends:
- ADR-002
- ADR-005
- ADR-022
- ADR-024
depends_on:
- ADR-028
read_next:
- ADR-033
does_not_govern:
- branding copy
- course-content permissions
related_oep: []
related_tutor_docs:
- https://docs.openedx.org
- https://docs.tutor.edly.io
related_specs: []
related_runbooks:
- docs/reference/operations/OPENEDX_HOSTNAMES.md
- docs/reference/operations/DOMAIN_MATRIX.md
related_evidence: []
fitness_functions:
- scripts/qa/verify-auth-surfaces.sh prod
- scripts/qa/verify-mfe-config-contract.sh --env prod
expiry_date: null
removal_condition: null
---

# ADR-029: Identity, Session, and Domain-Boundary Strategy

## Decision

Identity MUST be federated via OAuth2/OIDC. Cross-root-domain authentication MUST use federation flows and MUST NOT rely on shared cookies.

## Scope

Governs authentication/session behavior across `*.academyv2.mereka.io` and other root domains (for example `biji-biji.com`).

## Non-goals

- Authorization role taxonomy.
- Tenant branding configuration.

## Context

Legacy multisite assumptions around cookie sharing are insufficient for multi-root-domain architecture.

## Decision details

- Session cookies MAY be shared only within a single controlled root-domain boundary.
- Cross-root-domain SSO MUST use explicit OIDC authorize/callback exchanges.
- Domain-boundary assumptions MUST be documented in hostname/domain matrices.

## Invariants

- Root-domain boundaries MUST NOT be bypassed with implicit cookie trust.
- OIDC providers MUST remain enabled and secret-backed in runtime.

## Verification

- `scripts/qa/verify-auth-surfaces.sh prod`
- `scripts/qa/verify-mfe-config-contract.sh --env prod`
- `scripts/qa/list-openedx-hostnames.sh --env both`

## Failure modes

- Callback/session mismatch caused by forwarded-proto/cookie-domain drift.
- Disabled provider configuration leading to silent auth failures.

## Consequences

- ADR-002/005/022 language must align to federation-first identity wording.

## Alternatives considered

- Single-cookie model across all domains.
  - Rejected: not valid across unrelated root domains.
