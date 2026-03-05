# Tutor Plugins for Mereka LMS

This directory contains Tutor plugins that apply Mereka-specific customizations to Open edX.

## Plugins

### `mereka_lms.py` (Main Plugin)

The main plugin that consolidates all Mereka LMS configuration customizations. Handles configuration patches via Tutor hooks. Works alongside `apply-patches.sh` which handles file-system operations (asset sync, theme directories).

**What it does:**

1. **Multi-Site Domain Configuration**
   - Adds `academy.biji-biji.com` and `skillourfuture.academy.mereka.io` to `ALLOWED_HOSTS`
   - Configures CSRF trusted origins for all domains
   - Sets cookie domains for session/CSRF: `.academyv2.mereka.io`

2. **Django Settings Patches**
   - Enables enterprise integration (`ENABLE_ENTERPRISE_INTEGRATION = True`)
   - Forces MFE-only discussions (disables legacy in-LMS panel)
   - Sets default theme to `mereka`
   - Ensures optional Redwood apps are installed (content libraries, bookmarks, discussions)

3. **Custom Apps Integration**
   - Installs `mfe_oauth_fix` custom app
   - Installs `openedx_prometheus` custom app
   - Adds django-prometheus for metrics
   - Installs pymongo[srv] for MongoDB Atlas

4. **Build Configuration**
   - Increases Node memory limit to 6144 MB for webpack builds
   - Strips Google Fonts imports from SCSS sources (offline-friendly CSS)
   - Compiles SASS with Mereka theme
   - Disables Terser parallel processing (build stability)

5. **MFE Configuration**
   - Installs Node 18 build toolchain (gcc, g++, python3)
   - Configures npm with retry logic (network resilience)
   - Installs frontend-plugin-framework with legacy peer deps
   - Adds custom Mereka footer component
   - Imports Mereka theme SCSS

6. **Infrastructure Configuration**
   - MySQL 8: Uses `mysql_native_password` authentication plugin
   - Caddy: Adds multi-domain blocks for extra LMS hosts
   - Nginx: Adds health check endpoint (`/health`), metrics endpoint (`/metrics`), profile API proxy

7. **Asset Build Fixes**
   - Monkey-patches Django's `safe_join` to allow relative CSS paths during collectstatic
   - Prevents `SuspiciousFileOperation` errors in Tutor v21

### `mfe_oauth_fix.py`

Plugin for fixing MFE OAuth provider visibility (example plugin, functionality merged into main plugin).

## Usage

### Enable the Plugin

```bash
# From repository root
export TUTOR_ROOT="$(pwd)/tutor_env"

# Enable the plugin
tutor plugins enable mereka_lms

# Verify it's enabled
tutor plugins list

# Regenerate configuration (applies all patches)
tutor config save

# Rebuild images with patches applied
tutor images build openedx
tutor images build mfe
```

### Configuration Variables

The plugin exposes the following configuration variables (can be overridden in `config.yml`):

| Variable | Default | Description |
|----------|---------|-------------|
| `MEREKA_LMS_EXTRA_HOSTS` | `["admin.academyv2.mereka.io", "academy.biji-biji.com", "learner.academyv2.mereka.io", "skillourfuture.academy.mereka.io"]` | Additional LMS domains |
| `MEREKA_LMS_EXTRA_CSRF_ORIGINS` | `["https://admin.academyv2.mereka.io", "https://academy.biji-biji.com", "https://learner.academyv2.mereka.io", "https://skillourfuture.academy.mereka.io"]` | CSRF trusted origins |
| `SESSION_COOKIE_DOMAIN` | `.academyv2.mereka.io` | Session cookie domain |
| `CSRF_COOKIE_DOMAIN` | `.academyv2.mereka.io` | CSRF cookie domain |

### Verification

After enabling the plugin and rebuilding images:

```bash
# Verify patches are applied
tutor config printvalue MEREKA_LMS_VERSION  # Should print 1.0.0

# Check that custom apps are included
tutor local run lms python -c "import mfe_oauth_fix; print('MFE OAuth Fix OK')"
tutor local run lms python -c "import openedx_prometheus; print('Prometheus OK')"

# Verify Prometheus is installed
tutor local run lms pip list | grep django-prometheus

# Check pymongo SRV support
tutor local run lms python -c "import pymongo; from pymongo.srv_resolver import _SrvResolver; print('MongoDB SRV OK')"
```

## Division of Responsibility: Plugin vs Script

