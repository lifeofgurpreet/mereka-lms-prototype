---
title: "Tutor Plugin-Based Configuration Resilience"
type: "adr"
status: "accepted"
owner: "engineering"
last_updated: "2026-02-16"
links:
  related_specs:
    - "specs/tutor-configuration-resilience_spec.md"
    - "specs/tutor-configuration_spec.md"
    - "specs/ci-cd-pipeline_spec.md"
    - "specs/cross-cutting-requirements_spec.md"
    - "specs/branding-system_spec.md"
  related_adrs:
    - "docs/adr/014-mfe-branding-strategy.md"
---

# ADR-006: Tutor Plugin-Based Configuration with Three-Layer Defense

**Status**: Accepted
**Date**: 2026-02-10
**Updated**: 2026-02-16
**Deciders**: Platform Team

<!-- Last verified: 2026-02-16 -->

## Context

The Mereka Academy Open edX deployment depends on approximately 30 post-hoc patches applied to Tutor-generated templates. These patches cover critical functionality: MySQL authentication, MFE build toolchain, multi-site domain support, theme integration, custom application installation, observability instrumentation, and Redwood/Ulmo compatibility fixes.

Today, all patches live in a single Bash script (`infrastructure/tutor/apply-patches.sh`, ~1060 lines) that must be run manually after every `tutor config save`. This architecture has a fundamental design flaw: **`tutor config save` is a destructive operation that silently regenerates all templates from scratch, and nothing in the system enforces that patches are re-applied afterward.**

### Incidents Caused by This Architecture

1. **Tutor v18 to v21 upgrade (multi-site wipe)**: During the upgrade, `tutor config save` was run to regenerate templates for the new version. The operator did not run `apply-patches.sh` afterward. All multi-site domain configuration (`ALLOWED_HOSTS`, `CSRF_TRUSTED_ORIGINS`, Caddy blocks for `academy.biji-biji.com` and `skillourfuture.academy.mereka.io`) was silently removed. Users accessing via alternative domains received 400 Bad Request errors. The root cause was only identified after a manual audit of the rendered templates.

2. **Forum configuration regression**: A developer ran `tutor config save --set SOME_KEY=value` to update a single configuration value. This regenerated all templates, including the LMS production settings where MFE discussions configuration had been patched. The `DISCUSSIONS_MFE_ENABLED` and `DISCUSSIONS_MICROFRONTEND_URL` settings were lost, causing 500 errors on discussion pages.

3. **MFE authentication failure**: A CI job ran `tutor config save` to validate configuration syntax. The rendered MFE Dockerfile lost the cookie domain patches (`SESSION_COOKIE_DOMAIN`, `CSRF_COOKIE_DOMAIN`). A subsequent image build used these unpatched templates, producing MFE images that could not authenticate users across the `academyv2.mereka.io` domain.

### Root Cause Analysis

All three incidents share the same root cause: the system relies on a human or agent to remember to run `apply-patches.sh` after a destructive operation. This is a human-factors failure, not a technical one. The solution must make it **impossible** to produce an unpatched configuration, not merely **inconvenient**.

## Decision

We will implement a **three-layer defense** to prevent configuration regressions:

### Layer 1: Tutor Plugin (`tutor-plugin-mereka`)

The plugin is the PRIMARY mechanism for configuration patches. A proper Tutor plugin that uses Tutor's Python hook system (`Filters` and `Actions`) to apply configuration-level patches at template-render time. When `tutor config save` runs, the plugin's hooks fire automatically -- no manual step required. This eliminates the root cause for all patches that can be expressed as hook modifications.

Tutor provides hooks for:

- `ENV_PATCHES` (inject content into rendered environment files)
- `OPENEDX_DOCKERFILE_*` hooks (modify Dockerfile at build stages)
- `OPENEDX_LMS_PRODUCTION_SETTINGS` / `OPENEDX_CMS_PRODUCTION_SETTINGS` (inject Django settings)
- `MFE_DOCKERFILE_*` hooks (modify MFE Dockerfile)
- Various other extension points documented in the Tutor plugin API

