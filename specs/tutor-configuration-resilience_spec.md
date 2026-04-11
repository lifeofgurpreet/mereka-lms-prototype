---
id: "SPEC-PLT-002"
title: "Tutor Configuration Resilience and Patch Automation"
type: "feature_spec"
status: "approved"
spec_class: "system"
owner: "engineering"
vehicle: "talent_platform"
created: "2026-02-10"
last_reviewed: "2026-03-09"
review_due: "2026-06-09"
last_updated: "2026-02-10"
version: "1.0.0"
domain: "platform"
normativity: "normative"
depends_on:
  - "specs/repository-structure_spec.md"
  - "specs/tutor-configuration_spec.md"
supersedes: []
superseded_by: null
verification_sources:
  - "scripts/qa/run-spec-integrity-gates.sh"
interfaces:
  - "Tutor"
  - "Patch automation"
tags:
  - "platform.control-plane"
  - "build.version-pin"
summary: "Defines resilience requirements for Tutor configuration regeneration, patch application, and operational recovery from drift."
links:
  related_docs:
    - "docs/adr/006-tutor-plugin-based-configuration.md"
    - "docs/guides/onboarding/QUICK_START_LOCAL.md"
    - "docs/guides/onboarding/LOCAL_SETUP.md"
    - "docs/ops/runbooks/TROUBLESHOOTING.md"
    - "docs/ops/runbooks/DEPLOYMENT_RUNBOOK.md"
  related_specs:
    - "specs/tutor-configuration_spec.md"
    - "specs/ci-cd-pipeline_spec.md"
    - "specs/branding-system_spec.md"
    - "specs/multi-site-domains_spec.md"
    - "specs/k8s-deployment_spec.md"
    - "specs/observability-stack_spec.md"
    - "specs/cross-cutting-requirements_spec.md"
---

<!-- markdownlint-disable MD013 MD022 MD024 MD025 MD029 MD031 MD032 MD036 MD060 -->

# Human Summary

## What we're building

A three-layered defense system that prevents Tutor configuration regressions when `tutor config save` regenerates all templates from scratch. The layers are: (1) a Tutor plugin that applies critical patches at template-render time via Tutor's hook system, (2) Git hooks that block commits when patch verification fails, and (3) a CI/CD workflow that validates configuration integrity on every push to main. Together, these layers eliminate the class of outages caused by missing or partially applied patches after configuration changes or Tutor version upgrades.

## Why it matters

The Mereka Academy platform maintains approximately 30 distinct patches to Tutor-generated templates covering MySQL authentication, MFE build toolchain, multi-site domain support, theme integration, custom application installation, Redwood compatibility, and observability instrumentation. Today, all patches live in a single `apply-patches.sh` script that must be run manually after every `tutor config save`. This workflow has failed repeatedly:

- The Tutor v18 to v21 upgrade wiped all multi-site configuration because `apply-patches.sh` was not run after `tutor config save` during the upgrade process.
- Forum configuration patches were silently lost after a routine config change, causing 500 errors on discussion pages.
- MFE cookie domain settings disappeared after a developer ran `tutor config save` without the follow-up patch step, breaking cross-origin authentication for all micro-frontends.

Every one of these incidents was caused by the same root failure: reliance on a human remembering to run a script after a destructive operation. This spec replaces that fragile pattern with automated, layered defenses.

## Success looks like

- Zero incidents caused by missing patches in the 90 days following implementation.
- Every configuration change is automatically verified within 60 seconds of `tutor config save`.
- The Tutor plugin applies at least 80% of current patches at template-render time, removing them from the post-hoc `apply-patches.sh` script.
- CI/CD rejects any PR that would produce a configuration state missing required patches.
- An upgrade from one Tutor version to the next triggers automatic patch verification with clear pass/fail reporting before any deployment proceeds.

---

# Agent Contract

## Scope

- In scope:
  - Tutor plugin architecture for applying patches via the Tutor hook system (filters and actions)
  - Git pre-commit hook that validates patched configuration state
  - CI/CD GitHub Actions workflow for configuration integrity verification
  - Patch manifest format defining all required patches with verification commands
  - Rollback procedures when configuration changes break the deployment
  - Migration path from current `apply-patches.sh` monolith to plugin-based architecture
  - Verification tooling that tests patch application idempotency and completeness
- Out of scope:
  - Upstream contributions to Tutor (tracked separately)
  - Kubernetes deployment mechanics (covered in `specs/k8s-deployment_spec.md`)
  - Individual patch implementation details (those remain in the plugin code and `apply-patches.sh`)
  - Tutor plugin marketplace publishing

