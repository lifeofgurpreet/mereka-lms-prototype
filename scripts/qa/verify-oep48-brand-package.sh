#!/usr/bin/env bash
# @covers AC-SLOT-028
# @spec: oep48-brand-package_spec.md, mfe-plugin-slots_spec.md
# verify-oep48-brand-package.sh — OEP-48 brand package formalization audit.
#
# Verifies that Mereka Academy brand assets satisfy OEP-48 requirements:
# - All logo variants present and consistent across LMS, Studio, and MFE surfaces
# - Favicon assets present on all surfaces
# - Self-hosted fonts present on all surfaces (no Google Fonts)
# - Design tokens (CSS custom properties) defined and reachable
# - npm brand package wired correctly in MFE Dockerfile
# - Token pipeline files present and CI-enforced
# - Footer/header templates are white-label (no "Powered by Open edX")
# - Documentation file present
# - Remaining gap areas surfaced with explicit PASS/SKIP/FAIL status
#
# Usage:
#   scripts/qa/verify-oep48-brand-package.sh
#
# Exits 1 if any FAIL checks are found.
# Remaining SKIP checks represent known OEP-48 gaps documented in OEP48_BRAND_PACKAGE.md.
#
# Related: docs/reference/architecture/OEP48_BRAND_PACKAGE.md
# Tracker: T110

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"

PASS=0
FAIL=0
WARN=0
SKIP=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $*"; }
warn() { WARN=$((WARN + 1)); echo "  WARN: $*"; }
skip() { SKIP=$((SKIP + 1)); echo "  SKIP: $*"; }

echo "========================================================"
echo "OEP-48 Brand Package Verifier (T110)"
echo "Repo: ${REPO_ROOT}"
echo "========================================================"
echo ""

# Paths
ASSETS_BRANDING="${REPO_ROOT}/assets/branding"
THEME_ROOT="${REPO_ROOT}/infrastructure/tutor/themes/mereka"
SCSS_TOKENS="${THEME_ROOT}/scss/_tokens.scss"
SCSS_FONTS="${THEME_ROOT}/scss/_fonts.scss"
SCSS_THEME="${THEME_ROOT}/scss/theme.scss"
MFE_SCSS="${THEME_ROOT}/mfe/mereka.scss"
MFE_IMAGE_DIR="${THEME_ROOT}/mfe/images"
MFE_FONT_DIR="${THEME_ROOT}/mfe/fonts"
LMS_IMAGE_DIR="${THEME_ROOT}/lms/static/images"
LMS_FONT_DIR="${THEME_ROOT}/lms/static/fonts"
LMS_HEAD_EXTRA="${THEME_ROOT}/lms/templates/head-extra.html"
LMS_BRAND_HTML="${THEME_ROOT}/lms/templates/header/brand.html"
LMS_FOOTER="${THEME_ROOT}/lms/templates/footer.html"
CMS_IMAGE_DIR="${THEME_ROOT}/cms/static/images"
CMS_FONT_DIR="${THEME_ROOT}/cms/static/fonts"
CMS_HEAD_EXTRA="${THEME_ROOT}/cms/templates/head-extra.html"
CMS_FOOTER_WIDGET="${THEME_ROOT}/cms/templates/widgets/footer.html"
MFE_RENDERED_DOCKERFILE="${REPO_ROOT}/tutor_env/env/plugins/mfe/build/mfe/Dockerfile"
MFE_PLUGIN_HOOK_MODULE="${REPO_ROOT}/infrastructure/tutor/plugins/_mereka_lms/mfe_dockerfile.py"
MFE_SNAPSHOT_DOCKERFILE="${REPO_ROOT}/infrastructure/tutor/mfe-build/Dockerfile"
MFE_DOCKERFILE=""
MFE_DOCKERFILE_LABEL=""
if [[ -f "${MFE_RENDERED_DOCKERFILE}" ]]; then
  MFE_DOCKERFILE="${MFE_RENDERED_DOCKERFILE}"
  MFE_DOCKERFILE_LABEL="rendered MFE Dockerfile"
elif [[ -f "${MFE_SNAPSHOT_DOCKERFILE}" ]]; then
  MFE_DOCKERFILE="${MFE_SNAPSHOT_DOCKERFILE}"
  MFE_DOCKERFILE_LABEL="snapshot MFE Dockerfile"
