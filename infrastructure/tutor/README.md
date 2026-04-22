# Tutor Configuration and Patches

This directory contains Tutor configuration overrides, custom themes, and patch scripts for the Mereka Academy Open edX deployment.

## Plugin vs Script: Division of Responsibility

The Mereka LMS theming system uses TWO complementary mechanisms:

1. **Tutor Plugin** (`plugins/mereka_lms.py`) — PRIMARY for configuration patches
   - Django settings (multi-site domains, enterprise integration)
   - MFE footer component injection via Tutor hooks
   - Google Fonts stripping from SCSS sources
   - Build config (Node memory, npm retry logic)
   - Delivered automatically via Tutor hooks (no manual step)

2. **Patch Script** (`apply-patches.sh`) — COMPLEMENTARY for file-system operations
   - Asset syncing (logos, fonts, SCSS files)
   - Theme directory copying
   - Font file distribution
   - Invoked by the governed wrapper/prepare path, not by hand during normal setup

**Both are required**. The plugin handles what can be expressed as Tutor hooks. The script handles what requires file-system access after template rendering. Operators should enter through `./scripts/infra/tutor-config-save.sh` or `./scripts/infra/prepare-tutor-build-context.sh --target all`, which keep plugin sync, render, and patch-only file sync in the right order.

## Directory Structure

```
infrastructure/tutor/
├── apply-patches.sh           # Low-level compatibility layer behind prepare-tutor-build-context.sh
├── config.example.yml         # Example Tutor configuration
├── multisite-sites.yml        # Multi-site configuration
├── themes/                    # Custom themes
│   └── mereka/               # Mereka Academy theme
└── custom-apps/              # Custom Django apps
    ├── mfe_oauth_fix/        # OAuth provider visibility fix
    └── openedx_prometheus/   # Prometheus metrics integration
```

## Custom Apps

### openedx_prometheus

**Purpose**: Enables Prometheus metrics collection for monitoring LMS/CMS performance.

**What it does**:
- Installs `django-prometheus==2.3.1` package
- Adds Django middleware to track HTTP request metrics
- Exposes `/metrics` endpoint in Prometheus format
- Tracks database queries, cache operations, and Django internals

**Metrics exposed**:
- `django_http_requests_total_by_method` - Request count by HTTP method
- `django_http_requests_total_by_view` - Request count by view name
- `django_http_responses_total_by_status` - Response count by status code
- `django_http_requests_latency_seconds` - Request latency histogram
- `django_db_query_duration_seconds` - Database query duration
- `django_cache_get_total`, `django_cache_hits_total` - Cache metrics

**Integration**: Realized through the governed Tutor render/build-context path:
1. Copies app to `/openedx/openedx_prometheus` in Docker image
2. Installs django-prometheus in Open edX virtualenv
3. Adds to INSTALLED_APPS (django_prometheus must be first)
4. Configures middleware (PrometheusBeforeMiddleware and PrometheusAfterMiddleware)
5. Exposes `/metrics` through app URL wiring; current app-repo Caddy render does not manufacture `/health`

**Verification**:
```bash
# Test locally
curl http://localhost/metrics | head -20

# Test in Kubernetes
kubectl exec -n mereka-lms deploy/lms -- curl -s localhost:8000/metrics | head -20
```

**Documentation**: See `custom-apps/openedx_prometheus/README.md`

### mfe_oauth_fix

**Purpose**: Fixes OAuth provider visibility in MFE context API responses.

**Documentation**: See `custom-apps/mfe_oauth_fix/README.md`

## apply-patches.sh

This script applies remaining patch-only filesystem/build-context compatibility work after Tutor renders templates. Do not call it directly for normal local setup; use `./scripts/infra/tutor-config-save.sh` for config changes or `./scripts/infra/prepare-tutor-build-context.sh --target all` after a deliberate manual `tutor config save`.

### Why Patches Are Needed

