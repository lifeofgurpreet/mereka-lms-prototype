---
spec: tutor-configuration-resilience_spec.md
plan: plans/tutor-configuration-resilience_plan.md
tier: 0
status: superseded
test_framework: bash/bats (shell scripts), GitHub Actions (CI)
owner: engineering
last_updated: "2026-04-22"
---

# Test Plan: Tutor Configuration Resilience and Patch Automation

**Source Spec**: `specs/tutor-configuration-resilience_spec.md`
**Implementation Plan**: `specs/plans/tutor-configuration-resilience_plan.md`
**Test Framework**: bash/bats for shell tests, GitHub Actions for CI tests
**Status**: Superseded historical plan.

Do not use the matrix below as current execution guidance. Current authority is:

- `specs/tutor-configuration-resilience_spec.md`
- `specs/_generated/testmaps/tutor-configuration-resilience_spec.testmap.yml`
- `docs/reference/operations/TUTOR_CONFIG_CI.md`

The active CI lane is `.github/workflows/ci.yml` job `tutor-config-tests`.
The canonical rendered verifier is `scripts/infra/verify-tutor-config.sh`;
`scripts/qa/verify-tutor-patches.sh` is a stable compatibility entrypoint that
delegates to it. Tutor 21 local MySQL proof is `mysql-native-password=ON` plus
`MYSQL_ROOT_HOST: "%"`, not plugin-owned `mysql_native_password`.

---

## Test Framework Detection

This project uses:
- **Shell scripts** (bash) for infrastructure verification -- test with `bats` (Bash Automated Testing System) or raw bash assertions
- **Python 3.12** for Tutor plugin code -- test with `pytest` if unit tests needed
- **GitHub Actions** for CI/CD workflows -- test with `workflow_dispatch` and deliberate failure PRs
- **No JavaScript test framework** is relevant for this spec (infrastructure-only)

---

## Acceptance Criteria Test Matrix

| AC # | Test Case | Type | File | Mocks/Fixtures | Status |
|------|-----------|------|------|----------------|--------|
| AC-TCR-001 | Plugin installs via `pip install -e` and appears in `tutor plugins list` | integration | `tests/tutor/test_plugin_lifecycle.sh` | Clean Python venv with Tutor installed | not_implemented |
| AC-TCR-001 | Plugin install fails gracefully with missing dependencies | integration | `tests/tutor/test_plugin_lifecycle.sh` | Venv without Tutor | not_implemented |
| AC-TCR-002 | Plugin-only config save produces `academy.biji-biji.com` in ALLOWED_HOSTS | integration | `tests/tutor/test_plugin_integration.sh` | Clean tutor_env, plugin enabled, no apply-patches | not_implemented |
| AC-TCR-002 | Plugin-only config save produces CSRF origins without apply-patches.sh | integration | `tests/tutor/test_plugin_integration.sh` | Clean tutor_env, plugin enabled | not_implemented |
| AC-TCR-003 | Canonical render path produces `mysql-native-password=ON` and `MYSQL_ROOT_HOST` | shell_verification | `scripts/qa/verify-tutor-resilience-full.sh` | Generated tutor_env when present | implemented |
| AC-TCR-004 | Rendered verifier passes after governed wrapper/prepare path | integration | `tests/tutor/test_verify_patches.sh` | Fully patched tutor_env fixture | implemented |
| AC-TCR-004 | Verification reports each patch individually | integration | `tests/tutor/test_verify_patches.sh` | Fully patched tutor_env fixture | not_implemented |
| AC-TCR-005 | Pre-commit hook runs verification when `infrastructure/tutor/` files changed | integration | `tests/tutor/test_pre_commit_hook.sh` | Temporary git repo with hook installed | not_implemented |
| AC-TCR-005 | Pre-commit hook blocks commit on verification failure | integration | `tests/tutor/test_pre_commit_hook.sh` | Temporary git repo, unpatched config | not_implemented |
| AC-TCR-005 | Pre-commit hook completes within 15 seconds | unit | `tests/tutor/test_pre_commit_hook.sh` | Timer around hook execution | not_implemented |
| AC-TCR-005 | Pre-commit hook skippable with `--no-verify` | integration | `tests/tutor/test_pre_commit_hook.sh` | Temporary git repo, `git commit --no-verify` | not_implemented |
| AC-TCR-006 | CI workflow runs Tutor Configuration Tests for Tutor-authority PRs | e2e | `.github/workflows/ci.yml` | GitHub Actions PR trigger | implemented |
| AC-TCR-006 | CI workflow blocks merge on rendered verifier/test failure | e2e | `.github/workflows/ci.yml` | Branch protection rules | implemented |
| AC-TCR-007 | Manifest entries include id, module, function, target, target_family, authority_class, description, retirement_trigger, required | unit | `tests/tutor/test_verify_patches.sh` | Source manifest | implemented |
| AC-TCR-008 | Unpatched config: all critical patches report FAIL | integration | `tests/tutor/test_unpatched_config.sh` | Clean `tutor config save` output, no plugin, no patches | not_implemented |
| AC-TCR-008 | Unpatched config: exit code is non-zero | integration | `tests/tutor/test_unpatched_config.sh` | Clean `tutor config save` output | not_implemented |
| AC-TCR-009 | Double apply-patches.sh produces byte-identical output | integration | `tests/tutor/test_idempotency.sh` | Tutor config + single patch application | existing_in_ci |
| AC-TCR-009 | Idempotency holds for all file types (py, yml, Dockerfile) | integration | `tests/tutor/test_idempotency.sh` | File-type-specific checksums | existing_in_ci |
| AC-TCR-010 | Version upgrade: CI blocks merge until rendered verifier and tests pass | e2e | `.github/workflows/ci.yml` | PR with broken patches | implemented |
| AC-TCR-010 | Version upgrade PR: CI reports a per-patch adaptation plan | manual/e2e | `.github/workflows/ci.yml` | PR changing Tutor version pin | not_implemented |
| AC-TCR-011 | Critical patch failure shows red/bold terminal formatting | unit | `tests/tutor/test_verify_patches.sh` | ANSI color code detection | not_implemented |
| AC-TCR-011 | Critical patch failure includes remediation steps | unit | `tests/tutor/test_verify_patches.sh` | Grep for remediation text in output | not_implemented |
| AC-TCR-012 | `make tutor-apply` executes config save, plugin enable, patches, verify, restart | integration | `tests/tutor/test_tutor_apply.sh` | Running Tutor environment | not_implemented |
| AC-TCR-012 | `make tutor-apply` fails fast on any step failure | integration | `tests/tutor/test_tutor_apply.sh` | Deliberate failure injection | not_implemented |

