#!/usr/bin/env bash
# @covers AC-INT-001, AC-INT-002
# @spec: branding-system_spec.md
set -euo pipefail

# verify-branding-multi-domain.sh - Verify branding consistency across all production domains
#
# AC-INT-001: Mereka logo and custom footer render correctly on all three domains
# AC-INT-002: verify-branding-health.sh passes for all configured domains

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${SCRIPT_DIR}/../shared/config.sh" 2>/dev/null || true

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

pass() {
  echo -e "${GREEN}PASS${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}FAIL${NC} $1"
  FAIL=$((FAIL + 1))
}

skip() {
  echo -e "${YELLOW}SKIP${NC} $1"
  SKIP=$((SKIP + 1))
}

echo "=== Branding System: Multi-Domain Verification ==="
echo "Spec: branding-system_spec.md | AC-INT-001, AC-INT-002"
echo

# Define production domains per spec
PRODUCTION_DOMAINS=(
  "academyv2.mereka.io"
  "academy.biji-biji.com"
  "skillourfuture.academy.mereka.io"
)

# Check 1: Verify tutor_env exists (AC-INT-001 prerequisite)
if [[ ! -d "${REPO_ROOT}/tutor_env" ]]; then
  skip "tutor_env directory not found (local build not completed)"
  echo
  echo "=== Summary ==="
  echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
  echo
  echo "Note: This verification requires a local Tutor build to be present."
  echo "  Run: tutor local launch -I"
  exit 0
fi

pass "tutor_env directory exists"

# Check 2: Verify production domains are configured in LMS settings (AC-INT-001)
LMS_PRODUCTION_PY="${REPO_ROOT}/tutor_env/env/apps/openedx/settings/lms/production.py"

if [[ ! -f "$LMS_PRODUCTION_PY" ]]; then
  fail "LMS production.py not found at $LMS_PRODUCTION_PY"