## Non-goals

- This spec does NOT aim to eliminate `apply-patches.sh` entirely in the first iteration. Some patches (file copy operations, theme asset syncing) cannot be expressed as Tutor hooks. The goal is to move hook-expressible patches into the plugin and keep `apply-patches.sh` only for file-system operations.
- This spec does NOT aim to make patches survive `pip install --upgrade tutor`. Tutor upgrades are a distinct workflow that requires explicit patch review and adaptation.
- This spec does NOT define the content of individual patches. The existing `specs/tutor-configuration_spec.md` is the authoritative source for what patches are required and why.

## Assumptions

- Tutor 21.x (Ulmo) is the deployment tool, with support for the `tutor hooks` Python API.
- The repository uses GitHub Actions for CI/CD.
- Developers and agents use `make tutor-apply` or equivalent wrapper commands rather than raw `tutor config save`.
- The `tutor_env/` directory is gitignored and regenerated from config + patches.
- Python 3.10+ is available in the development environment.

---

## Implementation Status

### Overview

The three-layer defense system has been partially implemented with the Tutor plugin architecture as the foundation. The plugin consolidates the majority of patches from the legacy `apply-patches.sh` script into native Tutor hooks.

**Current State:**
- **Layer 1 (Tutor Plugin)**: ✅ Implemented (`infrastructure/tutor/plugins/mereka_lms.py`)
- **Layer 2 (Git Hooks)**: ✅ Implemented (`.githooks/pre-tutor-config`)
- **Layer 3 (CI/CD)**: ⚠️ Partially implemented (`.github/workflows/tutor-config-verify.yml`, `.github/workflows/tutor-plugin-test.yml`)

### Layer 1: Tutor Plugin Architecture

**File:** `infrastructure/tutor/plugins/mereka_lms.py`
**Size:** 555 lines
**Version:** 1.0.0

The `mereka_lms` plugin implements 15 ENV_PATCHES hooks covering:

#### Django Settings Patches
- **Hook:** `openedx-lms-production-settings`
- **Patches Applied:**
  - Multi-site domain configuration: Adds `academy.biji-biji.com` and `skillourfuture.academy.mereka.io` to `ALLOWED_HOSTS`
  - CSRF trusted origins for all domains
  - Session and CSRF cookie domains (`.academyv2.mereka.io`)
  - Enterprise integration enablement (`ENABLE_ENTERPRISE_INTEGRATION = True`)
  - MFE-only discussions (disables legacy in-LMS panel)
  - Default theme (`DEFAULT_SITE_THEME = "mereka"`)
  - Optional Redwood apps registration (content libraries, bookmarks, discussions, theming)
  - Custom Django apps: `mfe_oauth_fix`, `openedx_prometheus`
  - Django middleware: `MFEOAuthFixMiddleware`, `django_prometheus` middleware stack
  - Prometheus metrics integration

#### Asset Build Fixes
- **Hooks:** `openedx-lms-assets-settings`, `openedx-cms-assets-settings`
- **Patches Applied:**
  - Ensures optional Redwood apps exist during collectstatic
  - Monkey-patches Django's `safe_join` to prevent `SuspiciousFileOperation` errors (fixes CSS relative path references like `../../css/images/correct-icon.png`)

#### Open edX Dockerfile Patches
- **Hooks:** `openedx-dockerfile-pre-assets`, `openedx-dockerfile-post-python-requirements`
- **Patches Applied:**
  - Node.js memory limit increase (`NODE_OPTIONS="--max-old-space-size=6144"`)
  - PYTHONPATH configuration (`/openedx/edx-platform`)
  - Custom app installation (`mfe_oauth_fix`, `openedx_prometheus`)
  - Additional dependencies: `django-prometheus==2.3.1`, `pymongo[srv]` (MongoDB Atlas SRV support)
  - Google Fonts stripping from SCSS sources (offline-friendly CSS)
  - Custom theme SASS compilation with Mereka theme
  - Post-compilation Google Fonts cleanup from Studio CSS

#### Webpack Configuration
- **Hook:** `webpack-prod-config`
- **Patches Applied:**
  - Disables Terser parallel processing for build stability

