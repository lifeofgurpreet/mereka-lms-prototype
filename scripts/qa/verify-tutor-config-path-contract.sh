#!/usr/bin/env bash
# @covers AC-RS-002
# @spec: repository-structure_spec.md
#
# Enforces canonical Tutor config path references for docs/specs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

for stale in "${STALE_PATHS[@]}"; do
  if rg -n --glob 'docs/**' --glob 'specs/**' --glob 'README.md' --glob 'AGENTS.md' "$stale" "$REPO_ROOT" >/tmp/tutor-config-path-contract.out 2>/dev/null; then
    fail "Stale Tutor config path found: $stale"
    sed 's/^/    /' /tmp/tutor-config-path-contract.out
  else
    pass "No stale references to $stale in docs/specs"
  fi
done
rm -f /tmp/tutor-config-path-contract.out

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
