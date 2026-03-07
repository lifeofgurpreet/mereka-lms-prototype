# Logo 404 Emergency Fix - 2026-02-03

<!-- Last verified: 2026-02-13 -->

## Problem Summary

Production logo URLs were returning HTTP 404:
- `https://academyv2.mereka.io/static/images/logo-horizontal.png` → 404
- `https://academyv2.mereka.io/static/mereka/images/logo-horizontal.png` → 404

## Root Cause

The logo files exist in the theme source directory (`infrastructure/tutor/themes/mereka/`) but were NOT collected to the staticfiles directory during the Docker image build. This happened because:

1. Logo files were added to the theme AFTER the last Docker image build
2. The `collectstatic` process runs during image build time
3. Running `collectstatic` in the production pod failed with OOM (exit code 137) due to insufficient pod memory

## Emergency Fix Applied (TEMPORARY)

Manually copied logo files directly to the running pod's staticfiles directory:

```bash
# Copy to primary images path
kubectl exec -n mereka-lms deployment/lms -- bash -c \
  "cp /openedx/themes/mereka/common/static/images/logo-*.png /openedx/staticfiles/images/ && \
   cp /openedx/themes/mereka/common/static/images/logo-*.svg /openedx/staticfiles/images/"

# Copy to mereka subdirectory path
kubectl exec -n mereka-lms deployment/lms -- bash -c \
  "mkdir -p /openedx/staticfiles/mereka/images && \
   cp /openedx/themes/mereka/common/static/images/logo-*.png /openedx/staticfiles/mereka/images/ && \
   cp /openedx/themes/mereka/common/static/images/logo-*.svg /openedx/staticfiles/mereka/images/"
```

## Validation

All logo URLs now return HTTP 200:
- ✅ `https://academyv2.mereka.io/static/images/logo-horizontal.png` → HTTP 200, 25753 bytes
- ✅ `https://academyv2.mereka.io/static/mereka/images/logo-horizontal.png` → HTTP 200, 25753 bytes
- ✅ `https://academyv2.mereka.io/static/images/logo-horizontal-white.png` → HTTP 200
- ✅ `https://academyv2.mereka.io/static/images/logo-square.png` → HTTP 200
- ✅ `https://academyv2.mereka.io/static/images/logo-horizontal.svg` → HTTP 200

## Limitations of Emergency Fix

**CRITICAL**: This fix is TEMPORARY and will be lost when:
- LMS pods are restarted
- LMS pods are rescheduled to different nodes
- LMS deployment is updated

The `/openedx/staticfiles` directory is NOT backed by a persistent volume, so files copied there will be lost on pod restart.

## Permanent Fix Required

To permanently fix this issue, one of the following approaches must be taken:

### Option 1: Rebuild Docker Image (Recommended)

Rebuild the OpenedX Docker image with the updated theme files:

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
source infrastructure/tutor/tutor-env.sh
tutor images build openedx  # Takes 30-45 minutes
tutor k8s start
```

This ensures theme assets are properly collected during the build process.

### Option 2: Use Init Container

Add an init container to the LMS deployment that copies theme assets on pod startup:

```yaml
initContainers:
- name: copy-theme-assets
  image: <openedx-image>
  command:
  - /bin/bash
  - -c
  - |
    cp -R /openedx/themes/mereka/common/static/images/* /openedx/staticfiles/images/ || true
    mkdir -p /openedx/staticfiles/mereka/images
    cp -R /openedx/themes/mereka/common/static/images/* /openedx/staticfiles/mereka/images/ || true
  volumeMounts:
  - name: staticfiles
    mountPath: /openedx/staticfiles
```

### Option 3: Use Persistent Volume for Static Files

Create a PVC for static files and run a one-time job to populate it:

```bash
kubectl create -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: openedx-staticfiles
  namespace: mereka-lms
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 5Gi
EOF
```

Then mount this PVC to `/openedx/staticfiles` in LMS/CMS pods.

## Why Collectstatic Failed

The `collectstatic` command requires significant memory:
- Django loads all apps and their static files into memory
- Processes thousands of files across multiple apps
- Current LMS pod memory limits may be insufficient

Error seen:
```
command terminated with exit code 137
```

Exit code 137 = SIGKILL (killed by OOM killer)

## Recommended Action

1. **Immediate**: Current emergency fix is working - monitor URLs
2. **Next maintenance window**: Rebuild OpenedX Docker image (Option 1)
3. **Long-term**: Consider implementing Option 2 (init container) as a safeguard

## Monitoring Commands

```bash
# Test logo URLs
for url in \
  "https://academyv2.mereka.io/static/images/logo-horizontal.png" \
  "https://academyv2.mereka.io/static/mereka/images/logo-horizontal.png"; do
  echo "Testing: $url"
  curl -I "$url" 2>&1 | grep "HTTP/"
done

# Check if files exist in pod
kubectl exec -n mereka-lms deployment/lms -- \
  ls -la /openedx/staticfiles/images/logo-horizontal.png

# Check theme files in source
kubectl exec -n mereka-lms deployment/lms -- \
  ls -la /openedx/themes/mereka/common/static/images/
```

## Related Files

- Theme source: `infrastructure/tutor/themes/mereka/common/static/images/`
- Theme patches: `infrastructure/tutor/apply-patches.sh`
- Deployment: `deploy/k8s/base/apps/lms/deployment.yaml`

## Timeline

- **2026-02-03 14:56 UTC**: Logo 404s detected
- **2026-02-03 14:56 UTC**: Emergency fix applied via kubectl exec
- **2026-02-03 14:57 UTC**: All logo URLs validated returning HTTP 200

## Next Steps

- [ ] Schedule Docker image rebuild during next maintenance window
- [ ] Consider implementing init container solution
- [ ] Update deployment runbook with logo asset troubleshooting
- [ ] Add pre-deployment validation for theme assets
