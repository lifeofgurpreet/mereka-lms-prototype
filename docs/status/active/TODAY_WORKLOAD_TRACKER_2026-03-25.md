# Today Workload Tracker
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-26T02:36:00Z • Status: active_

This is the execution board for the remaining highest-leverage work on **March 25, 2026**. It is intentionally narrow: only items that are both true and actionable now belong here.

## Verified facts for today

- authoritative app repo state is `origin/main` at `54291d68` (`fix(ci): remove --with-deps from Playwright install on ARC runners (#1047)`)
- the current local `main` checkout is dirty and behind; it must not be treated as the source of truth for new work
- a clean worktree was created from `origin/main` for truth work
  - path: `/tmp/mereka-lms-pr1048-refresh`
  - branch: `truth/staging-runtime-gates-env-contract`
- staging authenticated canary secrets now exist in GitHub
  - present: `SSO_CANARY_EMAIL_STAGING`, `SSO_CANARY_PASSWORD_STAGING`, `SSO_CANARY_STUDIO_EMAIL_STAGING`, `SSO_CANARY_STUDIO_PASSWORD_STAGING`
  - missing but non-blocking for staging: `SSO_CANARY_*_DEV`
- `RUN_AUTHENTICATED_SSO_CANARY=true` is present in GitHub repo variables
- the workflow-parse blocker in the canonical staging proof lane is already closed on `origin/main`
  - `.github/workflows/operations-gates-runtime.yml` no longer defines top-level `permissions` twice
  - the workflow still remains `disabled_manually` on GitHub
- `.github/workflows/smoke-authenticated.yml` is `active`, but it is not the clean staging-proof lane
  - its separate smoke job still depends on `SMOKE_SSO_USERNAME` / `SMOKE_SSO_PASSWORD`
  - therefore it cannot be treated as the canonical substitute for `operations-gates-runtime.yml`
- the clean worktree now carries the next app-side staging proof repair tranche
  - staging and `all` env support was added across the operations/auth/multisite QA chain
  - SiteConfiguration / `MFE_CONFIG` writers were aligned to the explicit auth/cookie contract
  - staging `course_org_filter` was corrected to `["MEREKA"]` in repo contract surfaces
- that app-side tranche is now published as `mereka-lms#1048`
  - state: `OPEN`
  - branch: `truth/staging-runtime-gates-env-contract`
  - current verifier-alignment follow-up is on the same PR branch; use the PR for the current head
- live staging MFE config was re-verified after reseeding SiteConfiguration
  - `AUTHN_MICROFRONTEND_URL='https://staging.apps.academyv2.mereka.io/authn'`
  - `AUTHN_MICROFRONTEND_DOMAIN='staging.apps.academyv2.mereka.io'`
  - `SESSION_COOKIE_SAMESITE='None'`
  - `CSRF_COOKIE_SAMESITE='None'`
  - `ACCESS_TOKEN_COOKIE_NAME='edx-jwt-cookie-header-payload'`
  - `USER_INFO_COOKIE_NAME='user-info'`
  - `DISABLE_ENTERPRISE_LOGIN=True`
- scoped app-side staging validations are now green from the clean worktree
  - `./scripts/qa/verify-staging-vocabulary-drift.sh` → `PASS`
  - `./scripts/qa/verify-auth-surfaces.sh staging` → `PASS` with migration-window warnings for unresolved canonical discovery/credentials/ecommerce hosts
  - `./scripts/qa/verify-multisite-config.sh staging` → `PASS`
  - `./scripts/qa/audit-auth-access.sh --env staging --mode public` → `PASS`
  - `./scripts/qa/run-multisite-governance-gates.sh --env staging` → `PASS`
  - `STRICT=1 ./scripts/qa/list-openedx-hostnames.sh --env staging` → `PASS`
- `bbi-infrastructure` authoritative state is `origin/main` at `b8c4ab0a`
  - the merged runtime repair pair is now on `main`, and live staging now reflects both of them
  - `config/nonprod-execution-state.yaml` still says `ready_for_execution: false`
- `bbi-infrastructure#2131` is now merged
  - merge commit: `b8c4ab0af558ab909ae15701ddd521c50f7924cf`
  - scope: realize the Biji-Biji staging issuer in the active shared-cluster cert-manager owner