else
  pass "LMS production.py exists"

  echo
  echo -e "${BLUE}Checking domain configuration in LMS settings...${NC}"

  DOMAIN_CHECK_PASS=0
  DOMAIN_CHECK_FAIL=0

  for domain in "${PRODUCTION_DOMAINS[@]}"; do
    if grep -qF "$domain" "$LMS_PRODUCTION_PY"; then
      pass "Domain configured in LMS settings: $domain"
      DOMAIN_CHECK_PASS=$((DOMAIN_CHECK_PASS + 1))
    else
      fail "Domain NOT configured in LMS settings: $domain"
      DOMAIN_CHECK_FAIL=$((DOMAIN_CHECK_FAIL + 1))
    fi
  done

  if [[ $DOMAIN_CHECK_FAIL -eq 0 && $DOMAIN_CHECK_PASS -eq ${#PRODUCTION_DOMAINS[@]} ]]; then
    pass "AC-INT-001: All production domains configured in LMS settings"
  else
    fail "AC-INT-001: Missing domains in LMS settings (found $DOMAIN_CHECK_PASS/${#PRODUCTION_DOMAINS[@]})"
  fi
fi

# Check 3: Verify Mereka logo assets exist for all domains (AC-INT-001)
echo
echo -e "${BLUE}Checking logo assets in theme source...${NC}"

LOGO_VARIANTS=(
  "logo.png"
  "logo-horizontal.png"
  "logo-horizontal-white.png"
  "logo-square.png"
  "logo-horizontal.svg"
  "logo-horizontal-white.svg"
  "logo-square.svg"
  "favicon.ico"
)

LMS_THEME_IMAGES="${REPO_ROOT}/infrastructure/tutor/themes/mereka/lms/static/images"
CMS_THEME_IMAGES="${REPO_ROOT}/infrastructure/tutor/themes/mereka/cms/static/images"

LOGO_CHECK_PASS=0
LOGO_CHECK_FAIL=0

for logo in "${LOGO_VARIANTS[@]}"; do
  if [[ -f "${LMS_THEME_IMAGES}/${logo}" ]]; then
    pass "LMS logo asset exists: $logo"
    LOGO_CHECK_PASS=$((LOGO_CHECK_PASS + 1))
  else
    fail "LMS logo asset missing: $logo"
    LOGO_CHECK_FAIL=$((LOGO_CHECK_FAIL + 1))
  fi
done

if [[ $LOGO_CHECK_FAIL -eq 0 ]]; then
  pass "AC-INT-001: All required logo variants present in LMS theme"
else
  fail "AC-INT-001: Missing logo variants (found $LOGO_CHECK_PASS/${#LOGO_VARIANTS[@]})"
fi

# Check 4: Verify custom footer component exists in MFE config (AC-INT-001)
echo
echo -e "${BLUE}Checking MFE custom footer configuration...${NC}"

APPLY_PATCHES_SCRIPT="${REPO_ROOT}/infrastructure/tutor/apply-patches.sh"

if [[ ! -f "$APPLY_PATCHES_SCRIPT" ]]; then
  fail "apply-patches.sh not found at $APPLY_PATCHES_SCRIPT"
else
  pass "apply-patches.sh exists"

  # Check for MerekaFooter component definition
  if grep -q "const MerekaFooter" "$APPLY_PATCHES_SCRIPT"; then
    pass "MerekaFooter component defined in apply-patches.sh"

    # Verify footer contains required branding elements
    FOOTER_ELEMENTS=(
      "Mereka Academy"
      "team@mereka.io"
      "techadmin@biji-biji.com"
      "Biji-Biji Initiative"
    )

    FOOTER_CHECK_PASS=0
    FOOTER_CHECK_FAIL=0

    for element in "${FOOTER_ELEMENTS[@]}"; do
      if grep -q "$element" "$APPLY_PATCHES_SCRIPT"; then
        pass "Footer contains: $element"
        FOOTER_CHECK_PASS=$((FOOTER_CHECK_PASS + 1))
      else
        fail "Footer missing: $element"
        FOOTER_CHECK_FAIL=$((FOOTER_CHECK_FAIL + 1))
      fi
    done

    if [[ $FOOTER_CHECK_FAIL -eq 0 ]]; then
      pass "AC-INT-001: MerekaFooter contains all required branding elements"
    else
      fail "AC-INT-001: MerekaFooter missing elements (found $FOOTER_CHECK_PASS/${#FOOTER_ELEMENTS[@]})"
    fi
  else
    fail "MerekaFooter component NOT defined in apply-patches.sh"
  fi
fi

# Check 5: Verify no Google Fonts references in Mereka theme (AC-INT-001 - zero Open edX default branding leakage)
echo
echo -e "${BLUE}Checking for Google Fonts leakage in Mereka theme...${NC}"

GOOGLE_FONTS_PATTERN="fonts.googleapis.com"
MEREKA_THEME_DIR="${REPO_ROOT}/tutor_env/env/build/openedx/themes/mereka"

if [[ -d "$MEREKA_THEME_DIR" ]]; then
  # Search for Google Fonts in Mereka theme only (not default Indigo theme)
  GOOGLE_FONTS_RESULTS=$(grep -r "$GOOGLE_FONTS_PATTERN" "$MEREKA_THEME_DIR" 2>/dev/null || true)

  if [[ -z "$GOOGLE_FONTS_RESULTS" ]]; then
    pass "AC-INT-001: No Google Fonts references in Mereka theme (zero default branding leakage)"
  else
    fail "AC-INT-001: Found Google Fonts references in Mereka theme (default branding leakage detected)"
    echo "  Found in:"
    echo "$GOOGLE_FONTS_RESULTS" | head -5 | sed 's/^/    /'
  fi
else
  skip "Mereka theme build directory not found (cannot verify Google Fonts removal)"
fi

# Check 6: Run branding health check (AC-INT-002)
echo
echo -e "${BLUE}Running branding health check for all domains...${NC}"

BRANDING_HEALTH_SCRIPT="${REPO_ROOT}/scripts/branding/verify-branding-health.sh"

if [[ ! -f "$BRANDING_HEALTH_SCRIPT" ]]; then
  fail "AC-INT-002: verify-branding-health.sh not found at $BRANDING_HEALTH_SCRIPT"
elif [[ ! -x "$BRANDING_HEALTH_SCRIPT" ]]; then
  fail "AC-INT-002: verify-branding-health.sh is not executable"
else
  echo "---"
  if "$BRANDING_HEALTH_SCRIPT" >/dev/null 2>&1; then
    echo "---"
    pass "AC-INT-002: verify-branding-health.sh passes for all configured domains"
  else
    exit_code=$?
    echo "---"
    fail "AC-INT-002: verify-branding-health.sh exited with code $exit_code"
  fi
fi

# Check 7: Verify theme structure matches spec (AC-INT-001)
echo
echo -e "${BLUE}Checking theme directory structure...${NC}"

THEME_DIRS=(
  "infrastructure/tutor/themes/mereka/lms/static/images"
  "infrastructure/tutor/themes/mereka/lms/static/fonts"
  "infrastructure/tutor/themes/mereka/lms/static/css"
  "infrastructure/tutor/themes/mereka/cms/static/images"
  "infrastructure/tutor/themes/mereka/cms/static/fonts"
  "infrastructure/tutor/themes/mereka/mfe"
  "infrastructure/tutor/themes/mereka/common/templates"
)

STRUCTURE_CHECK_PASS=0
STRUCTURE_CHECK_FAIL=0

for dir in "${THEME_DIRS[@]}"; do
  if [[ -d "${REPO_ROOT}/${dir}" ]]; then
    pass "Theme directory exists: $dir"
    STRUCTURE_CHECK_PASS=$((STRUCTURE_CHECK_PASS + 1))
  else
    fail "Theme directory missing: $dir"
    STRUCTURE_CHECK_FAIL=$((STRUCTURE_CHECK_FAIL + 1))
  fi
done

if [[ $STRUCTURE_CHECK_FAIL -eq 0 ]]; then
  pass "AC-INT-001: Theme structure matches spec requirements"
else
  fail "AC-INT-001: Incomplete theme structure (found $STRUCTURE_CHECK_PASS/${#THEME_DIRS[@]})"
fi

# Summary
echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"

if [[ $FAIL -gt 0 ]]; then
  echo
  echo "Action required: Fix branding configuration for multi-domain support."
  echo "  1. Ensure all domains configured: ${PRODUCTION_DOMAINS[*]}"
  echo "  2. Run: ./scripts/infra/prepare-tutor-build-context.sh --target all"
  echo "  3. Verify: ./scripts/branding/verify-branding-health.sh"
  exit 1
fi

exit 0
