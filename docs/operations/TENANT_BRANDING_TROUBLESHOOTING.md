# Tenant Branding Troubleshooting

<!-- Last verified: 2026-02-17 -->

**Audience**: Platform Engineering + Operations
**Purpose**: Diagnose and resolve tenant branding runtime issues
**Related**: `scripts/qa/verify-tenant-branding-runtime.sh`

---

## Overview

This guide covers troubleshooting for the multi-tenant branding system when `ENABLE_MULTI_TENANT_BRANDING=True`. It addresses false positives from the runtime verifier, routing/cache edge cases, and common configuration issues.

**Related documentation**:
- Runtime verifier: `scripts/qa/verify-tenant-branding-runtime.sh`
- Governance gate: `scripts/qa/run-multisite-governance-gates.sh`
- Readiness assessment: `docs/operations/TENANT_BRANDING_READINESS_RAG.md`
- General troubleshooting: `docs/operations/TROUBLESHOOTING.md`

---

## Quick Diagnostic

Run the runtime verifier to check current branding state:

```bash
# Check production
./scripts/qa/verify-tenant-branding-runtime.sh --env prod

# Check local development
./scripts/qa/verify-tenant-branding-runtime.sh --env local

# Check custom target
./scripts/qa/verify-tenant-branding-runtime.sh --target http://localhost:8000
```

**Expected results**:
- **ENABLE_MULTI_TENANT_BRANDING=True**: All checks PASS with domain-specific SITE_NAME, logo URLs, brand colors
- **ENABLE_MULTI_TENANT_BRANDING=False**: All checks SKIP (runtime not available)
- **Configuration errors**: FAIL with diagnostic messages

---

## Scenario 1: False Positives from Runtime Verifier

### Symptom
Runtime verifier reports failures but manual inspection shows correct branding.

### Common Causes

#### 1.1 Cache TTL Delay (5-min Redis Cache)

**Problem**: MFE config API caches results for 5 minutes. After changing tenant branding, the verifier may see stale data.

**Diagnostics**:
```bash
# Check cache TTL
kubectl exec -n mereka-lms -it deploy/lms -- \
  python manage.py shell -c "from openedx_tenant_cache.models import TenantSiteConfiguration; \
  print(TenantSiteConfiguration._CACHE_TTL)"
# Should output: 300 (5 minutes)

# Check current cached value
curl -s https://academyv2.mereka.io/api/mfe_config/v1 | \
  grep -o '"SITE_NAME"[[:space:]]*:[[:space:]]*"[^"]*"'
```

**Fix**: Wait 5 minutes after config change, then re-run verifier.

**Workaround** (development only):
```bash
# Flush Redis cache
kubectl exec -n mereka-lms -it deploy/redis -- redis-cli FLUSHDB
```

**Note**: `MFE_CONFIG_API_CACHE_TIMEOUT=1` (1 second) only affects the MFE config endpoint response caching, NOT the Redis branding cache at `openedx_tenant_cache/branding.py:20`.

---

#### 1.2 DNS Propagation Delays for New Domains

**Problem**: New domains (e.g., `newclient.academy.mereka.io`) may take up to 30 minutes to propagate.

**Diagnostics**:
```bash
# Check DNS resolution
dig +short newclient.academy.mereka.io
# Should return: <Load Balancer IP>

# Test with IP override (bypass DNS)
curl -H "Host: newclient.academy.mereka.io" \
  http://<LB-IP>/api/mfe_config/v1 | grep SITE_NAME
```

**Fix**: Wait for DNS propagation (typically 5-30 minutes for Cloudflare).

**Workaround** (testing only):
```bash
# Add to /etc/hosts for local testing
echo "<LB-IP> newclient.academy.mereka.io" | sudo tee -a /etc/hosts
```

---

#### 1.3 ENABLE_MULTI_TENANT_BRANDING Flag Disabled

**Problem**: Feature flag set to `False` in production, causing all checks to SKIP.

**Diagnostics**:
```bash
# Check Tutor config
export TUTOR_ROOT="$(pwd)/tutor_env"
grep ENABLE_MULTI_TENANT_BRANDING tutor_env/config.yml
# Should show: ENABLE_MULTI_TENANT_BRANDING: true

# Check runtime setting
kubectl exec -n mereka-lms -it deploy/lms -- \
  python manage.py shell -c "from django.conf import settings; \
  print(settings.FEATURES.get('ENABLE_MULTI_TENANT_BRANDING'))"
# Should output: True
```

**Fix**:
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/tutor-config-save.sh \
  --set ENABLE_MULTI_TENANT_BRANDING=True
