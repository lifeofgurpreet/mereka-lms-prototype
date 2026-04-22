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
last_updated: "2026-04-21"
version: "1.1.0"
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

The Mereka Academy platform still carries a broad patch surface across Tutor-generated templates covering MySQL authentication, MFE build/toolchain behavior, multi-site domain support, theme integration, custom application installation, Redwood compatibility, and observability instrumentation. The current state is mixed: Tutor plugin hooks own durable settings and Dockerfile-level customization, while `apply-patches.sh` still handles the remaining filesystem sync/template rewrites and one explicit `pull_translations` retry exception in the rendered MFE Dockerfile. This workflow has still failed repeatedly whenever the governed post-render sync step was skipped:

- The Tutor v18 to v21 upgrade wiped all multi-site configuration because `apply-patches.sh` was not run after `tutor config save` during the upgrade process.
- Forum configuration patches were silently lost after a routine config change, causing 500 errors on discussion pages.
- MFE cookie domain settings disappeared after a developer ran `tutor config save` without the follow-up patch step, breaking cross-origin authentication for all micro-frontends.

Every one of these incidents was caused by the same root failure: reliance on a human remembering to run a script after a destructive operation. This spec replaces that fragile pattern with automated, layered defenses.

## Success looks like

- Zero incidents caused by missing patches in the 90 days following implementation.
- Every configuration change is automatically verified within 60 seconds of `tutor config save`.
- The Tutor plugin applies all durable hook-expressible patches at template-render time, leaving only bounded filesystem sync and explicit exception handling in `apply-patches.sh`.
- CI/CD rejects any PR that would produce a configuration state missing required patches.
- An upgrade from one Tutor version to the next triggers automatic patch verification with clear pass/fail reporting before any deployment proceeds.

---

# Agent Contract

## Scope

- In scope:
  - Tutor plugin architecture for applying patches via the Tutor hook system (filters and actions)
  - Git pre-commit hook that validates patched configuration state
  - CI/CD GitHub Actions workflow for configuration integrity verification
  - Patch manifest format defining active post-render patch authority, ownership class, and retirement metadata
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

The three-layer defense system is implemented with the Tutor plugin, canonical build-context preparation path, and CI rendered verification. Remaining post-render mutations are explicitly classified in the active patch manifest and inventory.

**Current State:**
- **Layer 1 (Tutor Plugin)**: ✅ Implemented (`infrastructure/tutor/plugins/mereka_lms.py`)
- **Layer 2 (Git Hooks)**: ✅ Implemented (`.githooks/pre-tutor-config`)
- **Layer 3 (CI/CD)**: ✅ Implemented for Tutor authority changes (`.github/workflows/ci.yml`, `.github/workflows/tutor-plugin-test.yml`)

### Layer 1: Tutor Plugin Architecture

**File:** `infrastructure/tutor/plugins/mereka_lms.py`
**Size:** 555 lines
**Version:** 1.0.0

The `mereka_lms` Tutor integration implements ENV_PATCHES hooks plus tightly scoped post-render patches covering:

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
- **Hooks:** `openedx-common-assets-settings`
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
- **Hooks / patches:** `mfe-dockerfile-pre-npm-install`, `mfe-dockerfile-post-npm-install`, `patches/mfe-npm-install-resilience.sh`
- **Patches Applied:**
  - Node 24 build toolchain installation plus HTTPS git rewrite hardening
  - Local `brand-mereka` materialization at `/openedx/app/node_modules/@edx/brand`
  - Rendered production-stage runtime theme payload copy
  - `@openedx/frontend-plugin-framework` installation with legacy peer deps
  - npm install resilience (retry/fallback logic, configurable timeouts)

#### MFE Theme Patches
- **Hook:** `mfe-env-config`
- **Patches Applied:**
  - Imports Mereka theme SCSS
  - Custom Mereka footer component (React)

#### Infrastructure Configuration
- **Rendered local compose compatibility:** `infrastructure/tutor/patches/mysql-root-host.sh`
- **Patches Applied:**
  - Local `MYSQL_ROOT_HOST: "%"` so sibling Tutor containers can connect during bootstrap.
  - MySQL native password mode is currently emitted by Tutor 21.0.4 as `--mysql-native-password=ON` and is verified as a rendered contract.

- **Hook:** `caddy-caddyfile`
- **Patches Applied:**
  - Multi-domain LMS host blocks for extra domains
  - Favicon rewrite rules
  - Profile image upload size limits
  - MFE proxy configuration for profile API

Retired Nginx-era hook ownership is intentionally absent. The verifier rejects
`nginx-lms-config` and old `lms.conf` edge rewrites so Caddy remains the active
edge authority.

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

