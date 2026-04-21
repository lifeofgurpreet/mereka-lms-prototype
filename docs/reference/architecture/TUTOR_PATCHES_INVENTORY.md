# Tutor Patches Inventory

This document classifies every patch module in `infrastructure/tutor/patches/` and describes
its relationship to the native Tutor hooks/filters in `infrastructure/tutor/plugins/mereka_lms.py`.

**Maintained as of**: 2026-04-20

## Classification Key

| Label | Meaning |
|-------|---------|
| `CONVERTIBLE` | Logic can live entirely in an `ENV_PATCHES` (or other Tutor filter) hook and survive `tutor config save` without any post-render surgery. |
| `FILESYSTEM` | Requires `cp`, `mkdir`, or regex surgery on _already-rendered_ files in `tutor_env/`. Cannot be expressed as a Tutor template patch alone. |
| `ALREADY_CONVERTED` | The logical equivalent already exists in `mereka_lms.py` via an `ENV_PATCHES` hook; the bash patch now only guards against mismatches in the rendered output (belt-and-suspenders or legacy idempotency). |
| `REMOVED` | Fully migrated to `mereka_lms.py` plugin and deleted from `patches/`. No bash equivalent remains. |

---

## Patch Modules

### `_common.sh`

| Field | Value |
|-------|-------|
| LOC | 98 |
| Classification | N/A (shared infrastructure, not a patch) |
| What it does | Activates the Python venv, then uses Python introspection to locate Tutor template files (MFE Dockerfile, MySQL docker-compose, openedx Dockerfile, Caddy, nginx, LMS settings, assets.py, webpack config). Exports all paths as shell variables used by every other patch module. |
| Tutor hook | Not applicable — this is the bootstrap harness for the bash system. |
| Risk | N/A |
| Notes | Must remain; every FILESYSTEM patch depends on the template paths it exports. |

---

### `mysql-auth.sh`

| Field | Value |
|-------|-------|
| Classification | `REMOVED` (2026-02-27) |
| What it did | 1. Added `MYSQL_ROOT_HOST: "%"` after `MYSQL_ROOT_PASSWORD` in `docker-compose.yml`. 2. Replaced `--mysql-native-password=ON` with `--default-authentication-plugin=mysql_native_password`. |
| Migrated to | `hooks.Filters.ENV_PATCHES` → patch name `"mysql-docker-compose"` in `mereka_lms.py`. |

---

### `mfe-node.sh`

| Field | Value |
|-------|-------|
| Classification | `REMOVED` (post-2026-04-10 rebase) |
| What it did | Historically performed regex surgery on the rendered Tutor MFE Dockerfile for toolchain, cookie env, theme and brand copy, npm resilience, dependency additions, source-ref rewrites, and other stage-specific mutations. |
| Replaced by | Tutor plugin MFE Dockerfile hooks in `infrastructure/tutor/plugins/_mereka_lms/mfe_dockerfile.py` plus bounded patch-only build-context sync via `scripts/infra/prepare-tutor-build-context.sh` / `apply-patches.sh`. |
| Notes | Historical only. This file is no longer part of the active patch chain and must not be treated as current MFE authority. The plugin-owned runtime theme contract now handles both legacy object-form `PARAGON_THEME` payloads and newer IIFE-wrapped payloads before it rewrites absolute `/theme/*` URLs and tenant-specific variant maps into the rendered authn shell. |

---

### `domain-names.sh`

| Field | Value |
|-------|-------|
| Classification | `REMOVED` (2026-02-27) |
| What it did | Added `academy.biji-biji.com` and `skillourfuture.academy.mereka.io` to ALLOWED_HOSTS, nginx server_name, and Caddy proxy blocks. |
| Migrated to | `openedx-lms-production-settings`, `nginx-lms-config`, `caddy-caddyfile` ENV_PATCHES in `mereka_lms.py`. |

---

### `webpack-memory.sh`

