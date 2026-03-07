# Auth and Tenancy Bundle

This file is generated from `docs/adr/manifest.yaml`.

## ADRs

- `ADR-013` [Studio SSO Bypass Middleware](../../013-studio-sso-bypass-middleware.md)
  - Governs: `studio-sso-oauth-next-preservation-workaround`
- `ADR-022` [Session Cookie SameSite Policy and Stale Cookie Mitigation](../../022-session-cookie-samesite-policy.md)
  - Governs: `session-cookie-samesite-exception, stale-cookie-dedup-workaround`
- `ADR-029` [Identity, Session, and Domain-Boundary Strategy](../../029-identity-session-and-domain-boundary-strategy.md)
  - Governs: `oidc, cookie-boundaries, cross-domain-auth, session-policy`
- `ADR-033` [Tenant Lifecycle Contract](../../033-tenant-lifecycle-contract.md)
  - Governs: `tenant-create-update-disable-offboard, tenant-isolation-contract, tenant-branding-governance`
- `ADR-041` [Authorization and Role-Boundary Model](../../041-authorization-and-role-boundary-model.md)
  - Governs: `role-boundary-contract, admin-scope, tenant-role-isolation`
