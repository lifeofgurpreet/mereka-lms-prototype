---
id: ADR-024
title: True Multi-Tenancy for Subsites (Biji-Biji, SkillOurFuture)
decision_status: accepted
decision_type: foundation
rollout_state: active
owner: engineering
created: '2026-03-05'
last_reviewed: '2026-03-07'
review_due: '2026-06-30'
supersedes: []
amends: []
depends_on: []
read_next:
- ADR-029
- ADR-033
governs:
- tenant.isolation
- tenant.domain-boundary
does_not_govern: []
related_oep: []
related_tutor_docs:
- https://docs.openedx.org
- https://docs.tutor.edly.io
related_specs: []
related_runbooks: []
related_evidence: []
fitness_functions:
- scripts/qa/verify-multisite-config.sh prod
- scripts/qa/verify-org-role-ownership.sh both
expiry_date: null
removal_condition: null
---
<!-- markdownlint-disable -->

# ADR-024: True Multi-Tenancy for Subsites (Biji-Biji, SkillOurFuture)

## Context

Mereka LMS serves multiple branded domains on one platform. The platform needed an explicit rule for whether those domains are treated as first-class tenants or merely as aliases on a shared default site.

## Decision

Branded subsites are true tenants, not vanity aliases. Every tenant MUST receive the application-layer records, domain boundary treatment, and provisioning workflow required for first-class operation on the shared platform.

## Scope

This ADR governs tenant classification, required records, and shared-vs-isolated service expectations for branded subsites.

## Non-goals

- Replacing ADR-029 for identity and root-domain federation rules.
- Defining tenant-specific content, pricing, or commercial policy.
- Requiring separate infrastructure stacks per tenant by default.

## Decision details

- Every tenant MUST have tenant-scoped application records at the Open edX layer, including `Site`, `SiteConfiguration`, and the enterprise/discovery records needed for routing and catalog scoping.
- LMS domain, MFE domain/config, branding assets, and tenant course visibility rules are tenant-specific concerns and MUST be provisioned explicitly.
- Studio remains platform-shared unless a later ADR changes that model.
- Notes and forum behavior remain shared-service implementations whose isolation is expressed through course or membership scope, not through separate deployments.
- Discovery, credentials, and commerce MUST respect tenant identity and domain contracts even when their runtime components are shared.
- Tenant provisioning MUST flow through governed automation such as `scripts/tenants/provision-tenant.sh`, not ad hoc manual partial setup.

## Invariants

- A branded tenant MUST NOT be introduced as a simple alias that bypasses tenant records and policy.
- Tenant isolation is primarily application-layer isolation unless another ADR explicitly elevates an infrastructure boundary.
- Shared platform services MUST still honor tenant-scoped routing, branding, and catalog boundaries.

## Verification

- `scripts/qa/verify-multisite-config.sh prod`
- `scripts/qa/verify-org-role-ownership.sh both`

## Failure modes

- A new branded domain is provisioned without the tenant records needed for routing, branding, or catalog isolation.
- Tenant behavior is assumed to require separate infrastructure when the governing model is still shared-platform, application-layer isolation.
- Shared services drift away from tenant-aware configuration and leak catalog, brand, or commerce boundaries.

## Consequences

- New tenant onboarding requires more deliberate provisioning than alias-domain setup, but the resulting system is coherent.
- Service-by-service isolation expectations become explicit and reviewable.
- Live record inventories and migration gaps belong in runbooks, generated references, or issue tracking rather than in the ADR body.

## Alternatives considered

- Treat branded subsites as alias domains on one default tenant.
  - Rejected: breaks first-class tenant governance for branding, routing, and catalog scope.
- Require fully separate infrastructure stacks for each tenant.
  - Rejected: stronger than the current platform model and not required for tenant correctness.
