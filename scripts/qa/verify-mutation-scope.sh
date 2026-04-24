#!/usr/bin/env bash
# Verify that changed files (vs HEAD or a base ref) fall within the
# allowed scope for a given agent lane.
#
# Lane definitions:
#   F — .github/, scripts/qa/, docs/stabilization/, var/proofs/, deploy/k8s/ (non-overlay), CLAUDE.md
#   A — deploy/k8s/, infrastructure/, services/, var/proofs/
#   E — docs/, specs/
#
# Usage:
#   scripts/qa/verify-mutation-scope.sh --lane <F|A|E> [--base <ref>]
#
# --base defaults to HEAD (staged + unstaged changes vs HEAD).
# Pass --base main to check the full branch diff vs main.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

LANE=""
BASE_REF="HEAD"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lane)
      LANE="${2:-}"
      shift 2
      ;;
    --base)
      BASE_REF="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 --lane <F|A|E> [--base <ref>]" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${LANE}" ]]; then
  echo "ERROR: --lane is required (F, A, or E)" >&2
  exit 1
fi

PASS=0
FAIL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() {
  echo -e "${GREEN}PASS${NC}  $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}FAIL${NC}  $1"
  FAIL=$((FAIL + 1))
}

echo "=== Mutation Scope Verification ==="
echo "Lane:     ${LANE}"
echo "Base ref: ${BASE_REF}"
echo "Repo:     ${REPO_ROOT}"
echo ""

if ! git -C "${REPO_ROOT}" rev-parse --git-dir >/dev/null 2>&1; then
  echo -e "${RED}FAIL${NC}  Not a git repository: ${REPO_ROOT}"
  exit 1
fi

# ---------------------------------------------------------------------------
# Declare allowed path prefixes per lane
# ---------------------------------------------------------------------------
declare -a ALLOWED_PREFIXES=()

case "${LANE}" in
  F)
    echo "Lane F allowed paths:"
    echo "  .github/  scripts/qa/  docs/stabilization/  var/proofs/"
    echo "  deploy/k8s/ (non-overlay)  CLAUDE.md"
    echo ""
    ALLOWED_PREFIXES=(
      ".github/"
      "scripts/qa/"
      "docs/stabilization/"
      "var/proofs/"
      "deploy/k8s/base/"
      "deploy/k8s/kustomization"
      "CLAUDE.md"
    )
    ;;
  A)
    echo "Lane A allowed paths:"
    echo "  deploy/k8s/  infrastructure/  services/  var/proofs/"
    echo ""
    ALLOWED_PREFIXES=(
      "deploy/k8s/"
      "infrastructure/"
      "services/"
      "var/proofs/"
    )
    ;;
  E)
    echo "Lane E allowed paths:"
    echo "  docs/  specs/"
    echo ""
    ALLOWED_PREFIXES=(
      "docs/"
      "specs/"
    )
    ;;
  *)
    echo -e "${RED}FAIL${NC}  Unknown lane '${LANE}'. Supported: F, A, E" >&2
    exit 1
    ;;
esac

# ---------------------------------------------------------------------------
# Collect changed files
# If BASE_REF is HEAD, compare staged+unstaged (working tree vs HEAD).
# If BASE_REF is a branch/SHA, use diff between that ref and the current HEAD.
# ---------------------------------------------------------------------------
if [[ "${BASE_REF}" == "HEAD" ]]; then
  # Staged changes
  STAGED="$(git -C "${REPO_ROOT}" diff --name-only --cached)"
  # Unstaged changes to tracked files
  UNSTAGED="$(git -C "${REPO_ROOT}" diff --name-only)"
  CHANGED_FILES="$(printf '%s\n%s\n' "${STAGED}" "${UNSTAGED}" | sort -u | grep -v '^$' || true)"
else
  CHANGED_FILES="$(git -C "${REPO_ROOT}" diff --name-only "${BASE_REF}...HEAD" | grep -v '^$' || true)"
fi

if [[ -z "${CHANGED_FILES}" ]]; then
  echo -e "      ${YELLOW}NOTE${NC}  No changed files detected vs ${BASE_REF}."
  pass "No files changed — scope check vacuously passes"
  echo ""
  echo "=== Summary ==="
  echo -e "Passed: ${GREEN}${PASS}${NC}"
  echo -e "Failed: ${RED}${FAIL}${NC}"
  echo ""
  echo -e "${GREEN}Mutation scope checks passed.${NC}"
  exit 0
fi

TOTAL=0
OUT_OF_SCOPE=0

echo "--- File scope check ---"

while IFS= read -r file; do
  [[ -z "${file}" ]] && continue
  TOTAL=$((TOTAL + 1))

  in_scope=0
  for prefix in "${ALLOWED_PREFIXES[@]}"; do
    if [[ "${file}" == "${prefix}"* || "${file}" == "${prefix}" ]]; then
      in_scope=1
      break
    fi
  done

  if [[ "${in_scope}" -eq 1 ]]; then
    pass "In scope: ${file}"
  else
    fail "OUT OF SCOPE for Lane ${LANE}: ${file}"
    OUT_OF_SCOPE=$((OUT_OF_SCOPE + 1))
  fi
done <<< "${CHANGED_FILES}"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Summary ==="
echo "Files checked: ${TOTAL}"
echo "Out of scope:  ${OUT_OF_SCOPE}"
echo -e "Passed: ${GREEN}${PASS}${NC}"
echo -e "Failed: ${RED}${FAIL}${NC}"
echo ""

if [[ ${FAIL} -eq 0 ]]; then
  echo -e "${GREEN}All changed files are within Lane ${LANE} scope.${NC}"
  exit 0
else
  echo -e "${RED}${FAIL} file(s) are outside the allowed scope for Lane ${LANE}.${NC}"
  exit 1
fi
