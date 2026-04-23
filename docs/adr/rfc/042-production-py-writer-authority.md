---
id: ADR-042
title: Django production.py Writer Authority — Resolving the Three-Layer Duplicate Trap
decision_status: proposed
decision_type: foundation
rollout_state: planned
owner: platform-team
created: '2026-04-23'
last_reviewed: '2026-04-23'
review_due: '2026-07-31'
supersedes: []
amends:
- ADR-006
depends_on:
- ADR-006
- ADR-021
- ADR-025
- ADR-027
- ADR-028
read_next:
- ADR-027
governs:
- build.tutor.plugin
- platform.config-rendering
- runtime.django-settings
does_not_govern: []
related_specs: []
related_oep: []
related_tutor_docs:
- https://docs.tutor.edly.io/plugins.html
related_runbooks: []
related_evidence:
- docs/ops/evidence/shadow-settings-file-defect-2026-04-19.md
- docs/ops/evidence/shadow-settings-correction-addendum-2026-04-19.md
- docs/ops/evidence/shadow-settings-source-identified-2026-04-19.md
fitness_functions: []
expiry_date: null
removal_condition: null
---
<!-- markdownlint-disable -->

# ADR-042: Django production.py Writer Authority — Resolving the Three-Layer Duplicate Trap

## Context

Four distinct code paths in two repos currently write to Open edX LMS/CMS Django settings for the same runtime file `/openedx/edx-platform/lms/envs/tutor/production.py`:

1. **Tutor plugin (app repo)** — `infrastructure/tutor/plugins/_mereka_lms/lms_settings.py` and `cms_settings.py` register Jinja-templated patches via `openedx-lms-production-settings` / `openedx-cms-production-settings` hooks. Fires at `tutor config save` (build-time). Writes: `ALLOWED_HOSTS`, `CSRF_TRUSTED_ORIGINS`, `SESSION_COOKIE_DOMAIN`, `CSRF_COOKIE_DOMAIN`, `DEFAULT_SITE_THEME`, `MFE_CONFIG` keys, `CSP_*`, Prometheus middleware, multi-tenancy apps.

2. **apply-patches.sh patch modules (app repo)** — `infrastructure/tutor/patches/*.sh` sourced by `apply-patches.sh`, executed post-`tutor config save`. Primarily Dockerfile/asset patching today; `brand-package.sh`, `build-optimizations.sh`, `webpack-memory.sh`, `sync-footer-assets.sh`, `mysql-root-host.sh`, `mfe-npm-install-resilience.sh`, `mfe-slot-ownership.sh`. Historical surface that used to write Django settings; now marked legacy post-ADR-006. Still executes on every build.

3. **bbi-infrastructure overlay patches** — `apps/mereka-lms/overlays/{dev,staging,prod}/patches/production-{lms,cms}-{env}.py` + sibling modules (`mereka_multisite.py`, `mereka_footer.py`, `mereka_jwt_session.py`, `mereka_platform_admin.py`, `mereka_forwarded_headers.py`, `mereka_enterprise_channels.py`, `mereka_xblock_iframe.py`). Mounted into pods via `configMapGenerator` → `/openedx/edx-platform/lms/envs/tutor/production.py`. Fires at **kustomize render / ArgoCD sync** (deploy-time). Writes: everything the plugin writes PLUS `SITE_ID`, `JWT_AUTH`, `CORS_*`, `XQUEUE_INTERFACE`, `FORUM_MONGODB_CLIENT_PARAMETERS`, `MEILISEARCH_*`, `CACHES`, `LOGGING`, `CODE_JAIL`, `FEATURES`, `MIDDLEWARE` injections, `CSP_REPORT_URI` derivation, `LOGIN_REDIRECT_WHITELIST`.

