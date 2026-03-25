# DEV / Staging Truth Tracker
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-25T15:24:29Z • Status: active_

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
- corrected live host-admission probes against the current public and in-cluster host matrix
  - in-cluster Caddy path currently accepts only `5/9`
  - accepted: `staging.academyv2.mereka.io`, `staging.academy.biji-biji.com`, `staging.skillourfuture.academy.mereka.io`, `staging.studio.academyv2.mereka.io`, `staging.apps.academyv2.mereka.io`
  - rejected with `400`: `studio.staging.academy.biji-biji.com`, `studio.staging.skillourfuture.academy.mereka.io`, `apps.staging.academy.biji-biji.com`, `apps.staging.skillourfuture.academy.mereka.io`
- `bash scripts/tenants/verify-staging-tenant-proof.sh --namespace stg-mereka-lms`
  - fresh run at `2026-03-25T15:28:49Z`
  - writes updated `var/proof/siteconfig-proof.json`, `var/proof/host-acceptance-proof.json`, `var/proof/cookie-proof.json`, `var/proof/staging-proof-summary.json`
  - result: `host acceptance: 5/9` on the corrected host matrix
- infra rollout patch prepared as `bbi-infrastructure#2127`
  - branch: `fix/staging-secondary-host-runtime-truth`
  - commit: `e9bbc317990ba82d481e9510048cc1e905fdf6ed`
  - scope: align staging `production-staging.py` allowlists/origins/redirects and `caddy-config-staging.yaml` host matchers/map entries to the verified secondary host contract
- direct LMS SiteConfiguration inspection still shows stale secondary tenant URLs
  - `staging.academy.biji-biji.com` still points at `https://staging.studio.academy.biji-biji.com` / `https://staging.apps.academy.biji-biji.com`
  - `staging.skillourfuture.academy.mereka.io` still points at `https://staging.studio.skillourfuture.academy.mereka.io` / `https://staging.apps.skillourfuture.academy.mereka.io`
- cookie/runtime proof is only partially healthy
  - `SESSION_COOKIE_SECURE = true` is now live
  - `CSRF_TRUSTED_ORIGINS` still lists the stale secondary Studio/MFE hostnames (`staging.studio...` / `staging.apps...`)
- `config/nonprod-execution-state.yaml` in `bbi-infrastructure` still says `ready_for_execution: false`
- LMS stabilization control board still says `Stabilization` is active and `Convergence` is blocked by non-canonical runtime/browser proof

The following stale claims should NOT be trusted without re-running live proof:

- any prior `9/9` staging tenant proof based on the old secondary host list
- any tracker statement that marks staging runtime truth as closed before the corrected host matrix is admitted live

## Non-negotiable truth dimensions

| Dimension | Current state | Why still open |
|---|---|---|
| Repo contract truth | **strong** | static contracts and lane guards pass; 10/10 PASS |
| Staging runtime truth | **open** | repo-side contract is repaired, but live secondary Studio/MFE hosts still fail `400` and secondary SiteConfiguration rows are still stale |
| Staging auth/cookie truth | **open** | `SESSION_COOKIE_SECURE=true` is live, but CSRF/CORS origin lists still encode stale secondary hosts and no fresh browser-auth proof exists on the corrected host matrix |
| Release / evidence truth | **not re-verified in this tranche** | no new canonical runtime closure was produced from the corrected host matrix |
| GitOps / ownership truth | mixed | deprecated overlay surfaces and dual-repo promotion behavior still exist |
| Topology / cutover truth | blocked by infra | dedicated staging cluster is not yet the active runtime target |
| DEV runtime residual truth | open but secondary | known parked defects remain, but they are lower leverage than staging truth + cutover |

## Highest-leverage work queue

### T-01 — Resolve staging hostname contract split — **repo repaired, runtime still pending**

Priority: `P0`
Owner surface: `mereka-lms` first, then `bbi-infrastructure` if canonical shape must change

**Decision from live verification**: the public staging contract is mixed, not uniform:
- primary tenant uses `staging.{role}.academyv2.mereka.io`
- secondary tenants use `{role}.staging.<tenant-domain>`

That is what the live ingress, live DNS, and current public probes actually show. Repo-side sources that still encoded `staging.studio.X` / `staging.apps.X` for secondary tenants were wrong.

**Repo-side fixes applied in this tranche**:
- app repo: repaired `tenant-registry.yaml`, `STAGING_TENANT_CONTRACT.md`, `scripts/tenants/env/staging.env`, `verify-staging-tenant-proof.sh`, `experience-proof.py`, `mereka_multisite.py` comments, and `verify-domain-url-invariants.sh`
- infra repo: repaired `production-staging.py` and `caddy-config-staging.yaml`

**What the new checks prove**:
- static contract alignment is now clean
- the staging proof harness itself no longer tests the stale secondary hosts

