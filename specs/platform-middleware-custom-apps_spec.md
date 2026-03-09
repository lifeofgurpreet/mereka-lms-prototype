---
title: Platform Middleware and Custom Apps
type: feature_spec
status: completed
owner: engineering
vehicle: talent_platform
version: 1.0.0
depends_on:
- specs/repository-structure_spec.md
- specs/k8s-deployment_spec.md
- specs/tutor-configuration_spec.md
links:
  related_docs:
  - deploy/k8s/base/apps/openedx/settings/lms/mereka_platform_admin.py
  - deploy/k8s/base/apps/openedx/settings/lms/mereka_multisite.py
  - deploy/k8s/base/apps/openedx/settings/lms/mereka_forwarded_headers.py
  - infrastructure/tutor/custom-apps/mfe_oauth_fix/README.md
  - infrastructure/tutor/custom-apps/openedx_prometheus/README.md
  related_specs:
  - specs/multi-site-domains_spec.md
  - specs/k8s-deployment_spec.md
  - specs/observability-stack_spec.md
  - specs/secrets-management_spec.md
  - specs/cross-cutting-requirements_spec.md
id: SPEC-PLATFORM-MIDDLEWARE-CUSTOM-APPS
spec_class: integration
created: '2026-02-10'
last_reviewed: '2026-02-10'
review_due: '2026-05-11'
domain: platform
normativity: normative
summary: Normative contract for platform middleware behavior and custom app integration
  points.
---

# Human Summary

## What we're building

A custom middleware stack and two Django apps that solve critical operational problems in the Mereka Academy Open edX deployment. The middleware stack consists of three production components: **MerekaPlatformAdminMiddleware** (auto-escalates configured admin emails to staff/superuser), **MerekaCookieDomainMiddleware** (ensures valid cookie domains when serving multiple root domains like academyv2.mereka.io and academy.biji-biji.com), and **MerekaForwardedHeadersMiddleware** (normalizes X-Forwarded headers from proxy chains and fixes Prometheus pod IP rejection). Two custom Django apps extend the platform: **mfe_oauth_fix** (intercepts `/api/mfe_context` responses to inject OAuth providers and normalize provider names) and **openedx_prometheus** (exposes `/metrics` endpoint with django-prometheus integration for cluster monitoring).

## Why it matters

Without this stack, the platform is operationally fragile. Platform admins who lose staff privileges cannot recover the system without database access. Multi-domain deployments break session management when cookies set invalid `Domain=.academyv2.mereka.io` attributes while serving `academy.biji-biji.com`, causing authentication failures across MFE boundaries. Cloudflare-to-Ingress-to-Caddy proxy chains produce multi-valued headers like `X-Forwarded-Proto: https,http`, which Django's `SECURE_PROXY_SSL_HEADER` rejects, breaking HTTPS detection and OAuth callbacks. MFE login pages show empty provider arrays even when OAuth is configured correctly. Prometheus cannot scrape metrics because Django rejects pod IP requests as `DisallowedHost`. These are not edge cases -- they are production blockers that require code-level fixes, not configuration workarounds.

## Success looks like

- Platform admin emails configured in `MEREKA_PLATFORM_ADMIN_EMAILS` always have `is_staff=True`, `is_superuser=True`, even after accidental privilege revocation.
- Session cookies work seamlessly across `apps.academyv2.mereka.io`, `studio.academyv2.mereka.io`, and `apps.academy.biji-biji.com` with correct domain scoping.
- HTTPS detection works reliably behind Cloudflare proxies, with OAuth callbacks returning to `https://` URLs.
- MFE authn login page displays "Mereka" as the OAuth provider name, not "Authentik".
- Prometheus scrapes `/metrics` from LMS/CMS pods without `DisallowedHost` errors.
- All middleware passes on every request (sub-millisecond overhead).

# Agent Contract

## Scope

This spec covers the custom middleware stack and custom Django apps deployed to the Mereka Academy Open edX platform. It defines the request-processing flow, configuration requirements, security boundaries, and observability hooks.

