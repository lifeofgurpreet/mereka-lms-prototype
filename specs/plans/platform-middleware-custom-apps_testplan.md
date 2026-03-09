---
spec: platform-middleware-custom-apps_spec.md
tier: 2
status: draft
last_updated: '2026-02-10'
test_framework: shell_verification (bash + Django shell + HTTP requests)
plan: platform-middleware-custom-apps_plan.md
---

# Test Plan: Platform Middleware and Custom Apps

**Source Spec**: `specs/platform-middleware-custom-apps_spec.md`
**Plan**: `specs/plans/platform-middleware-custom-apps_plan.md`

## Test Strategy

This spec governs Django middleware components and custom apps deployed inside the Open edX LMS/CMS containers. Most acceptance criteria require a running Django environment to verify runtime behavior. Test types used:

| Test Type | Description | Requires Cluster |
|-----------|-------------|------------------|
| `shell_verification` | Django shell script that imports middleware, constructs mock requests, verifies behavior | Yes (Django env) |
| `http_request` | HTTP request to live LMS/CMS with specific headers/paths, validates response | Yes |
| `unit_test` | Python unittest using Django RequestFactory, mock responses | No (local venv) |
| `manual_verification` | Human-performed check with documented steps | Yes |
| `ci_workflow` | GitHub Actions workflow step | No (if synthetic) |

**Key challenge**: Most middleware behavior requires a running cluster with Django loaded. We provide two test layers:

1. **Synthetic unit tests** (RequestFactory + mocks) -- can run locally in venv
2. **Runtime verification scripts** (exec into pod + Django shell) -- requires Kind or GKE cluster

---

## Test Matrix

### MerekaPlatformAdminMiddleware (AC-001, AC-002, AC-003)

| AC | Test Case | Type | File / Command | Fixtures / Notes |
|----|-----------|------|----------------|------------------|
| AC-001 | Given authenticated user with email in MEREKA_PLATFORM_ADMIN_EMAILS but is_staff=False, when request is processed, then middleware sets is_staff=True and saves user | shell_verification | `scripts/qa/verify-middleware-stack.sh --check admin-escalation` | Requires Django shell, creates test user, simulates request |
| AC-001 | (Unit test) RequestFactory + mock user object, verify user.save() called with update_fields | unit_test | `tests/middleware/test_platform_admin.py::test_admin_escalation` | Local venv, no cluster |
| AC-001 | (Negative) User with email NOT matching MEREKA_PLATFORM_ADMIN_EMAILS is not escalated | unit_test | `tests/middleware/test_platform_admin.py::test_non_admin_not_escalated` | Synthetic |
| AC-002 | Given user with is_staff=True already, when request is processed, then middleware does not call user.save() | shell_verification | `scripts/qa/verify-middleware-stack.sh --check admin-no-duplicate-save` | Requires Django shell + log inspection |
| AC-002 | (Unit test) Mock user with is_staff=True, verify save() not called | unit_test | `tests/middleware/test_platform_admin.py::test_no_duplicate_save` | Synthetic |
| AC-003 | Given authenticated user with email NOT in MEREKA_PLATFORM_ADMIN_EMAILS, when request is processed, then middleware does not modify is_staff, is_superuser, is_active | shell_verification | `scripts/qa/verify-middleware-stack.sh --check admin-non-admin-user` | Django shell test |
| AC-003 | (Unit test) Mock regular user, verify no attributes modified | unit_test | `tests/middleware/test_platform_admin.py::test_regular_user_unchanged` | Synthetic |

### MerekaCookieDomainMiddleware (AC-004 through AC-008)

