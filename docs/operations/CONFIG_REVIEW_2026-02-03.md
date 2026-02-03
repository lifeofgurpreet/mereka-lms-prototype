# Tutor/Open edX Configuration Review

**Date:** 2026-02-03
**Reviewer:** Claude Agent
**Environment:** Production (GKE - academyv2.mereka.io)

## Critical Issues Fixed

### 1. Caddy Crash Loop (1098 restarts)

**Problem:** Caddy pod was in crash loop (1098 restarts) due to `advanced_metrics` directive in Caddyfile that requires a custom Caddy build with the metrics plugin.

**Error:**
```
Error: adapting config using caddyfile: parsing caddyfile tokens for 'order':
/etc/caddy/Caddyfile:5 - Error during parsing: advanced_metrics is not a registered directive
```

**Fix:** Removed `advanced_metrics` directive from `caddy-config-staging` ConfigMap.

**Result:** Caddy now running with 0 restarts, site returning HTTP 200.

## Configuration Summary

### Images in Use

| Service | Image | Notes |
|---------|-------|-------|
| LMS/CMS | `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:mereka-brand` | Custom Mereka brand |
| MFE | `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-mfe:mereka-brand` | Custom Mereka brand |
| Forum | `overhangio/openedx-forum:18.1.1` | Stock Tutor |
| Discovery | `overhangio/openedx-discovery:18.0.0` | Stock Tutor |
| Ecommerce | `overhangio/openedx-ecommerce:18.0.1` | Stock Tutor |
| Caddy | `caddy:2.7.4` | Stock (no metrics plugin) |
| MySQL | `mysql:8.4.0` | In-cluster |
| MongoDB | `mongo:7.0` | In-cluster |
| Redis | `redis:7.2.4` | In-cluster |
| Elasticsearch | `elasticsearch:7.17.13` | In-cluster |

### Resource Usage (at review time)

| Service | CPU | Memory |
|---------|-----|--------|
| LMS | 1m | 433Mi |
| CMS | 1m | 282Mi |
| LMS Worker | 2m | 741Mi |
| CMS Worker | 2m | 747Mi |
| Elasticsearch | 3m | 1397Mi |
| MySQL | 7m | 449Mi |
| MongoDB | 8m | 75Mi |

### Pod Health

All pods running with 0 restarts except:
- Caddy: Was 1098 restarts, now fixed (0 restarts after fix)

## Security Observations

### ⚠️ Secrets in ConfigMaps

The following sensitive values are visible in ConfigMaps (should be K8s Secrets):

1. **Database password** in `openedx-config-staging`:
   - `PASSWORD: "CjsIbNU3"` visible in DATABASES config

2. **Django SECRET_KEY** in `openedx-config-staging`:
   - `SECRET_KEY: "UeCMQQglnc0O68rTJQezNNSt"` visible

**Recommendation:** Move sensitive values to K8s Secrets and reference via `secretKeyRef`.

### Domain Configuration

Current domains (to be updated by v2 rename agent):
- LMS: `staging.academy.mereka.io` → `academyv2.mereka.io`
- CMS: `studio.staging.academy.mereka.io` → `studio.academyv2.mereka.io`
- MFE: `apps.staging.academy.mereka.io` → `apps.academyv2.mereka.io`

## Feature Flags Review

Enabled features:
- ✅ CERTIFICATES_HTML_VIEW
- ✅ ENABLE_COURSEWARE_INDEX
- ✅ ENABLE_LEARNER_RECORDS
- ✅ ENABLE_LIBRARY_INDEX
- ✅ MILESTONES_APP
- ✅ ENABLE_PREREQUISITE_COURSES
- ✅ ENABLE_COMPREHENSIVE_THEMING

Disabled:
- ❌ ENABLE_CSMH_EXTENDED (Courseware Student Module History - disabled for performance)

## Recommendations

### Immediate

1. [x] Fix Caddy crash loop - **DONE**
2. [ ] Rotate database password and SECRET_KEY after moving to Secrets

### Short-term

3. [ ] Move secrets from ConfigMaps to K8s Secrets
4. [ ] Add Caddy metrics via Prometheus sidecar (instead of custom Caddy build)
5. [ ] Review CSRF_TRUSTED_ORIGINS after domain rename

### Long-term

6. [ ] Consider Cloud SQL for MySQL (better backups, HA)
7. [ ] Consider MongoDB Atlas for forum (managed service)
8. [ ] Add resource requests/limits to all pods

## Files Updated

- `deploy/k8s/patches/caddy-metrics-fix.yaml` - ConfigMap patch (runtime fix applied)
