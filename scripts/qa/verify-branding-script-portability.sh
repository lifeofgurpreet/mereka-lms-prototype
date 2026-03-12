#!/usr/bin/env bash
# @covers AC-007
# @spec: branding-system_spec.md
# Ensure branding automation scripts remain workstation-agnostic.
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$REPO_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

violations=0
checks=0

fail() {
  printf '%sFAIL%s %s\n' "$RED" "$NC" "$1"
  violations=$((violations + 1))
}

pass() {
  printf '%sPASS%s %s\n' "$GREEN" "$NC" "$1"
  checks=$((checks + 1))
}

echo "=== Branding Script Portability Verification ==="
echo

TARGET_DIR="$REPO_ROOT/scripts/branding"
if [[ ! -d "$TARGET_DIR" ]]; then
  fail "missing directory: scripts/branding"
  exit 1
fi

# Block absolute workstation-style paths in branding automation scripts.
# Portable scripts must resolve paths from REPO_ROOT or environment variables.
if rg -n --color=never --glob '*.sh' '/(home|Users)/[^[:space:]"'"'"'`]+' "$TARGET_DIR" >/tmp/branding_portability_hits.txt; then
  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    fail "workstation path literal found: $hit"
  done </tmp/branding_portability_hits.txt
else
  pass "no workstation absolute paths detected in scripts/branding/*.sh"
fi
rm -f /tmp/branding_portability_hits.txt

echo
echo "=== Summary ==="
echo "Checks     : $checks"
echo "Violations : $violations"
echo

if [[ "$violations" -gt 0 ]]; then
  echo "FAIL — branding script portability violations found."
  echo "Use REPO_ROOT-relative paths and env vars instead of workstation absolute paths."
  exit 1
fi

echo "PASS — branding script portability checks passed."
