---
title: "Multi-Site Domain Configuration"
type: "feature_spec"
id: "SPEC-MULTI-SITE-DOMAINS"
status: "approved"
owner: "engineering"
vehicle: "talent_platform"
spec_class: "system"
created: "2026-01-22"
last_updated: "2026-02-18"
last_reviewed: "2026-03-09"
review_due: "2026-06-09"
version: "1.0.0"
domain: "tenancy"
normativity: "normative"
depends_on:
  - "specs/repository-structure_spec.md"
  - "specs/secrets-management_spec.md"
  - "specs/tutor-configuration_spec.md"
supersedes: []
superseded_by: null
verification_sources:
  - "scripts/qa/run-spec-integrity-gates.sh"
  - "scripts/qa/spec-tools/spec_coverage_report.py"
interfaces:
  - "django-sites"
  - "caddy-host-routing"
  - "mfe-config-surface"
tags:
  - "tenant.lifecycle"
  - "tenant.isolation"
  - "auth.cookie-boundary"
  - "platform.control-plane"
summary: "Defines the required domain, host-routing, site-configuration, and environment contract for multi-site Open edX deployments."
links:
  related_docs:
    - "docs/reference/operations/OPENEDX_HOSTNAMES.md"
    - "docs/ops/runbooks/TROUBLESHOOTING.md"
    - "docs/reference/operations/AUTH_AND_PERMISSIONS.md"
    - "docs/guides/branding/BRANDING_OPERATING_MODEL.md"
    - "docs/guides/admin/K8S_OPERATIONS_GUIDE.md"
  related_specs:
    - "specs/k8s-deployment_spec.md"
    - "specs/branding-system_spec.md"
    - "specs/tutor-configuration_spec.md"
    - "specs/auth-sso-enterprise_spec.md"
    - "specs/multi-tenancy-architecture_spec.md"
    - "specs/cross-cutting-requirements_spec.md"
---

# Human Summary

## What we're building

Multi-site domain support for Mereka Academy, enabling the Open edX LMS to serve learners across three distinct production domains: the primary `academyv2.mereka.io`, the partner-branded `academy.biji-biji.com`, and the program-specific `skillourfuture.academy.mereka.io`. Each domain must resolve to the same LMS instance with correct CSRF protection, cookie scoping, cross-domain authentication, and reverse proxy routing.

## Why it matters

Mereka Academy operates under multiple organizational brands (Mereka, Biji-Biji Initiative, SkillOurFuture). Learners and partners access the platform through domain names they recognize and trust. If CSRF tokens are rejected, cookies are mis-scoped, or reverse proxy headers are wrong, users experience login failures, session loss, or broken API calls -- all of which erode trust and block learning. A precise domain configuration contract prevents these failures from recurring after every Tutor config regeneration cycle.

## Success looks like

- All three production domains serve the LMS with zero CSRF or session errors for 7 consecutive days after rollout.
- Cross-subdomain session sharing works between `academyv2.mereka.io` and `apps.academyv2.mereka.io` without re-login.
- Partner domain `academy.biji-biji.com` operates with an independent session, no cookie leakage from the primary domain.
- Adding or removing a domain follows a documented, repeatable procedure that completes in under 30 minutes.

# Agent Contract

## Scope

- In scope:
  - Django `ALLOWED_HOSTS` and `CSRF_TRUSTED_ORIGINS` configuration for all domains
  - Session and CSRF cookie domain scoping
  - SiteConfiguration runtime records reconciled from the multisite registry
  - OIDC provider configuration contract
  - Nginx (LMS backend) and Caddy (K8s ingress) reverse proxy rules
  - Domain addition and removal procedures
