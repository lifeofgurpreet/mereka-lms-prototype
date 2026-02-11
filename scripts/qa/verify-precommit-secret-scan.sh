#!/usr/bin/env bash
# @covers AC-027
# @spec: ci-cd-pipeline_spec.md
# Verify pre-commit hook exists and scans for hardcoded secrets.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS: $desc"; PASS=$((PASS+1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL+1))
  fi
}

HOOK="$REPO_ROOT/.githooks/pre-commit"

check "pre-commit hook exists" test -f "$HOOK"
check "pre-commit hook is executable" test -x "$HOOK"
check "pre-commit hook scans for PASSWORD patterns" grep -q "PASSWORD" "$HOOK"
check "pre-commit hook scans for API_KEY patterns" grep -q "api_key\|API_KEY\|apikey" "$HOOK"
check "pre-commit hook scans for SECRET_KEY patterns" grep -q "SECRET_KEY\|secret_key" "$HOOK"
check "pre-commit hook scans for private keys" grep -q "PRIVATE KEY" "$HOOK"
check "pre-commit hook scans for JWT tokens" grep -q "eyJ" "$HOOK"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