./infrastructure/tutor/apply-patches.sh
tutor k8s restart
```

---

#### 1.4 Caddy Domain Routing Not Updated

**Problem**: New domain not added to Caddy configuration, causing 404 or fallback to default site.

**Diagnostics**:
```bash
# Check Caddyfile for domain
kubectl exec -n mereka-lms -it deploy/caddy -- cat /etc/caddy/Caddyfile | \
  grep newclient.academy.mereka.io

# Check Caddy logs for routing errors
kubectl logs -n mereka-lms -l app.kubernetes.io/name=caddy --tail=50 | \
  grep newclient.academy.mereka.io
```

**Fix**: Add domain to LMS Caddyfile template at `infrastructure/tutor/templates/apps/openedx/config/caddy/Caddyfile`:

```caddyfile
academyv2.mereka.io, academy.biji-biji.com, skillourfuture.academy.mereka.io, newclient.academy.mereka.io {
  # ... existing config
}
```

Then rebuild and restart:
```bash
tutor config save
./infrastructure/tutor/apply-patches.sh
tutor k8s restart caddy
```

---

## Scenario 2: Routing and Cache Edge Cases

### 2.1 MFE Host Header Passthrough

**Problem**: MFE requests use hardcoded domain instead of client's Host header, causing wrong branding.

**Diagnostics**:
```bash
# Check MFE config API with different Host headers
curl -H "Host: academyv2.mereka.io" \
  https://apps.academyv2.mereka.io/api/mfe_config/v1 | grep SITE_NAME
# Should return: "Mereka Academy"

curl -H "Host: academy.biji-biji.com" \
  https://apps.academyv2.mereka.io/api/mfe_config/v1 | grep SITE_NAME
# Should return: "Biji-Biji Academy"
```

**Expected behavior**: MFE config API uses `request.get_host()` to resolve tenant, NOT the MFE subdomain.

**Fix** (if broken): Ensure Caddy MFE block includes Host header passthrough:

```caddyfile
# In MFE block (apps.academyv2.mereka.io)
reverse_proxy lms:8000 {
  header_up Host {http.request.host}  # CRITICAL: Pass original Host header
}
```

---

### 2.2 SiteConfiguration vs TenantSiteMapping Resolution Order

**Problem**: Legacy `SiteConfiguration` overrides tenant mapping.

**Diagnostics**:
```bash
# Check for conflicting SiteConfiguration
kubectl exec -n mereka-lms -it deploy/lms -- \
  python manage.py shell -c "from django.contrib.sites.models import Site; \
  from openedx.core.djangoapps.site_configuration.models import SiteConfiguration; \
  print('Sites:', list(Site.objects.values('id', 'domain'))); \
  print('Configs:', list(SiteConfiguration.objects.values('site__domain', 'values')))"
```

**Expected**: Only one `SiteConfiguration` per `Site`, with `values={}` (empty) if using multi-tenant branding.

**Fix**: Delete conflicting `SiteConfiguration`:

```bash
kubectl exec -n mereka-lms -it deploy/lms -- \
  python manage.py shell -c "from openedx.core.djangoapps.site_configuration.models import SiteConfiguration; \
  SiteConfiguration.objects.filter(site__domain='academy.biji-biji.com').delete()"
```

**Note**: `TenantResolutionMiddleware` runs AFTER `CurrentSiteMiddleware`, so tenant mapping should take precedence. If it doesn't, check middleware order in `production.py`.

---

### 2.3 Cookie Domain Conflicts

**Problem**: Session cookie with `Domain=.academyv2.mereka.io` causes cross-domain authentication issues.

**Diagnostics**:
```bash
# Check session cookie domain
curl -sI https://academyv2.mereka.io/login | grep Set-Cookie

# Expected (host-only cookies):
# Set-Cookie: sessionid=...; Path=/; HttpOnly; SameSite=Lax
# NOT: Set-Cookie: sessionid=...; Domain=.academyv2.mereka.io
```

**Fix**: Ensure host-only cookies in `production.py`:

```python
SESSION_COOKIE_DOMAIN = None  # Host-only
CSRF_COOKIE_DOMAIN = None     # Host-only
```

**Why**: `.academyv2.mereka.io` cookies are sent to ALL subdomains, causing session collisions between LMS, Studio, and MFE.

---

### 2.4 Footer Variant Mismatch

**Problem**: Footer variant doesn't match domain mapping.

**Diagnostics**:
```bash
# Check footer variant mapping in mereka_lms.py plugin
grep -A 20 "SITE_VARIANTS" infrastructure/tutor/plugins/mereka_lms.py

