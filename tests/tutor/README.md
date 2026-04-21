# Tutor Configuration Resilience Test Suite

Test suite for verifying current Tutor patch authority, canonical rendered verification, and automation.

## Test Coverage

This test suite covers the active acceptance criteria, edge cases, and non-functional requirements from `specs/tutor-configuration-resilience_spec.md`.

### Test Categories

| Test Suite | File | Test Cases | Coverage |
|------------|------|------------|----------|
| **Verification Tool Tests** | `test_verify_patches.sh` | 12 | AC-TCR-004, AC-TCR-008 |
| **Idempotency Tests** | `test_idempotency.sh` | 4 | AC-TCR-009 |
| **Pre-commit Hook Tests** | `test_pre_commit_hook.sh` | 6 | AC-TCR-005 |
| **Edge Case Tests** | `test_edge_cases.sh` | 8 | EC-TCR-001 through EC-TCR-007 |
| **NFR/Performance Tests** | `test_nfr_performance.sh` | 7 | Performance, offline verifier behavior, manifest authority metadata |

**Total: 37+ automated test cases** (plus skipped/conditional tests)

### Acceptance Criteria Coverage

| AC ID | Description | Status |
|-------|-------------|--------|
| AC-TCR-001 | Plugin installation | Covered in CI (tutor-plugin-test.yml) |
| AC-TCR-002 | Plugin-enabled config | Covered in CI (`ci.yml` Tutor Configuration Tests + `tutor-plugin-test.yml`) |
| AC-TCR-003 | MySQL auth fix | Covered in CI + test_verify_patches.sh |
| AC-TCR-004 | Manifest verification | **test_verify_patches.sh** |
| AC-TCR-005 | Pre-commit hook | **test_pre_commit_hook.sh** |
| AC-TCR-006 | CI workflow | Covered in CI (`ci.yml`) |
| AC-TCR-007 | Machine-readable patch authority | `patch-manifest.yml` + **test_nfr_performance.sh** |
| AC-TCR-008 | Unpatched config fails | **test_verify_patches.sh** |
| AC-TCR-009 | Idempotency | **test_idempotency.sh** + CI |
| AC-TCR-010 | Version upgrade handling | Manual + CI |
| AC-TCR-011 | Classified patch authority | `patch-manifest.yml` + **test_verify_patches.sh** |
| AC-TCR-012 | make tutor-apply | Manual (requires Docker) |

## Running Tests

### Prerequisites

- Tutor environment initialized through the canonical wrapper: `./scripts/infra/tutor-config-save.sh`
- Build context prepared at least once: `./scripts/infra/prepare-tutor-build-context.sh --target all`
- Optional: `yamllint` for manifest validation tests

### Quick Start

Run all test suites:

```bash
./tests/tutor/run_all_tests.sh
```

### Individual Test Suites

```bash
# Verification tool tests
./tests/tutor/test_verify_patches.sh

# Idempotency tests
./tests/tutor/test_idempotency.sh

# Pre-commit hook tests
./tests/tutor/test_pre_commit_hook.sh

# Edge case tests
./tests/tutor/test_edge_cases.sh

# Non-functional requirement tests
./tests/tutor/test_nfr_performance.sh
```

### CI Integration

Tests are also integrated into GitHub Actions:

- `.github/workflows/ci.yml` / **Tutor Configuration Tests** - Runs on PRs touching Tutor authority
- `.github/workflows/tutor-plugin-test.yml` - Tests plugin lifecycle

## Test Environment Requirements

### Local Testing

