#!/usr/bin/env bash
# verify-mfe-first-policy.sh — Enforce MFE-first frontend policy
# @covers AC-UIMFE-002
#
# Flags new Django template/JS patches under edx-platform-style paths
# when a matching MFE/plugin-slot route already exists.
#
# Usage:
#   ./scripts/qa/verify-mfe-first-policy.sh
#   ./scripts/qa/verify-mfe-first-policy.sh --strict
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"
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
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo -e "${BLUE}=== MFE-First Policy Compliance Check ===${NC}"
echo ""

pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASS_COUNT++)) || true; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAIL_COUNT++)) || true; }
warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
  ((WARN_COUNT++)) || true
  if [[ $STRICT_MODE -eq 1 ]]; then
    fail "$1 (strict mode)"
    ((WARN_COUNT--)) || true
  fi
}

# ============================================================================
# Policy Document Checks
# ============================================================================

echo -e "${BLUE}## Policy Documentation${NC}"

if [[ -f "docs/concepts/architecture/MFE_FIRST_POLICY.md" ]]; then
  pass "MFE-first policy document exists"
else
  fail "MFE-first policy document missing (docs/concepts/architecture/MFE_FIRST_POLICY.md)"
fi

if grep -rq "MFE-first\|MFE-First\|mfe-first" docs/ 2>/dev/null; then
  pass "Policy keywords found in docs"
else
  fail "No MFE-first policy keywords found in docs/"
fi

if grep -rq "plugin.slot\|plugin_slot\|PLUGIN_SLOTS" docs/ 2>/dev/null; then
  pass "Plugin slot references found in docs"
else
  fail "No plugin slot references in docs"
fi

if grep -rq "no new edx-platform frontend\|no new Django template" docs/ 2>/dev/null; then
  pass "No-new-Django-template directive found in docs"
else
  warn "Explicit no-new-Django-template directive not found in docs"
fi

# Check ADR-014 exists
if [[ -f "docs/programs/frontend/MFE_BRANDING_MIGRATION_DECISION.md" ]]; then
  pass "ADR-014 (plugin-first rationale) exists"
else
  fail "ADR-014 missing"
fi

# Check plugin slot inventory exists
if [[ -f "docs/concepts/architecture/MFE_PLUGIN_SLOT_INVENTORY.md" ]]; then
  pass "Plugin slot inventory exists"
else
  fail "Plugin slot inventory missing"
fi

echo ""

# ============================================================================
# MFE Route Coverage
# ============================================================================

echo -e "${BLUE}## MFE Route Coverage${NC}"

# MFE-owned route prefixes
MFE_ROUTES=(
  "authn"
  "account"
  "learning"
  "learner-dashboard"
  "discussions"
  "profile"
  "course-authoring"
  "gradebook"
  "communications"
  "ora-grading"
)

# Check that MFE Caddyfile defines each route
MFE_CADDYFILE="deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"
if [[ -f "$MFE_CADDYFILE" ]]; then
  for route in "${MFE_ROUTES[@]}"; do
    if grep -q "/${route}" "$MFE_CADDYFILE" 2>/dev/null; then
      pass "MFE route /${route}/ defined in Caddyfile"
    else
      warn "MFE route /${route}/ not found in Caddyfile"
    fi
  done
else
  warn "MFE Caddyfile not found at expected path"
fi

echo ""

# ============================================================================
# Django Template Overlap Detection
# ============================================================================

echo -e "${BLUE}## Django Template Overlap Detection${NC}"

# Check for Django templates that overlap with MFE-owned routes
THEME_DIR="infrastructure/tutor/themes/mereka"

for route in "${MFE_ROUTES[@]}"; do
  # Look for templates matching MFE route names
  OVERLAPS=$(find "$THEME_DIR" -type f -name "*.html" 2>/dev/null \
    | grep -i "${route}" \
    | grep -v "README" || true)

  if [[ -n "$OVERLAPS" ]]; then
    warn "Django template overlap with MFE route '${route}': $(echo "$OVERLAPS" | head -1)"
  fi
done

# Check for new JS files in theme (should use MFE instead)
JS_IN_THEME=$(find "$THEME_DIR" -type f -name "*.js" 2>/dev/null | wc -l)
if [[ "$JS_IN_THEME" -eq 0 ]]; then
  pass "No JavaScript files in theme directory (MFE-first compliant)"
else
  warn "${JS_IN_THEME} JavaScript file(s) found in theme directory"
fi

# Check for new template additions in patches
if [[ -d "infrastructure/tutor/patches/" ]]; then
  PATCH_TEMPLATES=$(find infrastructure/tutor/patches/ -type f -name "*.html" 2>/dev/null | wc -l)
  PATCH_TEMPLATES=$(echo "$PATCH_TEMPLATES" | tr -d ' \n')
  if [[ "$PATCH_TEMPLATES" -eq 0 ]]; then
    pass "No HTML templates in patches directory"
  else
    warn "${PATCH_TEMPLATES} HTML template(s) found in patches directory"
  fi
else
  pass "No patches directory (MFE-first compliant)"
fi

echo ""

# ============================================================================
# Plugin-Slot Wiring Check
# ============================================================================

echo -e "${BLUE}## Plugin-Slot Wiring${NC}"

PLUGIN="$PLUGIN_MAIN"

if mereka_plugin_has_fixed "$REPO_ROOT" "PLUGIN_SLOTS"; then
  pass "Plugin slot registration found in plugin contract files"
else
  fail "No plugin slot registration in plugin contract files"
fi

if mereka_plugin_has_fixed "$REPO_ROOT" "footer"; then
  pass "footer slot actively used (canonical MFE-first example)"
else
  warn "footer slot not wired in plugin contract files"
fi

echo ""

# ============================================================================
# Exception Documentation
# ============================================================================

echo -e "${BLUE}## Exception Documentation${NC}"

if grep -rq "Exception\|exception\|Legitimate" docs/concepts/architecture/MFE_FIRST_POLICY.md 2>/dev/null; then
  pass "Exception process documented in policy"
else
  warn "Exception process not documented"
fi

# Check known legitimate Django templates are documented
FOOTER_TEMPLATE="infrastructure/tutor/themes/mereka/lms/templates/footer.html"
if [[ -f "$FOOTER_TEMPLATE" ]]; then
  if grep -q "footer.html" docs/concepts/architecture/MFE_FIRST_POLICY.md 2>/dev/null; then
    pass "LMS footer template documented as known exception"
  else
    warn "LMS footer template exists but not documented as exception"
  fi
fi

echo ""

# ============================================================================
# Summary
# ============================================================================

echo -e "${BLUE}## Summary${NC}"
echo ""
echo -e "  ${GREEN}PASS${NC}: $PASS_COUNT"
echo -e "  ${YELLOW}WARN${NC}: $WARN_COUNT"
echo -e "  ${RED}FAIL${NC}: $FAIL_COUNT"
echo ""

if [[ $FAIL_COUNT -eq 0 && $WARN_COUNT -eq 0 ]]; then
  echo -e "${GREEN}MFE-first policy fully compliant${NC}"
  exit 0
elif [[ $FAIL_COUNT -eq 0 ]]; then
  echo -e "${YELLOW}Policy in place with acceptable exceptions${NC}"
  exit 0
else
  echo -e "${RED}Policy compliance issues found${NC}"
  exit 1
fi
