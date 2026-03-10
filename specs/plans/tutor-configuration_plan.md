---
spec: tutor-configuration_spec.md
tier: 0
status: draft
estimated_effort: "3-5 days (1 engineer)"
owner: engineering
last_updated: "2026-02-10"
---

# Implementation Plan: Tutor Configuration Lifecycle

**Source Spec**: `specs/tutor-configuration_spec.md`
**Tier**: 0 (Foundations -- all other specs depend on this)
**Status**: Draft

---

## Summary

This plan codifies the Tutor configuration save-patch-restartworkflow into verifiable, automated gates. The bulk of the infrastructure already exists (`apply-patches.sh`, `tutor-env.sh`, existing QA scripts). The work is primarily about **hardening, automating verification, and closing coverage gaps** rather than building from scratch.

Key deliverables:
1. A dedicated `verify-tutor-patches.sh` script that checks all 10 acceptance criteria
2. A CI job that validates patch script syntax and idempotency
3. A wrapper script or Makefile guard to prevent `tutor config save` without subsequent `apply-patches.sh`
4. Documentation updates linking the spec to runbooks

---

## Prerequisites

| Prerequisite | Status | Notes |
|-------------|--------|-------|
| Repository structure spec approved | Done | `repository-structure_spec.md` is APPROVED |
| `apply-patches.sh` exists | Done | 55KB, comprehensive patch script |
| `tutor-env.sh` exists | Done | Sets TUTOR_ROOT, activates venv |
| CI pipeline exists | Done | `.github/workflows/ci.yml` with`validate-tutor-config` job |
| QA scripts directory exists | Done | 60+ scripts in `scripts/qa/` |
| Python venv with Tutor installed | Done | `.venv/` with Tutor v21 |

---

## Task Breakdown

### Build

- [ ] **[M] Task 1: Create `scripts/qa/verify-tutor-patches.sh` verification script** (`scripts/qa/verify-tutor-patches.sh`) | AC: #1, #2, #3, #4, #5 | Depends: None
  - **Description**: Write a shell script that verifies all five grep-based acceptance criteria (AC-001 through AC-005) against the rendered tutor_env files. The script should outputpass/fail for each check and exit non-zero if any fail.
  - **Done definition**: Running `./scripts/qa/verify-tutor-patches.sh` on a fresh `tutor config save && apply-patches.sh`output returns exit 0 with all 5 checks passing.
  - **Complexity**: M (2-4h) -- grep patterns already definedin spec, need to structure as reusable script with proper error handling.

- [ ] **[S] Task 2: Add idempotency guard to `apply-patches.sh`** (`infrastructure/tutor/apply-patches.sh`) | AC: NFR (idempotency) | Depends: None
  - **Description**: Verify that `apply-patches.sh` already produces identical output when run twice consecutively. If not, add guards (e.g., check-before-patch patterns, `sed` idempotent replacements). Add a self-test mode (`--verify`) that runs the script twice and diffs the output.
  - **Done definition**: `apply-patches.sh && cp -r tutor_env/env /tmp/first && apply-patches.sh && diff -r tutor_env/env/tmp/first` shows no differences.
  - **Complexity**: S (1-2h) -- mostly verification, the script already uses pattern matching that should be idempotent.

- [ ] **[M] Task 3: Create `scripts/qa/verify-tutor-services.sh` service health checker** (`scripts/qa/verify-tutor-services.sh`) | AC: #7, #10 | Depends: None
  - **Description**: Write a script that verifies MySQL connections succeed without auth errors (AC-007) and that all services show "Up" status (AC-010). Reuse patterns from existing`scripts/qa/verify-setup.sh` but focus specifically on post-patch service health.
  - **Done definition**: Script verifies MySQL auth works and`tutor local dc ps` shows all services Up. Exits non-zero onany failure.
  - **Complexity**: M (2-4h) -- need to handle Docker not running gracefully, merge with existing verify-setup.sh patterns.

- [ ] **[S] Task 4: Add config-save wrapper to enforce patchapplication** (`infrastructure/tutor/tutor-config-save.sh`) |AC: Workflow requirement, Edge Case (forgetting patches) | Depends: None
  - **Description**: Create a wrapper script `tutor-config-save.sh` that runs `tutor config save "$@"`, then automaticallyruns `apply-patches.sh`, then optionally restarts services.This prevents the "forgot to run patches" failure mode. Update `Makefile` target `tutor-apply` to use this wrapper.
  - **Done definition**: Running `./infrastructure/tutor/tutor-config-save.sh --set KEY=value` executes config save, patches, and optionally restarts. `make tutor-apply` calls the wrapper.
  - **Complexity**: S (1-2h) -- simple wrapper script.

- [ ] **[S] Task 5: Add local service name validation to `apply-patches.sh`** (`infrastructure/tutor/apply-patches.sh`) |AC: Workflow requirement (no cloud IPs) | Depends: None
  - **Description**: Add a post-patch validation step to `apply-patches.sh` that checks `tutor_env/config.yml` for cloud IP patterns (`10.97.x.x`) and warns/fails if found. This catches the "cloud IPs in local config" edge case before servicesstart.
  - **Done definition**: `apply-patches.sh` exits with a warning (stderr) if cloud IPs are detected in config.yml during alocal deployment.
  - **Complexity**: S (<1h) -- simple grep check appended toexisting script.