| AC | Test Case | Type | File / Command | Fixtures / Notes |
|----|-----------|------|----------------|------------------|
| AC-004 | Given request to apps.academyv2.mereka.io, when response sets sessionid cookie, then cookie domain is .academyv2.mereka.io | http_request | `scripts/qa/verify-middleware-stack.sh --check cookie-domain-mereka` | Live LMS, curl -I https://apps.academyv2.mereka.io/login |
| AC-004 | (Unit test) RequestFactory with Host: apps.academyv2.mereka.io, verify response Set-Cookie | unit_test | `tests/middleware/test_cookie_domain.py::test_cookie_domain_mereka` | Mock response with cookies |
| AC-005 | Given request to academy.biji-biji.com, then cookie domain is .biji-biji.com | http_request | `scripts/qa/verify-middleware-stack.sh --check cookie-domain-biji` | Live LMS, curl |
| AC-005 | (Unit test) RequestFactory with Host: academy.biji-biji.com | unit_test | `tests/middleware/test_cookie_domain.py::test_cookie_domain_biji` | Synthetic |
| AC-006 | Given request to apps.academy.biji-biji.com, then cookie domain is .biji-biji.com (not subdomain) | http_request | `scripts/qa/verify-middleware-stack.sh --check cookie-domain-biji-subdomain` | Live LMS |
| AC-006 | (Unit test) Verify subdomain stripping logic | unit_test | `tests/middleware/test_cookie_domain.py::test_biji_subdomain_stripping` | Synthetic |
| AC-007 | Given request to localhost:8000, then cookie has no domain attribute (host-only) | http_request | `scripts/qa/verify-middleware-stack.sh --check cookie-domain-localhost` | Local Tutor dev mode |
| AC-007 | (Unit test) RequestFactory with Host: localhost:8000 | unit_test | `tests/middleware/test_cookie_domain.py::test_cookie_domain_localhost` | Synthetic |
| AC-008 | Given Site.objects.get_current(request) with request to apps.academyv2.mereka.io, when Sites table has academyv2.mereka.io row, then middleware returns that Site | shell_verification | `scripts/qa/verify-middleware-stack.sh --check sites-framework-patch` | Django shell: from django.contrib.sites.models import Site; rf = RequestFactory(); req = rf.get('/'); req.META['HTTP_HOST'] = 'apps.academyv2.mereka.io'; Site.objects.get_current(req) |
| AC-008 | (Negative) Missing Site row falls back to settings.SITE_ID | shell_verification | Manual: delete Site row, verify fallback | Staging cluster |
| AC-008 | (Unit test) Mock Site.objects.get() with DoesNotExist, verify fallback | unit_test | `tests/middleware/test_cookie_domain.py::test_sites_fallback` | Synthetic |

### MerekaForwardedHeadersMiddleware (AC-009 through AC-012)

| AC | Test Case | Type | File / Command | Fixtures / Notes |
|----|-----------|------|----------------|------------------|
| AC-009 | Given request with X-Forwarded-Proto: https,http, when middleware processes it, then request.META['HTTP_X_FORWARDED_PROTO'] is "https" | shell_verification | `scripts/qa/verify-middleware-stack.sh --check forwarded-proto-normalize` | Django shell: RequestFactory + middleware call |
| AC-009 | (Unit test) Mock request with multi-valued header, verify left-most value extracted | unit_test | `tests/middleware/test_forwarded_headers.py::test_proto_normalize` | Synthetic |
| AC-010 | Given request with CF-Visitor: {"scheme":"https"}, then X-Forwarded-Proto is "https" | shell_verification | `scripts/qa/verify-middleware-stack.sh --check cf-visitor-parse` | Django shell |
| AC-010 | (Unit test) Mock CF-Visitor JSON parsing | unit_test | `tests/middleware/test_forwarded_headers.py::test_cf_visitor` | Synthetic |
| AC-011 | Given request to /metrics with Host: 10.97.0.2:8000, when middleware processes it, then Host is rewritten to MEREKA_LMS_DOMAIN | shell_verification | `scripts/qa/verify-middleware-stack.sh --check metrics-host-rewrite` | Django shell: req.path = '/metrics'; req.META['HTTP_HOST'] = '10.97.0.2:8000'; middleware(req); assert req.META['HTTP_HOST'] != pod IP |
| AC-011 | (Unit test) Mock /metrics request with pod IP | unit_test | `tests/middleware/test_forwarded_headers.py::test_metrics_host_rewrite` | Synthetic |
| AC-011 | (HTTP test) Prometheus scrape from pod IP succeeds | http_request | `kubectl exec -n mereka-lms deploy/lms -- curl -s http://127.0.0.1:8000/metrics` | Live cluster |
| AC-012 | Given request to https://academyv2.mereka.io with no X-Forwarded-Proto, then X-Forwarded-Proto forced to "https" | shell_verification | `scripts/qa/verify-middleware-stack.sh --check forwarded-proto-force-https` | Django shell |
| AC-012 | (Unit test) Mock request with empty X-Forwarded-Proto, .mereka.io host | unit_test | `tests/middleware/test_forwarded_headers.py::test_force_https` | Synthetic |

