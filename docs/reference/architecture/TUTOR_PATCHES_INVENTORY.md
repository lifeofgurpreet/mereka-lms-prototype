# Tutor Patches Inventory

This document classifies every patch module in `infrastructure/tutor/patches/` and describes
its relationship to the native Tutor hooks/filters in `infrastructure/tutor/plugins/mereka_lms.py`.

**Maintained as of**: 2026-02-27

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
| LOC | 334 |
| Classification | `FILESYSTEM` |
| What it does | Applies a large set of transforms to the MFE Dockerfile (template + rendered copy): 1. Sets base image to `node:24.11.0-bullseye-slim` (or Node 24+). 2. Adds g++, python3, python3-distutils to toolchain. 3. Injects `SESSION_COOKIE_DOMAIN` / `CSRF_COOKIE_DOMAIN` ARG+ENV block. 4. Inserts `COPY indigo/mereka /openedx/app/mereka` at the right Dockerfile layers. 5. Wraps `npm clean-install` with a retry + fallback loop. 6. Installs `@openedx/frontend-plugin-framework` with `--legacy-peer-deps`. 7. Adds `react-redux`/`redux` to admin-console stage. 8. Adds symlink for course-authoring directory rename. 9. Propagates `ENABLE_NEW_RELIC` as an ENV var. 10. Rewrites Redwood branch refs to Ulmo. 11. Updates brand package version. |
| Tutor hook equivalent | Partial: `mfe-dockerfile-pre-npm-install`, `mfe-dockerfile-post-npm-install`, `mfe-dockerfile-npm-install` ENV_PATCHES in `mereka_lms.py` cover items 2–3 and 5–6 for _new_ template renders. Items 1, 4, 7–11 require regex surgery on the existing multi-stage Dockerfile and cannot be expressed as an append-only ENV_PATCH. |
| Why it must stay bash | The MFE Dockerfile is a 1000-line multi-stage file. Tutor ENV_PATCHES only append to named extension points. Changing the base image tag, rewriting branch refs, and injecting into specific stages require regex substitution on the rendered file. |
| Risk of conversion | HIGH — any partial conversion risks leaving an inconsistent Dockerfile. |

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
| Tutor hook equivalent | None. The MFE `COPY indigo/mereka /openedx/app/mereka` Dockerfile instruction (injected by `mfe-node.sh` and the `mfe-dockerfile-pre-npm-install` hook) requires these files to physically exist in the build context. A Tutor ENV_PATCH cannot create files. |
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
| LOC | 686 |
| Classification | `FILESYSTEM` |
| What it does | The largest patch module. Split into two sections: **Python string surgery** on 6 target files (openedx Dockerfile, production.py, assets.py x2, lms.conf, Caddyfile), plus **bash filesystem operations**: 1. i18n archive URL fix. 2. uv pip / no-build-isolation. 3. pip install retry wrapping. 4. Local requirements removal. 5. Optional app injection (coursewarehistoryextended). 6. compilemessages fix. 7. compilejsi18n output paths. 8. node_modules COPY path fix. 9. Static bundles COPY normalization. 10. Node cache reuse (FROM openedx_node_cache). 11. postinstall fix. 12. Brand SASS compile + Google fonts strip. 13. Webpack conditional. 14. cherry-pick removal. 15. Tutor v21 node_modules mv. 16. mereka-overrides.css bake. 17. Custom apps block in Dockerfile. 18. django-prometheus pip install. 19. DEFAULT_SITE_THEME. 20. MFE OAuth fix config. 21. mereka_tenancy config. 22. MFE discussions settings. 23. assets.py optional apps + pipeline + safe_join. 24. lms.conf /health + /profile/api/ blocks. 25. Caddyfile MFE cache headers + /profile/api/ proxy. **Bash filesystem section**: Syncs logos, fonts, theme templates/CSS, custom apps, and multi-tenancy plugin into `tutor_env/env/build/openedx/`. |
| Tutor hook equivalent | Many sub-operations are partially covered: openedx Dockerfile install steps are in `openedx-dockerfile-post-python-requirements`; custom app copy in `openedx-dockerfile-post-python-requirements`; LMS settings in `openedx-lms-production-settings`; assets.py patches in `openedx-lms-assets-settings` + `openedx-cms-assets-settings`; Caddy in `caddy-caddyfile`; nginx in `nginx-lms-config`. However the positional string surgery (find-replace in the middle of multi-stage Dockerfiles), deduplication, branch-ref rewrites, and file sync cannot be expressed as ENV_PATCHES. |
| Why it must stay bash | 1. The Dockerfile surgery is positional and non-additive. 2. The bash section (lines 586–685) does physical file copies into the build context — cannot be a Tutor hook. 3. Several transforms guard against stale rendered-file content from prior runs. |
| Risk of conversion | HIGH — the Python surgery section is deeply entangled. Safe extraction would require per-operation ENV_PATCHES and careful ordering. |

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
| `mfe-node.sh` | FILESYSTEM | Active — MFE Dockerfile surgery |
| `webpack-memory.sh` | FILESYSTEM | Active — memory limits + dedup |
| `footer-component.sh` | FILESYSTEM | Active — asset sync to build context |
| `brand-package.sh` | FILESYSTEM | Active — OEP-48 brand package sync to MFE build context |
| `build-optimizations.sh` | FILESYSTEM | Active — 25+ transforms on rendered files |
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
| `openedx-lms-assets-settings` | build-optimizations (assets.py portion) |
| `openedx-cms-assets-settings` | build-optimizations (assets.py portion) |
| `openedx-dockerfile-pre-python-requirements` | build-optimizations (pip filter) |
| `openedx-dockerfile-python-requirements` | build-optimizations (pip install) |
| `openedx-dockerfile-pre-assets` | webpack-memory (NODE_OPTIONS), build-optimizations (sass compile) |
| `openedx-dockerfile-post-python-requirements` | build-optimizations (custom apps, django-prometheus), mongodb-atlas |
| `openedx-dockerfile-npm-install-cmd` | build-optimizations (npm install cmd) |
| `webpack-prod-config` | webpack-memory (Terser, requireCompatConfig) |
| `mfe-dockerfile-pre-npm-install` | mfe-node (toolchain) |
| `mfe-dockerfile-post-npm-install` | mfe-node (cookie env, frontend-plugin-framework) |
| `mfe-dockerfile-npm-install` | mfe-node (npm resilience) |
| `mfe-env-config-buildtime-imports` | footer-component (SCSS import) |
| `mfe-env-config-runtime-definitions` | footer-component (MerekaFooter JSX — T101) |
| `mysql-docker-compose` | mysql-auth |
| `caddy-caddyfile` | domain-names (Caddy), build-optimizations (MFE proxy) |
| `nginx-lms-config` | domain-names (nginx), prometheus-metrics (nginx), build-optimizations (health) |
| `credentials-dockerfile-post-python-requirements` | (credentials VC issuer) |

