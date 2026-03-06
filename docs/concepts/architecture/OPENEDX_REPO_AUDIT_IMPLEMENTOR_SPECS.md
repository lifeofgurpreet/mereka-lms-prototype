# Open edX Repo Audit - Implementor Specs

Last updated: 2026-03-05  
Source tracker: `docs/concepts/architecture/OPENEDX_REPO_ARCH_HYGIENE_AUDIT_TRACKER.md`  
Parent issue: https://github.com/Biji-Biji-Initiative/mereka-lms/issues/214

## Purpose

This document converts audit findings into implementor-ready specs for child issues `#215` to `#222`, with:
- explicit acceptance criteria
- phased migration steps
- rollback plans
- verification gates

It is intentionally execution-focused and designed for handoff.

Execution board:
- `docs/concepts/architecture/OPENEDX_REPO_AUDIT_EXECUTION_BOARD.md`

## Detailed Packets

- `#215`: `docs/concepts/architecture/OPENEDX_REPO_AUDIT_ISSUE_215_PACKET.md`
- `#216`: `docs/concepts/architecture/OPENEDX_REPO_AUDIT_ISSUE_216_PACKET.md`
- `#217`: `docs/concepts/architecture/OPENEDX_REPO_AUDIT_ISSUE_217_PACKET.md`
- `#218`: `docs/concepts/architecture/OPENEDX_REPO_AUDIT_ISSUE_218_PACKET.md`
- `#219`: `docs/concepts/architecture/OPENEDX_REPO_AUDIT_ISSUE_219_PACKET.md`
- `#220`: `docs/concepts/architecture/OPENEDX_REPO_AUDIT_ISSUE_220_PACKET.md`
- `#221`: `docs/concepts/architecture/OPENEDX_REPO_AUDIT_ISSUE_221_PACKET.md`
- `#222`: `docs/concepts/architecture/OPENEDX_REPO_AUDIT_ISSUE_222_PACKET.md`

---

## Execution Order

1. `#215` Evidence pipeline hardening (security)
2. `#216` IaC control-plane unification (release safety)
3. `#222` Authn submodule canonicalization (repo contract)
4. `#217` Multi-brand asset SoT sync/drift (branding consistency)
5. `#218` Theming generated artifact governance (transition debt)
6. `#219` Verify-suite consolidation (operability)
7. `#220` Multi-tenancy declarative SoT (tenant onboarding)
8. `#221` Purchase gateway outbox/saga (payment resilience)

---

## Issue #215 - Evidence Pipeline Hardening

Issue: https://github.com/Biji-Biji-Initiative/mereka-lms/issues/215

### Current State (evidence)

- `docs/archive/evidence/operations/router-smoke/prod-route-health-20260219-1214.md` contains raw `set-cookie` with `sessionid` and `csrftoken`.
- Raw evidence is committed under `docs/archive/evidence/operations/**` and `docs/archive/evidence/observability/**`.
- `.gitignore` correctly ignores `var/`, but evidence discipline in `docs/` is policy-only today.
- Existing secret scanning does not reliably block this class before commit in docs evidence paths.

### Scope

- Redaction and storage policy for operational evidence in git.
- CI/pre-commit enforcement for cookie/session/token patterns.
- Evidence summaries in git, raw artifacts out of git.

### Non-goals

- Rewriting all historic evidence immediately in one PR.
- Replacing all existing workflow evidence behavior at once.

### Acceptance Criteria

- `AC-215-001`: Any new evidence committed under `docs/**/evidence/**` MUST be redacted for cookies, auth headers, and bearer/session artifacts.
- `AC-215-002`: CI MUST fail on unsafe patterns in tracked evidence files (`set-cookie`, `sessionid=`, `csrftoken=`, `authorization: bearer`, JWT-like blobs).
- `AC-215-003`: Raw operational payloads (HTML dumps, full headers, screenshots, logs) MUST be uploaded as artifacts/object storage and referenced by immutable IDs/links from markdown summaries.
- `AC-215-004`: Repo docs MUST define a clear evidence contract: what is allowed in git vs external artifact storage.

### Migration Steps

