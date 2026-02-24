#!/usr/bin/env bash
# verify-github-app-token.sh
#
# Scans all .github/workflows/*.yml files for PAT usage patterns and checks
# migration progress toward GitHub App token adoption.
#
# Exit 0  — no PAT references remain (migration complete) OR continue-on-error mode
# Exit 1  — PAT references found and not in advisory mode
#
# Usage:
#   scripts/qa/verify-github-app-token.sh
#   scripts/qa/verify-github-app-token.sh [--advisory]   # always exit 0 (for CI during migration)
#
# See docs/operations/GITHUB_APP_TOKEN.md for the full migration guide.

set -euo pipefail

# ---------------------------------------------------------------------------
# Detect repo root
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOWS_DIR="${REPO_ROOT}/.github/workflows"

# ---------------------------------------------------------------------------
# CLI flags
# ---------------------------------------------------------------------------

ADVISORY=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --advisory) ADVISORY=true; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Color helpers
# ---------------------------------------------------------------------------

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() { echo -e "  ${GREEN}PASS${NC}  $*"; PASS_COUNT=$(( PASS_COUNT + 1 )); }
fail() { echo -e "  ${RED}FAIL${NC}  $*"; FAIL_COUNT=$(( FAIL_COUNT + 1 )); }
warn() { echo -e "  ${YELLOW}WARN${NC}  $*"; WARN_COUNT=$(( WARN_COUNT + 1 )); }
info() { echo -e "        $*"; }

# ---------------------------------------------------------------------------
# PAT patterns to flag
# ---------------------------------------------------------------------------

# Classic and common PAT secret names used in this repo and similar GitOps setups
PAT_PATTERNS=(
  'secrets\.GITOPS_PAT'
  'secrets\.GH_PAT'
  'secrets\.GITHUB_PAT'
  'secrets\.GH_TOKEN'
  'secrets\.BOT_TOKEN'
  'secrets\.ACCESS_TOKEN'
)

# App token indicator
APP_TOKEN_PATTERN='actions/create-github-app-token'

# Workflows where GITHUB_TOKEN (the built-in token) is expected to be sufficient
# and should NOT be flagged as needing an App token.
# Format: <workflow-filename>:<job-or-step-context>  (we just skip GITHUB_TOKEN checks globally)

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------

echo
echo -e "${BOLD}=== verify-github-app-token ===${NC}"
echo -e "      Workflows : ${WORKFLOWS_DIR}"
echo -e "      Policy    : docs/operations/GITHUB_APP_TOKEN.md"
if [[ "${ADVISORY}" == "true" ]]; then
  echo -e "      Mode      : advisory (exit always 0)"
fi
echo

if [[ ! -d "${WORKFLOWS_DIR}" ]]; then
  echo -e "${RED}ERROR${NC}: Workflows directory not found: ${WORKFLOWS_DIR}"
  exit 1
fi

# ---------------------------------------------------------------------------
# Collect workflow files
# ---------------------------------------------------------------------------

mapfile -t WORKFLOW_FILES < <(find "${WORKFLOWS_DIR}" -maxdepth 1 -name "*.yml" -type f | sort)

