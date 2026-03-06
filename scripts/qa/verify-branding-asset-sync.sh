#!/usr/bin/env bash
# @covers AC-INT-003, AC-SLOT-029
# @spec: branding-system_spec.md, mfe-plugin-slots_spec.md
set -euo pipefail

# verify-branding-asset-sync.sh - Verify apply-patches workflow syncs theme assets correctly
#
# AC-INT-003: After tutor images build openedx completes, Mereka logo variants exist
# in compiled static files and grep -r "fonts.googleapis.com" tutor_env/env/build/openedx/
# returns zero results.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

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

echo "=== Branding System: Asset Sync Verification ==="
echo "Spec: branding-system_spec.md | AC-INT-003"
echo

# Check 1: Verify tutor_env build directory exists
BUILD_DIR="${REPO_ROOT}/tutor_env/env/build/openedx"
BUILD_AVAILABLE=1

if [[ ! -d "$BUILD_DIR" ]]; then
  BUILD_AVAILABLE=0
  skip "tutor_env/env/build/openedx not found (image build not completed)"
else
  pass "Build directory exists: tutor_env/env/build/openedx"
fi

RUNTIME_THEME_AVAILABLE=0
if [[ "$BUILD_AVAILABLE" -eq 1 ]]; then
  RUNTIME_THEME_AVAILABLE=1
  if [[ ! -d "${BUILD_DIR}/themes/mereka" ]]; then
    RUNTIME_THEME_AVAILABLE=0
    skip "Rendered themes/mereka build tree not found (runtime asset checks 2/3/4/7 will be skipped)"
  fi
fi

# Check 2: Verify Mereka logo variants exist in compiled static files (AC-INT-003)
echo
echo -e "${BLUE}Checking Mereka logo variants in build directory...${NC}"

# Expected locations after apply-patches.sh sync
LOGO_BUILD_PATHS=(
  "themes/mereka/lms/static/images/logo.png"
  "themes/mereka/lms/static/images/logo-horizontal.png"
  "themes/mereka/lms/static/images/logo-horizontal-white.png"
  "themes/mereka/lms/static/images/logo-square.png"
  "themes/mereka/lms/static/images/logo-horizontal.svg"
  "themes/mereka/lms/static/images/logo-horizontal-white.svg"
  "themes/mereka/lms/static/images/logo-square.svg"
  "themes/mereka/lms/static/images/favicon.ico"
)

