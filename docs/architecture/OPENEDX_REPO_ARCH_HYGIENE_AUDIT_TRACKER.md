# Open edX Repository Architecture and Hygiene Audit Tracker

Last updated: 2026-03-06  
Auditor/Implementor: Codex (audit + implementation guardrail rollout)

## Purpose

This tracker consolidates audit findings across repository hygiene, theming, IaC boundaries, multi-tenancy routing, and payment fulfillment resilience so implementors can execute remediation in a controlled, prioritized way.

## Implementor Specs

- Execution-ready child issue specs (AC + migration + rollback):
  - `docs/architecture/OPENEDX_REPO_AUDIT_IMPLEMENTOR_SPECS.md`
- Ordered execution board:
  - `docs/architecture/OPENEDX_REPO_AUDIT_EXECUTION_BOARD.md`
- Issue-specific implementation packets:
  - `docs/architecture/OPENEDX_REPO_AUDIT_ISSUE_215_PACKET.md`
  - `docs/architecture/OPENEDX_REPO_AUDIT_ISSUE_216_PACKET.md`
  - `docs/architecture/OPENEDX_REPO_AUDIT_ISSUE_217_PACKET.md`
  - `docs/architecture/OPENEDX_REPO_AUDIT_ISSUE_218_PACKET.md`
  - `docs/architecture/OPENEDX_REPO_AUDIT_ISSUE_219_PACKET.md`
  - `docs/architecture/OPENEDX_REPO_AUDIT_ISSUE_220_PACKET.md`
  - `docs/architecture/OPENEDX_REPO_AUDIT_ISSUE_221_PACKET.md`
  - `docs/architecture/OPENEDX_REPO_AUDIT_ISSUE_222_PACKET.md`

## Audit Guardrails

- Scope: non-destructive implementation guardrails first (CI policy, verifier scripts, `.gitignore` hardening).
- Method: static repo inspection + workflow/script tracing + incremental atomic PRs.
- Evidence style: file-backed findings with concrete paths + PR-linked execution trail.
- Status refresh command: `./scripts/qa/sync-openedx-audit-pr-status.sh`
- Parity verification command: `./scripts/qa/verify-openedx-audit-tracker-sync.sh`

## Audit Closure Snapshot (2026-03-06)

- Parent tracker `#214` plus child issues `#215` through `#222` are implemented; child issues are closed.
- Verification governance stream is completed through `#337` with current catalog posture:
  - total `verify-*` scripts: `496`
  - `active`: `366`
  - `manual_only`: `127`
  - `deprecated_candidate`: `0`
  - `ci_static` bound scripts: `334`
- Where domain findings below conflict with the merged remediation trail, treat `### Post-Audit Implementation Status` as canonical.

## Executive Summary

1. **Git hygiene is partially healthy but inconsistent**: critical runtime artifact directories (`exports/`, `var/`, `tutor_env/`) are ignored, but production evidence artifacts are still committed under `docs/operations/evidence`, including live `Set-Cookie` headers.
2. **Brand asset duplication is real and mostly intentional** due to isolated build/runtime surfaces (Django comprehensive theming vs MFE brand package/runtime theme), but sync coverage is uneven across tenant brand packages.
3. **Theming stack is in a transitional hybrid** (design tokens + SCSS bridge + runtime minified CSS). This is currently functional but has multiple generated layers that can drift.
4. **Custom Django apps are structurally installable** (all app dirs include `setup.py`) and not tracking stateful files in git, but local cache noise is widespread.
5. **IaC control planes are fragmented** across Tutor generation, Kustomize overlays, and GitOps repo pinning; legacy Tutor-K8s scripts still exist and can conflict with current GitOps flow.
6. **Verification surface remains large but is now governed** (`496` `verify-*.sh` scripts) with catalog ownership metadata, CI/static contracts, status overrides, and `deprecated_candidate=0`.
7. **Tenant onboarding is still multi-system** (DB, DNS, Caddy, settings, MFE config, branding) with no single declarative source of truth.
8. **Purchase gateway durability and operator controls are implemented** with outbox + reconciliation, admin recovery APIs, and resilience gates promoted into static CI.

## Implementation Tracker (GitHub)

- Master tracker issue:
  - https://github.com/Biji-Biji-Initiative/mereka-lms/issues/214
- Child implementation issues:
  - https://github.com/Biji-Biji-Initiative/mereka-lms/issues/215 (evidence pipeline hardening)
  - https://github.com/Biji-Biji-Initiative/mereka-lms/issues/216 (IaC control-plane unification)
  - https://github.com/Biji-Biji-Initiative/mereka-lms/issues/217 (multi-brand asset SoT sync/drift)
  - https://github.com/Biji-Biji-Initiative/mereka-lms/issues/218 (theming generated artifact governance)
  - https://github.com/Biji-Biji-Initiative/mereka-lms/issues/219 (verify script consolidation)
  - https://github.com/Biji-Biji-Initiative/mereka-lms/issues/220 (multi-tenancy declarative SoT)
  - https://github.com/Biji-Biji-Initiative/mereka-lms/issues/221 (purchase-gateway outbox/saga)
  - https://github.com/Biji-Biji-Initiative/mereka-lms/issues/222 (frontend-app-authn submodule canonicalization)