Most tests require a Tutor environment:

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/tutor-config-save.sh
./scripts/infra/prepare-tutor-build-context.sh --target all
```

### Skipped Tests

Some tests will skip if:
- `tutor_env/` doesn't exist → Most tests skip gracefully
- `yamllint` not installed → Manifest linting skips

This is by design to allow running tests in minimal environments.

## Test Implementation Details

### Verification Tool Tests (`test_verify_patches.sh`)

Tests current patch authority:
- QA verifier entrypoint executability
- Canonical rendered verifier executability
- Manifest file existence
- Manifest schema and `apply-patches.sh` wiring
- QA entrypoint delegation to `scripts/infra/verify-tutor-config.sh`
- MySQL 8.4 native-password and `MYSQL_ROOT_HOST` checks in the canonical verifier
- Canonical verifier exit code and failure output
- Performance (<30s threshold)

### Idempotency Tests (`test_idempotency.sh`)

Verifies `apply-patches.sh` can be run multiple times:
- Python files remain byte-identical after double-apply
- YAML files remain byte-identical
- Dockerfiles remain byte-identical
- Script exits 0 on second run

### Pre-commit Hook Tests (`test_pre_commit_hook.sh`)

Verifies Git hook integration:
- Hook exists and is executable
- Hook references verification script
- Hook only runs on Tutor file changes
- Hook exits 1 on verification failure
- Hook completes within 15 seconds
- Hook can be bypassed with `--no-verify`

### Edge Case Tests (`test_edge_cases.sh`)

Tests failure scenarios:
- Missing patches detected by verification
- Interrupted apply-patches.sh can be resumed
- Sequential runs complete without conflicts
- Verification catches template conflicts
- Double-application is idempotent
- Verification passes after apply-patches
- Patterns are specific enough to avoid false positives

### NFR Tests (`test_nfr_performance.sh`)

Non-functional requirements:
- Verification completes in <30s
- Manifest passes yamllint
- No network calls in verification
- Manifest documents active patch authority and retirement metadata
- Temporary compatibility patches have retirement triggers
- Manifest is machine-parseable YAML
- Scripts use proper error handling

## Expected Test Output

### All Tests Pass

```
=== Test Suite: verify-tutor-patches.sh ===

TEST 1: Verify script is executable
  ✓ PASS
TEST 2: Patch manifest exists
  ✓ PASS
...

=== Test Summary ===
Tests run: 10
Passed: 10
Failed: 0

✓ All tests passed!
```

### Some Tests Fail

```
TEST 6: Rendered verifier runs against tutor_env
  FAIL: Verifier exited 1

=== Test Summary ===
Tests run: 10
Passed: 9
Failed: 1

✗ Some tests failed
```

## Troubleshooting

### Tests Skipped Due to Missing tutor_env

Run:

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/tutor-config-save.sh
./scripts/infra/prepare-tutor-build-context.sh --target all
```

### Verification Tests Fail

Patches may be missing. Re-prepare the build context:

```bash
./scripts/infra/prepare-tutor-build-context.sh --target all
```

### Idempotency Tests Fail

This indicates patches are not idempotent. Check `apply-patches.sh` for:
- Patches that append instead of replace
- Conditional logic that doesn't check for existing patches
- String replacements that match partial text

### Performance Tests Fail

Verification taking >30s suggests:
- Very large tutor_env (network-mounted?)
- Slow disk I/O
- Too many patches in manifest

## Continuous Integration

### GitHub Actions Integration

The test suite integrates with existing CI workflows:

1. **ci.yml / Tutor Configuration Tests** - Runs on PRs touching Tutor authority
   - Renders Tutor through `scripts/infra/tutor-config-save.sh` and runs the Tutor test suite
   - Uses `scripts/qa/verify-tutor-patches.sh` as the stable entrypoint into
     `scripts/infra/verify-tutor-config.sh`
   - Blocks merge on failures

2. **tutor-plugin-test.yml** - Tests plugin lifecycle
   - Plugin enable/disable/re-enable
   - Plugin hook execution

### Local Pre-commit Hook

The pre-commit hook runs automatically on commits touching Tutor files:

```bash
# Automatic verification on commit
git add infrastructure/tutor/apply-patches.sh
git commit -m "fix: update patches"
# Hook runs verification automatically

# Bypass if needed (emergencies only)
git commit --no-verify
```

## Maintenance

### Adding New Patches

When adding new patches to `apply-patches.sh`:

1. Add entry to `infrastructure/tutor/patch-manifest.yml`
2. Include authority class, target family, description, and retirement trigger
3. Add or update the rendered guard in `scripts/infra/verify-tutor-config.sh` or a dedicated patch fixture test
4. Run tests: `./tests/tutor/run_all_tests.sh`

### Updating Test Suite

When modifying test suite:

1. Update relevant test file
2. Update this README if coverage changes
3. Update `specs/_generated/testmaps/tutor-configuration-resilience_spec.testmap.yml` if coverage changes
4. Run full suite to ensure no regressions

## Related Documentation

- **Spec**: `specs/tutor-configuration-resilience_spec.md`
- **Test Plan**: `specs/plans/tutor-configuration-resilience_testplan.md`
- **Test Map**: `specs/testmaps/tutor-configuration-resilience_testmap.yaml`
- **Patch Manifest**: `infrastructure/tutor/patch-manifest.yml`
- **Apply Patches**: `infrastructure/tutor/apply-patches.sh`
- **Canonical Rendered Verification Script**: `scripts/infra/verify-tutor-config.sh`
- **Stable QA/CI Entrypoint**: `scripts/qa/verify-tutor-patches.sh`