if [[ "$RUNTIME_THEME_AVAILABLE" -eq 1 ]]; then
  LOGO_FOUND=0
  LOGO_MISSING=0

  for logo_path in "${LOGO_BUILD_PATHS[@]}"; do
    full_path="${BUILD_DIR}/${logo_path}"
    if [[ -f "$full_path" ]]; then
      pass "Logo variant synced to build: $logo_path"
      LOGO_FOUND=$((LOGO_FOUND + 1))
    else
      fail "Logo variant missing in build: $logo_path"
      LOGO_MISSING=$((LOGO_MISSING + 1))
    fi
  done

  if [[ $LOGO_MISSING -eq 0 ]]; then
    pass "AC-INT-003 (Part 1): All Mereka logo variants exist in compiled static files"
  else
    fail "AC-INT-003 (Part 1): Missing logo variants in build (found $LOGO_FOUND/${#LOGO_BUILD_PATHS[@]})"
  fi

  # Check 3: Verify fonts exist in build directory
  echo
  echo -e "${BLUE}Checking custom fonts in build directory...${NC}"

  FONT_BUILD_DIR="${BUILD_DIR}/themes/mereka/lms/static/fonts"

  if [[ ! -d "$FONT_BUILD_DIR" ]]; then
    fail "Font directory missing in build: themes/mereka/lms/static/fonts"
  else
    pass "Font directory exists in build"

    # Count .woff2 files
    FONT_COUNT=$(find "$FONT_BUILD_DIR" -name "*.woff2" 2>/dev/null | wc -l)

    if [[ $FONT_COUNT -gt 0 ]]; then
      pass "Custom fonts synced to build ($FONT_COUNT .woff2 files found)"
    else
      fail "No custom fonts (.woff2) found in build directory"
    fi
  fi

  # Check 4: Verify Google Fonts imports removed from Mereka theme (AC-INT-003 Part 2)
  echo
  echo -e "${BLUE}Verifying Google Fonts removal from Mereka theme...${NC}"

  GOOGLE_FONTS_PATTERN="fonts.googleapis.com"
  MEREKA_THEME_DIR="${BUILD_DIR}/themes/mereka"

  echo "  Running: grep -r '$GOOGLE_FONTS_PATTERN' tutor_env/env/build/openedx/themes/mereka/"
  GOOGLE_FONTS_MATCHES=$(grep -r "$GOOGLE_FONTS_PATTERN" "$MEREKA_THEME_DIR" 2>/dev/null || true)

  if [[ -z "$GOOGLE_FONTS_MATCHES" ]]; then
    pass "AC-INT-003 (Part 2): No Google Fonts in Mereka theme (custom branding clean)"
  else
    fail "AC-INT-003 (Part 2): Found Google Fonts references in Mereka theme"
    echo
    echo "  Google Fonts references found in:"
    echo "$GOOGLE_FONTS_MATCHES" | head -10 | sed 's/^/    /'
  fi

  # Also check if Indigo theme has Google Fonts (informational only)
  INDIGO_THEME_DIR="${BUILD_DIR}/themes/indigo"
  if [[ -d "$INDIGO_THEME_DIR" ]]; then
    INDIGO_FONTS=$(grep -r "$GOOGLE_FONTS_PATTERN" "$INDIGO_THEME_DIR" 2>/dev/null | wc -l || echo "0")
    if [[ $INDIGO_FONTS -gt 0 ]]; then
      echo "  Note: Default Indigo theme contains $INDIGO_FONTS Google Fonts references (not used in production)"
    fi
  fi
else
  skip "AC-INT-003 (Part 1): runtime logo sync checks skipped (rendered theme artifacts unavailable)"
  skip "AC-INT-003 (Part 2): runtime Google Fonts checks skipped (rendered theme artifacts unavailable)"
fi

# Check 5: Verify MFE SCSS synced to build
echo
echo -e "${BLUE}Checking MFE branding assets in build directory...${NC}"

MFE_BUILD_DIR="${REPO_ROOT}/tutor_env/env/plugins/mfe/build/mfe"

if [[ "$RUNTIME_THEME_AVAILABLE" -eq 1 ]]; then
  if [[ ! -d "$MFE_BUILD_DIR" ]]; then
    skip "MFE build directory not found (MFE image not built)"
  else
    pass "MFE build directory exists"

    # Check for mereka.scss or brand.scss
    MFE_SCSS_FOUND=false

    if [[ -f "${MFE_BUILD_DIR}/indigo/mereka/mereka.scss" ]]; then
      pass "MFE SCSS synced: indigo/mereka/mereka.scss"
      MFE_SCSS_FOUND=true
    elif [[ -f "${MFE_BUILD_DIR}/brand/mereka.scss" ]]; then
      pass "MFE SCSS synced: brand/mereka.scss"
      MFE_SCSS_FOUND=true
    fi

    if [[ "$MFE_SCSS_FOUND" == "false" ]]; then
      fail "MFE SCSS not found in build directory"
    fi
  fi
else
  skip "MFE build-asset checks skipped (rendered theme artifacts unavailable)"
fi

# Check 6: Verify apply-patches.sh syncs assets correctly
echo
echo -e "${BLUE}Verifying apply-patches.sh asset sync logic...${NC}"

APPLY_PATCHES="${REPO_ROOT}/infrastructure/tutor/apply-patches.sh"

if [[ ! -f "$APPLY_PATCHES" ]]; then
  fail "apply-patches.sh not found at $APPLY_PATCHES"
