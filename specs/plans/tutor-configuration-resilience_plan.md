---
spec: tutor-configuration-resilience_spec.md
tier: 0
status: draft
estimated_effort: "8-12 weeks (1-2 engineers)"
owner: engineering
last_updated: "2026-02-10"
---

# Implementation Plan: Tutor Configuration Resilience and Patch Automation

**Source Spec**: `specs/tutor-configuration-resilience_spec.md`
**Tier**: 0 (Foundations -- configuration integrity underpins all other specs)
**Status**: Draft

---

## Summary

This plan implements a three-layered defense system against Tutor configuration regressions:

1. **Layer 1 -- Tutor Plugin** (`tutor-plugin-mereka`): Applies critical patches at template-render time via Tutor hooks, eliminating the need to run `apply-patches.sh` for hook-expressible patches.
2. **Layer 2 -- Git Hooks**: Pre-commit hook blocks commits when Tutor config changes fail patch verification.
3. **Layer 3 -- CI/CD Workflow**: GitHub Actions workflow validates configuration integrity on every push and PR.

A **patch manifest** (`patch-manifest.yml`) serves as the single source of truth for what constitutes a fully-patched configuration.

### Implementation Status Assessment

Significant implementation has already been completed by prior agents. Below is the current state:

| Component | File | Status | Notes |
|-----------|------|--------|-------|
| Tutor plugin (Layer 1) | `infrastructure/tutor/plugins/mereka_lms.py` | **IMPLEMENTED** | Full plugin with Django settings, Dockerfile, MFE, Caddy, nginx, MySQL patches via Tutor hooks |
| Verification script | `scripts/infra/verify-tutor-config.sh` | **IMPLEMENTED** | Comprehensive 370-line script checking all patch categories |
| Safe config wrapper | `scripts/infra/tutor-config-save.sh` | **IMPLEMENTED** | Backs up config, runs config save, applies patches, verifies |
| Pre-tutor-config hook | `.githooks/pre-tutor-config` | **IMPLEMENTED** | Interactive hook for tutor_env file commits |
| CI config verify | `.github/workflows/tutor-config-verify.yml` | **IMPLEMENTED** | 4-job workflow: patches, multi-site, enterprise, idempotency |
| CI plugin tests | `.github/workflows/tutor-plugin-test.yml` | **IMPLEMENTED** | 5-job workflow: plugin syntax, lifecycle, structure, lint, integration |
| apply-patches.sh | `infrastructure/tutor/apply-patches.sh` | **IMPLEMENTED** | 1066-line comprehensive patch script |
| Makefile targets | `Makefile` | **IMPLEMENTED** | `tutor-apply`, `tutor-verify` targets |
| Patch manifest | `infrastructure/tutor/patch-manifest.yml` | **NOT IMPLEMENTED** | Spec requires YAML manifest as single source of truth |
| verify-tutor-patches.sh | `scripts/infra/verify-tutor-patches.sh` | **NOT IMPLEMENTED** | Spec requires manifest-driven verification with `--json` and `--fix` flags |
| tutor-plugin-mereka package | `infrastructure/tutor/tutor-plugin-mereka/` | **NOT IMPLEMENTED** | Spec requires installable package (`pip install -e`) vs current single-file plugin |
| Pre-commit hook (spec) | `.githooks/pre-commit` | **PARTIAL** | Existing hook does secret scanning only; spec requires Tutor config verification on `infrastructure/tutor/` changes |
| Compatibility matrix | None | **NOT IMPLEMENTED** | Tutor 18.x vs 21.x support documentation |

---

## Prerequisites

| Prerequisite | Status | Notes |
|-------------|--------|-------|
| Repository structure spec approved | Done | `repository-structure_spec.md` |
| `apply-patches.sh` exists | Done | 1066-line comprehensive script |
| Tutor plugin exists | Done | `mereka_lms.py` with all hook categories |
| CI workflows exist | Done | Two workflows covering config verify + plugin tests |
| Verification script exists | Done | `verify-tutor-config.sh` with 30+ checks |
| Python venv with Tutor | Done | `.venv/` with Tutor installed |