### Live PR Board

- #215 → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/224
- #216 → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/225
- #217 → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/227
- #218 → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/228
- #219 → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/229
- #220 → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/230
- #221 → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/232
- #222 → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/226
- #180 → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/233
- ARC runner policy hardening → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/234
- Repo hygiene artifact guardrails → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/235
- Custom apps hygiene guardrails → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/236
- Evidence tracking forward policy → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/237
- Verification strict-mode contract gate → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/258
- Audit tracker synchronization gate → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/259
- Local config cloud-IP guardrail path fix → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/260
- Static-validation kubeconform portability fix → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/261
- Evidence redaction header/token hardening → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/262
- Repo hygiene static gate promotion + CI signal hardening bundle → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/263
- Branding upstream token sync determinism hardening → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/264
- Custom-app hygiene nested statefile hardening → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/266
- ARC runner policy fail-closed parser hardening → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/267
- New verify-script metadata contract gate → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/268
- Purchase-gateway LMS auth-expiry self-heal retry → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/269
- Purchase-gateway failed webhook status durability fix → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/270
- Repo-wide local statefile artifact guard → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/271
- New static-list entry contract gate → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/272
- Purchase-gateway admin fulfillment retry endpoint → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/273
- Purchase-gateway admin Stripe-event debug API → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/274
- Purchase-gateway admin order-detail API → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/275
- Purchase-gateway admin refund initiation API → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/276
- Purchase-gateway admin entitlements list API → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/282
- PR handoff discipline guardrails → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/312
- Verification catalog reference-scan performance optimization → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/314
- Purchase-gateway checkout durability + webhook recovery hardening → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/317
- Purchase-gateway resilience gate promotion into static CI → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/318
- Audit tracker PR status sync automation → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/319
- Purchase-gateway resilience assertions expansion → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/320
- Verification catalog baseline refresh → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/321
- Docs-only CI heavy-scan skip contract → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/322
- Archive unbound verify-bash-strict-mode check → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/323
- Promote Tutor config path contract static validation → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/324
- Archive stale verify-ux-audit-coverage check → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/325
- Archive stale verify-k8s-validation-job check → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/326
- Archive stale verify-lint-job check → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/327
- Remove stale paths from QA script catalog → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/328
- Archive stale GitHub Actions cost verifiers → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/329
- Archive stale CI/CD point-check verifiers → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/330
- Promote evidence sprawl budget gate → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/331
- Promote stable CI/CD contract verifiers → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/332
- Archive stale Tutor patch governance verifiers → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/333
- Archive stale email plugin code verifiers → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/334
- Promote high-signal governance and evidence verifiers → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/335
- Verification catalog runtime status overrides → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/336
- Final candidate classification + strictness fixes → https://github.com/Biji-Biji-Initiative/mereka-lms/pull/337

### Post-Audit Implementation Status (2026-03-06)