1. Add `scripts/qa/verify-evidence-redaction.sh` and wire it into `.github/workflows/ci.yml`.
2. Add pre-commit check for staged evidence files with same signature set.
3. Add `docs/operations/EVIDENCE_STORAGE_POLICY.md` with redaction examples.
4. Refactor evidence-producing workflows to:
   - write raw files into `var/ci/**`
   - upload with `actions/upload-artifact`
   - commit only summary markdown.
5. Redact the currently known unsafe committed evidence file(s) in a dedicated scrub PR.

### Rollback Plan

- If CI becomes too noisy, switch rule set to `warn` mode for one release while preserving logs.
- Keep redaction checker behind env flag `STRICT_EVIDENCE_REDACTION=1` for controlled rollout.
- Revert workflow-only changes first; keep policy doc and checker script.

### Verification

- `rg -n "set-cookie|sessionid=|csrftoken=|authorization:\\s*bearer" docs/archive/evidence/operations docs/archive/evidence/observability`
- `./scripts/qa/verify-evidence-redaction.sh`
- Trigger CI on a synthetic unsafe evidence file and confirm failure.

---

## Issue #216 - IaC Control-Plane Unification

Issue: https://github.com/Biji-Biji-Initiative/mereka-lms/issues/216

### Current State (evidence)

- Active deploy surface is `deploy/k8s/` with GitOps pinning in external infra repo.
- Legacy generation script still exists: `scripts/export-k8s-manifests.sh` (Tutor export rewriting `deploy/k8s/base`).
- Legacy runtime scripts still exist: `scripts/infra/deploy-aspects-k8s.sh`, `scripts/infra/setup-k8s-overrides.sh`, `scripts/infra/verify-k8s-overrides.sh`.
- Canonical release flow exists in docs and script (`docs/operations/CANONICAL_DEPLOY_CONTRACT.md`, `scripts/infra/release-openedx-gitops.sh`) but older paths remain available.

### Scope

- One authoritative control-plane flow for k8s changes and releases.
- Deprecation fence for legacy Tutor K8s paths.
- Clear repository boundary contracts.

### Non-goals

- Deleting all legacy scripts immediately.
- Re-architecting Terraform modules in this phase.

### Acceptance Criteria

- `AC-216-001`: Repo MUST declare one canonical flow: `Tutor config/build -> deploy/k8s -> GitOps repo pin/update -> ArgoCD`.
- `AC-216-002`: Legacy scripts that mutate `deploy/k8s/base` from `tutor_env` MUST be marked deprecated and blocked by default.
- `AC-216-003`: Release docs and runbooks MUST point only to canonical scripts.
- `AC-216-004`: CI MUST fail if deprecated script paths are invoked by workflow jobs.

### Migration Steps

1. Add deprecation header + non-zero exit (unless `ALLOW_LEGACY_TUTOR_K8S=1`) to:
   - `scripts/export-k8s-manifests.sh`
   - `scripts/infra/deploy-aspects-k8s.sh`
   - `scripts/infra/setup-k8s-overrides.sh`
   - `scripts/infra/verify-k8s-overrides.sh`
2. Update docs to canonical commands only:
   - `scripts/infra/release-openedx-gitops.sh`
   - `scripts/infra/canonical-release.sh` (where used)
3. Add CI grep gate preventing `tutor k8s init|apply` usage in release workflows.
4. Add `docs/operations/IAC_BOUNDARY_CONTRACT.md` mapping:
   - `infrastructure/terraform` = cloud infra
   - `deploy/k8s` = app manifests
   - GitOps repo = live release pinning/overrides.

### Rollback Plan

- Keep deprecation guard bypass variable available for one release cycle.
- If release blocked unexpectedly, temporarily permit legacy path for emergency, then capture postmortem and remove bypass use.

### Verification

- `rg -n "tutor k8s|export-k8s-manifests|setup-k8s-overrides|deploy-aspects-k8s" .github/workflows docs scripts`
- `./scripts/infra/release-openedx-gitops.sh --help`
- CI dry run confirming deprecated invocations fail.

---

## Issue #217 - Multi-Brand Asset SoT Sync and Drift

Issue: https://github.com/Biji-Biji-Initiative/mereka-lms/issues/217

### Current State (evidence)