---

## Task Breakdown

### Build

- [ ] **[L] Task B-1: Create patch manifest (`infrastructure/tutor/patch-manifest.yml`)** | AC: AC-TCR-004, AC-TCR-007, AC-TCR-008, AC-TCR-011 | Depends: None
  - **Description**: Catalog every required patch into a YAML manifest. Each entry needs: unique ID, human-readable description, target file(s), verification command (grep pattern or script), responsible layer (plugin / apply-patches.sh / both), severity level (critical/high/medium/low). Derive the patch list from the current `verify-tutor-config.sh` checks and `apply-patches.sh` operations.
  - **Estimated patches**: ~30 entries across categories: MySQL auth, MFE toolchain, webpack memory, multi-site domains, custom apps, Django middleware, Redwood compat, MFE discussions, default theme, extra pip deps, Caddy config, nginx config, asset build fixes, theme assets.
  - **Done definition**: YAML file passes `yamllint` and contains all patches currently verified by `verify-tutor-config.sh`. Each entry has all required fields.
  - **Complexity**: L (8-12h) -- requires auditing both `apply-patches.sh` and `mereka_lms.py` to enumerate every patch and write verification commands.

- [ ] **[L] Task B-2: Create manifest-driven verification tool (`scripts/infra/verify-tutor-patches.sh`)** | AC: AC-TCR-004, AC-TCR-007, AC-TCR-008, AC-TCR-011 | Depends: B-1
  - **Description**: Write a shell script that reads `patch-manifest.yml`, executes each verification command against the rendered `tutor_env/`, and reports per-patch pass/fail status. Must support `--json` flag for machine-readable output and `--fix` flag to run `apply-patches.sh` then re-verify. Must exit 0 if all pass, non-zero otherwise. Critical failures must display red/bold formatting with remediation steps. Output must include a summary table with columns: Patch ID, Description, Status, Target File, Severity.
  - **Done definition**: `./scripts/infra/verify-tutor-patches.sh` reports all patches from manifest. `--json` outputs valid JSON array. `--fix` re-applies patches and re-verifies. Exits non-zero on any failure.
  - **Complexity**: L (8-12h) -- YAML parsing in shell (using `yq` or Python helper), per-patch execution, JSON output, terminal formatting.

- [ ] **[M] Task B-3: Package plugin as installable package (`infrastructure/tutor/tutor-plugin-mereka/`)** | AC: AC-TCR-001 | Depends: None
  - **Description**: Convert the existing `mereka_lms.py` single-file plugin into a proper pip-installable package with `setup.py`/`pyproject.toml`, so it can be installed via `pip install -e ./infrastructure/tutor/tutor-plugin-mereka`. The package should register itself as a Tutor plugin entry point. Move `mereka_lms.py` into the package as the main module. Add version number (`__version__`). Ensure `tutor plugins list` shows `mereka_lms` (or `mereka`) as available after installation.
  - **Done definition**: `pip install -e ./infrastructure/tutor/tutor-plugin-mereka` succeeds. `tutor plugins list` shows the plugin. `tutor plugins enable mereka_lms && tutor config save` produces patched templates.
  - **Complexity**: M (4-6h) -- packaging boilerplate + entry point registration + testing.

- [ ] **[M] Task B-4: Integrate pre-commit hook with Tutor config verification** | AC: AC-TCR-005 | Depends: B-2
  - **Description**: Extend the existing `.githooks/pre-commit` secret scanning hook to also run `verify-tutor-patches.sh` when staged files include anything under `infrastructure/tutor/` or `tutor_env/config.yml`. Must complete within 15 seconds. Must produce clear error messages listing which patches failed, with remediation instructions. Must be skippable with `--no-verify`.
  - **Done definition**: Committing a change to `infrastructure/tutor/apply-patches.sh` triggers patch verification. Verification failure blocks the commit with actionable error output. Hook completes in <15 seconds.
  - **Complexity**: M (3-5h) -- integrate with existing hook, add file-path matching, performance constraints.

