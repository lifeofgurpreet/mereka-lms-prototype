# Logo 404 Fix - Deployment Checklist

## Quick Reference

**Status**: Ready for deployment
**Impact**: Critical - blocks production readiness
**Downtime**: None (live patch) or ~2 minutes (full rebuild)
**Risk**: Low - using already-working logo URL

## Pre-Deployment Verification

- [x] Template changes made (footer.html, header/brand.html)
- [x] MFE footer logo path updated in apply-patches.sh
- [x] Logo sync added to apply-patches.sh
- [x] Helper scripts created (fix-logo-static-files.sh, deploy-logo-fix.sh)
- [x] Verification script updated
- [x] Documentation created (LOGO_404_FIX.md)

## Deployment Options

### Option 1: Quick Fix (Recommended for Immediate Production)

**Time**: ~5 minutes
**Downtime**: None
**Risk**: Very Low

```bash
# 1. Apply patches locally
./infrastructure/tutor/apply-patches.sh

# 2. Deploy to production
./scripts/branding/deploy-logo-fix.sh

# 3. Verify
curl -I https://academyv2.mereka.io/static/images/logo.png
# Should return: HTTP/2 200
```

### Option 2: Full Rebuild (For Long-term Fix)

**Time**: ~45 minutes
**Downtime**: ~2 minutes during restart
**Risk**: Low

```bash
# 1. Apply patches
./infrastructure/tutor/apply-patches.sh

# 2. Set environment
export TUTOR_ROOT="$(pwd)/tutor_env"

# 3. Rebuild images
tutor images build openedx  # ~30 min
tutor images build mfe      # ~15 min

# 4. Push to registry
tutor images push openedx mfe

# 5. Restart K8s
tutor k8s restart
```

## Post-Deployment Verification

### 1. API Checks

```bash
# Logo should return 200
curl -I https://academyv2.mereka.io/static/images/logo.png

# Old path should still 404 (expected)
curl -I https://academyv2.mereka.io/static/mereka/images/logo-horizontal.png
```

### 2. Browser Checks

1. **LMS Footer**
   - URL: https://academyv2.mereka.io/
   - Action: Scroll to bottom
   - Expected: Logo displays (no broken image icon)

2. **LMS Header**
   - URL: https://academyv2.mereka.io/
   - Action: Check top navigation
   - Expected: Logo displays in header

3. **MFE Footer**
   - URL: https://apps.academyv2.mereka.io/authn/login
   - Action: Scroll to bottom
   - Expected: Logo displays in footer

### 3. Multiple Browsers

Test in:
- Chrome/Chromium (hard refresh: Ctrl+Shift+R)
- Firefox (hard refresh: Ctrl+F5)
- Safari (hard refresh: Cmd+Shift+R)

## Rollback Plan

If issues occur:

### For Quick Fix (Option 1)

```bash
# Revert template changes
git checkout HEAD -- infrastructure/tutor/themes/mereka/lms/templates/footer.html
git checkout HEAD -- infrastructure/tutor/themes/mereka/lms/templates/header/brand.html
git checkout HEAD -- infrastructure/tutor/apply-patches.sh

# Redeploy
./scripts/branding/deploy-logo-fix.sh
```

### For Full Rebuild (Option 2)

```bash
# Rollback to previous image tag
kubectl set image deployment/lms -n mereka-lms \
  lms=asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:<previous-tag>

# Or restore from backup
tutor k8s start  # Uses last known good images
```

## Known Issues & Workarounds

### CDN Cache Delays

**Symptom**: Logo still 404 after deployment
**Cause**: Cloudflare CDN caching
**Fix**: Wait 2-3 minutes or purge Cloudflare cache

### Browser Cache

**Symptom**: Logo shows old 404 in specific browser
**Fix**: Hard refresh (Ctrl+Shift+R / Cmd+Shift+R)

### Pod Restart Clears Copied Files

**Symptom**: Logo works then breaks after pod restart
**Cause**: Quick fix (Option 1) doesn't persist in image
**Fix**: Use full rebuild (Option 2) for permanent fix

## Success Criteria

- [ ] LMS footer logo displays correctly (no 404)
- [ ] LMS header logo displays correctly
- [ ] MFE footer logo displays correctly
- [ ] No console errors in browser
- [ ] Logo loads in <500ms
- [ ] Logo displays in all major browsers
- [ ] Production readiness blocker resolved

## Next Steps After Deployment

1. Monitor error logs for 24 hours:
   ```bash
   kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=100 | grep logo
   ```

2. Update status page:
   - Mark logo 404 issue as resolved
   - Update deployment notes

3. Notify stakeholders:
   - UI/UX reviewer
   - Product team
   - QA team

4. Schedule follow-up:
   - Review other static asset issues
   - Consider CDN optimization
   - Plan for MFE-specific logo variants

## Contact

**Issues during deployment?**
- Check: [LOGO_404_FIX.md](docs/operations/LOGO_404_FIX.md)
- Logs: `kubectl logs -n mereka-lms <pod-name>`
- Support: techadmin@biji-biji.com