- `scripts/branding/sync-brand-assets.sh` and `sync-brand-package.sh` currently sync only `brand-mereka`.
- `brand-biji-biji` and `brand-skillourfuture` exist but are not covered by equivalent canonical sync flow.
- `sync-brand-assets.sh` has optional absolute path dependency:
  - `/home/gurpreet/projects/bbbi-mereka-brand-assets/.../tokens.css`

### Scope

- Single source of truth for branding assets across all brand packages.
- Multi-brand deterministic sync and drift detection.
- Portable sync behavior (no workstation-only assumptions).

### Non-goals

- Rebranding visual language.
- Removing required duplication between Django theme and MFE brand package.

### Acceptance Criteria

- `AC-217-001`: `assets/branding/` MUST remain the in-repo canonical source for shared logos/fonts/tokens.
- `AC-217-002`: Sync pipeline MUST explicitly support `brand-mereka`, `brand-biji-biji`, and `brand-skillourfuture`.
- `AC-217-003`: CI MUST detect drift between source assets and each brand package/theme consumer.
- `AC-217-004`: Sync scripts MUST not require user-specific absolute source paths.

### Migration Steps

1. Generalize `sync-brand-package.sh` to `sync-brand-packages.sh`:
   - iterate configured brand package directories
   - validate expected assets per brand.
2. Update `sync-brand-assets.sh` to call multi-brand sync and remove absolute-path hard requirement (retain optional override env var only).
3. Add `scripts/qa/verify-brand-packages-drift.sh`:
   - hash compare assets from canonical source to each target consumer.
4. Add brand manifest file (e.g., `assets/branding/brand-packages.manifest.yml`) for declarative mapping.

### Rollback Plan

- Keep old `sync-brand-package.sh` as compatibility wrapper for one cycle.
- If a brand fails strict validation, allow scoped bypass for that brand with explicit TODO and ticket link.

### Verification

- `./scripts/branding/sync-brand-assets.sh`
- `./scripts/qa/verify-brand-packages-drift.sh`
- `find infrastructure/tutor/brand-* -maxdepth 2 -type f | sort`

---

## Issue #218 - Theming Generated Artifact Governance

Issue: https://github.com/Biji-Biji-Initiative/mereka-lms/issues/218

### Current State (evidence)

- Theming uses hybrid layers:
  - canonical token CSS: `assets/branding/tokens.css`
  - SCSS bridge: `themes/mereka/scss/_tokens.scss`
  - generated MFE runtime CSS: `themes/mereka/mfe/theme/*.min.css`
- `scripts/branding/build-tokens.sh` generates minified runtime files used by `PARAGON_THEME_URLS`.
- `.min.css` outputs are tracked in git.

### Scope

- Explicit policy: which generated artifacts are tracked vs generated at build time.
- Reproducible generation chain with checksum/drift gate.

### Non-goals

- Removing SCSS bridge immediately (still needed for backward compatibility).

### Acceptance Criteria

- `AC-218-001`: The theming pipeline MUST declare canonical inputs and generated outputs in one contract doc.
- `AC-218-002`: For each generated output, policy MUST state `tracked` or `untracked`.
- `AC-218-003`: CI MUST verify determinism (`generate -> no diff`) for tracked generated artifacts.
- `AC-218-004`: Build pipeline MUST regenerate required runtime CSS before packaging MFE image.

### Migration Steps

1. Add `docs/guides/branding/THEMING_ARTIFACT_POLICY.md` with table:
   - source files
   - generated files
   - owner script
   - tracking policy.
2. Add `scripts/qa/verify-theme-artifacts-determinism.sh`.
3. Choose one policy now:
   - Option A: keep tracking `*.min.css`, enforce strict regenerate gate.
   - Option B: stop tracking `*.min.css`, generate in image build and verify presence in CI.
4. Keep SCSS bridge in place until all dependent surfaces are token-native.

### Rollback Plan

- If Option B causes runtime misses, revert to Option A quickly (re-track generated files + determinism gate).
- Keep previous build script behavior available behind feature flag for one release.

### Verification

- `./scripts/branding/build-tokens.sh`
- `git diff -- infrastructure/tutor/themes/mereka/mfe/theme`
- `./scripts/qa/verify-token-drift.sh`

---

## Issue #219 - Verify-Suite Consolidation

Issue: https://github.com/Biji-Biji-Initiative/mereka-lms/issues/219

