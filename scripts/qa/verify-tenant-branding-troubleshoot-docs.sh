#!/usr/bin/env bash
# @covers AC-TBR-105
# @spec: multi-tenancy-architecture_spec.md
# Verify tenant branding troubleshooting documentation completeness
#
# Usage:
#   ./scripts/qa/verify-tenant-branding-troubleshoot-docs.sh
#
# This script verifies that the tenant branding troubleshooting documentation:
# - Exists and has required sections
# - Documents at least 5 troubleshooting scenarios
# - References the runtime verifier and governance gate scripts
# - Covers false positives, routing/cache edge cases, and known issues

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Counters
PASS=0
FAIL=0
WARN=0

# Helper functions
pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  FAIL=$((FAIL + 1))
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
  WARN=$((WARN + 1))
}

echo "=== Tenant Branding Troubleshooting Documentation Verification ==="
echo ""

# AC-TBR-105: Troubleshooting documentation exists
TROUBLESHOOT_DOC="docs/operations/TENANT_BRANDING_TROUBLESHOOTING.md"

if [[ ! -f "$TROUBLESHOOT_DOC" ]]; then
  fail "AC-TBR-105: Troubleshooting doc does not exist: $TROUBLESHOOT_DOC"
  echo ""
  echo "=== Summary ==="
  echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}WARN:${NC} $WARN"
  exit 1
fi

pass "AC-TBR-105: Troubleshooting doc exists: $TROUBLESHOOT_DOC"

# Check doc has required sections
REQUIRED_SECTIONS=(
  "Overview"
  "Quick Diagnostic"
  "False Positives"
  "Routing and Cache Edge Cases"
  "Known Issues"
  "Verification Commands"
  "Related Documentation"
)

for section in "${REQUIRED_SECTIONS[@]}"; do
  if grep -qi "## .*$section" "$TROUBLESHOOT_DOC" || \
     grep -qi "### .*$section" "$TROUBLESHOOT_DOC"; then
    pass "AC-TBR-105: Has section: $section"
  else
    fail "AC-TBR-105: Missing section: $section"
  fi
done

# Check for false positives section content
if grep -qi "false positive" "$TROUBLESHOOT_DOC"; then
  pass "AC-TBR-105: Discusses false positives"
else
  fail "AC-TBR-105: Missing false positive troubleshooting"
fi

# Check for routing/cache edge cases
if grep -qi "cache.*ttl" "$TROUBLESHOOT_DOC" && \
   grep -qi "routing" "$TROUBLESHOOT_DOC"; then
  pass "AC-TBR-105: Documents routing and cache edge cases"
else
  fail "AC-TBR-105: Missing routing/cache edge case documentation"
fi

# Check for references to runtime verifier script
if grep -q "verify-tenant-branding-runtime.sh" "$TROUBLESHOOT_DOC"; then
  pass "AC-TBR-105: References runtime verifier script"
else
  fail "AC-TBR-105: Missing reference to verify-tenant-branding-runtime.sh"
fi

# Check for references to governance gate script
if grep -q "run-multisite-governance-gates.sh" "$TROUBLESHOOT_DOC"; then
  pass "AC-TBR-105: References governance gate script"
else
  fail "AC-TBR-105: Missing reference to run-multisite-governance-gates.sh"
fi

# Check for at least 5 documented troubleshooting scenarios
# Count "### Scenario" or "## Scenario" headings
SCENARIO_COUNT=$(grep -c "^### [0-9]\+\.[0-9]\+" "$TROUBLESHOOT_DOC" || echo 0)
SECTION_SCENARIO_COUNT=$(grep -c "^## Scenario" "$TROUBLESHOOT_DOC" || echo 0)
TOTAL_SCENARIOS=$((SCENARIO_COUNT + SECTION_SCENARIO_COUNT))

if [[ "$TOTAL_SCENARIOS" -ge 5 ]]; then
  pass "AC-TBR-105: Documents at least 5 troubleshooting scenarios ($TOTAL_SCENARIOS found)"
else
  fail "AC-TBR-105: Needs at least 5 troubleshooting scenarios (found: $TOTAL_SCENARIOS)"
fi

