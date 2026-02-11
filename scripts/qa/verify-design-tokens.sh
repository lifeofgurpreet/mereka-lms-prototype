#!/usr/bin/env bash
# @covers AC-003, AC-004
# @spec: design-tokens-system_spec.md
# Verify design tokens file has spacing tokens and :root selector.
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

TOKENS="$REPO_ROOT/assets/branding/tokens.css"

# AC-003: Spacing tokens exist
check "tokens.css exists" test -f "$TOKENS"
check "tokens.css has --space-0" grep -q "\-\-space-0" "$TOKENS"
check "tokens.css has --space-4" grep -q "\-\-space-4" "$TOKENS"
check "tokens.css has --space-8" grep -q "\-\-space-8" "$TOKENS"
check "tokens.css has --space-16" grep -q "\-\-space-16" "$TOKENS"
check "tokens.css has --space-24" grep -q "\-\-space-24" "$TOKENS"

# AC-004: All tokens defined within :root
check "tokens.css has :root selector" grep -q ":root" "$TOKENS"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