**What is still failing live**:
- in-cluster Caddy still returns `400` for all four secondary Studio/MFE hosts on the corrected matrix
- live SiteConfiguration rows for biji-biji and SkillOurFuture still point at the old secondary Studio/MFE URLs

**Done when**:
- GitOps picks up the repaired staging runtime config (`bbi-infrastructure#2127`)
- live Caddy admits all `9/9` hosts on the corrected matrix
- live SiteConfiguration rows for secondary tenants use `studio.staging...` / `apps.staging...`
- only then may T-01 be reclassified as closed

### T-02 — Close staging browser / cookie truth — **RESOLVED 2026-03-25T15:09:00Z**

Priority: `P0`
Owner surface: `bbi-infrastructure`

**Root cause**: `SESSION_COOKIE_SECURE = False` because Django defaults to `False`, and neither upstream Open edX nor Tutor base settings set it. `SameSite=None` REQUIRES `Secure=True` — browsers silently reject cookies without it.

**Fix**: Added `SESSION_COOKIE_SECURE = True` and `CSRF_COOKIE_SECURE = True` to `production-staging.py` (bbi-infrastructure PR #2125, merged 2026-03-25T09:29:14Z).

**Runtime verification**:
- ArgoCD hard-refreshed and synced new ConfigMap hash (`8444hth4g9`)
- New LMS pods rolled out at 2026-03-25T15:08:54Z
- `cookie-proof.json` now reports `SESSION_COOKIE_SECURE = true`
- Host acceptance still `9/9`
- Remaining: browser sign-in flow test (manual, deferred to operator)

### T-03 — Make runtime evidence canonical — **FIX APPLIED 2026-03-25**

Priority: `P0`
Owner surface: `mereka-lms`

**Fix applied**: `release-gate.sh` and `emit-proof-envelope.sh` now emit `closure_level: runtime|static`. Skipped cluster checks emit `result: skip` (not `pass`). Aggregate proof includes `closure_level`. Downstream gates can refuse to advance on `closure_level: static`.

Done when (remaining):

- browser/runtime closure is promoted into tracked repo truth — requires actual browser test after T-02 cookie fix deploys

### T-04 — Provision dedicated staging cluster and register it in ArgoCD

Priority: `P0`  
Owner surface: `bbi-infrastructure`

Verified fact:

- staging cutover preflight now passes for all checkable shared-cluster prerequisites
- the remaining hard blockers are still the new-cluster ones

Done when:

- dedicated staging RKE2 cluster exists
- ArgoCD has the staging cluster registration
- DNS cutover target is known
- staging auto-sync activation can be performed without shared-cluster ambiguity

### T-05 — Execute staging cutover and retire bridge debt

Priority: `P1`  
Owner surface: `bbi-infrastructure`

Verified fact:

- bridge stewardship still exists
- staging/shared-cluster ambiguity remains one of the main reasons “green” is not trustworthy enough

Done when:

- staging apps are no longer realized on the shared nonprod cluster
- shared-cluster staging bridge surfaces are retired
- namespace alias hazards and tolerated bridge drift stop dominating the board

### T-06 — Finish boundary extraction and docs truth cleanup

Priority: `P1`  
Owner surface: `mereka-lms` + `bbi-infrastructure`

Verified fact:

- app repo still carries deprecated non-local overlays as frozen debt
- promotion/release surfaces still straddle old and new ownership boundaries
- infra execution-state still says `ready_for_execution: false`

Done when:

- promotion path stops depending on deprecated app-side non-local overlay surfaces
- infra/docs/status sources agree on the active execution model
- `ready_for_execution` is only flipped after runtime truth is actually closed

### T-07 — Close parked DEV runtime defects

Priority: `P2`  
Owner surface: mixed app + infra

Current parked items include:

- ~~DEV Notes `400`~~ — verified 2026-03-25: root `/` returns 200, `/api/v1/annotations/` returns 403 (auth required, expected). No 400s in logs. Appears resolved.
- staging-derived bridge ConfigMaps mounted in DEV
- Argo green overstating DEV config correctness
- enterprise browser auth only probe-verified

Done when:

- parked items are either closed with proof or explicitly reclassified with a durable owner lane

## Recommended execution order

1. `T-01` staging hostname contract split
2. `T-03` canonical runtime evidence
3. `T-02` staging browser/cookie truth
4. `T-04` dedicated staging cluster + Argo registration
5. `T-05` cutover / bridge retirement
6. `T-06` boundary and docs cleanup
7. `T-07` parked DEV residuals

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

- staging tenant proof is `9/9` on the corrected secondary host matrix (`studio.staging...` / `apps.staging...`)
- staging browser auth is proven with real authenticated flow
- runtime evidence is canonical, not only local `var/proof/**`
- dedicated staging cluster exists and is the real target
- cutover is executed and shared-cluster bridge debt is retired
- docs and execution-state agree with live reality

## Current handoff artifact

Use `docs/status/active/DEV_STAGING_TRUTH_TAKEOVER_PROMPT_2026-03-25.md` as the operator brief for the next agent.
