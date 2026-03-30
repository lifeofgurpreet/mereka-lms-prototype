# Multi-Site Domain Operations Guide
_Audience: Operations & Developers • Owner: Infra Team • Last updated: 2026-02-11_

**Purpose**: Manage multi-domain configuration for Mereka Academy Open edX platform.

**TL;DR**: 3 production domains (`academyv2.mereka.io`, `academy.biji-biji.com`, `skillourfuture.academy.mereka.io`) route to same LMS instance. Cross-subdomain sessions for primary domain, independent sessions for partner domains. CSRF + OIDC + Caddy routing must be configured correctly.

---

## Domain Overview

### Production Domains

| Domain | Purpose | Session Scope | MFE Subdomain |
|--------|---------|---------------|---------------|
| `academyv2.mereka.io` | Primary LMS | `.academyv2.mereka.io` (shared with MFE) | `apps.academyv2.mereka.io` |
| `academy.biji-biji.com` | Biji-Biji Initiative partner branding | Independent (no subdomain sharing) | Uses primary MFE |
| `skillourfuture.academy.mereka.io` | SkillOurFuture program | Independent | Uses primary MFE |

### Studio Domain

**Studio** (CMS): `studio.academyv2.mereka.io` only (no multi-domain for Studio)

### Key Constraints

- **Cross-subdomain sessions**: Login at `academyv2.mereka.io` persists to `apps.academyv2.mereka.io` (same root domain)
- **Independent partner sessions**: `academy.biji-biji.com` has separate session cookie (different root domain)
- **Single backend**: All domains route to same LMS/CMS Pods
- **CSRF protection**: All domains in `CSRF_TRUSTED_ORIGINS`, cookies scoped correctly

---

## Configuration

### Django Settings

**Required in LMS settings** (`deploy/k8s/base/apps/openedx/settings/lms/mereka_multisite.py`):

```python
# All domains must be allowed
ALLOWED_HOSTS = [
    "academyv2.mereka.io",
    "academy.biji-biji.com",
    "skillourfuture.academy.mereka.io",
    "apps.academyv2.mereka.io",  # MFE
]

# HTTPS origins for CSRF validation
CSRF_TRUSTED_ORIGINS = [
    "https://academyv2.mereka.io",
    "https://academy.biji-biji.com",
    "https://skillourfuture.academy.mereka.io",
    "https://apps.academyv2.mereka.io",
]

# Cookie domain for cross-subdomain sessions (primary only)
SESSION_COOKIE_DOMAIN = ".academyv2.mereka.io"
CSRF_COOKIE_DOMAIN = ".academyv2.mereka.io"

# Default theme
DEFAULT_SITE_THEME = "mereka"
```

**Verify settings**:
```bash
kubectl exec -it -n mereka-lms deployment/lms -- python manage.py lms shell -c "
from django.conf import settings
print('ALLOWED_HOSTS:', settings.ALLOWED_HOSTS)
print('CSRF_TRUSTED_ORIGINS:', settings.CSRF_TRUSTED_ORIGINS)
print('SESSION_COOKIE_DOMAIN:', settings.SESSION_COOKIE_DOMAIN)
"
```

### Caddy Configuration

**Caddyfile location**: `infrastructure/tutor/patches/caddyfile`

**Required per domain**:
```
academyv2.mereka.io {
    import mereka-lms-common
    reverse_proxy http://lms:8000
    rewrite /favicon.ico /theming/asset/images/favicon.ico
    request_body {
        max_size 4MB  # General requests
    }
    @profile_image {
        path /api/profile_images/*/*
    }
    request_body @profile_image {
        max_size 1MB  # Profile images
    }
}

academy.biji-biji.com {
    import mereka-lms-common
    reverse_proxy http://lms:8000
    rewrite /favicon.ico /theming/asset/images/favicon.ico
    request_body {
        max_size 4MB
    }
}

skillourfuture.academy.mereka.io {
    import mereka-lms-common
    reverse_proxy http://lms:8000
    rewrite /favicon.ico /theming/asset/images/favicon.ico
    request_body {
        max_size 4MB
    }
}
```

**Apply Caddy changes**:
```bash
# After modifying Caddyfile patch
./infrastructure/tutor/apply-patches.sh
kubectl rollout restart deployment/caddy -n mereka-lms
```

### OIDC Provider

**Contract** (per spec):
- Latest `OAuth2ProviderConfig` with `backend_name=oidc` must be enabled and visible
- Must resolve non-empty effective secret (`get_setting("SECRET")`)
- Provider label: `Mereka` (authn MFE prepends "Sign in with")

**Verify**:
```bash
./scripts/qa/verify-oidc-provider-configs.sh --env prod
```

Checks:
- ✅ Enabled and visible
- ✅ Non-empty secret
- ✅ Correct label