#### MFE Dockerfile Patches
- **Hooks:** `mfe-dockerfile-pre-npm-install`, `mfe-dockerfile-post-npm-install`, `mfe-dockerfile-npm-install`
- **Patches Applied:**
  - Node 18 build toolchain installation (gcc, g++, python3)
  - Cookie domain environment variables
  - `@openedx/frontend-plugin-framework` installation with legacy peer deps
  - npm install resilience (retry logic: 6 attempts, configurable timeouts)

#### MFE Theme Patches
- **Hook:** `mfe-env-config`
- **Patches Applied:**
  - Imports Mereka theme SCSS
  - Custom Mereka footer component (React)

#### Infrastructure Configuration
- **Hook:** `mysql-docker-compose`
- **Patches Applied:**
  - MySQL 8 authentication plugin fix (`--default-authentication-plugin=mysql_native_password`)

- **Hook:** `caddy-caddyfile`
- **Patches Applied:**
  - Multi-domain LMS host blocks for extra domains
  - Favicon rewrite rules
  - Profile image upload size limits
  - MFE proxy configuration for profile API

- **Hook:** `nginx-lms-config`
- **Patches Applied:**
  - Additional server names for multi-site support
  - Health check endpoint (`/health`)
  - Prometheus metrics endpoint (`/metrics`)
  - MFE profile API proxy

#### Configuration Defaults
The plugin defines the following configuration variables via `CONFIG_DEFAULTS` hook:
- `MEREKA_LMS_VERSION`: Plugin version (1.0.0)
- `MEREKA_LMS_EXTRA_HOSTS`: Additional LMS domains
- `MEREKA_LMS_EXTRA_CSRF_ORIGINS`: CSRF trusted origins
- `MEREKA_SESSION_COOKIE_DOMAIN`: Session cookie domain
- `MEREKA_CSRF_COOKIE_DOMAIN`: CSRF cookie domain

#### Plugin Initialization
- **Hook:** `PLUGIN_LOADED` action
- Prints loading message with version: `"Mereka LMS plugin v1.0.0 loaded"`

### Custom Django Applications

The plugin installs two custom Django applications that live under `infrastructure/tutor/custom-apps/`:

#### 1. `mfe_oauth_fix`
**Location:** `infrastructure/tutor/custom-apps/mfe_oauth_fix/`
**Purpose:** Fixes MFE OAuth provider visibility by adding middleware that processes `/api/mfe_context` responses.

#### 2. `openedx_prometheus`
**Location:** `infrastructure/tutor/custom-apps/openedx_prometheus/`
**Purpose:** Exposes `/metrics` endpoint for Prometheus scraping. Integrates with `django_prometheus` middleware.

### Layer 2: Git Hooks

**File:** `.githooks/pre-tutor-config`
**Status:** ✅ Implemented

The pre-commit hook:
- Detects commits touching `tutor_env/` files
- Warns if `config.yml` contains secrets
- Prompts to confirm `apply-patches.sh` was run
- Optionally runs verification checks (`verify-tutor-config.sh`)
- Can be bypassed with `--no-verify`

**Setup:**
```bash
git config --local include.path ../.gitconfig
```

**Workflow:**
1. User commits changes to Tutor-generated files
2. Hook detects changes and warns
3. User confirms patches were applied
4. Hook runs verification (optional)
5. Commit proceeds if verification passes

### Layer 3: CI/CD Verification

**Status:** ⚠️ Partially implemented

#### Existing Workflows

**1. `tutor-config-verify.yml`**
- Runs on pushes to `main` and pull requests
- **Jobs:**
  - `verify-patches`: Checks critical patches (MySQL auth, MFE Node 18, forum MongoDB SRV, multi-site domains)
  - `verify-multi-site-domains`: Validates ALLOWED_HOSTS and CSRF origins
  - `verify-idempotency`: Runs `apply-patches.sh` twice and compares checksums
  - `verify-plugin-patches`: Checks plugin applies expected patches (placeholder)
- **Limitation:** Uses inline checks instead of manifest-driven verification

**2. `tutor-plugin-test.yml`**
- Tests plugin lifecycle (enable, disable, re-enable)
- Validates plugin loads without errors
- Checks configuration variables are set

