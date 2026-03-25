# Today Workload Tracker
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-25T22:39:30Z • Status: active_

This is the execution board for the remaining highest-leverage work on **March 25, 2026**. It is intentionally narrow: only items that are both true and actionable now belong here.

## Verified facts for today

- authoritative app repo state is `origin/main` at `1e613462` (`docs(ui): close UI-01 through UI-04 with live runtime proof (#1043)`)
- the current local `main` checkout is dirty and behind; it must not be treated as the source of truth for new work
- a clean worktree was created from `origin/main` for truth work
  - path: `/tmp/mereka-lms-truth-20260325`
  - branch: `truth/staging-canary-contract-alignment`
- staging authenticated canary secrets now exist in GitHub
  - present: `SSO_CANARY_EMAIL_STAGING`, `SSO_CANARY_PASSWORD_STAGING`, `SSO_CANARY_STUDIO_EMAIL_STAGING`, `SSO_CANARY_STUDIO_PASSWORD_STAGING`
  - missing but non-blocking for staging: `SSO_CANARY_*_DEV`
- `RUN_AUTHENTICATED_SSO_CANARY=true` is present in GitHub repo variables
- the clean tracked staging browser-proof lane is still blocked in the app repo
  - `.github/workflows/operations-gates-runtime.yml` is `disabled_manually`
  - when temporarily enabled for a manual dispatch probe, GitHub rejected it with `HTTP 422` because the workflow defines top-level `permissions` twice
- `.github/workflows/smoke-authenticated.yml` is `active`, but it is not the clean staging-proof lane
  - its separate smoke job still depends on `SMOKE_SSO_USERNAME` / `SMOKE_SSO_PASSWORD`
  - therefore it cannot be treated as the canonical substitute for `operations-gates-runtime.yml`
- `bbi-infrastructure` authoritative state is `origin/main` at `1bc40187`
  - `config/nonprod-execution-state.yaml` still says `ready_for_execution: false`
- `platform-control-plane` authoritative state is `origin/main` at `cdafc4c`
  - no new first-order contract blocker was found there in this tranche
- by explicit operator decision, DEV and staging continue sharing the same RKE2 nonprod cluster until **May 1, 2026**
  - dedicated staging cluster provisioning and cutover are not part of today’s workload
- a fresh app-repo worktree is not automatically clean in this repository
  - `.gitattributes` says `eol=lf`
  - many tracked files still materialize with CRLF and appear modified in a fresh worktree
  - scoped diffs must be used instead of naive `git status` closure claims

## Today execution queue

### W-01 — Work only from an authoritative clean base

Priority: `P0`
Owner surface: `mereka-lms`

Why this is first:

- local `main` is dirty and behind
- this repo has CRLF baseline noise even in a fresh worktree
- any new work done from the wrong base risks mixing stale local edits with already-merged remote changes

Done when:

- new work uses a fresh worktree or clean branch from `origin/main`
- validation uses scoped diffs for authored files, not whole-tree cleanliness claims

### W-02 — Publish the runtime-gate workflow fix that unblocks canonical staging browser proof

Priority: `P0`
Owner surface: `mereka-lms`

Verified need:

- `operations-gates-runtime.yml` is the intended clean tracked staging-proof lane
- GitHub currently rejects dispatch because the workflow file on `origin/main` defines top-level `permissions` twice
- the workflow is also `disabled_manually`

Done when:

- the duplicate-`permissions` defect is merged
- the workflow can be safely re-enabled
- a manual dispatch no longer fails at GitHub workflow-parse time

### W-03 — Run a fresh tracked staging authenticated canary on the shared nonprod cluster

Priority: `P0`
Owner surface: `mereka-lms`

Verified fact:

- staging canary secrets now exist
- the blocking issue has shifted from secrets to workflow validity / execution state

Done when:

- a tracked workflow run executes against `env_scope=staging`
- the run is current and tied to merged repo truth
- runtime/browser evidence exists for the current staging state without relying on local-only probes

### W-04 — Reconcile tracker truth only after the tracked run exists

Priority: `P0`
Owner surface: `mereka-lms`

Verified fact:

- active trackers still mix old staging-host closure language, workflow-blocker language, and deferred-cluster posture
- `STABILIZATION_CONTROL_BOARD.md` still correctly says runtime/browser closure is not canonically closed

Done when:

- `DEV_STAGING_TRUTH_TRACKER_2026-03-25.md` matches the current tracked evidence
- control docs are updated only if the new tracked evidence actually supports it
- no local-only proof is promoted into canonical truth

### W-05 — Keep dedicated staging cluster work explicitly parked until May 1

Priority: `P1`
Owner surface: `bbi-infrastructure` + planning surfaces

Verified fact:

- the system is intentionally operating with DEV and staging on the shared nonprod cluster for now
- treating dedicated staging cluster work as the next irreversible step is currently false prioritization

Done when:

- active trackers consistently classify dedicated staging cluster provisioning and cutover as deferred work
- no operator brief tells the next agent to start there before May 1

### W-06 — Continue lower-leverage cleanup only after W-02 through W-04 move

Priority: `P2`
Owner surface: mixed

Examples:

- DEV residual cleanup
- cross-repo doc/spec drift cleanup
- CRLF baseline hygiene planning
- boundary extraction / deprecated overlay cleanup

These matter, but they are below the proof-lane unblockers above.

## Explicitly deferred

These are **not** today’s workload:

- dedicated staging cluster provisioning
- staging cluster cutover
- retirement of shared-cluster staging topology

Those are deferred until **May 1, 2026** by operator decision.

## Commands most likely needed today

- `git fetch origin main --quiet`
- `git log --oneline origin/main -8`
- `gh api repos/Biji-Biji-Initiative/mereka-lms/actions/workflows/operations-gates-runtime.yml`
- `gh api repos/Biji-Biji-Initiative/mereka-lms/actions/workflows/smoke-authenticated.yml`
- `gh secret list --repo Biji-Biji-Initiative/mereka-lms | rg 'SSO_CANARY|SMOKE_SSO'`
- `./scripts/qa/audit-authenticated-sso-canary-wiring.sh`

## Do not claim completion for today unless all of these are true

- work is based on a clean branch or worktree from `origin/main`
- staging canary secrets exist and remain wired
- `operations-gates-runtime.yml` is syntax-valid and no longer parse-blocked
- at least one fresh tracked staging browser-proof attempt has been made, or the remaining blocker is recorded exactly
- active trackers reflect the resulting state truthfully

## Deeper trackers for today

- staging/runtime lane: [DEV_STAGING_TRUTH_TRACKER_2026-03-25.md](/home/gurpreet/projects/k8s/mereka-lms/docs/status/active/DEV_STAGING_TRUTH_TRACKER_2026-03-25.md)
- UI/footer/mobile lane: [UI_RUNTIME_TRUTH_TRACKER_2026-03-25.md](/home/gurpreet/projects/k8s/mereka-lms/docs/status/active/UI_RUNTIME_TRUTH_TRACKER_2026-03-25.md)