- [ ] **[M] Task B-5: Upgrade CI workflow to use manifest-driven verification** | AC: AC-TCR-006, AC-TCR-010 | Depends: B-1, B-2
  - **Description**: Refactor `.github/workflows/tutor-config-verify.yml` to: (1) install the Mereka plugin package, (2) run `tutor config save`, (3) run `apply-patches.sh`, (4) run `verify-tutor-patches.sh`, (5) report per-patch pass/fail. Must complete within 5 minutes. Must cache the Tutor venv. Must produce a downloadable verification report artifact. Must block merges to `main` on any patch failure. Add handling for Tutor version upgrade PRs that reports which patches need adaptation.
  - **Done definition**: CI workflow uses `verify-tutor-patches.sh` instead of inline grep checks. Produces verification report artifact. Completes in <5 minutes. Blocks merge on failure.
  - **Complexity**: M (4-6h) -- refactor existing workflow, add artifact upload, caching, plugin install step.

- [ ] **[S] Task B-6: Update `make tutor-apply` to execute full pipeline** | AC: AC-TCR-012 | Depends: B-2, B-3
  - **Description**: Update the Makefile `tutor-apply` target to: (1) run `tutor config save`, (2) enable the Mereka plugin, (3) run `apply-patches.sh`, (4) run `verify-tutor-patches.sh`, (5) restart services. Fail fast on any step.
  - **Done definition**: `make tutor-apply` executes all 5 steps in order. Any step failure aborts the pipeline.
  - **Complexity**: S (1-2h) -- Makefile edits.

- [ ] **[S] Task B-7: Add `--verify` self-test mode to `apply-patches.sh`** | AC: AC-TCR-009 | Depends: B-2
  - **Description**: Add a `--verify` flag to `apply-patches.sh` that runs the script twice and diffs the rendered output to confirm idempotency. Also add logging: each patch application must log timestamp, patch ID, target file, and result (applied/skipped/already-present).
  - **Done definition**: `./infrastructure/tutor/apply-patches.sh --verify` runs twice, diffs output, and reports pass/fail.
  - **Complexity**: S (2-3h) -- add flag parsing and diff logic.

- [ ] **[S] Task B-8: Create Tutor version compatibility matrix** | AC: (Migration requirement) | Depends: B-3
  - **Description**: Document which plugin versions support which Tutor versions (18.x, 21.x) in a markdown table within the plugin package. Include hook API differences between versions.
  - **Done definition**: File `infrastructure/tutor/tutor-plugin-mereka/COMPATIBILITY.md` exists with version matrix.
  - **Complexity**: S (1-2h) -- documentation.

### Test

- [ ] **[M] Task T-1: Unit tests for `verify-tutor-patches.sh`** (`tests/tutor/test_verify_patches.sh`) | AC: AC-TCR-004, AC-TCR-007, AC-TCR-008, AC-TCR-011 | Depends: B-1, B-2
  - **Description**: Write shell-based tests (using `bats` or raw bash) that verify the manifest-driven verification tool: (1) all patches PASS on a correctly patched config, (2) all critical patches FAIL on unpatched config, (3) `--json` output is valid JSON, (4) critical failure output includes severity and remediation, (5) exit codes are correct.
  - **Done definition**: Test suite passes with both positive (patched) and negative (unpatched) test fixtures.
  - **Complexity**: M (4-6h) -- create test fixtures (patched vs unpatched tutor_env snapshots), implement test runner.

- [ ] **[M] Task T-2: Integration tests for plugin + apply-patches.sh** (`tests/tutor/test_plugin_integration.sh`) | AC: AC-TCR-002, AC-TCR-003, AC-TCR-004 | Depends: B-3
  - **Description**: Write integration tests that: (1) install the plugin, (2) enable it, (3) run `tutor config save`, (4) verify plugin patches are present in rendered templates without running `apply-patches.sh`, (5) run `apply-patches.sh`, (6) verify all patches pass. This validates that plugin and script work together and independently.
  - **Done definition**: Test passes in CI. Verifies plugin-only patches (AC-TCR-002, AC-TCR-003) and combined patches (AC-TCR-004).
  - **Complexity**: M (4-6h) -- requires Tutor installation in test environment.

