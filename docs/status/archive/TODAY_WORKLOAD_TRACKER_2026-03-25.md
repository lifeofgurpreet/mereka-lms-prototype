# Today Workload Tracker
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-26 • Status: active_

This is the current execution board for the remaining highest-leverage work. It should reflect only verified truth and the next actionable steps.

## Verified facts for today

- authoritative app repo state is the current merged `main` truth after:
  - `mereka-lms#1057` at `b6047dc2273415b11ae044819c43fcc11592cbbb`
  - `mereka-lms#1058` at `910da6c2e21af9f508a053c7667fb8aa5f7aeaa1`
  - `mereka-lms#1060` at `813b94f4034ade621faea5962836b749161a4c20`
  - `platform-control-plane#68` at `00c5948181b3ac57b2b78670f823a26378c9034a`
- canonical proof state is already green:
  - `23584121291` succeeded end to end
  - `23583848535` succeeded end to end
  - `23583950807` failed only at authenticated smoke step 5; visual/auth artifacts still completed
- open app PRs are review-gated, not blocked by checks:
  - `mereka-lms#1062` tenant theme host normalization
  - `mereka-lms#1063` smoke workflow concurrency
- live staging is still behind merged app truth:
  - Argo revision `d9bd9537af4ece908df3094d759ae977864f468f`
  - runtime still on old app image `d7f015d2...`
  - blockers remain: branded `/api/mfe_config/v1` deep-link leakage, tenant authn CSS still loading default `mereka-brand*.css`, unresolved `staging.discovery/notes/credentials/admin/learner.academyv2.mereka.io`

## Today execution queue

### W-01 — Keep the docs refresh truthful

Priority: `P0`
Owner surface: `mereka-lms`

Done when:

- the active trackers match the merged PRs, proof runs, and live staging state listed above
- no tracker still claims the pre-merge 1057/1058/1060/68 state as current

### W-02 — Wait on review and merge for the open app PRs

Priority: `P0`
Owner surface: `mereka-lms`

Done when:

- `mereka-lms#1062` is reviewed and merged
- `mereka-lms#1063` is reviewed and merged

### W-03 — Promote live staging runtime

Priority: `P0`
Owner surface: `mereka-lms` + `bbi-infrastructure`

Done when:

- staging runtime no longer serves `d7f015d2...`
- the live blockers above are gone from the staging surface

### W-04 — Re-run tracked staging proof after promotion

Priority: `P0`
Owner surface: `mereka-lms`

Done when:

- the tracked staging browser/auth proof is re-run against the promoted runtime
- the tracker and evidence surfaces agree on the final live state

### W-05 — Keep dedicated staging cluster work parked

Priority: `P1`
Owner surface: `bbi-infrastructure` + planning surfaces

Done when:

- dedicated staging cluster provisioning remains explicitly deferred until 2026-05-01
- no operator brief reopens cutover work as the next step
