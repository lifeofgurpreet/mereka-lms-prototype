# Migration from apply-patches.sh to Tutor Plugin

This guide explains how to migrate from the manual `apply-patches.sh` script to the native Tutor plugin system.

## Why Migrate?

| Issue with `apply-patches.sh` | Solution with Plugin |
|-------------------------------|---------------------|
| Must run manually after every `tutor config save` | Automatic when plugin is enabled |
| 1000+ lines of bash + embedded Python | Structured Python hooks (extensible) |
| String replacement logic (fragile) | Tutor's native template system |
| Hard to debug which patch failed | Clear hook names in error messages |
| Patches Tutor's internal templates | Uses documented extension points |
| Version-dependent (breaks on Tutor upgrades) | Hook API stable across versions |

## Migration Status

### ✅ Implemented in Plugin

- Multi-site domain configuration
- Django settings patches (ALLOWED_HOSTS, CSRF, sessions)
- MFE discussion settings (force MFE-only)
- Custom app integration (mfe_oauth_fix, openedx_prometheus)
- Prometheus metrics setup
- MySQL 8 authentication fix
- MFE Node 18 toolchain
- Node memory limit increase
- npm install retry logic
- SASS compilation with theme support
- Google Fonts stripping (offline-friendly CSS)
- Webpack optimization (Terser parallel: false)
- Safe_join monkey-patch (collectstatic fix)
- Health check and metrics endpoints

### ⚠️ Partially Implemented

These require additional file operations that plugins cannot handle directly:

1. **Theme file copying** (logos, fonts, SCSS)
   - **Workaround**: Use `tutor config save --set ...` or Tutor's theme mounting system
   - **Status**: May require a separate script or Tutor's `PLUGIN_FILES` hook

2. **MFE theme assets** (indigo/mereka directory)
   - **Workaround**: Copy manually or use build script
   - **Status**: Tutor's `mounts` feature can handle this

### ❌ Not in Plugin (Intentional)

These are handled by Tutor's native features:

- **Branding health check** (`verify-branding-health.sh`) - Keep as separate script
- **node_modules path fix** (Tutor v21) - Fixed in upstream Tutor, not needed anymore
- **i18n archive URL update** - Fixed in upstream, not needed
- **Conditional webpack skip** - Handled by Docker layer caching

## Step-by-Step Migration

### Phase 1: Test the Plugin (Local)

1. **Enable the plugin:**
   ```bash
   cd /home/gurpreet/projects/k8s/mereka-lms
   source infrastructure/tutor/tutor-env.sh
   tutor plugins enable mereka_lms
   tutor plugins list  # Verify it's listed
   ```

2. **Regenerate config:**
   ```bash
   tutor config save
   ```

3. **Check generated files:**
   ```bash
   # Verify LMS settings have Mereka patches
   grep -A 5 "MEREKA_LMS_EXTRA_HOSTS" tutor_env/env/apps/openedx/settings/lms/production.py

   # Verify Dockerfile has custom apps
   grep "mfe_oauth_fix" tutor_env/env/build/openedx/Dockerfile
   ```

4. **Build images:**
   ```bash
   tutor images build openedx  # Will take 30-45 min
   tutor images build mfe      # Will take 15-20 min
   ```

5. **Test locally:**
   ```bash
   tutor local launch
   curl -I http://localhost  # Should return 200
   ```

### Phase 2: Verify Parity

Run this comparison to ensure the plugin produces the same output as `apply-patches.sh`:

```bash
# Backup current patched files
mkdir -p /tmp/mereka-lms-migration
cp -r tutor_env/env /tmp/mereka-lms-migration/env-with-apply-patches

# Disable manual patches, enable plugin
tutor plugins enable mereka_lms
tutor config save

# Compare key files
diff -u \
  /tmp/mereka-lms-migration/env-with-apply-patches/apps/openedx/settings/lms/production.py \
  tutor_env/env/apps/openedx/settings/lms/production.py

diff -u \
  /tmp/mereka-lms-migration/env-with-apply-patches/build/openedx/Dockerfile \
  tutor_env/env/build/openedx/Dockerfile
```

### Phase 3: Deploy to Production

1. **Update CI/CD:**
   ```bash
   # In deploy scripts, replace:
   ./infrastructure/tutor/apply-patches.sh

   # With:
   tutor plugins enable mereka_lms
   tutor config save
   ```

2. **Update documentation:**
   ```bash
   # Update README, CLAUDE.md, docs/onboarding/
   # Remove references to apply-patches.sh
   ```

3. **Archive old script:**
   ```bash
   git mv infrastructure/tutor/apply-patches.sh \
          infrastructure/tutor/apply-patches.sh.deprecated
   git commit -m "refactor: migrate from apply-patches.sh to Tutor plugin"
   ```

## Configuration

The plugin exposes these variables (override in `tutor_env/config.yml`):

```yaml
# Mereka LMS Plugin Configuration
MEREKA_LMS_VERSION: "1.0.0"
MEREKA_LMS_EXTRA_HOSTS:
  - "academy.biji-biji.com"
  - "skillourfuture.academy.mereka.io"
MEREKA_LMS_EXTRA_CSRF_ORIGINS:
  - "https://academy.biji-biji.com"
  - "https://skillourfuture.academy.mereka.io"
MEREKA_SESSION_COOKIE_DOMAIN: ".academyv2.mereka.io"
MEREKA_CSRF_COOKIE_DOMAIN: ".academyv2.mereka.io"
```

## Troubleshooting

### Plugin not loading

```bash
# Check plugin is enabled
tutor plugins list | grep mereka_lms

# If not listed, enable it
tutor plugins enable mereka_lms
```

### Patches not applied

```bash
# Regenerate config after enabling plugin
tutor config save

# Check generated settings
cat tutor_env/env/apps/openedx/settings/lms/production.py | grep MEREKA
```

### Build failures

```bash
# Check Docker logs
tutor images build openedx 2>&1 | tee build.log

# Look for errors in custom app installation
grep -A 10 "mfe_oauth_fix" build.log
```

### Custom apps missing

Ensure custom apps exist:
```bash
ls -la infrastructure/tutor/custom-apps/
# Should show: mfe_oauth_fix/ and openedx_prometheus/
```

## Rollback Plan

If the plugin causes issues:

1. **Disable plugin:**
   ```bash
   tutor plugins disable mereka_lms
   ```

2. **Revert to apply-patches.sh:**
   ```bash
   tutor config save
   ./infrastructure/tutor/apply-patches.sh
   ```

3. **Rebuild images:**
   ```bash
   tutor images build openedx mfe
   ```

## Known Limitations

1. **Theme file copying:** The plugin does not handle file copying. You must still:
   - Copy theme assets to build directory
   - Run branding sync scripts

2. **Docker build context:** Custom apps must be in `./infrastructure/tutor/custom-apps/` relative to `TUTOR_ROOT`.

3. **Hook names:** Some hook names are Tutor version-specific. The plugin is tested with Tutor 18.2.2.

## Next Steps

After migration:

1. Update `AGENTS.md` to remove `apply-patches.sh` references
2. Update `CLAUDE.md` workflow section
3. Add plugin testing to CI/CD
4. Document plugin extension points for future customizations

## References

- [Tutor Plugin Tutorial](https://docs.tutor.edly.io/tutorials/plugin.html)
- [Tutor Hooks API](https://docs.tutor.edly.io/reference/hooks-api.html)
- `infrastructure/tutor/plugins/README.md` - Plugin documentation
- `infrastructure/tutor/plugins/mereka_lms.py` - Plugin source code
