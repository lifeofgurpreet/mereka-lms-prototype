---
spec: tutor-configuration_spec.md
plan: plans/tutor-configuration_plan.md
tier: 0
status: draft
last_updated: "2026-02-10"
---

# Test Plan: Tutor Configuration Lifecycle

**Source Spec**: `specs/tutor-configuration_spec.md`
**Implementation Plan**: `specs/plans/tutor-configuration_plan.md`

---

## Test Framework

This project uses **shell-based verification scripts** as itsprimary test infrastructure for infrastructure-as-code. There are no `vitest.config`, `jest.config`, or `pytest.ini` files for infrastructure testing. The test patterns are:

| Test Type | Tool | Location |
|-----------|------|----------|
| `shell_verification` | Bash scripts with `set -euo pipefail` | `scripts/qa/verify-*.sh` |
| `ci_workflow` | GitHub Actions | `.github/workflows/ci.yml`|
| `manual_verification` | Human-executed checklist | Documented in runbook |

Existing patterns: `scripts/qa/verify-setup.sh`, `scripts/qa/smoke-test.sh`, `scripts/branding/verify-branding-health.sh`.

---

## Test Matrix

### Acceptance Criteria Tests

| AC # | Test Case | Type | File | Mocks/Fixtures | Priority|
|------|-----------|------|------|----------------|----------|
| AC-001 | Verify `mysql_native_password` present in docker-compose.yml after patch | shell_verification | `scripts/qa/verify-tutor-patches.sh` | Requires rendered `tutor_env/env/local/docker-compose.yml` | P1 |
| AC-002 | Verify `NODE_OPTIONS.*6144` present in openedx Dockerfile after patch | shell_verification | `scripts/qa/verify-tutor-patches.sh` | Requires rendered `tutor_env/env/build/openedx/Dockerfile` | P1 |
| AC-003 | Verify `academy.biji-biji.com` present in LMS production.py after patch | shell_verification | `scripts/qa/verify-tutor-patches.sh` | Requires rendered `tutor_env/env/apps/openedx/settings/lms/production.py` | P1 |
| AC-004 | Verify `mfe_oauth_fix` present in LMS production.py after patch | shell_verification | `scripts/qa/verify-tutor-patches.sh` | Requires rendered `tutor_env/env/apps/openedx/settings/lms/production.py` | P1 |
| AC-005 | Verify `django_prometheus` present in LMS production.py after patch | shell_verification | `scripts/qa/verify-tutor-patches.sh` | Requires rendered `tutor_env/env/apps/openedx/settings/lms/production.py` | P1 |
| AC-006 | Verify the rendered MFE Dockerfile matches the Node 24 build contract, build tools, and retry hardening | shell_verification | `scripts/qa/verify-mfe-build-contract.sh` | Requires rendered `tutor_env/env/plugins/mfe/build/mfe/Dockerfile` | P1 |
| AC-007 | MySQL 8 connections succeed without authenticationerrors | manual_verification | `docs/operations/TUTOR_CONFIGURATION_RUNBOOK.md` | Requires running Docker stack with MySQL 8 | P1 |
| AC-008 | All three production domains resolve and accept logins | shell_verification | `scripts/qa/smoke-test.sh` (existing) | Requires live production deployment | P2 |
| AC-009 | Mereka logo and custom footer render on all MFEs |shell_verification | `scripts/qa/verify-tutor-branding-render.sh` + `scripts/branding/verify-branding-health.sh` (existing) | Requires theme assets synced to build directory | P2 |
| AC-010 | `tutor local dc ps` shows all services with status"Up" | manual_verification | `scripts/qa/verify-tutor-services.sh` | Requires running Docker stack | P1 |

### Edge Case / Negative Tests

| EC # | Test Case | Type | File | Mocks/Fixtures | Priority|
|------|-----------|------|------|----------------|----------|
| EC-1 | Detect missing patches: config.yml without `mysql_native_password` fails verification | shell_verification | `scripts/qa/verify-tutor-patches.sh` | Run against unpatched `tutor_env` | P1 |
| EC-2 | Detect cloud IPs in local config: `10.97.x.x` in config.yml triggers warning | shell_verification | `scripts/qa/verify-tutor-patches.sh` | Inject cloud IP into config.yml, verify detection | P1 |
| EC-3 | Patch idempotency: running `apply-patches.sh` twiceproduces identical output | shell_verification | `scripts/qa/test-patch-idempotency.sh` | Requires rendered `tutor_env` |P2 |
| EC-4 | Patch execution time under 30 seconds | shell_verification | `scripts/qa/verify-tutor-patches.sh` (timing mode) |Requires rendered `tutor_env` | P2 |
| EC-5 | Patch script exits non-zero on failure | shell_verification | Inline test in CI | Corrupt a template file, verifynon-zero exit | P2 |
| EC-6 | Partial patch recovery: re-running patches after interruption restores correct state | manual_verification | `docs/operations/TUTOR_CONFIGURATION_RUNBOOK.md` | Requires manual kill during patch run | P3 |
| EC-7 | Docker not running: service checks skip gracefully |shell_verification | `scripts/qa/verify-tutor-services.sh` |Run with Docker stopped | P2 |

### Non-Functional Requirement Tests

