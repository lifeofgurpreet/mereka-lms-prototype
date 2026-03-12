#!/usr/bin/env bash
# Verify the agent is in the correct repository and on a non-main branch.
# Checks:
#   - PWD is inside the mereka-lms repo (CLAUDE.md contains "Mereka Academy Open edX")
#   - Current branch is NOT main (unless --allow-main is passed)
#   - git remote origin resolves to Biji-Biji-Initiative/mereka-lms
#
# Usage:
#   scripts/qa/verify-agent-context-lock.sh [--allow-main]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ALLOW_MAIN=0
for arg in "$@"; do
  if [[ "${arg}" == "--allow-main" ]]; then
    ALLOW_MAIN=1
  fi
done

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

info() {
  echo -e "      $1"
}

echo "=== Agent Context Lock Verification ==="
echo ""

# ---------------------------------------------------------------------------
# 1. CLAUDE.md identity check
# ---------------------------------------------------------------------------
echo "--- Repository identity ---"

CLAUDE_MD="${REPO_ROOT}/CLAUDE.md"
if [[ -f "${CLAUDE_MD}" ]]; then
  if grep -qF "Mereka Academy Open edX" "${CLAUDE_MD}"; then
    pass "CLAUDE.md present and identifies as Mereka Academy Open edX"
    info "Repo root: ${REPO_ROOT}"
  else
    fail "CLAUDE.md present but does not contain 'Mereka Academy Open edX'"
    info "Found: $(head -3 "${CLAUDE_MD}")"
  fi
else
  fail "CLAUDE.md not found at ${CLAUDE_MD}"
fi

# ---------------------------------------------------------------------------
# 2. git remote origin
# ---------------------------------------------------------------------------
echo ""
echo "--- Remote origin ---"

if ! git -C "${REPO_ROOT}" rev-parse --git-dir >/dev/null 2>&1; then
  fail "Not a git repository: ${REPO_ROOT}"
else
  REMOTE_URL="$(git -C "${REPO_ROOT}" remote get-url origin 2>/dev/null || echo "")"
  if [[ -z "${REMOTE_URL}" ]]; then
    fail "No remote 'origin' configured"
  else
    info "Remote origin: ${REMOTE_URL}"
    # Accept SSH (git@github.com:...) and HTTPS forms
    if echo "${REMOTE_URL}" | grep -qiE "(Biji-Biji-Initiative/mereka-lms|biji-biji-initiative/mereka-lms)"; then
      pass "Remote origin points to Biji-Biji-Initiative/mereka-lms"
    else
      fail "Remote origin does not point to Biji-Biji-Initiative/mereka-lms (got: ${REMOTE_URL})"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 3. Branch check
# ---------------------------------------------------------------------------
echo ""
echo "--- Branch ---"

CURRENT_BRANCH="$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "UNKNOWN")"
info "Current branch: ${CURRENT_BRANCH}"

if [[ "${CURRENT_BRANCH}" == "main" ]]; then
  if [[ "${ALLOW_MAIN}" -eq 1 ]]; then
    echo -e "      ${YELLOW}WARN${NC}  On main branch (--allow-main passed, continuing)"
    PASS=$((PASS + 1))
  else
    fail "On main branch — agents must work on a feature branch (pass --allow-main to override)"
  fi
else
  pass "Not on main branch: ${CURRENT_BRANCH}"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Summary ==="
echo -e "Passed: ${GREEN}${PASS}${NC}"
echo -e "Failed: ${RED}${FAIL}${NC}"
echo ""

if [[ ${FAIL} -eq 0 ]]; then
  echo -e "${GREEN}Agent context lock checks passed.${NC}"
  exit 0
else
  echo -e "${RED}${FAIL} check(s) failed — agent may be in wrong repo or branch.${NC}"
  exit 1
fi
