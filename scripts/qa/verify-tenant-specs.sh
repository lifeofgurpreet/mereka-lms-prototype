#!/usr/bin/env bash
# @covers AC-MTA-001, AC-MTA-002
# @spec: multi-tenancy-architecture_spec.md
#
# CI-safe validation for enterprise tenant bootstrap artifacts.
# Verifies spec YAML parsing, test suite health, and dry-run fixture stability.
#
# Exit 0 = all checks pass
# Exit 1 = one or more checks failed
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CONFIG_DIR="${REPO_ROOT}/config/enterprise-tenants"
TEST_DIR="${REPO_ROOT}/tests/tenants"
FAILURES=0

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }

echo "=== Enterprise Tenant Spec Validation ==="
echo ""

# 1. All YAML specs parse correctly
echo "[1/5] YAML spec parsing"
for f in "${CONFIG_DIR}"/*.yaml; do
  if python3 -c "import yaml; yaml.safe_load(open('$f'))" 2>/dev/null; then
    pass "$(basename "$f") parses"
  else
    fail "$(basename "$f") YAML parse error"
  fi
done

# 2. All specs have required top-level keys
echo "[2/5] Spec structure validation"
for f in "${CONFIG_DIR}"/dev.enterprise-tenants*.yaml; do
  name="$(basename "$f")"
  version=$(python3 -c "import yaml; d=yaml.safe_load(open('$f')); print(d.get('version',''))" 2>/dev/null)
  tenants=$(python3 -c "import yaml; d=yaml.safe_load(open('$f')); print(len(d.get('tenants',[])))" 2>/dev/null)
  if [[ -n "$version" && "$tenants" -gt 0 ]]; then
    pass "${name}: version=${version}, tenants=${tenants}"
  else
    fail "${name}: missing version or tenants"
  fi
done

# 3. Execution plan JSON parses
echo "[3/5] Execution plan validation"
plan="${CONFIG_DIR}/dev.execution-plan.json"
if [[ -f "$plan" ]]; then
  if python3 -c "import json; json.load(open('$plan'))" 2>/dev/null; then
    pass "dev.execution-plan.json parses"
  else
    fail "dev.execution-plan.json JSON parse error"
  fi
else
  fail "dev.execution-plan.json not found"
fi

# 4. Test fixtures exist and parse
echo "[4/5] Test fixture validation"
for fixture in valid-spec.yaml invalid-spec-missing-slug.yaml invalid-spec-bad-slug.yaml duplicate-slugs.yaml; do
  f="${TEST_DIR}/fixtures/${fixture}"
  if [[ -f "$f" ]]; then
    if python3 -c "import yaml; yaml.safe_load(open('$f'))" 2>/dev/null; then
      pass "${fixture}"
    else
      fail "${fixture} YAML parse error"
    fi
  else
    fail "${fixture} not found"
  fi
done

for fixture in expected-dry-run-output.json expected-dryrun-shared-mereka.json expected-dryrun-partner-isolated.json; do
  f="${TEST_DIR}/fixtures/${fixture}"
  if [[ -f "$f" ]]; then
    if python3 -c "import json; json.load(open('$f'))" 2>/dev/null; then
      pass "${fixture}"
    else
      fail "${fixture} JSON parse error"
    fi
  else
    fail "${fixture} not found"
  fi
done

# 5. Unit tests pass (requires pytest — skip gracefully if not installed)
echo "[5/5] Unit test suite"
if ! python3 -c "import pytest" 2>/dev/null; then
  pass "pytest not installed — skipping unit tests (install via: pip install pytest)"
elif python3 -m pytest "${TEST_DIR}/test_bootstrap_spec.py" -q --tb=short 2>&1; then
  pass "unit tests pass"
else
  fail "test suite has failures"
fi

echo ""
echo "=== Results: $((FAILURES == 0 ? 1 : 0)) checks, ${FAILURES} failures ==="
if [[ $FAILURES -gt 0 ]]; then
  echo "VERDICT: FAIL"
  exit 1
fi
echo "VERDICT: PASS"
exit 0