- [ ] **[M] Task T-3: Idempotency tests** (`tests/tutor/test_idempotency.sh`) | AC: AC-TCR-009 | Depends: None (tests existing apply-patches.sh)
  - **Description**: Write tests that run `apply-patches.sh` twice and diff rendered output to confirm byte-identical results. Cover all target files (Docker Compose, Dockerfiles, Python settings, Caddyfile, nginx config).
  - **Done definition**: Checksums of all rendered files match between first and second run. Test captures and reports any differences.
  - **Complexity**: M (3-4h) -- requires Tutor config generation + dual patch application.

- [ ] **[S] Task T-4: Pre-commit hook tests** (`tests/tutor/test_pre_commit_hook.sh`) | AC: AC-TCR-005 | Depends: B-4
  - **Description**: Test that modifying `infrastructure/tutor/apply-patches.sh` and attempting to commit triggers verification. Test that failed verification blocks the commit. Test that `--no-verify` bypasses the hook.
  - **Done definition**: Test creates a temporary git repo, modifies tutor files, and verifies hook behavior.
  - **Complexity**: S (2-3h) -- git repo setup in test.

- [ ] **[M] Task T-5: CI workflow end-to-end test** | AC: AC-TCR-006, AC-TCR-010 | Depends: B-5
  - **Description**: Create a manual workflow dispatch test that validates the full CI verification pipeline. Include a test PR that deliberately breaks a patch to verify the workflow catches it and blocks merge.
  - **Done definition**: Workflow dispatch succeeds. Broken-patch test PR is correctly rejected by CI.
  - **Complexity**: M (3-5h) -- GitHub Actions workflow testing.

- [ ] **[S] Task T-6: Plugin installation and lifecycle tests** (`tests/tutor/test_plugin_lifecycle.py`) | AC: AC-TCR-001 | Depends: B-3
  - **Description**: Test `pip install -e`, `tutor plugins list`, `tutor plugins enable`, `tutor plugins disable`, and `tutor plugins enable` (re-enable) lifecycle. Verify plugin metadata (__version__).
  - **Done definition**: All lifecycle operations succeed. Plugin appears in `tutor plugins list` after install.
  - **Complexity**: S (2-3h) -- extend existing CI workflow tests.

- [ ] **[S] Task T-7: Negative tests for unpatched config** (`tests/tutor/test_unpatched_config.sh`) | AC: AC-TCR-008 | Depends: B-2
  - **Description**: Run `tutor config save` WITHOUT the plugin AND without `apply-patches.sh`, then run `verify-tutor-patches.sh`. Verify all critical patches report FAIL and exit code is non-zero.
  - **Done definition**: All critical patches fail. Non-critical patches may pass or fail (both acceptable). Exit code is non-zero.
  - **Complexity**: S (2-3h) -- straightforward negative test.

### Observability

- [ ] **[M] Task O-1: Add metrics instrumentation** | AC: (Observability requirements) | Depends: B-2
  - **Description**: Implement Prometheus metrics: `tutor_patch_verification_total` (counter, labeled by result and trigger), `tutor_patch_verification_failures` (counter, labeled by patch_id and severity), `tutor_config_save_duration_seconds` (histogram), `tutor_patches_applied_total` (gauge, labeled by layer). Emit metrics from `verify-tutor-patches.sh` to a Prometheus pushgateway or textfile collector.
  - **Done definition**: Metrics appear in Prometheus after running verification. Dashboard queries return data.
  - **Complexity**: M (4-6h) -- metrics emission from shell scripts, pushgateway integration.

- [ ] **[M] Task O-2: Add Slack alerting for CI failures** | AC: (Alert requirements) | Depends: B-5
  - **Description**: Configure CI workflow to send Slack alert to `#ops-alerts` when verification fails on `main` branch. Add drift detection alert if `verify-tutor-patches.sh` has not run successfully in 7 days.
  - **Done definition**: Slack notification fires on CI failure on main. Drift alert fires after 7-day gap.
  - **Complexity**: M (3-5h) -- Slack webhook integration, scheduled workflow for drift detection.