## Non-goals

- Generic multi-tenancy framework (the middleware is Mereka-specific, not a reusable plugin)
- Automated admin role assignment via external identity provider (this is a defensive backstop, not a provisioning system)
- Cookie domain rewriting for arbitrary TLDs (hardcoded to `.mereka.io`, `.biji-biji.com`, `.mereka.dev`)
- OAuth provider discovery automation (the middleware fixes presentation, not discovery)
- Full Prometheus exporter implementation (delegates to `django-prometheus` library)

## Requirements

### Functional

#### Middleware Stack Order

The middleware stack MUST execute in the following order (earliest to latest in `MIDDLEWARE` list):

1. `django_prometheus.middleware.PrometheusBeforeMiddleware` (if django-prometheus enabled)
2. `MerekaForwardedHeadersMiddleware` (normalize proxy headers before Django reads them)
3. `MerekaCookieDomainMiddleware` (patch Sites framework and rewrite response cookies)
4. (Django core middleware)
5. `MerekaPlatformAdminMiddleware` (escalate admin users if authenticated)
6. `mfe_oauth_fix.middleware.MFEOAuthFixMiddleware` (intercept `/api/mfe_context` responses)
7. `django_prometheus.middleware.PrometheusAfterMiddleware` (if django-prometheus enabled)

#### MerekaPlatformAdminMiddleware (AC-001 to AC-003)

- The middleware MUST read the `MEREKA_PLATFORM_ADMIN_EMAILS` environment variable as a comma-separated list of email addresses.
- Email matching MUST be case-insensitive and whitespace-tolerant.
- If an authenticated user's email matches the list, the middleware MUST set `is_active=True`, `is_staff=True`, `is_superuser=True` if any of those flags are not already set.
- The middleware MUST save the user model with `update_fields=["is_active", "is_staff", "is_superuser"]` to avoid overwriting unrelated fields.
- The middleware MUST only modify user attributes on mismatches (it MUST NOT call `save()` on every request for admin users).
- The middleware MUST NOT block the request or return a response (it always calls `self.get_response(request)`).

#### MerekaCookieDomainMiddleware (AC-004 to AC-008)

- The middleware MUST monkey-patch `django.contrib.sites.models.SiteManager.get_current()` to prefer host-based site resolution when a `request` object is provided.
- The patch MUST be idempotent (guarded by a `_PATCHED` global and `_mereka_patched` attribute check).
- The middleware MUST strip port numbers from `request.get_host()` before domain matching.
- The middleware MUST map subdomains (`apps.`, `studio.`, `preview.`) to their parent tenant domain for site lookup.
- The middleware MUST use environment variables (`MEREKA_LMS_DOMAIN`, `MEREKA_LMS_BASE_URL`, `LMS_HOST`, `MEREKA_BIJI_DOMAIN`, `MEREKA_SKILLOURFUTURE_DOMAIN`) as fallback candidates when `SITE_ID` points to a missing row.
- The middleware MUST rewrite `sessionid`, `csrftoken`, `edx-jwt-cookie-header-payload`, and `user-info` cookies to use the tenant-appropriate domain.
- For `*.biji-biji.com` hosts, the middleware MUST set `domain=.biji-biji.com` (not the full subdomain).
- For `localhost` or `*.localhost` hosts, the middleware MUST remove the `domain` attribute (host-only cookies).
- For all other tenant domains (e.g., `academyv2.mereka.io`), the middleware MUST set `domain=.<tenant>` (e.g., `.academyv2.mereka.io`).

#### MerekaForwardedHeadersMiddleware (AC-009 to AC-012)