| Area | PR | Status | Key Outcome |
|------|----|--------|-------------|
| CSP reporting hardening | #233 | Merged | DSN-host-agnostic CSP report URI derivation + CI gate |
| ARC runner policy (Linux) | #234 | Merged | `codeql`/`scorecard`/`dependency-review` moved to ARC; `ubuntu-*` blocked |
| Repository artifact bloat guard | #235 | Merged | New CI verifier blocks tracked `var/`, `exports/`, cache/bytecode, non-placeholder brand `dist` outputs |
| Custom app packaging/state hygiene | #236 | Merged | New CI verifier enforces `setup.py|pyproject` + blocks tracked runtime files |
| Evidence locker growth control | #237 | Merged | New CI verifier blocks newly added non-markdown evidence payloads in docs evidence paths |
| Purchase-gateway durability guard | #246 | Merged | Static CI gate validates webhook→outbox→worker/reconciliation contract anchors |
| Purchase-gateway runtime telemetry | #247 | Merged | Adds checkout/webhook/fulfillment/reconciliation Prometheus metrics + tests |
| Repo cache artifact guardrails (v2) | #248 | Merged | Blocks tracked `.ruff_cache`, `.pytest_cache`, and `.mypy_cache` via ignore + static verifier |
| Python cache cleanup ergonomics | #249 | Merged | Adds `clean-python-caches.sh` and integrates it with `make clean` |
| Verification governance entrypoint | #250 | Merged | Adds canonical `verify-manifest-integrity.sh` and wires it into static CI |
| Tutor custom-app install parity | #251 | Merged | Enforces `_CUSTOM_APPS` ↔ custom-app dir/package metadata install-map integrity |
| Custom-app state file pattern hardening | #252 | Merged | Expands custom-app hygiene detector for nested SQLite/log/cache/bytecode artifacts |
| Verification script growth budget gate | #253 | Merged | Adds static CI budget gate for verify-script count/status growth control |
| IaC control-plane boundary guard | #254 | Merged | Enforces `deploy/k8s` primacy and prevents `infrastructure/k8s` shadow-runtime drift |
| CI verifier signal hardening | #255 | Merged | Makes `verify-ci-script-list.sh` release-blocking aware and removes lingering executable-bit warning (`check-cluster-status.sh`) |
| Tenant DNS inventory drift guard | #256 | Merged | Verifies active tenant LMS domains against Cloudflare inventory files and surfaces onboarding DNS drift |
| Evidence footprint budget guard | #257 | Merged | Enforces tracked evidence file/size budget to slow git-based evidence locker growth |
| Verification strict-mode contract gate | #258 | Merged | Enforces `set -euo pipefail` across verification scripts with explicit waiver handling for legacy exceptions |
| Audit tracker synchronization guard | #259 | Merged | Enforces tracker ↔ execution-board issue/PR parity so the consolidated audit board stays actionable |
| Tutor config path contract hardening | #260 | Merged | Fixes stale cloud-IP guard path and adds CI verifier preventing stale `config.example` docs/spec references |
| Static-validation kubeconform portability fix | #261 | Merged | Removes `wget` dependency in CI kubeconform install step to prevent ARC runner static-validation hard-fail (`exit 127`) |
| Evidence redaction header/token hardening | #262 | Merged | Expands evidence leak detection for raw `cookie:` headers, basic auth credentials, and `x-auth-token` values |
| Repo hygiene gate promotion + CI signal bundle | #263 | Merged | Promotes `verify-repo-hygiene-artifacts.sh`, `verify-evidence-redaction.sh`, and `verify-evidence-tracking-policy.sh` into static CI; hardens `.ruff_cache`/`.pytest_cache`/`.mypy_cache` hygiene contracts; refreshes verification catalog; and bundles ci-script-list signal fixes from #255 |
| Branding sync determinism hardening | #264 | Merged | Makes upstream token refresh explicit in `sync-brand-assets.sh` and `update-token-provenance.sh` (opt-in env paths), removes implicit machine-dependent sibling-repo behavior, adds static CI portability guard (`verify-branding-script-portability.sh`), and updates branding runbook contract |
| Custom-app statefile pattern hardening | #266 | Merged | Expands custom-app hygiene detector coverage for nested `.sqlite3`/`.sqlite`/`.log`/`.pid`/`.sock` and compiled bytecode artifacts under `infrastructure/tutor/custom-apps/**` |
| ARC runner policy parser hardening | #267 | Merged | Rewrites `verify-ci-runner-policy.sh` to parse workflow jobs structurally (`yq` + `jq`) and fail closed on expression-based/missing/unknown runner labels while preserving explicit heavy-builder and macOS exception allowlists |
| New verify-script metadata contract gate | #268 | Closed | Adds `verify-new-verify-script-contract.sh` to enforce metadata/strict-mode/executable requirements for newly added `verify-*.sh` scripts and wires it into static CI to cap verification sprawl debt growth |
| Purchase-gateway auth-expiry retry hardening | #269 | Merged | Adds one-shot `401` token-refresh retry behavior in `LMSClient` (`get_user_by_email`, `enroll_user`, `deactivate_enrollment`) to reduce avoidable outbox retries and split-brain enrollment delays caused by transient OAuth token expiry |
| Purchase-gateway failed webhook status durability | #270 | Merged | Persists `StripeEvent.processing_status=failed` via explicit DB update after rollback on webhook handler exceptions, preventing detached-ORM-state drops and improving deterministic Stripe retry semantics |
| Repo-wide local statefile artifact guard | #271 | Closed | Extends repo hygiene verifier + `.gitignore` to block tracked local state artifacts (`*.sqlite*`, `*.db`, `.pid`, `.sock`) so database/runtime process files cannot silently enter git history |
| Static-list entry contract gate | #272 | Merged | Adds `verify-new-ci-static-entries.sh` to enforce integrity/metadata contracts for newly added `.github/ci-scripts-static.txt` entries (existence, executable + syntax for shell scripts, and `verify-*.sh` traceability hardening) |
| Purchase-gateway admin fulfillment retry API | #273 | Merged | Adds `POST /api/v1/admin/orders/{order_id}/retry-fulfillment/` with retryable-state guards + tenant scoping, force-requeues outbox jobs (`force=True`) for dead-letter recovery, and aligns service README/runbook recovery instructions with the new API contract |
| Purchase-gateway admin Stripe-event list API | #274 | Merged | Adds `GET /api/v1/admin/stripe-events/` with event/status/id filters, pagination, and opt-in payload exposure (`include_payload=true`) so operators can debug webhook/idempotency flows without exposing raw payloads by default |
| Purchase-gateway admin order-detail API | #275 | Merged | Adds `GET /api/v1/admin/orders/{order_id}/` returning line items + order audit timeline + fulfillment job state so operators can inspect end-to-end fulfillment state transitions from a single endpoint |
| Purchase-gateway admin refund initiation API | #276 | Merged | Adds `POST /api/v1/admin/orders/{order_id}/refund/` to trigger Stripe refunds (full by default, optional partial amount/reason) with explicit safety guards, while preserving webhook-driven local order-state transitions for idempotency |
| Purchase-gateway admin entitlements list API | #282 | Merged | Adds `GET /api/v1/admin/entitlements/` with tenant/status/recipient filters and pagination, providing direct operational visibility into pending/claimed/revoked entitlement state |
| PR handoff discipline guardrails | #312 | Merged | Adds required PR-template handoff checklist plus executable local (`check-pr-handoff-discipline.sh`) and CI (`verify-pr-handoff-guardrails.sh`) enforcement to prevent local-only implementation drift |
| Verification catalog performance hardening | #314 | Merged | Refactors verification-catalog reference counting to single-pass regex extraction with cache-dir exclusion, reducing generation runtime and keeping governance gates responsive as script inventory grows |
| Purchase-gateway checkout durability + webhook recovery hardening | #317 | Merged | Persists checkout order+line-item before Stripe call, marks failed checkout attempts as canceled, and recovers `checkout.session.completed` by `metadata.order_uuid` when session-id lookup misses so fulfillment can proceed without lost paid orders |
| Purchase-gateway resilience gate promotion into static CI | #318 | Merged | Promotes `verify-purchase-gateway-resilience.sh` into release-blocking static validation so outbox/webhook/worker durability contracts are continuously enforced in CI rather than manually |
| Audit tracker PR status sync automation | #319 | Merged | Adds `sync-openedx-audit-pr-status.sh` and CI wiring so tracker/board status cells stay aligned with live GitHub PR state |
| Purchase-gateway resilience assertion expansion | #320 | Merged | Deepens `verify-purchase-gateway-resilience.sh` checks for outbox retries, dead-letter semantics, and reconciliation anchors |
| Verification catalog/sprawl baseline refresh | #321 | Merged | Regenerates catalog artifacts and updates sprawl-budget baselines after governance and deprecation work |
| Docs-only CI heavy-scan skip contract | #322 | Merged | Skips expensive static scans for docs-only pull requests while preserving required release-blocking checks |
| Archive unbound verify-bash-strict-mode check | #323 | Merged | Moves stale unbound verifier into deprecated namespace and removes dead references from active CI paths |
| Tutor config path contract static validation | #324 | Merged | Promotes stale Tutor config path detector into static CI to prevent drift in docs/spec/runtime path contracts |
| Archive stale verify-ux-audit-coverage check | #325 | Merged | Archives unused UX audit verifier and removes it from active governance surfaces |
| Archive stale verify-k8s-validation-job check | #326 | Merged | Archives stale K8s validation-job verifier to reduce false signal and maintenance load |
| Archive stale verify-lint-job check | #327 | Merged | Archives stale lint-job verifier and keeps active lint contract checks consolidated |
| QA script catalog stale-path cleanup | #328 | Merged | Removes stale script paths from verification catalog docs and manifests |
| Archive stale GitHub Actions cost verifiers | #329 | Merged | Retires dead cost-check scripts and keeps cost governance under current canonical gates |
| Archive stale CI/CD point-check verifiers | #330 | Merged | Retires obsolete CI/CD point checks to reduce duplicate verification paths |
| Evidence sprawl budget gate promotion | #331 | Merged | Promotes evidence footprint budget verifier into static CI for continuous anti-locker enforcement |
| Stable CI/CD contract verifier promotion | #332 | Merged | Promotes durable CI/CD contract verifiers and de-emphasizes brittle legacy checks |
| Archive stale Tutor patch governance verifiers | #333 | Merged | Archives obsolete Tutor patch governance scripts replaced by current patch contract gates |
| Archive stale email plugin code verifiers | #334 | Merged | Archives unused email plugin implementation verifiers and trims inactive QA surface |
| High-signal governance/evidence verifier promotion | #335 | Merged | Promotes high-signal governance/evidence checks into static CI and standard entrypoints |
| Verification catalog runtime status overrides | #336 | Merged | Adds runtime/manual override mechanism for catalog status resolution without breaking CI ownership contracts |
| Final verification candidate classification + strictness fixes | #337 | Merged | Closes long-tail verification classification by fixing strict-mode script behavior and duplicate-AC detection, reducing deprecated-candidate scripts to zero |