# Should include all 3 domains:
# 'academyv2.mereka.io': { 'name': 'Mereka Academy', ... }
# 'academy.biji-biji.com': { 'name': 'Biji-Biji Academy', ... }
# 'skillourfuture.academy.mereka.io': { 'name': 'Skill Our Future Academy', ... }
```

**Fix**: Update `SITE_VARIANTS` in `infrastructure/tutor/plugins/mereka_lms.py` and rebuild MFE image:

```bash
tutor images build mfe
tutor k8s restart mfe
```

**Note**: Footer variant resolution uses `window.location.hostname` at runtime, NOT server-side domain mapping.

---

## Scenario 3: Known Issues

### 3.1 Brand Color Tokens Not Found

**Symptom**: Verifier reports "No brand color tokens (--mereka-color-*) found for domain".

**Cause**: MFE config API doesn't include CSS custom properties (tokens are in `tokens.css`, not MFE_CONFIG).

**Expected**: This is a WARN, not a FAIL. Brand color tokens are injected via `tokens.css` at build time, not at runtime.

**Verification**:
```bash
# Check tokens.css in MFE image
kubectl exec -n mereka-lms -it deploy/mfe -- \
  cat /openedx/dist/authn/assets/branding/tokens.css | grep --mereka-color-teal
# Should show: --mereka-color-teal: #2d898b;
```

---

### 3.2 SITE_NAME Mismatch (Footer Variant Contract Broken)

**Symptom**: SITE_NAME is domain-specific but doesn't match expected value from `DOMAIN_TARGETS` mapping.

**Example**:
```
Expected: Mereka Academy
Actual: Mereka Open edX Academy
```

**Cause**: `TenantSiteConfiguration.site_name` doesn't match footer variant mapping.

**Diagnostics**:
```bash
# Check TenantSiteConfiguration
kubectl exec -n mereka-lms -it deploy/lms -- \
  python manage.py shell -c "from openedx_tenant_cache.models import TenantSiteConfiguration; \
  for cfg in TenantSiteConfiguration.objects.all(): \
      print(f'{cfg.domain}: {cfg.site_name}')"
```

**Fix**: Update `TenantSiteConfiguration` to match footer variant:

```bash
kubectl exec -n mereka-lms -it deploy/lms -- \
  python manage.py shell -c "from openedx_tenant_cache.models import TenantSiteConfiguration; \
  cfg = TenantSiteConfiguration.objects.get(domain='academyv2.mereka.io'); \
  cfg.site_name = 'Mereka Academy'; \
  cfg.save()"

# Flush cache
kubectl exec -n mereka-lms -it deploy/redis -- redis-cli FLUSHDB
```

---

### 3.3 Logo URL Contains "openedx"

**Symptom**: LOGO_URL is not domain-specific (still points to default Open edX logo).

**Cause**: Tenant not provisioned with custom logo assets.

**Diagnostics**:
```bash
# Check TenantSiteConfiguration logo_url
kubectl exec -n mereka-lms -it deploy/lms -- \
  python manage.py shell -c "from openedx_tenant_cache.models import TenantSiteConfiguration; \
  cfg = TenantSiteConfiguration.objects.get(domain='academyv2.mereka.io'); \
  print(cfg.logo_url)"
```

**Fix**: Upload tenant logo and update configuration:

1. Upload logo to theme assets: `infrastructure/tutor/themes/mereka/tenants/<slug>/assets/logo.png`
2. Run `./scripts/branding/sync-branding.sh`
3. Update `TenantSiteConfiguration`:

```bash
kubectl exec -n mereka-lms -it deploy/lms -- \
  python manage.py shell -c "from openedx_tenant_cache.models import TenantSiteConfiguration; \
  cfg = TenantSiteConfiguration.objects.get(domain='academyv2.mereka.io'); \
  cfg.logo_url = 'https://academyv2.mereka.io/static/mereka/tenants/mereka/assets/logo.png'; \
  cfg.save()"
```

---

## Scenario 4: Configuration Gaps

### 4.1 Tenant Not Provisioned

**Symptom**: Domain returns default Open edX branding instead of tenant-specific branding.

**Diagnostics**:
```bash
# Check if tenant exists
kubectl exec -n mereka-lms -it deploy/lms -- \
  python manage.py shell -c "from openedx_tenant_cache.models import TenantSiteMapping; \
  print(TenantSiteMapping.objects.filter(domain='newclient.academy.mereka.io').exists())"
