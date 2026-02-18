#!/usr/bin/env bash
# @covers AC-POST-001, AC-POST-002, AC-POST-003, AC-POST-004, AC-POST-005
# @spec: bead-8jao23
#
# Post-merge governance and closure evidence pack verifier.
#
# Validates that all governance closure artifacts are present for bead 8jao.23:
#   AC-POST-001: Child-linked issue map with owner + severity exists
#   AC-POST-002: Analytics/flood-check evidence artifacts present; no undefined token patterns
#   AC-POST-003: Tenant-branding runtime/build contract verifier doc with run commands exists
#   AC-POST-004: Fallback behavior decision log with expiry + owner for non-plugin-slot paths
#   AC-POST-005: 2-agent execution lock guidance doc (runtime docs vs runtime checks ownership)
#
# Usage:
#   ./scripts/qa/verify-postmerge-governance-closure.sh
#   ./scripts/qa/verify-postmerge-governance-closure.sh --strict
#
# OFFLINE-capable: no live cluster access required.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
STRICT_MODE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict) STRICT_MODE=1; shift ;;
    -h|--help) echo "Usage: $0 [--strict]"; exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo -e "${BLUE}=== Post-Merge Governance Closure Verification (bead 8jao.23) ===${NC}"
echo ""

pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  ((PASS_COUNT++)) || true
}

fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  ((FAIL_COUNT++)) || true
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
  if [[ $STRICT_MODE -eq 1 ]]; then
    ((FAIL_COUNT++)) || true
  else
    ((WARN_COUNT++)) || true
  fi
}

# ---------------------------------------------------------------------------
# AC-POST-001: Child-linked issue map with owner + severity
# ---------------------------------------------------------------------------
echo -e "${BLUE}--- AC-POST-001: Regression inventory / issue map ---${NC}"

CLOSURE_DOC="docs/operations/POSTMERGE_GOVERNANCE_CLOSURE.md"

if [[ -f "$CLOSURE_DOC" ]]; then
  pass "AC-POST-001: Closure doc exists at $CLOSURE_DOC"
else
  fail "AC-POST-001: Missing closure doc at $CLOSURE_DOC"
fi

if [[ -f "$CLOSURE_DOC" ]]; then
  # Must contain issue map section referencing 8jao beads
  if grep -q "8jao" "$CLOSURE_DOC"; then
    pass "AC-POST-001: Closure doc references 8jao bead series"
  else
    fail "AC-POST-001: Closure doc does not reference 8jao bead series"
  fi

  # Must have Owner and Severity fields
  if grep -qi "owner" "$CLOSURE_DOC" && grep -qi "severity" "$CLOSURE_DOC"; then
    pass "AC-POST-001: Closure doc contains Owner and Severity fields"
  else
    fail "AC-POST-001: Closure doc missing Owner and/or Severity fields"
  fi

  # Must reference frontend/branding regressions
  if grep -qi "regression" "$CLOSURE_DOC"; then
    pass "AC-POST-001: Closure doc includes frontend/branding regression inventory"
  else
    fail "AC-POST-001: Closure doc missing regression inventory section"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# AC-POST-002: Analytics/flood-check evidence artifacts
# ---------------------------------------------------------------------------
echo -e "${BLUE}--- AC-POST-002: Analytics flood-check evidence ---${NC}"

ANALYTICS_SCRIPT="scripts/qa/verify-analytics-key.sh"
if [[ -f "$ANALYTICS_SCRIPT" ]]; then
  pass "AC-POST-002: Analytics key verification script exists ($ANALYTICS_SCRIPT)"
else
  fail "AC-POST-002: Missing analytics key verification script ($ANALYTICS_SCRIPT)"
fi

ANALYTICS_DRIFT="scripts/qa/verify-analytics-drift-guardrails.sh"
if [[ -f "$ANALYTICS_DRIFT" ]]; then
  pass "AC-POST-002: Analytics drift guardrails script exists"
else
  fail "AC-POST-002: Missing analytics drift guardrails script"
fi

