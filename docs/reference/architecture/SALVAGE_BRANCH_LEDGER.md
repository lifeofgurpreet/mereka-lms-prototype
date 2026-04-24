# Salvage Branch Ledger
_Audience: Platform Engineering • Owner: Platform Team • Last updated: 2026-03-11 • Status: canonical_

## Branch Under Review

- Branch: `fix/enterprise-mfe-theme-config`

Purpose of this ledger:

- prevent unsafe "merge the whole salvage branch" behavior
- preserve useful ideas without colliding with active runtime or tenant/data lanes
- classify each commit into a controlled follow-up path

## Classification Legend

| Class | Meaning |
|---|---|
| `KEEP` | Still valuable as a future, scoped change |
| `SUPERSEDED` | Already landed elsewhere or otherwise covered |
| `OBSOLETE` | No longer a sound path or no longer matches current architecture |
| `NEEDS_REWORK` | Idea may matter, but current commit shape collides with runtime ownership, mixes concerns, or is too unsafe to lift directly |

## Ledger Summary

| Commit | Summary | Classification | Why |
|---|---|---|---|
| `c0cb5ea5` | fix sed domain rewrite ordering bug | `NEEDS_REWORK` | Tied to runtime rewrite strategy owned by runtime lane |
| `a126cd7d` | route all MFE API calls through Caddy to LMS | `KEEP` | Useful route-truth candidate, but belongs in a later scoped routing PR |
| `2b58db40` | route enterprise LMS API proxy with correct Host header | `KEEP` | Valuable enterprise routing correction, but still runtime-adjacent |
| `d722dcda` | sync CMS overrides CSS with common copy | `SUPERSEDED` | Branding drift correction is already handled on mainline |
| `0149a137` | handle `no_new_privs` blocking sudo on ARC runners | `SUPERSEDED` | Landed through the proof-contract lane |
| `d066b22e` | sync common overrides CSS with LMS copy | `SUPERSEDED` | Mainline now carries the corrected override sync state |
| `79975d41` | replace unsupported `PLUGIN_OPERATIONS.Replace` | `KEEP` | Repo-only bugfix candidate that still appears relevant on current main |
| `548b7fb6` | derive JWT public key from private key at startup | `KEEP` | Still a potentially valuable app-level auth fix, but not for this lane |
| `fe0d769f` | route all MFE ingress traffic through Caddy | `NEEDS_REWORK` | Crosses repo/runtime/overlay ownership; cannot be lifted as-is |
| `c101938f` | runtime domain rewrite for non-production environments | `NEEDS_REWORK` | Directly overlaps active runtime lane and current enterprise build blocker work |
| `ceab0da4` | align hero logo and tab divider in minified MFE CSS | `OBSOLETE` | Edits compiled asset directly; not a maintainable forward path |
| `3830cbad` | wrap profile API proxy in handle block for correct Caddy ordering | `KEEP` | Narrow route-ordering fix worth preserving as a future route PR |
| `393810da` | complete Paragon CSS + course about/search fixes | `NEEDS_REWORK` | Mixed runtime ops, generated assets, and theming; too broad to salvage directly |
| `9ce13f3e` | enterprise MFE theme/env/head-extra fixes | `NEEDS_REWORK` | Mixed runtime env, LMS mount path, and reserved enterprise build logic |

## Detailed KEEP Commits

### `a126cd7d` — route all MFE API calls through Caddy to LMS

- Why it still matters:
  - It addresses a real route-truth gap: generic API/auth paths are currently split across ingress and Caddy surfaces.
- Overlaps active runtime lane:
  - Yes. It affects runtime route behavior.
- Where it belongs now:
  - Future scoped routing PR after route authority is explicitly chosen.
- Should it become a future PR:
  - Yes, but only after runtime lane stabilizes the current enterprise blocker.
- Blocking dependencies:
  - runtime owner decision on whether Caddy or ingress is the desired canonical proxy surface for these paths.

### `2b58db40` — route enterprise LMS API proxy with correct Host header

- Why it still matters:
  - Host-header correctness is central to multisite LMS behavior and enterprise domain routing.
