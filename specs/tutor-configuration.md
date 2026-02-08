---
title: "Tutor Configuration Lifecycle"
type: "feature_spec"
status: "draft"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-08"
---

# Tutor Configuration Lifecycle

## Scope

This spec covers the Tutor configuration save-patch-restart workflow required to maintain a working Open edX deployment. It ensures that local patches are consistently applied after every configuration change to prevent service failures.

## Non-goals

- Upstream Tutor template contributions (handled separately)
- Custom plugin development outside of existing patches
- Kubernetes-specific configuration (covered in k8s-deployment.md)

## Requirements

### Configuration Workflow

- The system MUST run `./infrastructure/tutor/apply-patches.sh` after every `tutor config save` operation
- The system MUST set `TUTOR_ROOT="$(pwd)/tutor_env"` before any Tutor command
- The system MUST verify local service names (`mysql`, `mongodb`, `redis`) in local deployments
- The system MUST NOT use cloud IPs (10.97.x.x) in local configuration

### Critical Patches

The `apply-patches.sh` script MUST apply the following patches:

#### MySQL Authentication
- MUST set MySQL authentication plugin to `mysql_native_password` (not `caching_sha2_password`)
- MUST add `MYSQL_ROOT_HOST: "%"` for remote root access
- MUST replace `--mysql-native-password=ON` with `--default-authentication-plugin=mysql_native_password`

#### MFE Build Toolchain
- MUST upgrade MFE base image from Node 12 to Node 18
- MUST add required build tools: `gcc g++ git libgl1 libxi6 make python3 python3-distutils`
- MUST set webpack memory limit to 6144MB via `NODE_OPTIONS=--max-old-space-size=6144`
- MUST add npm resilience with 3 retry attempts and increased timeouts

#### Multi-Site Domain Support
- MUST add `academy.biji-biji.com` to `ALLOWED_HOSTS`
- MUST add `skillourfuture.academy.mereka.io` to `ALLOWED_HOSTS`
- MUST add corresponding HTTPS origins to `CSRF_TRUSTED_ORIGINS`

#### Theme Integration
- MUST sync Mereka theme assets to build directory before image builds
- MUST copy logo variants (PNG, SVG, favicon) to LMS and CMS themes
- MUST sync font files (.woff2) to static directories
- MUST compile SASS with custom theme: `npm run compile-sass -- --skip-default --theme-dir /openedx/themes --theme mereka`
- MUST strip Google Fonts imports from SCSS and compiled CSS

#### Custom Applications
- MUST install `mfe_oauth_fix` custom app to fix OAuth provider visibility
- MUST install `openedx_prometheus` custom app for /metrics endpoint
- MUST install `django-prometheus==2.3.1` for metrics instrumentation
- MUST install `pymongo[srv]` for MongoDB Atlas SRV connection support

#### Redwood Compatibility
- MUST enable optional Redwood apps: `content_libraries`, `bookmarks`, `discussions`, `theming`
- MUST use `python -m django` instead of `django-admin.py` for message compilation
- MUST update i18n archive URL to `openedx-unsupported/openedx-i18n`
- MUST skip legacy `requirements/edx/local.in` reinstall step

## Acceptance Criteria

- [ ] `grep mysql_native_password tutor_env/env/local/docker-compose.yml` returns results
- [ ] `grep "NODE_OPTIONS.*6144" tutor_env/env/build/openedx/Dockerfile` returns results
- [ ] `grep "academy.biji-biji.com" tutor_env/env/apps/openedx/settings/lms/production.py` returns results
- [ ] `grep "mfe_oauth_fix" tutor_env/env/apps/openedx/settings/lms/production.py` returns results
- [ ] `grep "django_prometheus" tutor_env/env/apps/openedx/settings/lms/production.py` returns results
- [ ] MFE images build successfully with Node 18
- [ ] MySQL 8 connections succeed without authentication errors
- [ ] All three production domains (academyv2.mereka.io, academy.biji-biji.com, skillourfuture.academy.mereka.io) resolve and accept logins
- [ ] Mereka logo and custom footer render on all MFEs
- [ ] `tutor local dc ps` shows all services with status "Up"

## Edge Cases

### Forgetting to Run Patches

**Symptom**: MySQL authentication fails with "Authentication plugin 'caching_sha2_password' cannot be loaded"

**Recovery**:
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
./infrastructure/tutor/apply-patches.sh
tutor local restart mysql
```

### Cloud IPs in Local Config

**Symptom**: Services fail to connect, logs show "Connection refused" to 10.97.x.x

**Recovery**:
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor config save \
  --set MYSQL_HOST=mysql \
  --set MONGODB_HOST=mongodb \
  --set REDIS_HOST=redis \
  --set MONGODB_PORT=27017
./infrastructure/tutor/apply-patches.sh
tutor local restart
```

### Insufficient Docker RAM

**Symptom**: Webpack build OOM during `tutor images build openedx`

**Recovery**:
- Increase Docker Desktop RAM to ≥12GB
- Increase swap to ≥2GB
- Rebuild: `tutor images build openedx`

### Theme Assets Not Syncing

**Symptom**: Logo missing after theme changes, old branding visible

**Recovery**:
```bash
./infrastructure/tutor/apply-patches.sh
tutor images build openedx
tutor local restart lms cms
```

## Observability

### Logs

- Pre-patch validation: `scripts/branding/verify-branding-health.sh` output
- Patch application: Console output from `apply-patches.sh` showing file modifications
- Post-restart health: `tutor local logs --tail=50 lms` for startup errors

### Metrics

- Build time: Track duration of `tutor images build openedx` (baseline: 30-45 min)
- Theme sync duration: Time for `apply-patches.sh` to complete (baseline: <30s)

### Alerts

- MUST alert if `tutor config save` runs without subsequent `apply-patches.sh` within 5 minutes
- SHOULD alert if MySQL authentication fails with caching_sha2_password error

## Rollout & Rollback

### Config Save Workflow

```bash
# 1. Save new configuration
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor config save --set KEY=value

# 2. Apply patches (CRITICAL - do not skip)
./infrastructure/tutor/apply-patches.sh

# 3. Restart affected services
tutor local restart

# 4. Verify service health
docker ps --filter "name=tutor_local"
tutor local dc ps
```

### Rollback Procedure

If patches break the system:

1. Restore previous config: `cp tutor_env/config.yml.backup tutor_env/config.yml`
2. Re-run patches: `./infrastructure/tutor/apply-patches.sh`
3. Restart: `tutor local restart`
4. If still broken: `git checkout tutor_env/env/` (loses uncommitted patches)
5. Last resort: `tutor local quickstart -I` (full rebuild, 60+ min)

### Backup Strategy

- MUST backup database before major config changes: `tutor local do backup-db`
- SHOULD version `tutor_env/config.yml` in git (sensitive values redacted)
- SHOULD commit `infrastructure/tutor/apply-patches.sh` changes with context

## Open Questions

1. Can we upstream the MySQL native password patch to Tutor?
2. Should webpack memory limit be configurable via environment variable?
3. How do we detect config drift between local and production?
4. Should we automate patch verification in CI?