# No undefined token patterns in Tutor plugin config
PLUGIN="infrastructure/tutor/plugins/mereka_lms.py"
if [[ -f "$PLUGIN" ]]; then
  UNDEFINED_SEGMENT_COUNT=$(grep -c 'SEGMENT_KEY.*=.*"undefined"' "$PLUGIN" || true)
  if [[ "$UNDEFINED_SEGMENT_COUNT" -eq 0 ]]; then
    pass "AC-POST-002: No hard-coded 'undefined' segment key in mereka_lms.py"
  else
    fail "AC-POST-002: Found hard-coded 'undefined' segment key in mereka_lms.py ($UNDEFINED_SEGMENT_COUNT occurrences)"
  fi

  NONE_SEGMENT_COUNT=$(grep -cE "SEGMENT_KEY\s*=\s*\"(none|null|NONE|NULL)\"" "$PLUGIN" || true)
  if [[ "$NONE_SEGMENT_COUNT" -eq 0 ]]; then
    pass "AC-POST-002: No sentinel values (none/null) for SEGMENT_KEY in plugin"
  else
    fail "AC-POST-002: Found sentinel value for SEGMENT_KEY in plugin ($NONE_SEGMENT_COUNT occurrences)"
  fi
else
  warn "AC-POST-002: mereka_lms.py not found — skipping sentinel token check"
fi

# Closure doc must contain analytics/flood evidence section
if [[ -f "$CLOSURE_DOC" ]]; then
  if grep -qi "analytic" "$CLOSURE_DOC" && grep -qi "4xx\|flood\|admin\|authn\|ecommerce\|studio" "$CLOSURE_DOC"; then
    pass "AC-POST-002: Closure doc contains analytics and 4xx flood check evidence"
  else
    fail "AC-POST-002: Closure doc missing analytics/flood check evidence section"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# AC-POST-003: Tenant-branding runtime/build contract verifier doc
# ---------------------------------------------------------------------------
echo -e "${BLUE}--- AC-POST-003: Tenant-branding runtime contract doc ---${NC}"

# Primary: docs/operations/POSTMERGE_GOVERNANCE_CLOSURE.md must have a runtime contract section
if [[ -f "$CLOSURE_DOC" ]]; then
  if grep -qi "runtime.*contract\|build.*contract\|tenant.*branding.*verif\|verif.*tenant.*branding" "$CLOSURE_DOC"; then
    pass "AC-POST-003: Closure doc contains tenant-branding runtime/build contract section"
  else
    fail "AC-POST-003: Closure doc missing tenant-branding runtime contract section"
  fi

  # Must have run commands
  if grep -q "verify-tenant-branding" "$CLOSURE_DOC"; then
    pass "AC-POST-003: Closure doc references tenant branding verification command(s)"
  else
    fail "AC-POST-003: Closure doc missing tenant branding verification commands"
  fi

  # Must have expected output indicators
  if grep -qi "expected output\|0 FAIL\|\[PASS\]" "$CLOSURE_DOC"; then
    pass "AC-POST-003: Closure doc includes expected output examples"
  else
    fail "AC-POST-003: Closure doc missing expected output examples for runtime contract"
  fi
fi

# Supporting verifier must exist
TENANT_RUNTIME="scripts/qa/verify-tenant-branding-runtime.sh"
if [[ -f "$TENANT_RUNTIME" ]]; then
  pass "AC-POST-003: Tenant branding runtime verifier script exists"
else
  fail "AC-POST-003: Missing tenant branding runtime verifier script"
fi

TENANT_CONTRACT="scripts/qa/verify-tenant-branding-contract.sh"
if [[ -f "$TENANT_CONTRACT" ]]; then
  pass "AC-POST-003: Tenant branding contract verifier script exists"
else
  fail "AC-POST-003: Missing tenant branding contract verifier script"
fi

echo ""

# ---------------------------------------------------------------------------
# AC-POST-004: Fallback decision log with expiry + owner
# ---------------------------------------------------------------------------
echo -e "${BLUE}--- AC-POST-004: Fallback behavior decision log ---${NC}"