| Field | Value |
|-------|-------|
| LOC | 74 |
| Classification | `FILESYSTEM` |
| What it does | Mutates the openedx Dockerfile and `webpack.prod.config.js`: 1. Adds `ENV NODE_OPTIONS="--max-old-space-size=6144"`, `ENV REQUIRE_BUILD_PROFILE_OPTIMIZE=none`, `ENV PYTHONPATH=`. 2. Removes lower memory limits. 3. Deduplicates ENV blocks from prior runs. 4. Disables parallel Terser. 5. Removes `requireCompatConfig` from the webpack export. Targets both templates and rendered copies. |
| Tutor hook equivalent | `openedx-dockerfile-pre-assets` ENV_PATCH (line 382–391) covers NODE_OPTIONS + PYTHONPATH for new renders. `webpack-prod-config` ENV_PATCH (line 536–548) covers Terser. But the deduplication logic and removal of lower limits must act on the already-rendered file. |
| Why it must stay bash | The ENV block injection is positional (must come after a specific WORKDIR line) and the existing file may have stale ENV values from prior renders. Tutor ENV_PATCHES cannot remove or replace existing content. |
| Risk of conversion | MEDIUM — the new-render path is covered; the rendered-file cleanup is the only remaining bash responsibility. |

---

### `csrf-origins.sh`

| Field | Value |
|-------|-------|
| Classification | `REMOVED` (2026-02-27) |
| What it did | Appended `CSRF_TRUSTED_ORIGINS.append(...)` entries for biji-biji.com and skillourfuture to `production.py`. |
| Migrated to | `openedx-lms-production-settings` ENV_PATCH with `MEREKA_LMS_EXTRA_CSRF_ORIGINS` config default in `mereka_lms.py`. |

---

### `footer-component.sh`

| Field | Value |
|-------|-------|
| LOC | 25 |
| Classification | `FILESYSTEM` |
| What it does | Copies MFE theme SCSS and font assets from `infrastructure/tutor/themes/mereka/` into `tutor_env/env/plugins/mfe/build/mfe/indigo/mereka/`. This is a pure filesystem operation: `mkdir`, `rm -rf`, `cp -R`. |
| Tutor hook equivalent | None. The active MFE Dockerfile authority expects these assets to physically exist in the build context before image build. A Tutor ENV_PATCH cannot create files. |
| Why it must stay bash | Filesystem operations (copy files into the build context). Cannot be expressed as a Tutor filter. |
| Risk of conversion | N/A — inherently a filesystem operation. |
| Notes | JSX/env.config surgery was removed in T101 (footer migration to PLUGIN_SLOTS). This function now only syncs static assets. |

---

### `brand-package.sh`

| Field | Value |
|-------|-------|
| LOC | 22 |
| Classification | `FILESYSTEM` |
| What it does | Copies the OEP-48 brand package from `infrastructure/tutor/brand-mereka/` into `tutor_env/env/plugins/mfe/build/mfe/indigo/brand-mereka/`. Pure filesystem operation. |
| Tutor hook equivalent | None. The MFE Dockerfile `COPY` and `npm install @edx/brand@file:./brand-mereka` require the package to physically exist in the build context. |
| Why it must stay bash | Filesystem operations. Cannot be expressed as a Tutor filter. |
| Notes | Added 2026-02-27 for OEP-48 brand package support (FE-001). |

---

### `apply-patches.sh` inline helper — pull_translations retry wrapper

