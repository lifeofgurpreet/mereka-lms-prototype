# Logo 404 Fix - Production Readiness

<!-- Last verified: 2026-02-13 -->

## Problem Summary

The UI/UX reviewer identified critical logo 404 issues blocking production readiness:

1. **LMS Footer Logo 404**: `https://academyv2.mereka.io/static/mereka/images/logo-horizontal.png` returned 404
2. **MFE Footer Logo 404**: MFE footer referenced `/static/mereka/images/logo-horizontal.png` which didn't exist

## Root Cause

The theme static files were not being collected to the proper static paths during deployment:

- Logo files existed in theme source: `/infrastructure/tutor/themes/mereka/lms/static/images/`
- Only `logo.png` was being copied to build directory during `tutor config save`
- Template references to `logo-horizontal.png` failed because the file wasn't collected
- Working logo was accessible at `/static/images/logo.png`

## Solution Implemented

### 1. Template Updates

Updated templates to use the working logo path (`logo.png`):

**Files changed:**
- `infrastructure/tutor/themes/mereka/lms/templates/footer.html` (line 21)
- `infrastructure/tutor/themes/mereka/lms/templates/header/brand.html` (line 17)
- `infrastructure/tutor/apply-patches.sh` (line 468 - MFE footer logo)

**Before:**
```html
<img src="${static.url('images/logo-horizontal.png')}" alt="..." />
```

**After:**
```html
<img src="${static.url('images/logo.png')}" alt="..." />
```

### 2. Enhanced `apply-patches.sh`

Added automatic logo file sync to ensure all logo variants are copied during config save:

```bash
# Sync all logo files from theme source to build directory
THEME_BUILD_DIR="$REPO_ROOT/tutor_env/env/build/openedx/themes/mereka"
for logo_file in logo.png logo-horizontal.png logo-horizontal-white.png logo-square.png \
                 logo-horizontal.svg logo-horizontal-white.svg logo-square.svg \
                 favicon.ico; do
  cp "$src_file" "$THEME_BUILD_DIR/lms/static/images/$logo_file"
done
```

This ensures that after every `tutor config save`, all logo files are synced.

### 3. New Helper Scripts

Created two new scripts for immediate fixes and deployments:

**`./scripts/branding/fix-logo-static-files.sh`**
- Syncs logo files to build directory
- Runs `collectstatic` in local or K8s environments
- Useful for quick fixes without full rebuild

**`./scripts/branding/deploy-logo-fix.sh`**
- Production deployment script for K8s
- Copies logo files directly to running pods
- Runs `collectstatic` in production
- Verifies logo accessibility

### 4. Updated Verification Script

Updated `./scripts/branding/verify-logo-setup.sh` to check for `logo.png` references instead of `logo-horizontal.png`.

## Deployment Steps

### Option A: Quick Fix (No Rebuild Required)

For immediate production fix without rebuilding images:

```bash
# 1. Apply patches (syncs logo files locally)
./infrastructure/tutor/apply-patches.sh

# 2. Deploy to production K8s
./scripts/branding/deploy-logo-fix.sh
```

### Option B: Full Rebuild (Recommended for Long-term)

For a complete fix with proper image rebuild:

```bash
# 1. Apply patches
./infrastructure/tutor/apply-patches.sh

# 2. Rebuild OpenedX image
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor images build openedx

# 3. Rebuild MFE image
tutor images build mfe

# 4. Push to registry (if using K8s)
tutor images push openedx mfe

# 5. Restart services
tutor k8s restart  # or: tutor local restart
```

## Verification

After deployment, verify the fix:

1. **LMS Footer Logo**
   ```bash
   curl -I https://academyv2.mereka.io/static/images/logo.png
   # Should return: HTTP/2 200
   ```

2. **Browser Check**
   - Visit https://academyv2.mereka.io/
   - Scroll to footer - logo should display (no broken image)
   - Check header - logo should display

3. **MFE Footer Logo**
   - Visit https://apps.academyv2.mereka.io/authn/login
   - Scroll to footer - logo should display

## Files Changed

```
infrastructure/tutor/themes/mereka/lms/templates/footer.html
infrastructure/tutor/themes/mereka/lms/templates/header/brand.html
infrastructure/tutor/apply-patches.sh
scripts/branding/fix-logo-static-files.sh (new)
scripts/branding/deploy-logo-fix.sh (new)
scripts/branding/verify-logo-setup.sh
docs/operations/LOGO_404_FIX.md (new)
```

## Why Use `logo.png` Instead of `logo-horizontal.png`?

While we now sync all logo variants, we chose to use `logo.png` because:

1. **Immediate Fix**: `logo.png` was already accessible at `/static/images/logo.png`
2. **Simplicity**: Single logo file reduces complexity
3. **Consistency**: Same logo used everywhere (header, footer, MFE)
4. **Reliability**: Tutor has built-in handling for `logo.png` in themes

The other logo variants (`logo-horizontal.png`, `logo-square.png`, etc.) are still synced and available for future use or MFE-specific branding.

## Future Improvements

1. **Automated Testing**: Add smoke tests to verify logo accessibility after deployments
2. **CDN Cache**: Configure proper cache headers for static assets
3. **Image Optimization**: Consider using SVG for better scaling and smaller file size
4. **MFE Branding**: Use dedicated MFE logo variants for better responsive design

## Troubleshooting

### Logo still shows 404 after deployment

1. **Check collectstatic ran successfully**:
   ```bash
   kubectl logs -n mereka-lms <lms-pod-name> | grep collectstatic
   ```

2. **Verify file exists in pod**:
   ```bash
   kubectl exec -n mereka-lms <lms-pod-name> -- ls -la /openedx/staticfiles/images/logo.png
   ```

3. **Clear CDN cache** (if using Cloudflare):
   - Login to Cloudflare dashboard
   - Go to Caching > Purge Cache
   - Purge Everything

4. **Hard refresh browser**: Ctrl+Shift+R (Windows/Linux) or Cmd+Shift+R (Mac)

### Collectstatic fails

Check pod storage space:
```bash
kubectl exec -n mereka-lms <lms-pod-name> -- df -h
```

If storage is full, check for old static files or increase PVC size.

## Related Documentation

- [BRANDING.md](/docs/BRANDING.md) - Complete branding guide
- [TROUBLESHOOTING.md](/docs/operations/TROUBLESHOOTING.md) - General troubleshooting
- [DEVELOPER_ONBOARDING.md](/docs/onboarding/DEVELOPER_ONBOARDING.md) - Setup instructions

## Timeline

- **Identified**: 2026-02-03 (UI/UX reviewer)
- **Fixed**: 2026-02-03 (Template updates + apply-patches.sh enhancement)
- **Status**: Ready for production deployment