# Should return: True
```

**Fix**: Provision tenant using the provisioning script:

```bash
# Create tenant environment file
cat > scripts/tenants/newclient-tenant.env <<EOF
TENANT_SLUG=newclient
TENANT_NAME="New Client Academy"
TENANT_DOMAIN=newclient.academy.mereka.io
ENTERPRISE_CUSTOMER_UUID=<uuid>
PLATFORM_NAME="New Client Academy"
LOGO_URL=https://newclient.academy.mereka.io/static/mereka/tenants/newclient/assets/logo.png
BRAND_PRIMARY=#1a73e8
BRAND_SECONDARY=#34a853
EOF

# Provision tenant
./scripts/tenants/provision-tenant.sh --from-env scripts/tenants/newclient-tenant.env
```

**See**: `docs/operations/TENANT_PROVISIONING.md` for full provisioning workflow.

---

### 4.2 Placeholder UUIDs in Code

**Symptom**: Runtime errors referencing hardcoded test UUIDs.

**Diagnostics**:
```bash
# Search for placeholder UUIDs in codebase
grep -r "00000000-0000-0000-0000-000000000000" infrastructure/tutor/
```

**Fix**: Replace placeholder UUIDs with real tenant UUIDs from database:

```bash
# Get real tenant UUIDs
kubectl exec -n mereka-lms -it deploy/lms -- \
  python manage.py shell -c "from openedx_tenant_cache.models import TenantSiteMapping; \
  for t in TenantSiteMapping.objects.all(): \
      print(f'{t.domain}: {t.enterprise_customer_uuid}')"

# Update code with real UUIDs
```

---

## Scenario 5: Known Limitations

### 5.1 Single-Theme Architecture at Scale

**Current state**: All tenants share one `mereka` theme with runtime overlays.

**Known limitation**: At 5-10 tenants, static asset storage in theme directory may become a bottleneck.

**Mitigation strategies** (future):
- Move tenant assets to CDN or S3
- Implement per-tenant theme directories
- Use runtime asset URL configuration instead of file-based assets

**Monitoring**: Track cache hit rates (target: >90%) and query performance (p95 <300ms).

---

### 5.2 MFE Build Strategy (No Per-Tenant MFE Images)

**Current state**: One MFE image for all tenants. Footer variant uses runtime injection (`window.location.hostname`).

**Known limitation**: If tenant needs custom React components (not just CSS/config), runtime injection may not suffice.

**Decision point**: At 5+ tenants with custom component needs, evaluate per-tenant MFE builds vs. runtime plugin framework.

**See**: ADR-TBD (to be documented when decision is needed).

---

## Verification Commands

```bash
# Full runtime verification (production)
./scripts/qa/verify-tenant-branding-runtime.sh --env prod

# Check tenant provisioning
./scripts/qa/verify-tenant-isolation.sh

# Verify branding gates
./scripts/branding/run-branding-gates.sh prod

# Check multisite governance
./scripts/qa/run-multisite-governance-gates.sh --env prod
```

---

## Related Documentation

- **Contract**: `docs/branding/TENANT_BRANDING_CONTRACT.md`
- **Provisioning**: `docs/operations/TENANT_PROVISIONING.md`
- **Readiness**: `docs/operations/TENANT_BRANDING_READINESS_RAG.md`
- **Architecture**: `docs/architecture/multi-tenancy-overview.md`
- **Spec**: `specs/multi-tenancy-architecture_spec.md`
- **General troubleshooting**: `docs/operations/TROUBLESHOOTING.md`

---

## Escalation Path

If troubleshooting steps don't resolve the issue:

1. **Capture diagnostics**:
   ```bash
   # Run full diagnostic bundle
   ./scripts/qa/verify-tenant-branding-runtime.sh --env prod > tenant-branding-diagnostic.log 2>&1
   ./scripts/qa/run-multisite-governance-gates.sh --env prod >> tenant-branding-diagnostic.log 2>&1
   ```

2. **Check recent changes**:
   ```bash
   # Recent Tutor config changes
   git log -p --since="7 days ago" -- infrastructure/tutor/

   # Recent K8s deployments
   kubectl rollout history deployment -n mereka-lms
   ```

3. **Review cache state**:
   ```bash
   # Redis cache inspection
   kubectl exec -n mereka-lms -it deploy/redis -- redis-cli KEYS "*tenant*"
   kubectl exec -n mereka-lms -it deploy/redis -- redis-cli KEYS "*branding*"
   ```

4. **Contact Platform Engineering** with:
   - Diagnostic log
   - Recent changes log
   - Expected vs actual behavior
   - Tenant domain/slug affected