---

## Domain 1: Repository Hygiene and Artifact Bloat

### Current State

- Tracked files in risky dirs:
  - `exports/**`: `0`
  - `var/**`: `0`
  - `tutor_env/dev/**`: `0`
  - `tmp/**`: `1` (`tmp/frontend-app-authn`, a git submodule pointer)
- Tracked Python bytecode/cache:
  - `__pycache__` / `.pyc`: `0`
- Tracked `dist/` content:
  - only `.gitkeep` placeholders in brand package `dist/` dirs.
- Tracked MFE compiled CSS:
  - `infrastructure/tutor/themes/mereka/mfe/theme/core.min.css`
  - `infrastructure/tutor/themes/mereka/mfe/theme/light.min.css`
  - `infrastructure/tutor/themes/mereka/mfe/theme/mereka-brand.min.css`
  - `infrastructure/tutor/themes/mereka/mfe/theme/mereka-brand-light.min.css`
- `.gitignore` already ignores `exports/`, `var/`, `tutor_env/`, `__pycache__/`, `*.py[cod]`.

### Architectural Smells

- **Committed operational evidence with sensitive headers**:
  - `docs/operations/evidence/router-smoke/prod-route-health-20260219-1214.md` contains live `set-cookie` values (`sessionid`, `csrftoken`).
