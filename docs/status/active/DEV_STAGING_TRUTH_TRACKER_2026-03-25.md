# DEV / Staging Truth Tracker
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-26 • Status: active_

This tracker records the current control truth for DEV and staging. It is intentionally narrow: only verified repo state, tracked proof runs, and live staging probes belong here.

## Current verified signal

- Merged today:
  - `mereka-lms#1057` at `b6047dc2273415b11ae044819c43fcc11592cbbb`
  - `mereka-lms#1058` at `910da6c2e21af9f508a053c7667fb8aa5f7aeaa1`
  - `mereka-lms#1060` at `813b94f4034ade621faea5962836b749161a4c20`
  - `platform-control-plane#68` at `00c5948181b3ac57b2b78670f823a26378c9034a`
- Canonical proof runs:
  - `23584121291` succeeded end to end
  - `23583848535` succeeded end to end on the clean branch proof lane
  - `23583950807` failed only at authenticated smoke step 5; visual/auth artifacts still completed
- Open app PRs:
  - `mereka-lms#1062` tenant theme host normalization, all checks green, awaiting review
  - `mereka-lms#1063` smoke workflow concurrency, all checks green, awaiting review
- Live staging:
  - Argo revision `d9bd9537af4ece908df3094d759ae977864f468f`
  - runtime still serves the older app image `d7f015d2...`
  - live blockers remain: branded `/api/mfe_config/v1` deep-link leakage, tenant authn still loading default `mereka-brand*.css`, unresolved `staging.discovery/notes/credentials/admin/learner.academyv2.mereka.io`

## What is now true

| Dimension | Current state | Why |
|---|---|---|
| Repo contract truth | merged and green | the app-side contract repairs and the control-plane readiness tranche are merged; only review-gated follow-ups remain open |
| Staging runtime truth | open | live staging still serves the older app image and the blocker set above until promotion |
| Staging auth/browser truth | closed in proof, open in live runtime | the canonical tracked proof runs passed end to end, but live staging still needs promotion to match merged app truth |
| Release / evidence truth | closed for the tracked lane | both the main rerun and the clean branch rerun succeeded |
| GitOps / ownership truth | materially stronger | staging is on the corrected infra revision, but live runtime promotion is still pending |
| Topology / cutover truth | parked by operator decision | DEV and staging remain on the shared nonprod cluster until 2026-05-01 |

## Highest-leverage work queue

- T-01: wait on review and merge for `mereka-lms#1062` and `mereka-lms#1063`
- T-02: promote staging runtime so Argo catches up from `d9bd9537af4ece908df3094d759ae977864f468f` to the merged app image
- T-03: rerun tracked staging browser proof after promotion
- T-04: refresh the remaining trackers/docs to the same truth boundary
