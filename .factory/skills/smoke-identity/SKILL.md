---
name: smoke-identity
description: Manage smoke test identities, Infisical secrets, and CI consumer mapping. Use when provisioning smoke accounts, debugging credential issues, or mapping identity authority to secret consumers in Mereka LMS.
---

# Smoke Identity Management

## Authority Chain

```
Identity authority (Authentik + Open edX)
  → Secret authority (Infisical)
    → CI consumers (GitHub Actions secrets = mirrors only)
```

## Key Rule

GitHub secrets are **consumers**, not authority. Infisical is secret authority. Identity systems (Authentik + Open edX) are identity authority.

## Canonical Accounts

Machine-readable registry: `deploy/k8s/tenancy/smoke-account-registry.yaml`

| Account | Tenant | Role | Identity authority |
|---|---|---|---|
| smoke-learner-mereka | mereka | learner | Authentik + Open edX |
| smoke-operator-mereka | mereka | operator | Authentik + Open edX staff |
| smoke-learner-biji-biji | biji-biji | learner | Authentik + Open edX |
| smoke-operator-biji-biji | biji-biji | operator | Authentik + Open edX staff |
| smoke-learner-skillourfuture | skillourfuture | learner | Authentik + Open edX |
| smoke-operator-skillourfuture | skillourfuture | operator | Authentik + Open edX staff |
| smoke-platform-superuser | platform | superuser | Open edX admin |
| smoke-enterprise-admin | shared | enterprise admin | enterprise identity |
| smoke-analytics-support | shared | analytics | analytics identity |

## Provisioning Steps

1. Create identity in real identity authority (Authentik + Open edX)
2. Store secret material in Infisical: `SMOKE_{ROLE}_{TENANT}_{ENV}_*`
3. Mirror to CI consumers (GitHub Actions secrets) only as needed
4. Update `deploy/k8s/tenancy/smoke-account-registry.yaml` state field

## Transitional Consumer Keys

Current CI still reads legacy keys:
- `SSO_CANARY_EMAIL_*` / `SSO_CANARY_PASSWORD_*`
- `SSO_CANARY_STUDIO_EMAIL_*` / `SSO_CANARY_STUDIO_PASSWORD_*`

These must be mapped FROM canonical Infisical-backed identities.

## Never Do

- Treat GitHub secrets as the source of truth for identity
- Create smoke accounts directly in Infisical without creating the identity first
- Store passwords in repo docs
- Hardcode credentials in scripts

## References

- [SMOKE_ACCOUNT_REGISTRY](docs/status/active/SMOKE_ACCOUNT_REGISTRY_2026-04-04.md)
- [AUTHENTICATED_SMOKE_CREDENTIALS.md](docs/reference/operations/AUTHENTICATED_SMOKE_CREDENTIALS.md)
