#!/usr/bin/env bash
# verify-brand-parity.sh — WhiteCliff brand/plugin parity verification.
# Verifies that all surfaces (LMS, Studio, MFEs) carry consistent Mereka Academy
# branding: logos, favicons, fonts, color tokens, header, and footer.
# T016 — superset of verify-footer-parity.sh (footer is checked via AC-003/007/008).
#
# @spec: branding-system_spec.md
# @covers AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008, AC-009
# @covers AC-BRAND-001: Brand token file (_tokens.scss) defines required CSS custom properties
# @covers AC-BRAND-002: Logo assets present in LMS, Studio, and MFE theme directories
# @covers AC-BRAND-003: Favicon assets present in LMS, Studio, and MFE theme directories
# @covers AC-BRAND-004: Self-hosted fonts present for LMS, Studio, and MFE (no Google Fonts)
# @covers AC-BRAND-005: LMS header brand.html references Mereka logo
# @covers AC-BRAND-006: Studio head-extra.html loads Mereka overrides CSS
# @covers AC-BRAND-007: LMS head-extra.html loads Mereka overrides CSS
# @covers AC-BRAND-008: MFE mereka.scss declares --mereka-* CSS custom properties
# @covers AC-BRAND-009: No google fonts references in any theme file
# @covers AC-BRAND-010: Theme SCSS shared token stack (_tokens.scss, _fonts.scss, theme.scss)
# @covers AC-BRAND-011: LMS footer has Mereka branding (delegates to footer-parity checks)
# @covers AC-BRAND-012: Studio footer widget (cms/templates/widgets/footer.html) is white-label
# @covers AC-BRAND-013: Studio SCSS (studio-main-v1.scss) imports shared token stack
# @covers AC-BRAND-014: apply-patches.sh wires branding patches (SCSS, fonts, footer)
# @covers AC-BRAND-015: Live LMS page has Mereka logo src attribute (--live mode)
# @covers AC-BRAND-016: Live Studio page has Mereka branding markers (--live mode)
# @covers AC-BRAND-017: Live MFE authn page has Mereka branding markers (--live mode)
#
# Usage:
#   scripts/qa/verify-brand-parity.sh [--offline] [--live] [--lms-url URL] [--studio-url URL] [--mfe-url URL]
#
# Modes:
#   --offline  (default) Check theme directory structure, SCSS variables, logo/favicon
#              files, MFE brand config, apply-patches.sh wiring, font files.
#   --live     Probe LMS/Studio/MFE pages for brand elements (logo src, favicon,
#              CSS custom properties, no Open edX default leakage).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../shared/config.sh" 2>/dev/null || true

PASS=0
FAIL=0
WARN=0
SKIP=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }
warn() { WARN=$((WARN + 1)); echo "  WARN: $1"; }
skip() { SKIP=$((SKIP + 1)); echo "  SKIP: $1"; }

# Parse flags
LIVE_MODE=0
LMS_URL="https://${LMS_DOMAIN:-academyv2.mereka.io}"
STUDIO_URL="https://${STUDIO_DOMAIN:-studio.academyv2.mereka.io}"
MFE_URL="https://${MFE_DOMAIN:-apps.academyv2.mereka.io}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --live|--online) LIVE_MODE=1; shift ;;
    --offline)       shift ;;
    --lms-url)       LMS_URL="$2"; shift 2 ;;
    --studio-url)    STUDIO_URL="$2"; shift 2 ;;
    --mfe-url)       MFE_URL="$2"; shift 2 ;;
    -h|--help)
      sed -n '3,26p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Theme paths
THEME_ROOT="$REPO_ROOT/infrastructure/tutor/themes/mereka"
SCSS_TOKENS="$THEME_ROOT/scss/_tokens.scss"
SCSS_FONTS="$THEME_ROOT/scss/_fonts.scss"
SCSS_THEME="$THEME_ROOT/scss/theme.scss"

# LMS surfaces
LMS_THEME_SCSS="$THEME_ROOT/lms/static/sass/theme.scss"
LMS_OVERRIDES_CSS="$THEME_ROOT/lms/static/css/mereka-overrides.css"
LMS_HEAD_EXTRA="$THEME_ROOT/lms/templates/head-extra.html"
LMS_BRAND_HTML="$THEME_ROOT/lms/templates/header/brand.html"
LMS_FOOTER="$THEME_ROOT/lms/templates/footer.html"
LMS_LOGO_DIR="$THEME_ROOT/lms/static/images"
LMS_FONT_DIR="$THEME_ROOT/lms/static/fonts"