| Field | Value |
|-------|-------|
| Classification | `FILESYSTEM` |
| What it does | Rewrites each rendered MFE Dockerfile `RUN make OPENEDX_ATLAS_PULL=true ... pull_translations` line into a retry-wrapped bash loop with a sentinel comment. This protects long cold builds from transient GitHub/DNS failures during Atlas translation pulls. |
| Tutor hook equivalent | None today. Existing Tutor MFE hooks can inject additional Dockerfile lines around npm install/build phases, but they do not rewrite the already-rendered `pull_translations` RUN line emitted by the Tutor MFE template. |
| Why it must stay bash | The change is positional and non-additive: it transforms an already-rendered Dockerfile line in place. Tutor `ENV_PATCHES` can append hook content, but they cannot replace the upstream `pull_translations` RUN line once rendered. |
| Risk of conversion | MEDIUM — removal without an equivalent retry surface re-exposes cold builds to transient Atlas/GitHub DNS failures late in the Docker build graph. |
| Notes | As of 2026-04-14 this is the only direct rendered MFE Dockerfile rewrite left in `apply-patches.sh`. Theme-copy surgery was removed; durable MFE Dockerfile ownership now lives in Tutor plugin hooks. |

---

### `prometheus-metrics.sh`

| Field | Value |
|-------|-------|
| Classification | `REMOVED` (2026-02-27) |
| What it did | Injected `django_prometheus` into INSTALLED_APPS + middleware, added `/metrics` nginx block. |
| Migrated to | `openedx-lms-production-settings` (INSTALLED_APPS, middleware), `nginx-lms-config` (/metrics block), `openedx-dockerfile-post-python-requirements` (pip install) in `mereka_lms.py`. |

---

### `build-optimizations.sh`

| Field | Value |
|-------|-------|
| LOC | 927 |
| Classification | `FILESYSTEM` |
| What it does | Residual rendered Open edX Dockerfile normalization only. It now owns the base/assets `uv pip --no-build-isolation` normalization, plain-pip `uwsgi` fallback, production-stage build-profile arg, translation settings preflight, `openedx_advanced_xblocks` source carry before translation discovery, and fast-build translation command wrappers that still need positional post-render surgery in the rendered Open edX Dockerfile. It no longer owns the Tutor Dockerfile template target, rendered `docker-compose.yml`, `production.py`, `assets.py`, `lms.conf`, or Caddyfile rewrites, and it no longer owns build-context mirror sync for theme assets, custom apps, or the multi-tenancy plugin. It also no longer owns the duplicate brand compile tail, conditional webpack skip, legacy translation preflight scrubbers, local requirements reinstall scrubber, legacy base requirements pin scrubbers, stale openedx-i18n archive/version rewrites, ancient pip bootstrap rewrite, duplicate production-stage custom-app reinjection scrubbers, obsolete edx-platform cherry-pick scrubbers, escaped Google Fonts regex rewrites, raw pyenv clone compatibility rewrites, stale target scans, static payload trim, final runtime prune-stage rewrites, or the dead MySQL auth compatibility rewrite. The verifier now enforces those boundaries directly. |
| Tutor hook equivalent | Most of the former scope is source-owned elsewhere: support dependency install steps are in `openedx-dockerfile-post-python-requirements`; LMS settings in `openedx-lms-production-settings`; asset build settings in `openedx-common-assets-settings`; edge config in `nginx-lms-config` and `caddy-caddyfile`; and build-context mirror sync in `apply-patches.sh`. Tutor 21 exposes no additive hook before the base/assets install, `uwsgi` install, or production translation block, so those remaining cold-build compatibility changes still mutate rendered lines after render. |
| Why it must stay bash | 1. The remaining Dockerfile surgery is positional and non-additive. 2. Base/assets install, `uwsgi`, the profile-aware translation block, and advanced-xblock source carry must be inserted before later Tutor hooks exist in Tutor 21. 3. The verifier now depends on this module staying tightly scoped so stale template or rendered-target scans do not creep back in. |
| Risk of conversion | MEDIUM — the remaining scope is much smaller, but it still patches rendered Dockerfile text in place and needs render-contract proof if moved. |

#### Remaining `build-optimizations.sh` Mutation Ledger