### MFE OAuth Fix (AC-013 through AC-016)

| AC | Test Case | Type | File / Command | Fixtures / Notes |
|----|-----------|------|----------------|------------------|
| AC-013 | Given /api/mfe_context returns {"contextData": {"providers": []}}, when middleware processes it, then response includes non-empty providers array | http_request | `scripts/qa/verify-custom-apps.sh --check mfe-oauth-inject-empty` | Live LMS: curl -s https://academyv2.mereka.io/api/mfe_context \| jq '.contextData.providers' |
| AC-013 | (Unit test) Mock empty providers response, inject OAuth providers from database | unit_test | `tests/custom_apps/test_mfe_oauth_fix.py::test_inject_providers` | Requires mocked OAuth2ProviderConfig queryset |
| AC-014 | Given OAuth2ProviderConfig with slug="oidc" and name="Authentik", then provider name is "Mereka" | http_request | `scripts/qa/verify-custom-apps.sh --check mfe-oauth-rename-authentik` | Live LMS |
| AC-014 | (Unit test) Mock OAuth provider with "authentik" in name, verify renaming | unit_test | `tests/custom_apps/test_mfe_oauth_fix.py::test_rename_authentik` | Synthetic |
| AC-015 | Given /api/mfe_context with existing Authentik provider, then name is rewritten to "Mereka" | http_request | `scripts/qa/verify-custom-apps.sh --check mfe-oauth-rewrite-existing` | Live LMS |
| AC-015 | (Unit test) Mock non-empty providers array with Authentik entry | unit_test | `tests/custom_apps/test_mfe_oauth_fix.py::test_rewrite_existing_providers` | Synthetic |
| AC-016 | Given request to /api/user/v1/me, then response is not modified (middleware only intercepts /api/mfe_context) | http_request | `scripts/qa/verify-custom-apps.sh --check mfe-oauth-path-filter` | Live LMS: curl /api/user/v1/me, verify no provider field injection |
| AC-016 | (Unit test) Mock request to non-matching path, verify passthrough | unit_test | `tests/custom_apps/test_mfe_oauth_fix.py::test_path_filter` | Synthetic |

### openedx_prometheus (AC-017, AC-018)

| AC | Test Case | Type | File / Command | Fixtures / Notes |
|----|-----------|------|----------------|------------------|
| AC-017 | Given LMS running with openedx_prometheus in INSTALLED_APPS, when request to /metrics, then HTTP 200 with content-type text/plain | http_request | `scripts/qa/verify-custom-apps.sh --check prometheus-metrics-endpoint` | Live LMS: curl -I http://127.0.0.1:8000/metrics |
| AC-017 | (Negative) /metrics with invalid Prometheus scrape format is rejected | http_request | Manual: Prometheus ServiceMonitor with wrong path | Live cluster |
| AC-018 | Given /metrics endpoint, when Prometheus scrapes it, then metrics include django_http_requests_total_by_method, django_http_requests_latency_seconds, django_db_query_duration_seconds | http_request | `scripts/qa/verify-custom-apps.sh --check prometheus-metrics-content` | Live LMS: curl http://127.0.0.1:8000/metrics \| grep django_http |
| AC-018 | (Unit test) Verify openedx_prometheus.urls imports ExportToDjangoView | unit_test | `tests/custom_apps/test_openedx_prometheus.py::test_urls_config` | Import check |

### Feature Flags (AC-019, AC-020)

| AC | Test Case | Type | File / Command | Fixtures / Notes |
|----|-----------|------|----------------|------------------|
| AC-019 | Given MEREKA_PLATFORM_ADMIN_EMAILS is empty, when LMS starts, then MerekaPlatformAdminMiddleware is not loaded | shell_verification | `scripts/qa/verify-middleware-stack.sh --check admin-feature-flag` | Django shell: check MIDDLEWARE list |
| AC-019 | (Unit test) Mock settings with empty MEREKA_PLATFORM_ADMIN_EMAILS | unit_test | `tests/middleware/test_platform_admin.py::test_feature_flag_disabled` | Synthetic |
| AC-020 | Given django-prometheus is not installed, when LMS starts, then openedx_prometheus provides empty urlpatterns | manual_verification | Manual: uninstall django-prometheus, verify LMS starts without error | Staging cluster |
| AC-020 | (Unit test) Mock missing django-prometheus import | unit_test | `tests/custom_apps/test_openedx_prometheus.py::test_graceful_degradation` | Synthetic |