- **Submodule path hygiene drift**:
  - authn MFE submodule is under `tmp/frontend-app-authn` while repository guide/specs reference `apps/frontend-app-authn`.
- **Local cache sprawl risk**:
  - large local `__pycache__` footprint exists in `infrastructure/tutor/custom-apps/` and `services/purchase-gateway/` (not tracked, but noisy).

### Recommended Refactor

1. **PII/security gate**:
   - Add a CI check to fail on committed cookie/session/bearer patterns under `docs/**/evidence/**`.
   - Enforce redaction before evidence commit.
2. **Evidence policy split**:
   - Keep only curated summaries in git.
   - Move raw logs/screenshots/HTML dumps to artifact storage (GitHub Actions artifacts + object storage).
3. **Submodule placement normalization**:
   - Decide and standardize `apps/frontend-app-authn` vs `tmp/frontend-app-authn` (single canonical location).
4. **.gitignore hardening**:
   - Add `.ruff_cache/` and explicit `**/__pycache__/` safeguards if desired for clarity.

### Immediate Action Candidates (Non-destructive)

- Add hygiene issue for evidence redaction and directory contract.
- Add pre-commit/CI detector for `set-cookie:` and session token signatures in docs evidence.

---

## Domain 2: Asset Duplication and Single Source of Truth

### Current State

- Fonts/logos are duplicated across:
  - `assets/branding/`
  - `infrastructure/tutor/themes/mereka/{common,lms,cms,mfe}/...`
  - `infrastructure/tutor/brand-mereka/...`
  - plus tenant brand packages (`brand-biji-biji`, `brand-skillourfuture`).
- Existing sync mechanisms:
  - `scripts/branding/sync-brand-assets.sh` (assets -> theme dirs; also runs brand package sync for `brand-mereka`)
  - `scripts/branding/sync-brand-package.sh` (`assets/branding` -> `brand-mereka`)
  - token provenance + drift scripts exist.

### Architectural Smells

- **Duplication is structurally required in current stack**, but sync coverage is not symmetric:
  - robust for `brand-mereka`,
  - less explicit for `brand-biji-biji` / `brand-skillourfuture` (no equivalent font sync contract).
- **Local absolute dependency** in sync path:
  - optional refresh from `/home/gurpreet/projects/bbbi-mereka-brand-assets/...` can fail portability expectations.

### Recommended Refactor

1. **Formalize canonical source**:
   - `assets/branding/` remains single source of truth in-repo.
2. **Create one multi-brand sync contract**:
   - unify `brand-mereka`, `brand-biji-biji`, `brand-skillourfuture` sync behavior and verification.
3. **Make provenance portable**:
   - avoid hard dependency on workstation-specific absolute path.
4. **Add drift gate**:
   - check hashes of copied assets across all consumers.

### Justification (Open edX/Tutor)

- Comprehensive theming and MFE branding operate in different build/runtime contexts, so duplicated copies are expected in practice:
  - Tutor theming docs: https://docs.tutor.edly.io/tutorials/theming.html
  - OEP-48 brand package model for MFEs: https://docs.openedx.org/projects/openedx-proposals/en/latest/architectural-decisions/oep-0048-brand-customization.html