**Scope**: Configuration patches (Django settings, Dockerfile modifications, build-time environment variables, component injection via hooks).

`apply-patches.sh` is the COMPLEMENTARY mechanism for file-system operations (asset sync, theme directory setup). Neither replaces the other; they form a two-layer system. File-copy operations (syncing theme assets, logo files, font files, custom app directories) require file-system access that occurs after template rendering and cannot be expressed as Tutor hooks.

### Layer 2: Git Pre-Commit Hook

A pre-commit hook that runs a verification tool whenever files under `infrastructure/tutor/` are modified. This catches any configuration drift before it enters the repository. The hook reads a YAML patch manifest that lists every required patch with a verification command (typically a grep pattern against the rendered template). If any verification fails, the commit is blocked with a clear error message.

### Layer 3: CI/CD Verification Workflow

A GitHub Actions workflow that runs the same verification tool in a clean environment on every push and PR. This is the last line of defense -- it catches anything missed by Layers 1 and 2, including cases where a developer bypasses the pre-commit hook with `--no-verify`.

### Why All Three Layers

| Layer | Protects Against | Limitation |
|-------|------------------|------------|
| Plugin | Forgetting to run `apply-patches.sh` after `tutor config save` | Cannot handle file-copy patches; new Tutor versions may change hook API |
| Git hook | Committing unpatched configuration to the repository | Developer can bypass with `--no-verify`; only runs when `infrastructure/tutor/` files change |
| CI/CD | Merging unpatched configuration to `main`; catching bypassed hooks | Does not prevent local development issues; adds ~3 minutes to CI |

No single layer is sufficient. The plugin eliminates the most common failure mode (forgetting to patch after config save) but cannot handle all patches. The git hook catches local mistakes but can be bypassed. The CI layer is the authoritative gate but runs too late to prevent local development friction. Together, they provide defense in depth.

## Alternatives Considered

### Option A: Wrapper Script Only (Status Quo Improvement)

Replace direct `tutor config save` invocations with a wrapper (`make tutor-apply`) that always runs `apply-patches.sh` afterward.

**Why rejected**: This is the current approach (`make tutor-apply` already exists in the Makefile). It fails because nothing prevents calling `tutor config save` directly. CI jobs, scripts, documentation examples, and developers can all bypass the wrapper. The v18-to-v21 upgrade incident happened despite the wrapper existing.

### Option B: Tutor Plugin Only (No Git Hooks or CI)

Move all patches into a Tutor plugin and rely entirely on the hook system.

**Why rejected**: Not all patches can be expressed as Tutor hooks. Theme asset syncing, logo file copying, font distribution, and custom app directory copying require file-system operations that run after template rendering. A plugin-only approach leaves these patches unprotected. Additionally, Tutor's hook API has changed between major versions (v18 to v21), so a plugin alone introduces a new class of failure: hooks silently not firing after an upgrade.

### Option C: Tutor Fork

Maintain a fork of Tutor with all patches baked into the templates.

**Why rejected**: A fork creates a permanent maintenance burden. Every upstream Tutor release requires merging changes into the fork. The Tutor project releases 4-6 minor versions per year, each potentially touching the templates we patch. A fork also prevents using Tutor's plugin ecosystem, since third-party plugins expect unmodified Tutor.

### Option D: Replace Tutor Entirely

Use a custom deployment tool (Helm charts, raw Docker Compose) instead of Tutor.

**Why rejected**: Tutor provides substantial value: it manages the complex interdependencies between 10+ Open edX services, handles configuration generation for MySQL, MongoDB, Redis, Caddy, and application settings, and provides an upgrade path between Open edX releases. Replacing Tutor would require reimplementing all of this infrastructure. The cost far exceeds the benefit of eliminating the patching problem.

