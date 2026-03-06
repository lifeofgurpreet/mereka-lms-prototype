#!/usr/bin/env bash
# @covers AC-222-A1, AC-222-A2
# @spec: repository-structure_spec.md
# Enforce canonical authn submodule path contract.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

CANONICAL_PATH="tmp/frontend-app-authn"
LEGACY_PATH="apps/frontend-app-authn"

red=$'\033[0;31m'
green=$'\033[0;32m'
reset=$'\033[0m'

findings=0

# 1) .gitmodules must declare canonical submodule path.
if ! git config -f .gitmodules --get-regexp '^submodule\..*\.path$' | grep -q "${CANONICAL_PATH}$"; then
  printf '%sFAIL%s .gitmodules missing canonical path: %s\n' "$red" "$reset" "$CANONICAL_PATH"
  findings=$((findings + 1))
fi

# 2) Contract docs/specs must not reference legacy path.
CONTRACT_FILES=(
  "README.md"
  "docs/onboarding/REPOSITORY_GUIDE.md"
  "specs/repository-structure_spec.md"
)

for file in "${CONTRACT_FILES[@]}"; do
  if rg -n -F "$LEGACY_PATH" "$file" >/tmp/authn-path-check.out 2>/dev/null; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      printf '%sFAIL%s legacy path reference found: %s\n' "$red" "$reset" "$line"
      findings=$((findings + 1))
    done </tmp/authn-path-check.out
  fi

  if ! rg -n -F "$CANONICAL_PATH" "$file" >/dev/null 2>&1; then
    printf '%sFAIL%s canonical path not referenced in %s\n' "$red" "$reset" "$file"
    findings=$((findings + 1))
  fi
done

rm -f /tmp/authn-path-check.out

if [[ "$findings" -gt 0 ]]; then
  echo ""
  echo "Authn submodule path contract failed with $findings finding(s)."
  exit 1
fi

printf '%sPASS%s authn submodule path contract is consistent (%s)\n' "$green" "$reset" "$CANONICAL_PATH"
