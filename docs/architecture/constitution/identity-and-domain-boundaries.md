# Identity And Domain Boundaries

Owner: Auth Platform
Review cadence: quarterly

## Governs

- auth.oidc
- auth.cookie-boundary
- tenant.domain-boundary

## Non-goals

- branding
- course access policy

## Standard

- Cross-root-domain authentication MUST use federation.
- Shared cookies MAY exist only within a single controlled root domain.
- Provider configuration must remain secret-backed and explicitly enabled.
- Cookie-sharing workarounds are exceptions with expiry, not target architecture.

## Fitness Functions

- `scripts/qa/verify-auth-surfaces.sh prod`
- `scripts/qa/verify-mfe-config-contract.sh --env prod`

## Source ADRs

- `ADR-029`
- `ADR-022`
- `ADR-013`