---

## Domain 3: Theming Architecture (Tokens + SCSS + Minified Runtime CSS)

### Current State

- Active layers:
  - canonical token CSS: `assets/branding/tokens.css`
  - generated SCSS bridge: `infrastructure/tutor/themes/mereka/scss/_tokens.scss`
  - brand package token JSON/SCSS scaffolding in `infrastructure/tutor/brand-mereka/`
  - prebuilt runtime theme CSS in `infrastructure/tutor/themes/mereka/mfe/theme/*.min.css`
- Build/generation tooling exists:
  - `scripts/branding/generate-tokens-from-canonical.sh`
  - `scripts/branding/build-tokens.sh`
  - several `verify-token-*` checks.

### Architectural Smells

- **Multi-layer generated artifacts** increase drift surface.
- **Tracked minified CSS artifacts** are build outputs; they may be intentional for deterministic runtime, but they increase maintenance overhead.
- **Legacy + modern token mechanisms coexist**, which is common in transition but requires strict generation discipline.

### Recommended Refactor

1. **Declare explicit layer contract**:
   - Canonical: `assets/branding/tokens.css`
   - Generated: `_tokens.scss`, `mereka-overrides.css`, `mereka-design-tokens.css`, `mfe/theme/*.min.css`
2. **Choose build strategy and enforce**:
   - either keep `*.min.css` in git with strict regen checks,
   - or generate in CI/build pipeline from pinned inputs and stop tracking outputs.
3. **Back-compat stance**:
   - keep SCSS bridge while Django comprehensive theming and older consumers need SCSS variable surfaces.

### Justification (Open edX Transition)

- OEP-48 and newer tokenized theming direction support runtime/themed MFEs, while legacy server-rendered surfaces still rely on comprehensive theming conventions:
  - OEP-48: https://docs.openedx.org/projects/openedx-proposals/en/latest/architectural-decisions/oep-0048-brand-customization.html
  - Tutor theming flow: https://docs.tutor.edly.io/tutorials/theming.html
  - Design tokens release note context: https://docs.openedx.org/en/latest/community/release_notes/teak/design_tokens.html

---

## Domain 4: Custom Django Apps (`infrastructure/tutor/custom-apps/`)

### Current State

- App count: `21` directories.
- Packaging:
  - all include `setup.py`.
  - all include root `__init__.py`.
  - Dockerfile hook installs each via `pip install -e /openedx/<app>` in `openedx_dockerfile.py`.
- Tracked rogue stateful files in git:
  - none found (`db.sqlite3`, `.log`, `.pyc`, `__pycache__` not tracked).

### Architectural Smells

- **Local cache noise is heavy** in working directory (`__pycache__` trees), though gitignored.
- **Operational complexity**: large custom app surface injected by Docker patching implies higher upgrade friction.

### Recommended Refactor

1. **Keep package health gate**:
   - extend existing drift checks to validate each app’s install metadata and importability in CI.
2. **Cache cleanup ergonomics**:
   - add optional `make clean-pyc`/`scripts/qa/clean-python-caches.sh` for local hygiene.
3. **Modular ownership map**:
   - document app ownership, lifecycle, and deprecation candidates.

---

## Domain 5: IaC Fragmentation (`deploy/k8s`, `infrastructure/k8s`, `infrastructure/terraform`, Tutor)

### Current State

- Active runtime manifests are clearly centered in `deploy/k8s` (base + overlays + GitOps release scripts).
- Repository split snapshot:
  - `deploy/k8s`: `246` files (active manifest tree)
  - `infrastructure/k8s`: `5` files (cronjob templates + deprecated mongodb reference + helper script)
  - `infrastructure/terraform`: `35` files (cloud infra modules: GKE/CloudSQL/Redis/storage/secrets)
- `infrastructure/k8s` currently contains sidecar resources (cronjobs, velero helper, legacy mongodb manifest).
- Tutor generation path still exists (`scripts/export-k8s-manifests.sh` copies from `tutor_env/env/k8s` into `deploy/k8s/base`).
- Legacy Tutor-K8s operation scripts still exist (`setup-k8s-overrides.sh`, `verify-k8s-overrides.sh`, `deploy-aspects-k8s.sh`).

### Architectural Smells

- **Multiple control planes**:
  - Tutor-generated manifests,
  - hand-maintained Kustomize manifests,
  - external GitOps repo pinning (`BBI-K8`).
- **Legacy runtime path risk**:
  - old `tutor k8s` scripts can conflict with GitOps/Kustomize-first operations.
- **Config hardcoding spread**:
  - production defaults in base config files + env overlays patching dev values.
- **Infra boundary gap for tenant DNS**:
  - Terraform modules cover GCP infra but not Cloudflare tenant DNS records; DNS intent also exists in `infrastructure/cloudflare/tenant-dns-records.yaml`.

