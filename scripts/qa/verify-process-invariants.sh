#!/usr/bin/env bash
# verify-process-invariants.sh — Enforce process and template invariants
#
# Ensures that:
# 1. PR template mentions owner layer
# 2. Issue templates include at least one incident template
# 3. Runbooks directory contains playbooks or troubleshooting docs
# 4. Status docs do not claim "canonical" in their header status field
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0

pass() { PASSED=$((PASSED + 1)); echo -e "  ${GREEN}PASS${NC}: $1"; }
fail() { FAILED=$((FAILED + 1)); echo -e "  ${RED}FAIL${NC}: $1" >&2; }

echo "=== Process Invariant Verification ==="
echo "Repo root: ${REPO_ROOT}"
echo

# ---------------------------------------------------------------------------
# 1. PR template must mention "owner layer" (case-insensitive)
# ---------------------------------------------------------------------------
echo "--- Check 1: PR template contains owner-layer reference ---"
PR_TEMPLATE="$REPO_ROOT/.github/PULL_REQUEST_TEMPLATE.md"
if [[ ! -f "$PR_TEMPLATE" ]]; then
  fail "PR template (.github/PULL_REQUEST_TEMPLATE.md) does not exist"
else
  if grep -qi 'owner layer' "$PR_TEMPLATE"; then
    pass "PR template references owner layer"
  else
    fail "PR template (.github/PULL_REQUEST_TEMPLATE.md) does not contain 'owner layer' (case-insensitive)"
  fi
fi

# ---------------------------------------------------------------------------
# 2. Issue templates must include at least one incident template
# ---------------------------------------------------------------------------
echo "--- Check 2: At least one incident issue template exists ---"
ISSUE_TEMPLATE_DIR="$REPO_ROOT/.github/ISSUE_TEMPLATE"
if [[ ! -d "$ISSUE_TEMPLATE_DIR" ]]; then
  fail ".github/ISSUE_TEMPLATE/ directory does not exist"
else
  shopt -s nullglob nocaseglob
  incident_templates=("$ISSUE_TEMPLATE_DIR"/*incident*)
  shopt -u nullglob nocaseglob
  if [[ "${#incident_templates[@]}" -gt 0 ]]; then
    pass "Found ${#incident_templates[@]} incident template(s) in .github/ISSUE_TEMPLATE/"
  else
    fail "No incident template found in .github/ISSUE_TEMPLATE/ (expected filename containing 'incident')"
  fi
fi

# ---------------------------------------------------------------------------
# 3. Runbooks directory must contain playbooks or troubleshooting docs
# ---------------------------------------------------------------------------
echo "--- Check 3: Runbooks contain playbook or troubleshooting docs ---"
RUNBOOKS_DIR="$REPO_ROOT/docs/ops/runbooks"
if [[ ! -d "$RUNBOOKS_DIR" ]]; then
  fail "docs/ops/runbooks/ directory does not exist"
else
  shopt -s nullglob nocaseglob
  playbook_files=("$RUNBOOKS_DIR"/*playbook* "$RUNBOOKS_DIR"/TROUBLESHOOTING*)
  shopt -u nullglob nocaseglob
  if [[ "${#playbook_files[@]}" -gt 0 ]]; then
    pass "Found ${#playbook_files[@]} playbook/troubleshooting file(s) in docs/ops/runbooks/"
  else
    fail "No playbook or troubleshooting file found in docs/ops/runbooks/"
  fi
fi

# ---------------------------------------------------------------------------
# 4. Status docs must not claim "canonical" in their header status field
# ---------------------------------------------------------------------------
echo "--- Check 4: Status docs do not claim canonical in header ---"
STATUS_DIR="$REPO_ROOT/docs/status/active"
check4_failed=0
if [[ ! -d "$STATUS_DIR" ]]; then
  fail "docs/status/active/ directory does not exist"
else
  shopt -s nullglob
  status_files=("$STATUS_DIR"/*.md)
  shopt -u nullglob
  for f in "${status_files[@]}"; do
    basename_f="$(basename "$f")"
    # Extract the YAML front matter or first ~30 lines as the header region
    header="$(head -30 "$f")"
    # Check for a status field that contains the word canonical
    # Matches patterns like: status: canonical, Status: canonical, **Status**: canonical
    if echo "$header" | grep -iE '^[#*\s-]*status[*]*\s*[:=]' | grep -qi 'canonical'; then
      fail "$basename_f has 'canonical' in its status field (status-only docs must not claim canonical)"
      check4_failed=$((check4_failed + 1))
    fi
  done
  if [[ "$check4_failed" -eq 0 ]]; then
    pass "No status docs in docs/status/active/ claim canonical in their status field"
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
echo "=== Summary ==="
echo -e "${GREEN}PASS${NC}: $PASSED | ${RED}FAIL${NC}: $FAILED"
echo

if [[ "$FAILED" -gt 0 ]]; then
  echo "Process invariant violations detected."
  echo "Fix ALL failures before merging."
  exit 1
fi

echo "All process invariants hold."
exit 0