---

## Common Operations

### Adding a New Domain

**When**: New partner program or organizational rebrand.

**Prerequisites**:
- DNS record created (A or CNAME)
- TLS certificate provisioned (Cloudflare/Let's Encrypt)

**Steps**:

1. **Update Django settings** (`deploy/k8s/base/apps/openedx/settings/lms/mereka_multisite.py`):
   ```python
   ALLOWED_HOSTS += ["newdomain.example.com"]
   CSRF_TRUSTED_ORIGINS += ["https://newdomain.example.com"]
   ```

2. **Update Caddyfile** (`infrastructure/tutor/patches/caddyfile`):
   ```
   newdomain.example.com {
       import mereka-lms-common
       reverse_proxy http://lms:8000
       rewrite /favicon.ico /theming/asset/images/favicon.ico
       request_body {
           max_size 4MB
       }
   }
   ```

3. **Apply patches**:
   ```bash
   ./infrastructure/tutor/apply-patches.sh
   ```

4. **Update K8s Ingress** (`deploy/k8s/overlays/production/ingress-openedx-lms.yaml`):
   ```yaml
   spec:
     rules:
       - host: newdomain.example.com
         http:
           backend:
             service:
               name: caddy
               port:
                 number: 80
     tls:
       - hosts:
           - newdomain.example.com
         secretName: newdomain-tls
   ```

5. **Commit and reconcile**:
   - Commit the ingress / domain contract change and let GitOps reconcile production.
   - Do not use `kubectl apply -k` or `kubectl rollout restart` as the normal production path.
   - Watch the rollout after reconciliation:
     ```bash
     kubectl rollout status deployment/lms -n mereka-lms
     kubectl rollout status deployment/cms -n mereka-lms
     kubectl rollout status deployment/caddy -n mereka-lms
     ```

6. **Reconcile Site + SiteConfiguration** (canonical path):
   - Record the new tenant in the multisite source data.
   - Run `./scripts/tenants/provision-tenant.sh newdomain.example.com "New Domain"` if the tenant bootstrap record does not exist yet.
   - Run `./scripts/infra/apply-multisite-config.sh` to reconcile `Site` and `SiteConfiguration`.
   - Do not create `Site` / `SiteConfiguration` manually in Django admin for the normal path.

7. **Verify**:
   ```bash
   curl -I https://newdomain.example.com
   # Should return 200 OK

   ./scripts/qa/verify-csrf-multisite.sh
   # Should pass for new domain
   ```

**Timeline**: ~30 minutes

### Removing a Domain

**When**: Partner program ends, domain deprecation.

**Steps**:

1. **Remove from Django settings**:
   - Remove from `ALLOWED_HOSTS`
   - Remove from `CSRF_TRUSTED_ORIGINS`

2. **Remove from Caddyfile**:
   - Delete domain block

3. **Apply patches and restart**:
   ```bash
   ./infrastructure/tutor/apply-patches.sh
   kubectl rollout restart deployment/lms deployment/caddy -n mereka-lms
   ```

4. **Remove from K8s Ingress**:
   - Remove host from ingress rules
   - Remove from TLS section

5. **Reconcile Site + SiteConfiguration removal** (canonical path):
   - Remove or disable the tenant in the multisite source data
   - Run `./scripts/infra/apply-multisite-config.sh`
   - Do not disable `SiteConfiguration` manually in Django admin for the normal path

6. **Update DNS** (last step):
   - Remove A/CNAME record (prevents access)

### Session Testing

**Test cross-subdomain sessions** (primary domain):
```bash
# Login at main domain
curl -c cookies.txt -X POST https://academyv2.mereka.io/login \
  -d "email=test@example.com&password=testpass"

# Verify session at MFE subdomain
curl -b cookies.txt https://apps.academyv2.mereka.io/api/user/v1/me
# Should return user data (session persists)
```

**Test independent partner session**:
```bash
# Login at biji-biji domain
curl -c cookies-bb.txt -X POST https://academy.biji-biji.com/login \
  -d "email=test@example.com&password=testpass"

# Verify session does NOT work at primary domain
curl -b cookies-bb.txt https://academyv2.mereka.io/api/user/v1/me
# Should return 401 (different session domain)
```

---

## Troubleshooting

### CSRF Token Rejected

**Symptom**: `403 Forbidden` with "CSRF verification failed" message.

**Causes**:

1. **Domain not in `CSRF_TRUSTED_ORIGINS`**:
   ```bash
   # Verify settings
   kubectl exec -it -n mereka-lms deployment/lms -- \
     python manage.py lms shell -c "from django.conf import settings; print(settings.CSRF_TRUSTED_ORIGINS)"

   # If missing, add to mereka_multisite.py and restart
   ```

2. **Missing HTTPS prefix**:
   ```python
   # ❌ Wrong
   CSRF_TRUSTED_ORIGINS = ["academyv2.mereka.io"]

   # ✅ Correct
   CSRF_TRUSTED_ORIGINS = ["https://academyv2.mereka.io"]
   ```

3. **Cookie domain mismatch**:
   ```bash
   # Check cookie domain in browser DevTools → Application → Cookies
   # Should match SESSION_COOKIE_DOMAIN setting
   ```

**Fix**:
```bash
./scripts/qa/verify-csrf-multisite.sh
# Identifies which domains are not properly configured
```

### Session Lost on Subdomain Navigation

**Symptom**: Login at `academyv2.mereka.io` works, but navigating to `apps.academyv2.mereka.io` prompts for login again.

**Cause**: `SESSION_COOKIE_DOMAIN` not set or wrong value.

**Fix**:
```python
# Must be set in LMS settings
SESSION_COOKIE_DOMAIN = ".academyv2.mereka.io"  # Leading dot important!
CSRF_COOKIE_DOMAIN = ".academyv2.mereka.io"
```

**Verify**:
```bash
# Check browser DevTools → Application → Cookies
# Cookie should show Domain: .academyv2.mereka.io (not exact domain)
```

### 404 Not Found for Partner Domain

**Symptom**: `academy.biji-biji.com` returns 404.

**Possible causes**:

1. **Missing Caddy server block**:
   ```bash
   kubectl get configmap -n mereka-lms caddy-config -o yaml | grep -A 10 "academy.biji-biji.com"
   # Should show server block
   ```

2. **Missing Ingress rule**:
   ```bash
   kubectl get ingress -n mereka-lms -o yaml | grep "academy.biji-biji.com"
   # Should appear in hosts list
   ```

3. **DNS not pointing to cluster**:
   ```bash
   nslookup academy.biji-biji.com
   # Should resolve to GKE LoadBalancer IP
   ```

**Fix**: Follow "Adding a New Domain" procedure above.

### Profile Image Upload Fails

**Symptom**: `413 Request Entity Too Large`

**Cause**: Caddy body limit too small.

**Fix**: Verify Caddy config has profile image exception:
```
@profile_image {
    path /api/profile_images/*/*
}
request_body @profile_image {
    max_size 1MB
}
```

**Apply**:
```bash
./infrastructure/tutor/apply-patches.sh
kubectl rollout restart deployment/caddy -n mereka-lms
```

---

## Verification

### All Domains Accessible

```bash
for domain in academyv2.mereka.io academy.biji-biji.com skillourfuture.academy.mereka.io; do
  echo "Testing $domain..."
  curl -I -s https://$domain | head -1
done
# All should return: HTTP/2 200
```

### CSRF Protection

```bash
./scripts/qa/verify-csrf-multisite.sh
```

Checks each domain:
- ✅ CSRF token present in response
- ✅ Token accepted on form submission
- ✅ Cross-domain token rejected

### Session Persistence

```bash
# Manual test: Login at academyv2.mereka.io
# Navigate to apps.academyv2.mereka.io
# Should NOT prompt for re-login

# Automated:
./scripts/qa/verify-session-persistence.sh
```

### OIDC Configuration

```bash
./scripts/qa/verify-oidc-provider-configs.sh --env prod
```

Must pass all 3 checks:
- ✅ Enabled and visible
- ✅ Non-empty effective secret
- ✅ Provider label = "Mereka"

---

## Related Resources

**Spec**: `specs/multi-site-domains_spec.md` (9 ACs, 100% complete)

**Operations Docs**:
- `docs/reference/operations/OPENEDX_HOSTNAMES.md` - Complete hostname registry
- `docs/ops/runbooks/DOMAIN_CHANGE_RUNBOOK.md` - Domain change procedures
- `docs/ops/runbooks/DOMAIN_MANAGEMENT.md` - DNS management
- `docs/reference/operations/AUTH_AND_PERMISSIONS.md` - OIDC and auth config

**Scripts**:
- `scripts/qa/verify-csrf-multisite.sh` - CSRF validation
- `scripts/qa/verify-oidc-provider-configs.sh` - OIDC verification
- `scripts/qa/verify-session-persistence.sh` - Session testing
- `scripts/qa/verify-multisite-config.sh` - Full multi-site check

**Configuration Files**:
- `deploy/k8s/base/apps/openedx/settings/lms/mereka_multisite.py` - Django settings
- `infrastructure/tutor/patches/caddyfile` - Caddy reverse proxy config
- `deploy/k8s/overlays/production/ingress-openedx-lms.yaml` - K8s Ingress rules

**Branding**:
- `docs/guides/branding/BRANDING.md` - Theme system overview
- Domain-specific branding via canonical multisite config plus governed MFE publish
