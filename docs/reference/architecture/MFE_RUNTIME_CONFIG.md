# MFE Runtime Configuration

_Last updated: 2026-02-27_

This document describes how Micro-Frontend (MFE) configuration is managed in the
Mereka LMS deployment, distinguishing between what is baked into the image at build
time and what is fetched at runtime, and providing a migration plan to move toward
fully runtime-driven configuration.

## Background

Open edX MFEs follow a two-phase configuration model:

1. **Build-time**: Values embedded into the JavaScript bundle via Webpack `ENV` at
   `docker build` time. These cannot change without rebuilding the image.
2. **Runtime**: Values fetched from the LMS `mfe_config` API endpoint
   (`/api/mfe_config/v1`) when the browser loads the MFE. Changes take effect
   immediately on the next page load with no rebuild required.

Tutor generates a single `env.config.jsx` file that is copied into every MFE image.
This file wires plugin slots (footer, header, dark-mode toggle) and is rendered from
the Jinja2 template at
`tutor_env/env/plugins/mfe/build/mfe/env.config.jsx`.

## Current State

### Configuration Sources

| Layer | Mechanism | Changes require |
|-------|-----------|-----------------|
| Build-time ENV | `ARG`/`ENV` in Dockerfile | Image rebuild + redeploy |
| `env.config.jsx` | Copied into image at build | Image rebuild + redeploy |
| `mfe_config` API | LMS endpoint, fetched on load | LMS settings change + pod restart |
| Caddy routing | Caddyfile ConfigMap | ConfigMap update + pod restart |

### What Is Baked at Build Time

The following values are set as Docker `ARG`/`ENV` in
`infrastructure/tutor/mfe-build/Dockerfile` and compiled into every MFE bundle:

| Variable | Value | Location |
|----------|-------|----------|
| `APP_ID` | e.g. `authn`, `learning`, `account` | Per-MFE `ENV` in Dockerfile |
| `PUBLIC_PATH` | e.g. `/authn/`, `/learning/` | Per-MFE `ENV` in Dockerfile |
| `MFE_CONFIG_API_URL` | `/api/mfe_config/v1` (relative) | Per-MFE `ENV` in Dockerfile |
| `NODE_ENV` | `production` | Build-stage `ENV` in Dockerfile |
| Brand package | local `brand-mereka` materialized at `node_modules/@edx/brand` | post-`npm clean-install` Dockerfile hook |
| Runtime theme payload | `mereka/theme/` | Copied into `/openedx/dist/theme` in production stage |
| Mereka SCSS | `theme-source/mereka.scss` | Imported by `env.config.jsx` from `mereka/theme-source/` |

**Key observation**: `MFE_CONFIG_API_URL` is intentionally set to a relative path
(`/api/mfe_config/v1`) so that it resolves against whatever origin the MFE is served
from. This means the LMS URL is **not** hardcoded into the bundle. The Caddyfile
reverse-proxies this path to `lms:8000` internally.

The `env.config.jsx` file is also compiled into the bundle at build time. It
currently contains:

- Import of `mereka.scss` (Mereka brand CSS)
- `MerekaFooter` React component with hardcoded social/nav links
- Per-MFE plugin slot wiring owned by the repo-local Mereka plugin
- `SITE_VARIANTS` map keyed on hostnames (academyv2.mereka.io, academy.biji-biji.com,
  skillourfuture.academy.mereka.io) — **build-time coupling to domain list**

### What Is Delivered at Runtime (mfe_config API)

The LMS endpoint `/api/mfe_config/v1` returns a JSON object. The Caddyfile in
`deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile` proxies this path from the MFE
origin to `lms:8000`, forwarding the `Host` header so the LMS can resolve the correct
`SiteConfiguration` (required for multisite).

Current keys verified by `scripts/qa/verify-mfe-config-contract.sh`:

| Key | Purpose |
|-----|---------|
| `LMS_BASE_URL` | API endpoint root for all MFE → LMS calls |
| `STUDIO_BASE_URL` | Studio link in MFE navigation |
| `AUTHN_MICROFRONTEND_URL` | Login/registration redirect |
| `AUTHN_MICROFRONTEND_DOMAIN` | CORS/cookie domain for authn |
| `REFRESH_ACCESS_TOKEN_ENDPOINT` | JWT refresh (served on MFE origin via Caddy proxy) |
| `SESSION_COOKIE_SAMESITE` | Cookie posture for cross-site SSO |
| `CSRF_COOKIE_SAMESITE` | CSRF cookie posture |
| `ACCESS_TOKEN_COOKIE_NAME` | JWT access token cookie name |
| `USER_INFO_COOKIE_NAME` | User identity cookie name |
| `DISABLE_ENTERPRISE_LOGIN` | Feature flag: enterprise SSO gate |
| `PARAGON_THEME_URLS` | Runtime theme CSS URLs served from the MFE `/theme/*` path |

Additional keys served by the LMS but not explicitly validated include feature flags
for individual MFEs (e.g. `ENABLE_DISCUSSIONS_MFE`, `DISCUSSIONS_MICROFRONTEND_URL`).