#### Gap Analysis

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| Install Tutor and plugin in clean environment | ✅ Implemented | Both workflows install Tutor + plugin |
| Run `tutor config save` with production settings | ✅ Implemented | Both workflows generate config |
| Run `apply-patches.sh` | ✅ Implemented | `tutor-config-verify.yml` runs patches |
| Execute manifest-driven verification | ❌ Not implemented | Workflows use inline checks, not `verify-tutor-patches.sh` |
| Report per-patch pass/fail | ⚠️ Partial | `verify-patches` job reports 4 checks, not all patches |
| Block merges on failure | ✅ Implemented | Both workflows are required checks |
| Complete within 5 minutes | ✅ Implemented | Workflows complete in ~3-4 minutes |
| Produce audit artifact | ❌ Not implemented | No artifact upload of verification report |

### Migration Path from `apply-patches.sh`

The plugin architecture enables a phased migration:

**Phase 1 (Current):**
- Plugin handles Django settings patches and Dockerfile environment patches
- `apply-patches.sh` handles file-copy operations and template rewrites
- Both run; verification checks all patches

**Phase 2 (Target):**
- Plugin handles all hook-expressible patches
- `apply-patches.sh` reduced to file-system operations only (theme sync, logo copy)

**Phase 3 (Future):**
- `apply-patches.sh` eliminated entirely
- All patches expressed as plugin hooks or Tutor mounts

**Documentation:**
- Plugin README: `infrastructure/tutor/plugins/README.md`
- Implementation summary: `infrastructure/tutor/plugins/IMPLEMENTATION_SUMMARY.md`
- Migration guide: `infrastructure/tutor/MIGRATION_TO_PLUGIN.md`

### Testing & Verification

**Test Files:**
- `infrastructure/tutor/plugins/test_plugin.py`: Python syntax validation
- `infrastructure/tutor/plugins/verify-plugin.sh`: Plugin verification script
- Test suite planned: `tests/tutor/` (referenced in testmap but not yet implemented)

**Verification Commands:**
```bash
# Enable plugin
tutor plugins enable mereka_lms

# Verify plugin loaded
tutor plugins list | grep mereka_lms

# Check configuration
tutor config printvalue MEREKA_LMS_VERSION

# Verify patches applied
tutor config save
grep "academy.biji-biji.com" tutor_env/env/apps/openedx/settings/lms/production.py
```

### Outstanding Work

1. **Patch Manifest:** `infrastructure/tutor/patch-manifest.yml` not yet created (specification exists in this document)
2. **Verification Script:** `scripts/infra/verify-tutor-patches.sh` not yet implemented (existing `verify-tutor-config.sh` uses inline checks)
3. **CI Refactor:** Workflows need refactor to use manifest-driven verification
4. **Test Suite:** `tests/tutor/` directory tests not yet implemented (testmap references exist)
5. **Makefile Integration:** `make tutor-apply` does not yet enable plugin or run manifest verification

### Known Limitations

1. **Theme file copying:** Plugin does NOT handle file copying (logos, fonts, SCSS files). These must be copied manually or via Tutor mounts.
2. **MFE theme assets:** `indigo/mereka` directory requires manual setup or Dockerfile COPY.
3. **Hook API stability:** Plugin tested with Tutor 21.0.0; may need adjustments for other versions.

---

## Requirements

### Functional

#### Layer 1: Tutor Plugin

- The system MUST implement a Tutor plugin (`tutor-plugin-mereka`) that registers hooks to apply patches at template-render time.
- The plugin MUST use Tutor's `Filters` API to modify templates before they are written to disk (e.g., `ENV_PATCHES`, `OPENEDX_DOCKERFILE_PRE_ASSETS`, `OPENEDX_LMS_PRODUCTION_SETTINGS`).
- The plugin MUST apply the following patch categories via hooks:
  - MySQL authentication plugin configuration (`mysql_native_password`)
  - MFE Node.js version and build toolchain additions
  - Webpack memory limit (`NODE_OPTIONS=--max-old-space-size=6144`)
  - Multi-site domain additions to `ALLOWED_HOSTS` and `CSRF_TRUSTED_ORIGINS`
  - Custom Django application registration (`mfe_oauth_fix`, `openedx_prometheus`)
  - Django middleware injection (`django_prometheus`, `MFEOAuthFixMiddleware`)
  - Redwood compatibility settings (content libraries, bookmarks, discussions, theming apps)
  - MFE discussions configuration (`DISCUSSIONS_MFE_ENABLED`, `DISCUSSIONS_MICROFRONTEND_URL`)
  - Default site theme (`DEFAULT_SITE_THEME = "mereka"`)
  - Extra pip dependencies (`django-prometheus`, `pymongo[srv]`)
- The plugin MUST be installable via `pip install -e ./infrastructure/tutor/tutor-plugin-mereka`.
- The plugin MUST be idempotent: applying it multiple times MUST produce identical output.
- The plugin SHOULD define a version number that is bumped when patch content changes.