This file is a controlled compatibility layer, not a second source generator.
The J-exit target is raw Tutor render -> explicit allowed delta -> artifact.
Do not add another post-render mutation unless the change is classified as
`authority correction`, `obsolete expectation removal`, `temporary waiver`, or
`intentional architecture change`, and this ledger is updated in the same PR.

| Mutation | Authority class | Why it remains post-render | Retirement trigger | Guard |
|---|---|---|---|---|
| `base-assets-no-build-isolation`: base/assets `uv pip --no-build-isolation` normalization | temporary compatibility layer | Tutor 21 emits the install line before any live local hook can replace it without text surgery. | Tutor/upstream exposes a source hook or bake-owned dependency install stage that can express the exact install contract before render. | `verify-tutor-config.sh`, `verify-cold-start-onboarding-contract.sh`, `verify-build-optimizations-render-delta-contract.sh` |
| `uwsgi-plain-pip-fallback`: plain-pip `uwsgi` fallback | temporary compatibility layer | The rendered install path needs a non-PEP-517 fallback for the cold-build runtime dependency; current source hooks cannot replace the emitted line in place. | Dependency install semantics move to a source hook, upstream image, or bake stage with equivalent cold-build proof. | `verify-tutor-config.sh`, `verify-build-optimizations-render-delta-contract.sh` |
| `production-build-profile-arg`: production-stage `ARG MEREKA_BUILD_PROFILE=proof` | intentional architecture change | The profile switch is a repo-owned build behavior used to distinguish proof/fast translation behavior in the rendered production stage. | Bake/HCL owns the profile contract directly and render no longer needs a Dockerfile arg injection. | `verify-cold-start-onboarding-contract.sh`, benchmark workflow proof |
| `translation-settings-preflight`: translation settings preflight | intentional architecture change | Open edX translation discovery fails late without repo-owned settings validation before the production translation commands. | Translation preflight becomes source-owned through a Tutor hook or an upstream-supported build step before translation discovery. | `verify-tutor-config.sh`, true-cold benchmark proof |
| `advanced-xblocks-production-copy`: advanced XBlock source carry before translation discovery | intentional architecture change | Translation discovery needs source files before the rendered production stage reaches them. | XBlock source placement becomes bake/source-hook owned before translation discovery. | `verify-cold-start-onboarding-contract.sh`, true-cold benchmark proof |
| `fast-profile-translation-wrappers`: fast-profile translation command wrappers | temporary compatibility layer | The wrapper changes existing rendered translation command behavior; current Tutor hooks cannot replace those command lines cleanly. | Bake/HCL or a source hook owns fast/proof translation semantics without command-line text rewrites. | `verify-tutor-config.sh`, benchmark workflow proof |

Owner: platform build authority lane. Review date: 2026-04-27 or before merge
of any PR that changes `build-optimizations.sh`.

---

### `dependency-image-mirrors.sh`

| Field | Value |
|-------|-------|
| Classification | `FILESYSTEM` temporary compatibility layer |
| What it does | Rewrites only upstream hardcoded Docker Hub dependency image references in rendered Open edX/MFE Dockerfiles to equivalent `mirror.gcr.io` references: Dockerfile frontend, Open edX Ubuntu base, Open edX `powerman/dockerize`, and MFE Node base. |
| Tutor hook equivalent | None in Tutor 21/tutormfe for the Dockerfile frontend line, base `FROM` image, or `COPY --from` helper image before render. Tutor config covers exposed service/helper image refs, but not these emitted Dockerfile dependency refs. |
| Why it must stay bash | The rendered lines are emitted before any additive hook can express them, and BuildKit registry mirror config falls back to Docker Hub for these digests under ARC rate limits. |
| Risk of conversion | LOW if kept exact-match only. Any expansion must add a fixture and update this inventory. |

#### Remaining `dependency-image-mirrors.sh` Mutation Ledger

Allowed render-delta id: `dependency-image-mirror-normalization`.