- Overlaps active runtime lane:
  - Yes. Enterprise routing is currently owned elsewhere.
- Where it belongs now:
  - Future enterprise routing PR, likely paired with runtime proof.
- Should it become a future PR:
  - Yes, if the runtime lane confirms this remains the chosen path.
- Blocking dependencies:
  - runtime proof on current enterprise host/LMS routing behavior.

### `79975d41` — replace unsupported `PLUGIN_OPERATIONS.Replace`

- Why it still matters:
  - Current main still contains `PLUGIN_OPERATIONS.Replace` references in active code and active docs/verifiers, while the salvage commit argues the shipped Tutor/plugin-framework surface does not support it.
- Overlaps active runtime lane:
  - No direct runtime overlap; primarily repo/plugin-slot logic.
- Where it belongs now:
  - Separate repo-only plugin-slot correctness PR after owner review.
- Should it become a future PR:
  - Yes.
- Blocking dependencies:
  - confirm supported operations for the deployed Tutor/Open edX release line and then update docs/verifiers consistently.

### `548b7fb6` — derive JWT public key from private key at startup

- Why it still matters:
  - It addresses app-side JWT verification drift and could explain auth failures that are otherwise blamed on runtime config.
- Overlaps active runtime lane:
  - Partial overlap. It affects runtime behavior, but it is an app-repo code change rather than an infra overlay.
- Where it belongs now:
  - Separate auth/runtime-hardening PR, not bundled with frontend parity work.
- Should it become a future PR:
  - Yes, if auth/runtime owners confirm the mismatch still exists.
- Blocking dependencies:
  - current auth failure mode confirmation and owner alignment with runtime lane.

### `3830cbad` — wrap profile API proxy in handle block for correct Caddy ordering

- Why it still matters:
  - It is a narrow and understandable route-ordering fix inside repo-owned Caddy logic.
- Overlaps active runtime lane:
  - Moderate overlap because it changes request routing behavior.
- Where it belongs now:
  - Future route-order cleanup PR informed by `ROUTE_TRUTH_RECONCILIATION.md`.
- Should it become a future PR:
  - Yes.
- Blocking dependencies:
  - route owner decision for `/profile/api/*` handling.

## Detailed NEEDS_REWORK Commits

### `c0cb5ea5`

- The idea may matter only if the runtime lane keeps the sed-based runtime rewrite strategy.
- Current commit shape is unsafe to lift because it edits the same deployment surfaces owned by the runtime lane.

### `fe0d769f`

- Useful as context for why route truth is messy, but not safe to lift because it spans base Caddy plus environment ingress.

### `c101938f`

- Directly overlaps the live enterprise build/runtime blocker lane.
- Treat as reference material only while the runtime owner resolves the build-time config issue.

### `393810da`

- Mixed commit: theming assets, runtime ops notes, search fixes, credentials config.
- Needs decomposition before anything can be reused.

### `9ce13f3e`

- Mixed enterprise env/runtime/LMS mount-path change set.
- Crosses reserved enterprise build logic and runtime wiring.

## Detailed SUPERSEDED Commits

### `d722dcda`

- Same problem class is already resolved on mainline; this specific commit is no longer needed.

### `0149a137`

- Already landed through the proof-contract lane work.

### `d066b22e`

- Mainline already carries the corrected override-sync state.

## Detailed OBSOLETE Commits

### `ceab0da4`

- Directly editing generated/minified theme assets is not the maintainable path.
- Any equivalent visual tweak should come through canonical source assets or theme source, not compiled artifacts.

## Mining Guidance

Use this branch only as a source ledger:

1. Never merge the whole branch.
2. Lift `KEEP` commits only through new scoped PRs.
3. Re-open `NEEDS_REWORK` items only with the owning lane’s approval.
4. Ignore `SUPERSEDED` and `OBSOLETE` commits unless doing archaeology.

## Immediate Safe Next Candidates

If the team wants controlled follow-up work after the runtime blocker is resolved, the best salvage candidates are:

1. `79975d41` — plugin-slot operation compatibility review
2. `3830cbad` — profile API route ordering review
3. `a126cd7d` / `2b58db40` — only after route ownership is explicitly chosen and the runtime owner is done
