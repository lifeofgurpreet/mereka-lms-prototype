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

## One-pass next-priority scan (pass 2, 2026-04-14)

- Recomputed ownership boundary (fresh pull from `origin/main`):
  - `docs/status/active` only
  - files: `ACTIVE_SURFACE_STATUS_BOARD_2026-04-04.md`, `ACTIVE_SURFACE_RUNTIME_MATRIX_2026-04-04.md`, `ACTIVE_SURFACE_STATUS_AUDIT_2026-04-14.md`, `MASTER_LAUNCH_ROADMAP_2026-04-04.md`, `SMOKE_ACCOUNT_REGISTRY_2026-04-04.md`, `README.md`

- Boundary result: no boundary expansion needed; this lane is still status proof capture and evidence triage only.

- Unresolved broken surfaces, sorted by priority:
  1. `staging.apps.academyv2.mereka.io` — authenticated learner flow still recorded as broken
  2. `staging.forum.academyv2.mereka.io` — alias resolution still required
  3. `forum.academyv2.mereka.dev` — alias still returns empty 200

- One-pass recommendation:
  - keep next slice scoped to docs/status ownership files
  - capture runtime evidence for pass-2 execution once the first broken surface fix is owned and merged outside this lane
  - do not expand into non-status docs families until launch impact is reduced
