# Tutor Configuration CI/CD Reference
_Audience: Operators and release owners • Owner: Platform Team • Last verified: 2026-03-10 • Status: canonical_

This document describes the automated Tutor configuration verification workflows that run on every code change.

## Workflows

### Tutor Config Verification

**Workflow:** `.github/workflows/tutor-config-verify.yml`

**Triggers:**
- Push to any branch when `tutor_env/config.yml` or `infrastructure/tutor/**` changes
- Pull requests touching Tutor configuration files
- Manual workflow dispatch

**Jobs:**

1. **verify-patches** - Verifies all patches are correctly applied
   - AC-001: MySQL authentication patch
   - AC-002: MFE Node.js memory patch

2. **verify-multi-site-domains** - Verifies multi-site domain configuration
   - All production domains in `ALLOWED_HOSTS`
   - All domains in `CSRF_TRUSTED_ORIGINS`
   - `SESSION_COOKIE_DOMAIN` set correctly

3. **verify-enterprise-features** - Verifies custom apps and enterprise features
   - AC-004: mfe_oauth_fix installed
   - AC-005: django_prometheus installed
   - Redwood compatibility apps enabled

4. **verify-idempotency** - Verifies patch script is idempotent
   - Runs `apply-patches.sh` twice
   - Compares file checksums to ensure no changes

5. **post-failure-comment** - Posts helpful comment on PR if verification fails

### Tutor Plugin Tests

**Workflow:** `.github/workflows/tutor-plugin-test.yml`

**Triggers:**
- Push to any branch when `infrastructure/tutor/plugins/**` changes
- Pull requests touching plugin files
- Manual workflow dispatch

**Jobs:**

1. **test-mfe-oauth-plugin** - Tests MFE OAuth fix plugin
   - Verifies plugin syntax
   - Enables plugin
   - Verifies patches applied
   - Validates plugin metadata

2. **test-plugin-lifecycle** - Tests enable/disable lifecycle
   - Enable plugin
   - Generate config
   - Disable plugin
   - Re-enable plugin

3. **verify-custom-app-structure** - Documents expected custom app structure

4. **lint-plugins** - Lints plugin code
   - Runs ruff
   - Checks formatting with black

5. **integration-test** - Tests plugin works with apply-patches.sh
   - Enables plugin
   - Applies patches
   - Verifies both plugin and patches work together

6. **post-failure-comment** - Posts helpful comment on PR if tests fail

## Running Locally

### Verify Tutor Configuration

```bash
# Quick check (Make target)
make tutor-verify

# Full verification script
./scripts/infra/verify-tutor-config.sh
```

### Test Tutor Plugins

```bash
# Syntax check
python3 -m py_compile infrastructure/tutor/plugins/mfe_oauth_fix.py

# Enable and test
source .venv/bin/activate
export TUTOR_ROOT="$(pwd)/tutor_env"
mkdir -p tutor_env/plugins
cp infrastructure/tutor/plugins/mfe_oauth_fix.py tutor_env/plugins/
tutor plugins enable mfe_oauth_fix
tutor config save

# Verify patches applied
grep -q "mfe_oauth_fix" tutor_env/env/apps/openedx/settings/lms/production.py
```

## Acceptance Criteria

The workflows verify all acceptance criteria from `specs/tutor-configuration_spec.md`:

- **AC-001:** MySQL authentication plugin set to `mysql_native_password`
- **AC-002:** MFE Node.js memory limit set to 6144MB
- **AC-003:** All production domains (academyv2.mereka.io, academy.biji-biji.com, skillourfuture.academy.mereka.io) in `ALLOWED_HOSTS`
- **AC-004:** mfe_oauth_fix custom app installed in `INSTALLED_APPS`
- **AC-005:** django_prometheus installed for metrics
- **AC-006:** MFE images build successfully with Node 18 (not tested in CI, requires Docker)
- **AC-007:** MySQL 8 connections succeed (not tested in CI, requires MySQL)
- **AC-008:** All domains accept logins (not tested in CI, requires runtime)
- **AC-009:** Mereka branding renders (not tested in CI, requires runtime)
- **AC-010:** All services run (not tested in CI, requires Docker)

## Failure Scenarios

### MySQL Authentication Patch Not Applied

**Symptom:** CI fails with "AC-001 FAILED: MySQL native password patch not applied"

**Fix:**
```bash
./infrastructure/tutor/apply-patches.sh
git add tutor_env/env/local/docker-compose.yml
git commit -m "fix: apply MySQL authentication patch"
```

### Multi-Site Domains Missing

**Symptom:** CI fails with "AC-003 FAILED: Missing domains in ALLOWED_HOSTS"

**Fix:**
Verify `infrastructure/tutor/apply-patches.sh` includes all production domains in the `extra_lms_hosts` patch:
```python
extra_lms_hosts = [
    "academy.biji-biji.com",
    "skillourfuture.academy.mereka.io",
]
```

### Custom Apps Not Installed

**Symptom:** CI fails with "AC-004 FAILED: mfe_oauth_fix app not installed"

**Fix:**
Ensure `apply-patches.sh` installs custom apps in the OpenEdX Dockerfile patch.

### Plugin Syntax Error

**Symptom:** Plugin test fails with "Plugin syntax invalid"

**Fix:**
```bash
# Check syntax
python3 -m py_compile infrastructure/tutor/plugins/mfe_oauth_fix.py

# Fix syntax errors, then test locally
tutor plugins enable mfe_oauth_fix
tutor config save
```

### Plugin Not Loading

**Symptom:** Plugin test fails with "Plugin not enabled"

**Fix:**
Verify plugin uses correct Tutor hooks API. Check `tutor plugins list` output.

## Integration with CI Pipeline

These workflows integrate with the main CI pipeline (`.github/workflows/ci.yml`):

1. Main CI runs linting, validation, security scans
2. Tutor config verification ensures patches are applied
3. Plugin tests ensure custom plugins work correctly
4. All workflows must pass before merge

## Monitoring

- **GitHub Actions** - View workflow runs at: https://github.com/Biji-Biji-Initiative/mereka-lms/actions
- **PR Comments** - Failed verifications post detailed comments on PRs
- **Workflow Badges** - Status badges in README.md show workflow health

## Related Documentation

- **Spec:** `specs/tutor-configuration_spec.md` - Full requirements
- **Spec:** `specs/multi-site-domains_spec.md` - Multi-site domain requirements
- **Script:** `infrastructure/tutor/apply-patches.sh` - Patch application script
- **Script:** `scripts/infra/verify-tutor-config.sh` - Verification script
- **Plugin:** `infrastructure/tutor/plugins/mfe_oauth_fix.py` - MFE OAuth fix plugin

## Troubleshooting

### Workflow Fails But Local Verification Passes

**Cause:** CI uses clean environment with config.example.yml

**Fix:** Ensure `infrastructure/tutor/config.example.yml` is up to date

### Patch Idempotency Test Fails

**Cause:** `apply-patches.sh` modifies files differently on each run

**Fix:** Ensure all patches are deterministic (no timestamps, no random values)

### Plugin Integration Test Fails

**Cause:** Plugin patches conflict with `apply-patches.sh` patches

**Fix:** Ensure plugin and script patches target different files or use different patch strategies

## Future Improvements

- Add runtime tests using Docker-in-Docker
- Test actual service connectivity (MySQL, MongoDB, Redis)
- Verify branding assets render correctly
- Add performance benchmarks for patch application
- Test upgrade path from previous Tutor versions