**Status:** ✅ Implemented for current Tutor-authority PRs through `ci.yml`

#### Existing Workflows

**1. `ci.yml` / Tutor Configuration Tests**
- Runs on pull requests that touch Tutor authority.
- Renders Tutor, runs the canonical patch path, then executes:
  - `tests/tutor/test_tutor_apply.sh`
  - `tests/tutor/test_verify_patches.sh`
  - `tests/tutor/test_pre_commit_hook.sh`
  - `tests/tutor/test_idempotency.sh`
  - `tests/tutor/test_edge_cases.sh`
- Blocks merge on rendered patch or manifest authority failures.

**2. `tutor-plugin-test.yml`**
- Tests plugin lifecycle (enable, disable, re-enable)
- Validates plugin loads without errors
- Checks configuration variables are set

#### Gap Analysis

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| Install Tutor and plugin in clean environment | ✅ Implemented | Both workflows install Tutor + plugin |
| Run `tutor config save` with production settings | ✅ Implemented | Both workflows generate config |
| Run canonical patch path | ✅ Implemented | `ci.yml` runs `apply-patches.sh` after Tutor render |
| Execute rendered patch verification | ✅ Implemented | `tests/tutor/test_verify_patches.sh` invokes `scripts/qa/verify-tutor-patches.sh` |
| Verify manifest authority metadata | ✅ Implemented | `tests/tutor/test_verify_patches.sh` and `test_nfr_performance.sh` parse `patch-manifest.yml` |
| Block merges on failure | ✅ Implemented | Both workflows are required checks |
| Complete within 5 minutes | ✅ Implemented | Workflows complete in ~3-4 minutes |
| Produce audit artifact | ⚠️ Partial | CI logs include detailed output; no dedicated Tutor verification artifact yet |

### Migration Path from `apply-patches.sh`

The plugin architecture enables a phased migration:

**Phase 1 (Current):**
- Plugin handles source-owned Django settings, Dockerfile hooks, and MFE runtime config where Tutor hooks can express the behavior.
- `apply-patches.sh` is a controlled compatibility layer for filesystem sync, migration guards, dependency mirror normalization, and bounded rendered-file exceptions.
- Manifest and inventory classify each remaining active patch with retirement triggers.

**Phase 2 (Target):**
- Plugin, bake/HCL, or upstream Tutor hooks own all hook-expressible build semantics.
- `apply-patches.sh` shrinks to filesystem sync plus explicitly approved temporary compatibility exceptions.

**Phase 3 (Future):**
- `apply-patches.sh` is either eliminated or remains a named, tested filesystem-sync layer only.
- No durable build semantics are hidden in post-render bash rewrites.

**Documentation:**
- Plugin README: `infrastructure/tutor/plugins/README.md`
- Implementation summary: `infrastructure/tutor/plugins/IMPLEMENTATION_SUMMARY.md`
- Migration guide: `infrastructure/tutor/MIGRATION_TO_PLUGIN.md`

### Testing & Verification

**Test Files:**
- `infrastructure/tutor/plugins/test_plugin.py`: Python syntax validation
- `infrastructure/tutor/plugins/verify-plugin.sh`: Plugin verification script
- `tests/tutor/test_verify_patches.sh`: active manifest and rendered verifier checks
- `tests/tutor/test_idempotency.sh`: double-apply stability
- `tests/tutor/test_edge_cases.sh`: rerun and rendered-verification edge cases

**Verification Commands:**
```bash
# Enable plugin
tutor plugins enable mereka_lms

# Verify plugin loaded
tutor plugins list | grep mereka_lms

# Check configuration
tutor config printvalue MEREKA_LMS_VERSION

# Verify patches applied
./scripts/infra/tutor-config-save.sh
./scripts/infra/prepare-tutor-build-context.sh --target all
./scripts/qa/verify-tutor-patches.sh
```

### Outstanding Work

1. **Artifact-grade report:** CI logs are detailed, but there is not yet a dedicated Tutor verification JSON artifact.
2. **Negative fixture depth:** Some edge-case tests remain non-destructive; dedicated fixture tests cover individual text-rewrite modules where available.
3. **Retirement work:** Temporary compatibility patches must keep shrinking as Tutor hooks, bake/HCL, or upstream templates take over.

### Known Limitations

1. **Theme file copying:** Plugin does NOT handle file copying (logos, fonts, SCSS files). These must be realized through the canonical Tutor prepare path, not by plugin hooks alone.
2. **MFE theme assets:** `mereka/theme-source` still depends on the governed build-context sync path rather than plugin hooks alone.
3. **Hook API stability:** Plugin tested with Tutor 21.0.4; may need adjustments for other versions.

