# DEV / Staging Truth Tracker
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-25T22:39:30Z • Status: active_

This is the current control tracker for making DEV and staging operational in a way that is truthful across runtime, GitOps, release evidence, and docs. The goal is not “more green”; the goal is “no false closure.”

## Current verified signal

The following repo-side guardrails were re-run on 2026-03-25 and passed:

- `bash scripts/qa/verify-deployment-contract.sh`
- `bash scripts/qa/verify-runtime-authority-map.sh`
- `bash scripts/qa/verify-lane-identity.sh`
- `bash scripts/qa/verify-nonprod-gate-readiness.sh` in `bbi-infrastructure`
- `ENABLE_STAGING_CHECKS=1 bash scripts/qa/verify-staging-activation-gate.sh` in `bbi-infrastructure`
- `bash scripts/ops/staging-cutover-preflight.sh` in `bbi-infrastructure`

These are no longer the bottleneck.

The following live/runtime checks were re-verified in this tranche:

- `bash scripts/qa/verify-tenant-contract-alignment.sh`
  - `PASS` after repo-side hostname contract repair
- `bash scripts/qa/verify-domain-url-invariants.sh`
  - `PASS` after adding a new staging toolkit drift check (`1c. Staging tenant toolkit alignment`)
- the last durable live host-admission probe recorded in this tracker was `5/9`
  - that probe pre-dates the merged infra runtime fix
  - do not treat `5/9` as current runtime truth until the corrected matrix is re-run against live staging
- `bash scripts/tenants/verify-staging-tenant-proof.sh --namespace stg-mereka-lms`
  - fresh run at `2026-03-25T15:28:49Z`
  - writes updated `var/proof/siteconfig-proof.json`, `var/proof/host-acceptance-proof.json`, `var/proof/cookie-proof.json`, `var/proof/staging-proof-summary.json`
  - result: `host acceptance: 5/9` on the corrected host matrix
- infra rollout patch prepared as `bbi-infrastructure#2127`
  - branch: `fix/staging-secondary-host-runtime-truth`
  - commit: `e9bbc317990ba82d481e9510048cc1e905fdf6ed`
  - scope: align staging `production-staging.py` allowlists/origins/redirects and `caddy-config-staging.yaml` host matchers/map entries to the verified secondary host contract
- `bbi-infrastructure#2127` is now merged on `main`
  - merge commit: `1bc401874a0ab4d0b7167d6420a099e70fd754b7`
- the last recorded LMS SiteConfiguration inspection in this tracker still showed stale secondary tenant URLs
  - this must be re-verified after the current runtime config tranche rather than repeated as assumed truth
- cookie/runtime proof is improved but not canonically closed
  - `SESSION_COOKIE_SECURE = true` is live
  - the last recorded runtime inspection still showed stale secondary Studio/MFE entries in `CSRF_TRUSTED_ORIGINS`
  - this must be re-verified in a fresh tracked run, not inferred from old pod-local inspection
- staging browser-proof secrets are now present in GitHub
  - present: `SSO_CANARY_EMAIL_STAGING`, `SSO_CANARY_PASSWORD_STAGING`, `SSO_CANARY_STUDIO_EMAIL_STAGING`, `SSO_CANARY_STUDIO_PASSWORD_STAGING`
- tracked browser proof is still blocked by workflow execution state, not secrets
  - `.github/workflows/smoke-authenticated.yml` is now `active`, but its separate `smoke-authenticated` job still depends on missing `SMOKE_SSO_USERNAME` / `SMOKE_SSO_PASSWORD` secrets, so it is not the clean staging-proof lane
  - `.github/workflows/operations-gates-runtime.yml` remains `disabled_manually` on GitHub
  - when temporarily enabled for a manual run, `operations-gates-runtime.yml` fails dispatch with `HTTP 422` because the workflow file on `origin/main` currently defines top-level `permissions` twice
- a clean app-repo fix branch now exists for the workflow blocker
  - worktree: `/tmp/mereka-lms-truth-20260325`
  - branch: `truth/staging-canary-contract-alignment`
  - head: `70fb95b2`
- `config/nonprod-execution-state.yaml` in `bbi-infrastructure` still says `ready_for_execution: false`
- LMS stabilization control board still says `Stabilization` is active and `Convergence` is blocked by non-canonical runtime/browser proof
- by explicit operator decision, DEV and staging continue sharing the same RKE2 nonprod cluster until `2026-05-01`
  - dedicated staging cluster provisioning and cutover are not the current next step

The following stale claims should NOT be trusted without re-running live proof:

- any prior `9/9` staging tenant proof based on the old secondary host list
- any tracker statement that marks staging runtime truth as closed before the corrected host matrix is admitted live

## Non-negotiable truth dimensions