---

## Edge Case Test Matrix

| EC # | Edge Case | Test Case | Type | File | Mocks/Fixtures | Status |
|------|-----------|-----------|------|------|----------------|--------|
| EC-TCR-001 | Plugin hook not firing | Plugin enabled but patches absent in rendered templates | integration | `tests/tutor/test_plugin_failures.sh` | Plugin with broken hook registration | not_implemented |
| EC-TCR-001 | Plugin hook not firing | Verification tool catches missing patches from plugin | integration | `tests/tutor/test_plugin_failures.sh` | Plugin disabled, no apply-patches | not_implemented |
| EC-TCR-002 | apply-patches.sh interrupted | Partial patch application (kill -9 mid-script) | integration | `tests/tutor/test_partial_patch.sh` | Script interrupted after N patches | not_implemented |
| EC-TCR-002 | apply-patches.sh interrupted | Re-run completes remaining patches | integration | `tests/tutor/test_partial_patch.sh` | Pre-interrupted state + re-run | not_implemented |
| EC-TCR-003 | Concurrent config saves | Two `tutor config save` in parallel produce consistent output | integration | `tests/tutor/test_concurrent_config.sh` | Two background processes | not_implemented |
| EC-TCR-003 | Concurrent config saves | `flock` wrapper serializes access | integration | `tests/tutor/test_concurrent_config.sh` | `make tutor-apply` wrapper | not_implemented |
| EC-TCR-004 | Template conflict after Tutor upgrade | String-replacement patch fails on changed template | integration | `tests/tutor/test_template_conflict.sh` | Modified template fixture | not_implemented |
| EC-TCR-004 | Template conflict after Tutor upgrade | Verification tool catches missing patch in output | integration | `tests/tutor/test_template_conflict.sh` | Template with removed anchor text | not_implemented |
| EC-TCR-005 | Plugin conflicts with third-party plugins | Mereka plugin + tutor-mfe produce correct output and retired tutor-indigo is rejected | integration | `tests/tutor/test_plugin_conflicts.sh` | Current plugins enabled; stale Indigo plugin configured | not_implemented |
| EC-TCR-005 | Plugin conflicts | Double-application check (idempotent hooks) | integration | `tests/tutor/test_plugin_conflicts.sh` | Plugin enabled twice | not_implemented |
| EC-TCR-006 | Partial plugin migration | Plugin handles some patches, script handles rest, all verified | integration | `tests/tutor/test_partial_migration.sh` | Plugin with subset of hooks | not_implemented |
| EC-TCR-006 | Partial migration | Disabling plugin still passes verification via script | integration | `tests/tutor/test_partial_migration.sh` | Plugin disabled, script only | not_implemented |
| EC-TCR-007 | Verification false positive | Grep pattern matches unrelated text | unit | `tests/tutor/test_false_positives.sh` | Fixture with decoy text matching pattern | not_implemented |
| EC-TCR-007 | Verification false positive | Negative case confirms FAIL on actually unpatched config | unit | `tests/tutor/test_false_positives.sh` | Clean tutor config without patches | not_implemented |

