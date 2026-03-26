# DEV / Staging Truth Tracker
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-26T02:36:00Z • Status: active_

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
- the workflow-parse blocker on the canonical proof lane is now closed on `origin/main`
  - `operations-gates-runtime.yml` no longer defines top-level `permissions` twice
- tracked browser proof is still not closed, but the blocker has moved
  - `.github/workflows/smoke-authenticated.yml` is now `active`, but its separate `smoke-authenticated` job still depends on missing `SMOKE_SSO_USERNAME` / `SMOKE_SSO_PASSWORD` secrets, so it is not the clean staging-proof lane
  - `.github/workflows/operations-gates-runtime.yml` remains `disabled_manually` on GitHub
- a clean app-repo branch now exists for the next staging runtime-gates repair tranche
  - worktree: `/tmp/mereka-lms-pr1048-refresh`
  - branch: `truth/staging-runtime-gates-env-contract`
- current app-side tranche repairs the staging proof contract rather than workflow syntax
  - adds `staging` and `all` env support across the operations/auth/multisite QA chain
  - aligns SiteConfiguration / `MFE_CONFIG` writers to the explicit auth/cookie contract
  - corrects staging `course_org_filter` to `["MEREKA"]` in repo contract surfaces
- the app-side tranche is now published as `mereka-lms#1048`
  - state: `OPEN`
  - branch: `truth/staging-runtime-gates-env-contract`
  - follow-up verifier alignment is in the same PR branch; use the PR for the current head rather than this tracker for commit identity
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
  - `./scripts/qa/verify-auth-surfaces.sh staging` → `PASS`
    - canonical `staging.discovery.academyv2.mereka.io`, `staging.credentials.academyv2.mereka.io`, and `staging.ecommerce.academyv2.mereka.io` remain unresolved from this environment
    - compatibility aliases still resolve during the migration window, so the verifier now warns/skirts those checks instead of generating false `400` failures on legacy host order
  - `./scripts/qa/verify-multisite-config.sh staging` → `PASS`
    - verifier transport fixed to use the staging context by default and exec against a concrete running LMS pod instead of `deploy/lms`
  - `./scripts/qa/audit-auth-access.sh --env staging --mode public` → `PASS`
  - `./scripts/qa/run-multisite-governance-gates.sh --env staging` → `PASS`
  - `STRICT=1 ./scripts/qa/list-openedx-hostnames.sh --env staging` → `PASS`
    - staging compatibility aliases are now explicitly treated as migration-window extras instead of false drift
- the cross-repo host-contract repair is now published, not just described
  - `platform-control-plane#65` is `MERGED`
  - merge commit: `6e1fa4a5fae1f938863b89a6d0668367a83affcd`
  - scope: canonicalize the primary-tenant staging service host contract to `staging.<service>.academyv2.mereka.io`
  - validation: `./scripts/plan-all.sh --validate-only` → `PASS`
  - `bbi-infrastructure#2128` is `MERGED`
  - merge commit: `8f10dfd096d2d888b15f013c560e9c8c0f65202f`
  - scope: align staging overlay/certificate/domain-registry realization to the canonical host contract while preserving compatibility aliases during the migration window
  - validation: `make verify` → `PASS`
- the active-owner cert-manager follow-up is now also merged
  - `bbi-infrastructure#2131` is `MERGED`
  - merge commit: `b8c4ab0af558ab909ae15701ddd521c50f7924cf`
  - scope: realize `letsencrypt-bijibiji-staging` and its Cloudflare ExternalSecret in the active shared-cluster cert-manager owner
  - validation: `make verify` → `PASS`