# Studio surfaces
CMS_THEME_SCSS="$THEME_ROOT/cms/static/sass/theme.scss"
CMS_STUDIO_SCSS="$THEME_ROOT/cms/static/sass/studio-main-v1.scss"
CMS_OVERRIDES_CSS="$THEME_ROOT/cms/static/css/mereka-overrides.css"
CMS_HEAD_EXTRA="$THEME_ROOT/cms/templates/head-extra.html"
CMS_FOOTER_WIDGET="$THEME_ROOT/cms/templates/widgets/footer.html"
CMS_LOGO_DIR="$THEME_ROOT/cms/static/images"
CMS_FONT_DIR="$THEME_ROOT/cms/static/fonts"

# MFE surfaces
MFE_SCSS="$THEME_ROOT/mfe/mereka.scss"
MFE_IMAGE_DIR="$THEME_ROOT/mfe/images"
MFE_FONT_DIR="$THEME_ROOT/mfe/fonts"

# Plugin and patches
PLUGIN="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
APPLY_PATCHES="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
FOOTER_PATCH="$REPO_ROOT/infrastructure/tutor/patches/footer-component.sh"

echo "========================================================"
echo "WhiteCliff Brand Parity Verifier (T016)"
echo "Repo: $REPO_ROOT"
echo "========================================================"
echo ""

# -----------------------------------------------------------------------
# AC-BRAND-010: Shared token stack completeness
# _tokens.scss, _fonts.scss, and theme.scss must all exist and chain correctly
# -----------------------------------------------------------------------
echo "[OFFLINE] AC-BRAND-010: Shared token stack (_tokens.scss, _fonts.scss, theme.scss)"

if [[ -f "$SCSS_TOKENS" ]]; then
  pass "_tokens.scss exists"
else
  fail "_tokens.scss missing: $SCSS_TOKENS"
fi

if [[ -f "$SCSS_FONTS" ]]; then
  pass "_fonts.scss exists"
else
  fail "_fonts.scss missing: $SCSS_FONTS"
fi

if [[ -f "$SCSS_THEME" ]]; then
  pass "theme.scss exists"
  if grep -q "@import.*fonts" "$SCSS_THEME"; then
    pass "theme.scss imports _fonts partial"
  else
    fail "theme.scss does not import _fonts partial"
  fi
  if grep -q "@import.*tokens" "$SCSS_THEME"; then
    pass "theme.scss imports _tokens partial"
  else
    fail "theme.scss does not import _tokens partial"
  fi
else
  fail "theme.scss missing: $SCSS_THEME"
fi

echo ""

# -----------------------------------------------------------------------
# AC-BRAND-001: Brand token file defines required CSS custom properties
# -----------------------------------------------------------------------
echo "[OFFLINE] AC-BRAND-001: Brand token definitions in _tokens.scss"

REQUIRED_TOKENS=(
  "--mereka-font-body"
  "--mereka-font-heading"
  "--mereka-color-teal"
  "--mereka-color-magenta"
  "--mereka-color-blue"
  "--mereka-color-ink-900"
  "--mereka-color-ink-700"
  "--mereka-color-surface-primary"
  "--mereka-shadow-card"
)

if [[ -f "$SCSS_TOKENS" ]]; then
  for token in "${REQUIRED_TOKENS[@]}"; do
    # Use grep -F -- to prevent '--' prefix from being parsed as an option flag
    if grep -qF -- "$token" "$SCSS_TOKENS"; then
      pass "_tokens.scss defines $token"
    else
      fail "_tokens.scss missing required token: $token"
    fi
  done

  # Verify SCSS variables for primary brand colors exist
  if grep -q "\$color-teal:" "$SCSS_TOKENS"; then
    pass "_tokens.scss defines \$color-teal"
  else
    fail "_tokens.scss missing \$color-teal SCSS variable"
  fi
  if grep -q "\$color-magenta:" "$SCSS_TOKENS"; then
    pass "_tokens.scss defines \$color-magenta"
  else
    fail "_tokens.scss missing \$color-magenta SCSS variable"
  fi
  if grep -q "\$mereka-body-font:" "$SCSS_TOKENS"; then
    pass "_tokens.scss defines \$mereka-body-font"
  else
    fail "_tokens.scss missing \$mereka-body-font SCSS variable"
  fi
else
  fail "_tokens.scss missing — cannot check token definitions"
fi

echo ""

# -----------------------------------------------------------------------
# AC-BRAND-008: MFE mereka.scss declares --mereka-* CSS custom properties
# -----------------------------------------------------------------------
echo "[OFFLINE] AC-BRAND-008: MFE mereka.scss CSS custom properties"