The plugin and `apply-patches.sh` form a complementary two-layer system:

| Aspect | `apply-patches.sh` (File Operations) | `mereka_lms.py` Plugin (Configuration) |
|--------|--------------------------------------|----------------------------------------|
| **Purpose** | Asset sync, theme directories, file copying | Django settings, Dockerfile patches, build config |
| **Execution** | Must run manually after `tutor config save` | Automatic when plugin is enabled |
| **Scope** | File-system operations requiring direct file access | Configuration patches via Tutor hooks |
| **Maintenance** | Bash scripts for copy/sync operations | Structured Python hooks |
| **Idempotency** | Script-enforced idempotency checks | Tutor handles merging |
| **Version control** | Asset sync workflow | Native Tutor extension point |
| **Examples** | Logo sync, font distribution, SCSS copying | Multi-site domains, MFE footer component, Google Fonts stripping |

### Migration Steps

1. **Enable the plugin:**
   ```bash
   tutor plugins enable mereka_lms
   ```

2. **Regenerate config:**
   ```bash
   tutor config save
   ```

3. **Verify patches:**
   Check that settings are applied:
   ```bash
   tutor local run lms ./manage.py lms shell -c "from django.conf import settings; print(settings.ALLOWED_HOSTS)"
   ```

4. **Rebuild images:**
   ```bash
   tutor images build openedx
   tutor images build mfe
   ```

5. **(Optional) Archive `apply-patches.sh`:**
   ```bash
   mv infrastructure/tutor/apply-patches.sh infrastructure/tutor/apply-patches.sh.deprecated
   ```

## Tutor Plugin Hooks Used

| Hook | Purpose | Example |
|------|---------|---------|
| `CONFIG_DEFAULTS` | Define plugin configuration variables | `MEREKA_LMS_VERSION`, `MEREKA_LMS_EXTRA_HOSTS` |
| `ENV_PATCHES` | Inject code/config into templates | LMS settings, Dockerfile RUN commands |
| `PLUGIN_LOADED` | Run code when plugin loads | Print loading message |

## Development

### Adding New Patches

1. **Settings patches** → Add to `openedx-lms-production-settings` ENV_PATCHES
2. **Dockerfile patches** → Add to appropriate ENV_PATCHES:
   - `openedx-dockerfile-pre-assets` (before asset compilation)
   - `openedx-dockerfile-post-python-requirements` (after pip install)
   - `mfe-dockerfile-pre-npm-install` (before npm install)
3. **Template patches** → Use ENV_PATCHES with template name

### Testing

```bash
# Test locally
tutor local launch

# Check logs for errors
tutor local logs -f lms

# Test specific functionality
tutor local run lms ./manage.py lms check
```

### Debugging

Enable Tutor debug mode:
```bash
tutor config save --set DEBUG=true
tutor local restart lms
```

Check plugin is loaded:
```bash
tutor plugins list | grep mereka_lms
```

Inspect generated templates:
```bash
# Check LMS settings
cat tutor_env/env/apps/openedx/settings/lms/production.py

# Check Dockerfile
cat tutor_env/env/build/openedx/Dockerfile
```

## Known Issues

1. **Theme assets not synced:** The plugin does NOT handle file copying (logos, fonts, SCSS). This is by design. File-system operations are handled by `apply-patches.sh`:
   - Copies theme files to `tutor_env/env/build/openedx/themes/mereka/`
   - Copies MFE assets to `tutor_env/env/plugins/mfe/build/mfe/indigo/mereka/`
   - Syncs logos, fonts, SCSS files from source to theme directories

   Both the plugin (configuration via hooks) and the script (asset sync) are required and complementary.

2. **Custom apps must exist:** The plugin expects custom apps to be at:
   - `./infrastructure/tutor/custom-apps/mfe_oauth_fix/`
   - `./infrastructure/tutor/custom-apps/openedx_prometheus/`

   If missing, the build will fail.

3. **npm retry logic:** The npm retry logic is bash-based (not pure RUN commands). If your Docker version doesn't support this, you may need to adjust.

## References

- [Tutor Plugin Tutorial](https://docs.tutor.edly.io/tutorials/plugin.html)
- [Tutor Hooks API](https://docs.tutor.edly.io/reference/hooks-api.html)
- [Open edX Configuration](https://edx.readthedocs.io/projects/edx-platform-technical/en/latest/featuretoggles.html)

## License

Same as the repository (not specified).
