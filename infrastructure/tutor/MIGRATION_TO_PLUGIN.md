# Migration from direct apply-patches.sh usage to the Tutor plugin workflow

This guide explains how to move away from the old operator habit of calling
`apply-patches.sh` directly and toward the plugin-led Tutor workflow.

## Canonical Local Operator Path

For local iteration, the canonical path is:

```bash
source infrastructure/tutor/tutor-env.sh
tutor plugins enable mereka_lms
./scripts/infra/tutor-config-save.sh [tutor config save args]
```

Authority split:

- `infrastructure/tutor/plugins/mereka_lms.py` is the source of truth for Tutor configuration and MFE/runtime customization that belongs in hooks.
- `scripts/infra/tutor-config-save.sh` is the operator front door for regenerating local Tutor output safely.
- `infrastructure/tutor/apply-patches.sh` remains an implementation detail invoked by the wrapper for residual file-sync and generated-file patch debt. It is not the day-to-day operator command.

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
- MFE Node 24 toolchain
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
   - **Workaround**: Use `./scripts/infra/tutor-config-save.sh --set ...` or Tutor's theme mounting system
   - **Status**: May require a separate script or Tutor's `PLUGIN_FILES` hook

2. **MFE theme assets** (`mereka/theme-source` and `mereka/theme` directories)
   - **Workaround**: Regenerate through `./scripts/infra/tutor-config-save.sh`, which invokes the residual asset-sync layer
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

2. **Regenerate config through the canonical wrapper:**
   ```bash
   ./scripts/infra/tutor-config-save.sh
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

# Regenerate through the canonical plugin-led wrapper
tutor plugins enable mereka_lms
./scripts/infra/tutor-config-save.sh

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
   # In local/operator-facing docs or helper scripts, replace:
   #   tutor config save
   #   ./infrastructure/tutor/apply-patches.sh

   # With:
   tutor plugins enable mereka_lms
   ./scripts/infra/tutor-config-save.sh
   ```

2. **Update documentation:**
   ```bash
   # Update README, CLAUDE.md, docs/onboarding/
   # Remove apply-patches.sh as an operator instruction
   ```

3. **Archive old script:**
   ```bash
   # Only after theme/build-context sync no longer depends on it.
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
./scripts/infra/tutor-config-save.sh

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

This direct script path is an exceptional fallback only. The canonical local
operator path remains `./scripts/infra/tutor-config-save.sh`.

3. **Rebuild images:**
   ```bash
   tutor images build openedx mfe
   ```

## Known Limitations

1. **Theme file copying:** The plugin does not handle file copying. You must still:
   - Keep theme assets synced into the repo via branding sync scripts
   - Regenerate Tutor output through `./scripts/infra/tutor-config-save.sh`, which still calls `apply-patches.sh`

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