- [ ] **[M] Task 6: Create MFE build verification script** (`scripts/qa/verify-mfe-build-contract.sh`) | AC: #6 | Depends:None
  - **Description**: Write a script that verifies the MFE Dockerfile contains Node 18 base image, the required build tools, npm retry configuration, and the 6144MB memory limit. Thisproves AC-006 without requiring a full image build.
  - **Done definition**: Script checks rendered `tutor_env/env/plugins/mfe/build/mfe/Dockerfile` for Node 18, build tools,npm retries, and NODE_OPTIONS. Exits non-zero if any check fails.
  - **Complexity**: M (2-3h) -- need to parse Dockerfile patterns carefully.

- [ ] **[S] Task 7: Create multi-site domain verification script** (`scripts/qa/verify-tutor-multisite-domains.sh`) | AC:#8 | Depends: None
  - **Description**: Extend or create a verification script that checks all three production domains are present in ALLOWED_HOSTS and CSRF_TRUSTED_ORIGINS in the rendered LMS settings. Note: AC-008 also requires live domain resolution which iscovered by the existing `scripts/qa/smoke-test.sh`.
  - **Done definition**: Script verifies all three domains inrendered settings files. References `smoke-test.sh` for liveverification.
  - **Complexity**: S (1-2h) -- grep-based checks similar toAC-001 through AC-005.

- [ ] **[S] Task 8: Create branding render verification script** (`scripts/qa/verify-tutor-branding-render.sh`) | AC: #9 |Depends: None
  - **Description**: Write a script that verifies the Merekalogo and custom footer component are configured in the rendered Tutor templates. This checks the theme directory structure, logo file presence, and MFE footer configuration without requiring a running instance. For live verification, referenceexisting `scripts/branding/verify-branding-health.sh`.
  - **Done definition**: Script verifies theme assets are synced, logo variants exist in build directory, and MFE footer configuration is present. Exits non-zero on failure.
  - **Complexity**: S (1-2h) -- leverages existing branding health check.

### Test

- [ ] **[M] Task 9: Add `verify-tutor-patches` to CI workflow** (`.github/workflows/ci.yml`) | AC: #1-#5 (CI automation) |Depends: Task 1
  - **Description**: Add a new CI job `tutor-patch-contract`that runs `scripts/qa/verify-tutor-patches.sh` in offline mode (checking script syntax, pattern correctness, grep contracts against example/template files). Since CI cannot run the full Tutor stack, verify the script syntax and test against committed example files.
  - **Done definition**: CI job runs on every PR, validates patch verification script syntax, and checks patterns againstcommitted config examples.
  - **Complexity**: M (2-4h) -- need to handle CI environmentlimitations (no Tutor installed).

- [ ] **[M] Task 10: Create patch idempotency test** (`scripts/qa/test-patch-idempotency.sh`) | AC: NFR (idempotency) | Depends: Task 2
  - **Description**: Write a test script that runs `apply-patches.sh` twice on the same tutor_env and verifies the outputis byte-identical. This validates the NFR that running patches multiple times produces identical output.
  - **Done definition**: Script runs patches twice, diffs output, exits 0 if identical, exits 1 with diff output if not.
  - **Complexity**: M (2-3h) -- requires local Tutor environment to run; document as manual/local test.

- [ ] **[S] Task 11: Add patch timing assertion** (`scripts/qa/verify-tutor-patches.sh`) | AC: NFR (30s execution time) |Depends: Task 1
  - **Description**: Add timing instrumentation to `verify-tutor-patches.sh` that measures `apply-patches.sh` execution time and asserts it is under 30 seconds.
  - **Done definition**: Script reports execution time and fails if over 30 seconds.
  - **Complexity**: S (<1h) -- simple `time` wrapper with threshold check.

### Observability

- [ ] **[S] Task 12: Add structured logging to `apply-patches.sh`** (`infrastructure/tutor/apply-patches.sh`) | Req: Observability (Logs) | Depends: None
  - **Description**: Add structured log output (timestamp, patch name, status) to `apply-patches.sh` so that patch application history can be tracked. Output both to console and optionally to a log file at `var/logs/patch-application.log`.
  - **Done definition**: Each patch step logs `[TIMESTAMP] PATCH: <name> STATUS: <ok|fail>`. Log file is rotated or truncated on each run.
  - **Complexity**: S (1-2h) -- add logging functions to existing script.

- [ ] **[S] Task 13: Document monitoring integration points**(`docs/operations/TUTOR_CONFIGURATION_RUNBOOK.md`) | Req: Observability (Metrics, Alerts) | Depends: None
  - **Description**: Document how to monitor patch application (build time tracking, success rate, alert on missed patches). Reference existing Prometheus/Loki stack from `observability-stack_spec.md`. This is documentation only; actual metricinstrumentation depends on Tier 2 observability spec.
  - **Done definition**: Runbook section documents what to monitor and how alerts should be configured.
  - **Complexity**: S (1-2h) -- documentation task.