- live staging has moved forward materially, but runtime/browser truth is still not canonically closed
  - hard-refresh reconciliation exposed the real diff and brought canonical staging primary-tenant service hosts into live Caddy/TLS surfaces
  - the shared-cluster cert-manager owner is now aligned with the Biji-Biji staging issuer contract
    - `cert-manager-dev` is back to `Synced` / `Healthy`
    - `letsencrypt-bijibiji-staging` is live and tracked by `cert-manager-dev`
    - `ClusterIssuer/letsencrypt-bijibiji-staging` is `Ready=True` with `reason=ACMEAccountRegistered`
  - all three Biji-Biji staging certificates are now live on the intended issuer
    - `openedx-biji-biji-lms-tls` → `Ready=True`, `issuer=letsencrypt-bijibiji-staging`, `notAfter=2026-06-24T01:35:18Z`
    - `openedx-biji-biji-mfe-tls` → `Ready=True`, `issuer=letsencrypt-bijibiji-staging`, `notAfter=2026-06-24T01:35:41Z`
    - `openedx-biji-biji-studio-tls` → `Ready=True`, `issuer=letsencrypt-bijibiji-staging`, `notAfter=2026-06-24T01:35:40Z`
  - `mereka-lms-staging` is now `Synced` / `Progressing` at revision `b8c4ab0af558ab909ae15701ddd521c50f7924cf`
    - current Argo snapshot shows no `OutOfSync` resources on the app
  - live staging still serves compatibility aliases during the migration window:
    - `admin.staging.academyv2.mereka.io`
    - `discovery.staging.academyv2.mereka.io`
    - `notes.staging.academyv2.mereka.io`
    - `credentials.staging.academyv2.mereka.io`
    - `learner.staging.academyv2.mereka.io`
    - `staging.discovery.mereka.io`
    - `staging.notes.mereka.io`
    - `staging.credentials.mereka.io`
    - `staging.ecommerce.mereka.io`
  - the old Biji-Biji TLS residual set is closed
    - the remaining blocker chain is now narrower than hostname/certificate realization drift
  - the next real blockers are:
    - `mereka-lms#1048` is still open and requires external review before merge
    - `.github/workflows/operations-gates-runtime.yml` is still `disabled_manually`
    - there is still no fresh tracked staging authenticated/browser proof run tied to the merged runtime state
  - `platform-control-plane` staging DNS/cert readiness surfaces are now canonicalized for the primary staging service hosts and remain aligned with the “pending external dependency” posture for public DNS/TLS readiness
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
| Repo contract truth | **strong but not fully merged** | control-plane and GitOps runtime repairs are now merged, but the app-side repair in `mereka-lms#1048` is still open |
| Staging runtime truth | **stronger, not canonically closed** | live host/cert realization is materially repaired, but there is still no tracked browser/runtime closure |
| Staging auth/cookie truth | **partial** | public auth surfaces and MFE config/cookie contract now pass on live staging, but there is still no fresh tracked browser-proof run against the corrected merged state |
| Release / evidence truth | **not re-verified in this tranche** | no new canonical runtime closure was produced from the corrected host matrix |
| GitOps / ownership truth | **runtime-validated for the cert-manager lane** | `bbi-infrastructure#2128` and `#2131` are merged, and the live shared-cluster cert-manager owner now serves the intended Biji-Biji staging issuer |
| Topology / cutover truth | parked by operator decision | DEV and staging intentionally remain on the shared nonprod cluster until `2026-05-01` |
| DEV runtime residual truth | open but secondary | known parked defects remain, but they are lower leverage than staging truth + cutover |

## Highest-leverage work queue

### T-01 — Merge the published app-side staging runtime-gates repair tranche

Priority: `P0`
Owner surface: `mereka-lms`

Verified fact:

- staging canary secrets now exist
- the workflow-parse blocker is already fixed on `origin/main`
- the app-side runtime-gates/config repair is already published as `mereka-lms#1048`

Done when:

- `mereka-lms#1048` is merged on `main`
- static verification and scoped staging auth/MFE checks remain green
- only the live GitOps hostname realization drift remains red

### T-02 — Produce fresh tracked staging runtime/browser evidence

Priority: `P0`
Owner surface: `mereka-lms`

Verified fact:

- staging canary secrets exist
- cross-repo host and cert-manager runtime repairs are merged and live
- the remaining proof gap is now the absence of a fresh tracked authenticated/browser run

Done when:

- a tracked workflow run executes against `env_scope=staging`
- the corrected merged runtime state is proven from tracked evidence, not local-only probes
- staging browser auth is proven on the current merged host/cookie contract

