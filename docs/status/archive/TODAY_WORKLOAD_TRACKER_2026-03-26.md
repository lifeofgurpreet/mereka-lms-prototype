# Today Workload Tracker
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-26T10:45:00Z • Status: active_

This is the execution board for **March 26, 2026**. It is intentionally cross-repo and cross-lane: frontend/UI, runtime proof, governed GitOps promotion, and control-plane/domain truth all belong here when they are true and actionable now.

## Verified facts for today

- `mereka-lms` `origin/main` already contains:
  - `#1063` `fix(ci): serialize staging smoke runs`
  - `#1065` `docs: refresh staging truth trackers and runtime references`
- `bbi-infrastructure#2140` is merged at `d9c15bae06aadefff687f5b4707558fd57d3fe50`
  - meaning: governed staging promotion can truthfully consume app-origin release-bundle metadata instead of assuming provenance must resolve inside infra git history
- the highest-value remaining app PRs are:
  - `#1062` `fix(mfe): normalize tenant theme host lookup`
  - `#1064` `fix(ci): pin release-bundle cosign output format`
  - `#1068` `fix(qa): make verify-auth-sso-enterprise staging-aware`
- current app PR truth is split:
  - `#1062` and `#1064` are code-green and review-gated, and must stay current with `main`
  - `#1068` is still open with a real `Static Validation` failure
- live staging is still behind the merged app truth
  - Argo app `mereka-lms-staging` is `Synced` / `Progressing`
  - desired revision is now `d9c15bae06aadefff687f5b4707558fd57d3fe50`
  - last recorded deployed history entry is still `4961f848702ec9aedf57c2d362fd34ac93c6f612`
- that means the current trust boundary is clear:
  - repo-side smoke serialization and tracker refresh are already on `main`
  - governed promotion architecture is unblocked in infra
  - live tenant UI/runtime truth has **not** advanced until new app digests are promoted
- the highest-value live frontend defect is still tenant theme/runtime truth
  - direct probes show tenant authn hosts still serving default `mereka-brand*.css`
  - tenant `/api/mfe_config/v1` still needs post-promotion re-verification for branding completeness
- the deeper long-term domain/control-plane debt is now explicit
  - canonical staging host-family truth still diverges across control-plane, infra docs, and live publication
  - this is a real architecture lane, but it is not allowed to delay the app promotion and runtime-proof critical path

## Current control point

The system is no longer blocked on local debugging. It is blocked on **merge order**, **promotion order**, and **ownership discipline**:

1. land the remaining app truth that affects live runtime
2. promote that merged truth through governed GitOps
3. verify the live staging runtime actually moved
4. rerun canonical browser/runtime proof on `main`
5. then advance tracker, evidence, and stabilization claims

## Now / Next / Later

### Now

#### W-01 — Land the remaining app truth in the right order

Priority: `P0`
Owner surfaces: `mereka-lms`

Order:

1. `#1062` tenant theme host normalization
2. `#1064` release-bundle cosign output format
3. `#1068` enterprise staging-aware auth proof, once its static-validation failure is repaired

Why this order:

- `#1062` changes live tenant-facing UI/runtime behavior
- `#1064` protects the provenance path needed to promote `#1062` truthfully
- `#1068` matters for full runtime coverage, but it is a proof-lane fix and should not be confused with the tenant-theme runtime defect itself

Done when:

- the three PRs above are either merged or explicitly downgraded out of the critical path for a stronger reason than convenience

#### W-02 — Promote merged app truth into staging via the governed path

Priority: `P0`
Owner surfaces: `bbi-infrastructure` consuming `mereka-lms`

Verified fact:

- `#2140` is already merged, so the governed promotion lane can now accept app-origin release bundles truthfully

Done when:

- the staging overlay moves onto the merged app truth
- Argo desired and deployed state converge on the new digests
- live runtime is no longer serving the pre-`#1062/#1064` behavior

#### W-03 — Re-run canonical staging browser/runtime proof on `main`

Priority: `P0`
Owner surfaces: `mereka-lms`

Verified fact:

- proof-lane structure is no longer the blocker for primary staging smoke
- until new app truth is both merged and promoted, any tracked proof run would still be proving the wrong runtime

Done when:

- one tracked run on `main` proves the post-promotion staging state
- tenant branding/theme, login path, MFE config behavior, and authenticated smoke/browser lanes all agree with merged repo truth

### Next