#### Layer 2: Git Hooks

- The system MUST provide a pre-commit hook that runs `make verify-tutor-config` when files under `infrastructure/tutor/` or `tutor_env/config.yml` are modified.
- The pre-commit hook MUST verify that all patches defined in the patch manifest are present in the rendered templates.
- The pre-commit hook MUST complete within 15 seconds on a standard development machine.
- The pre-commit hook MUST produce a clear error message listing which patches failed verification, with remediation instructions.
- The pre-commit hook SHOULD be skippable with `--no-verify` for emergencies, but the CI/CD layer MUST catch any skipped verification.

#### Layer 3: CI/CD Verification

- The system MUST include a GitHub Actions workflow (`verify-tutor-config.yml`) that runs on every push to `main` and on every pull request.
- The CI workflow MUST perform the following checks in order:
  1. Install Tutor and the Mereka plugin in a clean environment.
  2. Run `tutor config save` with production-equivalent settings.
  3. Run `./infrastructure/tutor/apply-patches.sh`.
  4. Execute the patch verification tool against the rendered templates.
  5. Report pass/fail with per-patch granularity.
- The CI workflow MUST block merges to `main` if any patch verification check fails.
- The CI workflow MUST complete within 5 minutes.
- The CI workflow SHOULD cache the Tutor virtual environment to reduce execution time.
- The CI workflow MUST produce an artifact containing the verification report for audit purposes.

#### Patch Manifest

- The system MUST maintain a patch manifest file (`infrastructure/tutor/patch-manifest.yml`) listing every required patch with:
  - A unique identifier (e.g., `mysql-auth`, `mfe-node18`, `multisite-domains`)
  - A human-readable description
  - The target file(s) affected
  - A verification command (grep pattern or script) that confirms the patch is applied
  - The layer responsible (plugin, apply-patches.sh, or both)
  - A severity level (`critical`, `high`, `medium`, `low`)
- The patch manifest MUST be the single source of truth for what constitutes a "fully patched" configuration.
- The verification tool MUST read the patch manifest and execute each verification command, reporting pass/fail per patch.

#### Verification Tool

- The system MUST provide a verification script (`scripts/infra/verify-tutor-patches.sh`) that reads the patch manifest and checks each patch.
- The verification script MUST exit with code 0 if all patches pass and non-zero if any fail.
- The verification script MUST output a summary table showing each patch ID, description, status (PASS/FAIL), and the file checked.
- The verification script MUST support a `--json` flag for machine-readable output.
- The verification script SHOULD support a `--fix` flag that runs `apply-patches.sh` and re-verifies.

#### Migration Path

- The system MUST support a phased migration from `apply-patches.sh` to the Tutor plugin:
  - Phase 1: Plugin handles Django settings patches and Dockerfile environment patches. `apply-patches.sh` handles file-copy and template-rewrite patches. Both run; verification checks all patches regardless of source.
  - Phase 2: Plugin handles all hook-expressible patches. `apply-patches.sh` handles only file-system operations (theme sync, logo copy, custom app copy).
  - Phase 3: `apply-patches.sh` is reduced to file-system operations only. All configuration-level patches are in the plugin.
- The system MUST NOT break the existing `make tutor-apply` workflow at any migration phase.
- The system MUST maintain a compatibility matrix documenting which Tutor versions (18.x, 21.x) are supported by which plugin version.

### Non-Functional Requirements

- Patch verification MUST complete within 30 seconds for the full manifest.
- The Tutor plugin MUST NOT increase `tutor config save` execution time by more than 5 seconds.
- The CI verification workflow MUST complete within 5 minutes end-to-end.
- All patch changes MUST be auditable via git history (patch manifest is version-controlled).
- The system MUST support offline operation for Layers 1 and 2 (no network required for plugin application or pre-commit hook verification).
- The patch manifest MUST be human-readable (YAML format) and machine-parseable.

---

## Acceptance Criteria

- [ ] AC-TCR-001: Given a clean checkout of the repository, when `pip install -e ./infrastructure/tutor/tutor-plugin-mereka` is run, then the plugin installs without errors and `tutor plugins list` shows `mereka` as available.
  - **Status:** ✅ Implemented (plugin at `infrastructure/tutor/plugins/mereka_lms.py`, enabled via `tutor plugins enable mereka_lms`)
  - **Verification:** `.github/workflows/tutor-plugin-test.yml` tests plugin lifecycle (enable/disable/re-enable)