# Check for specific known issues
KNOWN_ISSUES=(
  "ENABLE_MULTI_TENANT_BRANDING"
  "DNS propagation"
  "Cache TTL"
  "Caddy.*routing"
  "Cookie domain"
)

KNOWN_ISSUE_COUNT=0
for issue in "${KNOWN_ISSUES[@]}"; do
  if grep -qi "$issue" "$TROUBLESHOOT_DOC"; then
    KNOWN_ISSUE_COUNT=$((KNOWN_ISSUE_COUNT + 1))
  fi
done

if [[ "$KNOWN_ISSUE_COUNT" -ge 3 ]]; then
  pass "AC-TBR-105: Documents common known issues ($KNOWN_ISSUE_COUNT/5)"
else
  warn "AC-TBR-105: Only $KNOWN_ISSUE_COUNT/5 common known issues documented"
fi

# Check for references to other related docs
RELATED_DOCS=(
  "TENANT_BRANDING_READINESS_RAG.md"
  "TROUBLESHOOTING.md"
  "multi-tenancy-architecture_spec.md"
)

RELATED_DOC_COUNT=0
for doc in "${RELATED_DOCS[@]}"; do
  if grep -q "$doc" "$TROUBLESHOOT_DOC"; then
    RELATED_DOC_COUNT=$((RELATED_DOC_COUNT + 1))
  fi
done

if [[ "$RELATED_DOC_COUNT" -ge 2 ]]; then
  pass "AC-TBR-105: References related documentation ($RELATED_DOC_COUNT found)"
else
  warn "AC-TBR-105: Few related doc references ($RELATED_DOC_COUNT found)"
fi

# Check for diagnostic commands
if grep -q '```bash' "$TROUBLESHOOT_DOC"; then
  pass "AC-TBR-105: Includes diagnostic bash commands"
else
  warn "AC-TBR-105: Missing diagnostic command examples"
fi

# Check for escalation path
if grep -qi "escalation" "$TROUBLESHOOT_DOC" || \
   grep -qi "contact.*platform" "$TROUBLESHOOT_DOC"; then
  pass "AC-TBR-105: Documents escalation path"
else
  warn "AC-TBR-105: Missing escalation path documentation"
fi

# Check for verification commands section
if grep -q "Verification Commands" "$TROUBLESHOOT_DOC"; then
  # Count verification commands
  VERIFICATION_CMD_COUNT=$(sed -n '/## Verification Commands/,/^## /p' "$TROUBLESHOOT_DOC" | grep -c "^./scripts/" || echo 0)
  if [[ "$VERIFICATION_CMD_COUNT" -ge 2 ]]; then
    pass "AC-TBR-105: Verification commands section has $VERIFICATION_CMD_COUNT commands"
  else
    warn "AC-TBR-105: Verification commands section has few commands ($VERIFICATION_CMD_COUNT)"
  fi
fi

# Check doc is up-to-date (has Last verified comment)
if grep -q "<!-- Last verified:" "$TROUBLESHOOT_DOC"; then
  LAST_VERIFIED=$(grep -o "Last verified: [0-9-]*" "$TROUBLESHOOT_DOC" | head -1 | cut -d' ' -f3)
  pass "AC-TBR-105: Document has last verified date ($LAST_VERIFIED)"
else
  warn "AC-TBR-105: Missing 'Last verified' comment"
fi

# Summary
echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}WARN:${NC} $WARN"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "${RED}FAILED:${NC} $FAIL check(s) failed"
  echo ""
  echo "Common fixes:"
  echo "- Ensure all required sections are present in $TROUBLESHOOT_DOC"
  echo "- Add at least 5 documented troubleshooting scenarios"
  echo "- Reference verify-tenant-branding-runtime.sh and run-multisite-governance-gates.sh"
  echo "- Document false positives, cache/routing edge cases, and known issues"
  exit 1
else
  echo -e "${GREEN}SUCCESS:${NC} All troubleshooting documentation checks passed"
  if [[ "$WARN" -gt 0 ]]; then
    echo -e "${YELLOW}Note:${NC} $WARN warning(s) - consider addressing for completeness"
  fi
  exit 0
fi
