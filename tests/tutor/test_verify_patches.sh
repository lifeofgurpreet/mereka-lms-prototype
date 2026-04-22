#!/usr/bin/env bash
# @covers AC-TCR-004, AC-TCR-008
# @spec: tutor-configuration-resilience_spec.md
# Tests for the current Tutor patch authority ledger and canonical rendered verifier.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY_SCRIPT="$REPO_ROOT/scripts/qa/verify-tutor-patches.sh"
CANONICAL_VERIFY_SCRIPT="$REPO_ROOT/scripts/infra/verify-tutor-config.sh"
MANIFEST_FILE="$REPO_ROOT/infrastructure/tutor/patch-manifest.yml"
APPLY_PATCHES="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
VERIFY_OUTPUT=""

test_start() {
  TESTS_RUN=$((TESTS_RUN + 1))
  echo -e "${YELLOW}TEST $TESTS_RUN: $1${NC}"
}

test_pass() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo -e "${GREEN}  PASS${NC}"
}

test_fail() {
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo -e "${RED}  FAIL: $1${NC}"
}

run_manifest_check() {
  python3 - "$REPO_ROOT" "$MANIFEST_FILE" "$APPLY_PATCHES" <<'PY'
import sys
from pathlib import Path

try:
    import yaml
except ImportError as exc:
    raise SystemExit(f"PyYAML is required for patch manifest validation: {exc}")

repo_root = Path(sys.argv[1])
manifest_path = Path(sys.argv[2])
apply_patches_path = Path(sys.argv[3])

payload = yaml.safe_load(manifest_path.read_text(encoding="utf-8")) or {}
patches = payload.get("patches") or []
inactive = payload.get("inactive_modules") or []
apply_text = apply_patches_path.read_text(encoding="utf-8")

required_fields = {
    "id",
    "module",
    "function",
    "target",
    "target_family",
    "authority_class",
    "description",
    "retirement_trigger",
    "required",
}
allowed_authority = {
    "authority_correction",
    "temporary_compatibility_layer",
    "migration_guard",
    "filesystem_sync",
}
errors = []

if not patches:
    errors.append("manifest has no active patches")

for patch in patches:
    patch_id = patch.get("id", "<missing id>")
    missing = sorted(field for field in required_fields if field not in patch)
    if missing:
        errors.append(f"{patch_id}: missing fields: {', '.join(missing)}")
        continue

    if patch["authority_class"] not in allowed_authority:
        errors.append(f"{patch_id}: unsupported authority_class {patch['authority_class']!r}")

    module_path = repo_root / patch["module"]
    if not module_path.exists():
        errors.append(f"{patch_id}: module does not exist: {patch['module']}")
        continue

    module_text = module_path.read_text(encoding="utf-8")
    function_name = patch["function"]
    if function_name not in module_text:
        errors.append(f"{patch_id}: function {function_name} not found in {patch['module']}")
    if function_name not in apply_text:
        errors.append(f"{patch_id}: function {function_name} not wired by apply-patches.sh")

for item in inactive:
    module = item.get("module")
    if not module:
        errors.append("inactive_modules entry missing module")
        continue
    source_line = f'source "$PATCHES_DIR/{Path(module).name}"'
    if source_line in apply_text:
        errors.append(f"inactive module is still sourced by apply-patches.sh: {module}")

if errors:
    print("\n".join(errors))
    raise SystemExit(1)

print(len(patches))
PY
}

echo "=== Test Suite: Tutor Patch Authority ==="
echo ""

test_start "QA verifier entrypoint is executable"
if [[ -x "$VERIFY_SCRIPT" ]]; then
  test_pass
else
  test_fail "Script not executable: $VERIFY_SCRIPT"
fi

test_start "Canonical rendered verifier is executable"
if [[ -x "$CANONICAL_VERIFY_SCRIPT" ]]; then
  test_pass
else
  test_fail "Script not executable: $CANONICAL_VERIFY_SCRIPT"
fi

test_start "Patch manifest exists"
if [[ -f "$MANIFEST_FILE" ]]; then
  test_pass
else
  test_fail "Manifest file not found: $MANIFEST_FILE"
fi