---

## Requirements

### Functional

#### Layer 1: Tutor Plugin

- The system MUST implement a Tutor plugin (`mereka_lms`) that registers hooks to apply source-owned behavior at template-render time.
- The plugin MUST use Tutor's `Filters` API to modify templates before they are written to disk (e.g., `ENV_PATCHES`, `OPENEDX_DOCKERFILE_PRE_ASSETS`, `OPENEDX_LMS_PRODUCTION_SETTINGS`).
- The plugin MUST apply hook-expressible patch categories via hooks:
  - MFE Node.js version and build toolchain additions
  - Webpack memory limit (`NODE_OPTIONS=--max-old-space-size=6144`)
  - Multi-site domain additions to `ALLOWED_HOSTS` and `CSRF_TRUSTED_ORIGINS`
  - Custom Django application registration (`mfe_oauth_fix`, `openedx_prometheus`)
  - Django middleware injection (`django_prometheus`, `MFEOAuthFixMiddleware`)
  - Redwood compatibility settings (content libraries, bookmarks, discussions, theming apps)
  - MFE discussions configuration (`DISCUSSIONS_MFE_ENABLED`, `DISCUSSIONS_MICROFRONTEND_URL`)
  - Default site theme (`DEFAULT_SITE_THEME = "mereka"`)
  - Extra pip dependencies (`django-prometheus`, `pymongo[srv]`)
- The plugin MUST be synced into `TUTOR_PLUGINS_ROOT` by the canonical wrapper and enabled as `mereka_lms`.
- The plugin MUST be idempotent: applying it multiple times MUST produce identical output.
- The plugin SHOULD define a version number that is bumped when patch content changes.

#### Layer 2: Git Hooks

- The system MUST provide a pre-commit hook that warns or verifies when files under `infrastructure/tutor/` or `tutor_env/config.yml` are modified.
- The local hook SHOULD invoke the rendered patch verifier when a rendered Tutor environment is available; CI MUST be the final enforcement layer.
- The pre-commit hook MUST complete within 15 seconds on a standard development machine.
- The pre-commit hook MUST produce a clear error message listing which patches failed verification, with remediation instructions.
- The pre-commit hook SHOULD be skippable with `--no-verify` for emergencies, but the CI/CD layer MUST catch any skipped verification.

#### Layer 3: CI/CD Verification

- The system MUST include GitHub Actions coverage for Tutor authority changes through `ci.yml` and `tutor-plugin-test.yml`.
- The CI workflow MUST perform the following checks in order:
  1. Install Tutor and the Mereka plugin in a clean environment.
  2. Run `tutor config save` with production-equivalent settings.
  3. Run the canonical patch path.
  4. Execute rendered patch verification against the rendered templates.
  5. Validate the active patch manifest authority metadata and `apply-patches.sh` wiring.
- The CI workflow MUST block merges to `main` if any patch verification check fails.
- The CI workflow MUST complete within 5 minutes.
- The CI workflow SHOULD cache the Tutor virtual environment to reduce execution time.
- The CI workflow SHOULD produce an artifact containing the verification report for audit purposes.

#### Patch Manifest

- The system MUST maintain a patch manifest file (`infrastructure/tutor/patch-manifest.yml`) listing every active post-render patch with:
  - A unique identifier
  - A human-readable description
  - The target file(s) affected
  - The module and function that realize the patch
  - The authority class (`temporary_compatibility_layer`, `migration_guard`, `filesystem_sync`, or `authority_correction`)
  - A retirement trigger
  - Required status
- The patch manifest MUST be the active ledger for remaining post-render patch authority.
- Rendered pass/fail checks MAY live in dedicated verifier scripts or fixture tests rather than inline manifest commands.

#### Verification Tool

- The system MUST provide a rendered verification script (`scripts/qa/verify-tutor-patches.sh`) that checks high-signal rendered patch markers.
- The verification script MUST exit with code 0 if all patches pass and non-zero if any fail.
- The verification script MUST output clear PASS/FAIL lines naming the file or rendered marker checked.
- Machine-readable patch authority MUST be available through `patch-manifest.yml`; a dedicated JSON report is optional until artifact reporting is added.

#### Migration Path

