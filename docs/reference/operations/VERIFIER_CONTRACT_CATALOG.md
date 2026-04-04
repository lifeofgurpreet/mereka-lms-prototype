# Verifier Catalog (Detailed Reference)
_Audience: Operators and implementers · Owner: Platform Team · Status: detailed-reference_

> **Superseded as contract owner by**
> [../contracts/VERIFIER_CONTRACT_CATALOG.md](../contracts/VERIFIER_CONTRACT_CATALOG.md).
>
> This document is still useful for implementation-level verifier details and
> script inventory context.

## What this file is still useful for

- locating concrete verifier scripts by domain
- understanding execution mode (offline/runtime/browser)
- mapping verifiers to CI inventory sources

## What this file is not

- not the canonical proof-lane contract
- not launch-scope authority
- not a substitute for runtime proof artifacts

## Inventory authority

- `scripts/governance/script-registry.yaml` is CI inventory authority.
- `ci_static_inventory` and `ci_runtime_inventory` classifications come from that file.

## Domains (detailed lookup)

| Domain | Typical scripts |
|---|---|
| tenant/routing | `verify-rke2-tenant-routes.sh`, `verify-tenant-*.sh` |
| auth/oidc | `verify-authenticated-sso-canary.sh`, `verify-oidc-provider-configs.sh` |
| release/proof | `release-gate.sh`, bundle verification scripts |
| security/secrets | `verify-secrets-*.sh`, secret scanners |
| observability | `verify-observability-*.sh`, `verify-slo-*.sh` |
| dr/backup | `verify-disaster-recovery.sh`, `audit-velero.sh` |

## Read next

- [../contracts/VERIFIER_CONTRACT_CATALOG.md](../contracts/VERIFIER_CONTRACT_CATALOG.md) (canonical contracts)
- [AGENT_EXECUTION_WORKFLOW.md](AGENT_EXECUTION_WORKFLOW.md)
