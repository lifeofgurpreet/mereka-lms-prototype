---
spec: repository-structure_spec.md
plan: repository-structure_plan.md
---

# Test Plan: Repository Structure

**Source Spec**: `specs/repository-structure_spec.md`
**Implementation Plan**: `specs/plans/repository-structure_plan.md`
**Last Updated**: 2026-02-10

## Overview

This test plan covers verification of all 12 acceptance criteria from the repository structure spec. Because this spec governs static directory layout and file placement (not runtimebehavior), the primary test types are `shell_verification` (bash scripts in `scripts/qa/`) and `ci_workflow` (GitHub Actions). There are no unit tests or integration tests in the traditional sense -- the "unit under test" is the repository filesystem itself.

## Test Framework Detection

This repository does not use a standard test framework (Vitest/Jest/pytest) for infrastructure verification. Instead:
- **Primary**: Bash verification scripts in `scripts/qa/` (pattern: `verify-*.sh`)
- **Secondary**: GitHub Actions workflows in `.github/workflows/`
- **Tertiary**: Manual verification checklists

## Test Matrix

| AC ID | Test Description | Test Type | Test Location | Priority | Mocks/Fixtures |
|-------|-----------------|-----------|---------------|----------|----------------|
| AC-001 | Verify all 7 required top-level directories exist(`deploy/`, `scripts/`, `infrastructure/`, `docs/`, `specs/`,`services/`, `assets/`) | `shell_verification` | `scripts/qa/verify-repo-structure.sh` | P0 | None (checks live filesystem) |
| AC-001 | Negative: detect missing required directory | `shell_verification` | `scripts/qa/test-verify-repo-structure.sh`| P1 | Temporary directory tree with one dir removed |
| AC-002 | Verify only allowlisted markdown files exist at root (README.md, CLAUDE.md, AGENTS.md, CONTRIBUTING.md, MIGRATION_CHECKLIST.md, CHANGES.md, GEMINI.md) | `shell_verification` | `scripts/qa/verify-repo-structure.sh` | P0 | None (checkslive filesystem) |
| AC-002 | Negative: detect non-allowlisted markdown file atroot | `shell_verification` | `scripts/qa/test-verify-repo-structure.sh` | P1 | Temporary dir with extra `TEMP_NOTES.md` |
| AC-003 | Verify all 6 required `scripts/` subdirectories exist (`shared/`, `infra/`, `migrations/`, `branding/`, `analytics/`, `qa/`) | `shell_verification` | `scripts/qa/verify-repo-structure.sh` | P0 | None |
| AC-003 | Negative: detect missing `scripts/` subdirectory |`shell_verification` | `scripts/qa/test-verify-repo-structure.sh` | P1 | Temporary dir without `scripts/analytics/` |
| AC-004 | Verify `scripts/shared/config.sh` exists and exports `GCP_PROJECT`, `GCP_REGION`, `LMS_DOMAIN` with non-empty values | `shell_verification` | `scripts/qa/verify-repo-structure.sh` | P0 | None (sources the actual config.sh) |
| AC-004 | Negative: detect missing or empty required variable | `shell_verification` | `scripts/qa/test-verify-repo-structure.sh` | P1 | Temporary config.sh with `GCP_PROJECT=""` |
| AC-005 | Verify `deploy/k8s/overlays/local/` and `production/` both exist | `shell_verification` | `scripts/qa/verify-repo-structure.sh` | P0 | None |
| AC-005 | Negative: detect missing overlay directory | `shell_verification` | `scripts/qa/test-verify-repo-structure.sh`| P1 | Temporary dir without `overlays/production/` |
| AC-006 | Verify no YAML file in `deploy/k8s/base/secrets/`contains `kind: Secret` with `data:` or `stringData:` inlinevalues | `shell_verification` | `scripts/qa/verify-repo-structure.sh` | P0 | None (scans actual YAML files) |
| AC-006 | Negative: detect hardcoded Secret manifest | `shell_verification` | `scripts/qa/test-verify-repo-structure.sh`| P1 | Temporary YAML with `kind: Secret` + `data: {key: dmFsdWU=}` |
| AC-007 | Verify `tools/` and `ops/` either do not exist orcontain only `README.md` | `shell_verification` | `scripts/qa/verify-repo-structure.sh` | P0 | None |
| AC-007 | Negative: detect non-README file in deprecated directory | `shell_verification` | `scripts/qa/test-verify-repo-structure.sh` | P1 | Temporary `tools/` dir with `script.sh`inside |
| AC-008 | Verify all 6 required `docs/` subdirectories exist(`adr/`, `onboarding/`, `operations/`, `migrations/`, `architecture/`, `archive/`) | `shell_verification` | `scripts/qa/verify-repo-structure.sh` | P0 | None |
| AC-008 | Negative: detect missing `docs/` subdirectory | `shell_verification` | `scripts/qa/test-verify-repo-structure.sh` | P1 | Temporary dir without `docs/archive/` |
| AC-009 | Verify all 4 required `infrastructure/` subdirectories exist (`tutor/`, `cloudflare/`, `terraform/`, `monitoring/`) | `shell_verification` | `scripts/qa/verify-repo-structure.sh` | P0 | None |
| AC-009 | Negative: detect missing `infrastructure/` subdirectory | `shell_verification` | `scripts/qa/test-verify-repo-structure.sh` | P1 | Temporary dir without `infrastructure/monitoring/` |
| AC-010 | Verify `var/` and `tutor_env/` patterns exist in `.gitignore` | `shell_verification` | `scripts/qa/verify-repo-structure.sh` | P0 | None |
| AC-010 | Negative: detect missing gitignore pattern | `shell_verification` | `scripts/qa/test-verify-repo-structure.sh`| P1 | Temporary `.gitignore` without `var/` |
| AC-011 | Verify all `specs/*.md` files match `*_spec.md` naming (with documented exceptions like `IMPLEMENTATION_ORDER.md`) | `shell_verification` | `scripts/qa/verify-repo-structure.sh` | P0 | None |
| AC-011 | Negative: detect non-conforming spec filename | `shell_verification` | `scripts/qa/test-verify-repo-structure.sh` | P1 | Temporary `specs/bad-name.md` |
| AC-012 | Verify the full verification script completes in under 5 seconds with PASS and zero violations | `shell_verification` | `scripts/qa/verify-repo-structure.sh` | P0 | Requires all cleanup tasks to be complete |
| AC-012 | CI workflow runs verification on every PR to main| `ci_workflow` | `.github/workflows/verify-repo-structure.yml` | P1 | GitHub Actions runner |

