#!/usr/bin/env bash
# @covers AC-DEPL-001
# @spec: k8s-deployment_spec.md
#
# Guard: every path deleted under deploy/k8s/overlays/ must have its
# repo-wide consumer references cleared or covered by an absence-tolerance
# annotation before the PR merges.
#
# What it does:
#   1. Resolves the diff base (main...HEAD) and collects every D-status
#      entry under deploy/k8s/overlays/.
#   2. For each deleted path, greps the full repo for string references.
#   3. A reference is considered TOLERATED if the file containing it also
#      contains an absence-tolerance marker — the canonical pattern used
#      throughout this repo for Wave 9 shadow deletions:
#        • if [[ -d <DIR> ]]; then ... elif [[ -f docs/reference/architecture/DEPLOYMENT_CONTRACT.md ]]; then
#        • Wave 9 absent
#        • absence tolerance
#      Any file that matches the deleted path string AND contains one of
#      those tolerance markers is skipped.
#   4. Files that reference the path WITHOUT a tolerance marker are reported
#      as offenders.  The script exits non-zero listing them.
#
# On main (zero deleted overlays in the diff), the script passes immediately.
#
# Usage:
#   scripts/qa/verify-deletion-wave-consumer-sweep.sh
#
# Environment overrides:
#   DIFF_BASE          — commit/ref to diff from (default: main)
#   REPO_ROOT_OVERRIDE — override repo root detection

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
DIFF_BASE="${DIFF_BASE:-main}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() {
  echo -e "${GREEN}PASS${NC}  $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}FAIL${NC}  $1"
  FAIL=$((FAIL + 1))
}

warn() {
  echo -e "${YELLOW}WARN${NC}  $1"
  WARN=$((WARN + 1))
}

echo "=== Deletion Wave Consumer Sweep ==="
echo "Repository:  ${REPO_ROOT}"
echo "Diff base:   ${DIFF_BASE}"
echo ""

# ---------------------------------------------------------------------------
# 1. Collect deleted paths under deploy/k8s/overlays/
# ---------------------------------------------------------------------------
cd "${REPO_ROOT}"

deleted_paths=()
while IFS=$'\t' read -r status path; do
  [[ "${status}" == D* ]] || continue
  case "${path}" in
    deploy/k8s/overlays/*)
      deleted_paths+=("${path}")
      ;;
  esac
done < <(git diff --name-status "${DIFF_BASE}...HEAD" 2>/dev/null || true)

if [[ ${#deleted_paths[@]} -eq 0 ]]; then
  pass "No deploy/k8s/overlays/ paths deleted in this diff — nothing to sweep"
  echo ""
  echo "=== Summary ==="
  echo -e "Passed: ${GREEN}${PASS}${NC}  Warned: ${YELLOW}${WARN}${NC}  Failed: ${RED}${FAIL}${NC}"
  echo ""
  echo -e "${GREEN}All deletion-wave consumer checks passed.${NC}"
  exit 0
fi

echo "Deleted overlay paths (${#deleted_paths[@]}):"
for p in "${deleted_paths[@]}"; do
  echo "  - ${p}"
done
echo ""

# ---------------------------------------------------------------------------
# 2. Absence-tolerance markers (any of these patterns in a file = tolerated)
# ---------------------------------------------------------------------------
# A file is considered to carry an absence-tolerance annotation if it
# contains at least one of these patterns (case-insensitive).
#
# The patterns are chosen to match the existing Wave 9 tolerance idiom seen
# in verify-kustomize-structure.sh, verify-k8s-images.sh, etc.
TOLERANCE_PATTERNS=(
  "absence tolerance"
  "Wave 9 absent"
  "Wave 9 shadow deletion"
  "Wave 9 deletion complete"
  "Wave 9.*absent"
  "absent.*Wave 9"
  "DEPLOYMENT_CONTRACT"
  "overlay_absent"
  "overlay.*absent"
  "absent.*overlay"
)

# ---------------------------------------------------------------------------
# Helper: check if a file contains any tolerance marker
# ---------------------------------------------------------------------------
file_is_tolerant() {
  local filepath="$1"
  [[ -f "${filepath}" ]] || return 1
  for pattern in "${TOLERANCE_PATTERNS[@]}"; do
    if grep -qiE "${pattern}" "${filepath}" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

# ---------------------------------------------------------------------------
# 3. For each deleted path, sweep for references
# ---------------------------------------------------------------------------
echo "--- Consumer sweep ---"
echo ""

all_clean=true

for deleted in "${deleted_paths[@]}"; do
  # Grep for the verbatim deleted path string across repo text files.
  # git grep --full-name searches committed content; we also check the
  # working tree for modified-but-not-committed references.
  echo "Scanning references to: ${deleted}"

  offenders=()
  tolerated=()

  while IFS= read -r hit_file; do
    [[ -z "${hit_file}" ]] && continue
    # Skip the deleted file itself (already gone from HEAD)
    [[ "${hit_file}" == "${deleted}" ]] && continue
    # Skip generated / gitignored artifacts
    case "${hit_file}" in
      .git/*|var/*|tutor_env/*)
        continue
        ;;
    esac

    if file_is_tolerant "${REPO_ROOT}/${hit_file}"; then
      tolerated+=("${hit_file}")
    else
      offenders+=("${hit_file}")
    fi
  done < <(
    git grep -l --full-name "${deleted}" -- \
      '*.sh' '*.py' '*.yaml' '*.yml' '*.md' '*.txt' '*.json' '*.toml' \
      2>/dev/null \
    | sort
  )

  if [[ ${#offenders[@]} -eq 0 && ${#tolerated[@]} -eq 0 ]]; then
    pass "No remaining references to ${deleted}"
  elif [[ ${#offenders[@]} -eq 0 ]]; then
    pass "All ${#tolerated[@]} reference(s) to ${deleted} carry absence-tolerance markers"
    for t in "${tolerated[@]}"; do
      echo "         tolerated: ${t}"
    done
  else
    all_clean=false
    fail "${#offenders[@]} non-tolerated reference(s) remain for deleted path: ${deleted}"
    echo ""
    echo "  Offending files (reference the deleted path without absence-tolerance):"
    for o in "${offenders[@]}"; do
      echo "    ${RED}→${NC} ${o}"
    done
    if [[ ${#tolerated[@]} -gt 0 ]]; then
      echo ""
      echo "  Already-tolerated files (OK — no action needed):"
      for t in "${tolerated[@]}"; do
        echo "    ${GREEN}✓${NC} ${t}"
      done
    fi
    echo ""
    echo "  To resolve: either"
    echo "    (a) Remove or update the reference in each offending file, OR"
    echo "    (b) Add an absence-tolerance guard like:"
    echo "          if [[ -d deploy/k8s/overlays/<name> ]]; then"
    echo "            # normal check"
    echo "          elif [[ -f docs/reference/architecture/DEPLOYMENT_CONTRACT.md ]]; then"
    echo "            pass \"<overlay> absent (Wave 9 shadow deletion — canonical boundary doc present)\""
    echo "          fi"
    echo ""
  fi
done

# ---------------------------------------------------------------------------
# 4. Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Summary ==="
echo -e "Passed: ${GREEN}${PASS}${NC}  Warned: ${YELLOW}${WARN}${NC}  Failed: ${RED}${FAIL}${NC}"
echo ""

if [[ ${FAIL} -eq 0 ]]; then
  echo -e "${GREEN}All deletion-wave consumer checks passed.${NC}"
  exit 0
else
  echo -e "${RED}${FAIL} check(s) failed — orphaned references block this deletion.${NC}"
  exit 1
fi
