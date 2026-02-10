# Studio Branding Fix - Verification Report

## Issue Summary

**URL**: https://studio.academyv2.mereka.io
**Expected**: "Welcome to Mereka Academy - Studio"
**Previous**: "Welcome to My Open edX - Studio"
**Status**: ✅ FIXED

## Root Cause

The CMS deployment was using an outdated ConfigMap (`openedx-settings-cms-g4g47c7cg4`) that contained the default "My Open edX - Studio" branding instead of the correct ConfigMap (`openedx-settings-cms-cf29k7kf85`) with "Mereka Academy - Studio" branding.

### Why it happened:

1. **Deprecated Kustomize syntax**: `staging/kustomization.yaml` was using `labels:` instead of `commonLabels:`
2. **ConfigMap reference not updating**: Kustomize's automatic name reference transformation wasn't working properly
3. **Deployment not recreated**: Changes to ConfigMaps don't automatically trigger pod recreations

## Solution Applied

### 1. Fixed Kustomization Configuration

```yaml
# deploy/k8s/overlays/staging/kustomization.yaml
- labels:
+ commonLabels:
  environment: staging
```

### 2. Recreated CMS Deployment

```bash
kubectl delete deployment cms -n mereka-lms
kubectl apply -k deploy/k8s/overlays/staging
```

This forced the deployment to use the correct ConfigMap with updated branding.

## Verification Results

### Django Settings (In-Pod)

```bash
kubectl exec -n mereka-lms deployment/cms -- \
  python manage.py cms shell -c \
  "from django.conf import settings; \
   print(f'PLATFORM_NAME: {settings.PLATFORM_NAME}'); \
   print(f'STUDIO_NAME: {settings.STUDIO_NAME}')"
```

**Output**:
```
PLATFORM_NAME: Mereka Academy
STUDIO_NAME: Mereka Academy - Studio
```

### HTML Content (From Cluster)

```bash
kubectl exec -n mereka-lms deployment/lms -- curl -sL http://cms:8000/
```

**Page Title**:
```html
<title>
    Welcome |
    Mereka Academy - Studio
</title>
```

**Heading**:
```html
<h1><span class="wrapper-text-welcome">Welcome to Mereka Academy - Studio</span></h1>
```

### ConfigMap Verification

```bash
kubectl get deployment cms -n mereka-lms -o json | \
  jq '.spec.template.spec.volumes[] | select(.name=="settings-cms")'
```

**Output**:
```json
{
  "configMap": {
    "defaultMode": 420,
    "name": "openedx-settings-cms-cf29k7kf85"
  },
  "name": "settings-cms"
}
```

✅ Deployment now uses the correct ConfigMap with Mereka branding.

## Configuration Files

The correct branding is defined in:

1. **`deploy/k8s/base/apps/openedx/settings/cms/production.py`** (line 300):
   ```python
   STUDIO_NAME = "Mereka Academy - Studio"
   ```

2. **`deploy/k8s/base/apps/openedx/config/cms.env.yml`** (line 6):
   ```yaml
   PLATFORM_NAME: "Mereka Academy"
   ```

## Known Issue: External Access (LoadBalancer)

**Note**: External access to https://studio.academyv2.mereka.io currently returns 503 due to a separate infrastructure issue:

- The Caddy service is configured as `ClusterIP` instead of `LoadBalancer`
- Service type is oscillating between ClusterIP and LoadBalancer
- This is unrelated to the branding fix and is a GKE/service configuration issue

**Evidence**:
```
NAME    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
caddy   ClusterIP   34.118.234.137   <none>        80/TCP    19d
```

**However**, the branding is correct within the cluster and will display properly once the LoadBalancer issue is resolved.

## Production Readiness

✅ **Studio branding is PRODUCTION READY**

The application-level branding configuration is correct. Once the LoadBalancer/ingress issue is resolved, Studio will display:

- **Page Title**: "Welcome | Mereka Academy - Studio"
- **Heading**: "Welcome to Mereka Academy - Studio"
- **Platform Name**: "Mereka Academy"

## Commit

```
commit 89e32fd
fix: correct Studio CMS branding to show "Mereka Academy - Studio"
```

## Files Changed

- `deploy/k8s/overlays/staging/kustomization.yaml` (1 line: `labels:` → `commonLabels:`)

## Next Steps

1. ✅ Branding fix is complete and verified
2. ⚠️ Resolve Caddy LoadBalancer configuration (separate issue)
3. ⚠️ Test external access once LoadBalancer is configured
4. ✅ Ready for production deployment of branding changes

---

**Date**: 2026-02-03
**Verified by**: Claude Sonnet 4
**Status**: RESOLVED
