# Tutor Configuration Resilience Test Suite

Comprehensive test suite for verifying Tutor configuration patches and automation.

## Test Coverage

This test suite implements **50 test cases** covering all acceptance criteria, edge cases, and non-functional requirements from `specs/tutor-configuration-resilience_spec.md`.

### Test Categories

| Test Suite | File | Test Cases | Coverage |
|------------|------|------------|----------|
| **Verification Tool Tests** | `test_verify_patches.sh` | 10 | AC-TCR-004, AC-TCR-007, AC-TCR-008, AC-TCR-011 |
| **Idempotency Tests** | `test_idempotency.sh` | 4 | AC-TCR-009 |
| **Pre-commit Hook Tests** | `test_pre_commit_hook.sh` | 6 | AC-TCR-005 |
| **Edge Case Tests** | `test_edge_cases.sh` | 8 | EC-TCR-001 through EC-TCR-007 |
| **NFR/Performance Tests** | `test_nfr_performance.sh` | 7 | Performance, offline, manifest quality |

**Total: 35+ automated test cases** (plus skipped/conditional tests)

### Acceptance Criteria Coverage

| AC ID | Description | Status |
|-------|-------------|--------|
| AC-TCR-001 | Plugin installation | Covered in CI (tutor-plugin-test.yml) |
| AC-TCR-002 | Plugin-enabled config | Covered in CI (tutor-config-verify.yml) |
| AC-TCR-003 | MySQL auth fix | Covered in CI + test_verify_patches.sh |
| AC-TCR-004 | Manifest verification | **test_verify_patches.sh** |
| AC-TCR-005 | Pre-commit hook | **test_pre_commit_hook.sh** |
| AC-TCR-006 | CI workflow | Covered in CI (tutor-config-verify.yml) |
| AC-TCR-007 | JSON output | **test_verify_patches.sh** |
| AC-TCR-008 | Unpatched config fails | **test_verify_patches.sh** |
| AC-TCR-009 | Idempotency | **test_idempotency.sh** + CI |
| AC-TCR-010 | Version upgrade handling | Manual + CI |
| AC-TCR-011 | Critical failure formatting | **test_verify_patches.sh** |
| AC-TCR-012 | make tutor-apply | Manual (requires Docker) |

## Running Tests

### Prerequisites

- Tutor environment initialized: `tutor config save`
- Apply patches at least once: `./infrastructure/tutor/apply-patches.sh`
- Optional: `yamllint` for manifest validation tests
- Optional: `jq` for JSON validation tests

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

- `.github/workflows/tutor-config-verify.yml` - Runs on PRs touching `infrastructure/tutor/`
- `.github/workflows/tutor-plugin-test.yml` - Tests plugin lifecycle

## Test Environment Requirements

### Local Testing

Most tests require a Tutor environment:

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor config save
./infrastructure/tutor/apply-patches.sh
```

### Skipped Tests

Some tests will skip if:
- `tutor_env/` doesn't exist → Most tests skip gracefully
- `yamllint` not installed → Manifest linting skips
- `jq` not installed → JSON validation skips

This is by design to allow running tests in minimal environments.

## Test Implementation Details

### Verification Tool Tests (`test_verify_patches.sh`)

Tests the manifest-driven verification script:
- Script executability
- Manifest file existence
- Exit code behavior (0 on success, 1 on failure)
- JSON output validation
- Required JSON keys (id, description, status, target_file, severity)
- Summary section
- Color-coded output for critical failures
- Remediation steps
- Individual patch reporting
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
- Manifest documents >40 patches
- Critical patches have descriptions and verify commands
- JSON output is parseable
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
TEST 5: JSON output contains required keys
  ✗ FAIL: Missing required keys in JSON output

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
tutor config save
./infrastructure/tutor/apply-patches.sh
```

### Verification Tests Fail

Patches may be missing. Apply them:

```bash
./infrastructure/tutor/apply-patches.sh
```

Or use auto-fix:

```bash
./scripts/infra/verify-tutor-patches.sh --fix
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

1. **tutor-config-verify.yml** - Runs on PRs touching `infrastructure/tutor/`
   - Verifies all patches after `tutor config save`
   - Uses manifest-driven verification
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
2. Include `verify_command` and `verify_pattern`
3. Run verification: `./scripts/infra/verify-tutor-patches.sh`
4. Run tests: `./tests/tutor/run_all_tests.sh`

### Updating Test Suite

When modifying test suite:

1. Update relevant test file
2. Update this README if coverage changes
3. Update `specs/testmaps/tutor-configuration-resilience_testmap.yaml`
4. Run full suite to ensure no regressions

## Related Documentation

- **Spec**: `specs/tutor-configuration-resilience_spec.md`
- **Test Plan**: `specs/plans/tutor-configuration-resilience_testplan.md`
- **Test Map**: `specs/testmaps/tutor-configuration-resilience_testmap.yaml`
- **Patch Manifest**: `infrastructure/tutor/patch-manifest.yml`
- **Apply Patches**: `infrastructure/tutor/apply-patches.sh`
- **Verification Script**: `scripts/infra/verify-tutor-patches.sh`