### Caddy Routing

`deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile` serves all MFEs from a single
container on port 8002. Key routing decisions:

- `/api/mfe_config/v1*` and `/login_refresh*` are reverse-proxied to `lms:8000`.
  The `Host` header is forwarded explicitly.
- Each MFE is served from its own `/dist/<app-name>` directory with `try_files`
  falling back to `index.html` for SPA routing.
- Hashed static assets (`*.js`, `*.css`, etc.) receive `Cache-Control: immutable`.
- All other responses receive `Cache-Control: no-cache` (must revalidate).
- The `orders` and `payment` paths are proxied to `payments-gateway:8080`.

The main Caddyfile at `deploy/k8s/base/apps/caddy/Caddyfile` routes the `apps.*`
vhosts to `mfe:8002` and also proxies `/api/mfe_config/v1*` from the enterprise
portal vhosts (`admin.academyv2.mereka.io`, `learner.academyv2.mereka.io`).

### LMS Production Settings (mereka_lms plugin)

`infrastructure/tutor/plugins/mereka_lms.py` injects into `openedx-lms-production-settings`:

- `DISCUSSIONS_MICROFRONTEND_URL` — constructed from `MEREKA_MFE_BASE_URL` config key
  or defaulting to `https://apps.academyv2.mereka.io/discussions`. This default is a
  build-time coupling that should move to runtime config.
- `DEFAULT_SITE_THEME = "mereka"` — theme selection baked into Django settings, not
  runtime-configurable per-request without a `SiteConfiguration` override.

## Target State

The goal is: **config that changes between environments or tenants should be
runtime-driven; only things that are truly image-specific should be build-time.**

### Build-Time (justified, keep as-is)

These values are intrinsic to the image and cannot be changed without rebuilding:

| Variable | Reason to keep build-time |
|----------|--------------------------|
| `APP_ID` | Determines which plugin slot branches execute in `env.config.jsx` |
| `PUBLIC_PATH` | Webpack base path, embedded in all asset URL references |
| `NODE_ENV` | Affects React production optimizations (dead code elimination) |
| Brand package | materialized library; must be present at webpack compile time |
| Mereka SCSS | Compiled into CSS bundle at webpack time |
| `MFE_CONFIG_API_URL` | Already relative — correct as-is |

### Runtime (target, via mfe_config API)

These values currently have environment-specific or tenant-specific values that
prevent image reuse across environments:

| Variable | Current state | Target |
|----------|--------------|--------|
| Cookie domain keys | Removed from the active MFE Dockerfile; LMS/runtime config owns delivery | Keep runtime-owned via `mfe_config` |
| New Relic toggle | Removed from the active MFE Dockerfile | Keep runtime- or release-owned; do not restore build ARGs |
| Footer nav links | Read from `MEREKA_PUBLIC_FOOTER` runtime config with code fallbacks | Keep tenant/site-owned via LMS runtime config |
| `SITE_VARIANTS` hostname map | Hardcoded in `env.config.jsx` | LMS `SiteConfiguration` already handles per-site branding; remove from MFE |
| `DISCUSSIONS_MICROFRONTEND_URL` default | Hardcoded string in mereka_lms.py plugin | Set via `SiteConfiguration` or Tutor config variable only |

### Plugin Slot Wiring

`env.config.jsx` plugin slot wiring (footer, dark mode) is appropriate as build-time
content because it is structural — it determines which React components render in
which slots. **However**, the data those components consume (nav links, branding
variants) should be sourced from runtime config keys.

## Migration Plan

### Phase 1 — Cookie domain (completed)

`SESSION_COOKIE_DOMAIN` and `CSRF_COOKIE_DOMAIN` are no longer baked into the
active MFE Dockerfile. The frontend now relies on the runtime config posture
served by the LMS instead of build-time cookie-domain args.

Verification: `scripts/qa/verify-mfe-config-contract.sh` already checks that the
correct cookie posture is present in the mfe_config API response.

### Phase 2 — Footer nav links (medium complexity)

Replace the hardcoded `navLinks`, `corporateLinks`, etc. arrays in
`tutor_env/env/plugins/mfe/build/mfe/mereka/env.config.jsx` with reads from
`getConfig().MEREKA_FOOTER_NAV_LINKS` (or similar LMS-served key).

The LMS serves arbitrary keys via `mfe_config` when they are present in the
`SiteConfiguration` `values` JSON field. Add a `MEREKA_FOOTER_CONFIG` key to
the default `SiteConfiguration` and read it in the footer component.

This decouples nav link changes from image rebuilds, which is valuable because
the Mereka marketing site structure changes frequently.

### Phase 3 — Hostname-based site variant map (medium complexity)

Replace the `SITE_VARIANTS` map in `env.config.jsx` with a single runtime config
key, e.g. `MEREKA_SITE_VARIANT`, served by the LMS based on the current
`SiteConfiguration`. The LMS already resolves the site from the `Host` header and
the mfe_config proxy forwards `Host`, so this is straightforward.