4. **Shadow copy (app repo)** — `deploy/k8s/base/apps/openedx/settings/lms/production.py` carries a banner declaring "SHADOW FILE. LMS RUNTIME DOES NOT LOAD THIS." A verifier was previously greping this file and reporting success while the cluster ran diverged settings (2026-04-19 incident, three evidence files). The file is a drift honeypot: grep-based verifiers pass, runtime diverges, no one notices until login breaks.

**Observed divergence** (bead `mereka-lms-9o0o` triage):

- `SESSION_COOKIE_DOMAIN`: plugin writes `{{ MEREKA_SESSION_COOKIE_DOMAIN }}` → `.academyv2.mereka.io`. Overlay writes the same string literally. The shadow file had a stale `.mereka.io` entry during the 2026-03-10 staging cookie-domain incident.
- `MIDDLEWARE`: plugin appends `csp.middleware.CSPMiddleware`. Overlay additionally injects `mereka_xblock_iframe.MerekaXBlockIframeMiddleware` BEFORE `XFrameOptionsMiddleware`. Plugin does not know about this middleware. If an operator edited the plugin to "also add the XBlock iframe middleware," the overlay's insert-before-index-of logic would silently double-register.
- `JWT_AUTH["JWT_PUBLIC_SIGNING_JWK_SET"]`: ONLY the overlay derives the public JWK from the private key (2026-03-09 fix). If a future plugin-side "fix" hardcoded a public JWK, the overlay would override it at deploy-time but a local Tutor boot would run the plugin's wrong value — producing different JWT verification behavior between local dev and cluster.
- `SITE_ID`: overlay writes `SITE_ID = 7`. Plugin never touches it. An operator who set this via `tutor config save --set SITE_ID=1` would see local divergence from prod.
- `CSP_REPORT_URI`: only the overlay derives from `SENTRY_DSN`. Shadow file contains commentary referencing this code ("Source: app-repo shadow … lines 1981-2004") — proof the shadow file was once edited in parallel with the overlay.

The Caddyfile source-parity verifier (`scripts/qa/verify-caddyfile-source-parity.sh`, bead `mereka-lms-kyat`) closed the same class of trap for one artifact. This ADR generalises that precedent and sets the authority chain for all Django settings writers.

## Decision

Per ADR-025 / ADR-027 deployment-contract boundaries:

**The bbi-infrastructure overlay file `apps/mereka-lms/overlays/{env}/patches/production-{lms|cms}-{env}.py` is the SINGLE canonical runtime-authority writer for Django production settings.** It is cluster-adjacent, per-environment, ConfigMap-mounted, and already authoritative in practice.

The other layers are demoted to explicit, bounded roles:

| Layer | New role | Allowed to write |
|---|---|---|
| **Tutor plugin** (`infrastructure/tutor/plugins/_mereka_lms/*.py`) | **Image-baked defaults only.** Writes into the Docker image at build time for local `tutor local launch` fidelity and as a fallback when the overlay ConfigMap fails to mount. | Any Django setting, but **every key written MUST also be written identically or superseded by the overlay**. Plugin value is a build-time default; overlay value is runtime truth. |
| **apply-patches.sh patch modules** (`infrastructure/tutor/patches/*.sh`) | **Dockerfile / asset / filesystem work only.** No Django settings writes. | NOT allowed to touch `production.py`, `development.py`, or any file under `/openedx/edx-platform/lms/envs/` or `/cms/envs/`. |
| **Shadow file** (`deploy/k8s/base/apps/openedx/settings/lms/production.py`) | **Retired.** File is deleted or reduced to a one-line stub that imports from the overlay-staged location via documented symlink. | Nothing. Grep-based verifiers against this path are defects. |
| **Overlay** (`bbi-infrastructure/apps/mereka-lms/overlays/{env}/patches/production-{lms,cms}-{env}.py`) | **Canonical runtime writer.** Source of truth for all Django settings at runtime. | All Django settings. |

### Scope