### Docs

- [ ] **[M] Task 14: Create Tutor Configuration Runbook** (`docs/operations/TUTOR_CONFIGURATION_RUNBOOK.md`) | Req: Rollout & Rollback, Edge Cases | Depends: None
  - **Description**: Create an operational runbook documenting the config save-patch-restart workflow, all edge case recovery procedures from the spec, and the rollback procedure. Link to verification scripts created in Tasks 1-8.
  - **Done definition**: Runbook covers: standard workflow, all 6 edge cases with recovery steps, rollback procedure, backup strategy. Cross-references spec and verification scripts.
  - **Complexity**: M (2-4h) -- consolidate edge cases and rollback steps from spec into operator-friendly format.

- [ ] **[S] Task 15: Update CLAUDE.md with verification commands** (`CLAUDE.md`) | Depends: Tasks 1, 3
  - **Description**: Add the new verification scripts to the"Common Development Commands" and "Diagnostics (Local)" sections of CLAUDE.md so that agents and developers know to run them after config changes.
  - **Done definition**: CLAUDE.md references `verify-tutor-patches.sh` and `verify-tutor-services.sh` in the appropriatesections.
  - **Complexity**: S (<1h) -- small documentation update.

- [ ] **[S] Task 16: Update onboarding docs to reference spec** (`docs/guides/onboarding/LOCAL_SETUP.md`, `docs/guides/onboarding/QUICK_START_LOCAL.md`) | Depends: Task 14
  - **Description**: Add a reference to the Tutor Configuration spec and runbook in the onboarding documentation, so new developers understand the mandatory patch workflow.
  - **Done definition**: Both onboarding docs link to spec and runbook. "After config changes" section references verification scripts.
  - **Complexity**: S (<1h) -- small documentation update.

### Rollout

- [ ] **[S] Task 17: Add pre-commit hook for patch script changes** (`.githooks/pre-commit`) | Depends: None
  - **Description**: Extend the existing pre-commit hook to run `bash -n infrastructure/tutor/apply-patches.sh` when thatfile is modified, catching syntax errors before commit.
  - **Done definition**: Modifying `apply-patches.sh` and committing triggers syntax validation. Invalid syntax blocks thecommit.
  - **Complexity**: S (<1h) -- append to existing hook.

- [ ] **[S] Task 18: Add Makefile target for full verification** (`Makefile`) | Depends: Tasks 1, 3
  - **Description**: Add `make verify-tutor` target that runs`verify-tutor-patches.sh` and optionally `verify-tutor-services.sh` (if Docker is running).
  - **Done definition**: `make verify-tutor` runs patch verification and reports results.
  - **Complexity**: S (<1h) -- one-line Makefile addition.

---

## Milestones

| Milestone | Tasks | Target |
|-----------|-------|--------|
| **M1: Verification scripts** | Tasks 1, 3, 6, 7, 8 | Day 1-|
| **M2: Hardening & guards** | Tasks 2, 4, 5 | Day 2-3 |
| **M3: CI integration** | Tasks 9, 10, 11 | Day 3-4 |
| **M4: Documentation** | Tasks 12, 13, 14, 15, 16 | Day 4-5|
| **M5: Rollout guards** | Tasks 17, 18 | Day 5 |

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| CI cannot run full Tutor stack | Tests limited to syntax and pattern checks in CI | Use offline mode for CI; full verification runs locally and in deployment pipeline |
| `apply-patches.sh` is 55KB and complex | Idempotency verification may surface unexpected edge cases | Task 2 explicitlytests idempotency; any failures become bugs to fix |
| Docker not running during verification | Service health checks (AC-007, AC-010) cannot run offline | Scripts detect Docker availability and skip gracefully with clear messaging |
| Tutor version upgrade breaks patches | Patches target specific template paths that change between Tutor versions | Document version pinning; patch script already uses Python to resolve template paths dynamically |
| Concurrent config saves (edge case) | File corruption or interleaved patches | Task 4 wrapper could add file locking; documented as known limitation for now |

---

## Dependency Graph

```
Task 1 (verify-patches.sh) ──→ Task 9 (CI job)
                              ──→ Task 11 (timing assert)
                              ──→ Task 15 (CLAUDE.md update)
                              ──→ Task 18 (Makefile target)

Task 2 (idempotency guard) ──→ Task 10 (idempotency test)

Task 3 (service health) ──→ Task 15 (CLAUDE.md update)
                         ──→ Task 18 (Makefile target)

Tasks 4, 5, 6, 7, 8 ──→ independent (no downstream deps within plan)

Task 14 (runbook) ──→ Task 16 (onboarding docs)
```

---

## Self-Check

- [x] Every acceptance criterion (AC-001 through AC-010) hasat least one build task
- [x] Every acceptance criterion has at least one test case (via verification scripts or CI)
- [x] Every edge case has a negative test or recovery procedure
- [x] Test tasks cover both happy path and failure modes
- [x] File paths specified for each task
- [x] Dependencies identified
- [x] Complexity estimated (S/M/L) for each task
- [x] Testmap YAML will be generated as a sibling artifact
- [x] Source spec linked in header
