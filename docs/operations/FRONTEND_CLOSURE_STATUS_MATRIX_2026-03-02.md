# Frontend Closure Status Matrix (2026-03-02)

Scope: `mereka-lms` repo only.  
No `bbi-infrastructure` / GitOps repo mutations in this lane.

## Issue Status

| Issue | Status | Evidence |
|---|---|---|
| `#103` Frontend phase handover + closure epic | CLOSED | Final handover update posted (`issuecomment-3981836140`) with runtime proofs, residual risks, rollback path |
| `#104` CI ceremony reduction + workflow consolidation | CLOSED | Initial consolidation: `docs/operations/FRONTEND_CI_CEREMONY_REDUCTION_2026-03-02.md`, commit `776adce7`; canonical wrapper-prune follow-on completed: commit `e2937e6b` + `docs/operations/CI_CEREMONY_REDUCTION_MATRIX_104.md` |
| `#105` Runtime branding stabilization + deterministic screenshot evidence | CLOSED | Deterministic screenshots + runtime gates; focused closure capture mode added (`capture-branding-screenshots.sh --core-routes`), latest artifacts `var/screenshots/dev/20260302T061514Z/` + `capture-summary.tsv`; runtime gates PASS (`verify-paragon-runtime.sh`, `verify-studio-authoring-branding.sh`) |
| `#106` PDF certificate branding closure | CLOSED | `verify-certificate-branding.sh` PASS; issue closure evidence on thread |
| `#107` Phase 7 BEM live DOM audit + selector pruning | CLOSED | DOM audit rerun PASS after stability hardening (`issuecomment-3981799304`) |
| `#108` Accessibility closure (contrast + focus) | CLOSED | `verify-a11y-contrast-focus.sh` + `verify-wcag-contrast-v2.sh` PASS |
| `#109` `mereka_lms.py` maintainability split | CLOSED | Phase-14 extraction complete (`issuecomment-3981834322`): `mereka_lms.py` `3426 -> 2226`, new `mereka_lms_mfe_slots.py` (`1110`), QA path coupling `98 -> 0` |
| `#111` Phase 6 slot decision (freeze vs continue) | CLOSED | Freeze decision recorded in `docs/BRANDING_PLAN.md` and issue thread |
| `#110` staging promotion + rollback evidence | OPEN (BLOCKED BY SIGNAL) | Blocking notes posted (`issuecomment-3981835559`, `issuecomment-3981860415`, `issuecomment-3981904379`); offline preflight `verify-staging-activation.sh --offline` (`30 PASS / 0 FAIL / 3 SKIP`); repo-local rollback contract checks pass (`verify-cicd-release-rollback.sh`, `verify-release-dry-run-contract.sh`); staging-target release dry-run rehearsal passed (`var/qa/staging-release-dryrun-rehearsal-20260302T040104Z.log`); strict frontend stability sweep baseline is green (`var/qa/frontend-stability-sweep-20260302T040727Z.summary.log`, screenshots `var/screenshots/dev/20260302T040827Z/`); latest online read-only probe captured (`6 PASS / 3 FAIL / 1 SKIP`) with blockers in `var/qa/staging-activation-online-20260302T040504Z.log` (Argo `OutOfSync/Degraded`, `enterprise-secrets Ready=False SecretSyncedError`); execution playbook: `docs/operations/STAGING_PROMOTION_PLAYBOOK_110.md` |

## Current Blocker

- `#110` requires explicit operator signal to perform staging/GitOps promotion actions.
- This lane intentionally performed only repo-local preparation and evidence packaging.

## Commit Trace (this lane)

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
    - `./scripts/qa/capture-branding-screenshots.sh --env dev --core-routes`
    - `./scripts/qa/verify-paragon-runtime.sh --runtime-url https://apps.academyv2.mereka.dev --require-slot-markers`
    - `./scripts/qa/verify-studio-authoring-branding.sh dev`
  - Latest capture artifact set: `var/screenshots/dev/20260302T061514Z/` (`capture-summary.tsv` now includes `auth_state`, `nav_ms`, `me_status` (`/api/user/v1/me` probe), and `login_refresh_status` in `GET:<code>,POST:<code>` format per route, with normalized unquoted probe values for deterministic parsing; confirms deterministic non-blank renders for authn/login + studio, plus unauthenticated redirects for account/learner-dashboard).
  - Latest Phase 7 + a11y sweep on dev:
    - `./scripts/qa/run-phase7-dom-audit-full.sh --env dev --project chromium` (PASS, log: `var/qa/mfe-live-dom-audit-dev-20260302T054715Z.log`)
    - `./scripts/qa/verify-mfe-selector-hardening.sh` (PASS)
    - `./scripts/qa/verify-a11y-contrast-focus.sh` (PASS, warning pair now enforced and passing at `4.52:1`)
    - `./scripts/qa/verify-wcag-contrast-v2.sh` (PASS)
  - Auth surface probe on dev (`./scripts/qa/verify-auth-surfaces.sh dev`) still fails outside authn lane (`credentials` 500, `notes` banner mismatch, `forum/heartbeat` 404), so local login/session runtime validation remains infra-convergence dependent.
  - Credentialed canary blocker: local/SSO canary env credentials are not available in this execution environment (`SSO_CANARY_*` and `LOCAL_CANARY_*` currently unset), so full authenticated local-login replay is pending secrets injection. Runner now supports independent mode toggles (`RUN_OIDC_CANARY`, `RUN_STUDIO_CANARY`, `RUN_LOCAL_LOGIN_CANARY`) so local checks can execute without OIDC lanes once local creds are injected (example command: `RUN_OIDC_CANARY=0 RUN_STUDIO_CANARY=0 RUN_LOCAL_LOGIN_CANARY=1 REQUIRE_LOCAL_CANARY=1 ./scripts/qa/verify-authenticated-sso-canary.sh --env dev`). Failure diagnostics now include `login_refresh_probe=GET:<code>,POST:<code>` to speed cookie/session drift triage.
  - Follow-on #104 reduction matrix now reflects completed canonical prune + post-tranche counts: `docs/operations/CI_CEREMONY_REDUCTION_MATRIX_104.md`.
