# Tutor Configuration Safety Guide

<!-- Last verified: 2026-02-13 -->

This guide explains the safety mechanisms in place to prevent Tutor configuration mistakes.

## Problem Statement

When you run `tutor config save`, Tutor regenerates **all templates from scratch**. This means:

1. Custom patches are lost
2. Multi-site domain configurations disappear
3. MySQL authentication fixes are removed
4. MFE build toolchain reverts to Node 12
5. Prometheus metrics integration is removed
6. Custom Mereka footer disappears

**Common failure modes:**
- Site goes down after config change
- MySQL authentication fails
- MFE builds fail with out-of-memory errors
- Multi-site domains return 404
- Prometheus metrics stop working

## Solution: Three-Layer Safety System

### Layer 1: Safe Wrapper Script

**Recommended for all users**

Use `tutor-config-save.sh` instead of `tutor config save`:

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/tutor-config-save.sh --set KEY=value
tutor local restart
```

**What it does:**
1. Backs up existing config (`config.yml.backup.YYYYMMDD_HHMMSS`)
2. Runs `tutor config save` with your arguments
3. Automatically applies all patches
4. Verifies patches were applied correctly
5. Shows clear next steps
6. Restores backup if anything fails

**Example output:**
```
=== Tutor Configuration Manager ===

Repository:  <repo-root>
Tutor Root:  <repo-root>/tutor_env

Backing up existing config...
  → tutor_env/config.yml.backup.20260210_125000

Step 1: Running 'tutor config save'
✓ Config saved successfully

Step 2: Applying custom patches
✓ Patches applied successfully

Step 3: Verifying configuration
✓ All required patches verified successfully!

=== Configuration Complete ===

Next steps:
  Local development:
    tutor local restart

  Kubernetes:
    tutor k8s restart
```

### Layer 2: Verification Script

**Manual verification**

Run after any `tutor config save`:

```bash
./scripts/infra/verify-tutor-config.sh
```

**Checks performed:**
- ✓ Multi-site domain configuration (biji-biji.com, skillourfuture)
- ✓ MySQL authentication fix
- ✓ MFE Node 24 toolchain
- ✓ MFE cookie domain config
- ✓ Custom Mereka footer
- ✓ Forum MongoDB Atlas SRV
- ✓ Custom apps integration (mfe_oauth_fix, openedx_prometheus)
- ✓ Prometheus metrics middleware
- ✓ Build optimizations (npm/pip retry logic)
- ✓ Asset build fixes (collectstatic safe_join)
- ✓ Theme assets (logos, fonts, SCSS)
- ✓ Health endpoints (/health, /metrics)
- ✓ Enterprise features (content_libraries, bookmarks, discussions)

**Exit codes:**
- `0` - All checks passed
- `1` - One or more checks failed

**Example output:**
```
=== Checking Multi-Site Domain Configuration ===
✓ Biji-Biji domain in ALLOWED_HOSTS
✓ SkillOurFuture domain in ALLOWED_HOSTS
✓ Biji-Biji domain in CSRF_TRUSTED_ORIGINS
✓ SkillOurFuture domain in CSRF_TRUSTED_ORIGINS

=== Checking MySQL Authentication Fix ===
✓ MySQL native password plugin
✓ MySQL remote root access

=== Verification Summary ===
✓ All required patches verified successfully!
```

### Layer 3: Git Pre-Commit Hook

**Automatic safety net**

Activates when committing `tutor_env/` files.

**Setup (one-time):**
```bash
git config --local include.path ../.gitconfig
```

**What it does:**
1. Detects commits touching `tutor_env/` files
2. Warns if `config.yml` contains secrets
3. Prompts: "Did you run apply-patches.sh?"
4. Optionally runs verification checks
5. Blocks commit if verification fails

**Example interaction:**
```
$ git add tutor_env/env/apps/openedx/settings/lms/production.py
$ git commit -m "feat: update LMS settings"

=== Tutor Configuration Change Detected ===

The following Tutor-generated files are being committed:
  - tutor_env/env/apps/openedx/settings/lms/production.py

IMPORTANT: Did you run apply-patches.sh?

Patches applied:
  • MySQL authentication fix
  • MFE Node 24 toolchain
  • Multi-site domain configuration
  • Custom Mereka footer
  • Prometheus metrics integration
  • MongoDB Atlas SRV support
  • Build optimizations

Have you run apply-patches.sh after 'tutor config save'? [y/N] y

Running verification checks...
✓ All required patches verified successfully!

✓ Proceeding with commit
```

**Bypass (emergencies only):**
```bash
git commit --no-verify
```

## Workflows

### Recommended Workflow (Safest)

```bash
# 1. Set environment
export TUTOR_ROOT="$(pwd)/tutor_env"

# 2. Use safe wrapper
./scripts/infra/tutor-config-save.sh --set KEY=value

# 3. Restart services
tutor local restart  # or 'tutor k8s restart'

# 4. Commit (git hook verifies automatically)
git add tutor_env/
git commit -m "feat: update config"
```

### Manual Workflow (Advanced Users)

```bash
# 1. Set environment
export TUTOR_ROOT="$(pwd)/tutor_env"

# 2. Save config
tutor config save --set KEY=value

