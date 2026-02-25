# Tutor Patches Inventory

This document classifies every patch module in `infrastructure/tutor/patches/` and describes
its relationship to the native Tutor hooks/filters in `infrastructure/tutor/plugins/mereka_lms.py`.

**Maintained as of**: 2026-02-25

## Classification Key

| Label | Meaning |
|-------|---------|
| `CONVERTIBLE` | Logic can live entirely in an `ENV_PATCHES` (or other Tutor filter) hook and survive `tutor config save` without any post-render surgery. |
| `FILESYSTEM` | Requires `cp`, `mkdir`, or regex surgery on _already-rendered_ files in `tutor_env/`. Cannot be expressed as a Tutor template patch alone. |
| `ALREADY_CONVERTED` | The logical equivalent already exists in `mereka_lms.py` via an `ENV_PATCHES` hook; the bash patch now only guards against mismatches in the rendered output (belt-and-suspenders or legacy idempotency). |

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
| LOC | 66 |
| Classification | `ALREADY_CONVERTED` |
| What it does | 1. Adds `MYSQL_ROOT_HOST: "%"` after `MYSQL_ROOT_PASSWORD` in `docker-compose.yml`. 2. Replaces `--mysql-native-password=ON` with `--default-authentication-plugin=mysql_native_password`. Targets both the upstream Tutor template and the rendered `tutor_env/` copy. |
| Tutor hook equivalent | `hooks.Filters.ENV_PATCHES` → patch name `"mysql-docker-compose"` in `mereka_lms.py` (line 897–907). |
| Why still in bash | Belt-and-suspenders for the rendered `tutor_env/env/local/docker-compose.yml` file in case the ENV_PATCHES hook is not yet active or the plugin was installed after the first `tutor config save`. Also normalises any brace-syntax regressions from prior runs. |
| Risk of full removal | MEDIUM — removing the bash patch is safe only after confirming the plugin is always enabled before `tutor config save`. |

---

### `mfe-node.sh`

| Field | Value |
|-------|-------|
| LOC | 334 |
| Classification | `FILESYSTEM` |
| What it does | Applies a large set of transforms to the MFE Dockerfile (template + rendered copy): 1. Sets base image to `node:18-bullseye-slim`. 2. Adds g++, python3, python3-distutils to toolchain. 3. Injects `SESSION_COOKIE_DOMAIN` / `CSRF_COOKIE_DOMAIN` ARG+ENV block. 4. Inserts `COPY indigo/mereka /openedx/app/mereka` at the right Dockerfile layers. 5. Wraps `npm clean-install` with a retry + fallback loop. 6. Installs `@openedx/frontend-plugin-framework` with `--legacy-peer-deps`. 7. Adds `react-redux`/`redux` to admin-console stage. 8. Adds symlink for course-authoring directory rename. 9. Propagates `ENABLE_NEW_RELIC` as an ENV var. 10. Rewrites Redwood branch refs to Ulmo. 11. Updates brand package version. |
| Tutor hook equivalent | Partial: `mfe-dockerfile-pre-npm-install`, `mfe-dockerfile-post-npm-install`, `mfe-dockerfile-npm-install` ENV_PATCHES in `mereka_lms.py` cover items 2–3 and 5–6 for _new_ template renders. Items 1, 4, 7–11 require regex surgery on the existing multi-stage Dockerfile and cannot be expressed as an append-only ENV_PATCH. |
| Why it must stay bash | The MFE Dockerfile is a 1000-line multi-stage file. Tutor ENV_PATCHES only append to named extension points. Changing the base image tag, rewriting branch refs, and injecting into specific stages require regex substitution on the rendered file. |
| Risk of conversion | HIGH — any partial conversion risks leaving an inconsistent Dockerfile. |

---

### `domain-names.sh`

| Field | Value |
|-------|-------|
| LOC | 105 |
| Classification | `ALREADY_CONVERTED` |
| What it does | Adds `academy.biji-biji.com` and `skillourfuture.academy.mereka.io` to: 1. `ALLOWED_HOSTS` in `production.py`. 2. `server_name` in `nginx/lms.conf`. 3. Caddy LMS proxy blocks in `Caddyfile`. Operates on both upstream templates and rendered `tutor_env/` copies. |
| Tutor hook equivalent | `openedx-lms-production-settings` patch (ALLOWED_HOSTS, line 63–68), `nginx-lms-config` patch (line 958–988), `caddy-caddyfile` patch (line 914–952) in `mereka_lms.py` — all three are `ALREADY_CONVERTED`. |
| Why still in bash | Belt-and-suspenders for the rendered copies. The plugin patches are authoritative for new renders; the bash patch guards the current `tutor_env/` state. |
| Risk of full removal | LOW — safe to remove once the plugin is confirmed always-enabled before config save. The extra hosts are fully expressed in `mereka_lms.py` `CONFIG_DEFAULTS` + ENV_PATCHES. |

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
| LOC | 47 |
| Classification | `ALREADY_CONVERTED` |
| What it does | Appends `CSRF_TRUSTED_ORIGINS.append(...)` entries for biji-biji.com and skillourfuture to `production.py`. Anchors on the existing Mereka-generated origin line. Targets both template and rendered copy. |
| Tutor hook equivalent | `openedx-lms-production-settings` ENV_PATCH includes CSRF_TRUSTED_ORIGINS loop (lines 66–68) in `mereka_lms.py`. The full set of extra CSRF origins is in `MEREKA_LMS_EXTRA_CSRF_ORIGINS` config default. |
| Why still in bash | Patches the rendered `tutor_env/` file after the fact; required when the plugin was added after the initial config save. |
| Risk of full removal | LOW — safe once plugin is always-enabled before config save. |

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