### T-03 — Reconcile runtime and tracker truth after the tracked run

Priority: `P0`
Owner surface: `mereka-lms` + `bbi-infrastructure`

Verified fact:

- this tracker still contains older blocker language from before `bbi-infrastructure#2131`
- stabilization docs should not be promoted until the fresh tracked run exists

Done when:

- this tracker and the daily board both describe the same remaining blocker chain
- control docs are updated only if the tracked runtime/browser evidence supports it
- no old hostname/certificate residual is left stated as an active blocker after it was fixed live

### T-04 — Keep dedicated staging cluster work explicitly parked until 2026-05-01

Priority: `P1`
Owner surface: `bbi-infrastructure` + planning surfaces

Verified fact:

- shared nonprod cluster remains the accepted live topology for DEV and staging until `2026-05-01`
- that should stay explicitly separate from proof-lane closure work

Done when:

- active trackers and takeover prompts all classify dedicated staging cluster work as deferred
- no current brief sends the next operator into topology cutover before the proof lane closes

### T-05 — Boundary extraction and DEV residual cleanup after proof lane unblockers

Priority: `P1`
Owner surface: mixed app + infra

Examples:

- deprecated app-side non-local overlays
- `ready_for_execution: false` follow-up once runtime truth is genuinely stronger
- parked DEV residuals such as bridge ConfigMaps and enterprise browser-auth proof

## Recommended execution order

1. `T-01` merge the published app-side staging runtime-gates repair tranche
2. `T-02` run fresh tracked staging runtime/browser proof
3. `T-03` reconcile tracker/runtime truth from that fresh evidence
4. `T-04` keep dedicated staging cluster work explicitly parked until `2026-05-01`
5. `T-05` only then resume lower-leverage cleanup

## Commands to rerun after each meaningful change

### App repo (`mereka-lms`)

- `bash scripts/qa/verify-deployment-contract.sh`
- `bash scripts/qa/verify-runtime-authority-map.sh`
- `bash scripts/qa/verify-lane-identity.sh`
- `bash scripts/qa/verify-staging-vocabulary-drift.sh`
- `bash scripts/qa/verify-mfe-config-contract.sh --env staging`
- `bash scripts/qa/audit-auth-access.sh --env staging --mode public`
- `bash scripts/qa/run-multisite-governance-gates.sh --env staging`
- `bash scripts/tenants/verify-staging-tenant-proof.sh --namespace stg-mereka-lms`

### Infra repo (`bbi-infrastructure`)

- `bash scripts/qa/verify-nonprod-gate-readiness.sh`
- `ENABLE_STAGING_CHECKS=1 bash scripts/qa/verify-staging-activation-gate.sh`
- `bash scripts/qa/verify-passive-staging-status.sh --no-color`
- `bash scripts/qa/verify-namespace-alias-hazards.sh --no-color`
- `bash scripts/qa/verify-staging-cutover-prereqs.sh --no-color`
- `bash scripts/ops/staging-cutover-preflight.sh`
- `make verify`

### Control-plane repo (`platform-control-plane`)

- `./scripts/guardrails/verify-staging-dns-cert-readiness.sh`
- `./scripts/guardrails/verify-control-plane-merge-safety.sh`
- `./scripts/plan-all.sh --validate-only`

## Do not claim closure until all of these are true

- staging runtime/browser evidence is fresh, tracked, and tied to merged repo truth
- `mereka-lms#1048`, `platform-control-plane#65`, `bbi-infrastructure#2128`, and `bbi-infrastructure#2131` are merged or their exact blocker state is recorded
- the corrected host matrix is re-proven from current live evidence, not repeated from older probes
- staging browser auth is proven with a real authenticated flow
- runtime evidence is canonical, not only local `var/proof/**`
- docs and execution-state agree with live reality

Dedicated staging cluster provisioning and cutover remain important, but they are explicitly deferred until `2026-05-01` and are not required for truthful closure of the current proof-lane blocker.

## Current handoff artifact

Use `docs/status/active/DEV_STAGING_TRUTH_TAKEOVER_PROMPT_2026-03-25.md` as the operator brief for the next agent.
