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
   - Required manual step after `tutor config save`

**Both are required**. The plugin handles what can be expressed as Tutor hooks. The script handles what requires file-system access after template rendering.

## Directory Structure

```
infrastructure/tutor/
├── apply-patches.sh           # Apply local patches to Tutor templates
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

**Integration**: Automatically enabled via `apply-patches.sh`:
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

This script applies necessary patches to Tutor-generated templates. It must be run after every `tutor config save` command.

### Why Patches Are Needed

Tutor generates templates from scratch on every `config save`, losing any manual modifications. This script re-applies required changes:

1. **Node 24 toolchain**: Upgrades MFE builds from earlier LTS defaults to Node 24.11.0 with required build tools (g++, python3)
2. **MySQL 8 authentication**: Changes default authentication plugin to `mysql_native_password`
3. **Multi-site domains**: Adds extra domain names (biji-biji.com, skillourfuture.academy.mereka.io)
4. **Webpack memory**: Increases Node memory limit to 6144MB for asset compilation
5. **Custom apps**: Copies and configures custom Django apps (prometheus, oauth_fix)
6. **Branding**: Syncs Mereka theme assets and custom MFE footer
7. **Prometheus metrics**: Installs django-prometheus and configures the app-level `/metrics` endpoint

### Usage

**Always run after config changes**:
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor config save --set KEY=value
./infrastructure/tutor/apply-patches.sh  # CRITICAL!
tutor local restart
```

**Manual patch application**:
```bash
./infrastructure/tutor/apply-patches.sh
```

### Patch Targets

The script patches both:
1. **Tutor plugin templates** (source files in Python site-packages)
2. **Generated environment** (files in `tutor_env/env/`)

This ensures patches persist even if templates are regenerated.

## Configuration Files

### config.example.yml

Sanitized template for local development. Copy to `tutor_env/config.yml` and fill in secrets.

**Key settings**:
- `LMS_HOST: localhost` - LMS domain
- `OPENEDX_COMMON_VERSION: open-release/redwood.master` - Open edX version
- `PLUGINS` - Enabled Tutor plugins (discovery, mfe, notes, ecommerce, forum, aspects)
- `LMS_DEFAULT_SITE_THEME: mereka` - Default theme

### multisite-sites.yml

Multi-site configuration for serving multiple domains from one LMS instance.

## Theme Development

Themes are stored in `themes/mereka/` and synced to the build directory via `apply-patches.sh`.

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

# Automatically during patches
./infrastructure/tutor/apply-patches.sh
```

## Building Images with Patches

**Local development**:
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
source infrastructure/tutor/tutor-env.sh

# Apply patches first
./infrastructure/tutor/apply-patches.sh

# Build Open edX image (includes prometheus, oauth_fix apps)
tutor images build openedx  # 30-45 min, needs 12GB+ RAM

# Build MFE image
tutor images build mfe      # 15-20 min
```

**Production**:
```bash
# Build and tag
tutor images build openedx
docker tag local/openedx:latest ghcr.io/biji-biji-initiative/mereka-lms/openedx:$(git rev-parse --short HEAD)

# Push to Artifact Registry
docker push ghcr.io/biji-biji-initiative/mereka-lms/openedx:$(git rev-parse --short HEAD)
```

## Prometheus Metrics Integration

### What Was Added

**Bead**: mereka-lms-2s8

1. **Custom app**: `custom-apps/openedx_prometheus/`
2. **Package**: django-prometheus==2.3.1 installed in Open edX image
3. **Configuration**: Middleware and INSTALLED_APPS configured via apply-patches.sh
4. **Endpoint**: `/metrics` exposed via nginx lms.conf
5. **Documentation**: Metrics usage documented in custom app README

### Rebuilding Images

After updating `apply-patches.sh` to include prometheus integration:

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
source infrastructure/tutor/tutor-env.sh

# Apply patches
./infrastructure/tutor/apply-patches.sh

# Rebuild Open edX image (REQUIRED - takes 30-45 min)
tutor images build openedx

# For production deployment
docker tag local/openedx:latest ghcr.io/biji-biji-initiative/mereka-lms/openedx:latest
docker push ghcr.io/biji-biji-initiative/mereka-lms/openedx:latest

# Restart pods
kubectl rollout restart deployment/lms deployment/cms -n mereka-lms
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

**Cause**: Forgot to run `apply-patches.sh`

**Fix**:
```bash
./infrastructure/tutor/apply-patches.sh
tutor local restart
```

### MySQL Authentication Error

**Symptom**: `Authentication plugin 'caching_sha2_password' cannot be loaded`

**Cause**: MySQL 8 default auth plugin incompatible with some clients

**Fix**: `apply-patches.sh` sets `--default-authentication-plugin=mysql_native_password`

### MFE Build Fails

**Symptom**: `error gyp ERR! stack Error: not found: g++`

**Cause**: Node 24 builds of MFE dependencies require C++ toolchain

**Fix**: `apply-patches.sh` adds `g++, python3, python3-distutils` to MFE Dockerfile

### Metrics Endpoint Returns 400

**Symptom**: `curl localhost:8000/metrics` returns HTTP 400

**Cause**: django-prometheus not installed or not in INSTALLED_APPS

**Fix**:
1. Verify django-prometheus is installed: `kubectl exec -n mereka-lms deploy/lms -- pip list | grep django-prometheus`
2. Check INSTALLED_APPS includes 'django_prometheus': `kubectl exec -n mereka-lms deploy/lms -- grep django_prometheus /openedx/edx-platform/lms/envs/production.py`
3. Rebuild image with patches applied: `tutor images build openedx`

### Metrics Endpoint Returns 404

**Symptom**: `curl localhost:8000/metrics` returns HTTP 404

**Cause**: URL configuration not updated or nginx not proxying /metrics

**Fix**:
1. Check nginx config: `kubectl exec -n mereka-lms deploy/lms -- cat /etc/nginx/sites-enabled/lms.conf | grep metrics`
2. Verify openedx_prometheus app in INSTALLED_APPS
3. Re-run `apply-patches.sh` to update nginx template

## References

- [Tutor Documentation](https://docs.tutor.edly.io/)
- [Open edX Redwood Release](https://docs.openedx.org/en/latest/community/release_notes/redwood.html)
- [django-prometheus Documentation](https://github.com/korfuri/django-prometheus)
- [Prometheus Operator](https://prometheus-operator.dev/)