- live cert-manager/runtime truth is materially stronger than it was at the start of the day
  - `cert-manager-dev` is `Synced` / `Healthy`
  - `letsencrypt-bijibiji-staging` is `Ready=True`
  - `openedx-biji-biji-lms-tls`, `openedx-biji-biji-mfe-tls`, and `openedx-biji-biji-studio-tls` are all `Ready=True` on `letsencrypt-bijibiji-staging`
  - `mereka-lms-staging` is `Synced` / `Progressing` at revision `b8c4ab0af558ab909ae15701ddd521c50f7924cf`
- cross-repo truth is still not fully converged
  - `platform-control-plane` staging DNS/cert readiness surfaces are canonicalized for the primary staging hosts
  - public DNS/TLS readiness for the newly canonical satellite/admin/learner hosts remains an external-dependency lane rather than a contract-definition lane
- the GitOps runtime repair is now published as `bbi-infrastructure#2128`
  - state: `MERGED`
  - merge commit: `8f10dfd096d2d888b15f013c560e9c8c0f65202f`
  - validation: `make verify` → `PASS`
- `platform-control-plane` authoritative state is `origin/main` at `6e1fa4a`
  - the contract-authority repair is now published as `platform-control-plane#65`
  - state: `MERGED`
  - merge commit: `6e1fa4a5fae1f938863b89a6d0668367a83affcd`
  - validation: `./scripts/plan-all.sh --validate-only` → `PASS`
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

### W-02 — Merge the published app-side staging runtime-gates contract repair

Priority: `P0`
Owner surface: `mereka-lms`

Verified need:

- the workflow-parse blocker is already fixed on `origin/main`
- the next real app-side gap is the already-published runtime-gates/config repair in `mereka-lms#1048`
- reviewer requests are now in place, but the PR is still not merged

Done when:

- `mereka-lms#1048` is merged on `main`
- static verification and scoped staging auth/MFE checks remain green
- the next blocker is no longer repo/runtime contract drift inside GitOps, only tracked proof closure

### W-03 — Run a fresh tracked staging authenticated canary on the shared nonprod cluster

Priority: `P0`
Owner surface: `mereka-lms`

Verified fact:

- `platform-control-plane#65` is merged
- `bbi-infrastructure#2128` is merged
- `bbi-infrastructure#2131` is merged
- live host/cert-manager realization is now repaired for the Biji-Biji staging TLS lane
- tracked browser/runtime proof still does not exist for the corrected merged state

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
- `gh pr view 1048 --repo Biji-Biji-Initiative/mereka-lms`
- `gh pr view 2128 --repo Biji-Biji-Initiative/bbi-infrastructure`
- `gh pr view 2131 --repo Biji-Biji-Initiative/bbi-infrastructure`
- `gh pr view 65 --repo Biji-Biji-Initiative/platform-control-plane`
- `gh api repos/Biji-Biji-Initiative/mereka-lms/actions/workflows/operations-gates-runtime.yml`
- `gh api repos/Biji-Biji-Initiative/mereka-lms/actions/workflows/smoke-authenticated.yml`
- `gh secret list --repo Biji-Biji-Initiative/mereka-lms | rg 'SSO_CANARY|SMOKE_SSO'`
- `./scripts/qa/audit-authenticated-sso-canary-wiring.sh`
- `./scripts/qa/verify-staging-vocabulary-drift.sh`
- `./scripts/qa/audit-auth-access.sh --env staging --mode public`
- `./scripts/qa/run-multisite-governance-gates.sh --env staging`

## Do not claim completion for today unless all of these are true

- work is based on a clean branch or worktree from `origin/main`
- staging canary secrets exist and remain wired
- `operations-gates-runtime.yml` is syntax-valid and no longer parse-blocked
- the cross-repo state is accurately recorded: `mereka-lms#1048` open, `platform-control-plane#65` merged, `bbi-infrastructure#2128` merged, `bbi-infrastructure#2131` merged
- the remaining blocker is accurately classified if browser proof still cannot run
- at least one fresh tracked staging browser-proof attempt has been made, or the remaining blocker is recorded exactly
- active trackers reflect the resulting state truthfully

## Deeper trackers for today

- staging/runtime lane: [DEV_STAGING_TRUTH_TRACKER_2026-03-25.md](/home/gurpreet/projects/k8s/mereka-lms/docs/status/active/DEV_STAGING_TRUTH_TRACKER_2026-03-25.md)
- UI/footer/mobile lane: [UI_RUNTIME_TRUTH_TRACKER_2026-03-25.md](/home/gurpreet/projects/k8s/mereka-lms/docs/status/active/UI_RUNTIME_TRUTH_TRACKER_2026-03-25.md)