## Edge Case Tests

| EC ID | Edge Case Description | Test Type | Test Location |Priority |
|-------|----------------------|-----------|---------------|----------|
| EC-001 | Root markdown violation on feature branch (allowed) vs main (blocked) | `manual_verification` | Verify CI onlyblocks on PRs targeting `main` | P2 |
| EC-002 | New subdirectory under `scripts/` (e.g., `scripts/mobile/`) does not cause failure | `shell_verification` | `scripts/qa/test-verify-repo-structure.sh` | P1 |
| EC-003 | Deprecated directory `tools/` recreated with non-README files | `shell_verification` | `scripts/qa/test-verify-repo-structure.sh` | P1 |
| EC-004 | `var/` and `tutor_env/` absent on fresh clone (should not fail) | `shell_verification` | `scripts/qa/test-verify-repo-structure.sh` | P1 |
| EC-005 | Submodule directory in `apps/` is not recursed into | `shell_verification` | `scripts/qa/test-verify-repo-structure.sh` | P2 |
| EC-006 | Empty required directory (e.g., `docs/adr/` with no files) still passes | `shell_verification` | `scripts/qa/test-verify-repo-structure.sh` | P1 |
| EC-007 | `IMPLEMENTATION_ORDER.md` in `specs/` is a known exception to `*_spec.md` naming | `shell_verification` | `scripts/qa/verify-repo-structure.sh` | P1 |

## Coverage Summary

| Category | Automated | Manual | Total |
|----------|-----------|--------|-------|
| Acceptance Criteria (AC-001 to AC-012) | 12 (100%) | 0 | 12|
| Positive test cases | 12 | 0 | 12 |
| Negative test cases | 11 | 1 | 12 |
| Edge case tests | 6 | 1 | 7 |
| **Total test cases** | **29** | **1** | **30** |

All 12 acceptance criteria are covered by automated `shell_verification` tests. The single `manual_verification` item (EC-001) covers branch-specific enforcement behavior that requires a real PR workflow to validate.

## Environment Requirements

| Requirement | Details |
|-------------|---------|
| Shell | Bash 4.0+ (for associative arrays and `[[ ]]` syntax) |
| Git | Git 2.x+ (for `git rev-parse --show-toplevel`) |
| Utilities | `grep`, `find`, `test`, `time` (standard POSIX)|
| Working directory | Must run from within the git repository|
| Special tools | None -- all checks use standard shell builtins and POSIX utilities |
| CI runner | Ubuntu 22.04+ (GitHub Actions `ubuntu-latest`)|
| Permissions | Read-only access to the repository filesystem; no network access required |

## Test Execution

### Running the verification script (live repo)
```bash
cd /home/gurpreet/projects/k8s/mereka-lms
bash scripts/qa/verify-repo-structure.sh
```

### Running the test harness (synthetic scenarios)
```bash
cd /home/gurpreet/projects/k8s/mereka-lms
bash scripts/qa/test-verify-repo-structure.sh
```

### Running via CI
The GitHub Actions workflow at `.github/workflows/verify-repo-structure.yml` triggers automatically on PRs targeting `main`. During the 2-week advisory period, failures are non-blocking (`continue-on-error: true`).

## Test Implementation Notes

### Verification Script (`scripts/qa/verify-repo-structure.sh`)
- Must be idempotent and read-only (never modifies the filesystem)
- Must produce deterministic output (same input = same output)
- Must exit with code 0 for all-pass, non-zero for any failure (exit code = violation count)
- Must complete in under 5 seconds (self-timed)
- Must handle the `IMPLEMENTATION_ORDER.md` exception in AC-0gracefully

### Test Harness (`scripts/qa/test-verify-repo-structure.sh`)
- Creates a temporary directory tree (via `mktemp -d`) for each test scenario
- Runs the verification script with `REPO_ROOT` overridden tothe temp directory
- Captures exit code and stdout
- Asserts expected PASS/FAIL outcomes
- Cleans up temp directories on exit (via `trap`)
- The harness itself must be executable and pass shellcheck

### CI Workflow (`.github/workflows/verify-repo-structure.yml`)
- Triggers on `pull_request` targeting `main` and `push` to `main`
- Single job: checkout + run verification script
- Advisory mode: `continue-on-error: true` for first 2 weeks
- No external dependencies or secrets required
