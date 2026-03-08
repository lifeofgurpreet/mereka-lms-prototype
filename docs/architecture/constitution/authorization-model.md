# Authorization Model

Owner: Auth Platform
Review cadence: quarterly

## Governs

- auth.authorization.roles
- tenant.isolation

## Non-goals

- identity-provider protocol choice
- login UX copy

## Standard

- Platform-admin, tenant-admin, staff, and learner scopes must be explicit.
- Cross-tenant administrative access must be minimal and auditable.
- Role mappings must not implicitly escalate across tenant boundaries.

## Fitness Functions

- `scripts/qa/verify-org-role-ownership.sh both`

## Source ADRs

- `ADR-041`
- `ADR-033`
- `ADR-029`
