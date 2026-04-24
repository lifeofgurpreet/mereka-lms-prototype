# Auth and Tenancy Bundle

> Generated file. Do not hand-edit. Regenerate from the ADR source inputs.

This file is generated from `docs/adr/manifest.yaml`.

## ADRs

- `ADR-013` [Studio SSO Bypass Middleware](../../docs/adr/013-studio-sso-bypass-middleware.md)
  - Governs: `auth.oidc`
- `ADR-022` [Session Cookie SameSite Policy and Stale Cookie Mitigation](../../docs/adr/022-session-cookie-samesite-policy.md)
  - Governs: `auth.cookie-boundary`
- `ADR-029` [Identity, Session, and Domain-Boundary Strategy](../../docs/adr/029-identity-session-and-domain-boundary-strategy.md)
  - Governs: `auth.oidc, auth.cookie-boundary, tenant.domain-boundary`
- `ADR-033` [Tenant Lifecycle Contract](../../docs/adr/033-tenant-lifecycle-contract.md)
  - Governs: `tenant.lifecycle, tenant.isolation, tenant.domain-boundary, frontend.brand.tokens`
