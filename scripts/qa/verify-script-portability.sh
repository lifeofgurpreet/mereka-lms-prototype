#!/usr/bin/env bash
# Ensure automation shell scripts remain workstation-agnostic.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

violations=0
checks=0
declare -a TARGET_DIRS=()

usage() {
  cat <<'EOF'
Usage: ./scripts/qa/verify-script-portability.sh [--dir <relative-or-abs-dir>]...

Checks shell automation directories for workstation-specific absolute path literals.
Defaults:
  scripts/qa
  scripts/infra
  scripts/branding
  scripts/migrations
EOF
}

fail() {
  printf '%sFAIL%s %s\n' "$RED" "$NC" "$1"
  violations=$((violations + 1))
}

pass() {
  printf '%sPASS%s %s\n' "$GREEN" "$NC" "$1"
  checks=$((checks + 1))
}

warn() {
  printf '%sWARN%s %s\n' "$YELLOW" "$NC" "$1"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      [[ $# -lt 2 ]] && { echo "Missing value for --dir" >&2; exit 1; }
      TARGET_DIRS+=("$2")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "${#TARGET_DIRS[@]}" -eq 0 ]]; then
  TARGET_DIRS=(
    "scripts/qa"
    "scripts/infra"
    "scripts/branding"
    "scripts/migrations"
  )
fi

echo "=== Script Portability Verification ==="
echo

tmp_hits="$(mktemp -t verify-script-portability.XXXXXX)"
trap 'rm -f "$tmp_hits"' EXIT

for dir in "${TARGET_DIRS[@]}"; do
  if [[ ! -d "$dir" ]]; then
    warn "directory missing, skipping: $dir"
    continue
  fi

  # POSIX workstation path literals.
  # Exclude scripts whose purpose is to detect hardcoded paths (they contain the pattern by design).
  if rg -n --color=never --glob '*.sh' --glob '!test-*.sh' \
       --glob '!verify-no-hardcoded-user-paths.sh' \
       --glob '!verify-no-hardcoded-dev-paths.sh' \
       '/(home|Users)/[^[:space:]"'"'"'`]+' "$dir" >>"$tmp_hits"; then
    :
  fi
  # Windows workstation path literals.
  if rg -n --color=never --glob '*.sh' --glob '!test-*.sh' '[A-Za-z]:\\Users\\[^[:space:]"'"'"'`]+' "$dir" >>"$tmp_hits"; then
    :
  fi
done

if [[ -s "$tmp_hits" ]]; then
  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    fail "workstation path literal found: $hit"
  done <"$tmp_hits"
else
  pass "no workstation absolute paths detected in target script directories"
fi

echo
echo "=== Summary ==="
echo "Checks     : $checks"
echo "Violations : $violations"
echo

if [[ "$violations" -gt 0 ]]; then
  echo "FAIL — script portability violations found."
  echo "Use REPO_ROOT-relative paths and environment variables."
  exit 1
fi

echo "PASS — script portability checks passed."
