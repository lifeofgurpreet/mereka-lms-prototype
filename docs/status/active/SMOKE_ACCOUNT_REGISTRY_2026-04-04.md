# SMOKE_ACCOUNT_REGISTRY_2026-04-04
_Audience: Operators/release engineers · Owner: Platform Team · Status: active status-only_

Operational registry for canonical smoke identities.
Passwords are never stored in repo.

Canonical contract:

- [../../reference/contracts/SMOKE_ACCOUNT_REGISTRY_CONTRACT.md](../../reference/contracts/SMOKE_ACCOUNT_REGISTRY_CONTRACT.md)
- [../../../config/smoke-account-registry.yaml](../../../config/smoke-account-registry.yaml)

## Governing rule

1. Create identity in real identity authority first.
2. Store secret material/metadata in Infisical.
3. Mirror to CI consumers only as needed.

## Smoke identity authority/consumer mapping

| Canonical id | Tenant | Role | Identity authority | Target envs | Infisical refs | Current state |
|---|---|---|---|---|---|---|
| `smoke-learner-mereka` | mereka | learner | Authentik + Open edX learner record | dev/staging/prod | `SMOKE_LEARNER_MEREKA_{ENV}_*` | missing canonical registry wiring |
| `smoke-operator-mereka` | mereka | operator | Authentik + Open edX staff record | dev/staging/prod | `SMOKE_OPERATOR_MEREKA_{ENV}_*` | missing canonical registry wiring |
| `smoke-learner-biji-biji` | biji-biji | learner | Authentik + Open edX learner record | dev/staging/prod | `SMOKE_LEARNER_BIJI_BIJI_{ENV}_*` | missing canonical registry wiring |
| `smoke-operator-biji-biji` | biji-biji | operator | Authentik + Open edX staff record | dev/staging/prod | `SMOKE_OPERATOR_BIJI_BIJI_{ENV}_*` | missing canonical registry wiring |
| `smoke-learner-skillourfuture` | skillourfuture | learner | Authentik + Open edX learner record | dev/staging/prod | `SMOKE_LEARNER_SOF_{ENV}_*` | missing canonical registry wiring |
| `smoke-operator-skillourfuture` | skillourfuture | operator | Authentik + Open edX staff record | dev/staging/prod | `SMOKE_OPERATOR_SOF_{ENV}_*` | missing canonical registry wiring |
| `smoke-platform-superuser` | platform | superuser | Open edX admin authority | dev/staging/prod | `SMOKE_PLATFORM_SUPERUSER_{ENV}_*` | missing canonical registry wiring |
| `smoke-enterprise-admin` | shared/tenant | enterprise admin | enterprise identity authority | envs where active | `SMOKE_ENTERPRISE_ADMIN_{ENV}_*` | missing canonical registry wiring |
| `smoke-analytics-support` | shared/tenant | analytics/support | analytics identity authority | envs where active | `SMOKE_ANALYTICS_SUPPORT_{ENV}_*` | missing canonical registry wiring |

## Transitional consumer keys (compatibility)

Current CI consumers still read:

- `SSO_CANARY_EMAIL_*`
- `SSO_CANARY_PASSWORD_*`
- `SSO_CANARY_STUDIO_EMAIL_*`
- `SSO_CANARY_STUDIO_PASSWORD_*`

These are consumer keys and must be mapped from canonical Infisical-backed identities.

## Related

- [../../reference/operations/AUTHENTICATED_SMOKE_CREDENTIALS.md](../../reference/operations/AUTHENTICATED_SMOKE_CREDENTIALS.md)
- [../../reference/contracts/VERIFIER_CONTRACT_CATALOG.md](../../reference/contracts/VERIFIER_CONTRACT_CATALOG.md)