**In scope** (governed by this ADR):
- All files ending in `production.py`, `development.py`, `test.py`, `__init__.py` under `lms/envs/tutor/` or `cms/envs/tutor/` (rendered path).
- All sibling Python modules imported by those files (e.g. `mereka_multisite.py`).
- Tutor plugin `_register_env_patch("openedx-lms-production-settings", …)` and `_register_env_patch("openedx-cms-production-settings", …)` template payloads.

**Out of scope**:
- ConfigMap mount wiring (owned by bbi-infrastructure kustomize).
- ExternalSecret → env var materialisation (owned by ADR-004 pipeline).
- MFE config API surface (`MFE_CONFIG` dict) — plugin writes defaults, overlay may override; both are governed here.
- Caddyfile (governed by `verify-caddyfile-source-parity.sh`, bead `mereka-lms-kyat`).
- Dockerfile content (governed by ADR-006 three-layer defense for build hooks).

### Rationale

- **ADR-025 / ADR-027 authority boundary**: cluster-scoped runtime configuration lives in the GitOps repo, not the app repo. The overlay is already cluster-scoped and per-env; the plugin is image-scoped and env-agnostic. Runtime wins.
- **Failure mode evidence**: 2026-04-19 shadow-file incident proved grep-based verifiers against non-authoritative paths actively hide drift. 2026-03-10 cookie-domain and 2026-03-09 JWT-key incidents both required overlay-side fixes that a plugin-only worldview would have missed.
- **Local-vs-cluster fidelity**: keeping the plugin as an image-baked default lets `tutor local launch` continue to work without a kustomize render, at the cost of a documented rule that the plugin's writes must be a subset-or-equal of the overlay's writes for any shared key. The parity gate enforces this.
- **Patches-layer retirement is already in motion** (ADR-006 repositioned patches to post-render file-system work). This ADR closes the loophole that patches could still theoretically write Django settings by naming them out of scope.

### Alternatives Rejected

- **Plugin as canonical, overlay-as-override**: rejected. The overlay already carries env-specific logic (per-env JWT issuer, per-env Site IDs, per-env email domains) that cannot be expressed as a plugin default without making the plugin environment-aware — a category error per ADR-027.
- **Merge overlay back into plugin**: rejected. Would require the app repo to carry per-env overlays, violating deployment-contract ownership.
- **Delete the plugin's settings writers**: rejected for now. Local Tutor dev loop and upstream Tutor fidelity both depend on baked-in defaults. Retirement is a future ADR once local dev moves to kustomize-render workflow.
- **Allow the shadow file to continue as a "design doc"**: rejected. Files that look like code and live on a code path WILL be edited by an agent or human who misses the banner. Retire the file.

### Transition Plan

1. **Week 1**: ship `verify-production-py-writer-parity.sh` in warn-only mode (exit 0, print diff). Register in 6-guard matrix as advisory.
2. **Week 1**: delete the shadow file `deploy/k8s/base/apps/openedx/settings/lms/production.py` OR replace its body with a `raise ImportError("This path is non-authoritative — see ADR-042")` stub. Update any verifier that greps it to grep the overlay instead.
3. **Week 2**: audit `infrastructure/tutor/patches/*.sh` for any Django-settings writes. Migrate offenders to the plugin. Add a lint rule in `verify-production-py-writer-parity.sh` that patches are not allowed to touch `production.py`.
4. **Week 3**: flip the parity gate to enforcing mode (exit 1 on mismatch). Gate PR merges in both `mereka-lms` and `bbi-infrastructure`.
5. **Week 4**: publish operator runbook entry in `docs/ops/runbooks/` describing the two-repo edit workflow and the allowlist shape for intentional divergence.
6. **Quarterly review**: audit allowlist entries; entries older than one quarter must be converted to converged writes or escalated to ADR amendment.

### Status

**Proposed.** Not yet accepted. Authority claims take effect on merge of the accompanying parity gate and retirement of the shadow file.
