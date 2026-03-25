# DEV / Staging Truth Tracker
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-25T08:21:00Z • Status: active_

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

The following live/runtime checks have been updated:

- `bash scripts/tenants/verify-staging-tenant-proof.sh --namespace stg-mereka-lms`
  - first run: 2026-03-25T05:27:16Z → `host acceptance: 5/9` (4 failures: Convention B hostnames not in ALLOWED_HOSTS)
  - **fix applied**: aligned all staging hostnames to Convention A (`staging.{role}.{domain}`) across 18 files in app repo + 1 file in infra repo
  - **re-run: 2026-03-25T08:21:00Z → `host acceptance: 9/9`** — all staging hosts accepted by Django
  - proof artifacts: `var/proof/siteconfig-proof.json`, `var/proof/host-acceptance-proof.json`, `var/proof/cookie-proof.json`, `var/proof/staging-proof-summary.json`
- `config/nonprod-execution-state.yaml` in `bbi-infrastructure` still says `ready_for_execution: false`
- LMS stabilization control board still says `Stabilization` is active and `Convergence` is blocked by non-canonical runtime/browser proof

The following runtime checks still have open findings:

- cookie-proof.json reports `SESSION_COOKIE_SAMESITE = "None"` with `SESSION_COOKIE_SECURE = false` — this is a T-02 issue, not T-01
- 48 multisite middleware unit tests pass (both Convention A and Convention B inputs handled correctly)

## Non-negotiable truth dimensions

| Dimension | Current state | Why still open |
|---|---|---|
| Repo contract truth | **strong** | static contracts and lane guards pass; 10/10 PASS |
| Staging runtime truth | **CLOSED** | live staging tenant proof is `9/9` (fixed 2026-03-25T08:21:00Z) |
| Staging auth/cookie truth | **fix applied, pending deploy** | root cause: Django default `False` + missing explicit `True` in staging overlay. Fix in PR #2125. After merge+deploy, cookies will work correctly (T-02) |
| Release / evidence truth | **fix applied** | proof artifacts now emit `closure_level: static\|runtime`; `--skip-cluster` no longer masquerades as canonical (T-03) |
| GitOps / ownership truth | mixed | deprecated overlay surfaces and dual-repo promotion behavior still exist |
| Topology / cutover truth | blocked by infra | dedicated staging cluster is not yet the active runtime target |
| DEV runtime residual truth | open but secondary | known parked defects remain, but they are lower leverage than staging truth + cutover |

## Highest-leverage work queue

### T-01 — Resolve staging hostname contract split — **RESOLVED 2026-03-25T08:21:00Z**

Priority: `P0`
Owner surface: `mereka-lms` first, then `bbi-infrastructure` if canonical shape must change

**Decision**: Convention A (`staging.{role}.{domain}`) is canonical. It matches live DNS, TLS, ingress, ALLOWED_HOSTS, and Caddy in the infra repo. Convention B (`{role}.staging.{domain}`) was aspirational but never deployed to live infrastructure. The multisite middleware handles both conventions (48 unit tests pass).

**Root cause of 5/9**: The proof script tested Convention B hostnames for biji-biji/skillourfuture tenants (`studio.staging.X`, `apps.staging.X`), but Django ALLOWED_HOSTS only had Convention A (`staging.studio.X`, `staging.apps.X`). Those 4 hosts returned HTTP 400.

**Fix applied**: Aligned all staging hostnames to Convention A across both repos:
- App repo: 18 files changed (tenant-registry, contract doc, staging.env, proof scripts, overlay manifests, config.sh, experience-proof.py)
- Infra repo: 1 file changed (caddy-config-staging.yaml — biji-biji/skillourfuture matchers)

**Result**: `bash scripts/tenants/verify-staging-tenant-proof.sh --namespace stg-mereka-lms` → `host acceptance: 9/9`

**Verification suite (all PASS)**:
- `verify-deployment-contract.sh`: 10/10 PASS
- `verify-runtime-authority-map.sh`: ALL CHECKS PASSED
- `verify-lane-identity.sh`: 33/33 PASS
- `test_mereka_multisite.py`: 48/48 PASS
- `verify-staging-tenant-proof.sh`: 9/9 PASS

### T-02 — Close staging browser / cookie truth — **FIX APPLIED 2026-03-25T08:30:00Z (pending deploy)**

Priority: `P0`
Owner surface: `bbi-infrastructure`

**Root cause identified and fixed**:

- `SESSION_COOKIE_SECURE = false` because Django defaults to `False`, and neither upstream Open edX nor Tutor base settings set it
- The staging overlay previously removed the explicit `True`, trusting a nonexistent "app-repo base" default
- `SameSite=None` REQUIRES `Secure=True` — modern browsers silently reject `SameSite=None` cookies without `Secure`
- This means staging session cookies were being **silently dropped by browsers**
- Both dev and prod overlays already set `SESSION_COOKIE_SECURE = True` explicitly

**Fix**: Added `SESSION_COOKIE_SECURE = True` and `CSRF_COOKIE_SECURE = True` to `production-staging.py` in bbi-infrastructure PR #2125.

**Status**: Fix is in PR, not yet deployed. After merge + ArgoCD sync + pod restart, re-run cookie proof to confirm `SESSION_COOKIE_SECURE = true`.

Done when:

- PR #2125 is merged and ArgoCD deploys updated production-staging.py
- cookie-proof.json reports `SESSION_COOKIE_SECURE = true`
- staging sign-in flow succeeds in browser (SameSite=None + Secure=True = cookies accepted)

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

- DEV Notes `400`
- staging-derived bridge ConfigMaps mounted in DEV
- Argo green overstating DEV config correctness
- enterprise browser auth only probe-verified

Done when:

- parked items are either closed with proof or explicitly reclassified with a durable owner lane

## Recommended execution order

1. `T-01` staging hostname contract split
2. `T-02` staging browser/cookie truth
3. `T-03` canonical runtime evidence
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

- staging tenant proof is `9/9`
- staging browser auth is proven with real authenticated flow
- runtime evidence is canonical, not only local `var/proof/**`
- dedicated staging cluster exists and is the real target
- cutover is executed and shared-cluster bridge debt is retired
- docs and execution-state agree with live reality

## Current handoff artifact

Use `docs/status/active/DEV_STAGING_TRUTH_TAKEOVER_PROMPT_2026-03-25.md` as the operator brief for the next agent.
