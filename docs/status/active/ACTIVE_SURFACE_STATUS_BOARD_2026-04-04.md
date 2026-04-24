# ACTIVE_SURFACE_STATUS_BOARD_2026-04-04
_Audience: Operators/reviewers · Owner: Platform Team · Status: active status-only_

Compressed execution board for active surfaces.

Source matrix: [ACTIVE_SURFACE_RUNTIME_MATRIX_2026-04-04.md](ACTIVE_SURFACE_RUNTIME_MATRIX_2026-04-04.md)

## Current counts

| Status | Count |
|---|---:|
| proved | 18 |
| broken | 3 |
| must-remove-or-redirect | 3 |
| unproved | 76 |

## Broken surfaces

| Env | Domain | Failure summary |
|---|---|---|
| staging | `staging.apps.academyv2.mereka.io` | authenticated learner flow broken |
| staging | `staging.forum.academyv2.mereka.io` | forum alias unresolved |
| dev | `forum.academyv2.mereka.dev` | alias empty 200 response |

## Must remove or redirect

| Domain | Source status |
|---|---|
| `ecommerce.academyv2.mereka.io` | deprecated |
| `apps.skillourfuture.academy.mereka.io` | deprecated |
| `studio.skillourfuture.academy.mereka.io` | deprecated |

## Execution rule

Until a surface is `proved` or `must-remove-or-redirect`, it remains launch work.

## Next-priority snapshot (1-pass, 2026-04-14)

- Next priority: `staging.apps.academyv2.mereka.io` (staging auth learner flow)
- Rationale: highest-impact broken launcher surface for active authenticated journey continuity.
- Scope: status proof/surface lane only; ownership remains in docs/status active board family.
- Follow-up: proceed only after owner-validated runtime evidence changes before boundary crossing into must-remove lanes.
