# Authenticated Smoke Credentials Reference
_Audience: Platform Operators · Owner: Platform Team · Last verified: 2026-04-04 · Status: canonical_

This document defines credential authority for authenticated smoke lanes.

## Identity vs secret authority

- Identity authority: real identity systems (Authentik + Open edX account records).
- Secret authority: Infisical (credential material + metadata).
- GitHub secrets / runner env vars: consumer mirrors only.

## Contract

1. No ad-hoc one-off smoke identities.
2. Every smoke account must map to a real identity record.
3. Every smoke credential must be tracked in Infisical.
4. Consumer mirrors must be updated only after Infisical authority is updated.

## Current consumer secret families

- `SSO_CANARY_EMAIL_*` / `SSO_CANARY_PASSWORD_*`
- `SSO_CANARY_STUDIO_EMAIL_*` / `SSO_CANARY_STUDIO_PASSWORD_*`
- `SMOKE_SSO_USERNAME` / `SMOKE_SSO_PASSWORD`
- `E2E_TEST_USERNAME` / `E2E_TEST_PASSWORD`

## Canonical registry

- Machine-readable contract: [../contracts/SMOKE_ACCOUNT_REGISTRY_CONTRACT.md](../contracts/SMOKE_ACCOUNT_REGISTRY_CONTRACT.md)
- Operational status companion: [../../status/active/SMOKE_ACCOUNT_REGISTRY_2026-04-04.md](../../status/active/SMOKE_ACCOUNT_REGISTRY_2026-04-04.md)

## Rotation rule

- rotate when underlying identity password changes
- update Infisical first
- update consumer mirrors second
- rerun authenticated smoke proof immediately after rotation

## Verification commands

- `bash scripts/qa/verify-authenticated-ui-smoke.sh`
- `bash scripts/qa/verify-authenticated-sso-canary.sh --env staging`
- `bash scripts/qa/verify-authenticated-sso-canary.sh --env prod`

## Related

- [SSO_CANARY.md](SSO_CANARY.md)
- [../contracts/VERIFIER_CONTRACT_CATALOG.md](../contracts/VERIFIER_CONTRACT_CATALOG.md)