| NFR # | Test Case | Type | File | Threshold | Priority |
|-------|-----------|------|------|-----------|----------|
| NFR-1 | Patch execution time <= 30 seconds | shell_verification | `scripts/qa/verify-tutor-patches.sh` | 30s wall clock| P1 |
| NFR-2 | Patch idempotency (multiple runs = same output) | shell_verification | `scripts/qa/test-patch-idempotency.sh` |Byte-identical output | P1 |
| NFR-3 | Patch script exits non-zero on failure | shell_verification | CI inline | Exit code != 0 | P1 |
| NFR-4 | Configuration validation under 5 seconds | shell_verification | `scripts/qa/verify-tutor-patches.sh` | 5s wall clock | P2 |
| NFR-5 | Offline patch application (no network required) | manual_verification | Runbook | Network disabled during patchrun | P3 |

---

## CI Integration

### Existing CI Jobs (already covering partial contract)

| Job | File | What It Checks |
|-----|------|----------------|
| `validate-tutor-config` | `.github/workflows/ci.yml` | Config YAML syntax, patch script syntax (`bash -n`) |
| `branding-preflight` | `.github/workflows/ci.yml` | Branding asset presence and wiring |
| `monitoring-guardrails` | `.github/workflows/ci.yml` | Script syntax for all QA scripts |

### New CI Jobs Required

| Job | File | What It Checks | Depends On |
|-----|------|----------------|------------|
| `tutor-patch-contract` | `.github/workflows/ci.yml` | Patchverification script syntax, grep patterns against config examples | Task 9 |

### CI Limitations

The CI environment (GitHub Actions `ubuntu-latest`) does nothave Tutor installed and cannot render `tutor_env`. Therefore:
- AC-001 through AC-005 (grep checks against rendered files)run locally only
- AC-007, AC-010 (running services) require a live Docker environment
- AC-008 (production domains) requires production deployment
- CI can validate: script syntax, grep pattern correctness against committed examples, branding asset presence

---

## Test Execution

### Local Development (Full)

```bash
# After any config change
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/tutor-config-save.sh --set KEY=value

# If you need a manual post-render refresh after source edits
./scripts/infra/prepare-tutor-build-context.sh --target all

# Run patch verification (AC-001 through AC-005)
./scripts/qa/verify-tutor-patches.sh

# Run MFE build contract (AC-006)
./scripts/qa/verify-mfe-build-contract.sh

# Run service health (AC-007, AC-010) -- requires Docker
./scripts/qa/verify-tutor-services.sh

# Run branding check (AC-009)
./scripts/branding/verify-branding-health.sh

# Run smoke test (AC-008) -- requires production deployment
./scripts/qa/smoke-test.sh

# Run idempotency test (NFR-2)
./scripts/qa/test-patch-idempotency.sh
```

### CI (Offline)

```bash
# Runs automatically on PR
# ci.yml tutor-config-tests: render Tutor env, apply governed patch path, run Tutor tests
# tutor-plugin-test.yml render-contract-preflight: plugin/render-contract preflight
# static validation lanes: script syntax, generated drift, and branding/supporting gates
```

### Pre-Release (Manual)

| Step | Command | Checks |
|------|---------|--------|
| 1 | `make verify-tutor` | AC-001 through AC-005, NFR-1 |
| 2 | `./scripts/qa/verify-tutor-services.sh` | AC-007, AC-01|
| 3 | `./scripts/qa/smoke-test.sh` | AC-008 |
| 4 | Visual inspection of MFE login page | AC-009 (logo + footer) |

---

## Coverage Summary

| Category | Total | Automated | Manual | Coverage |
|----------|-------|-----------|--------|----------|
| Acceptance Criteria (AC-001 to AC-010) | 10 | 7 | 3 | 100%|
| Edge Cases (EC-1 to EC-7) | 7 | 5 | 2 | 100% |
| Non-Functional Requirements (NFR-1 to NFR-5) | 5 | 4 | 1 |100% |
| **Total** | **22** | **16** | **6** | **100%** |

**Notes on manual tests**:
- AC-007 (MySQL auth): Requires live MySQL 8 container. Cannot be automated in CI without Docker-in-Docker.
- AC-010 (services Up): Requires live Docker stack. Cannot run in standard CI.
- EC-6 (partial patch recovery): Inherently requires manual interruption.
- NFR-5 (offline mode): Requires disabling network, not practical for CI.

---

## Self-Check

- [x] Every acceptance criterion (AC-001 through AC-010) hasat least one test case
- [x] Edge cases from spec have negative test cases (EC-1 through EC-7)
- [x] Test type (shell_verification/ci_workflow/manual_verification) is appropriate
- [x] Mocks/fixtures specified (rendered tutor_env files, Docker stack, live domains)
- [x] Test framework matches project patterns (shell scripts,not Jest/pytest)
- [x] CI limitations documented
- [x] Source spec linked in headerapply_patch marked them as deleted. It shows "D," which might meanthat git is tracking them as deleted, but they were untrackedinitially. The output indicates "D," so is it related to git diffinstead? Since this is about the patch tool, it might not bedirectly linked to git. I really need to check git status to clarifywhat's going on.│ --porcelain└ ?? specs/plans/?? specs/testmaps/are still untracked. Even though I've deleted their files, thedirectories remain. It seems that untracked directories show up ifthey still contain files. I should probably look deeper as theremight be other files left. I think a good next step is to list thecontents of those directories to clarify what’s going on.└ List plansI’ll need to delete those as well using apply_patch. There are quitea few, but it looks like a necessary step to take. I think it's allabout keeping things tidy and organized. So, let's get to it andremove these untracked files too! It's an important part of theprocess, and I don't want anything unnecessary lying around.