fi
PLUGIN_FILE="${PLUGIN_MAIN}"
PROVENANCE="${ASSETS_BRANDING}/tokens.provenance.json"
OEP48_DOC="${REPO_ROOT}/docs/reference/architecture/OEP48_BRAND_PACKAGE.md"
TOKEN_GENERATOR="${REPO_ROOT}/scripts/branding/generate-tokens-from-canonical.sh"

# Logo/favicon sets required on every surface
LOGO_VARIANTS=(
  "logo.png"
  "logo.svg"
  "logo-white.png"
  "logo-white.svg"
  "logo-horizontal.png"
  "logo-square.png"
  "logo-square.svg"
)
FAVICON_VARIANTS=(
  "favicon.ico"
  "favicon-16x16.png"
  "favicon-32x32.png"
  "favicon-256x256.png"
)

# -----------------------------------------------------------------------
# Section 1: Canonical brand asset source (assets/branding/)
# -----------------------------------------------------------------------
echo "[SECTION 1] Canonical brand asset source: assets/branding/"

if [[ -d "${ASSETS_BRANDING}" ]]; then
  pass "assets/branding/ directory exists"
else
  fail "assets/branding/ directory missing — canonical brand source absent"
fi

# Canonical logo variants
for logo in "${LOGO_VARIANTS[@]}"; do
  if [[ -f "${ASSETS_BRANDING}/${logo}" ]]; then
    pass "canonical: ${logo} present"
  else
    fail "canonical: ${logo} MISSING from assets/branding/"
  fi
done

# Canonical favicon variants
for fav in "${FAVICON_VARIANTS[@]}"; do
  if [[ -f "${ASSETS_BRANDING}/${fav}" ]]; then
    pass "canonical: ${fav} present"
  else
    fail "canonical: ${fav} MISSING from assets/branding/"
  fi
done

# tokens.css (canonical color/typography source)
if [[ -f "${ASSETS_BRANDING}/tokens.css" ]]; then
  pass "canonical: tokens.css present"
  # Must contain at least one --color-teal entry (primary brand color)
  if grep -q "\-\-color-teal:" "${ASSETS_BRANDING}/tokens.css"; then
    pass "canonical: tokens.css defines --color-teal"
  else
    fail "canonical: tokens.css missing --color-teal entry"
  fi
  # Must have :root block
  if grep -q "^:root {" "${ASSETS_BRANDING}/tokens.css"; then
    pass "canonical: tokens.css has :root block"
  else
    fail "canonical: tokens.css missing :root block"
  fi
else
  fail "canonical: tokens.css MISSING from assets/branding/"
fi

# Provenance file
if [[ -f "${PROVENANCE}" ]]; then
  pass "canonical: tokens.provenance.json present (upstream sync tracked)"
else
  warn "canonical: tokens.provenance.json missing — upstream sync not tracked"
fi

echo ""

# -----------------------------------------------------------------------
# Section 2: LMS theme — logo, favicon, fonts
# -----------------------------------------------------------------------
echo "[SECTION 2] LMS theme surface: lms/static/{images,fonts}/"

if [[ -d "${LMS_IMAGE_DIR}" ]]; then
  for logo in "${LOGO_VARIANTS[@]}"; do
    if [[ -f "${LMS_IMAGE_DIR}/${logo}" ]]; then
      pass "lms: ${logo} present"
    else
      fail "lms: ${logo} MISSING from lms/static/images/"
    fi
  done
  for fav in "${FAVICON_VARIANTS[@]}"; do
    if [[ -f "${LMS_IMAGE_DIR}/${fav}" ]]; then
      pass "lms: ${fav} present"
    else
      fail "lms: ${fav} MISSING from lms/static/images/"
    fi
  done
else
  fail "lms: image directory missing: ${LMS_IMAGE_DIR}"
fi