- The middleware MUST normalize `HTTP_X_FORWARDED_PROTO`, `HTTP_X_FORWARDED_PORT`, and `HTTP_X_FORWARDED_HOST` headers by taking the left-most value if comma-separated.
- The middleware MUST parse the `HTTP_CF_VISITOR` JSON header and extract the `scheme` field to set `HTTP_X_FORWARDED_PROTO` if present.
- If the request path is `/metrics` and `HTTP_HOST` is a pod IP address (pattern: `\d{1,3}(\.\d{1,3}){3}(:\d+)?`), the middleware MUST rewrite `HTTP_HOST` to `MEREKA_LMS_DOMAIN` to bypass Django's `ALLOWED_HOSTS` check.
- For hosts ending in `.mereka.io`, `.biji-biji.com`, or `.mereka.dev`, the middleware MUST force `HTTP_X_FORWARDED_PROTO=https` if the current value is empty, `None`, or `http`.
- The middleware MUST lowercase normalized header values for `X-Forwarded-Proto` and `X-Forwarded-Host`.
- The middleware MUST NOT block the request or return a response (it always calls `self.get_response(request)`).

#### MFE OAuth Fix Custom App (AC-013 to AC-016)

- The middleware MUST intercept responses from requests where `request.path.startswith('/api/mfe_context')`.
- The middleware MUST only process responses with `status_code=200` and `Content-Type` containing `application/json`.
- If the `contextData.providers` array is empty, the middleware MUST query `OAuth2ProviderConfig.objects.filter(site=current_site, enabled=True, visible=True)` to fetch OAuth providers.
- For each provider, the middleware MUST construct a provider object with keys: `id`, `name`, `loginUrl`, `registerUrl`, and optionally `iconClass` and `iconImage`.
- If a provider's `slug`, `name`, or `backend_name` contains the substring `"authentik"` (case-insensitive), the middleware MUST set the display name to `"Mereka"`.
- The middleware MUST encode the updated JSON response and update `response.content` and `Content-Length` header.
- The middleware MUST log actions at `INFO` level via the `mfe_oauth_fix.middleware` logger.
- The middleware MUST NOT raise exceptions that propagate to the client (catch all exceptions, log errors, return original response on failure).

**Note**: MFE footer component is defined in `specs/branding-system_spec.md`. This spec handles OAuth provider normalization only.

#### openedx_prometheus Custom App (AC-017 to AC-018)

- The app MUST be added to `INSTALLED_APPS` after `django_prometheus`.
- The app MUST provide a `urls.py` module that imports `django_prometheus.exports.ExportToDjangoView` and maps it to the root path (`path('', ...)`).
- The `/metrics` URL MUST be mounted in both LMS and CMS URL configurations (e.g., `path('metrics', include('openedx_prometheus.urls'))`).
- The app MUST expose Prometheus metrics in text format (content type: `text/plain; version=0.0.4; charset=utf-8`).
- The app MUST NOT implement custom middleware (it relies on `django_prometheus.middleware.PrometheusBeforeMiddleware` and `PrometheusAfterMiddleware` configured separately).

#### Installation and Patching

- All three middleware modules MUST be deployed to `/openedx/edx-platform/lms/envs/` in the Docker image.
- Both custom apps MUST be copied to `/openedx/<app_name>/` in the Docker image.
- The `apply-patches.sh` script MUST inject middleware imports and configuration into LMS production settings (`tutor_env/env/apps/openedx/settings/lms/production.py`).
- The script MUST add `MIDDLEWARE` entries in the correct order as specified above.
- The script MUST add custom apps to `INSTALLED_APPS`.
- The script MUST inject URL patterns for `/metrics` endpoint.
- The script MUST set `MEREKA_PLATFORM_ADMIN_EMAILS` environment variable via K8s ConfigMap or Secret.

### Non-Functional Requirements

#### Performance

