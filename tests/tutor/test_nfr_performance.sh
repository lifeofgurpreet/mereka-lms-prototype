#!/usr/bin/env bash
# Non-functional requirements tests: Performance, offline operation, manifest quality
# Coverage: NFR tests from testplan

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY_SCRIPT="$REPO_ROOT/scripts/qa/verify-tutor-patches.sh"
MANIFEST_CONTRACT_SCRIPT="$REPO_ROOT/scripts/qa/verify-tutor-patch-manifest-contract.sh"
MANIFEST_FILE="$REPO_ROOT/infrastructure/tutor/patch-manifest.yml"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

test_start() {
  TESTS_RUN=$((TESTS_RUN + 1))
  echo -e "${YELLOW}TEST $TESTS_RUN: $1${NC}"
}

test_pass() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo -e "${GREEN}  ✓ PASS${NC}"
}

test_fail() {
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo -e "${RED}  ✗ FAIL: $1${NC}"
}

echo "=== Test Suite: Non-Functional Requirements ==="
echo ""

# NFR-001: Verification speed (<30s)
test_start "Full manifest verification completes in <30s"
if [[ -d "$REPO_ROOT/tutor_env" ]]; then
  START_TIME=$(date +%s)
  "$VERIFY_SCRIPT" >/dev/null 2>&1 || true
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  if [[ $DURATION -lt 30 ]]; then
    test_pass
    echo -e "  ${GREEN}  Completed in ${DURATION}s (threshold: 30s)${NC}"
  else
    test_fail "Took ${DURATION}s (threshold: 30s)"
  fi
else
  echo -e "  ${YELLOW}SKIP: tutor_env not found${NC}"
fi

# NFR-002: Manifest readability (yamllint)
test_start "Manifest passes yamllint validation"
if command -v yamllint >/dev/null 2>&1; then
  if yamllint -d '{extends: default, rules: {line-length: {max: 200}}}' "$MANIFEST_FILE" >/dev/null 2>&1; then
    test_pass
  else
    test_fail "yamllint found issues"
    yamllint "$MANIFEST_FILE" || true
  fi
else
  echo -e "  ${YELLOW}SKIP: yamllint not installed${NC}"
fi

# NFR-003: Offline operation (no network calls)
test_start "Verification script works without network access"
if [[ -d "$REPO_ROOT/tutor_env" ]]; then
  # Check if verification script makes network calls (grep for curl, wget, http://, https://)
  if grep -qE 'curl|wget|http://|https://' "$VERIFY_SCRIPT"; then
    test_fail "Script contains network-related commands"
  else
    test_pass
  fi
else
  echo -e "  ${YELLOW}SKIP: tutor_env not found${NC}"
fi

# NFR-004: Active manifest has authority metadata for every remaining patch
test_start "Manifest documents active patch authority and retirement metadata"
set +e
MANIFEST_CHECK_OUTPUT=$("$MANIFEST_CONTRACT_SCRIPT" 2>&1)
MANIFEST_CHECK_RC=$?
set -e

if [[ "$MANIFEST_CHECK_RC" -eq 0 ]]; then
  test_pass
  echo -e "  ${GREEN}  $MANIFEST_CHECK_OUTPUT${NC}"
else
  test_fail "$MANIFEST_CHECK_OUTPUT"
fi

# NFR-005: Temporary compatibility patches have retirement triggers
test_start "Temporary compatibility patches have retirement triggers"
set +e
TEMPORARY_CHECK_OUTPUT=$(
  python3 - "$MANIFEST_FILE" <<'PY'
import sys
from pathlib import Path

try:
    import yaml
except ImportError as exc:
    raise SystemExit(f"PyYAML unavailable: {exc}")

payload = yaml.safe_load(Path(sys.argv[1]).read_text(encoding="utf-8")) or {}
patches = payload.get("patches") or []
missing = [
    patch.get("id", "<missing id>")
    for patch in patches
    if patch.get("authority_class") == "temporary_compatibility_layer"
    and not patch.get("retirement_trigger")
]
if missing:
    print(", ".join(missing))
    raise SystemExit(1)
print(sum(1 for patch in patches if patch.get("authority_class") == "temporary_compatibility_layer"))
PY
)
TEMPORARY_CHECK_RC=$?
set -e

if [[ "$TEMPORARY_CHECK_RC" -eq 0 ]]; then
  test_pass
  echo -e "  ${GREEN}  Temporary compatibility patches with retirement triggers: $TEMPORARY_CHECK_OUTPUT${NC}"
else
  test_fail "Missing retirement trigger for: $TEMPORARY_CHECK_OUTPUT"
fi

# NFR-006: Manifest is machine-parseable
test_start "Patch manifest can be parsed as YAML"
if python3 -c "import yaml, sys; yaml.safe_load(open(sys.argv[1], encoding='utf-8'))" "$MANIFEST_FILE" 2>/dev/null; then
  test_pass
else
  test_fail "Patch manifest is not valid YAML"
fi

# NFR-007: Verification script has proper error handling
test_start "Verification script uses set -euo pipefail"
if grep -q "set -euo pipefail" "$VERIFY_SCRIPT"; then
  test_pass
else
  test_fail "Script missing strict error handling"
fi

# Summary
echo ""
echo "=== Test Summary ==="
echo "Tests run: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo -e "${GREEN}✓ All NFR tests passed!${NC}"
  exit 0
else
  echo -e "${RED}✗ Some tests failed${NC}"
  exit 1
fi