| Mutation | Authority class | Why it remains post-render | Retirement trigger | Guard |
|---|---|---|---|---|
| Dockerfile frontend mirror: `# syntax=mirror.gcr.io/docker/dockerfile:1` | temporary compatibility layer | The syntax directive is emitted by upstream templates and resolved before normal build stages. | Tutor/tutormfe exposes a source setting for Dockerfile frontend image, or CI can authenticate Docker Hub without affecting developer cold start. | `test-dependency-image-mirrors-patch.sh`, `verify-cold-start-onboarding-contract.sh`, app-cache-cold benchmark proof |
| Open edX Ubuntu base mirror | temporary compatibility layer | Tutor 21 emits `FROM docker.io/ubuntu:22.04 AS minimal`; no config key owns this base ref. | Tutor exposes a base-image config/hook or upstream switches to non-rate-limited acquisition. | same |
| Open edX dockerize helper mirror | temporary compatibility layer | Tutor 21 emits `COPY --from=docker.io/powerman/dockerize:0.19.0`; no config key owns this helper ref. | Tutor exposes helper-image config/hook or upstream switches to non-rate-limited acquisition. | same |
| MFE Node base mirror | temporary compatibility layer | tutormfe 21 emits `FROM docker.io/node:24.11.0-bullseye-slim AS base`; no hook exists before the base stage. | tutormfe exposes a base-image setting/hook or upstream switches to non-rate-limited acquisition. | same |

---

### `mongodb-atlas.sh`

| Field | Value |
|-------|-------|
| Classification | `REMOVED` (2026-02-27) |
| What it did | Added `RUN pip install "pymongo[srv]"` to the openedx Dockerfile for Atlas SRV connections. |
| Migrated to | `openedx-dockerfile-post-python-requirements` ENV_PATCH in `mereka_lms.py`. |

---

### `security-hardening.sh`

| Field | Value |
|-------|-------|
| Classification | `REMOVED` (2026-02-27) |
| What it did | 1. Injected `(security_headers)` Caddy snippet. 2. Appended Django security settings (session cookies, CSP report-only, DRF rate limiting, login throttle). |
| Migrated to | Django settings migrated to `openedx-lms-production-settings` ENV_PATCH in `mereka_lms.py`. Caddy security headers moved to static K8s Caddyfile at `deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile`. |

---

## Summary Table

| Patch | Classification | Status |
|-------|----------------|--------|
| `_common.sh` | N/A (harness) | Active — required by all FILESYSTEM patches |
| `webpack-memory.sh` | FILESYSTEM | Active — memory limits + dedup |
| `footer-component.sh` | FILESYSTEM | Active — asset sync to build context |
| `brand-package.sh` | FILESYSTEM | Active — OEP-48 brand package sync to MFE build context |
| `dependency-image-mirrors.sh` | FILESYSTEM | Active — exact dependency-acquisition mirror normalization for upstream hardcoded Docker Hub refs |
| `apply-patches.sh:inline retry wrapper` | FILESYSTEM | Active — rendered MFE pull-translations retry wrapper |
| `build-optimizations.sh` | FILESYSTEM | Active — residual Open edX cold-build compatibility and translation preflight/wrapper surgery |
| `mfe-node.sh` | REMOVED | Removed post-rebase; replaced by Tutor plugin hooks + MFE build-context sync |
| `mysql-auth.sh` | REMOVED | Deleted 2026-02-27 → `mereka_lms.py` |
| `domain-names.sh` | REMOVED | Deleted 2026-02-27 → `mereka_lms.py` |
| `csrf-origins.sh` | REMOVED | Deleted 2026-02-27 → `mereka_lms.py` |
| `prometheus-metrics.sh` | REMOVED | Deleted 2026-02-27 → `mereka_lms.py` |
| `mongodb-atlas.sh` | REMOVED | Deleted 2026-02-27 → `mereka_lms.py` |
| `security-hardening.sh` | REMOVED | Deleted 2026-02-27 → `mereka_lms.py` + K8s Caddyfile |

