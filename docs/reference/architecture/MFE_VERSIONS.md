# MFE Version Tracking

**Purpose**: Track MFE versions to prevent unexpected upstream version drift (AC-UI-004, AC-UIVER-001)

**Last Updated**: 2026-04-14

## Version Baseline (Canonical Source of Truth)

This section is the **authoritative reference** for all frontend tooling versions. CI validates that all configuration files match these values.

| Component | Version | Source | Notes |
|-----------|---------|--------|-------|
| **Tutor (pip)** | 21.0.0 | `requirements-tutor.txt` | Tutor 21.0.0 (Ulmo release) |
| **Tutor MFE Plugin** | 21.0.0 | `requirements-tutor.txt` | Official plugin for MFE builds |
| **Open edX Release** | Ulmo | Named release | Tutor v21.0.0 |
| **Node.js** | 24.11.0 | Tutor plugin MFE Dockerfile hooks | Current supported build base |
| **Python (CI/Dev)** | 3.12 | CI workflows, local dev | Minimum: 3.10 |
| **Webpack Memory Limit** | 6144 MB | `NODE_OPTIONS=--max-old-space-size=6144` | Required for Ulmo asset pipeline |
| **Mereka Plugin** | 1.0.0 | `infrastructure/tutor/plugins/mereka_lms.py` | Custom Tutor plugin for Mereka patches |

### Current Image Tags (Production)

| Image | Registry | Current Tag | Base Image |
|-------|----------|-------------|------------|
| **OpenEdX** | `ghcr.io/biji-biji-initiative/mereka-lms/openedx` | `20260210-v21-mfe-only-b988d63` | `docker.io/overhangio/openedx:21.0.0-indigo` |
| **MFE** | `ghcr.io/biji-biji-initiative/mereka-lms/mfe` | `20260208-mfe-discussions-pass4-c17df16` | `docker.io/overhangio/openedx-mfe:21.0.0-indigo` |

**Verification**: Image tags are pinned in `deploy/k8s/base/kustomization.yaml` and validated by CI (`verify-mfe-version-pinning.sh`, `verify-frontend-version-truth.sh`).

### Custom Apps Inventory

**Total custom apps**: 21 (tracked in `infrastructure/tutor/plugins/mereka_lms.py`)

These apps are installed via the Mereka Tutor plugin and verified by `scripts/qa/verify-custom-app-drift.sh`.

## Current MFE Versions

All MFEs are built from Tutor 21.0.0 (Ulmo release) with the current plugin-first MFE build contract.

| MFE | Version | Tutor Image Tag | Node Version | Notes |
|-----|---------|-----------------|--------------|-------|
| learner-dashboard | v21.0.0 | `openedx-mfe:21.0.0` | 24.11.0 | Learner progress, recommendations |
| learning | v21.0.0 | `openedx-mfe:21.0.0` | 24.11.0 | Course player, unit navigation |
| profile | v21.0.0 | `openedx-mfe:21.0.0` | 24.11.0 | User profiles |
| account | v21.0.0 | `openedx-mfe:21.0.0` | 24.11.0 | Account settings |
| gradebook | v21.0.0 | `openedx-mfe:21.0.0` | 24.11.0 | Instructor gradebook |
| authn | v21.0.0 | `openedx-mfe:21.0.0` | 24.11.0 | Login, registration |
| course-authoring | v21.0.0 | `openedx-mfe:21.0.0` | 24.11.0 | Studio content authoring |

## Version Pinning Strategy

### Current Approach (Tutor-managed)
- MFE versions are pinned via Tutor release (21.0.0 / Ulmo)
- Tutor handles MFE builds with specific git commits
- No automatic upstream updates

### Current Build Authority Split

The current MFE build path is no longer driven by broad post-render Dockerfile surgery.

1. **Tutor plugin MFE Dockerfile hooks** (`infrastructure/tutor/plugins/_mereka_lms/mfe_dockerfile.py`)
   - Own the durable Dockerfile contract: Node 24 base image, build prerequisites, plugin framework install, Redux/runtime package additions, and related hook-expressible lines.
   - These hooks are the canonical source for MFE Dockerfile customization.

2. **Governed build-context refresh** (`./scripts/infra/prepare-tutor-build-context.sh --target mfe`)
   - Refreshes the rendered MFE build context and then runs the bounded patch helper path required for asset sync, helper file copy, and other filesystem-only operations.
   - This is the sanctioned operator entrypoint after `tutor config save`.

3. **Single documented rendered-Dockerfile exception** (`infrastructure/tutor/apply-patches.sh`)
   - Retains the `wrap_mfe_pull_translations_retry` rewrite so Atlas translation pulls are retried inside the rendered MFE Dockerfile.
   - This is the only allowed post-render MFE Dockerfile rewrite still documented on 2026-04-14.

## Upstream Update Policy

**IMPORTANT**: Do NOT update MFE versions without testing

### Upgrade Procedure for Tutor 21 (AC-UIVER-004)