- Each middleware MUST add less than 2ms of latency to the request-response cycle (p95).
- The MFEOAuthFixMiddleware MUST only parse JSON for `/api/mfe_context` requests (not all requests).
- The Sites framework monkey-patch MUST cache site lookups to avoid repeated database queries within the same request.
- The Prometheus middleware MUST NOT cause memory leaks (relies on django-prometheus's internal metrics cleanup).

#### Security

- The MerekaPlatformAdminMiddleware MUST NOT auto-escalate users whose emails do not match the configured list.
- The middleware MUST NOT expose the list of admin emails in error messages or logs.
- The MFEOAuthFixMiddleware MUST NOT include OAuth client secrets in the JSON response (only provider metadata).
- The `/metrics` endpoint MUST NOT include sensitive user data (only aggregate counters and latencies).
- The Prometheus endpoint SHOULD be accessible only within the cluster (not exposed via public Ingress).
- Cookie domain rewriting MUST NOT allow cookies to be shared across unrelated domains (e.g., `.mereka.io` cookies MUST NOT be sent to `.biji-biji.com`).

#### Availability

- Middleware failures MUST NOT break the request (if a middleware component crashes, the request MUST still proceed with default Django behavior).
- The MFEOAuthFixMiddleware MUST return the original response if database queries fail.
- The Sites framework patch MUST fall back to `settings.SITE_ID` if host-based lookup fails.
- The Prometheus middleware MUST gracefully handle missing `django-prometheus` dependency (app provides fallback empty `urlpatterns`).

#### Observability

- All middleware SHOULD log actions at `INFO` level for successful operations (e.g., "Auto-escalated user@example.com to staff/superuser").
- All middleware SHOULD log errors at `ERROR` level with stack traces (`exc_info=True`).
- The MFEOAuthFixMiddleware MUST log the number of providers injected and the current site ID.
- The Prometheus app MUST expose metrics about the middleware stack itself (request counts, latencies).

## Acceptance Criteria

### MerekaPlatformAdminMiddleware

- [ ] AC-001: Given an authenticated user with email in `MEREKA_PLATFORM_ADMIN_EMAILS` but `is_staff=False`, when a request is processed, then the middleware sets `is_staff=True` and calls `user.save()`.
- [ ] AC-002: Given an authenticated user with email in `MEREKA_PLATFORM_ADMIN_EMAILS` and `is_staff=True`, when a request is processed, then the middleware does not call `user.save()`.
- [ ] AC-003: Given an authenticated user with email NOT in `MEREKA_PLATFORM_ADMIN_EMAILS`, when a request is processed, then the middleware does not modify `is_staff`, `is_superuser`, or `is_active`.

### MerekaCookieDomainMiddleware

- [ ] AC-004: Given a request to `apps.academyv2.mereka.io`, when the response sets a `sessionid` cookie, then the cookie's `domain` attribute is `.academyv2.mereka.io`.
- [ ] AC-005: Given a request to `academy.biji-biji.com`, when the response sets a `sessionid` cookie, then the cookie's `domain` attribute is `.biji-biji.com`.
- [ ] AC-006: Given a request to `apps.academy.biji-biji.com`, when the response sets a `sessionid` cookie, then the cookie's `domain` attribute is `.biji-biji.com` (not `.apps.academy.biji-biji.com`).
- [ ] AC-007: Given a request to `localhost:8000`, when the response sets a `sessionid` cookie, then the cookie has no `domain` attribute (host-only).
- [ ] AC-008: Given `Site.objects.get_current(request)` is called with a request to `apps.academyv2.mereka.io`, when the Sites table has a row with `domain="academyv2.mereka.io"`, then the middleware returns that Site row.

### MerekaForwardedHeadersMiddleware

- [ ] AC-009: Given a request with `X-Forwarded-Proto: https,http`, when the middleware processes it, then `request.META['HTTP_X_FORWARDED_PROTO']` is `"https"`.
- [ ] AC-010: Given a request with `CF-Visitor: {"scheme":"https"}`, when the middleware processes it, then `request.META['HTTP_X_FORWARDED_PROTO']` is `"https"`.
- [ ] AC-011: Given a request to `/metrics` with `Host: 10.97.0.2:8000`, when the middleware processes it, then `request.META['HTTP_HOST']` is rewritten to `MEREKA_LMS_DOMAIN`.
- [ ] AC-012: Given a request to `https://academyv2.mereka.io` with no `X-Forwarded-Proto` header, when the middleware processes it, then `request.META['HTTP_X_FORWARDED_PROTO']` is forced to `"https"`.

### MFE OAuth Fix

- [ ] AC-013: Given a request to `/api/mfe_context` that returns `{"contextData": {"providers": []}}`, when the middleware processes it, then the response includes a non-empty `providers` array with OAuth provider data.
- [ ] AC-014: Given an `OAuth2ProviderConfig` with `slug="oidc"` and `name="Authentik"`, when the middleware injects it, then the provider's `name` field is `"Mereka"`.
- [ ] AC-015: Given a request to `/api/mfe_context` that returns `{"contextData": {"providers": [{"name": "Authentik", "id": "oa2-oidc"}]}}`, when the middleware processes it, then the provider's `name` is rewritten to `"Mereka"`.
- [ ] AC-016: Given a request to `/api/user/v1/me`, when the middleware processes it, then the response is not modified (middleware only intercepts `/api/mfe_context`).

### openedx_prometheus

- [ ] AC-017: Given the LMS is running with `openedx_prometheus` in `INSTALLED_APPS`, when a request to `/metrics` is made, then the response is HTTP 200 with content type `text/plain`.
- [ ] AC-018: Given the `/metrics` endpoint, when Prometheus scrapes it, then metrics include `django_http_requests_total_by_method`, `django_http_requests_latency_seconds`, and `django_db_query_duration_seconds`.

### Feature Flags

- [ ] AC-019: The MerekaPlatformAdminMiddleware MUST be enabled only when `MEREKA_PLATFORM_ADMIN_EMAILS` environment variable is non-empty.
- [ ] AC-020: The openedx_prometheus app SHOULD be conditionally loaded based on whether `django-prometheus` is installed (graceful degradation if missing).

## Edge Cases

### Admin Email Collision

**Symptom**: Two users have the same email address (platform admin and a regular learner with admin's email via profile field).

**Cause**: Django allows duplicate emails in non-primary fields (profile fields, social auth emails).

**Recovery**: The middleware matches on `user.email` (the official User model field), not profile fields. If two users have the same `user.email`, Django's authentication will reject them at login. This is a database integrity issue, not a middleware issue.

### Cookie Domain Leakage

**Symptom**: Cookies set on `academyv2.mereka.io` are sent to `academy.biji-biji.com`.

**Cause**: Incorrect domain mapping in middleware.

**Recovery**: The middleware hardcodes two separate root domains (`.mereka.io` variants and `.biji-biji.com`). Cookies CANNOT leak across these roots because they are disjoint. If leakage occurs, the browser is violating RFC 6265.

### Prometheus Scrape Failures

**Symptom**: Prometheus scraper reports `400 DisallowedHost` errors.

**Cause**: The middleware's pod IP rewrite is not triggered (wrong path, pattern mismatch, or Prometheus scraping via LoadBalancer IP).

**Recovery**:
```bash
# Verify the rewrite logic
kubectl exec -n mereka-lms deploy/lms -- curl -s http://127.0.0.1:8000/metrics | head
# Should return metrics, not DisallowedHost error

# Check Prometheus ServiceMonitor targets
kubectl get servicemonitor -n mereka-lms -o yaml | grep path
# Should show path: /metrics
```

### Empty OAuth Providers After Middleware Injection

**Symptom**: Login page still shows no providers after the middleware runs.

**Cause**: The middleware successfully injects providers into the API response, but the MFE frontend does not re-fetch the data (cache staleness).

**Recovery**:
```bash
# Clear browser cache and hard-refresh (Ctrl+Shift+R)
# Verify the API response directly
curl -s https://academyv2.mereka.io/api/mfe_context | jq '.contextData.providers'
# Should show providers array

# Check MFE logs for client-side errors
kubectl logs -n mereka-lms -l app.kubernetes.io/name=mfe --tail=50
```

### Sites Framework Patch Race Condition

**Symptom**: Intermittent `Site matching query does not exist` errors.

**Cause**: The monkey-patch is applied in `MerekaCookieDomainMiddleware.__init__()`, which may be called multiple times in multi-worker setups.

**Recovery**: The patch is idempotent (guarded by `if _PATCHED: return` and `_mereka_patched` attribute). If race conditions occur, add a threading lock around the patch block.

### Middleware Order Violation

**Symptom**: Cookies have wrong domains, or HTTPS detection fails.

**Cause**: Middleware is not ordered correctly in `MIDDLEWARE` list.

**Recovery**:
```bash
# Verify middleware order
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "from django.conf import settings; print('\\n'.join(settings.MIDDLEWARE))"
# MUST show MerekaForwardedHeadersMiddleware before SecurityMiddleware
# MUST show MerekaCookieDomainMiddleware before other middleware
```

## Observability

### Logs

- Middleware actions SHOULD be logged to the LMS/CMS application logs with logger names:
  - `mereka.platform_admin` (admin escalations)
  - `mereka.multisite` (cookie domain rewrites, site lookups)
  - `mereka.forwarded_headers` (header normalization, /metrics rewrites)
  - `mfe_oauth_fix.middleware` (OAuth provider injection)
  - `openedx_prometheus` (metrics endpoint errors)
- Log messages MUST include relevant context (user email for admin escalations, host for cookie rewrites, path for /metrics rewrites).
- Error logs MUST include stack traces (`logger.error(..., exc_info=True)`).

### Metrics

- The Prometheus app SHOULD expose the following custom metrics:
  - `mereka_platform_admin_escalations_total` (counter of admin privilege escalations)
  - `mereka_cookie_domain_rewrites_total` (counter of cookie domain rewrites, labeled by tenant)
  - `mereka_forwarded_header_normalizations_total` (counter of header normalizations)
  - `mereka_mfe_oauth_injections_total` (counter of provider array injections)
- The `django_http_requests_total_by_view` metric SHOULD show `/metrics` endpoint requests.

### Alerts

- An alert SHOULD fire if `django_http_responses_total_by_status{status="400"}` spikes on `/metrics` endpoint (indicates pod IP rewrite failure).
- An alert SHOULD fire if `mereka_mfe_oauth_injections_total` counter does not increment for 24 hours (indicates OAuth fix middleware is broken or `/api/mfe_context` is not being called).

### Dashboards

- A Grafana dashboard panel SHOULD display:
  - Request latency histogram for each middleware component
  - Error rate by middleware component
  - Admin escalation events (time-series)
  - OAuth injection success rate

## Rollout & Rollback

### Adding a New Admin Email

```bash
# 1. Update ConfigMap
kubectl edit configmap lms-config -n mereka-lms
# Add email to MEREKA_PLATFORM_ADMIN_EMAILS (comma-separated)

# 2. Restart LMS to pick up new config
kubectl rollout restart deployment/lms -n mereka-lms

# 3. Verify
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=100 | grep "Auto-escalated"
```

### Adding a New Tenant Domain

```bash
# 1. Edit middleware source
vim deploy/k8s/base/apps/openedx/settings/lms/mereka_multisite.py
# Add new domain to _env_site_domain_candidates() and _cookie_policy_for_host()

# 2. Apply patches and rebuild
./infrastructure/tutor/apply-patches.sh
tutor images build openedx

# 3. Deploy
kubectl set image deployment/lms -n mereka-lms lms=<new-image>
```

### Disabling a Middleware Component

```bash
# 1. Edit LMS production settings
vim deploy/k8s/base/apps/openedx/settings/lms/production.py
# Comment out middleware import and MIDDLEWARE entry

# 2. Apply
kubectl apply -f deploy/k8s/base/apps/openedx/settings/
kubectl rollout restart deployment/lms -n mereka-lms
```

### Rollback to Default Behavior

```bash
# 1. Remove middleware imports from settings
# 2. Rebuild image without patches
tutor images build openedx

# 3. Deploy
tutor k8s restart lms cms
```

## Verification

```bash
# 1. Verify middleware is loaded
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c \
  "from django.conf import settings; print('\\n'.join(settings.MIDDLEWARE))"
# MUST show MerekaPlatformAdminMiddleware, MerekaCookieDomainMiddleware, MerekaForwardedHeadersMiddleware

# 2. Verify admin escalation
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=500 | grep -i "platform admin"

# 3. Verify cookie domain rewrite
curl -I -H "Host: apps.academyv2.mereka.io" http://localhost/login
# Set-Cookie header MUST include Domain=.academyv2.mereka.io

# 4. Verify X-Forwarded-Proto normalization
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c \
  "from django.test import RequestFactory; from mereka_forwarded_headers import MerekaForwardedHeadersMiddleware; \
   rf = RequestFactory(); req = rf.get('/'); req.META['HTTP_X_FORWARDED_PROTO'] = 'https,http'; \
   mw = MerekaForwardedHeadersMiddleware(lambda r: None); mw(req); \
   print(req.META['HTTP_X_FORWARDED_PROTO'])"
# MUST output: https

# 5. Verify OAuth provider injection
curl -s https://academyv2.mereka.io/api/mfe_context | jq '.contextData.providers'
# MUST show non-empty array with "Mereka" provider

# 6. Verify Prometheus metrics endpoint
kubectl exec -n mereka-lms deploy/lms -- curl -s http://127.0.0.1:8000/metrics | head -20
# MUST show django_http_requests_total_by_method and other metrics

# 7. Verify custom apps in INSTALLED_APPS
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c \
  "from django.conf import settings; print([app for app in settings.INSTALLED_APPS if 'mfe_oauth_fix' in app or 'openedx_prometheus' in app])"
# MUST show ['mfe_oauth_fix', 'openedx_prometheus']
```

## Open Questions

1. ~~Should the MerekaPlatformAdminMiddleware apply to CMS as well as LMS?~~ **RESOLVED**: Yes. Keep deployed to both via shared production settings. CMS admin needs the same platform-level controls (audit logging, rate limiting). No reason to diverge.
2. ~~Should the Sites framework patch be extracted to a separate middleware component or remain in MerekaCookieDomainMiddleware?~~ **RESOLVED**: Remain in MerekaCookieDomainMiddleware. Extraction adds a component without benefit; the patch is 10 lines and tightly coupled to cookie domain logic.
3. ~~Should the cookie domain rewriting support wildcards or regex patterns for future multi-tenant expansion?~~ **RESOLVED**: No wildcards/regex. Use explicit domain list from SiteConfiguration. Wildcards introduce security risks (cookie scope too broad). Each tenant domain added explicitly via Tutor config + apply-patches.sh.
4. ~~Should the MFEOAuthFixMiddleware cache OAuth provider queries for performance?~~ **RESOLVED**: Yes. Cache OAuth provider lookup in Django per-request cache (request-scoped, not global). Eliminates repeated DB queries on `/api/mfe_context`. Implementation: `functools.lru_cache` with request lifecycle invalidation.
5. ~~Should the Prometheus `/metrics` endpoint require authentication via bearer token or IP whitelist?~~ **RESOLVED**: IP whitelist via K8s NetworkPolicy. Only allow scraping from Prometheus pod CIDR. No bearer token needed for in-cluster access. External access blocked by default.
6. ~~Should we add a health check endpoint (`/health`) that verifies all middleware is loaded correctly?~~ **RESOLVED**: No separate `/health` endpoint. Use existing `/heartbeat` (liveness) and `/readyz` (readiness) endpoints per cross-cutting-requirements_spec.md. Middleware loading verified by the application startup health check.
7. ~~How should we handle middleware version skew when rolling out new images?~~ **RESOLVED**: Rolling update (K8s default). Middleware is backward-compatible by design (no breaking changes between versions). Blue/green adds operational complexity not justified for middleware updates.