---

## Converted Patches (in `mereka_lms.py`)

The following `ENV_PATCHES` hook names in `mereka_lms.py` are the canonical form of the
corresponding bash patches. These survive `tutor config save` without any post-render surgery.

| ENV_PATCH name | Replaces |
|----------------|---------- |
| `openedx-lms-production-settings` | mysql-auth, domain-names, csrf-origins, prometheus-metrics (settings portions) |
| `openedx-common-assets-settings` | build-optimizations (assets.py portion) |
| `openedx-dockerfile-pre-python-requirements` | build-optimizations (pip filter) |
| `openedx-dockerfile-python-requirements` | build-optimizations (pip install) |
| `openedx-dockerfile-pre-assets` | webpack-memory (NODE_OPTIONS), source-owned brand compile + Google Fonts stripping |
| `openedx-dockerfile-post-python-requirements` | build-optimizations (custom apps, django-prometheus), mongodb-atlas |
| `openedx-dockerfile-npm-install-cmd` | build-optimizations (npm install cmd) |
| `webpack-prod-config` | webpack-memory (Terser, requireCompatConfig) |
| `mfe-dockerfile-pre-npm-install` | historical `mfe-node` toolchain / MFE Dockerfile customisation |
| `mfe-dockerfile-post-npm-install` | historical `mfe-node` cookie env, frontend-plugin-framework, and related MFE Dockerfile customisation |
| `mfe-dockerfile-npm-install` | historical `mfe-node` npm resilience; retired in Tutor 21 path because the current template does not consume this patch |
| `mfe-env-config-buildtime-imports` | footer-component (SCSS import) |
| `mfe-env-config-runtime-definitions` | footer-component (MerekaFooter JSX — T101) |
| `mysql-docker-compose` | mysql-auth |
| `caddy-caddyfile` | domain-names (Caddy), build-optimizations (MFE proxy) |
| `nginx-lms-config` | domain-names (nginx), prometheus-metrics (nginx), build-optimizations (health) |
| `credentials-dockerfile-post-python-requirements` | (credentials VC issuer) |

### Retired / Dead Patch Names

These patch names are either historical Tutor hook names or retired plugin hooks.
Do not register them as live source-owned hooks unless `tutor config save` proves
that the rendered template consumes them.

| Dead Patch Name | Content | Impact |
| --- | --- | --- |
| `openedx-lms-assets-settings`, `openedx-cms-assets-settings` | old LMS/CMS safe_join monkey-patch hook names | Tutor 21 ignores them; the live hook is `openedx-common-assets-settings` |
| `openedx-dockerfile-npm-install-cmd` | npm install lockfile drift override | Builds fall back to default `npm ci` |
| `webpack-prod-config` | Terser parallel=false | Parallel Terser may OOM on constrained builders |
| `mfe-dockerfile-npm-install` | npm retry + resilience config | Tutor 21 MFE templates do not consume it; npm resilience is currently owned by `patches/mfe-npm-install-resilience.sh` |

**Fix approach**: These need to be converted to Tutor filter hooks (`ENV_TEMPLATE_*`)
or filesystem patches in `apply-patches.sh`. Tracked for future cleanup.

---

## History: Patch Consolidation (2026-02-27)

Six `ALREADY_CONVERTED` patches were fully removed from `infrastructure/tutor/patches/`:
`mysql-auth.sh`, `domain-names.sh`, `csrf-origins.sh`, `prometheus-metrics.sh`,
`mongodb-atlas.sh`, and `security-hardening.sh`. All functionality was already present in
`mereka_lms.py` via `ENV_PATCHES` hooks.

**Remaining 5 active patch modules** plus **1 inline `apply-patches.sh` exception** are all
`FILESYSTEM` classification — they require regex surgery on rendered files or physical file
copies into build contexts, which cannot be expressed as Tutor hooks. These must remain in bash.
