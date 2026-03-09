# Tenant Lifecycle
_Audience: Engineering Team • Owner: Multisite Platform • Last verified: 2026-03-09 • Status: canonical_

## Governs

- tenant.lifecycle
- tenant.isolation
- frontend.brand.tokens

## Non-goals

- tenant pricing
- commercial terms

## Standard

- Every subsite is a true tenant, not a vanity alias.
- Tenant onboarding, validation, operation, and retirement are one lifecycle contract.
- Tenant state must be deterministic across site, domain, enterprise, and branding records.
- Isolation checks must pass before and after meaningful tenancy changes.

## Fitness Functions

- `scripts/qa/verify-tenant-isolation.sh`
- `scripts/qa/verify-multisite-config.sh prod`
- `scripts/qa/verify-org-role-ownership.sh both`

## Source ADRs

- `ADR-033`
- `ADR-024`
