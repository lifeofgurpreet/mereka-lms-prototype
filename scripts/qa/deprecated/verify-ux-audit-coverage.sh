#!/usr/bin/env bash
# Verifies UI/UX audit report structure exists and has required sections
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_REPORT="$REPO_ROOT/docs/operations/UI_UX_AUDIT_REPORT.md"

PASS=0
FAIL=0
WARN=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "UI/UX Audit Coverage Verification"
echo "========================================="
echo ""

# Check audit report exists
if [[ ! -f "$AUDIT_REPORT" ]]; then
  echo -e "${RED}✗ FAIL${NC}: Audit report not found at $AUDIT_REPORT"
  FAIL=$((FAIL + 1))
  exit 1
fi
echo -e "${GREEN}✓ PASS${NC}: Audit report exists"
PASS=$((PASS + 1))

# Check required sections exist
REQUIRED_SECTIONS=(
  "## Audit Scope"
  "## Severity Taxonomy"
  "## Audit Categories"
  "### 1. Navigation Consistency"
  "### 2. CTA Hierarchy"
  "### 3. Spacing & Typography"
  "### 4. Cross-MFE Transitions"
  "### 5. Responsive Behavior"
  "## Findings Summary"
  "## Quick Wins Delivered"
  "## Implementation Backlog"
  "## Related Documents"
)

for section in "${REQUIRED_SECTIONS[@]}"; do
  if grep -qF "$section" "$AUDIT_REPORT"; then
    echo -e "${GREEN}✓ PASS${NC}: Section found: $section"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}✗ FAIL${NC}: Missing section: $section"
    FAIL=$((FAIL + 1))
  fi
done

# Check audit scope covers all 3 domains
REQUIRED_DOMAINS=(
  "academyv2.mereka.io"
  "academy.biji-biji.com"
  "skillourfuture.academy.mereka.io"
)

for domain in "${REQUIRED_DOMAINS[@]}"; do
  if grep -qF "$domain" "$AUDIT_REPORT"; then
    echo -e "${GREEN}✓ PASS${NC}: Domain found in scope: $domain"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}✗ FAIL${NC}: Missing domain: $domain"
    FAIL=$((FAIL + 1))
  fi
done

# Check severity levels exist
SEVERITY_LEVELS=(
  "Critical"
  "High"
  "Medium"
  "Low"
)

for level in "${SEVERITY_LEVELS[@]}"; do
  if grep -q "| $level |" "$AUDIT_REPORT"; then
    echo -e "${GREEN}✓ PASS${NC}: Severity level defined: $level"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}✗ FAIL${NC}: Missing severity level: $level"
    FAIL=$((FAIL + 1))
  fi
done

# Check audit categories have check items
AUDIT_CATEGORIES=(
  "N-001"
  "C-001"
  "T-001"
  "X-001"
  "R-001"
)

for item in "${AUDIT_CATEGORIES[@]}"; do
  if grep -qF "$item" "$AUDIT_REPORT"; then
    echo -e "${GREEN}✓ PASS${NC}: Audit check item found: $item"
    PASS=$((PASS + 1))
  else
    echo -e "${YELLOW}⚠ WARN${NC}: Missing audit check item: $item (might be renamed)"
    WARN=$((WARN + 1))
  fi
done

# Check Quick Wins section has at least 5 entries
quick_wins_count=$(grep -c "| QW-" "$AUDIT_REPORT" || true)
if [[ $quick_wins_count -ge 5 ]]; then
  echo -e "${GREEN}✓ PASS${NC}: Quick Wins section has $quick_wins_count entries (target: 5)"
  PASS=$((PASS + 1))
else
  echo -e "${YELLOW}⚠ WARN${NC}: Quick Wins section has $quick_wins_count entries (target: 5)"
  WARN=$((WARN + 1))
fi

# Check Related Documents section has required links
RELATED_DOCS=(
  "_tokens.scss"
  "PARAGON_TOKEN_ALIGNMENT.md"
  "FOOTER_V2_TO_LMS_MAPPING.md"
  "MFE_FIRST_POLICY.md"
  "VISUAL_REGRESSION_RUNBOOK.md"
)

for doc in "${RELATED_DOCS[@]}"; do
  if grep -qF "$doc" "$AUDIT_REPORT"; then
    echo -e "${GREEN}✓ PASS${NC}: Related document referenced: $doc"
    PASS=$((PASS + 1))
  else
    echo -e "${YELLOW}⚠ WARN${NC}: Missing related document reference: $doc"
    WARN=$((WARN + 1))
  fi
done

# Summary
echo ""
echo "========================================="
echo "Summary"
echo "========================================="
echo -e "${GREEN}PASS${NC}: $PASS"
echo -e "${YELLOW}WARN${NC}: $WARN"
echo -e "${RED}FAIL${NC}: $FAIL"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo -e "${RED}✗ VERIFICATION FAILED${NC}"
  exit 1
elif [[ $WARN -gt 0 ]]; then
  echo -e "${YELLOW}⚠ VERIFICATION PASSED WITH WARNINGS${NC}"
  exit 0
else
  echo -e "${GREEN}✓ VERIFICATION PASSED${NC}"
  exit 0
fi