- Out of scope:
  - SSL certificate management (handled by Cloudflare/Let's Encrypt)
  - DNS configuration (managed in infrastructure/cloudflare/)
  - Load balancing (handled by GKE Ingress/Caddy)

## Non-goals

- SSL certificate management (handled by Cloudflare/Let's Encrypt)
- DNS configuration (managed in infrastructure/cloudflare/)
- Load balancing (handled by GKE Ingress/Caddy)

## Requirements

### Production Domains

The system MUST support the following domains:

| Domain | Purpose | MFE Subdomain |
|--------|---------|---------------|
| `academyv2.mereka.io` | Primary LMS | `apps.academyv2.mereka.io` |
| `academy.biji-biji.com` | Partner branding | `apps.academy.biji-biji.com` |
| `skillourfuture.academy.mereka.io` | Program-specific | N/A (shares primary MFE via `apps.academyv2.mereka.io`) |

### Django Settings

- The system MUST add all domains to `ALLOWED_HOSTS` in LMS settings
- The system MUST add all HTTPS origins to `CSRF_TRUSTED_ORIGINS`
- The system MUST set `DEFAULT_SITE_THEME = "mereka"` for consistent branding

### Cookie Configuration

- The system MUST set `SESSION_COOKIE_DOMAIN = None` (host-only) so cookies work on all root domains
- The system MUST set `CSRF_COOKIE_DOMAIN = None` (host-only) so CSRF tokens work on all root domains
- Cross-subdomain session sharing between `academyv2.mereka.io` and `apps.academyv2.mereka.io` is handled by Caddy proxying `/login_refresh` and `/api/mfe_config/v1` to LMS with the original Host header preserved
- The system SHOULD NOT set a static cookie domain (e.g., `.academyv2.mereka.io`) because it is invalid on `academy.biji-biji.com` and browsers will drop the cookie

### SiteConfiguration

- The system MUST reconcile a SiteConfiguration for each domain from the multisite registry via `scripts/infra/apply-multisite-config.sh`
- Each SiteConfiguration MUST specify the correct domain name
- Each SiteConfiguration SHOULD override branding if domain-specific customization is needed

### OIDC Provider Contract

- The latest `OAuth2ProviderConfig` for `backend_name=oidc` MUST be enabled and visible.
- The latest provider config MUST resolve a non-empty effective secret (`get_setting("SECRET")`).
- The default provider display label MUST be `Mereka` (the authn MFE prepends "Sign in with").

### Reverse Proxy

#### Nginx (LMS Backend)

- MUST add all domains to `server_name` directive in `apps/nginx/lms.conf`
- MUST proxy `/profile/api/*` requests from MFE subdomain to LMS with correct Host header

#### Caddy (K8s Ingress)

- MUST define separate server blocks for each domain
- MUST rewrite `/favicon.ico` to `/theming/asset/images/favicon.ico`
- MUST limit profile image uploads to 1MB
- MUST set general request body limit to 4MB

### Non-Functional Requirements

- All domain endpoints MUST respond with HTTP 200 within 2 seconds (p95) under normal load
- CSRF validation failure rate MUST remain below 0.5% of total requests per domain
- Session cookie propagation between subdomains MUST succeed on first navigation (zero re-login required)
- Domain addition or removal procedure SHOULD complete in under 30 minutes including verification
- The system SHOULD maintain 99.9% availability across all configured domains (measured monthly)
- Caddy request body limits (1MB profile images, 4MB general) MUST be enforced without silent truncation

## Acceptance Criteria

- [ ] AC-001: All three domains resolve to the LMS
- [ ] AC-002: Login on `academyv2.mereka.io` persists session when navigating to `apps.academyv2.mereka.io`
- [ ] AC-003: Login on `academy.biji-biji.com` works independently (separate session)
- [ ] AC-004: CSRF tokens are accepted from all three domains
- [ ] AC-005: `/api/mfe_config/v1` returns correct `LMS_BASE_URL` for each domain
- [ ] AC-006: Studio is accessible at `studio.academyv2.mereka.io` only
- [ ] AC-007: Profile image upload from MFE succeeds
- [ ] AC-008: Favicon loads correctly on all domains
- [ ] AC-009: `./scripts/qa/verify-oidc-provider-configs.sh --env prod` passes (enabled/visible + non-empty effective secret + provider label contract)

## Edge Cases

### Cookie Domain Mismatch

**Symptom**: Login succeeds but session lost when navigating to MFE subdomain

**Cause**: `SESSION_COOKIE_DOMAIN` not set or set to wrong value

**Recovery**:
```bash
# Verify cookie domain at runtime
kubectl exec -n mereka-lms deploy/lms -- \
  python manage.py lms shell -c "from django.conf import settings; print(settings.SESSION_COOKIE_DOMAIN)"

# Should show: None
# If wrong, fix the LMS settings source, merge, and redeploy the affected image
```

### CSRF Token Rejection

**Symptom**: API calls from MFE fail with 403 Forbidden CSRF validation

**Cause**: MFE domain not in `CSRF_TRUSTED_ORIGINS`

**Recovery**:
```bash
# Check CSRF origins
grep CSRF_TRUSTED_ORIGINS tutor_env/env/apps/openedx/settings/lms/production.py

# Should include:
# - https://academyv2.mereka.io
# - https://apps.academyv2.mereka.io
# - https://academy.biji-biji.com
# - https://apps.academy.biji-biji.com
# - https://skillourfuture.academy.mereka.io
```

### Reverse Proxy Host Header

**Symptom**: `/profile/api/` requests return 404 when called from MFE

**Cause**: Reverse proxy not setting correct Host header

**Recovery**:
```nginx
# In apps/nginx/lms.conf — MUST preserve original Host for SiteConfiguration resolution
location ^~ /profile/api/ {
    proxy_set_header Host $http_host;  # NOT hardcoded — preserves original domain
    proxy_redirect off;
    proxy_pass http://lms-backend;
}
```

### CORS Headers

**Symptom**: Browser blocks cross-origin requests from MFE subdomain

**Cause**: MFE subdomain needs CORS allowlist configuration

**Recovery**: Add to LMS settings via Tutor patch:
```python
CORS_ORIGIN_WHITELIST.append('apps.academyv2.mereka.io')
```

## Observability

### Logs

- LMS request logs: `tutor local logs lms | grep "GET /api/"`
- Nginx access logs: `tutor local logs nginx | grep "domain.com"`
- CSRF validation errors: `tutor local logs lms | grep CSRF`

### Metrics

- Request count by domain: Group by `http_host` header
- Session creation rate per domain
- CSRF validation failure rate

### Alerts

- SHOULD alert if any domain returns 5xx errors for >1 minute
- SHOULD alert if CSRF validation failures exceed 5% of requests

## Rollout & Rollback

### Adding a New Domain

```bash
# 1. Add the tenant/domain to the multisite registry
# Edit infrastructure/tutor/multisite-sites.yml

# 2. Update host acceptance / CSRF sources in repo-owned config
# (apply-patches/plugin registry changes as needed)

# 3. Merge the source-of-truth change

# 4. Reconcile Site + SiteConfiguration runtime state
CONFIRM_APPLY_MULTISITE_CONFIG=APPLY_MULTISITE_CONFIG \
ALLOW_PROD_APPLY=1 \
./scripts/infra/apply-multisite-config.sh --env prod --apply
```

### Removing a Domain

```bash
# 1. Remove the domain from the multisite registry / host-acceptance sources

# 2. Merge the source-of-truth change

# 3. Reconcile runtime Site + SiteConfiguration from source of truth
CONFIRM_APPLY_MULTISITE_CONFIG=APPLY_MULTISITE_CONFIG \
ALLOW_PROD_APPLY=1 \
./scripts/infra/apply-multisite-config.sh --env prod --apply
```

### Rollback

If multi-site config breaks primary domain:

1. Revert the multisite source-of-truth change in git
2. Merge the rollback under the merge-first protocol
3. Re-run `./scripts/infra/apply-multisite-config.sh --env prod --apply`
4. Verify primary domain works: `curl -I https://academyv2.mereka.io`

## Resolved Questions

1. **Separate SiteConfiguration per domain**: YES — each domain has its own SiteConfiguration runtime record, reconciled from `infrastructure/tutor/multisite-sites*.yml` via `scripts/infra/apply-multisite-config.sh`, enabling per-domain `SITE_NAME`, `LMS_BASE_URL`, and `MFE_BASE_URL` overrides.
2. **Domain-specific branding**: Handled via `MerekaFooter` SITE_VARIANTS (runtime hostname → brand mapping) and per-tenant values reconciled into SiteConfiguration from the canonical multisite registry. Logo/colors share the `mereka` theme; text/footer vary by domain.
3. **Biji-biji.com branding**: Same `mereka` theme, but MerekaFooter shows "Biji-Biji Academy" brand text and "Biji-Biji Initiative" copyright. See `infrastructure/tutor/plugins/mereka_lms.py` SITE_VARIANTS.
4. **Separate analytics**: NOT YET — all domains share a single analytics pipeline. Domain-based segmentation can be added later via `http_host` grouping in Prometheus metrics.
5. **Domain-based rate limiting**: NOT YET — rate limiting is applied globally. Per-domain limits can be added via Caddy `rate_limit` directive if needed.