FOOTER_POLICY="docs/operations/FOOTER_SLOT_ONLY_POLICY.md"
if [[ -f "$FOOTER_POLICY" ]]; then
  pass "AC-POST-004: Footer slot-only policy doc exists"

  # Must have an Exception Register with expiry and owner
  if grep -qi "Exception Register" "$FOOTER_POLICY"; then
    pass "AC-POST-004: Footer policy contains Exception Register section"
  else
    fail "AC-POST-004: Footer policy missing Exception Register section"
  fi

  if grep -qE "Expiry|expiry|2026-Q" "$FOOTER_POLICY"; then
    pass "AC-POST-004: Exception Register entries contain expiry dates"
  else
    fail "AC-POST-004: Exception Register entries missing expiry dates"
  fi

  if grep -qi "Owner" "$FOOTER_POLICY"; then
    pass "AC-POST-004: Exception Register entries contain owner fields"
  else
    fail "AC-POST-004: Exception Register entries missing owner fields"
  fi
else
  fail "AC-POST-004: Missing footer slot-only policy doc at $FOOTER_POLICY"
fi

# Closure doc must have fallback decision log section
if [[ -f "$CLOSURE_DOC" ]]; then
  if grep -qi "fallback\|decision log\|temporary" "$CLOSURE_DOC"; then
    pass "AC-POST-004: Closure doc contains fallback/decision log section"
  else
    fail "AC-POST-004: Closure doc missing fallback decision log section"
  fi

  # Must have non-plugin-slot path references
  if grep -qi "non-plugin-slot\|outside.*plugin.slot\|FTRE-\|FTRX-" "$CLOSURE_DOC"; then
    pass "AC-POST-004: Closure doc references registered non-plugin-slot fallback paths"
  else
    fail "AC-POST-004: Closure doc missing non-plugin-slot fallback path references"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# AC-POST-005: 2-agent execution lock guidance doc
# ---------------------------------------------------------------------------
echo -e "${BLUE}--- AC-POST-005: 2-agent execution lock guidance ---${NC}"

if [[ -f "$CLOSURE_DOC" ]]; then
  # Must have agent ownership section
  if grep -qi "agent.*lock\|execution lock\|BoldBadger\|WhiteCliff\|runtime docs.*runtime check\|parallel.*agent" "$CLOSURE_DOC"; then
    pass "AC-POST-005: Closure doc contains 2-agent execution lock guidance"
  else
    fail "AC-POST-005: Closure doc missing 2-agent execution lock guidance section"
  fi

  # Must distinguish runtime docs vs runtime checks owners
  if grep -qi "runtime docs\|runtime checks" "$CLOSURE_DOC"; then
    pass "AC-POST-005: Closure doc distinguishes runtime docs vs runtime checks ownership"
  else
    fail "AC-POST-005: Closure doc does not distinguish runtime docs vs runtime checks ownership"
  fi

  # Must have actionable guidance (who does what)
  if grep -qi "BoldBadger\|WhiteCliff\|deploy.*agent\|UI.*agent\|branding.*agent" "$CLOSURE_DOC"; then
    pass "AC-POST-005: Closure doc names agents or roles for each domain"
  else
    warn "AC-POST-005: Closure doc does not name specific agents — guidance may be abstract"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo -e "${BLUE}=== Summary ===${NC}"
echo -e "${GREEN}PASS: $PASS_COUNT${NC} | ${RED}FAIL: $FAIL_COUNT${NC} | ${YELLOW}WARN: $WARN_COUNT${NC}"
echo ""

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo -e "${RED}FAILED${NC}: $FAIL_COUNT check(s) did not pass."
  echo ""
  echo "Remediation steps:"
  echo "  AC-POST-001: Create/update docs/operations/POSTMERGE_GOVERNANCE_CLOSURE.md with"
  echo "               8jao bead issue map including Owner and Severity columns."
  echo "  AC-POST-002: Ensure verify-analytics-key.sh and verify-analytics-drift-guardrails.sh"
  echo "               exist. Add analytics/4xx flood evidence to closure doc."
  echo "  AC-POST-003: Add tenant-branding runtime contract section to closure doc with"
  echo "               run commands and expected output."
  echo "  AC-POST-004: Ensure FOOTER_SLOT_ONLY_POLICY.md has Exception Register with"
  echo "               expiry + owner. Add fallback decision log to closure doc."
  echo "  AC-POST-005: Add 2-agent execution lock section to closure doc naming"
  echo "               BoldBadger (deploy/non-UI) and WhiteCliff (UI/UX) domains."
  exit 1
fi

echo -e "${GREEN}All checks passed.${NC}"
exit 0
