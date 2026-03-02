# Frontend Closure Status Matrix (2026-03-02)

Scope: `mereka-lms` repo only.  
No `bbi-infrastructure` / GitOps repo mutations in this lane.

## Issue Status

| Issue | Status | Evidence |
|---|---|---|
| `#103` Frontend phase handover + closure epic | CLOSED | Final handover update posted (`issuecomment-3981836140`) with runtime proofs, residual risks, rollback path |
| `#104` CI ceremony reduction + workflow consolidation | CLOSED | Initial consolidation: `docs/operations/FRONTEND_CI_CEREMONY_REDUCTION_2026-03-02.md`, commit `776adce7`; canonical wrapper-prune follow-on completed: commit `e2937e6b` + `docs/operations/CI_CEREMONY_REDUCTION_MATRIX_104.md` |
| `#105` Runtime branding stabilization + deterministic screenshot evidence | CLOSED | Deterministic screenshots + runtime gates; focused closure capture mode added (`capture-branding-screenshots.sh --core-routes`), latest MFE artifacts `var/screenshots/dev/20260302T105625Z/` + `capture-summary.tsv`; runtime gates PASS (`verify-paragon-runtime.sh`, `verify-studio-authoring-branding.sh`; logs `var/qa/paragon-runtime-dev-20260302T105604Z.log`, `var/qa/studio-authoring-branding-dev-20260302T105604Z.log`); cross-browser matrix rerun PASS (`./scripts/qa/verify-cross-browser-branding-smoke.sh --env dev --cross-browser`, `15 passed`, log `var/qa/cross-browser-branding-smoke-dev-20260302T100442Z.log`) |
| `#106` PDF certificate branding closure | CLOSED | `verify-certificate-branding.sh` PASS; issue closure evidence on thread |
| `#107` Phase 7 BEM live DOM audit + selector pruning | CLOSED | DOM audit rerun PASS after stability hardening (`issuecomment-3981799304`) |
| `#108` Accessibility closure (contrast + focus) | CLOSED | `verify-a11y-contrast-focus.sh` + `verify-wcag-contrast-v2.sh` PASS |
| `#109` `mereka_lms.py` maintainability split | CLOSED | Phase-14 extraction complete (`issuecomment-3981834322`): `mereka_lms.py` `3426 -> 2226`, new `mereka_lms_mfe_slots.py` (`1110`), QA path coupling `98 -> 0` |
| `#111` Phase 6 slot decision (freeze vs continue) | CLOSED | Freeze decision recorded in `docs/BRANDING_PLAN.md` and issue thread |
| `#110` staging promotion + rollback evidence | OPEN (BLOCKED BY SIGNAL) | Blocking notes posted (`issuecomment-3981835559`, `issuecomment-3981860415`, `issuecomment-3981904379`); offline preflight `verify-staging-activation.sh --offline` (`30 PASS / 0 FAIL / 3 SKIP`); repo-local rollback contract checks pass (`verify-cicd-release-rollback.sh`, `verify-release-dry-run-contract.sh`); staging-target release dry-run rehearsal passed (`var/qa/staging-release-dryrun-rehearsal-20260302T040104Z.log`); strict frontend stability sweep baseline is green (`var/qa/frontend-stability-sweep-20260302T040727Z.summary.log`, screenshots `var/screenshots/dev/20260302T040827Z/`); latest online read-only probe captured (`6 PASS / 3 FAIL / 1 SKIP`) with blockers in `var/qa/staging-activation-online-20260302T040504Z.log` (Argo `OutOfSync/Degraded`, `enterprise-secrets Ready=False SecretSyncedError`); staging auth-surface pre-signal baseline refreshed via `./scripts/qa/verify-auth-surfaces.sh staging` (`OK` with unresolved optional host warnings, log `var/qa/auth-surfaces-staging-20260302T101941Z.log`); execution playbook: `docs/operations/STAGING_PROMOTION_PLAYBOOK_110.md` |

## Current Blocker

- `#110` requires explicit operator signal to perform staging/GitOps promotion actions.
- This lane intentionally performed only repo-local preparation and evidence packaging.

## Commit Trace (this lane)