Tutor generates templates from scratch on every `config save`. Source hooks own
behavior wherever Tutor can express it; the remaining script work is the bounded
compatibility layer documented in `patch-manifest.yml` and
`docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md`.

Current active classes:

1. **Local MySQL compatibility**: Adds `MYSQL_ROOT_HOST: "%"` after Tutor 21 renders `mysql-native-password=ON`.
2. **Dependency acquisition resilience**: Normalizes exact dependency image refs and wraps fragile MFE npm/translation install steps.
3. **Build compatibility deltas**: Keeps the allowed Open edX build delta in sync with `build-optimizations.allowed-delta.yaml`.
4. **Repo-owned filesystem sync**: Copies theme, brand package, fonts, SCSS, and custom app payloads into generated build contexts.
5. **Migration guards**: Removes stale generated residue such as retired Tutor Indigo slot ownership and deprecated MFE shells.

### Usage

**Config changes**:
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/tutor-config-save.sh --set KEY=value
tutor local restart
```

**Manual render refresh, only after a deliberate raw Tutor render**:
```bash
./scripts/infra/prepare-tutor-build-context.sh --target all
```

### Patch Targets

The script only mutates generated Tutor output and generated build-context
payloads under `tutor_env/env/`. Source behavior must live in Tutor plugins,
Bake/HCL, or repo-owned source files before this compatibility layer is retired.

## Configuration Files

### config.example.yml

Sanitized non-secret reference for local development. Generate the active
`tutor_env/config.yml` through `./scripts/infra/tutor-config-save.sh`; do not
hand-copy this file as a replacement for the governed wrapper.

**Key settings**:
- `LMS_HOST: localhost` - LMS domain
- `OPENEDX_COMMON_VERSION: open-release/ulmo.1` - Open edX version
- `PLUGINS` - Enabled Tutor plugins (discovery, mfe, notes, ecommerce, forum, aspects)
- `LMS_DEFAULT_SITE_THEME: mereka` - Default theme

### multisite-sites.yml

Multi-site configuration for serving multiple domains from one LMS instance.

## Theme Development

Themes are stored in `themes/mereka/` and synced to the build directory via `./scripts/infra/prepare-tutor-build-context.sh --target all`.

**Structure**:
```
themes/mereka/
├── lms/
│   └── static/
│       ├── images/       # Logo files
│       └── sass/         # LMS styles
├── cms/
│   └── static/
│       └── images/       # Studio logo files
├── mfe/
│   ├── fonts/           # Custom fonts for MFEs
│   └── mereka.scss      # MFE styles
└── scss/                # Shared styles
```

**Syncing themes**:
```bash
# Via make
make branding-sync

# Via script
./scripts/branding/setup-mfe-branding.sh

# Automatically during governed render prep
./scripts/infra/prepare-tutor-build-context.sh --target all
```

## Building Images with Patches

**Local development**:
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
source infrastructure/tutor/tutor-env.sh

# Refresh rendered build context first
./scripts/infra/prepare-tutor-build-context.sh --target all

# Build Open edX image (includes prometheus, oauth_fix apps)
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast

# Build MFE image
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast
```

**Production**:
```bash
# Use the release-object-driven promotion path; do not promote ad hoc local images
# from this README. See docs/architecture/PROMOTION_REALIZATION_AND_INCIDENT_FLOW.md.
```

## Prometheus Metrics Integration

### What Was Added

**Bead**: mereka-lms-2s8

1. **Custom app**: `custom-apps/openedx_prometheus/`
2. **Package**: django-prometheus==2.3.1 installed in Open edX image
3. **Configuration**: Middleware and INSTALLED_APPS configured through the governed Tutor render path
4. **Endpoint**: `/metrics` exposed via nginx lms.conf
5. **Documentation**: Metrics usage documented in custom app README

### Rebuilding Images

After changing prometheus integration:

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
source infrastructure/tutor/tutor-env.sh

# Refresh rendered build context
./scripts/infra/prepare-tutor-build-context.sh --target all