### Recommended Refactor

1. **Single declared flow**:
   - `Tutor build/config -> deploy/k8s source -> BBI-K8 pin/tag -> Argo apply`.
2. **Quarantine/deprecate legacy scripts**:
   - mark `tutor k8s` override scripts deprecated unless explicitly needed.
3. **Boundary doc refresh**:
   - reconcile outdated references (e.g., missing `infrastructure/k8s/README.md`, stale path guidance).

---

## Domain 6: Git as Evidence Locker Anti-pattern

### Current State

- Tracked evidence footprint:
  - `docs/operations/evidence` + `docs/evidence/observability`: `133` tracked files total
  - extension mix: `91 .md`, `17 .txt`, `9 .html`, `6 .png`, `5 .json`, `4 .log`, `1 .timestamp`
  - largest tracked evidence file currently: `docs/operations/evidence/ui_finality/20260219-2032/dom-academy.html` (~204 KB)
  - `var/velero-evidence`: not tracked (good)
- CI runtime artifacts already exist in gitignored `var/` (e.g., `var/ci`, `var/screenshots`).

### Architectural Smells

- Evidence files in git contain raw operational payloads and logs, including sensitive headers.
- Git history is being used for mutable operational evidence instead of artifact systems.

### Recommended Refactor

1. **Evidence tiering model**:
   - Git: human summary + links + immutable IDs/hashes.
   - Artifact store: raw logs/screenshots/HTML.
2. **Use workflow artifacts + retention policy**:
   - GitHub artifact docs:
     - https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts
     - https://docs.github.com/actions/automating-your-workflow-with-github-actions/persisting-workflow-data-using-artifacts
     - https://docs.github.com/organizations/managing-organization-settings/configuring-the-retention-period-for-github-actions-artifacts-and-logs-in-your-organization
3. **Redaction contract**:
   - scrub cookies, bearer tokens, raw auth headers before any committed summary.

---

## Domain 7: Verification Script Sprawl

### Current State

- `verify-*.sh` count: `490`
  - `scripts/qa`: `479`
  - `scripts/infra`: `6`
  - `scripts/branding`: `4`
  - `scripts/analytics`: `1`
- Syntax quality:
  - `bash -n` failures: `0`
  - missing strict mode: `2` scripts
- Workflow binding:
  - directly referenced in `.github/workflows`: `49`
  - candidate unreferenced scripts by basename scan against `scripts/` + `.github/workflows/`: `76`

### Architectural Smells

- Large script surface with uneven CI enforcement.
- Mixed invocation paths (direct workflow calls vs wrappers) make coverage and reliability hard to reason about.

### Recommended Refactor

1. **Test taxonomy**:
   - classify scripts: blocking CI / nightly / manual / deprecated.
2. **Consolidate by domain**:
   - replace many micro-check scripts with declarative suites where feasible (pytest + structured fixtures, or policy engines for K8s/IaC checks).
3. **Enforcement manifest**:
   - maintain one machine-readable map of required gates per pipeline.

---

## Domain 8: Multi-Tenancy and Edge Routing Complexity

### Current State

- Tenant truth is split across:
  - Django DB (`Site`, `SiteConfiguration`, `EnterpriseCustomer`, `TenantConfig`)
  - Caddy routing (`deploy/k8s/base/apps/caddy/Caddyfile`)
  - static tenant registry ConfigMap (`deploy/k8s/base/apps/multi-tenancy/configmap-tenants.yaml`)
  - per-tenant MFE env files and provisioning scripts.
- Provisioning scripts explicitly require manual post-steps (DNS, CSRF/hosts, SSO, branding, catalog/subscriptions).
- Practical onboarding currently spans at least these system boundaries:
  - Django tenant provisioning command (`provision_tenant`)
  - Caddy host/routing updates for new tenant domains
  - DNS updates (Cloudflare records / external infra flow)
  - MFE config API provisioning (`provision-mfe-config.sh`)
  - LMS host/security settings (`ALLOWED_HOSTS`, `CSRF_TRUSTED_ORIGINS`)
  - tenant branding asset deployment under theme directories
  - enterprise catalog/subscription setup

### Architectural Smells

- **Onboarding blast radius is high** across DNS, ingress/reverse proxy, DB records, and MFE runtime settings.
- **ConfigMap tenant registry is declared as non-canonical**, while still used operationally as bootstrap/reference.

### Recommended Refactor

1. **Single declarative tenant spec**:
   - generate DB provisioning, routing, and MFE config from one source.
2. **Runtime config API-first for MFEs**:
   - reduce static env file divergence across overlays.
3. **Tenant onboarding automation pipeline**:
   - one command producing deterministic infra + app state changes.

---