### `prometheus-metrics.sh`

| Field | Value |
|-------|-------|
| LOC | 68 |
| Classification | `ALREADY_CONVERTED` |
| What it does | 1. Injects `django_prometheus` and `openedx_prometheus` into `INSTALLED_APPS`, adds Prometheus middleware wrapping in `production.py`. 2. Adds `/metrics` nginx location block to `lms.conf`. Targets both templates and rendered copies. |
| Tutor hook equivalent | `openedx-lms-production-settings` ENV_PATCH covers Prometheus INSTALLED_APPS + middleware (lines 110–123 of plugin). `nginx-lms-config` ENV_PATCH covers the `/metrics` nginx block (lines 971–978). `openedx-dockerfile-post-python-requirements` installs `django-prometheus==2.3.1`. |
| Why still in bash | Belt-and-suspenders on rendered files. Also guards against the production.py sentinel check — the bash patch checks `"django_prometheus" not in updated` so it's idempotent if the ENV_PATCH already applied. |
| Risk of full removal | LOW — plugin covers all three insertion points. |

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
| LOC | 46 |
| Classification | `ALREADY_CONVERTED` |
| What it does | Adds `RUN pip install "pymongo[srv]"` to the openedx Dockerfile after the base requirements install step. Targets both template and rendered copy. |
| Tutor hook equivalent | `openedx-dockerfile-post-python-requirements` ENV_PATCH includes `RUN pip install "pymongo[srv]"` (line 463 of plugin). |
| Why still in bash | Belt-and-suspenders on rendered `tutor_env/env/build/openedx/Dockerfile`. Also piggybacks on the `django-prometheus` sentinel to find the right anchor line. |
| Risk of full removal | LOW — fully covered by the plugin patch. |

---

### `security-hardening.sh`

| Field | Value |
|-------|-------|
| LOC | 209 |
| Classification | `FILESYSTEM` |
| What it does | 1. Injects a `(security_headers)` Caddy named snippet before the first site block in the Caddyfile. 2. Appends a Django security settings block (session cookie flags, CSP in report-only mode, DRF rate limiting, Open edX login throttle) to `production.py`. Targets both templates and rendered copies. Guards via sentinel strings. |
| Tutor hook equivalent | The Django settings block could become a `"openedx-lms-production-settings"` ENV_PATCH. The Caddy snippet injection cannot be expressed as an additive patch because it must be inserted _before_ the first site block (not appended); Tutor's `caddy-caddyfile` patch appends to the end of the file. |
| Why Caddy part must stay bash | The `(security_headers)` snippet is a named snippet that must appear before site blocks. Tutor ENV_PATCHES for Caddyfile append to the end after all site blocks. Inserting before site blocks requires the positional regex approach in this patch. |
| Risk of settings conversion | LOW — the Django settings block (CSP, throttling) is a clean append and could be an ENV_PATCH. |
| Risk of Caddy conversion | HIGH — would require a new Tutor template extension point or a restructured Caddyfile template. |
| Recommended action | Convert the `production.py` section to an `openedx-lms-production-settings` ENV_PATCH; keep the Caddyfile injection as bash. |

---

## Summary Table

| Patch | LOC | Classification | Already in plugin? | Removable from bash? |
|-------|-----|----------------|--------------------|----------------------|
| `_common.sh` | 98 | N/A (harness) | N/A | No |
| `mysql-auth.sh` | 66 | ALREADY_CONVERTED | Yes (mysql-docker-compose) | LOW risk |
| `mfe-node.sh` | 334 | FILESYSTEM | Partial | No |
| `domain-names.sh` | 105 | ALREADY_CONVERTED | Yes (3 patches) | LOW risk |
| `webpack-memory.sh` | 74 | FILESYSTEM | Partial | No (cleanup needed) |
| `csrf-origins.sh` | 47 | ALREADY_CONVERTED | Yes (production-settings) | LOW risk |
| `footer-component.sh` | 25 | FILESYSTEM | N/A (file copy) | No |
| `prometheus-metrics.sh` | 68 | ALREADY_CONVERTED | Yes (settings + nginx) | LOW risk |
| `build-optimizations.sh` | 686 | FILESYSTEM | Partial | No |
| `mongodb-atlas.sh` | 46 | ALREADY_CONVERTED | Yes (post-requirements) | LOW risk |
| `security-hardening.sh` | 209 | FILESYSTEM (Caddy) / CONVERTIBLE (Django settings) | No | Partial (Django settings only) |

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
| `credentials-urlpatterns` | (credentials VC issuer URLs) |
| `lms-urlpatterns` | (notifications, email prefs, Mux, video URLs) |

---

## Decision: No New Conversions This Sprint

After auditing all 10 patch modules, only the Django-settings portion of `security-hardening.sh`
is a clear low-risk conversion candidate. However, the `openedx-lms-production-settings`
ENV_PATCH in `mereka_lms.py` is already large (200+ lines). Adding a 100-line CSP/throttling
block to it would be safe but not strictly necessary — the bash patch already applies it
idempotently and guards via a sentinel string (`"Security Hardening (T119)"`).

**Conclusion**: The FILESYSTEM patches must remain in bash. The ALREADY_CONVERTED patches
provide belt-and-suspenders coverage for stale rendered files. No conversions are required
at this time without breaking changes to `apply-patches.sh`.

If `security-hardening.sh` Django settings are converted in a future sprint:
- Target hook: `openedx-lms-production-settings`
- Sentinel to remove from bash: `"Security Hardening (T119)"`
- Caddy snippet injection MUST remain in bash (positional, not appendable)