### Dead Patches (registered but no template consumes them)

These patch names are registered in `mereka_lms.py` via `ENV_PATCHES.add_item()` but
**no Tutor template contains `{{ patch("name") }}`** for them — content is silently discarded.

| Dead Patch Name | Content | Impact |
| --- | --- | --- |
| `openedx-cms-assets-settings` | CMS safe_join monkey-patch | CMS collectstatic may fail on edge-case theme paths |
| `openedx-dockerfile-npm-install-cmd` | npm install lockfile drift override | Builds fall back to default `npm ci` |
| `webpack-prod-config` | Terser parallel=false | Parallel Terser may OOM on constrained builders |
| `mfe-dockerfile-npm-install` | npm retry + resilience config | MFE builds use default npm install without retries |

**Fix approach**: These need to be converted to Tutor filter hooks (`ENV_TEMPLATE_*`)
or filesystem patches in `apply-patches.sh`. Tracked for future cleanup.

---

## History: Patch Consolidation (2026-02-27)

Six `ALREADY_CONVERTED` patches were fully removed from `infrastructure/tutor/patches/`:
`mysql-auth.sh`, `domain-names.sh`, `csrf-origins.sh`, `prometheus-metrics.sh`,
`mongodb-atlas.sh`, and `security-hardening.sh`. All functionality was already present in
`mereka_lms.py` via `ENV_PATCHES` hooks.

**Remaining 5 active patches** are all `FILESYSTEM` classification — they require regex surgery
on rendered files or physical file copies into build contexts, which cannot be expressed as
Tutor hooks. These must remain in bash.
