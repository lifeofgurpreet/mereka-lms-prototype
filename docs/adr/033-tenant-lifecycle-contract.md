---
id: ADR-033
title: Tenant Lifecycle Contract
decision_status: accepted
decision_type: foundation
rollout_state: active
owner: multisite-platform
created: '2026-03-07'
last_reviewed: '2026-03-07'
review_due: '2026-06-30'
supersedes: []
amends:
- ADR-024
depends_on:
- ADR-028
- ADR-029
- ADR-032
read_next: []
governs:
- tenant.lifecycle
- tenant.isolation
- tenant.domain-boundary
- frontend.brand.tokens
does_not_govern:
- tenant commercial terms
related_oep: []
related_tutor_docs:
- https://docs.openedx.org
- https://docs.tutor.edly.io
related_specs:
- specs/multi-tenancy-architecture_spec.md
related_runbooks:
- docs/ops/runbooks/TENANT_PROVISIONING.md
- docs/guides/branding/TENANT_CONFIG_HANDOFF.md
related_evidence: []
fitness_functions:
- scripts/qa/verify-tenant-isolation.sh
- scripts/qa/verify-multisite-config.sh prod
expiry_date: null
removal_condition: null
---
<!-- markdownlint-disable -->

# ADR-033: Tenant Lifecycle Contract

## Decision

Tenancy MUST be governed as a lifecycle contract: create, configure, validate, operate, and retire.

## Scope

Applies to tenant onboarding, per-tenant config state, domain mapping, and offboarding controls.

## Non-goals

- Commercial pricing or contract policy.

## Context

Existing tenancy decisions focus on tenant shape but are less explicit about operational lifecycle guarantees.

## Decision details

- Tenant creation MUST include identity/domain/config prerequisites.
- Tenant runtime config MUST be validated through deterministic checks.
- Tenant offboarding MUST define state transition and data-retention outcomes.

## Invariants

- Each tenant MUST have deterministic mapping in site/domain/config records.
- Tenant isolation checks MUST pass before and after significant tenancy changes.

## Verification

- `scripts/qa/verify-tenant-isolation.sh`
- `scripts/qa/verify-multisite-config.sh prod`
- `scripts/tenants/provision-tenant.sh`

## Failure modes

- Partial tenant config causing mixed-domain behavior.
- Untracked offboarding causing stale or orphaned tenant state.

## Consequences

- Tenancy work requires lifecycle acceptance criteria, not only creation scripts.

## Alternatives considered

- Treat tenancy as one-time provisioning only.
  - Rejected: operational lifecycle drift and incomplete governance.