## Domain 9: Distributed Transactions in Purchase Gateway

### Current State

- Webhook flow:
  - Stripe event dedupe table (`stripe_events`) with explicit processing-status transitions.
  - `checkout.session.completed` resolves order (including metadata fallback), marks paid, and enqueues fulfillment via durable outbox.
  - failures persist failed status and remain retryable through Stripe redelivery plus internal reconciliation.
- Fulfillment:
  - async outbox worker claims jobs with retry/backoff and dead-letter handling.
  - reconciliation loop requeues recoverable paid orders lacking successful fulfillment.
  - operator APIs support manual retry and inspection for event/order state.
- Config includes fulfillment retry/backoff/reconciliation controls and worker polling cadence.

### Architectural Smells

- **Cross-system split-brain risk is reduced but not eliminated** (Stripe/LMS remain separate systems with eventual consistency).
- **Recovery correctness now depends on operational SLOs** for worker liveness, retry budget, and dead-letter triage.
- **Telemetry and gate drift can silently erode resilience** if resilience contracts are not continuously enforced.

### Recommended Refactor

1. **Keep outbox contract release-blocking**:
   - preserve static CI resilience gates and update them with any schema/flow changes.
2. **Harden runtime operations loop**:
   - keep reconciliation enabled with monitored cadence and explicit dead-letter runbooks.
3. **Expand failure-mode tests**:
   - continue adding integration tests for partial failure paths (`paid` + deferred LMS availability, idempotent replay, admin retry race cases).

### Stripe Guidance Reference

- Webhook duplicate handling and retries:
  - https://docs.stripe.com/webhooks
  - https://docs.stripe.com/workbench/webhooks

---

## Initial Backlog (Now Completed)

### P0 (Security / Correctness)

- [x] Redact/remove committed cookie-bearing evidence files and add CI guard against raw session/token artifacts (`#215`, follow-up hardening PRs through `#337`).
- [x] Decide and enforce canonical location for `frontend-app-authn` submodule path (`#222`).
- [x] Add explicit fulfillment durability plan (outbox + retry worker) for purchase gateway (`#221` + follow-up resilience hardening).

### P1 (Architecture Stabilization)

- [x] Publish single authoritative IaC flow and deprecate legacy Tutor-K8s runtime scripts (`#216`).
- [x] Standardize multi-brand asset sync coverage and drift checks across all brand packages (`#217`/`#218`).
- [x] Classify/curate verify script inventory into enforceable suites (`#219`, completed through `#337`).

### P2 (Debt Reduction)

- [x] Normalize docs/spec path references where current repository reality differs (completed in post-audit follow-ups).
- [x] Improve local cache cleanup ergonomics for large Python cache footprints (`#249` + repo hygiene follow-ups).

## Recommended Execution Sequencing (Historical)

This historical sequencing was executed. Keep for audit provenance only; use `### Post-Audit Implementation Status` for active state.

---

## Evidence Index (Representative)

- `.gitignore`
- `.gitmodules`
- `README.md`
- `docs/onboarding/REPOSITORY_GUIDE.md`
- `specs/repository-structure_spec.md`
- `docs/operations/evidence/router-smoke/prod-route-health-20260219-1214.md`
- `scripts/branding/sync-brand-assets.sh`
- `scripts/branding/sync-brand-package.sh`
- `scripts/branding/build-tokens.sh`
- `scripts/branding/generate-tokens-from-canonical.sh`
- `infrastructure/tutor/patches/brand-package.sh`
- `infrastructure/tutor/plugins/_mereka_lms/openedx_dockerfile.py`
- `infrastructure/tutor/plugins/_mereka_lms/mfe_dockerfile.py`
- `infrastructure/tutor/custom-apps/*/setup.py`
- `deploy/k8s/base/kustomization.yaml`
- `deploy/k8s/overlays/local/kustomization.yaml`
- `deploy/k8s/overlays/production/kustomization.yaml`
- `scripts/export-k8s-manifests.sh`
- `scripts/infra/apply-kind-overlay.sh`
- `scripts/infra/release-openedx-gitops.sh`
- `deploy/k8s/base/apps/caddy/Caddyfile`
- `deploy/k8s/base/apps/multi-tenancy/configmap-tenants.yaml`
- `scripts/tenants/provision-tenant.sh`
- `scripts/tenants/provision-mfe-config.sh`
- `infrastructure/tutor/plugins/multi-tenancy/middleware.py`
- `infrastructure/tutor/plugins/multi-tenancy/management/commands/provision_tenant.py`
- `services/purchase-gateway/app/routers/webhooks.py`
- `services/purchase-gateway/app/services/fulfillment.py`
- `services/purchase-gateway/app/services/lms_client.py`
- `services/purchase-gateway/app/config.py`
- `services/purchase-gateway/README.md`
