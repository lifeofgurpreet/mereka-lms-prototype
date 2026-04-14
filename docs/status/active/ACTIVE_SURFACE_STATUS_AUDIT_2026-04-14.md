# Active Status Audit Pass 1
_Auditor: docs extraction lane · Date: 2026-04-14_

## Recomputed ownership boundary
- Boundary source: `docs/status/active` only (`README.md`, `MASTER_LAUNCH_ROADMAP_2026-04-04.md`, `ACTIVE_SURFACE_STATUS_BOARD_2026-04-04.md`, `ACTIVE_SURFACE_RUNTIME_MATRIX_2026-04-04.md`, `SMOKE_ACCOUNT_REGISTRY_2026-04-04.md`).
- Excluded: migration, architecture, contracts, runbooks, and non-active status trackers.

## One-pass next-priority scan
1. Read latest board + roadmap + matrix and rank unresolved items by launch criticality.
2. Top priority lane is `staging.apps.academyv2.mereka.io` under `broken`:
   - Current note: authenticated learner flow broken.
   - Launch impact: blocks authenticated-staging verification lane for active tenants.
3. Secondary broken items are:
   - `staging.forum.academyv2.mereka.io` (alias resolution)
   - `forum.academyv2.mereka.dev` (empty 200)
4. Must-remove-or-redirect lane stays priority-2 after fix of the top broken runtime gate.