if [[ -d "${LMS_FONT_DIR}" ]]; then
  lms_woff2_count=$(ls "${LMS_FONT_DIR}"/*.woff2 2>/dev/null | wc -l | tr -d ' ')
  if [[ "${lms_woff2_count}" -ge 4 ]]; then
    pass "lms: ${lms_woff2_count} .woff2 font files present"
  else
    fail "lms: only ${lms_woff2_count} .woff2 files (need >= 4 for Poppins + Lato)"
  fi
  if ls "${LMS_FONT_DIR}"/Poppins-*.woff2 >/dev/null 2>&1; then
    pass "lms: Poppins font files present"
  else
    fail "lms: Poppins font files missing"
  fi
  if ls "${LMS_FONT_DIR}"/Lato-*.woff2 >/dev/null 2>&1; then
    pass "lms: Lato font files present"
  else
    fail "lms: Lato font files missing"
  fi
else
  fail "lms: font directory missing: ${LMS_FONT_DIR}"
fi

echo ""

# -----------------------------------------------------------------------
# Section 3: Studio (CMS) theme — logo, favicon, fonts
# -----------------------------------------------------------------------
echo "[SECTION 3] Studio (CMS) theme surface: cms/static/{images,fonts}/"

if [[ -d "${CMS_IMAGE_DIR}" ]]; then
  for logo in "${LOGO_VARIANTS[@]}"; do
    if [[ -f "${CMS_IMAGE_DIR}/${logo}" ]]; then
      pass "cms: ${logo} present"
    else
      fail "cms: ${logo} MISSING from cms/static/images/"
    fi
  done
  for fav in "${FAVICON_VARIANTS[@]}"; do
    if [[ -f "${CMS_IMAGE_DIR}/${fav}" ]]; then
      pass "cms: ${fav} present"
    else
      fail "cms: ${fav} MISSING from cms/static/images/"
    fi
  done
else
  fail "cms: image directory missing: ${CMS_IMAGE_DIR}"
fi

if [[ -d "${CMS_FONT_DIR}" ]]; then
  cms_woff2_count=$(ls "${CMS_FONT_DIR}"/*.woff2 2>/dev/null | wc -l | tr -d ' ')
  if [[ "${cms_woff2_count}" -ge 4 ]]; then
    pass "cms: ${cms_woff2_count} .woff2 font files present"
  else
    fail "cms: only ${cms_woff2_count} .woff2 files (need >= 4)"
  fi
  if ls "${CMS_FONT_DIR}"/Poppins-*.woff2 >/dev/null 2>&1; then
    pass "cms: Poppins font files present"
  else
    fail "cms: Poppins font files missing"
  fi
  if ls "${CMS_FONT_DIR}"/Lato-*.woff2 >/dev/null 2>&1; then
    pass "cms: Lato font files present"
  else
    fail "cms: Lato font files missing"
  fi
else
  fail "cms: font directory missing: ${CMS_FONT_DIR}"
fi

echo ""

# -----------------------------------------------------------------------
# Section 4: MFE theme surface — logo, favicon, fonts, SCSS
# -----------------------------------------------------------------------
echo "[SECTION 4] MFE theme surface: mfe/{images,fonts,mereka.scss}"

if [[ -d "${MFE_IMAGE_DIR}" ]]; then
  for logo in "${LOGO_VARIANTS[@]}"; do
    if [[ -f "${MFE_IMAGE_DIR}/${logo}" ]]; then
      pass "mfe: ${logo} present"
    else
      fail "mfe: ${logo} MISSING from mfe/images/"
    fi
  done
  for fav in "${FAVICON_VARIANTS[@]}"; do
    if [[ -f "${MFE_IMAGE_DIR}/${fav}" ]]; then
      pass "mfe: ${fav} present"
    else
      fail "mfe: ${fav} MISSING from mfe/images/"
    fi
  done
else
  fail "mfe: image directory missing: ${MFE_IMAGE_DIR}"
fi

if [[ -d "${MFE_FONT_DIR}" ]]; then
  mfe_woff2_count=$(ls "${MFE_FONT_DIR}"/*.woff2 2>/dev/null | wc -l | tr -d ' ')
  if [[ "${mfe_woff2_count}" -ge 4 ]]; then
    pass "mfe: ${mfe_woff2_count} .woff2 font files present"
  else
    fail "mfe: only ${mfe_woff2_count} .woff2 files (need >= 4)"
  fi
  if ls "${MFE_FONT_DIR}"/Poppins-*.woff2 >/dev/null 2>&1; then
    pass "mfe: Poppins font files present"
  else
    fail "mfe: Poppins font files missing"
  fi
  if ls "${MFE_FONT_DIR}"/Lato-*.woff2 >/dev/null 2>&1; then
    pass "mfe: Lato font files present"
  else
    fail "mfe: Lato font files missing"
  fi
else
  fail "mfe: font directory missing: ${MFE_FONT_DIR}"
fi

# mereka.scss
if [[ -f "${MFE_SCSS}" ]]; then
  pass "mfe: mereka.scss exists"
  if grep -q "@import.*scss/theme\|@import.*theme" "${MFE_SCSS}" \
    || { grep -q '@import "./scss/fonts";' "${MFE_SCSS}" \
      && grep -q '@import "./scss/tokens";' "${MFE_SCSS}" \
      && grep -q '@import "./scss/base";' "${MFE_SCSS}"; }; then
    pass "mfe: mereka.scss imports shared SCSS token stack"
  else
    fail "mfe: mereka.scss does not import shared SCSS token stack"
  fi
  if grep -q "\$mereka-font-path:" "${MFE_SCSS}"; then
    pass "mfe: mereka.scss overrides \$mereka-font-path"
  else
    warn "mfe: mereka.scss missing \$mereka-font-path override — MFE fonts may 404"
  fi
  if grep -q "\-\-mereka-mfe-branding-rev:" "${MFE_SCSS}"; then
    pass "mfe: mereka.scss has --mereka-mfe-branding-rev marker"
  else
    warn "mfe: mereka.scss missing --mereka-mfe-branding-rev revision marker"
  fi
  if grep -q "\-\-mereka-mfe-gradient:" "${MFE_SCSS}" \
    || grep -q "\-\-mereka-mfe-gradient:" "${THEME_ROOT}/mfe/scss/_mfe-tokens.scss"; then
    pass "mfe: theme stack defines --mereka-mfe-gradient token"
  else
    fail "mfe: mereka.scss missing --mereka-mfe-gradient"
  fi
else
  fail "mfe: mereka.scss MISSING: ${MFE_SCSS}"
fi

echo ""

# -----------------------------------------------------------------------
# Section 5: SCSS token stack completeness
# -----------------------------------------------------------------------
echo "[SECTION 5] SCSS token stack: scss/_tokens.scss, _fonts.scss, theme.scss"

if [[ -f "${SCSS_TOKENS}" ]]; then
  pass "scss: _tokens.scss exists"
  # Primary brand colors
  for var in "\$color-teal" "\$color-magenta" "\$color-blue" "\$mereka-body-font" "\$mereka-heading-font"; do
    if grep -q "${var}:" "${SCSS_TOKENS}"; then
      pass "scss: _tokens.scss defines ${var}"
    else
      fail "scss: _tokens.scss missing ${var}"
    fi
  done
  # Required CSS custom properties
  for token in "--mereka-font-body" "--mereka-font-heading" "--mereka-color-teal" "--mereka-color-magenta" "--mereka-color-blue" "--mereka-color-ink-900" "--mereka-shadow-card"; do
    if grep -qF -- "${token}" "${SCSS_TOKENS}"; then
      pass "scss: _tokens.scss defines CSS prop ${token}"
    else
      fail "scss: _tokens.scss missing CSS prop ${token}"
    fi
  done
  # Paragon bridge tokens
  for pgn in "--pgn-color-primary-base" "--pgn-color-secondary-base" "--pgn-typography-font-family-sans-serif"; do
    if grep -qF -- "${pgn}" "${SCSS_TOKENS}"; then
      pass "scss: _tokens.scss bridges ${pgn} to Paragon"
    else
      fail "scss: _tokens.scss missing Paragon bridge token ${pgn}"
    fi
  done
  # Generated block markers
  if grep -q "BEGIN GENERATED" "${SCSS_TOKENS}" && grep -q "END GENERATED" "${SCSS_TOKENS}"; then
    pass "scss: _tokens.scss has BEGIN/END GENERATED markers (generator-safe)"
  else
    fail "scss: _tokens.scss missing BEGIN/END GENERATED markers — generator will overwrite preserved sections"
  fi
else
  fail "scss: _tokens.scss MISSING: ${SCSS_TOKENS}"
fi

if [[ -f "${SCSS_FONTS}" ]]; then
  pass "scss: _fonts.scss exists"
  if grep -q "Poppins\|poppins" "${SCSS_FONTS}"; then
    pass "scss: _fonts.scss declares Poppins font"
  else
    fail "scss: _fonts.scss missing Poppins font declaration"
  fi
  if grep -q "Lato\|lato" "${SCSS_FONTS}"; then
    pass "scss: _fonts.scss declares Lato font"
  else
    fail "scss: _fonts.scss missing Lato font declaration"
  fi
  if grep -qi "fonts.googleapis.com\|fonts.gstatic.com" "${SCSS_FONTS}"; then
    fail "scss: _fonts.scss references Google Fonts — privacy violation"
  else
    pass "scss: _fonts.scss has no Google Fonts references (self-hosted only)"
  fi
else
  fail "scss: _fonts.scss MISSING: ${SCSS_FONTS}"
fi

if [[ -f "${SCSS_THEME}" ]]; then
  pass "scss: theme.scss exists"
  if grep -q "@import.*fonts\|@import.*_fonts" "${SCSS_THEME}"; then
    pass "scss: theme.scss imports _fonts"
  else
    fail "scss: theme.scss does not import _fonts partial"
  fi
  if grep -q "@import.*tokens\|@import.*_tokens" "${SCSS_THEME}"; then
    pass "scss: theme.scss imports _tokens"
  else
    fail "scss: theme.scss does not import _tokens partial"
  fi
else
  fail "scss: theme.scss MISSING: ${SCSS_THEME}"
fi

echo ""

# -----------------------------------------------------------------------
# Section 6: Design token pipeline
# -----------------------------------------------------------------------
echo "[SECTION 6] Design token pipeline"

if [[ -f "${TOKEN_GENERATOR}" ]]; then
  pass "token pipeline: generate-tokens-from-canonical.sh exists"
  if [[ -x "${TOKEN_GENERATOR}" ]]; then
    pass "token pipeline: generate-tokens-from-canonical.sh is executable"
  else
    fail "token pipeline: generate-tokens-from-canonical.sh is not executable"
  fi
  if grep -q "\-\-check" "${TOKEN_GENERATOR}"; then
    pass "token pipeline: --check mode present (CI can verify sync without modifying files)"
  else
    warn "token pipeline: --check mode not found in generate-tokens-from-canonical.sh"
  fi
else
  fail "token pipeline: generate-tokens-from-canonical.sh MISSING"
fi

# Verify common/mereka-design-tokens.css (verbatim copy of tokens.css)
DESIGN_TOKENS_CSS="${THEME_ROOT}/common/static/css/mereka-design-tokens.css"
if [[ -f "${DESIGN_TOKENS_CSS}" ]]; then
  pass "token pipeline: common/mereka-design-tokens.css exists (verbatim copy output)"
  if grep -q "\-\-color-teal:" "${DESIGN_TOKENS_CSS}"; then
    pass "token pipeline: mereka-design-tokens.css contains --color-teal"
  else
    fail "token pipeline: mereka-design-tokens.css missing --color-teal (may be out of sync)"
  fi
else
  fail "token pipeline: common/mereka-design-tokens.css MISSING"
fi

# Verify common/mereka-overrides.css has generated block
COMMON_OVERRIDES="${THEME_ROOT}/common/static/css/mereka-overrides.css"
if [[ -f "${COMMON_OVERRIDES}" ]]; then
  pass "token pipeline: common/mereka-overrides.css exists"
  if grep -q "BEGIN GENERATED\|END GENERATED" "${COMMON_OVERRIDES}"; then
    pass "token pipeline: common/mereka-overrides.css has generated block markers"
  else
    warn "token pipeline: common/mereka-overrides.css missing generated block markers"
  fi
else
  fail "token pipeline: common/mereka-overrides.css MISSING"
fi

# Verify no Google Fonts in any theme file
GF_HITS=$(grep -rli "fonts.googleapis.com\|fonts.gstatic.com" "${THEME_ROOT}" 2>/dev/null || true)
if [[ -z "${GF_HITS}" ]]; then
  pass "no Google Fonts references in theme directory (self-hosted fonts only)"
else
  fail "Google Fonts reference found — privacy violation:"
  echo "${GF_HITS}" | sed 's/^/    /'
fi

echo ""

# -----------------------------------------------------------------------
# Section 7: MFE brand package wiring (npm / Dockerfile)
# -----------------------------------------------------------------------
echo "[SECTION 7] MFE brand package wiring"

if [[ -f "${MFE_DOCKERFILE}" ]]; then
  if [[ "${MFE_DOCKERFILE}" == "${MFE_RENDERED_DOCKERFILE}" ]]; then
    pass "rendered MFE Dockerfile exists"
  else
    warn "rendered MFE Dockerfile missing — verifying tracked snapshot Dockerfile instead"
  fi

  if [[ -f "${MFE_RENDERED_DOCKERFILE}" && -f "${MFE_SNAPSHOT_DOCKERFILE}" ]]; then
    if cmp -s "${MFE_RENDERED_DOCKERFILE}" "${MFE_SNAPSHOT_DOCKERFILE}"; then
      pass "rendered MFE Dockerfile matches tracked snapshot"
    else
      fail "rendered MFE Dockerfile diverges from tracked snapshot"
      diff -u "${MFE_SNAPSHOT_DOCKERFILE}" "${MFE_RENDERED_DOCKERFILE}" | sed -n '1,40p' | sed 's/^/    /' || true
    fi
  fi

  # Brand package must be installed via the local @edx/brand alias on the active path.
  if grep -q "@edx/brand@file:./brand-mereka" "${MFE_DOCKERFILE}"; then
    pass "${MFE_DOCKERFILE_LABEL} installs local @edx/brand alias (brand-mereka)"
  else
    fail "${MFE_DOCKERFILE_LABEL} missing local @edx/brand alias — active MFE brand package not wired"
  fi
  if grep -q "indigo-brand-openedx" "${MFE_DOCKERFILE}"; then
    fail "${MFE_DOCKERFILE_LABEL} still references legacy indigo-brand-openedx package"
  else
    pass "${MFE_DOCKERFILE_LABEL} has no legacy indigo-brand-openedx package reference"
  fi
  # The Mereka SCSS directory must be copied into the container
  if grep -q "COPY.*mereka/theme-source" "${MFE_DOCKERFILE}"; then
    pass "${MFE_DOCKERFILE_LABEL} copies Mereka SCSS directory into MFE container"
  else
    warn "${MFE_DOCKERFILE_LABEL} may not copy mereka/ SCSS dir into container — MFE branding may be missing"
  fi
  # No Google Fonts in Dockerfile
  if grep -qi "fonts.googleapis.com\|fonts.gstatic.com" "${MFE_DOCKERFILE}"; then
    fail "${MFE_DOCKERFILE_LABEL} references Google Fonts — must use self-hosted fonts"
  else
    pass "${MFE_DOCKERFILE_LABEL} has no Google Fonts references"
  fi

  if [[ -f "${MFE_PLUGIN_HOOK_MODULE}" ]]; then
    if grep -q "@edx/brand@file:./brand-mereka" "${MFE_PLUGIN_HOOK_MODULE}"; then
      pass "plugin hook module stages local @edx/brand alias into the rendered Dockerfile"
    else
      fail "plugin hook module missing local @edx/brand alias wiring"
    fi
  else
    fail "plugin hook module missing: ${MFE_PLUGIN_HOOK_MODULE}"
  fi
else
  warn "No rendered or snapshot MFE Dockerfile surface found — cannot verify MFE brand wiring"
fi

echo ""

# -----------------------------------------------------------------------
# Section 8: Header and footer templates (white-label)
# -----------------------------------------------------------------------
echo "[SECTION 8] Header/footer templates: white-label compliance"

# LMS header brand.html
if [[ -f "${LMS_BRAND_HTML}" ]]; then
  pass "lms: header/brand.html exists"
  if grep -q "logo.png\|logo-image\|mereka-navbar-brand" "${LMS_BRAND_HTML}"; then
    pass "lms: brand.html references Mereka logo"
  else
    fail "lms: brand.html has no Mereka logo reference"
  fi
  # Check for visible Open edX branding (excluding Python import lines)
  OPEN_EDX_VISIBLE=$(grep -v "^## \|from openedx\.\|import openedx\." "${LMS_BRAND_HTML}" | grep -i "open edx\|openedx" || true)
  if [[ -z "${OPEN_EDX_VISIBLE}" ]]; then
    pass "lms: brand.html has no visible Open edX branding (Python imports are expected)"
  else
    fail "lms: brand.html contains visible Open edX branding — must be white-label"
  fi
  if grep -q "branding_api\|get_home_url" "${LMS_BRAND_HTML}"; then
    pass "lms: brand.html uses branding_api (not hardcoded URL)"
  else
    warn "lms: brand.html may have hardcoded home URL — prefer branding_api.get_home_url()"
  fi
else
  fail "lms: header/brand.html MISSING: ${LMS_BRAND_HTML}"
fi

# LMS head-extra.html
if [[ -f "${LMS_HEAD_EXTRA}" ]]; then
  pass "lms: head-extra.html exists"
  if grep -q "mereka-overrides.css" "${LMS_HEAD_EXTRA}"; then
    pass "lms: head-extra.html loads mereka-overrides.css"
  else
    fail "lms: head-extra.html does not load mereka-overrides.css"
  fi
  # Font preload may be split across multiple lines (rel="preload" on one line, as="font" on another)
  if grep -q "rel=\"preload\"\|rel='preload'" "${LMS_HEAD_EXTRA}" && grep -q "as=\"font\"\|as='font'" "${LMS_HEAD_EXTRA}"; then
    pass "lms: head-extra.html preloads brand fonts"
  else
    warn "lms: head-extra.html does not preload fonts (performance impact)"
  fi
else
  fail "lms: head-extra.html MISSING: ${LMS_HEAD_EXTRA}"
fi

# LMS footer
if [[ -f "${LMS_FOOTER}" ]]; then
  pass "lms: footer.html exists"
  if grep -qi "mereka-footer\|mereka" "${LMS_FOOTER}"; then
    pass "lms: footer.html contains Mereka branding"
  else
    fail "lms: footer.html has no Mereka branding"
  fi
  if grep -qE "datetime\.now\(\)\.year|%Y" "${LMS_FOOTER}"; then
    pass "lms: footer.html has dynamic copyright year"
  else
    fail "lms: footer.html missing dynamic copyright year"
  fi
  POWERED_BY=$(grep -i "powered by open edx" "${LMS_FOOTER}" | grep -v '^\s*##' || true)
  if [[ -z "${POWERED_BY}" ]]; then
    pass "lms: footer.html has no 'Powered by Open edX' (white-label clean)"
  else
    fail "lms: footer.html contains 'Powered by Open edX' — remove for white-label"
  fi
else
  fail "lms: footer.html MISSING: ${LMS_FOOTER}"
fi

# Studio head-extra.html
if [[ -f "${CMS_HEAD_EXTRA}" ]]; then
  pass "cms: head-extra.html exists"
  if grep -q "mereka-overrides.css" "${CMS_HEAD_EXTRA}"; then
    pass "cms: head-extra.html loads mereka-overrides.css"
  else
    fail "cms: head-extra.html does not load mereka-overrides.css"
  fi
else
  fail "cms: head-extra.html MISSING: ${CMS_HEAD_EXTRA}"
fi

# Studio footer widget
if [[ -f "${CMS_FOOTER_WIDGET}" ]]; then
  pass "cms: widgets/footer.html exists"
  if grep -qi "powered by open edx\|footer-about-openedx\|open-edx-logo-tag" "${CMS_FOOTER_WIDGET}"; then
    fail "cms: footer widget has 'Powered by Open edX' — must be removed for white-label Studio"
  else
    pass "cms: footer widget has no 'Powered by Open edX' (white-label)"
  fi
  if grep -qE "datetime\.now\(\)\.year|%Y|\{year\}" "${CMS_FOOTER_WIDGET}"; then
    pass "cms: footer widget has dynamic copyright year"
  else
    fail "cms: footer widget missing dynamic copyright year"
  fi
else
  fail "cms: widgets/footer.html MISSING: ${CMS_FOOTER_WIDGET}"
fi

echo ""

# -----------------------------------------------------------------------
# Section 9: Cross-surface consistency (same files on all three surfaces)
# -----------------------------------------------------------------------
echo "[SECTION 9] Cross-surface asset consistency"

SURFACES=(
  "lms:${LMS_IMAGE_DIR}"
  "cms:${CMS_IMAGE_DIR}"
  "mfe:${MFE_IMAGE_DIR}"
)

CANONICAL_ASSETS=("logo.png" "logo.svg" "logo-white.png" "favicon.ico" "favicon-32x32.png")

for asset in "${CANONICAL_ASSETS[@]}"; do
  missing_on=()
  for entry in "${SURFACES[@]}"; do
    surface="${entry%%:*}"
    img_dir="${entry#*:}"
    if [[ ! -f "${img_dir}/${asset}" ]]; then
      missing_on+=("${surface}")
    fi
  done
  if [[ "${#missing_on[@]}" -eq 0 ]]; then
    pass "cross-surface: '${asset}' present on all surfaces (lms, cms, mfe)"
  elif [[ "${#missing_on[@]}" -lt "${#SURFACES[@]}" ]]; then
    fail "cross-surface: '${asset}' missing on: ${missing_on[*]}"
  else
    fail "cross-surface: '${asset}' missing on ALL surfaces"
  fi
done

echo ""

# -----------------------------------------------------------------------
# Section 10: OEP-48 gap status (closed vs remaining)
# -----------------------------------------------------------------------
echo "[SECTION 10] OEP-48 gap status (closed vs remaining)"

BRAND_PACKAGE_DIR="${REPO_ROOT}/infrastructure/tutor/brand-mereka"
if [[ -f "${BRAND_PACKAGE_DIR}/package.json" ]]; then
  pass "GAP-1 closed: standalone brand package exists at infrastructure/tutor/brand-mereka/package.json"
else
  fail "GAP-1 open: standalone brand package missing at infrastructure/tutor/brand-mereka/package.json"
fi

if [[ -f "${BRAND_PACKAGE_DIR}/logo.js" ]]; then
  pass "GAP-2 closed: logo.js / ESM exports present for @edx/brand imports"
else
  skip "GAP-2 open: logo.js / ESM exports for @edx/brand React imports are not implemented"
fi

if grep -q "^scripts/qa/verify-branding-asset-sync.sh$" "${REPO_ROOT}/.github/ci-scripts-static.txt"; then
  pass "GAP-3 closed: branding asset sync verifier is wired into static CI"
else
  fail "GAP-3 open: scripts/qa/verify-branding-asset-sync.sh missing from .github/ci-scripts-static.txt"
fi

if [[ -f "${BRAND_PACKAGE_DIR}/logo_white.png" ]]; then
  pass "GAP-4 closed: OEP-48 underscore logo_white.png alias exists"
else
  skip "GAP-4 open: logo_white.png alias not present (hyphenated logo-white.png is in use)"
fi

HEADER_SLOT_OK=1
if ! rg -q 'org\.openedx\.frontend\.layout\.header_logo\.v1' "$PLUGIN_FILE"; then
  HEADER_SLOT_OK=0
fi
if ! rg -q 'RenderWidget:[[:space:]]*MerekaHeaderLogo' "$PLUGIN_FILE"; then
  HEADER_SLOT_OK=0
fi
if ! rg -q 'const[[:space:]]+MerekaHeaderLogo[[:space:]]*=[[:space:]]*\(\)[[:space:]]*=>' "$PLUGIN_FILE"; then
  HEADER_SLOT_OK=0
fi

if [[ "$HEADER_SLOT_OK" -eq 1 ]]; then
  pass "GAP-5 closed: header_logo plugin-slot wiring + MerekaHeaderLogo component are present"
else
  skip "GAP-5 open: header_logo slot wiring or MerekaHeaderLogo component definition is incomplete"
fi

echo ""

# -----------------------------------------------------------------------
# Section 11: Documentation present
# -----------------------------------------------------------------------
echo "[SECTION 11] OEP-48 documentation"

if [[ -f "${OEP48_DOC}" ]]; then
  pass "docs/reference/architecture/OEP48_BRAND_PACKAGE.md exists"
  if grep -q "Gap Analysis\|GAP-" "${OEP48_DOC}"; then
    pass "OEP48_BRAND_PACKAGE.md contains gap analysis section"
  else
    warn "OEP48_BRAND_PACKAGE.md missing gap analysis section"
  fi
else
  fail "docs/reference/architecture/OEP48_BRAND_PACKAGE.md MISSING"
fi

echo ""

# -----------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------
echo "========================================================"
echo "OEP-48 Brand Package: PASS=${PASS} FAIL=${FAIL} WARN=${WARN} SKIP=${SKIP}"
echo "========================================================"
echo ""
if [[ "${SKIP}" -gt 0 ]]; then
  echo "Remaining SKIP items are documented OEP-48 gaps (not blocking failures)."
  echo "See: docs/reference/architecture/OEP48_BRAND_PACKAGE.md — Gap Analysis section."
else
  echo "No remaining OEP-48 gap SKIPs in this verifier."
fi
echo ""

if [[ "${FAIL}" -gt 0 ]]; then
  echo "RESULT: FAIL (${FAIL} failure(s))" >&2
  exit 1
fi

echo "RESULT: PASS"
exit 0
