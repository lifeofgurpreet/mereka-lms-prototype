# MFE Version Tracking

**Purpose**: Track MFE versions to prevent unexpected upstream version drift (AC-UI-004)

**Last Updated**: 2026-02-14

## Current MFE Versions

All MFEs are built from Tutor 21.0.0 (Ulmo release) with custom patches.

| MFE | Version | Tutor Image Tag | Node Version | Notes |
|-----|---------|-----------------|--------------|-------|
| learner-dashboard | v21.0.0 | `openedx-mfe:21.0.0` | 18.20.5 | Learner progress, recommendations |
| learning | v21.0.0 | `openedx-mfe:21.0.0` | 18.20.5 | Course player, unit navigation |
| profile | v21.0.0 | `openedx-mfe:21.0.0` | 18.20.5 | User profiles |
| account | v21.0.0 | `openedx-mfe:21.0.0` | 18.20.5 | Account settings |
| gradebook | v21.0.0 | `openedx-mfe:21.0.0` | 18.20.5 | Instructor gradebook |
| authn | v21.0.0 | `openedx-mfe:21.0.0` | 18.20.5 | Login, registration |
| course-authoring | v21.0.0 | `openedx-mfe:21.0.0` | 18.20.5 | Studio content authoring |

## Version Pinning Strategy

### Current Approach (Tutor-managed)
- MFE versions are pinned via Tutor release (21.0.0 / Ulmo)
- Tutor handles MFE builds with specific git commits
- No automatic upstream updates

### Custom Patches Applied

All MFEs receive the following patches via `infrastructure/tutor/apply-patches.sh`:

1. **Node 18 Build Toolchain** (`00-mfe-node18.patch`):
   - Adds build essentials: `g++`, `python3`, `make`
   - Fixes webpack compilation errors on Node 18
   - Required for: all MFEs

2. **Webpack Memory Limit** (`02-mfe-webpack-memory.patch`):
   - Sets `NODE_OPTIONS=--max-old-space-size=6144`
   - Prevents OOM during asset compilation
   - Required for: all MFEs

3. **Mereka Footer** (`03-mfe-mereka-footer.patch`):
   - Injects custom Mereka footer component
   - Branding consistency across all MFEs
   - Required for: learner-dashboard, learning, profile, account, gradebook, authn, course-authoring

## Upstream Update Policy

**IMPORTANT**: Do NOT update MFE versions without testing

### Update Procedure

1. **Check Tutor Release Notes**
   - Review https://docs.tutor.edly.io/release_notes.html
   - Identify breaking changes in MFEs

2. **Test in Local Environment**
   ```bash
   export TUTOR_ROOT="$(pwd)/tutor_env"

   # Update Tutor version
   pip install "tutor[full]==<new-version>"

   # Rebuild MFEs
   tutor images build mfe

   # Apply patches
   ./infrastructure/tutor/apply-patches.sh

   # Test locally
   tutor local restart
   ./scripts/qa/verify-mfe-branding.sh --env local
   ./scripts/qa/visual-regression-test.sh --env local
   ```

3. **Visual Regression Testing**
   ```bash
   # Capture current baseline (before update)
   ./scripts/qa/visual-regression-test.sh --update-baseline --env local

   # After update, compare
   ./scripts/qa/visual-regression-test.sh --env local

   # Review diff images in var/screenshots/diff/
   ```

4. **Update Documentation**
   - Update this file with new versions
   - Document any new patches required
   - Update `infrastructure/tutor/apply-patches.sh` if needed

5. **Deploy to Production**
   - Only after successful local testing
   - Only after visual regression tests pass

## MFE Build Configuration

### Build Environment
- **Base Image**: `node:18-bullseye` (patched from default Node 16)
- **Build Tool**: Webpack 5
- **Memory Limit**: 6GB (`NODE_OPTIONS=--max-old-space-size=6144`)
- **Build Time**: ~15-20 minutes (all MFEs)

### Build Command
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor images build mfe
```

### Build Output
- **Registry**: `asia-southeast1-docker.pkg.dev/mereka-lms/openedx`
- **Tag Format**: `openedx-mfe:21.0.0` (local), `openedx-mfe:<git-sha>` (cloud)

## MFE URL Path Mapping (AC-UI-001)

| MFE | Container Directory | URL Path | Status |
|-----|---------------------|----------|--------|
| learner-dashboard | `/openedx/app/learner-dashboard/` | `/learner-dashboard` | ✓ Match |
| learning | `/openedx/app/learning/` | `/learning` | ✓ Match |
| profile | `/openedx/app/profile/` | `/profile` | ✓ Match |
| account | `/openedx/app/account/` | `/account` | ✓ Match |
| gradebook | `/openedx/app/gradebook/` | `/gradebook` | ✓ Match |
| authn | `/openedx/app/authn/` | `/authn` | ✓ Match |
| course-authoring | `/openedx/app/course-authoring/` | `/course-authoring` | ✓ Match |

**Verification**: All URL paths match container directory names (AC-UI-001)

## Known Issues

### Issue: Studio 404 on /authoring
- **Status**: RESOLVED
- **Root Cause**: LMS settings had `AUTHN_MICROFRONTEND_URL` pointing to `/authoring` instead of `/course-authoring`
- **Fix**: Updated to `/course-authoring` in `deploy/k8s/base/apps/openedx/settings/lms/production.py`
- **Verified**: 2026-02-14

### Issue: MFE Asset 404s
- **Status**: MONITORING
- **Symptoms**: Some MFE static assets return 404 when accessed directly
- **Impact**: Low (assets are bundled in HTML, direct access not required)
- **Action**: Monitor via `verify-mfe-branding.sh`

## Monitoring

### Automated Checks
```bash
# Daily verification (cron)
./scripts/qa/verify-mfe-branding.sh --env production

# Weekly visual regression
./scripts/qa/visual-regression-test.sh --env production
```

### Manual Verification
1. Access each MFE URL path
2. Verify Mereka branding (footer, logo, colors)
3. Check browser console for errors
4. Verify no default "edX" branding visible

## References

- **Tutor Documentation**: https://docs.tutor.edly.io/
- **Tutor MFE Plugin**: https://docs.tutor.edly.io/plugins/mfe.html
- **Open edX Micro-frontends**: https://docs.openedx.org/en/latest/developers/concepts/microfrontends.html
- **Ulmo Release Notes**: https://docs.tutor.edly.io/release_notes.html#v21-0-0-ulmo

## Version History

| Date | Tutor Version | MFE Version | Changed By | Notes |
|------|---------------|-------------|------------|-------|
| 2026-02-14 | 21.0.0 | v21.0.0 | gurpreet | Initial version tracking (AC-UI-004) |

---

**Maintenance**: Update this document whenever MFE versions change or new patches are applied.
