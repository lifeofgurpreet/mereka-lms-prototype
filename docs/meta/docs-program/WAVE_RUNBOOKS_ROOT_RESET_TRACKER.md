# Wave Runbooks Root Reset Tracker

Status: in_progress  
Branch: `docs/runbooks-root-reset`  
Worktree: `/home/gurpreet/projects/k8s/mereka-lms-wt-runbooks-root-reset`

## Objective

Retire `docs/runbooks/**` as an active peer root without losing live operational guidance.

This wave is narrower than a general runbook rewrite. The goal is to collapse the legacy
root into canonical homes, primarily `docs/ops/runbooks/**`, while keeping active spec,
workflow, and docs references intact.

## Packet A

### Inventory

Current files under `docs/runbooks/**`:

- `docs/runbooks/README.md`
- `docs/runbooks/LMS_RUNTIME_CLOSURE_RUNBOOK.md`
- `docs/runbooks/architecture/*.md` (9 files)
- `docs/runbooks/migrations/VERIFICATION_CHECKLIST.md`
- `docs/runbooks/migrations/kajabi/*.md` (4 files)
- `docs/runbooks/operations/*.md` (81 files)

### What repo reality proves

1. `docs/runbooks/**` is not a dead wrapper graveyard in the same way `docs/operations/**`
   or `docs/architecture/**` were at end state.
2. `docs/runbooks/operations/*.md` already has a one-to-one canonical filename match under
   `docs/ops/runbooks/*.md` for all 81 files.
3. `docs/runbooks/architecture/*.md` already has a one-to-one canonical filename match under
   `docs/ops/runbooks/architecture/*.md`.
4. `docs/runbooks/migrations/**` already has canonical counterparts under
   `docs/ops/runbooks/migrations/**`.
5. The root is still heavily referenced across specs, workflows, scripts, and docs governance,
   so this cannot be deleted in one blind pass.

### Live reference pressure

Observed active references to `docs/runbooks/**` include:

- workflow annotations in `.github/workflows/**`
- testmap and plan references in `specs/**`
- docs governance and transitional-root checks in `tools/docs/verify/**`
- operational script guidance in `scripts/**`

This means the safe order is:

1. classify and map
2. rewrite active references to canonical homes
3. delete wrappers in slices
4. reduce the root to a tombstone only after references are converged

### Classification

#### Wrapper/redirect candidates

- `docs/runbooks/README.md`
- `docs/runbooks/LMS_RUNTIME_CLOSURE_RUNBOOK.md`
- all `docs/runbooks/architecture/*.md`
- all `docs/runbooks/migrations/**/*.md`
- all `docs/runbooks/operations/*.md`

These are not new canonical docs. They are duplicate path surfaces for material already
owned by `docs/ops/runbooks/**`.

#### Canonical target root

- `docs/ops/runbooks/**`

#### Canonical owning support roots still involved

- `specs/**` for runbook references in plans/testmaps
- `.github/workflows/**` for workflow-linked remediation docs
- `tools/docs/verify/**` for transitional-root policy

### Existing migration map

The repo already contains:

- `docs/meta/docs-program/root-collapse/docs-runbooks-collapse-map.yaml`

That file is useful as source material, but it is not sufficient by itself. The execution
source of truth for this wave is this tracker plus the actual repo state on branch.

### Packet A conclusion

- Proceed with a phased collapse to `docs/ops/runbooks/**`.
- Do not delete the root yet.
- Do not create more compatibility stubs than necessary.
- Prefer reference rewrites plus deletion over long-lived path shims.

## Open risks

- Some specs refer to flat root runbooks that do not currently exist in the tracked tree
  (for example `docs/runbooks/proctoring-operations-runbook.md` and
  `docs/runbooks/purchase-gateway-runbook.md`). Those require separate classification before
  any broad guardrail is tightened.
- The existing transitional-root verifier currently allows stub-only markdown under
  `docs/runbooks/**`; the end-state guard should be stricter once the collapse is complete.

## Next packet

Packet B should:

1. rewrite the highest-signal active references from `docs/runbooks/operations/**` to
   `docs/ops/runbooks/**`
2. remove the corresponding duplicate wrapper files from `docs/runbooks/operations/**`
3. validate docs policy and docs catalog freshness