- [ ] **[S] Task O-3: Add structured logging to apply-patches.sh and verify-tutor-patches.sh** | AC: (Logging requirements) | Depends: B-1, B-2
  - **Description**: Add per-patch logging with timestamp, patch ID, target file, and result. Plugin must log summary line after `tutor config save`. CI must produce downloadable verification report artifact.
  - **Done definition**: Logs include all required fields. CI artifact contains full verification report.
  - **Complexity**: S (2-3h) -- logging format additions.

- [ ] **[M] Task O-4: Create patch compliance dashboard** | AC: (Dashboard requirements) | Depends: O-1
  - **Description**: Create Grafana dashboard showing: patches by layer, verification pass rate over time, last successful verification timestamp, patches pending migration to plugin. Create CI workflow dashboard showing: run frequency, failure rate, mean execution time.
  - **Done definition**: Dashboard panels render correctly with sample data. Prometheus queries return expected metrics.
  - **Complexity**: M (4-6h) -- Grafana dashboard JSON + Prometheus queries.

### Docs

- [ ] **[S] Task D-1: Update developer onboarding guide** (`docs/onboarding/DEVELOPER_ONBOARDING.md`) | AC: (Rollout) | Depends: B-3, B-4
  - **Description**: Add section on pre-commit hook installation, plugin usage, and `make tutor-apply` workflow. Include troubleshooting for common hook failures.
  - **Done definition**: Onboarding guide includes Tutor config resilience section with clear step-by-step instructions.
  - **Complexity**: S (1-2h).

- [ ] **[S] Task D-2: Create patch manifest maintenance guide** (`docs/operations/PATCH_MANIFEST_GUIDE.md`) | AC: (Rollout) | Depends: B-1
  - **Description**: Document how to add, modify, and remove patches from the manifest. Include examples for each severity level. Document the verification command format.
  - **Done definition**: Guide covers full CRUD lifecycle for patch manifest entries.
  - **Complexity**: S (1-2h).

- [ ] **[S] Task D-3: Create migration runbook** (`docs/operations/TUTOR_PLUGIN_MIGRATION_RUNBOOK.md`) | AC: (Migration requirements) | Depends: B-3
  - **Description**: Document the phased migration from `apply-patches.sh` to the Tutor plugin. Include rollback steps for each phase. Document the compatibility matrix.
  - **Done definition**: Runbook covers Phase 1-3 migration with rollback procedures and version compatibility.
  - **Complexity**: S (2-3h).

- [ ] **[S] Task D-4: Update troubleshooting guide** (`docs/operations/TROUBLESHOOTING.md`) | AC: (Rollout) | Depends: B-2
  - **Description**: Add section on patch verification failures with symptom-to-fix mapping. Include CI bypass instructions for emergencies.
  - **Done definition**: Troubleshooting guide includes patch-related failure scenarios.
  - **Complexity**: S (1-2h).

- [ ] **[S] Task D-5: Update ADR for plugin-based configuration** (`docs/adr/006-tutor-plugin-based-configuration.md`) | AC: (Rollout) | Depends: B-3
  - **Description**: Update or create ADR documenting the decision to use a Tutor plugin for configuration management, the three-layer defense architecture, and the rationale for phased migration.
  - **Done definition**: ADR documents the architectural decision with context, decision, and consequences.
  - **Complexity**: S (1-2h).

### Rollout

- [ ] **[S] Task R-1: Phase 1 -- Verification infrastructure** | AC: AC-TCR-004, AC-TCR-007, AC-TCR-008, AC-TCR-011 | Depends: B-1, B-2 | Timeline: Week 1-2
  - **Description**: Deploy patch manifest and manifest-driven verification tool. Run verification manually to baseline current coverage.
  - **Done definition**: `verify-tutor-patches.sh` runs successfully against current config. All patches cataloged in manifest.
  - **Complexity**: S (included in B-1, B-2).