# 3. Apply patches (CRITICAL!)
./infrastructure/tutor/apply-patches.sh

# 4. Verify patches
./scripts/infra/verify-tutor-config.sh

# 5. Restart services
tutor local restart

# 6. Commit
git add tutor_env/
git commit -m "feat: update config"
```

### Emergency Recovery

If you forgot to apply patches:

```bash
# 1. Check what's wrong
./scripts/infra/verify-tutor-config.sh

# 2. Apply patches
./infrastructure/tutor/apply-patches.sh

# 3. Verify fixed
./scripts/infra/verify-tutor-config.sh

# 4. Restart
tutor local restart
```

## Patch Details

### Critical Patches Applied

**MySQL Authentication:**
- Changes `--mysql-native-password=ON` to `--default-authentication-plugin=mysql_native_password`
- Adds `MYSQL_ROOT_HOST: "%"` for remote root access

**MFE Build Toolchain:**
- Upgrades Node 12 → Node 18
- Adds `g++` and `python3` to build dependencies
- Sets cookie domain environment variables

**Multi-Site Configuration:**
- Adds `academy.biji-biji.com` to ALLOWED_HOSTS
- Adds `skillourfuture.academy.mereka.io` to ALLOWED_HOSTS
- Adds CSRF trusted origins for both domains
- Configures Caddy/nginx for extra domains

**Build Optimizations:**
- Increases Node memory: `NODE_OPTIONS=--max-old-space-size=6144`
- Adds retry logic for npm/pip installs (3 attempts)
- Disables Terser parallelism (memory-intensive)

**Custom Apps:**
- Copies and installs `mfe_oauth_fix` (OAuth provider visibility)
- Copies and installs `openedx_prometheus` (metrics endpoint)
- Installs `django-prometheus==2.3.1`
- Installs `pymongo[srv]` (MongoDB Atlas SRV support)

**Theme Integration:**
- Syncs logo files (PNG/SVG variants)
- Syncs font files (WOFF2)
- Syncs SCSS overrides
- Injects custom Mereka footer in MFE env.config.jsx

**Asset Build Fixes:**
- Monkey-patches `safe_join` to fix SuspiciousFileOperation errors
- Strips Google Fonts imports from SCSS
- Ensures optional Redwood apps are enabled

### Files Modified by Patches

**Templates:**
- `tutor_env/env/plugins/mfe/build/mfe/Dockerfile`
- `tutor_env/env/plugins/mfe/build/mfe/indigo/env.config.jsx`
- `tutor_env/env/local/docker-compose.yml`
- `tutor_env/env/build/openedx/Dockerfile`
- `tutor_env/env/apps/caddy/Caddyfile`
- `tutor_env/env/apps/nginx/lms.conf`
- `tutor_env/env/apps/openedx/settings/lms/production.py`
- `tutor_env/env/build/openedx/settings/lms/assets.py`
- `tutor_env/env/build/openedx/settings/cms/assets.py`
- `tutor_env/env/build/openedx/edx-platform/webpack.prod.config.js`

**Theme Assets:**
- `tutor_env/env/build/openedx/themes/mereka/`
- `tutor_env/env/plugins/mfe/build/mfe/indigo/mereka/`

## Troubleshooting

### Verification Failed

If `verify-tutor-config.sh` fails:

1. Check which patches failed:
   ```bash
   ./scripts/infra/verify-tutor-config.sh
   ```

2. Re-apply patches:
   ```bash
   ./infrastructure/tutor/apply-patches.sh
   ```

3. If still failing, check for template drift:
   ```bash
   # Compare with upstream Tutor templates
   tutor --version
   # Check if Tutor version changed
   ```

### Site Down After Config Change

1. Run diagnostics:
   ```bash
   ./scripts/infra/verify-tutor-config.sh
   ```

2. If patches missing, apply and restart:
   ```bash
   ./infrastructure/tutor/apply-patches.sh
   tutor local restart
   ```

3. Check logs:
   ```bash
   tutor local logs --tail=100 lms
   ```

### Git Hook Not Running

1. Check hook path is configured:
   ```bash
   git config --local core.hooksPath
   # Should show: .githooks
   ```

2. Configure if missing:
   ```bash
   git config --local include.path ../.gitconfig
   ```

3. Verify hook is executable:
   ```bash
   ls -l .githooks/pre-tutor-config
   # Should show: -rwxr-xr-x
   ```

## Related Documentation

- `docs/meta/standing-orders/README.md` - Canonical standing orders
- `docs/concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md` - Canonical doc roots
- `infrastructure/tutor/apply-patches.sh` - Patch implementation
- `docs/ops/runbooks/TROUBLESHOOTING.md` - General troubleshooting
- `.githooks/pre-tutor-config` - Git hook source code
- `scripts/infra/verify-tutor-config.sh` - Verification script source

## Quick Reference

**Safe config change:**
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/tutor-config-save.sh --set KEY=value
tutor local restart
```

**Manual verification:**
```bash
./scripts/infra/verify-tutor-config.sh
```

**Emergency patch re-apply:**
```bash
./infrastructure/tutor/apply-patches.sh
```

**Setup git hooks:**
```bash
git config --local include.path ../.gitconfig
```
