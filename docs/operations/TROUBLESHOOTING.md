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

## Docker Image Build Failures (Tutor v21 / Ulmo)

Image builds (`tutor images build openedx`) can fail at several stages. These are the known issues and fixes as of Feb 2026.

### collectstatic: UglifyJS Parse Error

**Symptom**: Build fails at `collectstatic` with:
```
pipeline.exceptions.CompressorError: Parse error at -:895,20
SyntaxError: Unexpected token: punc ())
```

**Cause**: django-pipeline bundles UglifyJS v2.6.1 which cannot parse ES6+ JavaScript (arrow functions, template literals, default parameters). The edx-platform JS codebase now contains ES6+.

**Fix**: Disable JS compression in `assets.py` settings. Add to `apply-patches.sh` (targets both `lms/assets.py` and `cms/assets.py`):
```python
PIPELINE['JS_COMPRESSOR'] = None
```

**Wrong fixes (don't use these)**:
- `REQUIRE_BUILD_PROFILE_OPTIMIZE=none` — only affects RequireJS r.js, not django-pipeline
- `COMPRESS_ENABLED = False` — affects django-compressor which Open edX does NOT use

**Key insight**: Open edX uses **django-pipeline** (not django-compressor). The correct settings are `PIPELINE['JS_COMPRESSOR']` and `PIPELINE['PIPELINE_ENABLED']`, not `COMPRESS_ENABLED`.

### pip install: Unsupported Editable Git URL

**Symptom**: Build fails at pip install with:
```
error: Unsupported editable requirement: git+https://github.com/...#egg=edx_proctoring_proctortrack
```

**Cause**: Tutor v21 switched to `uv pip` (`$PIP_COMMAND`) which doesn't support `-e git+https://` editable Git URLs in requirements files.

**Fix**: Use standard `pip` instead of `$PIP_COMMAND` for base.txt/assets.txt:
```dockerfile
# Instead of: $PIP_COMMAND install -r requirements/edx/base.txt
pip install --no-build-isolation -r /openedx/edx-platform/requirements/edx/base.txt
```

### npm install: Lockfile Out of Sync

**Symptom**: Build fails at npm stage with:
```
npm error: package.json and package-lock.json are not in sync. Missing: fsevents@2.3.3
```

**Cause**: Upstream `package-lock.json` drift + Node v24 incompatibility with old packages (e.g., Karma requires Node 0.10-5).

**Fix**: Copy node_modules from the upstream cache image instead of running npm:
```dockerfile
FROM docker.io/overhangio/openedx:18.2.2 AS openedx_node_cache

FROM python AS nodejs-requirements
COPY --from=openedx_node_cache /openedx/nodeenv /openedx/nodeenv
COPY --from=openedx_node_cache /openedx/node_modules /openedx/node_modules
RUN ln -s /openedx/node_modules /openedx/edx-platform/node_modules
```

### ModuleNotFoundError for Custom Apps (Editable Install)

**Symptom**: LMS pod crashes with `ModuleNotFoundError: No module named 'mereka_tenancy'` even though `pip show mereka_tenancy` confirms it's installed.

**Cause**: `pip install -e` with `package_dir={'pkg': '.'}` uses legacy `setup.py develop` which adds the wrong directory to `sys.path`. Python looks for `pkg/pkg/__init__.py` instead of `pkg/__init__.py`.

**Fix (quick)**: Add a `.pth` file pointing to the parent directory:
```dockerfile
RUN echo '/openedx' > /openedx/venv/lib/python3.11/site-packages/mereka-plugins.pth
```

**Fix (proper)**: Use non-editable install in production images:
```dockerfile
# Instead of: pip install -e /openedx/mereka_tenancy
pip install /openedx/mereka_tenancy
```

### Tutor Plugin Not Taking Effect

**Symptom**: Plugin patches aren't rendered in generated Dockerfile/settings even though the plugin file exists.

**Cause**: Plugin is **installed** but not **enabled**. `tutor plugins list` shows "installed" (no checkmark) vs "enabled" (with ✅).

**Fix**:
```bash
tutor plugins enable mereka_lms
tutor config save
./infrastructure/tutor/apply-patches.sh
```

**Prevention**: Always verify plugin status after installation:
```bash
tutor plugins list | grep mereka_lms
# Should show: mereka_lms ✅ enabled
```

### Build Speed Tips

Full builds take 2-3 hours. Here's how to iterate faster:

| Approach | Time | When to Use |
|----------|------|-------------|
| Full rebuild | 2-3 hours | First build or Dockerfile structure change |
| Cached rebuild (settings-only change) | 30-60 min | Changing assets.py, production.py |
| Single-layer fix | <1 min | Adding .pth file, env var, small fix |
| Runtime test | ~10 min | Testing collectstatic before full rebuild |

**Test collectstatic without rebuilding**:
```bash
tutor local run lms ./manage.py lms collectstatic --noinput --settings=tutor.assets
```

**Add a single layer to existing image**:
```dockerfile
FROM asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:mereka-brand
RUN echo '/openedx' > /openedx/venv/lib/python3.11/site-packages/mereka-plugins.pth
```
```bash
docker build -f fix.Dockerfile -t <same-tag> .  # Takes seconds
```

**Use `--target` for partial builds**:
```bash
tutor images build openedx --target production  # Stop before final stage
```

### Open Questions / Technical Debt

These are workarounds we applied to unblock deployment. Each should be properly investigated:

| Workaround | Proper Fix (TODO) | Impact |
|------------|-------------------|--------|
| `PIPELINE['JS_COMPRESSOR'] = None` | Upgrade to Terser (`pip install terser` + `PIPELINE['JS_COMPRESSOR'] = 'pipeline.compressors.terser.TerserCompressor'`) or wait for edx-platform to drop django-pipeline entirely (ADR 0017) | JS files served unminified (~20-30% larger) |
| `pip` instead of `uv pip` for base.txt | Investigate why `uv pip` rejects editable Git URLs. Tutor v21 chose `uv pip` for speed (10x faster installs). May need `--no-editable` flag or PEP 508 format conversion of requirements | Slower pip install phase (~5-10 min extra) |
| Copy node_modules from upstream cache | Fix upstream lockfile drift (PR to edx-platform?) or use `npm install --legacy-peer-deps` instead of `npm ci` | Locked to upstream's exact Node dependency versions |
| `.pth` file for editable installs | Use non-editable `pip install` (no `-e`) in production Dockerfiles, or restructure packages to proper nested layout (`mereka_tenancy/mereka_tenancy/__init__.py`) | Minor — .pth works fine, just not elegant |
| mereka_lms plugin was installed but not enabled | Add plugin enable check to `apply-patches.sh` or `verify-tutor-config.sh` | Could silently regress if plugin gets disabled |
| Theme 'mereka' not found errors in logs | Ensure theme directory is properly included in image build and `COMPREHENSIVE_THEME_DIRS` is set | Cosmetic errors in logs, fallback to default theme |

**Priority for investigation**: The `uv pip` and `npm ci` fixes are the highest value — solving them properly would cut build times significantly (uv pip is 10x faster than pip, and proper npm would allow native caching instead of copying from upstream).

---

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

---

## Tenant Branding Runtime Verification

### Common Issues

**SITE_NAME shows "Open edX" instead of tenant name**
- Check: `curl -s https://{domain}/api/mfe_config/v1 | grep SITE_NAME`
- Fix: Verify the domain has a Django `Site` record with the correct `display_name`. Run:
  ```bash
  kubectl exec -n mereka-lms deploy/lms -- python -c "
  from django.contrib.sites.models import Site
  for s in Site.objects.all(): print(f'{s.domain} → {s.name}')
  "
  ```
- If missing, create via Django admin or management command.

**Logo returns default Open edX logo**
- Check: `curl -s https://{domain}/api/mfe_config/v1 | grep LOGO_URL`
- Fix: Verify theme assets exist at `/theming/asset/mereka/images/`. If 404, rebuild with `tutor images build openedx`.

**Brand color tokens missing from MFE config**
- This is expected in Phase 1. Brand colors require populating `branding_config` in each `TenantConfig` record.
- To populate: `kubectl exec -n mereka-lms deploy/lms -- python -c "..." ` (update TenantConfig.branding_config)

**Footer shows wrong variant**
- Check: Verify `SITE_VARIANTS` in Caddy/LMS settings includes the domain.
- Check: Verify footer template renders correctly: `curl -s https://{domain}/ | grep -i "footer"`

**Runtime verification script fails with timeout**
- Increase timeout: `CURL_TIMEOUT=30 ./scripts/qa/verify-tenant-branding-runtime.sh --env prod`
- Check DNS: `dig +short {domain}`
- Check ingress: `kubectl get ingress -n mereka-lms`

### Verification Commands

```bash
# Full branding runtime check
./scripts/qa/verify-tenant-branding-runtime.sh --env prod

# Full governance gates (includes branding)
./scripts/qa/run-multisite-governance-gates.sh --env prod

# Per-domain MFE config
curl -s https://academyv2.mereka.io/api/mfe_config/v1 | python3 -m json.tool
curl -s https://academy.biji-biji.com/api/mfe_config/v1 | python3 -m json.tool
curl -s https://skillourfuture.academy.mereka.io/api/mfe_config/v1 | python3 -m json.tool
```

### Reference
- Surface matrix: `docs/operations/TENANT_BRANDING_SURFACE_MATRIX.md`
- Branding runtime script: `scripts/qa/verify-tenant-branding-runtime.sh`
- Governance gates: `scripts/qa/run-multisite-governance-gates.sh`
