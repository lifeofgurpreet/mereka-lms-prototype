# Open edX Repository Architecture and Hygiene Audit Tracker

Last updated: 2026-03-05  
Auditor: Codex (read-only audit pass, no destructive cleanup executed)

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

- Scope: analysis only, no destructive changes.
- Method: static repo inspection + workflow/script tracing + official Open edX/Tutor/Stripe/GitHub docs cross-reference.
- Evidence style: file-backed findings with concrete paths.

## Executive Summary

1. **Git hygiene is partially healthy but inconsistent**: critical runtime artifact directories (`exports/`, `var/`, `tutor_env/`) are ignored, but production evidence artifacts are still committed under `docs/operations/evidence`, including live `Set-Cookie` headers.
2. **Brand asset duplication is real and mostly intentional** due to isolated build/runtime surfaces (Django comprehensive theming vs MFE brand package/runtime theme), but sync coverage is uneven across tenant brand packages.
3. **Theming stack is in a transitional hybrid** (design tokens + SCSS bridge + runtime minified CSS). This is currently functional but has multiple generated layers that can drift.
4. **Custom Django apps are structurally installable** (all app dirs include `setup.py`) and not tracking stateful files in git, but local cache noise is widespread.
5. **IaC control planes are fragmented** across Tutor generation, Kustomize overlays, and GitOps repo pinning; legacy Tutor-K8s scripts still exist and can conflict with current GitOps flow.
6. **Verification surface is oversized** (`490` `verify-*.sh` scripts), with relatively limited direct CI invocation and many scripts not referenced by workflows.
7. **Tenant onboarding is still multi-system** (DB, DNS, Caddy, settings, MFE config, branding) with no single declarative source of truth.
8. **Purchase gateway webhook flow lacks an internal durable saga/outbox**, relying primarily on Stripe retries plus synchronous fulfillment.

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
  - Stripe event dedupe table (`stripe_events`) with status tracking.
  - `checkout.session.completed` marks order paid, commits, then calls synchronous `fulfill_order`.
  - errors mark event failed and return HTTP 500, relying on Stripe redelivery.
- Fulfillment:
  - LMS lookup + enrollment API call inline.
  - entitlement creation for users not yet in LMS.
  - no internal persistent outbox/worker saga in current implementation.
- Config includes retry-related knobs and Redis URL, but webhook fulfillment path is synchronous.

### Architectural Smells

- **Charge-confirmed but fulfillment-failed split-brain risk** depends on external webhook retries.
- **README/config suggest queue architecture not reflected in code path**.
- **No explicit reconciliation worker shown for stuck failed events in this path.**

### Recommended Refactor

1. **Adopt transactional outbox/inbox pattern**:
   - persist fulfillment jobs atomically with payment state update.
2. **Async worker + retry policy**:
   - controlled retries, DLQ, and observability.
3. **Reconciliation loop**:
   - periodic scan of `failed/processing` events and order states.

### Stripe Guidance Reference

- Webhook duplicate handling and retries:
  - https://docs.stripe.com/webhooks
  - https://docs.stripe.com/workbench/webhooks

---

## Priority Backlog for Implementor

### P0 (Security / Correctness)

1. Redact/remove committed cookie-bearing evidence files and add CI guard against raw session/token artifacts.
2. Decide and enforce canonical location for `frontend-app-authn` submodule path.
3. Add explicit fulfillment durability plan (outbox + retry worker) for purchase gateway.

### P1 (Architecture Stabilization)

1. Publish single authoritative IaC flow and deprecate legacy Tutor-K8s runtime scripts.
2. Standardize multi-brand asset sync coverage and drift checks across all brand packages.
3. Classify/curate verify script inventory into enforceable suites.

### P2 (Debt Reduction)

1. Normalize docs/spec path references where current repository reality differs.
2. Improve local cache cleanup ergonomics for large Python cache footprints.

## Recommended Execution Sequencing

1. **Start immediately (parallel-safe):**
   - #215 evidence pipeline hardening
   - #216 IaC control-plane unification draft contract
   - #219 verification suite inventory/classification
2. **Begin once #215 policy is decided:**
   - #217 multi-brand sync/drift contract
   - #218 theming generated artifact governance
3. **Begin once #216 contract is stable:**
   - #220 multi-tenancy declarative source-of-truth design
4. **Run as backend reliability track:**
   - #221 purchase-gateway outbox/saga design + implementation
5. **Quick hygiene alignment track:**
   - #222 submodule canonicalization + docs/spec path normalization

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