### Phase 4 — New Relic toggle (completed)

The active MFE Dockerfile no longer carries `ENABLE_NEW_RELIC` build args.
Keep any New Relic enablement decision outside the MFE build ARG contract.

### Phase 5 — DISCUSSIONS_MICROFRONTEND_URL default (cleanup)

Remove the hardcoded fallback default
`https://apps.academyv2.mereka.io/discussions` from `mereka_lms.py` and require the
value to be supplied via `MEREKA_MFE_BASE_URL` Tutor config or `SiteConfiguration`.
This prevents the production domain from leaking into non-production environments.

## Configuration Taxonomy Reference

```
┌─────────────────────────────────────────────────────┐
│  BUILD-TIME (requires image rebuild to change)      │
│                                                     │
│  APP_ID, PUBLIC_PATH, NODE_ENV                      │
│  Brand package materialized at node_modules/@edx/brand │
│  mereka.scss (compiled into CSS bundle)             │
│  env.config.jsx plugin slot structure               │
│                                                     │
└──────────────────────────┬──────────────────────────┘
                           │ browser fetches on load
┌──────────────────────────▼──────────────────────────┐
│  RUNTIME (mfe_config API — change without rebuild)  │
│                                                     │
│  LMS_BASE_URL, STUDIO_BASE_URL                      │
│  AUTHN_MICROFRONTEND_URL                            │
│  REFRESH_ACCESS_TOKEN_ENDPOINT                      │
│  SESSION_COOKIE_SAMESITE, CSRF_COOKIE_SAMESITE      │
│  SESSION_COOKIE_DOMAIN, CSRF_COOKIE_DOMAIN          │
│  DISABLE_ENTERPRISE_LOGIN                           │
│  PARAGON_THEME_URLS                                 │
│  Feature flags (ENABLE_DISCUSSIONS_MFE, etc.)       │
│                                                     │
└──────────────────────────┬──────────────────────────┘
                           │ multisite resolution
┌──────────────────────────▼──────────────────────────┐
│  PER-SITE (SiteConfiguration in LMS database)       │
│                                                     │
│  Site name, logo, theme                             │
│  MEREKA_SITE_VARIANT (target — phase 3)             │
│  MEREKA_FOOTER_CONFIG (target — phase 2)            │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## Impact on Deployment

| Change type | Current | After migration (phases 1-5) |
|-------------|---------|------------------------------|
| Cookie domain change | Rebuild + redeploy all MFEs | LMS settings change only |
| Footer nav link change | Rebuild + redeploy all MFEs | LMS SiteConfiguration update |
| Feature flag toggle | Rebuild + redeploy if build ARG | LMS settings change only |
| New Relic enable/disable | Rebuild + redeploy | LMS settings change only |
| Brand theme change (SCSS) | Rebuild + redeploy (justified) | — |
| MFE SPA routing change | Rebuild + redeploy (justified) | — |

## How Tutor Handles MFE Config

Tutor renders `env.config.jsx` from a Jinja2 template at
`tutor_env/env/plugins/mfe/build/mfe/env.config.jsx`. The template uses two
extension points:

- `patch("mfe-env-config-buildtime-imports")` — for React imports needed at build time
- `patch("mfe-env-config-buildtime-definitions")` — for component definitions
- `patch("mfe-env-config-runtime-definitions")` — for logic inside `setConfig()` that
  runs at browser load time (after mfe_config is resolved)
- `patch("mfe-env-config-runtime-definitions-{app_name}")` — per-MFE runtime logic

Tutor Indigo is retired. Mereka uses the Tutor MFE-rendered `env.config.jsx`,
then mirrors it into the repo-owned MFE build-context path at
`tutor_env/env/plugins/mfe/build/mfe/mereka/env.config.jsx`.

After any manual `tutor config save`, run
`./scripts/infra/prepare-tutor-build-context.sh --target mfe` before treating
the rendered Dockerfile or tracked snapshot as current. That canonical wrapper
checks rendered freshness, runs the remaining patch-only build-context sync, and
refreshes `infrastructure/tutor/mfe-build/Dockerfile` from the rendered
authority path.

## Files Referenced

| File | Purpose |
|------|---------|
| `infrastructure/tutor/mfe-build/Dockerfile` | MFE image build; contains build-time ARG/ENV |
| `infrastructure/tutor/plugins/mereka_lms.py` | Tutor plugin; injects LMS settings including MFE-related flags |
| `deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile` | MFE static file server + mfe_config proxy |
| `deploy/k8s/base/apps/caddy/Caddyfile` | Main Caddy config; routes `apps.*` vhosts to MFE container |
| `tutor_env/env/plugins/mfe/build/mfe/env.config.jsx` | Generated `env.config.jsx` (do not edit directly) |
| `tutor_env/env/plugins/mfe/build/mfe/mereka/env.config.jsx` | Mereka-customized `env.config.jsx` source |
| `scripts/qa/verify-mfe-config-contract.sh` | Validates mfe_config API response keys |
| `scripts/qa/verify-mfe-runtime-config.sh` | Validates runtime config structural contract |