- [ ] AC-TCR-002: Given the Mereka plugin is enabled, when `tutor config save` is run, then the rendered `production.py` contains `academy.biji-biji.com` in `ALLOWED_HOSTS` without running `apply-patches.sh`.
  - **Status:** ✅ Implemented (via `openedx-lms-production-settings` ENV_PATCHES hook)
  - **Verification:** CI job `verify-multi-site-domains` checks ALLOWED_HOSTS (note: current job runs after `apply-patches.sh`, needs plugin-only test)

- [ ] AC-TCR-003: Given the Mereka plugin is enabled, when `tutor config save` is run, then the rendered `docker-compose.yml` contains `mysql_native_password` without running `apply-patches.sh`.
  - **Status:** ✅ Implemented (via `mysql-docker-compose` ENV_PATCHES hook)
  - **Verification:** CI job `verify-patches` checks `mysql_native_password` (note: current job runs after `apply-patches.sh`, needs plugin-only test)

- [ ] AC-TCR-004: Given the Mereka plugin is enabled and `apply-patches.sh` is run, when `scripts/infra/verify-tutor-patches.sh` is executed, then all patches in `patch-manifest.yml` report PASS.
  - **Status:** ❌ Not implemented (manifest-driven verification script does not exist; existing `verify-tutor-config.sh` uses inline checks)
  - **Blocker:** `infrastructure/tutor/patch-manifest.yml` not yet created; `scripts/infra/verify-tutor-patches.sh` not yet implemented

- [ ] AC-TCR-005: Given a developer modifies `infrastructure/tutor/apply-patches.sh` and attempts to commit, when the pre-commit hook runs, then it executes `verify-tutor-patches.sh` and blocks the commit if any patch verification fails.
  - **Status:** ⚠️ Partially implemented (`.githooks/pre-tutor-config` hook exists and warns on Tutor changes, but does not yet call manifest-driven `verify-tutor-patches.sh`)
  - **Current Behavior:** Hook prompts user to confirm patches were applied, optionally runs `verify-tutor-config.sh`

- [ ] AC-TCR-006: Given a pull request that modifies any file under `infrastructure/tutor/`, when the CI workflow runs, then it executes the full patch verification and reports per-patch pass/fail status in the PR checks.
  - **Status:** ⚠️ Partially implemented (`.github/workflows/tutor-config-verify.yml` has inline checks for 4 critical patches, not manifest-driven per-patch reporting)
  - **Gap:** Workflow needs refactor to use `verify-tutor-patches.sh` reading from `patch-manifest.yml`

- [ ] AC-TCR-007: Given the verification script is run with `--json` flag, then the output is valid JSON containing an array of objects with keys `id`, `description`, `status`, `target_file`, and `severity`.
  - **Status:** ❌ Not implemented (verification script does not exist)
  - **Blocker:** `scripts/infra/verify-tutor-patches.sh` not yet implemented

- [ ] AC-TCR-008: Given `tutor config save` is run without enabling the Mereka plugin and without running `apply-patches.sh`, when `verify-tutor-patches.sh` is executed, then it reports FAIL for all critical patches and exits with non-zero status.
  - **Status:** ❌ Not implemented (verification script does not exist)
  - **Blocker:** `scripts/infra/verify-tutor-patches.sh` not yet implemented

- [ ] AC-TCR-009: Given the `apply-patches.sh` script is run twice consecutively, when the rendered templates are compared, then they are byte-identical (idempotency).
  - **Status:** ✅ Implemented (CI job `verify-idempotency` runs double-apply checksum comparison)
  - **Verification:** `.github/workflows/tutor-config-verify.yml` job checks byte-identical output for Python, YAML, Dockerfile files

- [ ] AC-TCR-010: Given a Tutor version upgrade from 18.x to 21.x, when the CI workflow runs on the upgrade PR, then it reports which patches need adaptation and blocks merge until all patches pass verification.
  - **Status:** ❌ Not implemented (CI does not detect version upgrades or report patch adaptation needs)
  - **Note:** Version upgrades are manual events; CI catches failures but upgrade planning requires human judgment

- [ ] AC-TCR-011: Given the patch manifest contains a patch with severity `critical`, when that patch fails verification, then the verification tool outputs the failure in red/bold formatting (terminal) and includes remediation steps.
  - **Status:** ❌ Not implemented (verification script does not exist)
  - **Blocker:** `scripts/infra/verify-tutor-patches.sh` not yet implemented