| Dimension | Current state | Why still open |
|---|---|---|
| Repo contract truth | **strong** | static contracts and lane guards pass; 10/10 PASS |
| Staging runtime truth | **open** | repo-side contract is repaired, but the corrected host matrix has not yet been re-proven in a fresh tracked runtime/browser run |
| Staging auth/cookie truth | **open** | `SESSION_COOKIE_SECURE=true` is live and staging canary secrets now exist, but the clean tracked proof workflow (`operations-gates-runtime.yml`) cannot dispatch until its GitHub Actions syntax defect is fixed |
| Release / evidence truth | **not re-verified in this tranche** | no new canonical runtime closure was produced from the corrected host matrix |
| GitOps / ownership truth | mixed | deprecated overlay surfaces and dual-repo promotion behavior still exist |
| Topology / cutover truth | parked by operator decision | DEV and staging intentionally remain on the shared nonprod cluster until `2026-05-01` |
| DEV runtime residual truth | open but secondary | known parked defects remain, but they are lower leverage than staging truth + cutover |

## Highest-leverage work queue

### T-01 — Repair the canonical staging proof lane

Priority: `P0`
Owner surface: `mereka-lms`

Verified fact:

- staging canary secrets now exist
- the clean tracked proof lane is still blocked by app-repo workflow state, not by secrets
- `operations-gates-runtime.yml` is `disabled_manually`
- when enabled for a dispatch probe, GitHub rejects it with `HTTP 422` because the workflow defines top-level `permissions` twice

Done when:

- the duplicate-`permissions` defect is merged
- `operations-gates-runtime.yml` is syntax-valid on `main`
- the workflow can be re-enabled without parse failure

### T-02 — Produce fresh tracked staging runtime/browser evidence

Priority: `P0`
Owner surface: `mereka-lms`

Verified fact:

- repo-side canary and closure-level surfaces are stronger than they were at the start of the tranche
- no fresh tracked staging browser/runtime proof run exists yet on `main`

Done when:

- a tracked workflow run executes against `env_scope=staging`
- the corrected host matrix is re-proven from that tracked run
- the result is current merged evidence, not local `var/proof/**` only

### T-03 — Reconcile runtime and tracker truth after the tracked run

Priority: `P1`  
Owner surface: `mereka-lms` + `bbi-infrastructure`

Verified fact:

- this tracker currently mixes older live-probe findings with newer workflow-blocker findings
- dedicated staging cluster work was still described here as the next step even after the operator deferred it

Done when:

- live host admission, SiteConfiguration, and cookie/CSRF facts are reclassified from fresh evidence instead of repeated from older probes
- this tracker and the daily execution board agree on the next real blocker
- control docs are updated only if the new tracked evidence supports it

### T-04 — Keep dedicated staging cluster work explicitly parked until 2026-05-01

Priority: `P1`
Owner surface: `bbi-infrastructure` + planning surfaces

Verified fact:

- shared nonprod cluster is the accepted live topology for DEV and staging until `2026-05-01`
- telling the next operator to provision a dedicated staging cluster now is false prioritization

Done when:

- active trackers and takeover prompts all classify dedicated staging cluster provisioning and cutover as deferred work
- no current operator brief tells the next agent to start there first

### T-05 — Boundary extraction and DEV residual cleanup after proof lane unblockers

Priority: `P2`
Owner surface: mixed app + infra

Examples:

- deprecated app-side non-local overlays
- `ready_for_execution: false` follow-up once runtime truth is genuinely stronger
- parked DEV residuals such as bridge ConfigMaps and enterprise browser-auth proof

## Recommended execution order

1. `T-01` repair the canonical staging proof lane
2. `T-02` run fresh tracked staging runtime/browser proof
3. `T-03` reconcile tracker/runtime truth from that fresh evidence
4. `T-04` keep dedicated staging cluster work explicitly parked until `2026-05-01`
5. `T-05` only then resume lower-leverage cleanup

## Commands to rerun after each meaningful change

### App repo (`mereka-lms`)

- `bash scripts/qa/verify-deployment-contract.sh`
- `bash scripts/qa/verify-runtime-authority-map.sh`
- `bash scripts/qa/verify-lane-identity.sh`
- `bash scripts/tenants/verify-staging-tenant-proof.sh --namespace stg-mereka-lms`

### Infra repo (`bbi-infrastructure`)

- `bash scripts/qa/verify-nonprod-gate-readiness.sh`
- `ENABLE_STAGING_CHECKS=1 bash scripts/qa/verify-staging-activation-gate.sh`
- `bash scripts/qa/verify-passive-staging-status.sh --no-color`
- `bash scripts/qa/verify-namespace-alias-hazards.sh --no-color`
- `bash scripts/qa/verify-staging-cutover-prereqs.sh --no-color`
- `bash scripts/ops/staging-cutover-preflight.sh`

## Do not claim closure until all of these are true

- staging runtime/browser evidence is fresh, tracked, and tied to merged repo truth
- the corrected host matrix is re-proven from current live evidence, not repeated from older probes
- staging browser auth is proven with a real authenticated flow
- runtime evidence is canonical, not only local `var/proof/**`
- docs and execution-state agree with live reality

Dedicated staging cluster provisioning and cutover remain important, but they are explicitly deferred until `2026-05-01` and are not required for truthful closure of the current proof-lane blocker.

## Current handoff artifact

Use `docs/status/active/DEV_STAGING_TRUTH_TAKEOVER_PROMPT_2026-03-25.md` as the operator brief for the next agent.