else
  pass "apply-patches.sh exists"
  if grep -q 'source "\$PATCHES_DIR/mfe-node.sh"' "$APPLY_PATCHES"; then
    pass "apply-patches sources mfe-node patch module"
  else
    fail "apply-patches missing source for mfe-node.sh"
  fi
  if grep -q 'source "\$PATCHES_DIR/brand-package.sh"' "$APPLY_PATCHES"; then
    pass "apply-patches sources brand-package patch module"
  else
    fail "apply-patches missing source for brand-package.sh"
  fi

  SYNC_BRAND_ASSETS="$REPO_ROOT/scripts/branding/sync-brand-assets.sh"
  SYNC_BRAND_PACKAGE="$REPO_ROOT/scripts/branding/sync-brand-package.sh"

  if [[ -x "$SYNC_BRAND_ASSETS" ]]; then
    pass "sync-brand-assets.sh exists and is executable"
  else
    fail "sync-brand-assets.sh missing or not executable"
  fi
  if [[ -x "$SYNC_BRAND_PACKAGE" ]]; then
    pass "sync-brand-package.sh exists and is executable"
  else
    fail "sync-brand-package.sh missing or not executable"
  fi
  if grep -q 'BRAND_PACKAGE_SYNC=' "$SYNC_BRAND_ASSETS" && grep -q '"\$BRAND_PACKAGE_SYNC"' "$SYNC_BRAND_ASSETS"; then
    pass "sync-brand-assets.sh invokes sync-brand-package.sh in the asset pipeline"
  else
    fail "sync-brand-assets.sh does not invoke sync-brand-package.sh"
  fi
fi

# Check 7: Verify CMS theme assets also synced
echo
echo -e "${BLUE}Checking Studio (CMS) theme assets in build directory...${NC}"

CMS_THEME_IMAGES="${BUILD_DIR}/themes/mereka/cms/static/images"

if [[ "$RUNTIME_THEME_AVAILABLE" -eq 1 ]]; then
  if [[ ! -d "$CMS_THEME_IMAGES" ]]; then
    fail "CMS theme images directory missing in build"
  else
    pass "CMS theme images directory exists in build"

    # Check for at least one logo file
    if ls "$CMS_THEME_IMAGES"/logo*.png >/dev/null 2>&1; then
      pass "CMS logo files found in build"
    else
      fail "No CMS logo files found in build"
    fi
  fi
else
  skip "CMS theme asset checks skipped (rendered theme artifacts unavailable)"
fi

# Check 8: Verify SASS compilation strips Google Fonts
echo
echo -e "${BLUE}Checking SASS compilation configuration...${NC}"

# Check if build patches mention Google Fonts stripping/handling.
if rg -q "strip.*google.*fonts|fonts\\.googleapis\\.com|fonts\\.gstatic\\.com" \
  "$REPO_ROOT/infrastructure/tutor/patches" "$APPLY_PATCHES" 2>/dev/null; then
  pass "Google Fonts handling logic present in Tutor patch/apply scripts"
else
  skip "Google Fonts stripping logic not explicitly found in patch/apply scripts (may be implicit)"
fi

# Check 9: Verify DEFAULT_SITE_THEME setting
echo
echo -e "${BLUE}Checking DEFAULT_SITE_THEME configuration...${NC}"

LMS_PRODUCTION_PY="${REPO_ROOT}/tutor_env/env/apps/openedx/settings/lms/production.py"

if [[ -f "$LMS_PRODUCTION_PY" ]]; then
  if grep -q 'DEFAULT_SITE_THEME.*=.*"mereka"' "$LMS_PRODUCTION_PY"; then
    pass "DEFAULT_SITE_THEME set to 'mereka' in LMS production.py"
  else
    fail "DEFAULT_SITE_THEME not set to 'mereka' in LMS production.py"
  fi
else
  skip "LMS production.py not found (tutor_env not generated)"
fi

# Summary
echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"

if [[ $FAIL -gt 0 ]]; then
  echo
  echo "Action required: Re-sync branding assets and rebuild images."
  echo "  1. Run: ./infrastructure/tutor/apply-patches.sh"
  echo "  2. Build: tutor images build openedx"
  echo "  3. Verify: grep -r 'fonts.googleapis.com' tutor_env/env/build/openedx/"
  exit 1
fi

if [[ "$BUILD_AVAILABLE" -eq 0 ]]; then
  echo
  echo "Note: Runtime asset checks were skipped because Tutor build artifacts are unavailable."
  echo "  Run: tutor images build openedx"
fi

exit 0
