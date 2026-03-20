#!/usr/bin/env bash
# verify-branch-protection.sh
#
# Verifies that the main branch protection settings meet the requirements
# documented in docs/policies/operations/BRANCH_PROTECTION.md.
#
# Exit 0  — all required settings are compliant
# Exit 1  — one or more settings are missing or misconfigured
#
# Usage:
#   scripts/qa/verify-branch-protection.sh
#   scripts/qa/verify-branch-protection.sh [--owner <org>] [--repo <name>] [--branch <name>]
#
# Requirements:
#   - gh CLI authenticated with a token that has Administration: read on the repo
#   - jq installed
#
# See docs/policies/operations/BRANCH_PROTECTION.md for the full policy.

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration defaults (can be overridden via CLI args)
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Attempt to infer owner/repo from git remote
_default_remote() {
  git -C "${REPO_ROOT}" remote get-url origin 2>/dev/null \
    | sed -E 's|.*github\.com[:/]([^/]+/[^/.]+)(\.git)?$|\1|' \
    || true
}

REMOTE="$(_default_remote)"
OWNER="${OWNER:-${REMOTE%%/*}}"
REPO="${REPO:-${REMOTE##*/}}"
BRANCH="${BRANCH:-main}"

# Parse optional flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner) OWNER="$2"; shift 2 ;;
    --repo)  REPO="$2";  shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

pass()  { echo -e "  ${GREEN}PASS${RESET}  $*"; }
fail()  { echo -e "  ${RED}FAIL${RESET}  $*"; FAILURES=$(( FAILURES + 1 )); }
warn()  { echo -e "  ${YELLOW}WARN${RESET}  $*"; }
info()  { echo -e "        $*"; }

FAILURES=0

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------

echo
echo -e "${BOLD}=== verify-branch-protection ===${RESET}"
echo -e "      Repo  : ${OWNER}/${REPO}"
echo -e "      Branch: ${BRANCH}"
echo -e "      Policy: docs/policies/operations/BRANCH_PROTECTION.md"
echo

if ! command -v gh &>/dev/null; then
  echo -e "${RED}ERROR${RESET}: 'gh' CLI not found. Install from https://cli.github.com/"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo -e "${RED}ERROR${RESET}: 'jq' not found. Install with: apt-get install jq / brew install jq"
  exit 1
fi

if [[ -z "${OWNER}" || -z "${REPO}" ]]; then
  echo -e "${RED}ERROR${RESET}: Could not determine owner/repo. Use --owner and --repo flags."
  exit 1
fi

# Verify gh is authenticated
if ! gh auth status &>/dev/null; then
  echo -e "${RED}ERROR${RESET}: gh CLI is not authenticated. Run: gh auth login"
  exit 1
fi

# ---------------------------------------------------------------------------
# Fetch branch protection data
# ---------------------------------------------------------------------------

echo -e "${BOLD}Fetching branch protection settings...${RESET}"

PROTECTION_JSON="$(gh api \
  "repos/${OWNER}/${REPO}/branches/${BRANCH}/protection" \
  --header "Accept: application/vnd.github+json" \
  2>&1)" || {
  HTTP_STATUS="$?"
  if echo "${PROTECTION_JSON}" | grep -q "Branch not protected"; then
    echo -e "${RED}FAIL${RESET}: Branch '${BRANCH}' has NO protection rules configured."
    echo -e "       See docs/policies/operations/BRANCH_PROTECTION.md to set up protection."
    exit 1
  fi
  if echo "${PROTECTION_JSON}" | grep -q "Not Found"; then
    echo -e "${RED}ERROR${RESET}: Repository '${OWNER}/${REPO}' not found or token lacks permission."
    exit 1
  fi
  echo -e "${RED}ERROR${RESET}: gh api returned status ${HTTP_STATUS}:"
  echo "${PROTECTION_JSON}"
  exit 1
}

echo -e "  ${GREEN}OK${RESET}    Branch protection is enabled."
echo

# ---------------------------------------------------------------------------
# Check: Required pull request reviews
# ---------------------------------------------------------------------------

echo -e "${BOLD}--- Pull Request Reviews ---${RESET}"

PR_REVIEWS="$(echo "${PROTECTION_JSON}" | jq -r '.required_pull_request_reviews // empty')"

if [[ -z "${PR_REVIEWS}" ]]; then
  fail "required_pull_request_reviews: not configured"
else
  REQUIRED_COUNT="$(echo "${PROTECTION_JSON}" | jq -r '.required_pull_request_reviews.required_approving_review_count // 0')"
  if [[ "${REQUIRED_COUNT}" -ge 1 ]]; then
    pass "required_approving_review_count >= 1 (got: ${REQUIRED_COUNT})"
  else
    fail "required_approving_review_count must be >= 1 (got: ${REQUIRED_COUNT})"
  fi

  DISMISS_STALE="$(echo "${PROTECTION_JSON}" | jq -r '.required_pull_request_reviews.dismiss_stale_reviews // false')"
  if [[ "${DISMISS_STALE}" == "true" ]]; then
    pass "dismiss_stale_reviews: enabled"
  else
    fail "dismiss_stale_reviews: must be enabled (currently: ${DISMISS_STALE})"
  fi
