# MFE OAuth Fix Deployment Guide

## Problem Summary

The `/api/mfe_context` endpoint returns an empty `providers` array even though OAuth providers (Authentik) are properly configured in the database. This prevents the MFE login page from displaying OAuth login buttons.

## Solution Overview

A custom Django middleware (`mfe_oauth_fix`) that intercepts responses from `/api/mfe_context` and injects OAuth providers from the database.

## Files Created

```
infrastructure/tutor/custom-apps/mfe_oauth_fix/
├── __init__.py           - App initialization
├── apps.py               - Django app configuration
├── middleware.py         - Middleware that fixes the response
├── views.py              - Alternative view implementation (unused)
├── urls.py               - URL patterns (unused)
├── setup.py              - Package configuration
└── README.md             - App documentation

infrastructure/tutor/apply-patches.sh
└── Updated to:
    - Copy custom app into Docker image
    - Add app to INSTALLED_APPS
    - Add middleware to MIDDLEWARE stack

scripts/qa/test-mfe-oauth-fix.sh
└── Test script to verify the fix works
```

## Deployment Steps

### 1. Apply Patches and Rebuild

The custom app needs to be built into the Open edX Docker image:

```bash
cd /home/gurpreet/projects/k8s/mereka-lms

# Source Tutor environment
source infrastructure/tutor/tutor-env.sh
export TUTOR_ROOT="$(pwd)/tutor_env"

# Apply patches (this updates settings and Dockerfile)
./infrastructure/tutor/apply-patches.sh

# Rebuild the Open edX image (required to include the custom app)
# This takes 30-45 minutes
tutor images build openedx

# If deploying to production, tag and push the image
docker tag localhost/openedx:latest asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:$(git rev-parse --short HEAD)
docker push asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:$(git rev-parse --short HEAD)
```

### 2. Deploy to Kubernetes

```bash
# Update the image tag in Kustomize overlays (production)
cd deploy/k8s/overlays/production

# Edit kustomization.yaml to use the new image tag
# Then apply
kubectl apply -k .

# Wait for pods to restart
kubectl rollout status deployment/lms -n mereka-lms
```

### 3. Verify the Fix

```bash
# Run the test script
./scripts/qa/test-mfe-oauth-fix.sh

# Or test manually
curl -s https://academyv2.mereka.io/api/mfe_context | jq '.contextData.providers'
```

Expected output:
```json
[
  {
    "id": "oa2-authentik",
    "name": "Authentik",
    "loginUrl": "/auth/login/oauth2-authentik/?auth_entry=login&next=/dashboard",
    "registerUrl": "/auth/login/oauth2-authentik/?auth_entry=register&next=/dashboard"
  }
]
```

### 4. Check Logs

```bash
# Check LMS logs for middleware activity
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=100 | grep -i "mfe_oauth"

# Look for messages like:
# - "Empty providers array detected in /api/mfe_context, attempting to fix..."
# - "Found X OAuth providers for site Y"
# - "Added provider: Authentik (slug: authentik, backend: oauth2-authentik)"
# - "Successfully fixed /api/mfe_context response with X providers"
```

## Local Development Testing

If you want to test locally first:

```bash
cd /home/gurpreet/projects/k8s/mereka-lms

# Apply patches
./infrastructure/tutor/apply-patches.sh

# Rebuild the Open edX image
tutor local dc build lms

# Restart LMS
tutor local restart lms

# Test the endpoint
curl -s http://localhost/api/mfe_context | jq '.contextData.providers'
```

## Troubleshooting

### Issue: Providers still empty after deployment

**Check 1: Verify custom app is installed**
```bash
kubectl exec -it deployment/lms -n mereka-lms -- python manage.py lms shell -c "import mfe_oauth_fix; print(mfe_oauth_fix.__file__)"
```

Expected: `/openedx/mfe_oauth_fix/__init__.py`

**Check 2: Verify middleware is loaded**
```bash
kubectl exec -it deployment/lms -n mereka-lms -- python manage.py lms shell -c "from django.conf import settings; print([m for m in settings.MIDDLEWARE if 'mfe_oauth_fix' in m])"
```

Expected: `['mfe_oauth_fix.middleware.MFEOAuthFixMiddleware']`

**Check 3: Check database for OAuth providers**
```bash
kubectl exec -it deployment/lms -n mereka-lms -- python manage.py lms shell
```
```python
from third_party_auth.models import OAuth2ProviderConfig
from django.contrib.sites.models import Site

site = Site.objects.get(id=6)
providers = OAuth2ProviderConfig.objects.filter(site=site, enabled=True, visible=True)
print(f"Found {providers.count()} providers")
for p in providers:
    print(f"  - {p.name} (slug: {p.slug}, backend: {p.backend_name})")
```

**Check 4: Verify middleware is executing**
```bash
# Increase Django logging verbosity temporarily
kubectl exec -it deployment/lms -n mereka-lms -- python manage.py lms shell -c "
import logging
logging.getLogger('mfe_oauth_fix').setLevel(logging.DEBUG)
"

# Then test the endpoint and check logs
curl -s https://academyv2.mereka.io/api/mfe_context
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=50 | grep mfe_oauth
```

### Issue: Middleware raises errors

Check for import errors or missing dependencies:
```bash
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=200 | grep -i "error\|exception" | grep -i mfe_oauth
```

Common issues:
- `ImportError: third_party_auth` - Ensure third_party_auth app is enabled
- `Site matching query does not exist` - Verify site ID 6 exists in database
- JSON decode errors - Check if upstream endpoint changed response format

### Issue: Image build fails

If the Docker build fails with "COPY failed":
```bash
# Verify the custom app directory exists
ls -la infrastructure/tutor/custom-apps/mfe_oauth_fix/

# Check Dockerfile patch was applied
grep "mfe_oauth_fix" tutor_env/env/build/openedx/Dockerfile
```

## Rollback

If the fix causes issues, you can quickly rollback:

1. Comment out the custom app sections in `apply-patches.sh`:
```bash
# Around line 449-458, comment out the mfe_oauth_fix_config section
```

2. Rebuild and redeploy:
```bash
./infrastructure/tutor/apply-patches.sh
tutor images build openedx
# Push and deploy
```

## Future Work

1. **Investigate root cause**: Why does the default Open edX endpoint filter out the OAuth providers?
2. **Upstream contribution**: If this is a platform bug, contribute the fix to Open edX
3. **Remove middleware**: Once the root cause is fixed upstream, this middleware can be removed
4. **Performance**: The middleware queries the database on every /api/mfe_context request. Consider caching if this becomes a bottleneck.

## Related Files

- Custom app: `/home/gurpreet/projects/k8s/mereka-lms/infrastructure/tutor/custom-apps/mfe_oauth_fix/`
- Test script: `/home/gurpreet/projects/k8s/mereka-lms/scripts/qa/test-mfe-oauth-fix.sh`
- Patches: `/home/gurpreet/projects/k8s/mereka-lms/infrastructure/tutor/apply-patches.sh`

## References

- Issue description: (link to issue tracker)
- Database confirmation: OAuth2ProviderConfig exists for site 6, enabled=True, visible=True
- Open edX third_party_auth docs: https://github.com/openedx/edx-platform/tree/master/openedx/core/djangoapps/third_party_auth
