# MFE OAuth Fix - Implementation Summary

## Problem

The `/api/mfe_context` endpoint returns HTTP 200 with correct structure, but the `providers` array is empty:

```json
{
  "contextData": {
    "providers": []
  }
}
```

**Database State (Confirmed)**:
- Site ID 6 (academyv2.mereka.io)
- OAuth2ProviderConfig for Authentik exists
- enabled=True, visible=True
- Provider should be returned but isn't

## Root Cause

The default Open edX `/api/mfe_context` endpoint has filtering logic that incorrectly excludes the OAuth providers for site ID 6. The exact cause in the platform code needs further investigation, but the symptom is clear: providers exist in DB but aren't returned.

## Solution Architecture

Created a custom Django middleware that:
1. **Intercepts** responses from `/api/mfe_context`
2. **Detects** empty providers array
3. **Queries** database directly for OAuth providers
4. **Injects** providers into the response JSON

This is a **non-invasive fix** that:
- ✅ Doesn't modify Open edX platform code
- ✅ Can be easily removed when root cause is fixed
- ✅ Logs all actions for debugging
- ✅ Only activates when providers array is empty

## Implementation Details

### Files Created

1. **Custom Django App** (`infrastructure/tutor/custom-apps/mfe_oauth_fix/`)
   - `middleware.py` - Core fix logic
   - `apps.py`, `__init__.py` - Django app structure
   - `views.py`, `urls.py` - Alternative implementation (unused)
   - `setup.py` - Package configuration
   - `README.md` - App documentation

2. **Patches** (`infrastructure/tutor/apply-patches.sh`)
   - Added Dockerfile COPY command to include custom app
   - Added app to INSTALLED_APPS in LMS production settings
   - Added middleware to MIDDLEWARE stack

3. **Testing** (`scripts/qa/test-mfe-oauth-fix.sh`)
   - Automated test script to verify fix works

4. **Documentation** (`docs/runbooks/architecture/MFE_OAUTH_FIX_DEPLOYMENT.md`)
   - Complete deployment guide
   - Troubleshooting steps
   - Rollback instructions

### Middleware Logic

```python
class MFEOAuthFixMiddleware(MiddlewareMixin):
    def process_response(self, request, response):
        if request.path == '/api/mfe_context' and response.status_code == 200:
            data = json.loads(response.content)
            if not data.get('contextData', {}).get('providers'):
                # Query OAuth2ProviderConfig for current site
                providers = OAuth2ProviderConfig.objects.filter(
                    site=get_current_site(request),
                    enabled=True,
                    visible=True
                )
                # Build provider data and inject into response
                data['contextData']['providers'] = [build_provider_data(p) for p in providers]
                response.content = json.dumps(data)
        return response
```

## Deployment Process

### 1. Apply Patches
```bash
./infrastructure/tutor/apply-patches.sh
```
This updates:
- Open edX Dockerfile to copy custom app
- LMS production.py to load app and middleware

### 2. Rebuild Image
```bash
tutor images build openedx  # Takes 30-45 minutes
```

### 3. Deploy to K8s
```bash
# Tag and push
docker tag localhost/openedx:latest asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:$(git rev-parse --short HEAD)
docker push asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:$(git rev-parse --short HEAD)

# Update Kustomize and apply
cd deploy/k8s/overlays/production
kubectl apply -k .
```

### 4. Verify
```bash
./scripts/qa/test-mfe-oauth-fix.sh
```

Expected output:
```
✓ Successfully fetched endpoint
✓ PASS: Found 1 provider(s)

Providers:
  - Authentik (id: oa2-authentik)

✓ Authentik provider found
  ID: oa2-authentik
  Login URL: /auth/login/oauth2-authentik/?auth_entry=login&next=/dashboard

✓ All tests passed!
```

## Verification Steps

### Check Custom App Installation
```bash
kubectl exec -it deployment/lms -n mereka-lms -- \
  python manage.py lms shell -c "import mfe_oauth_fix; print(mfe_oauth_fix.__file__)"
```
Expected: `/openedx/mfe_oauth_fix/__init__.py`

### Check Middleware Loaded
```bash
kubectl exec -it deployment/lms -n mereka-lms -- \
  python manage.py lms shell -c "from django.conf import settings; print('mfe_oauth_fix.middleware.MFEOAuthFixMiddleware' in settings.MIDDLEWARE)"
```
Expected: `True`

### Check Logs
```bash
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=100 | grep -i mfe_oauth
```
Look for:
- "Empty providers array detected in /api/mfe_context, attempting to fix..."
- "Found X OAuth providers for site Y"
- "Successfully fixed /api/mfe_context response with X providers"

### Test Endpoint
```bash
curl -s https://academyv2.mereka.io/api/mfe_context | jq '.contextData.providers'
```
Expected: Non-empty array with Authentik provider

## Impact Assessment

### Minimal Risk
- ✅ Only affects `/api/mfe_context` endpoint
- ✅ Only modifies response when providers array is empty
- ✅ No changes to database or platform code
- ✅ Can be disabled by rebuilding without the middleware
- ✅ Extensive logging for debugging

### Performance
- Middleware adds one database query per `/api/mfe_context` request
- Query is filtered by site and uses indexed fields (site_id, enabled, visible)
- Endpoint is only called during login/registration flow, not high-frequency
- **Optimization**: Can add caching if needed in future

### Maintainability
- Self-contained custom app, easy to understand
- Well-documented with inline comments
- Clear deployment and rollback procedures
- Can be removed when upstream fix is available

## Next Steps

1. **Deploy to dev (kind) or canary** and verify with test script
2. **Monitor logs** for any unexpected behavior
3. **Test MFE login flow** to ensure OAuth buttons appear
4. **Deploy to production** after dev/canary verification
5. **Investigate upstream** - Why does default endpoint filter out providers?
6. **Contribute fix** upstream to Open edX if root cause found
7. **Remove middleware** once platform bug is fixed

## Rollback Plan

If issues occur:

1. **Quick rollback**: Deploy previous image tag
   ```bash
   kubectl set image deployment/lms lms=asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:<previous-tag> -n mereka-lms
   ```

2. **Full rollback**: Comment out middleware in apply-patches.sh and rebuild
   ```bash
   # Edit apply-patches.sh, comment lines 449-458
   ./infrastructure/tutor/apply-patches.sh
   tutor images build openedx
   # Deploy new image
   ```

## Contact

For questions or issues:
- Check deployment guide: `docs/runbooks/architecture/MFE_OAUTH_FIX_DEPLOYMENT.md`
- Check app README: `infrastructure/tutor/custom-apps/mfe_oauth_fix/README.md`
- Review logs: `kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms`

---

**Status**: Ready for deployment
**Risk Level**: Low
**Estimated Deployment Time**: 45-60 minutes (mostly image build)
