---
title: "Multi-Site Domain Configuration"
type: "feature_spec"
status: "completed"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-10"
depends_on:
  - "specs/repository-structure_spec.md"
  - "specs/secrets-management_spec.md"
  - "specs/tutor-configuration_spec.md"
links:
  related_docs:
    - "docs/operations/OPENEDX_HOSTNAMES.md"
    - "docs/operations/TROUBLESHOOTING.md"
    - "docs/operations/AUTH_AND_PERMISSIONS.md"
    - "docs/branding/BRANDING_OPERATING_MODEL.md"
    - "docs/operations/K8S_OPERATIONS_GUIDE.md"
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
  - SiteConfiguration records in Django admin
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
| `academy.biji-biji.com` | Partner branding | N/A (shares primary MFE) |
| `skillourfuture.academy.mereka.io` | Program-specific | N/A (shares primary MFE) |

### Django Settings

- The system MUST add all domains to `ALLOWED_HOSTS` in LMS settings
- The system MUST add all HTTPS origins to `CSRF_TRUSTED_ORIGINS`
- The system MUST set `DEFAULT_SITE_THEME = "mereka"` for consistent branding

### Cookie Configuration

- The system MUST set `SESSION_COOKIE_DOMAIN = ".academyv2.mereka.io"` for cross-subdomain sessions
- The system MUST set `CSRF_COOKIE_DOMAIN = ".academyv2.mereka.io"` for CSRF protection
- The system SHOULD NOT set domain-specific cookies for biji-biji.com (different root domain)

### SiteConfiguration

- The system MUST create a SiteConfiguration for each domain in Django admin
- Each SiteConfiguration MUST specify the correct domain name
- Each SiteConfiguration SHOULD override branding if domain-specific customization is needed

### OIDC Provider Contract

- The latest `OAuth2ProviderConfig` for `backend_name=oidc` MUST be enabled and visible.
- The latest provider config MUST resolve a non-empty effective secret (`get_setting("SECRET")`).
- The default provider display label MUST remain `Sign in with Mereka`.

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
# Verify cookie domain in config
grep SESSION_COOKIE_DOMAIN tutor_env/config.yml

# Should show: SESSION_COOKIE_DOMAIN: ".academyv2.mereka.io"
# If missing, add via Tutor patch and restart
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
# - https://skillourfuture.academy.mereka.io
```

### Reverse Proxy Host Header

**Symptom**: `/profile/api/` requests return 404 when called from MFE

**Cause**: Reverse proxy not setting correct Host header

**Recovery**:
```nginx
# In apps/nginx/lms.conf
location ^~ /profile/api/ {
    proxy_set_header Host academyv2.mereka.io;
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
# 1. Add to Tutor config (via patch)
# Edit infrastructure/tutor/apply-patches.sh
# Add domain to extra_lms_hosts and extra_csrf_origins

# 2. Apply patches
./infrastructure/tutor/apply-patches.sh

# 3. Rebuild images (picks up nginx/caddy config)
tutor images build openedx

# 4. Restart services
tutor k8s restart

# 5. Create SiteConfiguration in Django admin
# Navigate to /admin/site_configuration/siteconfiguration/
# Create entry with domain name and enabled=True
```

### Removing a Domain

```bash
# 1. Disable in Django admin
# Set SiteConfiguration enabled=False

# 2. Remove from apply-patches.sh
# Delete from extra_lms_hosts and extra_csrf_origins

# 3. Apply patches and restart
./infrastructure/tutor/apply-patches.sh
tutor k8s restart
```

### Rollback

If multi-site config breaks primary domain:

1. Remove custom domains from `extra_lms_hosts` in `apply-patches.sh`
2. Re-run patches: `./infrastructure/tutor/apply-patches.sh`
3. Restart: `tutor k8s restart`
4. Verify primary domain works: `curl -I https://academyv2.mereka.io`

## Open Questions

1. Should we use separate SiteConfiguration for each domain or share one?
2. How do we handle domain-specific branding overrides (logos, colors)?
3. Should biji-biji.com users see Mereka branding or custom Biji-Biji branding?
4. Do we need separate analytics tracking for each domain?
5. Should we implement domain-based rate limiting?