#### W-04 — Keep active trackers and evidence surfaces downstream of runtime truth

Priority: `P1`
Owner surfaces: `mereka-lms`

Rule:

- tracker surfaces are consumers of runtime truth, not substitutes for it
- do not advance closure claims because a PR merged or a local probe looked good

Done when:

- active trackers describe the same state the cluster and tracked proof runs describe
- no document claims tenant UI closure or staging runtime closure before live proof exists

#### W-05 — Treat control-plane/domain truth as its own architecture lane

Priority: `P1`
Owner surfaces: `platform-control-plane`, then `bbi-infrastructure`

Current structural debts:

- `platform-control-plane#69` now carries the bounded canonical host-family correction for secondary staging surfaces
- canonical secondary-host family is still unresolved: `staging.<service>...` vs `<service>.staging...`
- control-plane readiness contracts, infra public endpoint registry, and live probes disagree on which staging secondary hosts are real, pending, or alias-only
- `platform-control-plane#24` remains a separate long-term DX improvement for multi-zone Cloudflare authority

Done when:

- one host-family rule is canonical repo-wide
- infra truth surfaces consume that contract instead of inventing a parallel one
- unresolved secondary hosts are either published canonically or explicitly removed from active/public claims

#### W-06 — Reduce app-boundary debt after runtime closure is stronger

Priority: `P1`
Owner surfaces: `mereka-lms`

Current candidates:

- remove lingering `infrastructure/cloudflare/**` authority artifacts from the app repo
- make smoke proof consume the tenant/domain contract instead of scattered hardcoded tenant URLs
- fix any post-promotion tenant runtime-config completeness gaps if branding keys remain blank

Done when:

- app owns tenant runtime consumption and proof
- control-plane owns DNS/domain authority
- infra owns realization/publication

### Later

#### W-07 — Resume broader CI/DX and non-critical hygiene after convergence truth is stronger

Priority: `P2`
Owner surfaces: mixed

Examples:

- CodeQL runner/workflow optimization
- ARC runner image refresh and CI ceremony reduction
- lower-risk lint, dependency, and archival doc cleanup

These matter, but they sit below the current trust boundary:

- merge app truth
- promote app truth
- prove live runtime

## Long-term workstreams

| Workstream | Current truth | Next forcing function |
|---|---|---|
| Frontend / UI tenant truth | `#1062` is still not live; tenant authn still serves default theme CSS | merge + promote `#1062`, then re-probe tenant branding and `/api/mfe_config/v1` |
| Runtime / browser proof | primary smoke lane is structurally stronger; enterprise proof still incomplete in `#1068` | promote new app digests, then rerun tracked proof on `main` |
| GitOps / promotion architecture | `#2140` removed the infra-side provenance blocker | execute the first post-`#2140` governed staging promotion |
| Control-plane / domain truth | host-family and alias truth still diverge across repos; `platform-control-plane#69` is the active bounded fix | merge the canonicalization fix, then clean infra truth surfaces and publication claims |
| Tracker / evidence truth | active status still needs to stay downstream of runtime | refresh only after promotion and tracked proof advance |

## Ownership boundary

- `mereka-lms`: tenant runtime behavior, MFE/LMS host consumption, branding/theme correctness, proof/tests, enterprise auth proof
- `bbi-infrastructure`: promotion PRs, overlay digests, Argo realization, public exposure, runtime convergence
- `platform-control-plane`: canonical domain authority, Cloudflare/import tooling, host-family contract, generated readiness references

## Do not claim completion for today unless all of these are true

- `#1062`, `#1064`, and any still-required proof PRs are no longer open blockers
- the governed promotion path has actually been exercised after `#2140`
- staging Argo desired and deployed history both reflect the intended app truth
- a tracked post-promotion staging proof run exists on `main`
- tracker and stabilization surfaces describe the resulting runtime honestly

## Deeper trackers for today

- staging/runtime lane: [DEV_STAGING_TRUTH_TRACKER_2026-03-25.md](DEV_STAGING_TRUTH_TRACKER_2026-03-25.md)
- UI/browser-proof lane: [UI_RUNTIME_TRUTH_TRACKER_2026-03-25.md](UI_RUNTIME_TRUTH_TRACKER_2026-03-25.md)
- canonical control board: [STABILIZATION_CONTROL_BOARD.md](../../stabilization/STABILIZATION_CONTROL_BOARD.md)