---

## Edge Case Tests

These correspond to the Edge Cases section of the spec. Most are verified by monitoring or manual procedures.

| Edge Case | Test Case | Type | File / Command | Notes |
|-----------|-----------|------|----------------|-------|
| EC-01: Admin email collision | Two users with same email (Django prevents at login) | manual_verification | Manual: create duplicate email users, verify authentication rejection | Staging |
| EC-02: Cookie domain leakage | Cookies set on academyv2.mereka.io are NOT sent to academy.biji-biji.com | http_request | `scripts/qa/verify-middleware-stack.sh --check cookie-isolation` | Browser DevTools + live LMS |
| EC-03: Prometheus scrape failures | DisallowedHost errors if middleware rewrite fails | http_request | `kubectl logs -n mereka-lms deploy/lms \| grep DisallowedHost` | Live cluster |
| EC-04: Empty OAuth providers after middleware injection | API response verified directly, MFE cache cleared | http_request | `curl -s https://academyv2.mereka.io/api/mfe_context \| jq '.contextData.providers'` | Live LMS |
| EC-05: Sites framework patch race condition | Idempotency check prevents duplicate patching | unit_test | `tests/middleware/test_cookie_domain.py::test_patch_idempotency` | Synthetic: call patch multiple times |
| EC-06: Middleware order violation | Verify middleware order in MIDDLEWARE list | shell_verification | `scripts/qa/verify-middleware-order.sh` | Django shell: from django.conf import settings; print(settings.MIDDLEWARE) |

---

## Integration Tests

These tests verify end-to-end behavior across multiple middleware components.

| Test Case | Type | File / Command | Notes |
|-----------|------|----------------|-------|
| Full login flow with cookie domain rewrite | http_request | `scripts/qa/qa-smoke.sh --test login-flow-multi-domain` | Live LMS: login via apps.academyv2.mereka.io, verify sessionid domain, access studio.academyv2.mereka.io, verify session persists |
| OAuth login with Authentik provider renaming | http_request | `scripts/qa/qa-smoke.sh --test oauth-login-mereka` | Live LMS: visit /login, verify "Mereka" button present, click, verify OAuth flow |
| Prometheus scrape from pod IP with header rewrite | http_request | `kubectl exec -n mereka-lms deploy/lms -- curl -s http://127.0.0.1:8000/metrics \| wc -l` | Verify >100 lines of metrics |
| Admin escalation after privilege revocation | manual_verification | Manual: revoke staff privilege via Django admin, log out, log back in as admin email, verify staff restored | Staging |

---

## CI Integration

Add these checks to `.github/workflows/ci.yml`:

```yaml
- name: Verify Middleware Order
  run: scripts/qa/verify-middleware-order.sh

- name: Run Middleware Unit Tests
  run: |
    source .venv/bin/activate
    pytest tests/middleware/ tests/custom_apps/ -v

- name: Verify Middleware Stack (requires cluster)
  if: env.CI_CLUSTER_AVAILABLE == 'true'
  run: scripts/qa/verify-middleware-stack.sh

- name: Verify Custom Apps (requires cluster)
  if: env.CI_CLUSTER_AVAILABLE == 'true'
  run: scripts/qa/verify-custom-apps.sh
```

---

## Performance Testing

The spec requires <2ms latency per middleware (p95). Performance tests:

| Test | Type | File / Command | Notes |
|------|------|----------------|-------|
| Middleware latency baseline (all middleware disabled) | http_request | `scripts/qa/benchmark-middleware.sh --baseline` | Apache Bench: ab -n 1000 -c 10 https://academyv2.mereka.io/ |
| Middleware latency with stack enabled | http_request | `scripts/qa/benchmark-middleware.sh --with-middleware` | Same ab command, compare latencies |
| MFEOAuthFixMiddleware database query count | shell_verification | Django debug toolbar or django-silk profiling | Live LMS: visit /api/mfe_context, verify query count |

---

## Self-Check

- [x] Every AC (001-020) has at least one test case
- [x] Edge cases from spec have test cases (EC-01 through EC-06)
- [x] Test types appropriate for each case (unit_test for synthetic, http_request for runtime)
- [x] File paths specified for all verification scripts
- [x] Fixtures/notes explain what is needed for each test
- [x] Source spec linked in header
- [x] Integration tests cover multi-component interactions
- [x] Performance testing strategy defined