- [ ] AC-TCR-012: Given the `make tutor-apply` command is run, then it executes `tutor config save`, enables the Mereka plugin, runs `apply-patches.sh`, runs `verify-tutor-patches.sh`, and restarts services -- in that order, failing fast on any step.
  - **Status:** ⚠️ Partially implemented (Makefile runs `tutor config save` + `apply-patches.sh` + `restart`, but does not enable plugin or run verification)
  - **Gap:** Needs plugin enablement step and manifest-driven verification

---

## Edge Cases

### Plugin Hook Not Firing

**Symptom**: Plugin is installed and enabled but patches are not applied to rendered templates. This can happen when Tutor changes its hook API between versions.

**Mitigation**: The verification tool (Layer 3) catches this because it validates rendered output, not hook registration. The CI workflow blocks merge. Recovery: fall back to `apply-patches.sh` for the affected patches and file a compatibility issue against the plugin.

### apply-patches.sh Interrupted Mid-Execution

**Symptom**: Some files patched, others not. The Python patch phase applies all patches in a single pass, but the shell phase (file copies) can fail partway through.

**Mitigation**: `apply-patches.sh` MUST be idempotent. Re-running it completes the remaining patches. The verification tool confirms completeness. If files are corrupted: `tutor config save` regenerates clean templates, then re-run patches.

### Concurrent Config Saves

**Symptom**: Two developers or CI jobs run `tutor config save` simultaneously, producing interleaved or inconsistent output.

**Mitigation**: The `make tutor-apply` wrapper SHOULD use file locking (`flock`) to serialize access. The CI workflow runs in an isolated environment, so concurrency is not a concern there. The pre-commit hook validates the final state, catching any interleaving issues before commit.

### New Tutor Version Introduces Conflicting Template Changes

**Symptom**: A Tutor upgrade changes the template structure such that existing string-replacement patches no longer match their target strings. `apply-patches.sh` silently skips the patch.

**Mitigation**: The verification tool checks for patch presence in rendered output, not for string-match success in `apply-patches.sh`. If a patch is not present in the output, verification fails. The patch manifest's `severity: critical` patches block CI. Recovery: update `apply-patches.sh` and/or the plugin to handle the new template structure, then re-verify.

### Plugin Conflicts with Third-Party Tutor Plugins

**Symptom**: Another Tutor plugin (e.g., `tutor-mfe`, `tutor-indigo`) modifies the same template sections, causing conflicts or double-application.

**Mitigation**: The Mereka plugin MUST define explicit ordering dependencies using Tutor's hook priority system. Patches MUST be idempotent (check-before-apply pattern). The verification tool checks for correct final state, not for individual hook execution.

### Partial Plugin Migration (Phase 1/2)

**Symptom**: During migration, some patches are in the plugin and some in `apply-patches.sh`. A developer disables the plugin thinking `apply-patches.sh` covers everything, or vice versa.

**Mitigation**: The patch manifest records which layer is responsible for each patch. The verification tool checks all patches regardless of source. Both layers can safely apply the same patch (idempotency requirement). The `make tutor-apply` command runs both the plugin and `apply-patches.sh`.

### Verification Tool False Positive

**Symptom**: A patch verification grep pattern matches unrelated text, reporting PASS when the patch is actually missing.

**Mitigation**: Verification commands in the patch manifest SHOULD use specific, multi-line grep patterns or script checks rather than single-word matches. The patch manifest SHOULD be reviewed when patches are added or modified. Integration tests SHOULD include a negative case (unpatched config) to confirm the verification tool correctly reports FAIL.

---

## Observability

### Logs

- `apply-patches.sh`: MUST log each patch application with timestamp, patch ID, target file, and result (applied/skipped/already-present).
- `verify-tutor-patches.sh`: MUST log each verification check with timestamp, patch ID, status (PASS/FAIL), and target file.
- Tutor plugin: MUST log a summary line at the end of `tutor config save` listing how many patches were applied via hooks.
- CI workflow: MUST produce a downloadable verification report artifact with full per-patch results.

### Metrics

- `tutor_patch_verification_total` counter: Total verification runs, labeled by `result` (pass/fail) and `trigger` (pre-commit/ci/manual).
- `tutor_patch_verification_failures` counter: Total individual patch failures, labeled by `patch_id` and `severity`.
- `tutor_config_save_duration_seconds` histogram: Duration of `tutor config save` including plugin hooks.
- `tutor_patches_applied_total` gauge: Number of patches currently applied, labeled by `layer` (plugin/script).