Follow these steps to upgrade Tutor, Open edX, or MFE versions:

#### 1. Pre-Upgrade Research
   - Review https://docs.tutor.edly.io/release_notes.html
   - Identify breaking changes in MFEs, LMS, CMS
   - Check Open edX release notes: https://docs.openedx.org/
   - Review plugin compatibility (discovery, ecommerce, credentials, notes, xqueue)

#### 2. Update Version Baseline Documentation
   - Update the **Version Baseline** table in this file (`docs/reference/architecture/MFE_VERSIONS.md`)
   - Specify new Tutor version, MFE plugin version, Node version (if changed)
   - Document new image base tags
   - **CRITICAL**: Update this file BEFORE changing any code

#### 3. Update Pinned Versions in Code
   Update version pins in these files (must match Version Baseline table):
   - `.github/workflows/build-tutor-images.yml` (Tutor version)
   - `scripts/shared/setup-local.sh` (Tutor version)
   - `infrastructure/tutor/plugins/mereka_lms.py` (`__version__` field)
   - Run `./scripts/qa/verify-frontend-version-truth.sh` to verify consistency

#### 4. Test in Local Environment
   ```bash
   export TUTOR_ROOT="$(pwd)/tutor_env"

   # Update Tutor version
   pip install "tutor[full]==<new-version>" "tutor-mfe==<new-version>"

   # Refresh governed MFE build context
   ./scripts/infra/prepare-tutor-build-context.sh --target mfe

   # Validate MFEs locally
   tutor images build mfe

   # Verify patches applied
   ./scripts/qa/verify-mfe-build-prereqs.sh
   ./scripts/infra/verify-tutor-config.sh

   # Test locally
   tutor local restart
   ./scripts/qa/verify-mfe-branding.sh --env local
   ./scripts/qa/visual-regression-test.sh --env local
   ```

#### 5. Visual Regression Testing
   ```bash
   # Capture current baseline (before update)
   ./scripts/qa/visual-regression-test.sh --update-baseline --env local

   # After update, compare
   ./scripts/qa/visual-regression-test.sh --env local

   # Review diff images in var/screenshots/diff/
   ```

#### 6. Update Patches (if needed)
   - Review Tutor plugin hook ownership in `infrastructure/tutor/plugins/_mereka_lms/mfe_dockerfile.py`
   - Review `infrastructure/tutor/apply-patches.sh` only for the bounded retry/file-sync exceptions
   - Verify the governed refresh path still reproduces the tracked snapshot
   - Run verification: `./scripts/qa/verify-mfe-build-prereqs.sh` and `./scripts/infra/verify-tutor-config.sh`

#### 7. CI Validation
   ```bash
   # Run all frontend verification scripts
   ./scripts/qa/verify-frontend-version-truth.sh
   ./scripts/qa/verify-mfe-version-pinning.sh
   ./scripts/qa/verify-mfe-build-contract.sh
   ./scripts/qa/verify-custom-app-drift.sh
   ```

#### 8. Deploy to Production
   - Only after successful local testing
   - Only after visual regression tests pass
   - Only after CI gates pass
   - Use GitOps workflow: `.github/workflows/build-tutor-images.yml`

### Post-Upgrade Verification Contract

After upgrading Tutor/Open edX, verify these contracts:

| Verification | Script | Expected Result |
|--------------|--------|-----------------|
| Version truth consistency | `./scripts/qa/verify-frontend-version-truth.sh` | PASS (0 FAIL) |
| Image tags pinned | `./scripts/qa/verify-mfe-version-pinning.sh` | PASS (9 checks) |
| Custom apps installed | `./scripts/qa/verify-custom-app-drift.sh` | PASS (21/21 apps) |
| Patches applied | `./scripts/infra/verify-tutor-config.sh` | All patches verified |
| MFE branding | `./scripts/qa/verify-mfe-branding.sh` | PASS (56 checks) |
| Theme consistency | `./scripts/qa/verify-theme-consistency.sh` | PASS (13 checks) |
| Plugin-slot wiring | `./scripts/qa/verify-plugin-slot-wiring.sh` | PASS (28 checks) |

**Failure to verify these contracts may result in runtime errors, branding regressions, or site downtime.**

## MFE Build Configuration

### Build Environment
- **Base Image**: `docker.io/node:24.11.0-bullseye-slim`
- **Build Tool**: Webpack 5
- **Memory Limit**: 6GB (`NODE_OPTIONS=--max-old-space-size=6144`)
- **Build Time**: ~15-20 minutes (all MFEs)

### Build Command
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor images build mfe
```

This command is for local validation and parity checks. Production rollout of the
updated MFE bundle should publish through `.github/workflows/build-tutor-images.yml`
and promote the resulting digests with
`./scripts/infra/release-openedx-gitops.sh --require-digests`.

### Build Output
- **Registry**: `ghcr.io/biji-biji-initiative/mereka-lms`
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
