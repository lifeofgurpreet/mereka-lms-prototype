#!/usr/bin/env bash
# @covers AC-222-A1, AC-222-A2
# @spec: repository-structure_spec.md
# Enforce canonical authn submodule path contract.
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$REPO_ROOT"

CANONICAL_PATH="tmp/frontend-app-authn"
CANONICAL_URL="https://github.com/openedx/frontend-app-authn"
LEGACY_PATH="apps/frontend-app-authn"

red=$'\033[0;31m'
green=$'\033[0;32m'
reset=$'\033[0m'

findings=0

# 1a) .gitmodules must declare canonical submodule path.
if ! git config -f .gitmodules --get-regexp '^submodule\..*\.path$' | grep -q "${CANONICAL_PATH}$"; then
  printf '%sFAIL%s .gitmodules missing canonical path: %s\n' "$red" "$reset" "$CANONICAL_PATH"
  findings=$((findings + 1))
fi

# 1b) .gitmodules must pin canonical upstream URL.
if ! git config -f .gitmodules --get-regexp '^submodule\..*\.url$' | grep -q "${CANONICAL_URL}$"; then
  printf '%sFAIL%s .gitmodules missing canonical URL: %s\n' "$red" "$reset" "$CANONICAL_URL"
  findings=$((findings + 1))
fi

# 1c) canonical path must be tracked as a gitlink.
if ! git ls-files -s "$CANONICAL_PATH" | awk '{print $1}' | grep -q '^160000$'; then
  printf '%sFAIL%s canonical submodule is not tracked as gitlink: %s\n' "$red" "$reset" "$CANONICAL_PATH"
  findings=$((findings + 1))
fi

# 1d) forbid additional tracked tmp/frontend-app-* clones/submodules.
while IFS= read -r entry; do
  [[ -z "$entry" ]] && continue
  path="$(awk '{print $4}' <<<"$entry")"
  mode="$(awk '{print $1}' <<<"$entry")"
  if [[ "$path" == "$CANONICAL_PATH" ]]; then
    continue
  fi
  printf '%sFAIL%s tracked tmp frontend app path outside canonical allowlist: %s (mode=%s)\n' "$red" "$reset" "$path" "$mode"
  findings=$((findings + 1))
done < <(git ls-files -s 'tmp/frontend-app-*' || true)

# 1e) .gitignore must ignore tmp/frontend-app-* with explicit canonical allowlist exception.
if ! rg -n -F 'tmp/frontend-app-*/' .gitignore >/dev/null 2>&1; then
  printf '%sFAIL%s .gitignore missing tmp frontend clone ignore rule\n' "$red" "$reset"
  findings=$((findings + 1))
fi
if ! rg -n -F '!tmp/frontend-app-authn/' .gitignore >/dev/null 2>&1; then
  printf '%sFAIL%s .gitignore missing canonical submodule exception rule\n' "$red" "$reset"
  findings=$((findings + 1))
fi

# 2) Contract docs/specs must not reference legacy path.
CONTRACT_FILES=(
  "README.md"
  "docs/guides/onboarding/REPOSITORY_GUIDE.md"
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