### Option E: Upstream All Patches to Tutor

Contribute all patches upstream to the Tutor project so they become part of the default template.

**Why not primary approach**: Some patches are Mereka-specific (multi-site domains, custom theme, custom apps) and would not be accepted upstream. Other patches (MySQL auth fix, MFE Node version) could be upstreamed but the Tutor project has its own release cadence. Upstreaming is a complementary strategy, not a replacement for local resilience. The spec tracks upstream contribution as a non-goal for this iteration but the plugin architecture makes upstreaming easier by clearly separating Mereka-specific patches from general fixes.

## Consequences

### Positive

- Eliminates the class of outages caused by forgetting to run `apply-patches.sh` after `tutor config save`.
- Makes configuration state machine-verifiable at three points: render time (plugin), commit time (hook), and merge time (CI).
- The patch manifest creates a single source of truth for all required patches, making audits and onboarding straightforward.
- The plugin architecture makes Tutor version upgrades safer: the verification tool immediately reports which patches need adaptation.
- Reduces the 1060-line `apply-patches.sh` to a focused file-copy script, improving maintainability.
- The verification tool provides clear, actionable output when something fails, reducing mean time to recovery.

### Negative

- Adds complexity: three layers instead of one script.
- The Tutor plugin requires understanding Tutor's hook API, which is less documented than Bash scripting.
- The CI verification workflow adds approximately 3 minutes to every PR.
- Maintaining the patch manifest requires discipline -- every new patch must be added to the manifest with a verification command.
- The plugin may need updates when Tutor changes its hook API between major versions (though the verification layer catches this automatically).

### Risks

- **Plugin API instability**: Tutor's hook API changed between v18 and v21. If it changes again, the plugin will need updating. Mitigation: the verification layer catches this, and `apply-patches.sh` remains as a fallback.
- **Manifest drift**: The patch manifest could fall out of sync with actual patches. Mitigation: the CI workflow verifies manifest completeness; adding a patch to `apply-patches.sh` without updating the manifest causes CI failure.
- **Developer friction**: Pre-commit hooks can slow down development. Mitigation: the hook only runs when `infrastructure/tutor/` files change, and it completes in under 15 seconds.

## Lessons Learned from Tutor v18 to v21 Upgrade

1. **Destructive operations must be self-healing**: `tutor config save` silently destroys all patches. The only safe response is to make patch application automatic (Layer 1) and verifiable (Layers 2-3).
2. **Manual runbook steps will be skipped**: The upgrade runbook said "run apply-patches.sh after config save". It was skipped. Checklists and documentation are not sufficient for critical operations.
3. **Verification must test output, not process**: Checking whether `apply-patches.sh` ran is insufficient. The verification tool checks whether the rendered templates contain the expected content, regardless of how the content got there.
4. **Version upgrades are the highest-risk configuration change**: The v18-to-v21 upgrade changed template structure, hook API, and file paths simultaneously. The patch manifest's per-patch verification is the only reliable way to know what survived the upgrade and what did not.
5. **Idempotency is non-negotiable**: Every patch, whether applied by plugin or script, must be safe to apply repeatedly. The v21 upgrade caused double-application of some patches because `apply-patches.sh` lacked idempotency guards for all code paths.

## Implementation Notes

- Plugin location: `infrastructure/tutor/tutor-plugin-mereka/`
- Patch manifest: `infrastructure/tutor/patch-manifest.yml`
- Verification tool: `scripts/infra/verify-tutor-patches.sh`
- CI workflow: `.github/workflows/verify-tutor-config.yml`
- Pre-commit hook: `.pre-commit-config.yaml` (local hook entry)
- Related spec: `specs/tutor-configuration-resilience_spec.md`
- Related spec (patch content): `specs/tutor-configuration_spec.md`

# Change Log

- 2026-02-10: Initial proposal drafted based on analysis of v18-to-v21 upgrade failure and recurring patch-skip incidents.