- The system MUST support a phased migration from `apply-patches.sh` to the Tutor plugin:
  - Phase 1: Plugin handles Django settings patches and durable Dockerfile environment/build patches. `apply-patches.sh` handles file-copy, template-rewrite, and bounded rendered-file exceptions. Both run; verification checks all patches regardless of source.
  - Phase 2: Plugin handles all hook-expressible patches. `apply-patches.sh` handles only file-system operations plus explicitly documented rendered-file exceptions.
  - Phase 3: `apply-patches.sh` is reduced to file-system operations plus any still-approved explicit exception; all durable configuration-level patches are in the plugin.
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

- [ ] AC-TCR-001: Given a clean checkout of the repository, when the Mereka Tutor plugin is installed and enabled, then the plugin loads without errors and `tutor plugins list` shows `mereka_lms` as available.
  - **Status:** ✅ Implemented (plugin at `infrastructure/tutor/plugins/mereka_lms.py`, enabled via `tutor plugins enable mereka_lms`)
  - **Verification:** `.github/workflows/tutor-plugin-test.yml` tests plugin lifecycle (enable/disable/re-enable)

- [ ] AC-TCR-002: Given the Mereka plugin is enabled, when `tutor config save` is run, then the rendered `production.py` contains `academy.biji-biji.com` in `ALLOWED_HOSTS` without running `apply-patches.sh`.
  - **Status:** ✅ Implemented (via `openedx-lms-production-settings` ENV_PATCHES hook)
  - **Verification:** CI job `verify-multi-site-domains` checks ALLOWED_HOSTS (note: current job runs after `apply-patches.sh`, needs plugin-only test)

- [ ] AC-TCR-003: Given Tutor 21.0.4 renders local MySQL and the canonical patch path runs, then the rendered `docker-compose.yml` contains `mysql-native-password=ON` and `MYSQL_ROOT_HOST: "%"`.
  - **Status:** ✅ Implemented (`mysql-native-password=ON` comes from the Tutor 21 render; `MYSQL_ROOT_HOST` is the active local compatibility patch)
  - **Verification:** `scripts/qa/verify-tutor-patches.sh` and `tests/tutor/test_verify_patches.sh`

- [ ] AC-TCR-004: Given the Mereka plugin is enabled and `prepare-tutor-build-context.sh --target all` is run, when `scripts/qa/verify-tutor-patches.sh` is executed, then all high-signal rendered patch markers report PASS.
  - **Status:** ✅ Implemented
  - **Verification:** `tests/tutor/test_verify_patches.sh`

- [ ] AC-TCR-005: Given a developer modifies Tutor authority and attempts to commit, when the pre-commit hook runs, then it detects Tutor-scope changes and invokes the local verification path when available.
  - **Status:** ✅ Implemented for local hook wiring
  - **Verification:** `tests/tutor/test_pre_commit_hook.sh`

- [ ] AC-TCR-006: Given a pull request that modifies any file under Tutor authority, when the CI workflow runs, then it renders Tutor, applies the canonical patch path, validates active manifest wiring, and executes rendered patch verification.
  - **Status:** ✅ Implemented
  - **Verification:** `.github/workflows/ci.yml` Tutor Configuration Tests

- [ ] AC-TCR-007: Given `infrastructure/tutor/patch-manifest.yml` is parsed, then every active patch entry contains id, module, function, target, target_family, authority_class, description, retirement_trigger, and required status.
  - **Status:** ✅ Implemented
  - **Verification:** `tests/tutor/test_verify_patches.sh`, `tests/tutor/test_nfr_performance.sh`

- [ ] AC-TCR-008: Given a rendered Tutor environment is missing a required rendered marker checked by `scripts/qa/verify-tutor-patches.sh`, when the verifier is executed, then it emits a `[FAIL]` line and exits non-zero.
  - **Status:** ✅ Implemented for rendered verifier behavior
  - **Verification:** `scripts/qa/verify-tutor-patches.sh`; destructive clean-negative proof remains fixture/manual class

- [ ] AC-TCR-009: Given the `apply-patches.sh` script is run twice consecutively, when the rendered templates are compared, then they are byte-identical (idempotency).
  - **Status:** ✅ Implemented
  - **Verification:** `tests/tutor/test_idempotency.sh`

- [ ] AC-TCR-010: Given a Tutor version upgrade from 18.x to 21.x, when the CI workflow runs on the upgrade PR, then it reports which patches need adaptation and blocks merge until all patches pass verification.
  - **Status:** ❌ Not implemented (CI does not detect version upgrades or report patch adaptation needs)
  - **Note:** Version upgrades are manual events; CI catches failures but upgrade planning requires human judgment

- [ ] AC-TCR-011: Given an active patch remains in `patch-manifest.yml`, then it has an explicit authority class and retirement trigger.
  - **Status:** ✅ Implemented
  - **Verification:** `tests/tutor/test_verify_patches.sh`, `tests/tutor/test_nfr_performance.sh`