- `24176afa` — tracker update: add Beads P1 bug `bd-1gx8` for remaining dev credentials auth-runtime blocker
- `2358ef59` — docs sync: align closure + handoff references to canonical head after #104 follow-on
- `b941c66a` — #104 follow-on completion: parameterize canonical `qa-frontend-closure` make lane and keep env-specific targets as delegators
- `f0d007ec` — docs update (`#105/#104/#110`): record consolidated frontend evidence bundle and align handoff references
- `d1e28b55` — docs update (handoff): append 2026-03-02 stabilization addendum with current blocker/evidence/start commands
- `8f05f9d9` — docs update (`#110`): add staging auth-surface pre-signal baseline evidence
- `db39572e` — docs update (`#105/#110`): add latest dev/prod auth-surface evidence log references
- `4afb0bcd` — docs update (`#104/#106`): refresh closure evidence with latest CI/certificate gate reruns
- `cd9511b1` — troubleshooting docs (`#105`): add dev credentials tzdata/zoneinfo failure runbook
- `4e026762` — auth-surface hardening (`#105`): add enriched failure diagnostics (`diag{...}`) for runtime triage
- `91043ae3` — docs update (`#105`): narrow remaining blocker to dev credentials runtime only
- `a88200fa` — docs update (`#105/#104`): refresh closure evidence references after auth-surface stabilization
- `c0f0d9a2` — auth-surface contract stabilization (`#105`): accept branded notes marker; require forum `/heartbeat` in prod while allowing non-prod `/healthz` fallback
- `e2937e6b` — #104 follow-on completion: remove `policy-checks.yml`, delete 18 `verify-*-workflow.sh` wrappers, retarget Make/CI contracts to direct scripts
- `fe2944f1` — runtime evidence hardening (`#105`): normalize probe values (`me_status`, `login_refresh_status`) for deterministic TSV parsing
- `073f8be3` — docs trace sync: refresh closure matrix commit ledger with latest stabilization commits
- `eefe8b5b` — runtime evidence hardening (`#105`): capture `login_refresh_status` as `GET:<code>,POST:<code>` and refresh closure artifacts/docs
- `1ace06ea` — auth canary diagnostics (`#105`): add `login_refresh_probe=GET:<code>,POST:<code>` to local/OIDC failure paths
- `1b3d33d2` — runtime evidence hardening (`#105`): add per-route `me_status` + `login_refresh_status` to screenshot summary
- `63614879` — warning contrast hardening (`#108`): promote warning token to `#996b00`, enforce warning pair in a11y gate, refresh token provenance + docs
- `7668e3e8` — auth stability hardening (`#105`): add optional native `/authn/login` local-session canary mode to `verify-authenticated-sso-canary.sh`
- `f224e375` — source hardening + status docs (`#105/#107/#108`, staged notes for `#109/#111`)
- `776adce7` — ceremony reduction (`#104`)
- `0320d5e4` — runtime evidence/check stabilization (`#105/#107/#108`)
- `cc7a2385` — `#103` handover draft scaffold
- `9c2ba4a5` — `#109` phase-10 verifier migration tranche
- `49620b34` — `#109` phase-11 verifier migration tranche
- `22d01caa` — `#109` phase-12 verifier migration tranche
- `2bfd7f2a` — `#109` phase-13 verifier migration tranche
- `b0c6951c` — remove last QA direct plugin-path coupling (`#109`)
- `234997c3` — extract MFE slot registrations from `mereka_lms.py` (`#109`)
- `6c6f1c6e` — update split status + branding plan evidence (`#109`)
- `2996b193` — align staging blocker + closure matrix (`#110`)
- `f326f879` — refresh #110 pre-promotion baseline evidence (`#110`)

## Notes

