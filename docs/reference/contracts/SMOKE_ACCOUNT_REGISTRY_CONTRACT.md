# SMOKE_ACCOUNT_REGISTRY_CONTRACT
_Audience: Operators and agents · Owner: Platform Team · Status: canonical_

This document defines the canonical smoke-account registry contract.

## Canonical source

- Machine-readable contract: [../../../config/smoke-account-registry.yaml](../../../config/smoke-account-registry.yaml)
- Operational status companion: [../../status/active/SMOKE_ACCOUNT_REGISTRY_2026-04-04.md](../../status/active/SMOKE_ACCOUNT_REGISTRY_2026-04-04.md)

## Authority rules

1. Identity owner: the real identity system (`Authentik`, `Open edX`, or service-specific authority).
2. Secret owner: `Infisical`.
3. Consumer mirrors: GitHub secrets / runtime canaries only after Infisical is updated.
4. Status docs may report provisioning state, but they are not the canonical contract.

## Required binding fields

Every canonical smoke registration must bind:

- canonical id
- tenant
- role
- identity authority
- secret authority
- target environments
- Infisical refs
- consumer mirror keys, if any

## Consumer surfaces

- authenticated learner / Studio canaries
- post-deploy E2E gate
- any runtime canary or smoke workflow that reads mirrored credentials

## Related

- [AUTHENTICATED_SMOKE_CREDENTIALS.md](../operations/AUTHENTICATED_SMOKE_CREDENTIALS.md)
- [VERIFIER_CONTRACT_CATALOG.md](VERIFIER_CONTRACT_CATALOG.md)