# Rebuild Open edX image (REQUIRED - takes 30-45 min)
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast

# For production deployment, do not retag `latest` or restart pods by hand.
# Use `.github/workflows/build-tutor-images.yml` to emit immutable tags/digests,
# then promote with the release-object/GitOps path.
gh workflow run build-tutor-images.yml \
  -f build_openedx=true \
  -f build_mfe=false \
  -f build_profile=production
```

### Verification

**Test /metrics endpoint**:
```bash
# Local
curl http://localhost/metrics | head -20

# Kubernetes
kubectl exec -n mereka-lms deploy/lms -- curl -s localhost:8000/metrics | head -20
```

**Expected output**:
```
# HELP django_http_requests_total_by_method Count of requests by method
# TYPE django_http_requests_total_by_method counter
django_http_requests_total_by_method{method="GET"} 42
...
```

**Check ServiceMonitor is scraping**:
```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090

# Open browser: http://localhost:9090/targets
# Search for "lms-metrics" and "cms-metrics"
# Should show as UP with recent scrape time
```

### Performance Impact

- Request overhead: ~1-2ms per request
- Memory overhead: ~10-20MB for in-memory metrics
- No external dependencies required
- Metrics stored in-memory only (Prometheus scrapes every 30s)

### Security

- `/metrics` endpoint is accessible without authentication
- In Kubernetes: Only accessible within cluster (ServiceMonitor scrapes internal port)
- Metrics do not contain user data, only aggregate counters
- Consider blocking `/metrics` from external traffic via Caddy/nginx if needed

## Troubleshooting

### Patches Not Applied

**Symptom**: Services fail to start after `tutor config save`

**Cause**: Rendered build context was not refreshed through the governed prepare path

**Fix**:
```bash
./scripts/infra/prepare-tutor-build-context.sh --target all
tutor local restart
```

### MySQL Authentication Error

**Symptom**: `Authentication plugin 'caching_sha2_password' cannot be loaded`

**Cause**: MySQL auth mode or local root-host compatibility is missing from the rendered local compose file

**Fix**: rerun the governed Tutor render path. Tutor 21 renders `--mysql-native-password=ON`; the local compatibility layer adds `MYSQL_ROOT_HOST: "%"`.

### MFE Build Fails

**Symptom**: `error gyp ERR! stack Error: not found: g++`

**Cause**: Node 24 builds of MFE dependencies require C++ toolchain

**Fix**: the repo-owned MFE Dockerfile hook adds `g++, python3, python3-distutils`

### Metrics Endpoint Returns 400

**Symptom**: `curl localhost:8000/metrics` returns HTTP 400

**Cause**: django-prometheus not installed or not in INSTALLED_APPS

**Fix**:
1. Verify django-prometheus is installed: `kubectl exec -n mereka-lms deploy/lms -- pip list | grep django-prometheus`
2. Check INSTALLED_APPS includes 'django_prometheus': `kubectl exec -n mereka-lms deploy/lms -- grep django_prometheus /openedx/edx-platform/lms/envs/production.py`
3. Rebuild image with `./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast`

### Metrics Endpoint Returns 404

**Symptom**: `curl localhost:8000/metrics` returns HTTP 404

**Cause**: URL configuration not updated or nginx not proxying /metrics

**Fix**:
1. Check nginx config: `kubectl exec -n mereka-lms deploy/lms -- cat /etc/nginx/sites-enabled/lms.conf | grep metrics`
2. Verify openedx_prometheus app in INSTALLED_APPS
3. Re-run `./scripts/infra/prepare-tutor-build-context.sh --target all`

## References

- [Tutor Documentation](https://docs.tutor.edly.io/)
- [Open edX Ulmo Release](https://docs.openedx.org/en/latest/community/release_notes/ulmo.html)
- [django-prometheus Documentation](https://github.com/korfuri/django-prometheus)
- [Prometheus Operator](https://prometheus-operator.dev/)