### Current State (evidence)

- `490` `verify-*.sh` scripts across repo.
- Only a subset is directly invoked by workflows.
- Current script surface is hard to reason about for gate coverage and ownership.

### Scope

- Rationalize verification suite into declared lanes and ownership.
- Separate blocking gates from advisory/manual checks.

### Non-goals

- Migrating every script to Python in one cycle.
- Removing all Bash checks immediately.

### Acceptance Criteria

- `AC-219-001`: Every verify script MUST be classified (`blocking`, `scheduled`, `manual`, `deprecated`).
- `AC-219-002`: A machine-readable gate manifest MUST map workflows to required checks.
- `AC-219-003`: Deprecated scripts MUST emit deprecation warning and planned removal version.
- `AC-219-004`: CI MUST ensure all blocking checks remain reachable from at least one workflow.

### Migration Steps

1. Create `scripts/qa/verify-manifest.yml` with:
   - script path
   - class
   - owner
   - workflow bindings.
2. Add `scripts/qa/verify-manifest-integrity.sh` to detect orphaned blocking checks.
3. Create wrapper entrypoints by lane:
   - `scripts/qa/run-lane-auth.sh`
   - `scripts/qa/run-lane-branding.sh`
   - `scripts/qa/run-lane-ops.sh`
4. Begin deprecating duplicate/narrow scripts with aliases to lane runners.

### Rollback Plan

- Keep old script paths as thin wrappers until downstream workflows are migrated.
- If a lane wrapper fails unexpectedly, workflows can temporarily call previous direct scripts.

### Verification

- `find scripts -type f -name 'verify-*.sh' | wc -l`
- `./scripts/qa/verify-manifest-integrity.sh`
- `rg -n "verify-.*\\.sh" .github/workflows`

---

## Issue #220 - Multi-Tenancy Declarative Source of Truth

Issue: https://github.com/Biji-Biji-Initiative/mereka-lms/issues/220

### Current State (evidence)

- Tenant onboarding is split across:
  - Django command (`provision_tenant.py`)
  - shell wrappers (`provision-tenant.sh`, `provision-mfe-config.sh`)
  - Caddy and k8s config
  - DNS updates
  - branding sync and enterprise setup.
- `configmap-tenants.yaml` explicitly states it is bootstrap/reference, not canonical.
- Multiple manual steps remain after command execution.

### Scope

- Define one declarative tenant spec from which onboarding is generated.
- Reduce multi-system manual hand edits.

### Non-goals

- Replacing Open edX Site/SiteConfiguration model.
- Full elimination of human approvals for DNS or certs in phase 1.

### Acceptance Criteria

- `AC-220-001`: A tenant spec file format MUST exist (slug, domains, branding key, enterprise UUID, feature flags, org filter).
- `AC-220-002`: Provisioning pipeline MUST generate/apply Django tenant records and MFE config from that spec.
- `AC-220-003`: Routing and DNS targets MUST be derivable from the same spec.
- `AC-220-004`: Onboarding of one new tenant MUST require one spec change + one orchestrated command.

### Migration Steps

1. Define `tenants/registry.yaml` as canonical tenant declaration.
2. Implement `scripts/tenants/apply-tenant-registry.sh` to orchestrate:
   - Django `provision_tenant`
   - MFE config provisioning
   - generated patch artifacts for Caddy/DNS manifests.
3. Keep `configmap-tenants.yaml` generated from `tenants/registry.yaml` (not hand-edited).
4. Add drift check: live DB + configmap + registry consistency.

### Rollback Plan

- Preserve existing manual scripts as fallback path during migration.
- If registry apply fails mid-run, run idempotent re-apply after fixing spec.
- Keep per-tenant disable/offboard workflow independent from registry rollout.

### Verification

- `./scripts/tenants/apply-tenant-registry.sh --dry-run`
- `./scripts/qa/verify-tenant-isolation-gates.sh --offline`
- `./scripts/qa/verify-mfe-config-contract.sh --env prod`

---

## Issue #221 - Purchase Gateway Outbox/Saga

Issue: https://github.com/Biji-Biji-Initiative/mereka-lms/issues/221

### Current State (evidence)

