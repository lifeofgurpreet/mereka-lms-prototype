# Troubleshooting

<!-- Last verified: 2026-02-13 -->

Quick diagnostics and fixes for common Mereka LMS issues.

## Site Down? Start Here (5-Command Diagnostic)

```bash
# 1. Are pods running?
kubectl get pods -n mereka-lms

# 2. CRITICAL: Empty endpoints = no traffic
kubectl get endpoints -n mereka-lms

# 3. LoadBalancer status
kubectl get svc caddy -n mereka-lms

# 4. Recent pod events
kubectl describe pods -n mereka-lms -l app.kubernetes.io/name=lms | tail -30

# 5. LMS logs
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=50
```

Most common cause: **service selector mismatches** after pod restarts.
Quick fix: `./scripts/infra/fix-service-selectors.sh`

---

## Studio SSO Login

**Symptom**: Can't log into Studio, or Studio login redirects to LMS dashboard instead of completing the Studio OAuth flow.

**Cause**: The MFE authn page loses the `next` query parameter when fetching `/api/third_party_auth_context` for SSO providers. When Studio initiates OAuth login (`/login?next=/oauth2/authorize?client_id=cms-sso&...`), the MFE replaces the `next` value with `/dashboard`, so after OIDC login the user lands on the dashboard instead of completing the OAuth authorize flow back to Studio.

**Fix**: `StudioSSOBypassMiddleware` (see [ADR-013](../adr/013-studio-sso-bypass-middleware.md)) detects `/login?next=/oauth2/authorize` requests and redirects directly to `/auth/login/oidc/` with the correct `next` parameter, bypassing the MFE authn page entirely for service-to-service OAuth flows.

**Verification**:
```bash
./scripts/qa/verify-studio-sso-flow.sh
```

**If middleware is missing**: Check that `production-prod.py` (bbi-infrastructure LMS settings overlay) contains `StudioSSOBypassMiddleware` in the `MIDDLEWARE` list. The middleware should be at index 1 (after forwarded-headers hardening).

**Manual check**:
```bash
# Should redirect to /auth/login/oidc/ (NOT apps.academyv2.mereka.io/authn)
curl -sS -o /dev/null -w '%{redirect_url}' \
  'https://academyv2.mereka.io/login?next=/oauth2/authorize%3Fclient_id%3Dcms-sso'
```

---

## MFE White Screen / Login Issues

See [`MFE_LOGIN_FIX.md`](MFE_LOGIN_FIX.md) for MFE-specific login issues (white screen, missing authn MFE).

## Ecommerce OAuth 500

See [`ECOMMERCE_OAUTH_TROUBLESHOOTING.md`](ECOMMERCE_OAUTH_TROUBLESHOOTING.md) for Ecommerce OAuth client configuration issues.

## Cloud IPs in Local Config

**Symptom**: Local services fail to connect (MySQL, MongoDB, Redis timeouts).

**Cause**: `tutor_env/config.yml` contains cloud IPs (`10.97.x.x`) instead of local service names.

**Fix**:
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/tutor-config-save.sh \
  --set MYSQL_HOST=mysql \
  --set MONGODB_HOST=mongodb \
  --set REDIS_HOST=redis \
  --set MONGODB_PORT=27017
tutor local restart
```

## Empty Kubernetes Endpoints

**Symptom**: Site returns 502/503 but pods are running.

**Cause**: Service selectors don't match pod labels after a restart or redeployment.

**Fix**:
```bash
# Check for empty endpoints
kubectl get endpoints -n mereka-lms

# Auto-fix selector mismatches
./scripts/infra/fix-service-selectors.sh
```

## Tenant Branding Runtime Verification

**Symptom**: Runtime branding verification script reports failures or unexpected SITE_NAME values.

**Common false positives:**

1. **Cache TTL (5-minute Redis cache)**
   - Wait 5 minutes after config change before re-running verification
   - Clear cache: `tutor k8s exec lms -- ./manage.py lms shell -c "from django.core.cache import cache; cache.clear()"`

2. **DNS propagation**
   - New domains may take up to 30 minutes to resolve
   - Verify DNS: `dig +short skillourfuture.academy.mereka.io`

3. **MFE config endpoint returns default when ENABLE_MULTI_TENANT_BRANDING=False**
   - Expected behavior: all checks will SKIP with message "Runtime not available"
   - Enable in Tutor config: `tutor config save --set ENABLE_MULTI_TENANT_BRANDING=true`

4. **Caddy routing**
   - Verify domain is in Caddyfile: `grep skillourfuture deploy/k8s/base/apps/caddy/Caddyfile`
   - Restart Caddy: `kubectl rollout restart deployment/caddy -n mereka-lms`

**Known edge cases:**

- **skillourfuture.academy.mereka.io requires multi-level subdomain SSL setup**
  - See `docs/operations/MULTI_LEVEL_SUBDOMAIN_SSL.md` (if exists) or `docs/architecture/DOMAIN_SSL_MANAGEMENT.md`
  - Cloudflare Free SSL only covers `*.mereka.io`, NOT `*.*.mereka.io`
  - Use DNS-only (gray cloud) + Let's Encrypt via cert-manager

- **Footer variants depend on window.location.hostname matching**
  - If accessed via IP or proxy, variant falls back to default
  - Verify: `curl -H "Host: academy.biji-biji.com" https://academyv2.mereka.io/api/mfe_config/v1 | grep SITE_NAME`

**Verification script:**
```bash
# Check runtime branding for production
./scripts/qa/verify-tenant-branding-runtime.sh --env prod

# Check local development
./scripts/qa/verify-tenant-branding-runtime.sh --env local

# Manual MFE config check
curl -s https://academyv2.mereka.io/api/mfe_config/v1 | grep -E 'SITE_NAME|LOGO_URL|--mereka-color'
```