### Alerts

- MUST alert (Slack `#ops-alerts`) if the CI verification workflow fails on `main` branch.
- MUST alert if `verify-tutor-patches.sh` has not been run successfully in the past 7 days (drift detection).
- SHOULD alert if `tutor config save` duration exceeds 60 seconds (indicates plugin performance degradation).

### Dashboards

- Patch compliance dashboard showing: number of patches by layer, verification pass rate over time, last successful verification timestamp, patches pending migration to plugin.
- CI workflow dashboard showing: verification run frequency, failure rate, mean execution time.

---

## Rollout & Rollback

### Rollout Plan

**Phase 1: Verification Infrastructure (Week 1-2)**

1. Create `infrastructure/tutor/patch-manifest.yml` with all current patches cataloged.
2. Implement `scripts/infra/verify-tutor-patches.sh` that reads the manifest and verifies each patch.
3. Add `verify-tutor-config` target to Makefile.
4. Run verification manually to baseline current patch coverage.

**Phase 2: CI Integration (Week 3)**

5. Add `verify-tutor-config.yml` GitHub Actions workflow.
6. Configure as a required check for PRs touching `infrastructure/tutor/`.
7. Extend to all PRs once confidence is established.

**Phase 3: Git Hooks (Week 4)**

8. Add pre-commit hook that runs verification when `infrastructure/tutor/` files change.
9. Document hook installation in `docs/guides/onboarding/LOCAL_SETUP.md`.

**Phase 4: Tutor Plugin (Week 5-8)**

10. Scaffold `tutor-plugin-mereka` with initial hooks for Django settings patches.
11. Migrate patches incrementally: settings first, then Dockerfile patches, then Caddy/nginx.
12. After each migration batch, verify that both `apply-patches.sh` and the plugin produce identical results.
13. Update patch manifest to record layer responsibility.

**Phase 5: Stabilization (Week 9-12)**

14. Monitor CI verification pass rate for 4 weeks.
15. Reduce `apply-patches.sh` to file-system operations only.
16. Update documentation and onboarding guides.

### Feature Flags

- `MEREKA_PLUGIN_ENABLED=true/false`: Controls whether the Tutor plugin is active. Default: `true` after Phase 4 rollout.
- The Makefile `tutor-apply` target MUST work correctly regardless of plugin enablement (it runs both plugin and script).

### Backward Compatibility

- The `make tutor-apply` command MUST continue to work identically throughout all rollout phases.
- `apply-patches.sh` MUST remain functional even when the plugin is active (both are idempotent and complementary).
- Developers who have not installed the pre-commit hook are protected by the CI layer.
- The verification tool works against rendered output, not against the method of patch application, so it is agnostic to the migration phase.

### Rollback Steps

1. **Plugin causes issues**: Disable plugin with `tutor plugins disable mereka`. Run `apply-patches.sh` to ensure all patches are applied via the script path. Verify with `verify-tutor-patches.sh`.
2. **CI workflow blocking legitimate PRs**: Add `[skip-tutor-verify]` to commit message as emergency bypass. File issue to fix false positive. Remove bypass after fix.
3. **Pre-commit hook too slow**: Temporarily remove hook with `pre-commit uninstall`. CI layer still provides protection.
4. **Full rollback**: Revert to pre-implementation state by removing the plugin, CI workflow, and hooks. `apply-patches.sh` continues to work as before. This is a safe rollback because the spec adds layers on top of the existing system rather than replacing it.

---

## Open Questions

1. Which Tutor hook API is stable across 18.x and 21.x? The `tutor hooks` module changed significantly between versions. The plugin compatibility matrix needs to be validated against both versions before Phase 4.
2. Should the patch manifest include patches for local-only vs production-only configurations, or should all patches be verified regardless of target environment?
3. What is the appropriate CI runner size for the verification workflow? Installing Tutor and running `config save` may require more resources than the default GitHub Actions runner provides.
4. Should the verification tool integrate with the existing `scripts/qa/smoke-test.sh` or remain independent?
5. How should the plugin handle patches that depend on Tutor plugin load order (e.g., `tutor-mfe` must load before `tutor-plugin-mereka` for MFE Dockerfile patches)?
6. Should we implement a "patch expiry" mechanism where patches are flagged for review after a configurable time period (e.g., 6 months)?
