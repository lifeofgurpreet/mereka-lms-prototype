# MFE OAuth Fix - Deployment Checklist

Use this checklist to deploy the OAuth provider fix.

## Pre-Deployment

- [ ] Read `MFE_OAUTH_FIX_SUMMARY.md` for context
- [ ] Read `docs/runbooks/architecture/MFE_OAUTH_FIX_DEPLOYMENT.md` for detailed steps
- [ ] Verify current issue exists:
  ```bash
  curl -s https://academyv2.mereka.io/api/mfe_context | jq '.contextData.providers'
  # Should return: []
  ```
- [ ] Check database has OAuth providers:
  ```bash
  # Execute in LMS pod
  kubectl exec -it deployment/lms -n mereka-lms -- python manage.py lms shell
  ```
  ```python
  from third_party_auth.models import OAuth2ProviderConfig
  OAuth2ProviderConfig.objects.filter(site_id=6, enabled=True, visible=True).count()
  # Should return: 1 (or more)
  ```

## Deployment Steps

### 1. Prepare Environment
- [ ] Navigate to repository root:
  ```bash
  cd /home/gurpreet/projects/k8s/mereka-lms
  ```
- [ ] Activate virtual environment:
  ```bash
  source .venv/bin/activate
  ```
- [ ] Set Tutor environment:
  ```bash
  source infrastructure/tutor/tutor-env.sh
  export TUTOR_ROOT="$(pwd)/tutor_env"
  ```

### 2. Apply Patches
- [ ] Run apply-patches.sh:
  ```bash
  ./infrastructure/tutor/apply-patches.sh
  ```
- [ ] Verify patches applied:
  ```bash
  # Check Dockerfile includes custom app
  grep "mfe_oauth_fix" tutor_env/env/build/openedx/Dockerfile

  # Check production.py includes middleware
  grep "mfe_oauth_fix" tutor_env/env/apps/openedx/settings/lms/production.py
  ```

### 3. Rebuild Open edX Image
- [ ] Build the image (takes 30-45 minutes):
  ```bash
  tutor images build openedx
  ```
- [ ] Verify build succeeded:
  ```bash
  docker images | grep localhost/openedx
  ```
- [ ] Test locally (optional but recommended):
  ```bash
  # Start local environment
  tutor local restart lms

  # Wait for LMS to be ready
  sleep 30

  # Test the endpoint
  curl -s http://localhost/api/mfe_context | jq '.contextData.providers'
  # Should return: non-empty array with Authentik
  ```

### 4. Push to Registry (Production)
- [ ] Tag the image:
  ```bash
  GIT_SHA=$(git rev-parse --short HEAD)
  docker tag localhost/openedx:latest \
    asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:${GIT_SHA}
  ```
- [ ] Push to registry:
  ```bash
  docker push asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:${GIT_SHA}
  ```
- [ ] Verify image in registry:
  ```bash
  gcloud artifacts docker images list asia-southeast1-docker.pkg.dev/mereka-lms/openedx \
    --include-tags | grep ${GIT_SHA}
  ```

### 5. Update Kubernetes Manifests
- [ ] Update image tag in Kustomize:
  ```bash
  cd deploy/k8s/overlays/production
  # Edit kustomization.yaml to set new image tag
  ```
- [ ] Preview changes:
  ```bash
  kubectl diff -k .
  ```

### 6. Deploy to Kubernetes
- [ ] Apply the manifests:
  ```bash
  kubectl apply -k .
  ```
- [ ] Monitor rollout:
  ```bash
  kubectl rollout status deployment/lms -n mereka-lms
  ```
- [ ] Check pod status:
  ```bash
  kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms
  ```

## Post-Deployment Verification

### 7. Verify Custom App Loaded
- [ ] Check app is installed:
  ```bash
  kubectl exec -it deployment/lms -n mereka-lms -- \
    python manage.py lms shell -c "import mfe_oauth_fix; print(mfe_oauth_fix.__file__)"
  # Expected: /openedx/mfe_oauth_fix/__init__.py
  ```
- [ ] Check middleware is loaded:
  ```bash
  kubectl exec -it deployment/lms -n mereka-lms -- \
    python manage.py lms shell -c "from django.conf import settings; print('mfe_oauth_fix.middleware.MFEOAuthFixMiddleware' in settings.MIDDLEWARE)"
  # Expected: True
  ```

### 8. Test the Endpoint
- [ ] Run automated test:
  ```bash
  ./scripts/qa/test-mfe-oauth-fix.sh
  ```
- [ ] Manual verification:
  ```bash
  curl -s https://academyv2.mereka.io/api/mfe_context | jq '.contextData.providers'
  ```
- [ ] Expected output:
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

### 9. Check Logs
- [ ] View LMS logs:
  ```bash
  kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=100 | grep -i mfe_oauth
  ```
- [ ] Look for success messages:
  - "Empty providers array detected in /api/mfe_context, attempting to fix..."
  - "Found 1 OAuth providers for site 6"
  - "Added provider: Authentik (slug: authentik, backend: oauth2-authentik)"
  - "Successfully fixed /api/mfe_context response with 1 providers"

### 10. Test MFE Login Flow
- [ ] Open browser to: https://apps.academyv2.mereka.io/authn/login
- [ ] Verify "Authentik" login button is visible
- [ ] Test OAuth login flow (optional)
- [ ] Verify no console errors

## Post-Deployment Tasks

### 11. Monitoring
- [ ] Monitor error rates in logs:
  ```bash
  kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=500 | grep -i error
  ```
- [ ] Check application metrics (if available)
- [ ] Monitor for 24 hours and check for any issues

### 12. Documentation
- [ ] Update deployment log with:
  - Deployment date/time
  - Image tag deployed
  - Verification results
  - Any issues encountered
- [ ] Notify team of successful deployment

## Rollback (If Needed)

### Emergency Rollback
- [ ] Deploy previous image tag:
  ```bash
  kubectl set image deployment/lms \
    lms=asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:<previous-tag> \
    -n mereka-lms
  ```
- [ ] Monitor rollout:
  ```bash
  kubectl rollout status deployment/lms -n mereka-lms
  ```
- [ ] Verify original behavior restored

## Troubleshooting

If verification fails, check:

1. **Custom app not found**:
   - Verify Dockerfile was patched correctly
   - Check image build logs for errors
   - Ensure custom app files exist in repository

2. **Middleware not loaded**:
   - Verify production.py was patched correctly
   - Check for Python syntax errors in settings
   - Review LMS startup logs

3. **Still empty providers**:
   - Check middleware logs for errors
   - Verify database query returns providers
   - Check site ID matches (should be 6)
   - Review middleware exception handling

4. **Import errors**:
   - Verify third_party_auth app is enabled
   - Check Python path includes /openedx
   - Review LMS error logs

For detailed troubleshooting, see: `docs/runbooks/architecture/MFE_OAUTH_FIX_DEPLOYMENT.md`

---

**Remember**: Take your time and verify each step. The image build takes 30-45 minutes, so don't rush it.