if [[ -f "$MFE_SCSS" ]]; then
  pass "MFE mereka.scss exists"
  if grep -q "\$mereka-font-path:" "$MFE_SCSS"; then
    pass "MFE mereka.scss overrides \$mereka-font-path (relative to MFE asset dir)"
  else
    warn "MFE mereka.scss does not override \$mereka-font-path — MFE fonts may 404"
  fi
  if grep -q "@import.*scss/theme\|@import.*theme" "$MFE_SCSS"; then
    fail "MFE mereka.scss imports monolithic theme.scss (should stay split to avoid LMS/Studio CSS leakage)"
  else
    pass "MFE mereka.scss avoids monolithic theme.scss import"
  fi
  if grep -q "@import.*./scss/fonts" "$MFE_SCSS" && grep -q "@import.*./scss/tokens" "$MFE_SCSS"; then
    pass "MFE mereka.scss imports focused token/font partials"
  else
    fail "MFE mereka.scss missing focused token/font partial imports"
  fi
  if grep -q "\-\-mereka-mfe-branding-rev:" "$MFE_SCSS"; then
    pass "MFE mereka.scss has branding revision marker (--mereka-mfe-branding-rev)"
  else
    warn "MFE mereka.scss missing branding revision marker --mereka-mfe-branding-rev"
  fi
  if grep -q "\-\-mereka-color-teal:\|\-\-mereka-color-magenta:" "$MFE_SCSS"; then
    pass "MFE mereka.scss declares --mereka-color-* custom properties"
  else
    # May be in the imported theme partial — check shared token file as fallback
    if [[ -f "$SCSS_TOKENS" ]] && grep -q "\-\-mereka-color-teal:" "$SCSS_TOKENS"; then
      pass "MFE --mereka-color-* tokens provided via imported _tokens.scss"
    else
      fail "MFE mereka.scss does not declare --mereka-color-* custom properties"
    fi
  fi
else
  fail "MFE mereka.scss missing: $MFE_SCSS"
fi

echo ""

# -----------------------------------------------------------------------
# AC-BRAND-002: Logo assets present across all three surfaces
# -----------------------------------------------------------------------
echo "[OFFLINE] AC-BRAND-002: Logo assets in LMS, Studio, and MFE directories"

LOGO_FILES=("logo.png" "logo.svg" "logo-horizontal.png" "logo-white.png" "logo-square.png")

for surface in "lms" "cms" "mfe"; do
  if [[ "$surface" == "mfe" ]]; then
    img_dir="$MFE_IMAGE_DIR"
  else
    img_dir="$THEME_ROOT/$surface/static/images"
  fi

  if [[ -d "$img_dir" ]]; then
    found_count=0
    for logo in "${LOGO_FILES[@]}"; do
      if [[ -f "$img_dir/$logo" ]]; then
        found_count=$((found_count + 1))
      fi
    done
    if [[ "$found_count" -ge 3 ]]; then
      pass "$surface: $found_count/${#LOGO_FILES[@]} logo variants present"
    elif [[ "$found_count" -ge 1 ]]; then
      warn "$surface: only $found_count/${#LOGO_FILES[@]} logo variants present (need at least 3)"
    else
      fail "$surface: no logo files found in $img_dir"
    fi
    # logo.png is the canonical LMS header logo — must be present
    if [[ -f "$img_dir/logo.png" ]]; then
      pass "$surface: logo.png (canonical) present"
    else
      fail "$surface: logo.png missing — canonical header logo required"
    fi
  else
    fail "$surface: image directory missing: $img_dir"
  fi
done

echo ""

# -----------------------------------------------------------------------
# AC-BRAND-003: Favicon assets present across all three surfaces
# -----------------------------------------------------------------------
echo "[OFFLINE] AC-BRAND-003: Favicon assets in LMS, Studio, and MFE directories"

FAVICON_FILES=("favicon.ico" "favicon-32x32.png" "favicon-16x16.png")

for surface in "lms" "cms" "mfe"; do
  if [[ "$surface" == "mfe" ]]; then
    img_dir="$MFE_IMAGE_DIR"
  else
    img_dir="$THEME_ROOT/$surface/static/images"
  fi

  if [[ -d "$img_dir" ]]; then
    favicon_count=0
    for fav in "${FAVICON_FILES[@]}"; do
      if [[ -f "$img_dir/$fav" ]]; then
        favicon_count=$((favicon_count + 1))
      fi
    done
    if [[ "$favicon_count" -ge 3 ]]; then
      pass "$surface: all $favicon_count/${#FAVICON_FILES[@]} favicon sizes present"
    elif [[ "$favicon_count" -ge 1 ]]; then
      warn "$surface: only $favicon_count/${#FAVICON_FILES[@]} favicon sizes present"
    else
      fail "$surface: no favicon files found in $img_dir"
    fi
    # favicon.ico is the universal fallback — must be present on all surfaces
    if [[ -f "$img_dir/favicon.ico" ]]; then
      pass "$surface: favicon.ico (universal fallback) present"
    else
      fail "$surface: favicon.ico missing"
    fi
    # favicon-256x256 for PWA / homescreen
    if [[ -f "$img_dir/favicon-256x256.png" ]]; then
      pass "$surface: favicon-256x256.png (PWA/homescreen) present"
    else
      warn "$surface: favicon-256x256.png missing (needed for PWA homescreen icon)"
    fi
  else
    fail "$surface: image directory missing: $img_dir"
  fi