- Stripe webhook is idempotent at event level, but fulfillment is synchronous in webhook request path (`webhooks.py` -> `fulfill_order`).
- On fulfillment error, API returns `500` and relies on Stripe redelivery.
- Config advertises retry/queue knobs (`REDIS_URL`, `FULFILLMENT_MAX_RETRIES`, `ENABLE_RECONCILIATION_JOB`) but durable worker/outbox path is not implemented.

### Scope

- Durable payment-to-fulfillment boundary with asynchronous processing.
- Explicit retry and reconciliation for split-brain prevention.

### Non-goals

- Replacing Stripe as source of payment truth.
- Rewriting all order/refund logic in phase 1.

### Acceptance Criteria

- `AC-221-001`: `checkout.session.completed` processing MUST atomically persist a fulfillment job record (outbox) with payment state transition.
- `AC-221-002`: Webhook endpoint MUST ACK quickly after persistence; fulfillment MUST execute asynchronously.
- `AC-221-003`: Worker MUST enforce bounded retries with backoff and dead-letter state.
- `AC-221-004`: Reconciliation job MUST requeue failed/stuck jobs and emit metrics/alerts.
- `AC-221-005`: System MUST remain idempotent across duplicate Stripe delivery and worker retries.

### Migration Steps

1. Add new DB model/table:
   - `fulfillment_jobs` with status, attempt count, next_attempt_at, dedupe keys.
2. Change webhook flow:
   - persist event + order state + outbox job in one transaction
   - return success after commit.
3. Add worker process deployment (separate deployment from API) consuming outbox jobs.
4. Add reconciliation cron/worker scanning `failed`/`processing-timeout` jobs.
5. Add metrics:
   - queue depth
   - retry count
   - age of oldest pending job
   - fulfillment success/failure rates.

### Rollback Plan

- Keep synchronous fulfillment codepath behind feature flag `ENABLE_ASYNC_FULFILLMENT`.
- In incident mode, disable async flag and fall back to current synchronous behavior.
- Preserve outbox table for forensic continuity even if worker disabled.

### Verification

- Unit/integration tests for duplicate webhook + worker retry idempotency.
- Stripe test replay to force transient LMS failure and verify eventual fulfillment.
- Runtime check: no long-lived pending jobs beyond defined SLO.

---

## Issue #222 - Authn Submodule Path Canonicalization

Issue: https://github.com/Biji-Biji-Initiative/mereka-lms/issues/222

### Current State (evidence)

- `.gitmodules` path is `tmp/frontend-app-authn`.
- Some docs/specs reference `apps/frontend-app-authn`.
- This creates structural contract drift and operator confusion.

### Scope

- Choose and enforce one canonical submodule path contract.
- Align docs/specs/scripts with actual structure.

### Non-goals

- Migrating entire frontend development layout in same phase.

### Acceptance Criteria

- `AC-222-001`: Repo MUST define one canonical location for authn submodule and document rationale.
- `AC-222-002`: `.gitmodules`, README, repository guide, and structure specs MUST be consistent.
- `AC-222-003`: CI/qa check MUST fail on references to non-canonical path.

### Migration Steps

1. Decision point:
   - Option A: keep `tmp/frontend-app-authn` and update docs/specs to match.
   - Option B: move submodule to `apps/frontend-app-authn` and update references + scripts.
2. Execute one canonical decision in one PR:
   - update `.gitmodules` (if path changes)
   - update docs/spec references
   - add path contract check (`scripts/qa/verify-submodule-path-contract.sh`).
3. If moving path, include migration note for local clones:
   - `git submodule sync --recursive`
   - `git submodule update --init --recursive`.

### Rollback Plan

- If submodule path move breaks local workflows, revert pointer/path change and keep doc-only normalization first.
- Keep compatibility mention for one release in onboarding docs.

### Verification

- `git config -f .gitmodules --get-regexp '^submodule\\..*\\.path$'`
- `rg -n "apps/frontend-app-authn|tmp/frontend-app-authn" README.md docs specs scripts`
- `git submodule status`

---

## Handoff Notes for Implementor

- Execute one child issue per PR.
- Link PR to child issue and parent `#214`.
- Attach before/after verification output for each AC group.
- Do not combine `#221` with infra/theming work; keep it isolated as reliability track.
