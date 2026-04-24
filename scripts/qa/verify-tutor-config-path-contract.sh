#!/usr/bin/env bash
# @covers AC-RS-002
# @spec: repository-structure_spec.md
#
# Enforces canonical Tutor config path references for docs/specs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

PASS=0
FAIL=0

pass() {
  echo "  PASS: $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "  FAIL: $1"
  FAIL=$((FAIL + 1))
}

echo "=== Tutor Config Path Contract Verification ==="
echo "Repo: $REPO_ROOT"
echo ""

CANONICAL_TEMPLATE_PATH="infrastructure/tutor/config.example.yml"
if [[ -f "$REPO_ROOT/$CANONICAL_TEMPLATE_PATH" ]]; then
  pass "Canonical Tutor config template exists ($CANONICAL_TEMPLATE_PATH)"
else
  fail "Canonical Tutor config template missing ($CANONICAL_TEMPLATE_PATH)"
fi

echo ""
echo "-- Checking stale path references in docs/specs --"

STALE_PATHS=(
  "tutor_env/config.example.yml"
  "infrastructure/tutor/config.yml.example"
)

TMP_OUT="$(mktemp -t tutor-config-path-contract.XXXXXX)"
trap 'rm -f "$TMP_OUT"' EXIT

SCAN_PATHS=()
for path in docs specs README.md AGENTS.md; do
  [[ -e "$REPO_ROOT/$path" ]] && SCAN_PATHS+=("$REPO_ROOT/$path")
done

for stale in "${STALE_PATHS[@]}"; do
  if ((${#SCAN_PATHS[@]} == 0)); then
    pass "No docs/spec paths found to scan for stale references"
    continue
  fi
  if rg -n "$stale" "${SCAN_PATHS[@]}" >"$TMP_OUT" 2>/dev/null; then
    fail "Stale Tutor config path found: $stale"
    sed 's/^/    /' "$TMP_OUT"
  else
    pass "No stale references to $stale in docs/specs"
  fi
done

echo ""
echo "=== Summary ==="
echo "Pass: $PASS"
echo "Fail: $FAIL"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo "FAIL — Tutor config path contract violations detected."
  exit 1
fi

echo "PASS — Tutor config path contract holds."