fi

echo

# ---------------------------------------------------------------------------
# Check: Required status checks
# ---------------------------------------------------------------------------

echo -e "${BOLD}--- Required Status Checks ---${RESET}"

STATUS_CHECKS="$(echo "${PROTECTION_JSON}" | jq -r '.required_status_checks // empty')"

if [[ -z "${STATUS_CHECKS}" ]]; then
  fail "required_status_checks: not configured"
else
  STRICT="$(echo "${PROTECTION_JSON}" | jq -r '.required_status_checks.strict // false')"
  if [[ "${STRICT}" == "true" ]]; then
    pass "strict (require branch up-to-date): enabled"
  else
    fail "strict: must be enabled (branches must be up-to-date before merging)"
  fi

  # Required check names
  # These names must match the `name:` field of jobs in .github/workflows/
  REQUIRED_CHECKS=(
    "Static Validation"
    "Tutor Configuration Tests"
    "Security Scans"
    "Python test coverage"
    "Review dependencies"
    "Trivy — K8s Manifests"
    "Trivy — Terraform"
  )

  # Gather configured contexts (legacy API) and checks (rulesets/newer API)
  CONFIGURED="$(echo "${PROTECTION_JSON}" | jq -r '
    (.required_status_checks.contexts // []) +
    ([(.required_status_checks.checks // [])[] | .context])
    | .[]
  ' 2>/dev/null || true)"

  for check in "${REQUIRED_CHECKS[@]}"; do
    if echo "${CONFIGURED}" | grep -qF "${check}"; then
      pass "status check present: '${check}'"
    else
      fail "status check missing: '${check}'"
      info "Add this check name in: Settings → Branches → main → Status checks"
    fi
  done
fi

echo

# ---------------------------------------------------------------------------
# Check: Force push disabled
# ---------------------------------------------------------------------------

echo -e "${BOLD}--- Force Push / Deletion ---${RESET}"

ALLOW_FORCE="$(echo "${PROTECTION_JSON}" | jq -r '.allow_force_pushes.enabled // false')"
if [[ "${ALLOW_FORCE}" == "false" ]]; then
  pass "allow_force_pushes: disabled"
else
  fail "allow_force_pushes: must be disabled (currently enabled)"
fi

ALLOW_DELETE="$(echo "${PROTECTION_JSON}" | jq -r '.allow_deletions.enabled // false')"
if [[ "${ALLOW_DELETE}" == "false" ]]; then
  pass "allow_deletions: disabled"
else
  fail "allow_deletions: must be disabled (currently enabled)"
fi

echo

# ---------------------------------------------------------------------------
# Check: No direct pushes (enforce admins)
# ---------------------------------------------------------------------------

echo -e "${BOLD}--- Enforce Admins ---${RESET}"

ENFORCE_ADMINS="$(echo "${PROTECTION_JSON}" | jq -r '.enforce_admins.enabled // false')"
if [[ "${ENFORCE_ADMINS}" == "true" ]]; then
  pass "enforce_admins: enabled (admins cannot bypass protection)"
else
  warn "enforce_admins: disabled (admins can bypass protection)"
  info "Consider enabling: Settings → Branches → main → Include administrators"
fi

echo

# ---------------------------------------------------------------------------
# Check: Signed commits (informational — optional now, per T064 escalation)
# ---------------------------------------------------------------------------

echo -e "${BOLD}--- Signed Commits (informational) ---${RESET}"

REQUIRED_SIGNATURES="$(echo "${PROTECTION_JSON}" | jq -r '.required_signatures.enabled // false')"
if [[ "${REQUIRED_SIGNATURES}" == "true" ]]; then
  pass "required_signatures: enabled"
else
  warn "required_signatures: not enabled (optional now; escalate per T064)"
  info "Enable when team is ready: gh api --method POST 'repos/${OWNER}/${REPO}/branches/${BRANCH}/protection/required_signatures'"
fi

echo

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo -e "${BOLD}--- Summary ---${RESET}"

if [[ ${FAILURES} -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}RESULT: PASS — branch protection is compliant (${BRANCH})${RESET}"
  echo -e "  See docs/policies/operations/BRANCH_PROTECTION.md for the full policy."
  exit 0
else
  echo -e "${RED}${BOLD}RESULT: FAIL — ${FAILURES} setting(s) are non-compliant${RESET}"
  echo -e "  Fix the settings listed above, then re-run this script."
  echo -e "  See docs/policies/operations/BRANCH_PROTECTION.md for remediation steps."
  exit 1
fi