- [ ] AC-TCR-012: Given the `make tutor-apply` command is run, then it executes the canonical `tutor-config-save.sh` wrapper, which enables the canonical Tutor plugins, runs `tutor config save`, prepares the build context, runs verification, and then restarts services -- failing fast on any step.
  - **Status:** ✅ Implemented for wrapper wiring
  - **Verification:** `tests/tutor/test_tutor_apply.sh`

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

**Mitigation**: The rendered verifier checks for required markers in rendered output, not for string-match success in `apply-patches.sh`. If a required marker is not present in the output, verification fails. The patch manifest classifies active post-render authority and retirement triggers. Recovery: update the source hook, patch module, manifest, and verifier together, then re-verify.

### Plugin Conflicts with Third-Party Tutor Plugins

**Symptom**: Another Tutor plugin modifies the same template sections, causing conflicts or double-application; retired plugins such as `tutor-indigo` must be rejected before render.

**Mitigation**: The Mereka plugin MUST define explicit ordering dependencies using Tutor's hook priority system. Patches MUST be idempotent (check-before-apply pattern). The verification tool checks for correct final state, not for individual hook execution.

### Partial Plugin Migration (Phase 1/2)

**Symptom**: During migration, some patches are in the plugin and some in `apply-patches.sh`. A developer disables the plugin thinking `apply-patches.sh` covers everything, or vice versa.

**Mitigation**: The patch manifest records each active post-render patch module and authority class. Rendered verifier scripts and fixture tests check final output regardless of source. The `make tutor-apply` command runs the plugin render and canonical patch path.

### Verification Tool False Positive

**Symptom**: A patch verification grep pattern matches unrelated text, reporting PASS when the patch is actually missing.

**Mitigation**: Rendered verifier checks SHOULD use specific markers or dedicated fixture tests rather than single-word matches. The patch manifest SHOULD be reviewed when patches are added or modified. Integration tests SHOULD include a negative case where practical; destructive clean-negative proof may remain manual or fixture-based.

---

## Observability

### Logs

- `apply-patches.sh`: SHOULD log each patch function and result.
- `scripts/qa/verify-tutor-patches.sh`: MUST log each rendered verification check with PASS/FAIL and target file or marker.
- Tutor plugin: SHOULD log a summary line when loaded.
- CI workflow: SHOULD produce a downloadable verification report artifact with full patch verification results.

### Metrics

- `tutor_patch_verification_total` counter: Total verification runs, labeled by `result` (pass/fail) and `trigger` (pre-commit/ci/manual).
- `tutor_patch_verification_failures` counter: Total individual patch failures, labeled by check id and authority class where available.
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

### Current Operating Plan

1. Keep `infrastructure/tutor/patch-manifest.yml` limited to active post-render patch authority.
2. Keep `docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md` as the mutation ledger and retirement map.
3. Use `./scripts/infra/tutor-config-save.sh` and `./scripts/infra/prepare-tutor-build-context.sh --target all` as local front doors.
4. Use `scripts/qa/verify-tutor-patches.sh` for rendered marker checks.
5. Shrink temporary compatibility patches when Tutor hooks, bake/HCL, or upstream templates can own the behavior directly.

### Feature Flags

- The Makefile `tutor-apply` target MUST work correctly with the canonical plugin and patch path.

### Backward Compatibility

- The `make tutor-apply` command MUST continue to work identically throughout all rollout phases.
- `apply-patches.sh` MUST remain functional even when the plugin is active (both are idempotent and complementary).
- Developers who have not installed the pre-commit hook are protected by the CI layer.
- The verification tool works against rendered output, not against the method of patch application, so it is agnostic to the migration phase.

### Rollback Steps

1. **Plugin causes issues**: Disable only as an emergency diagnostic. Re-enable before closure, run the canonical prepare path, and verify with `scripts/qa/verify-tutor-patches.sh`.
2. **CI workflow blocking legitimate PRs**: Treat as a verifier or authority classification incident. File/fix the false positive and update the manifest or verifier in the same PR.
3. **Pre-commit hook too slow**: Temporarily remove hook with `pre-commit uninstall`. CI layer still provides protection.
4. **Full rollback**: Revert the specific source hook or patch module change. Do not remove the plugin, manifest, or CI guardrails as a routine rollback.

---

## Open Questions

1. Which remaining temporary compatibility patches can move to bake/HCL or Tutor hooks next?
2. What artifact format should CI publish for machine-readable Tutor verification evidence?
3. Should each temporary compatibility patch get an explicit expiry date in addition to a retirement trigger?