if [[ ${#WORKFLOW_FILES[@]} -eq 0 ]]; then
  warn "No workflow files found in ${WORKFLOWS_DIR}"
fi

TOTAL_WORKFLOWS=${#WORKFLOW_FILES[@]}

# ---------------------------------------------------------------------------
# Scan: PAT references
# ---------------------------------------------------------------------------

echo -e "${BOLD}--- PAT reference scan ---${NC}"

PAT_REF_COUNT=0
declare -A PAT_FILES  # file -> list of matching lines

for wf in "${WORKFLOW_FILES[@]}"; do
  wf_name="$(basename "${wf}")"
  for pattern in "${PAT_PATTERNS[@]}"; do
    matches=""
    matches="$(grep -nE "${pattern}" "${wf}" 2>/dev/null || true)"
    if [[ -n "${matches}" ]]; then
      while IFS= read -r line; do
        linenum="${line%%:*}"
        content="${line#*:}"
        PAT_FILES["${wf_name}"]="${PAT_FILES[${wf_name}]:-}  line ${linenum}: ${content}\n"
        PAT_REF_COUNT=$(( PAT_REF_COUNT + 1 ))
      done <<< "${matches}"
    fi
  done
done

if [[ ${PAT_REF_COUNT} -eq 0 ]]; then
  pass "No PAT references found across ${TOTAL_WORKFLOWS} workflow file(s)"
else
  for wf_name in "${!PAT_FILES[@]}"; do
    fail "PAT reference(s) in ${wf_name}:"
    # Print the stored lines (use printf to interpret \n)
    printf '%b' "${PAT_FILES[${wf_name}]}" | while IFS= read -r detail; do
      [[ -n "${detail}" ]] && info "${detail}"
    done
  done
fi

echo

# ---------------------------------------------------------------------------
# Scan: App token adoption
# ---------------------------------------------------------------------------

echo -e "${BOLD}--- GitHub App token adoption ---${NC}"

APP_TOKEN_REF_COUNT=0
APP_TOKEN_FILES=()

for wf in "${WORKFLOW_FILES[@]}"; do
  wf_name="$(basename "${wf}")"
  if grep -qE "${APP_TOKEN_PATTERN}" "${wf}" 2>/dev/null; then
    APP_TOKEN_REF_COUNT=$(( APP_TOKEN_REF_COUNT + 1 ))
    APP_TOKEN_FILES+=("${wf_name}")
  fi
done

if [[ ${APP_TOKEN_REF_COUNT} -eq 0 ]]; then
  warn "No workflows use 'actions/create-github-app-token' yet (migration not started)"
  info "See docs/operations/GITHUB_APP_TOKEN.md for setup instructions."
else
  pass "App token action found in ${APP_TOKEN_REF_COUNT} workflow file(s):"
  for f in "${APP_TOKEN_FILES[@]}"; do
    info "  - ${f}"
  done
fi

echo

# ---------------------------------------------------------------------------
# Check: GITHUB_TOKEN where App token may be needed
# ---------------------------------------------------------------------------

echo -e "${BOLD}--- GITHUB_TOKEN adequacy check ---${NC}"

# Workflows that push to external repos cannot use GITHUB_TOKEN (which is
# scoped to the current repo only). Flag any workflow that references a
# cross-repo checkout/push without an App token.
CROSS_REPO_PAT_ISSUES=0

for wf in "${WORKFLOW_FILES[@]}"; do
  wf_name="$(basename "${wf}")"

  # A workflow is suspect if it checks out a *different* repository AND
  # uses GITHUB_TOKEN (not an App token) for the checkout token field.
  has_external_repo=""
  has_external_repo="$(grep -E "^\s+repository:\s+['\"]?[^'\"[:space:]]+/[^'\"[:space:]]+" "${wf}" 2>/dev/null \
    | grep -v 'Biji-Biji-Initiative/mereka-lms' \
    | grep -v 'github\.repository' \
    || true)"

  uses_app_token=""
  uses_app_token="$(grep -E "${APP_TOKEN_PATTERN}" "${wf}" 2>/dev/null || true)"

  if [[ -n "${has_external_repo}" && -z "${uses_app_token}" ]]; then
    # Check if it uses GITHUB_TOKEN for the token field (might be intentional for public repos)
    uses_builtin=""
    uses_builtin="$(grep -E "token:\s+\\\$\{\{\s*secrets\.GITHUB_TOKEN\s*\}\}" "${wf}" 2>/dev/null || true)"
    if [[ -n "${uses_builtin}" ]]; then
      warn "${wf_name}: checks out external repo with secrets.GITHUB_TOKEN — may fail for private repos"
      info "  Consider using 'actions/create-github-app-token' instead."
      CROSS_REPO_PAT_ISSUES=$(( CROSS_REPO_PAT_ISSUES + 1 ))
    fi
  fi
done

if [[ ${CROSS_REPO_PAT_ISSUES} -eq 0 ]]; then
  pass "No GITHUB_TOKEN adequacy issues found for cross-repo operations"
fi

echo

# ---------------------------------------------------------------------------
# Migration progress
# ---------------------------------------------------------------------------

echo -e "${BOLD}--- Migration progress ---${NC}"

if [[ ${PAT_REF_COUNT} -eq 0 && ${APP_TOKEN_REF_COUNT} -gt 0 ]]; then
  MIGRATION_STATUS="COMPLETE"
  pass "Migration status: COMPLETE — all PAT references replaced with App token"
elif [[ ${PAT_REF_COUNT} -eq 0 && ${APP_TOKEN_REF_COUNT} -eq 0 ]]; then
  MIGRATION_STATUS="NOT_STARTED"
  warn "Migration status: NOT STARTED — no PATs and no App token (check if GitOps push is needed)"
elif [[ ${PAT_REF_COUNT} -gt 0 && ${APP_TOKEN_REF_COUNT} -gt 0 ]]; then
  MIGRATION_STATUS="IN_PROGRESS"
  warn "Migration status: IN PROGRESS — ${PAT_REF_COUNT} PAT ref(s) remain, ${APP_TOKEN_REF_COUNT} workflow(s) migrated"
else
  MIGRATION_STATUS="NOT_STARTED"
  warn "Migration status: NOT STARTED — ${PAT_REF_COUNT} PAT ref(s) found, 0 workflows migrated"
  info "See docs/operations/GITHUB_APP_TOKEN.md to begin migration."
fi

echo
info "  PAT references   : ${PAT_REF_COUNT}"
info "  App token refs   : ${APP_TOKEN_REF_COUNT}"
info "  Total workflows  : ${TOTAL_WORKFLOWS}"
echo

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo -e "${BOLD}--- Summary ---${NC}"
echo -e "  PASS: ${PASS_COUNT}  WARN: ${WARN_COUNT}  FAIL: ${FAIL_COUNT}"
echo

if [[ ${FAIL_COUNT} -eq 0 && ${WARN_COUNT} -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}RESULT: PASS${NC}"
  exit 0
elif [[ ${FAIL_COUNT} -eq 0 ]]; then
  echo -e "${YELLOW}${BOLD}RESULT: WARN — migration in progress or not started${NC}"
  echo -e "  See docs/operations/GITHUB_APP_TOKEN.md for next steps."
  if [[ "${ADVISORY}" == "true" ]]; then
    exit 0
  fi
  exit 0  # WARNs alone are not blocking; FAIL blocks
else
  echo -e "${RED}${BOLD}RESULT: FAIL — ${FAIL_COUNT} PAT reference(s) remain${NC}"
  echo -e "  Migrate to GitHub App token. See docs/operations/GITHUB_APP_TOKEN.md"
  if [[ "${ADVISORY}" == "true" ]]; then
    echo -e "  (advisory mode — exiting 0)"
    exit 0
  fi
  exit 1
fi