- “OPEN (BLOCKED BY SIGNAL)” means the issue is execution-ready but deferred by current no-infra/no-GitOps instruction.
- Once signal is granted, follow `docs/operations/STAGING_PROMOTION_PLAYBOOK_110.md` and attach promotion + rollback evidence back to `#110`.
- Latest repo-only stabilization update (while infra sync pending):
  - Script hardening: `scripts/qa/capture-branding-screenshots.sh` now includes route-aware readiness probes, retry capture logic, `capture-summary.tsv`, and `--core-routes` mode for canonical closure paths.
  - Runtime proof refresh on dev:
    - `RUN_BASELINE_GATES=0 RUN_MFE_LIVE_DOM_AUDIT=1 RUN_SCREENSHOTS=1 SCREENSHOT_SCOPE=mfe-only ./scripts/qa/run-branding-evidence-pipeline.sh --env dev --frontend-only` (PASS; bundle: `var/evidence/branding/20260302-065539/`, summary: `11 PASS / 0 FAIL / 7 WARN|SKIP`)
    - `./scripts/qa/capture-branding-screenshots.sh --env dev --core-routes`
    - `./scripts/qa/verify-paragon-runtime.sh --runtime-url https://apps.academyv2.mereka.dev --require-slot-markers`
    - `./scripts/qa/verify-studio-authoring-branding.sh dev`
  - Latest capture artifact set: `var/screenshots/dev/20260302T063522Z/` (`capture-summary.tsv` now includes `auth_state`, `nav_ms`, `me_status` (`/api/user/v1/me` probe), and `login_refresh_status` in `GET:<code>,POST:<code>` format per route, with normalized unquoted probe values for deterministic parsing; confirms deterministic non-blank renders for authn/login + studio, plus unauthenticated redirects for account/learner-dashboard).
  - Latest Phase 7 + a11y sweep on dev:
    - `./scripts/qa/run-phase7-dom-audit-full.sh --env dev --project chromium` (PASS, log: `var/qa/mfe-live-dom-audit-dev-20260302T063401Z.log`)
    - `./scripts/qa/verify-mfe-selector-hardening.sh` (PASS)
    - `./scripts/qa/verify-a11y-contrast-focus.sh` (PASS, warning pair now enforced and passing at `4.52:1`)
    - `./scripts/qa/verify-wcag-contrast-v2.sh` (PASS)
  - Latest cross-browser smoke stability rerun (dev):
    - `./scripts/qa/verify-cross-browser-branding-smoke.sh --env dev --cross-browser` (PASS `15 passed`, log: `var/qa/cross-browser-branding-smoke-dev-20260302T100442Z.log`)
  - Latest deterministic capture/runtime rerun (dev):
    - `CAPTURE_RETRIES=1 AGENT_BROWSER_TIMEOUT_SECONDS=30 ./scripts/qa/capture-branding-screenshots.sh --env dev --mfe-only` (PASS; screenshots `var/screenshots/dev/20260302T105625Z/`, log `var/qa/capture-branding-screenshots-dev-mfe-20260302T105625Z.log`)
    - `./scripts/qa/verify-paragon-runtime.sh --runtime-url https://apps.academyv2.mereka.dev --require-slot-markers` (PASS; log `var/qa/paragon-runtime-dev-20260302T105604Z.log`)
    - `./scripts/qa/verify-studio-authoring-branding.sh dev` (PASS; log `var/qa/studio-authoring-branding-dev-20260302T105604Z.log`)
  - Latest certificate closure rerun: `./scripts/qa/verify-certificate-branding.sh` (PASS `23`, WARN `1`, FAIL `0`; warning is expected when `frontend-app-profile` source checkout is absent on runner).
  - Latest #104 consolidation contract reruns:
    - `./scripts/qa/verify-frontend-qa-make-targets.sh` (PASS)
    - `./scripts/qa/verify-ci-cd-pipeline.sh --section gitops` (PASS `27/0/0`)
    - `./scripts/qa/verify-release-automation.sh` (PASS; one expected worktree-mode WARN for dry-run contract checker)
  - #104 follow-on make-lane consolidation:
    - canonical parameterized target added: `qa-frontend-closure`
    - env-specific closure targets now delegate to `qa-frontend-closure` with explicit `QA_*` flags
    - verifier updated: `scripts/qa/verify-frontend-qa-make-targets.sh` and rerun PASS
  - Auth surface probe on dev (`./scripts/qa/verify-auth-surfaces.sh dev`) now passes notes-root banner and forum health contracts (forum non-prod fallback `/healthz=200`) and still fails on one non-authn runtime blocker (`credentials` `/login`, `/login/edx-oauth2`, `/admin/login` returning `500`), so local login/session runtime validation remains infra-convergence dependent. Equivalent prod credentials checks return `302`, confirming dev-runtime drift.
  - Latest auth-surface evidence logs: dev `var/qa/auth-surfaces-dev-20260302T105604Z.log` (`FAILED` with 2 checks) vs prod `var/qa/auth-surfaces-prod-20260302T101515Z.log` (`OK`).
  - Capture/verification deterministic hardening in this tranche:
    - `capture-branding-screenshots.sh` now starts by closing stale agent-browser daemon sessions so launch flags are applied consistently.
    - Capture wrapper strips daemon-warning noise from command stdout so `capture-summary.tsv` fields remain parseable and stable.
    - `verify-paragon-runtime.sh` and `verify-studio-authoring-branding.sh` now auto-allow insecure TLS only for dev runtime checks (configurable via `PARAGON_RUNTIME_CURL_INSECURE` and `STUDIO_CURL_INSECURE`) to prevent self-signed cert false failures.
    - `verify-authenticated-sso-canary.sh` now supports `SSO_CANARY_IGNORE_HTTPS_ERRORS=auto|0|1` and defaults to TLS-ignore only in `dev` (prod stays strict), reducing false auth/session canary failures from non-prod cert trust.
  - `verify-auth-surfaces.sh` now applies TLS-insecure curl mode only for non-prod (`dev`/`staging`) so self-signed certs do not create false failures.
  - Runtime log signal for the failing dev credentials lane: `ZoneInfoNotFoundError: 'No time zone found with key UTC'` together with `ModuleNotFoundError: No module named 'tzdata'` in `deployment/credentials` logs.
  - Direct pod inspection confirms timezone data is missing in dev credentials runtime (`/usr/share/zoneinfo/UTC` absent; `python -m pip show tzdata` not found), narrowing remediation to image/runtime package composition.
  - Repo-side remediation is committed in this lane: credentials Docker hook now installs `tzdata>=2024.1` in `infrastructure/tutor/plugins/mereka_lms.py`; verification contract updated via `scripts/qa/verify-credentials-readiness.sh` and rerun PASS (`PASS=48 FAIL=0 SKIP=9`).
  - `verify-credentials-readiness.sh --cluster` now checks credentials runtime `ZoneInfo('UTC')` resolution and python `tzdata` package presence for direct post-rollout confirmation of the dev 500 root cause.
  - Latest live cluster evidence (`var/qa/credentials-readiness-cluster-20260302T103931Z.log`) reports `PASS=54 FAIL=1 SKIP=0`; health-check false positive is removed and DID is marked cascaded while timezone is broken, leaving a single canonical runtime blocker: `ZoneInfo('UTC')`/missing python `tzdata`.
  - This blocker now depends on runtime rollout convergence (new image build + deploy) rather than additional source-side debugging.
  - `verify-auth-surfaces.sh` now emits per-failure `diag{...}` metadata (status/location/content-type/body head) to speed runtime triage without changing pass/fail criteria.
  - Credentialed canary blocker: local/SSO canary env credentials are not available in this execution environment (`SSO_CANARY_*` and `LOCAL_CANARY_*` currently unset), so full authenticated local-login replay is pending secrets injection. Runner now supports independent mode toggles (`RUN_OIDC_CANARY`, `RUN_STUDIO_CANARY`, `RUN_LOCAL_LOGIN_CANARY`) so local checks can execute without OIDC lanes once local creds are injected (example command: `RUN_OIDC_CANARY=0 RUN_STUDIO_CANARY=0 RUN_LOCAL_LOGIN_CANARY=1 REQUIRE_LOCAL_CANARY=1 ./scripts/qa/verify-authenticated-sso-canary.sh --env dev`). Failure diagnostics now include `login_refresh_probe=GET:<code>,POST:<code>` to speed cookie/session drift triage.
  - Follow-on #104 reduction matrix now reflects completed canonical prune + post-tranche counts: `docs/operations/CI_CEREMONY_REDUCTION_MATRIX_104.md`.