done

echo ""

# -----------------------------------------------------------------------
# AC-BRAND-004: Self-hosted fonts present — no Google Fonts dependency
# -----------------------------------------------------------------------
echo "[OFFLINE] AC-BRAND-004: Self-hosted fonts present for LMS, Studio, and MFE"

FONT_SURFACES=(
  "lms:$LMS_FONT_DIR"
  "cms:$CMS_FONT_DIR"
  "mfe:$MFE_FONT_DIR"
)

for entry in "${FONT_SURFACES[@]}"; do
  surface="${entry%%:*}"
  font_dir="${entry#*:}"

  if [[ -d "$font_dir" ]]; then
    woff2_count=$(ls "$font_dir"/*.woff2 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$woff2_count" -ge 4 ]]; then
      pass "$surface: $woff2_count .woff2 font files present"
    elif [[ "$woff2_count" -ge 1 ]]; then
      warn "$surface: only $woff2_count .woff2 files (expected >= 4 for Poppins + Lato)"
    else
      fail "$surface: no .woff2 files in font directory $font_dir"
    fi

    # Poppins and Lato are the canonical brand fonts — both required
    if ls "$font_dir"/Poppins-*.woff2 >/dev/null 2>&1; then
      pass "$surface: Poppins font files present"
    else
      fail "$surface: Poppins font files missing"
    fi
    if ls "$font_dir"/Lato-*.woff2 >/dev/null 2>&1; then
      pass "$surface: Lato font files present"
    else
      fail "$surface: Lato font files missing"
    fi
  else
    fail "$surface: font directory missing: $font_dir"
  fi
done

echo ""

# -----------------------------------------------------------------------
# AC-BRAND-009: No Google Fonts references anywhere in theme
# -----------------------------------------------------------------------
echo "[OFFLINE] AC-BRAND-009: No Google Fonts references in theme files"

GOOGLE_FONTS_HIT=$(grep -rli "fonts.googleapis.com\|fonts.gstatic.com" "$THEME_ROOT" 2>/dev/null || true)
if [[ -z "$GOOGLE_FONTS_HIT" ]]; then
  pass "No Google Fonts references in theme directory"
else
  fail "Google Fonts reference found in theme — privacy violation:"
  echo "$GOOGLE_FONTS_HIT" | sed 's/^/    /'
fi

if [[ -f "$PLUGIN" ]]; then
  if grep -vE '^\s*#|^\s*//|^\s*/\*|^\s*\*' "$PLUGIN" | grep -q "fonts.googleapis.com\|fonts.gstatic.com"; then
    fail "Plugin (mereka_lms.py) references Google Fonts"
  else
    pass "Plugin has no active Google Fonts references"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-BRAND-005: LMS header brand.html references Mereka logo
# -----------------------------------------------------------------------
echo "[OFFLINE] AC-BRAND-005: LMS header brand.html"

if [[ -f "$LMS_BRAND_HTML" ]]; then
  pass "LMS brand.html exists"
  if grep -q "logo.png\|logo-image\|mereka-navbar-brand" "$LMS_BRAND_HTML"; then
    pass "LMS brand.html references Mereka logo"
  else
    fail "LMS brand.html has no Mereka logo reference"
  fi
  if grep -q "branding_api\|get_home_url\|platform_name" "$LMS_BRAND_HTML"; then
    pass "LMS brand.html uses branding API (not hardcoded URL)"
  else
    warn "LMS brand.html may have hardcoded URL — prefer branding_api.get_home_url()"
  fi
  # Only flag visible Open edX branding in HTML/text content; exclude Mako/Python imports
  # (openedx.core Python imports are expected in Mako templates)
  LMS_BRAND_VISIBLE=$(grep -v "^## \|from openedx\.\|import openedx\." "$LMS_BRAND_HTML" | grep -i "open edx\|openedx" || true)
  if [[ -n "$LMS_BRAND_VISIBLE" ]]; then
    fail "LMS brand.html contains visible Open edX branding — must be white-label"
    echo "$LMS_BRAND_VISIBLE" | sed 's/^/    /'
  else
    pass "LMS brand.html has no Open edX visible branding (Python imports are expected)"
  fi
else
  fail "LMS brand.html missing: $LMS_BRAND_HTML"
fi

echo ""

# -----------------------------------------------------------------------
# AC-BRAND-007: LMS head-extra.html loads Mereka overrides
# -----------------------------------------------------------------------
echo "[OFFLINE] AC-BRAND-007: LMS head-extra.html"

if [[ -f "$LMS_HEAD_EXTRA" ]]; then
  pass "LMS head-extra.html exists"
  if grep -q "mereka-overrides.css" "$LMS_HEAD_EXTRA"; then
    pass "LMS head-extra.html loads mereka-overrides.css"
  else
    fail "LMS head-extra.html does not load mereka-overrides.css"
  fi
  if grep -q "preload.*font\|font.*preload" "$LMS_HEAD_EXTRA"; then
    pass "LMS head-extra.html preloads brand fonts"
  else
    warn "LMS head-extra.html does not preload fonts (performance impact)"
  fi
  if grep -q "Poppins\|Lato" "$LMS_HEAD_EXTRA"; then
    pass "LMS head-extra.html references Poppins/Lato brand fonts"
  else
    warn "LMS head-extra.html does not reference Poppins or Lato fonts"
  fi
else
  fail "LMS head-extra.html missing: $LMS_HEAD_EXTRA"
fi

# LMS CSS overrides file must exist
if [[ -f "$LMS_OVERRIDES_CSS" ]]; then
  pass "LMS mereka-overrides.css exists"
else
  fail "LMS mereka-overrides.css missing: $LMS_OVERRIDES_CSS"
fi

# LMS SCSS theme.scss must import shared token stack
if [[ -f "$LMS_THEME_SCSS" ]]; then
  pass "LMS theme.scss exists"
  if grep -q "@import.*theme\|scss/theme" "$LMS_THEME_SCSS"; then
    pass "LMS theme.scss imports shared token stack"
  else
    fail "LMS theme.scss does not import shared token stack"
  fi
else
  fail "LMS theme.scss missing: $LMS_THEME_SCSS"
fi

echo ""

# -----------------------------------------------------------------------
# AC-BRAND-006 / AC-BRAND-013: Studio head-extra.html and Studio SCSS
# -----------------------------------------------------------------------
echo "[OFFLINE] AC-BRAND-006: Studio head-extra.html and SCSS"

if [[ -f "$CMS_HEAD_EXTRA" ]]; then
  pass "Studio head-extra.html exists"
  if grep -q "mereka-overrides.css" "$CMS_HEAD_EXTRA"; then
    pass "Studio head-extra.html loads mereka-overrides.css"
  else
    fail "Studio head-extra.html does not load mereka-overrides.css"
  fi
  if grep -q "Poppins\|Lato" "$CMS_HEAD_EXTRA"; then
    pass "Studio head-extra.html references brand fonts"
  else
    warn "Studio head-extra.html does not reference Poppins or Lato fonts"
  fi
else
  fail "Studio head-extra.html missing: $CMS_HEAD_EXTRA"
fi

if [[ -f "$CMS_OVERRIDES_CSS" ]]; then
  pass "Studio mereka-overrides.css exists"
else
  fail "Studio mereka-overrides.css missing: $CMS_OVERRIDES_CSS"
fi

# AC-BRAND-013: Studio-specific SCSS (studio-main-v1.scss) imports shared tokens
if [[ -f "$CMS_STUDIO_SCSS" ]]; then
  pass "Studio studio-main-v1.scss exists"
  if grep -q "@import.*theme\|scss/theme\|../../../scss/theme" "$CMS_STUDIO_SCSS"; then
    pass "Studio studio-main-v1.scss imports shared token stack"
  else
    fail "Studio studio-main-v1.scss does not import shared token stack"
  fi
else
  fail "Studio studio-main-v1.scss missing: $CMS_STUDIO_SCSS"
fi

if [[ -f "$CMS_THEME_SCSS" ]]; then
  pass "Studio theme.scss entrypoint exists"
else
  fail "Studio theme.scss entrypoint missing: $CMS_THEME_SCSS"
fi

echo ""

# -----------------------------------------------------------------------
# AC-BRAND-012: Studio footer widget is white-label (no Open edX branding)
# -----------------------------------------------------------------------
echo "[OFFLINE] AC-BRAND-012: Studio footer widget white-label"

if [[ -f "$CMS_FOOTER_WIDGET" ]]; then
  pass "Studio footer widget (cms/templates/widgets/footer.html) exists"
  if grep -qi "mereka\|Mereka Academy" "$CMS_FOOTER_WIDGET"; then
    pass "Studio footer widget contains Mereka branding"
  else
    warn "Studio footer widget exists but lacks explicit Mereka brand name"
  fi
  if grep -qi "powered by open edx\|footer-about-openedx\|open-edx-logo-tag" "$CMS_FOOTER_WIDGET"; then
    fail "Studio footer widget has 'Powered by Open edX' — must be removed for white-label Studio"
  else
    pass "Studio footer widget has no 'Powered by Open edX' (white-label)"
  fi
  if grep -q "mereka-studio-footer\|mereka-footer" "$CMS_FOOTER_WIDGET"; then
    pass "Studio footer widget has Mereka footer CSS class"
  else
    warn "Studio footer widget missing Mereka CSS class identifier (mereka-studio-footer)"
  fi
  # Must have dynamic copyright year (not hardcoded)
  if grep -qE "datetime\.now\(\)\.year|%Y|\{year\}" "$CMS_FOOTER_WIDGET"; then
    pass "Studio footer widget has dynamic copyright year"
  else
    fail "Studio footer widget missing dynamic copyright year"
  fi
else
  fail "Studio footer widget missing: $CMS_FOOTER_WIDGET — Studio renders upstream Open edX footer"
fi

echo ""

# -----------------------------------------------------------------------
# AC-BRAND-011: LMS footer has Mereka branding
# -----------------------------------------------------------------------
echo "[OFFLINE] AC-BRAND-011: LMS footer Mereka branding"

if [[ -f "$LMS_FOOTER" ]]; then
  pass "LMS footer template exists"
  if grep -qi "mereka\|mereka-footer" "$LMS_FOOTER"; then
    pass "LMS footer contains Mereka branding"
  else
    fail "LMS footer has no Mereka branding content"
  fi
  if grep -q "mereka-footer" "$LMS_FOOTER"; then
    pass "LMS footer has mereka-footer CSS class"
  else
    fail "LMS footer missing mereka-footer CSS class"
  fi
  if grep -q "logo.png\|images/logo" "$LMS_FOOTER"; then
    pass "LMS footer references Mereka logo image"
  else
    warn "LMS footer does not reference logo image"
  fi
  if grep -qE "datetime\.now\(\)\.year|%Y" "$LMS_FOOTER"; then
    pass "LMS footer has dynamic copyright year"
  else
    fail "LMS footer missing dynamic copyright year expression"
  fi
  # Guard against Open edX default leakage
  POWERED_BY=$(grep -i "powered by open edx" "$LMS_FOOTER" | grep -v '^\s*##' || true)
  if [[ -z "$POWERED_BY" ]]; then
    pass "LMS footer has no unbranded 'Powered by Open edX'"
  else
    fail "LMS footer has 'Powered by Open edX' — must be removed or co-branded"
  fi
else
  fail "LMS footer template missing: $LMS_FOOTER"
fi

echo ""

# -----------------------------------------------------------------------
# AC-BRAND-014: apply-patches.sh wires branding patches
# -----------------------------------------------------------------------
echo "[OFFLINE] AC-BRAND-014: apply-patches.sh branding wiring"

if [[ -f "$APPLY_PATCHES" ]]; then
  pass "apply-patches.sh exists"
  # Footer component must be sourced
  if grep -q "footer-component.sh\|apply_footer_component_patch" "$APPLY_PATCHES"; then
    pass "apply-patches.sh wires footer-component patch"
  else
    fail "apply-patches.sh does not wire footer-component patch"
  fi
  # SCSS/MFE theme injection
  if grep -q "mereka.scss\|mereka_scss\|mfe.*branding\|MFE_BRANDING" "$APPLY_PATCHES"; then
    pass "apply-patches.sh references MFE mereka.scss injection"
  elif [[ -f "$FOOTER_PATCH" ]] && grep -q "mereka/mereka.scss" "$FOOTER_PATCH"; then
    pass "MFE mereka.scss injection is handled by footer-component.sh asset sync path"
  else
    warn "MFE mereka.scss injection path not detected — check apply-patches + footer-component wiring"
  fi
  # Branding health check invocation
  if grep -q "verify-branding-health\|branding.*check\|BRANDING_CHECK" "$APPLY_PATCHES"; then
    pass "apply-patches.sh invokes branding health check"
  else
    warn "apply-patches.sh does not invoke branding health check (recommended for CI safety)"
  fi
else
  fail "apply-patches.sh missing: $APPLY_PATCHES"
fi

if [[ -f "$FOOTER_PATCH" ]]; then
  pass "footer-component.sh patch module exists"
else
  fail "footer-component.sh patch module missing: $FOOTER_PATCH"
fi

echo ""

# -----------------------------------------------------------------------
# Consistency: same logo/favicon set on all surfaces
# -----------------------------------------------------------------------
echo "[OFFLINE] Cross-surface asset consistency"

SURFACES_IMG_DIRS=(
  "lms:$LMS_LOGO_DIR"
  "cms:$CMS_LOGO_DIR"
  "mfe:$MFE_IMAGE_DIR"
)

CANONICAL_ASSETS=("logo.png" "logo.svg" "favicon.ico" "favicon-32x32.png")

for asset in "${CANONICAL_ASSETS[@]}"; do
  missing_on=()
  for entry in "${SURFACES_IMG_DIRS[@]}"; do
    surface="${entry%%:*}"
    img_dir="${entry#*:}"
    if [[ ! -f "$img_dir/$asset" ]]; then
      missing_on+=("$surface")
    fi
  done
  if [[ "${#missing_on[@]}" -eq 0 ]]; then
    pass "Asset '$asset' present on all surfaces (lms, cms, mfe)"
  elif [[ "${#missing_on[@]}" -lt "${#SURFACES_IMG_DIRS[@]}" ]]; then
    fail "Asset '$asset' missing on: ${missing_on[*]}"
  else
    fail "Asset '$asset' missing on ALL surfaces"
  fi
done

echo ""

# -----------------------------------------------------------------------
# Live mode: probe LMS/Studio/MFE pages for brand elements
# AC-BRAND-015: Live LMS page has Mereka logo
# AC-BRAND-016: Live Studio page has Mereka branding markers
# AC-BRAND-017: Live MFE authn page has Mereka branding
# -----------------------------------------------------------------------
echo "AC-BRAND-015/016/017: Live page brand element checks"

if [[ "$LIVE_MODE" -eq 1 ]]; then
  echo "  LMS URL: $LMS_URL"
  echo "  Studio URL: $STUDIO_URL"
  echo "  MFE URL: $MFE_URL"
  echo ""

  # --- LMS live check ---
  echo "  [LMS live checks: $LMS_URL]"
  LMS_HTML=$(curl -sf --max-time 20 "$LMS_URL" 2>/dev/null || true)
  if [[ -z "$LMS_HTML" ]]; then
    fail "LMS: failed to fetch $LMS_URL (curl error, timeout, or 5xx)"
  else
    pass "LMS: page loaded successfully"
    # Mereka logo must appear in src attribute
    if grep -qi "logo.png\|images/logo\|mereka.*logo" <<<"$LMS_HTML"; then
      pass "LMS: Mereka logo src present in page"
    else
      fail "LMS: no Mereka logo src found in page HTML"
    fi
    # mereka-footer class on LMS pages
    if grep -q "mereka-footer" <<<"$LMS_HTML"; then
      pass "LMS: mereka-footer class present"
    else
      fail "LMS: mereka-footer class NOT present"
    fi
    # No unbranded Open edX
    if grep -qi "powered by open edx" <<<"$LMS_HTML"; then
      fail "LMS: 'Powered by Open edX' found on live page"
    else
      pass "LMS: no 'Powered by Open edX' on live page"
    fi
    # Copyright/brand
    if grep -qiE "©|&copy;|Mereka|Biji-Biji" <<<"$LMS_HTML"; then
      pass "LMS: copyright/brand line present"
    else
      fail "LMS: no copyright/brand line found"
    fi
    # Favicon link
    if grep -qi "favicon\|icon.*\.ico\|icon.*\.png" <<<"$LMS_HTML"; then
      pass "LMS: favicon link present in <head>"
    else
      warn "LMS: no favicon link detected in page <head>"
    fi
  fi

  echo ""

  # --- Studio live check ---
  echo "  [Studio live checks: $STUDIO_URL]"
  STUDIO_HTML=$(curl -sf --max-time 20 "$STUDIO_URL" 2>/dev/null || true)
  if [[ -z "$STUDIO_HTML" ]]; then
    skip "Studio: could not fetch $STUDIO_URL — may require authentication (expected for Studio)"
    # Studio redirects to login page; check the login page for branding
    STUDIO_LOGIN_HTML=$(curl -sf --max-time 20 "${STUDIO_URL}/signin" 2>/dev/null || true)
    if [[ -n "$STUDIO_LOGIN_HTML" ]]; then
      STUDIO_HTML="$STUDIO_LOGIN_HTML"
      echo "  [Studio: using signin page for checks]"
    fi
  fi
  if [[ -n "$STUDIO_HTML" ]]; then
    pass "Studio: page loaded (or signin page reachable)"
    if grep -qi "mereka\|Mereka Academy" <<<"$STUDIO_HTML"; then
      pass "Studio: Mereka brand name present on page"
    else
      fail "Studio: no Mereka brand name found on Studio page"
    fi
    if grep -qi "powered by open edx" <<<"$STUDIO_HTML"; then
      fail "Studio: 'Powered by Open edX' found on live Studio page"
    else
      pass "Studio: no 'Powered by Open edX' on live Studio page"
    fi
    if grep -qi "mereka-overrides\|mereka\.css\|mereka-studio" <<<"$STUDIO_HTML"; then
      pass "Studio: Mereka CSS referenced on Studio page"
    else
      warn "Studio: no Mereka CSS reference found in Studio page — check head-extra.html"
    fi
    if grep -qi "favicon\|icon.*\.ico" <<<"$STUDIO_HTML"; then
      pass "Studio: favicon link present in <head>"
    else
      warn "Studio: no favicon link detected in Studio page <head>"
    fi
  fi

  echo ""

  # --- MFE live check ---
  echo "  [MFE live checks: ${MFE_URL}/authn/login]"
  MFE_HTML=$(curl -sf --max-time 20 "${MFE_URL}/authn/login" 2>/dev/null || true)
  if [[ -z "$MFE_HTML" ]]; then
    fail "MFE: failed to fetch ${MFE_URL}/authn/login"
  else
    pass "MFE: authn login page loaded"
    if grep -qi "mereka\|Mereka Academy\|mereka-footer" <<<"$MFE_HTML"; then
      pass "MFE: Mereka branding present on authn login page"
    elif grep -qiE "/authn/.*\.css|/theme/mereka-brand(\-light)?\.min\.css|/theme/core\.min\.css" <<<"$MFE_HTML"; then
      warn "MFE: explicit brand text markers not in initial HTML; CSS/theme assets detected (branding likely client-rendered)"
    else
      fail "MFE: no Mereka branding found on authn login page"
    fi
    if grep -qi "powered by open edx" <<<"$MFE_HTML"; then
      fail "MFE: 'Powered by Open edX' found on authn login page"
    else
      pass "MFE: no 'Powered by Open edX' on authn login page"
    fi
    if grep -qi "fonts.googleapis.com\|fonts.gstatic.com" <<<"$MFE_HTML"; then
      fail "MFE: Google Fonts request found on authn login page (privacy violation)"
    else
      pass "MFE: no Google Fonts request on authn login page"
    fi
    if grep -qi "favicon" <<<"$MFE_HTML"; then
      pass "MFE: favicon present in authn login page <head>"
    else
      warn "MFE: no favicon detected in authn login page <head>"
    fi
  fi

  echo ""

  # --- Multi-domain check ---
  echo "  [Multi-domain live brand checks]"
  LIVE_DOMAINS=(
    "academyv2.mereka.io"
    "academy.biji-biji.com"
  )
  for domain in "${LIVE_DOMAINS[@]}"; do
    DOMAIN_HTML=$(curl -sf --max-time 15 "https://${domain}" 2>/dev/null || true)
    if [[ -z "$DOMAIN_HTML" ]]; then
      fail "${domain}: failed to fetch"
      continue
    fi
    if grep -qi "mereka-footer\|mereka.*logo\|Mereka Academy" <<<"$DOMAIN_HTML"; then
      pass "${domain}: Mereka brand markers present"
    else
      fail "${domain}: no Mereka brand markers found"
    fi
    if grep -qi "powered by open edx" <<<"$DOMAIN_HTML"; then
      fail "${domain}: 'Powered by Open edX' found"
    else
      pass "${domain}: no 'Powered by Open edX'"
    fi
  done

else
  skip "AC-BRAND-015: LMS live page check skipped — pass --live to run"
  skip "AC-BRAND-016: Studio live page check skipped — pass --live to run"
  skip "AC-BRAND-017: MFE live page check skipped — pass --live to run"
  echo "  Usage: ./scripts/qa/verify-brand-parity.sh --live"
fi

echo ""

# -----------------------------------------------------------------------
# WARN ALLOWLIST
# -----------------------------------------------------------------------
echo "WARN allowlist (accepted warnings — not gate failures):"
echo "  WARN-001: Enterprise MFE portals (admin-portal, learner-portal) use Open edX"
echo "            default footer — MerekaFooter wiring is P4 backlog (see FOOTER_PARITY.md)"
echo "  WARN-002: Studio renders brand via head-extra.html CSS only (not MFE env.config.jsx)"
echo "  WARN-003: MFE font preload in HTML may not appear on static entry bundle — fonts"
echo "            are loaded via mereka.scss @font-face declarations"
echo ""

echo "========================================================"
echo "Brand parity: PASS=$PASS FAIL=$FAIL WARN=$WARN SKIP=$SKIP"
echo "========================================================"

if [[ "$FAIL" -gt 0 ]]; then
  echo "RESULT: FAIL ($FAIL failure(s))" >&2
  exit 1
fi
echo "RESULT: PASS"
exit 0