---

## NFR (Non-Functional Requirements) Tests

| NFR | Test Case | Type | File | Threshold |
|-----|-----------|------|------|-----------|
| Verification speed | Full manifest verification completes in <30s | unit | `tests/tutor/test_nfr_performance.sh` | 30 seconds |
| Plugin overhead | `tutor config save` duration increase <5s with plugin | unit | `tests/tutor/test_nfr_performance.sh` | 5 seconds over baseline |
| CI duration | Tutor Configuration Tests complete within declared budget | e2e | `.github/workflows/ci.yml` | Current CI budget |
| Offline operation | Plugin + pre-commit hook work without network | integration | `tests/tutor/test_nfr_offline.sh` | No network calls |
| Manifest readability | `yamllint` passes on `patch-manifest.yml` | unit | `tests/tutor/test_nfr_manifest.sh` | Zero yamllint errors |
| Auditability | All patch changes tracked in git history | manual | N/A | Git log shows manifest changes |

---

## Test Execution Strategy

### Local Development

```bash
# Run all tests (requires Tutor installed in .venv)
source .venv/bin/activate
export TUTOR_ROOT="$(pwd)/tutor_env"

# Verification tests (fast, no Docker needed)
bash tests/tutor/test_verify_patches.sh

# Idempotency tests (requires tutor config save)
bash tests/tutor/test_idempotency.sh

# Plugin lifecycle tests (requires pip install)
bash tests/tutor/test_plugin_lifecycle.sh

# Pre-commit hook tests (creates temp git repo)
bash tests/tutor/test_pre_commit_hook.sh
```

### CI/CD

Current CI coverage lives in `.github/workflows/ci.yml` (`tutor-config-tests`)
and `.github/workflows/tutor-plugin-test.yml`. The retired
`.github/workflows/tutor-config-verify.yml` workflow must not be used as current
guidance.

### Test Data / Fixtures

| Fixture | Description | Location |
|---------|-------------|----------|
| Patched tutor_env | Full `tutor config save` + `prepare-tutor-build-context.sh --target all` output | Generated at test time |
| Unpatched tutor_env | Raw `tutor config save` output (no plugin, no patches) | Generated at test time |
| Patch manifest | `infrastructure/tutor/patch-manifest.yml` | Source-controlled |
| Plugin package | `infrastructure/tutor/tutor-plugin-mereka/` | Source-controlled |
| Config example | `infrastructure/tutor/config.example.yml` | Source-controlled |

---

## Coverage Summary

| Category | Total Tests | Automated | Manual | Not Implemented |
|----------|-------------|-----------|--------|-----------------|
| Acceptance Criteria (AC-TCR-001 to AC-TCR-012) | 30 | 28 | 2 | 24 |
| Edge Cases (EC-TCR-001 to EC-TCR-007) | 14 | 14 | 0 | 14 |
| NFR Tests | 6 | 5 | 1 | 6 |
| **Total** | **50** | **47** | **3** | **44** |

**Existing CI coverage** (from `.github/workflows/`):
- AC-TCR-002 partial (multi-site domain checks)
- AC-TCR-003 partial (MySQL auth check)
- AC-TCR-004 partial (custom app checks)
- AC-TCR-009 (idempotency test in `verify-idempotency` job)

---

## Self-Check

- [x] Every acceptance criterion (AC-TCR-001 through AC-TCR-012) has at least one test case
- [x] Every edge case from the spec has a negative test case
- [x] Test type (unit/integration/e2e) is appropriate for what is being tested
- [x] Mocks/fixtures specified for tests requiring external services
- [x] Test file paths specified for all test cases
- [x] Both happy path and failure path covered for each AC
- [x] NFR thresholds specified with measurable values
- [x] Source spec linked in header
