# ACTIVE_SURFACE_RUNTIME_MATRIX_2026-04-04
_Audience: Operators/reviewers · Owner: Platform Team · Status: active status-only_

> This matrix is operational state, not architecture authority.
> Canonical model/docs:
> - [../../architecture/PLATFORM_AUTHORITY_MAP.md](../../architecture/PLATFORM_AUTHORITY_MAP.md)
> - [../../reference/contracts/VERIFIER_CONTRACT_CATALOG.md](../../reference/contracts/VERIFIER_CONTRACT_CATALOG.md)

## Classification rules

- `proved`: runtime/browser proof exists for this execution wave
- `broken`: runtime proof exists and is red
- `unproved`: active in source truth, no current proof artifact
- `must-remove-or-redirect`: source truth marks deprecated

## Source inventory summary (from tenant authority)

| Metric | Count |
|---|---:|
| active domains | 97 |
| deprecated domains | 3 |
| production domains | 29 |
| staging domains | 31 |
| dev domains | 28 |
| profiles-dev domains | 9 |

## Environment summary

| Environment | Proved | Broken | Must-remove-or-redirect | Unproved |
|---|---:|---:|---:|---:|
| production | 1 | 0 | 3 | 28 |
| staging | 6 | 2 | 0 | 23 |
| dev | 11 | 1 | 0 | 16 |
| profiles-dev | 0 | 0 | 0 | 9 |

## Known broken active surfaces

| Env | Surface | Current note |
|---|---|---|
| staging | `staging.apps.academyv2.mereka.io` (authenticated learner flow) | public apps root green, post-login flow broken |
| staging | `staging.forum.academyv2.mereka.io` | forum alias resolution break |
| dev | `forum.academyv2.mereka.dev` | alias returns empty 200 while in-process endpoint returns 401 |

## Must remove or redirect (deprecated in source truth)

| Env | Domain |
|---|---|
| production | `ecommerce.academyv2.mereka.io` |
| production | `apps.skillourfuture.academy.mereka.io` |
| production | `studio.skillourfuture.academy.mereka.io` |

## Companion status docs

- [ACTIVE_SURFACE_STATUS_BOARD_2026-04-04.md](ACTIVE_SURFACE_STATUS_BOARD_2026-04-04.md)
- [SMOKE_ACCOUNT_REGISTRY_2026-04-04.md](SMOKE_ACCOUNT_REGISTRY_2026-04-04.md)
- [MASTER_LAUNCH_ROADMAP_2026-04-04.md](MASTER_LAUNCH_ROADMAP_2026-04-04.md)