test_start "Patch manifest schema and apply-patches wiring are valid"
if MANIFEST_PATCH_COUNT="$(run_manifest_check 2>&1)"; then
  test_pass
  echo -e "  ${GREEN}  Active manifest patches: ${MANIFEST_PATCH_COUNT}${NC}"
else
  test_fail "$MANIFEST_PATCH_COUNT"
fi

test_start "QA verifier delegates to canonical rendered verifier"
if grep -q 'scripts/infra/verify-tutor-config.sh' "$VERIFY_SCRIPT"; then
  test_pass
else
  test_fail "QA verifier must delegate to scripts/infra/verify-tutor-config.sh"
fi

test_start "Canonical verifier checks current MySQL 8.4 native-password flag"
if grep -q 'mysql-native-password=ON' "$CANONICAL_VERIFY_SCRIPT"; then
  test_pass
else
  test_fail "Canonical verifier must check --mysql-native-password=ON, not retired mysql_native_password syntax"
fi

test_start "Canonical verifier checks local MYSQL_ROOT_HOST contract"
if grep -q 'MYSQL_ROOT_HOST' "$CANONICAL_VERIFY_SCRIPT"; then
  test_pass
else
  test_fail "Canonical verifier does not check rendered MYSQL_ROOT_HOST"
fi

test_start "QA verifier runs against tutor_env through canonical verifier"
if [[ -d "$REPO_ROOT/tutor_env/env" ]]; then
  set +e
  VERIFY_OUTPUT="$("$VERIFY_SCRIPT" 2>&1)"
  VERIFY_RC=$?
  set -e

  if [[ "$VERIFY_RC" -eq 0 ]]; then
    test_pass
  else
    test_fail "Verifier exited $VERIFY_RC"
    printf '%s\n' "$VERIFY_OUTPUT"
  fi
else
  echo -e "  ${YELLOW}SKIP: tutor_env/env not found${NC}"
fi

test_start "Canonical verifier output has no failed checks"
if [[ -n "$VERIFY_OUTPUT" ]]; then
  if grep -Eq '(^\[FAIL\]|✗|ERROR:|FAIL \(|FAILURES:)' <<<"$VERIFY_OUTPUT"; then
    test_fail "Verifier reported failed checks"
    printf '%s\n' "$VERIFY_OUTPUT"
  else
    test_pass
  fi
else
  echo -e "  ${YELLOW}SKIP: verifier did not run${NC}"
fi

test_start "Canonical verifier reports concrete pass checks"
if [[ -n "$VERIFY_OUTPUT" ]]; then
  PATCH_COUNT=$(grep -c '✓' <<<"$VERIFY_OUTPUT" || true)
  if [[ "$PATCH_COUNT" -ge 20 ]]; then
    test_pass
    echo -e "  ${GREEN}  Found $PATCH_COUNT canonical rendered pass checks${NC}"
  else
    test_fail "Expected at least 20 canonical rendered pass checks, found $PATCH_COUNT"
  fi
else
  echo -e "  ${YELLOW}SKIP: verifier did not run${NC}"
fi

test_start "Legacy manifest verifier is not the branch-protection verifier"
if grep -qF "scripts/infra/verify-tutor-patches.sh" "$REPO_ROOT/.github/ci-scripts-static.txt"; then
  test_fail "Legacy infra verifier is still registered in static CI"
else
  test_pass
fi

test_start "Rendered verifier completes within 30 seconds"
if [[ -d "$REPO_ROOT/tutor_env/env" ]]; then
  START_TIME=$(date +%s)
  "$VERIFY_SCRIPT" >/dev/null 2>&1
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  if [[ "$DURATION" -lt 30 ]]; then
    test_pass
    echo -e "  ${GREEN}  Completed in ${DURATION}s${NC}"
  else
    test_fail "Took ${DURATION}s (threshold: 30s)"
  fi
else
  echo -e "  ${YELLOW}SKIP: tutor_env/env not found${NC}"
fi

echo ""
echo "=== Test Summary ==="
echo "Tests run: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [[ "$TESTS_FAILED" -eq 0 ]]; then
  echo -e "${GREEN}All Tutor patch authority tests passed.${NC}"
  exit 0
fi

echo -e "${RED}Some Tutor patch authority tests failed.${NC}"
exit 1