- [ ] **[S] Task R-2: Phase 2 -- CI integration** | AC: AC-TCR-006 | Depends: B-5 | Timeline: Week 3
  - **Description**: Deploy updated CI workflow. Configure as required check for PRs touching `infrastructure/tutor/`. Extend to all PRs after confidence period.
  - **Done definition**: CI workflow runs on tutor-related PRs. Required check configured in GitHub branch protection.
  - **Complexity**: S (included in B-5).

- [ ] **[S] Task R-3: Phase 3 -- Git hooks** | AC: AC-TCR-005 | Depends: B-4 | Timeline: Week 4
  - **Description**: Deploy updated pre-commit hook. Document installation in onboarding guide.
  - **Done definition**: Hook active for all developers. Documented in onboarding guide.
  - **Complexity**: S (included in B-4, D-1).

- [ ] **[S] Task R-4: Phase 4 -- Plugin packaging** | AC: AC-TCR-001, AC-TCR-002, AC-TCR-003 | Depends: B-3 | Timeline: Week 5-8
  - **Description**: Deploy packaged plugin. Migrate patches incrementally. Verify plugin and script produce identical results after each batch.
  - **Done definition**: Plugin installable via `pip install -e`. Patches verified after migration.
  - **Complexity**: S (included in B-3).

- [ ] **[S] Task R-5: Phase 5 -- Stabilization** | AC: All | Depends: All | Timeline: Week 9-12
  - **Description**: Monitor CI pass rate for 4 weeks. Reduce `apply-patches.sh` to file-system operations only. Update documentation.
  - **Done definition**: 4 weeks with zero configuration-regression incidents. Documentation updated.
  - **Complexity**: S (monitoring + documentation).

---

## Dependency Graph

```
B-1 (patch manifest)
  |
  +---> B-2 (verify-tutor-patches.sh) ---> B-4 (pre-commit hook) ---> T-4 (hook tests)
  |       |                                                            |
  |       +---> B-5 (CI workflow) ---> T-5 (CI e2e test)              +---> R-3
  |       |       |
  |       |       +---> R-2
  |       |       +---> O-2 (Slack alerts)
  |       |
  |       +---> B-6 (Makefile update)
  |       +---> B-7 (idempotency self-test)
  |       +---> T-1 (verification tests)
  |       +---> T-7 (negative tests)
  |       +---> O-1 (metrics) ---> O-4 (dashboard)
  |       +---> O-3 (logging)
  |       +---> D-2 (manifest guide)
  |       +---> D-4 (troubleshooting)
  |
  +---> R-1

B-3 (plugin package) ---> T-2 (integration tests)
  |                         |
  +---> T-6 (lifecycle)     +---> R-4
  +---> B-6 (Makefile)
  +---> B-8 (compat matrix)
  +---> D-1 (onboarding)
  +---> D-3 (migration runbook)
  +---> D-5 (ADR update)

T-3 (idempotency tests) ---> standalone (no deps)
```

---

## Risk Register

| Risk | Mitigation |
|------|------------|
| `yq` not available in CI runner | Use Python YAML parser as fallback; or vendor `yq` binary |
| Plugin hook API changes between Tutor 18.x and 21.x | Compatibility matrix (B-8); conditional hook registration in plugin |
| Pre-commit hook too slow (>15s) | Cache verification results; only re-verify changed patches |
| False positives in verification grep patterns | Use multi-line specific patterns; include negative test case (T-7) |
| Concurrent `tutor config save` races | Add `flock` to `make tutor-apply` wrapper |

---

## Self-Check

- [x] Every acceptance criterion (AC-TCR-001 through AC-TCR-012) has at least one build task
- [x] Every acceptance criterion has at least one test case
- [x] Every edge case in the spec has coverage in the test plan
- [x] File paths specified for each task
- [x] Dependencies identified for all tasks
- [x] Complexity estimated (S/M/L) for each task
- [x] Source spec linked in header
