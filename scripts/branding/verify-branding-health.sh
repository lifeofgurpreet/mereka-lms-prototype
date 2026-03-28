#!/usr/bin/env bash
# @covers AC-002, AC-004, AC-005, AC-006, AC-007, AC-009
# @spec: branding-system_spec.md
# Verify end-to-end Mereka branding assets + wiring before builds/deploys.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

failures=0

check_file() {
  local label="$1"
  local path="$2"
  if [[ -f "$path" ]]; then
    echo "  ✓ $label"
  else
    echo "  ✗ $label (missing: $path)"
    failures=1
  fi
}

check_contains() {
  local label="$1"
  local path="$2"
  local needle="$3"
  if [[ ! -f "$path" ]]; then
    echo "  ✗ $label (missing file: $path)"
    failures=1
    return
  fi
  if grep -q -- "$needle" "$path"; then
    echo "  ✓ $label"
  else
    echo "  ✗ $label (missing: $needle)"
    failures=1
  fi
}

check_contains_any() {
  local label="$1"
  local path="$2"
  shift 2

  if [[ ! -f "$path" ]]; then
    echo "  ✗ $label (missing file: $path)"
    failures=1
    return
  fi

  for needle in "$@"; do
    if grep -q -- "$needle" "$path"; then
      echo "  ✓ $label"
      return
    fi
  done

  echo "  ✗ $label (missing all candidates: $*)"
  failures=1
}

check_mfe_token_stack_imports() {
  local label="$1"
  local path="$2"

  if [[ ! -f "$path" ]]; then
    echo "  ✗ $label (missing file: $path)"
    failures=1
    return
  fi

  if grep -q -- '@import "./scss/theme";' "$path"; then
    echo "  ✓ $label (legacy theme import)"
    return
  fi

  if grep -q -- '@import "./scss/fonts";' "$path" \
    && grep -q -- '@import "./scss/tokens";' "$path" \
    && grep -q -- '@import "./scss/base";' "$path"; then
    echo "  ✓ $label (split fonts/tokens/base imports)"
    return
  fi

  echo "  ✗ $label (missing legacy theme import or split shared stack imports)"
  failures=1
}

check_selector_absent_noncomment() {
  local label="$1"
  local path="$2"
  local needle="$3"

  if [[ ! -f "$path" ]]; then
    echo "  ✗ $label (missing file: $path)"
    failures=1
    return
  fi

  if python3 - "$path" "$needle" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
needle = sys.argv[2]

for line in path.read_text(encoding="utf-8").splitlines():
    stripped = line.strip()
    if not stripped or stripped.startswith("//") or stripped.startswith("/*") or stripped.startswith("*"):
        continue
    if needle in line:
        raise SystemExit(1)
raise SystemExit(0)
PY
  then
    echo "  ✓ $label"
  else
    echo "  ✗ $label (found forbidden selector pattern: $needle)"
    failures=1
  fi
}

echo "Verifying Mereka branding health..."
echo ""

echo "1. Logo + template checks..."
if [[ -x "$REPO_ROOT/scripts/branding/verify-logo-setup.sh" ]]; then
  if ! "$REPO_ROOT/scripts/branding/verify-logo-setup.sh"; then
    failures=1
  fi
else
  echo "  ✗ verify-logo-setup.sh missing or not executable"
  failures=1
fi

echo ""
echo "2. Font assets..."
FONT_DIR="$REPO_ROOT/assets/branding/fonts"
THEME_FONT_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/fonts"
LMS_FONT_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/fonts"
CMS_FONT_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/fonts"
MFE_FONT_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/fonts"
required_fonts=(
  "Poppins-Regular.woff2"
  "Poppins-SemiBold.woff2"
  "Poppins-Bold.woff2"
  "Lato-Regular.woff2"
  "Lato-Italic.woff2"
  "Lato-Bold.woff2"
  "Lato-BoldItalic.woff2"
  "Lato-Black.woff2"
  "Lato-BlackItalic.woff2"
)
for font in "${required_fonts[@]}"; do
  check_file "Source font $font" "$FONT_DIR/$font"
  check_file "Theme font $font" "$THEME_FONT_DIR/$font"
  check_file "LMS font $font" "$LMS_FONT_DIR/$font"
  check_file "CMS font $font" "$CMS_FONT_DIR/$font"
  check_file "MFE font $font" "$MFE_FONT_DIR/$font"
done

echo ""
echo "3. Core SCSS wiring..."
THEME_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/scss/theme.scss"
TOKENS_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/scss/_tokens.scss"
FONTS_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/scss/_fonts.scss"
MFE_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss"
LMS_THEME_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/sass/theme.scss"
LMS_MAIN_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/sass/lms-main-v1.scss"
LMS_DISCOVERY_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/sass/partials/_discovery.scss"
LMS_DISCOVERY_TEMPLATE="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates/discovery/course_card.underscore"
LMS_CUSTOM_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/sass/partials/_custom.scss"
LMS_HOMEPAGE_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/sass/partials/_homepage.scss"
LMS_INDEX_OVERLAY="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates/index_overlay.html"
CMS_THEME_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/sass/theme.scss"
CMS_HEAD_EXTRA_TEMPLATE="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/templates/head-extra.html"
CMS_OVERRIDE_CSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/css/mereka-overrides.css"
CADDYFILE="$REPO_ROOT/deploy/k8s/base/apps/caddy/Caddyfile"

check_file "Shared tokens" "$TOKENS_SCSS"
check_file "Shared fonts" "$FONTS_SCSS"
check_contains "Theme imports fonts" "$THEME_SCSS" '@import "fonts";'
check_contains "Theme imports tokens" "$THEME_SCSS" '@import "tokens";'
check_contains "LMS theme imports shared tokens" "$LMS_THEME_SCSS" '@import "../../../scss/theme";'
check_contains "LMS main imports discovery partial" "$LMS_MAIN_SCSS" "@import 'partials/discovery';"
check_file "LMS discovery partial" "$LMS_DISCOVERY_SCSS"
check_contains "LMS discovery partial styles discovery route" "$LMS_DISCOVERY_SCSS" '.find-courses'
check_contains "LMS discovery partial styles course-about route" "$LMS_DISCOVERY_SCSS" '.course-about'
check_contains "Discovery card template keeps CTA inside cover image" "$LMS_DISCOVERY_TEMPLATE" '<div class="cover-image">'
check_contains "Discovery card template renders View Course inside cover image" "$LMS_DISCOVERY_TEMPLATE" 'class="learn-more"'
check_file "LMS homepage shell partial" "$LMS_HOMEPAGE_SCSS"
check_contains "LMS custom SCSS imports homepage shell partial" "$LMS_CUSTOM_SCSS" '@import "homepage";'
check_contains "Homepage overlay exposes spotlight shell" "$LMS_INDEX_OVERLAY" 'mereka-hero__spotlight'
check_contains "Homepage overlay exposes signal chips" "$LMS_INDEX_OVERLAY" 'mereka-hero__signal'
check_contains "Homepage overlay exposes primary CTA cluster" "$LMS_INDEX_OVERLAY" 'hero-actions'
check_contains "Homepage shell styles spotlight panel" "$LMS_HOMEPAGE_SCSS" '.mereka-hero__spotlight'
check_contains "Homepage shell styles signal chips" "$LMS_HOMEPAGE_SCSS" '.mereka-hero__signal'
check_contains "Homepage shell styles public course cards" "$LMS_HOMEPAGE_SCSS" '.course::before'
check_selector_absent_noncomment "Shared theme avoids LMS homepage shell selectors" "$THEME_SCSS" '.mereka-hero'
check_selector_absent_noncomment "Shared theme avoids LMS homepage metrics selectors" "$THEME_SCSS" '.hero-metrics'
check_selector_absent_noncomment "Shared theme avoids LMS logged-out header selectors" "$THEME_SCSS" '.home.style-logout header'
check_contains "CMS theme imports shared tokens" "$CMS_THEME_SCSS" '@import "../../../scss/theme";'
check_file "CMS runtime overrides CSS" "$CMS_OVERRIDE_CSS"
check_contains "CMS head-extra links runtime overrides" "$CMS_HEAD_EXTRA_TEMPLATE" "mereka/css/mereka-overrides.css"
check_contains "MFE theme sets font path" "$MFE_SCSS" '$mereka-font-path'
check_mfe_token_stack_imports "MFE theme imports shared token stack" "$MFE_SCSS"
check_contains "MFE theme exports branding revision marker" "$MFE_SCSS" '--mereka-mfe-branding-rev'
check_contains "MFE theme styles Paragon card" "$MFE_SCSS" '.pgn__card'
check_contains_any "MFE theme styles alert surface" "$MFE_SCSS" '.pgn__alert' '.alert'
check_contains_any "MFE theme styles modal surface" "$MFE_SCSS" '.pgn__modal-content' '.modal-content'
check_contains "MFE theme styles authn slot component" "$MFE_SCSS" '.mereka-authn-login-branding'
check_selector_absent_noncomment "MFE authn wildcard selectors removed" "$MFE_SCSS" '[class*="authn"]'
check_contains "MFE theme targets account/settings surfaces" "$MFE_SCSS" 'account-settings'
check_selector_absent_noncomment "MFE learner-dashboard wildcard selectors removed" "$MFE_SCSS" '[class*="learner-dashboard"]'
check_selector_absent_noncomment "MFE learning wildcard selectors removed" "$MFE_SCSS" '[class*="learning"]'
check_selector_absent_noncomment "MFE discussions wildcard selectors removed" "$MFE_SCSS" '[class*="discussions"]'
# Ecommerce removed (ADR-018, Oscar deprecated → Purchase Gateway)
# Forum v2 runs in-process (no separate Caddy block) - skip forum landing check

echo ""
echo "3.25 Token drift (design system)..."
if [[ -x "$REPO_ROOT/scripts/branding/verify-token-drift.sh" ]]; then
  if ! "$REPO_ROOT/scripts/branding/verify-token-drift.sh"; then
    failures=1
  fi
else
  echo "  ✗ verify-token-drift.sh missing or not executable"
  failures=1
fi

echo ""
echo "3.5 Runtime override CSS..."
if [[ -x "$REPO_ROOT/scripts/branding/verify-branding-css.sh" ]]; then
  if ! "$REPO_ROOT/scripts/branding/verify-branding-css.sh"; then
    failures=1
  fi
else
  echo "  ✗ verify-branding-css.sh missing or not executable"
  failures=1
fi

echo ""
echo "4. Required branding assets..."
check_file "Canonical logo.png" "$REPO_ROOT/assets/branding/logo.png"
check_file "Canonical favicon.ico" "$REPO_ROOT/assets/branding/favicon.ico"
check_file "Canonical favicon.svg" "$REPO_ROOT/assets/branding/favicon.svg"
check_file "Favicon 16x16" "$REPO_ROOT/assets/branding/favicon-16x16.png"
check_file "Favicon 32x32" "$REPO_ROOT/assets/branding/favicon-32x32.png"
check_file "Favicon 256x256" "$REPO_ROOT/assets/branding/favicon-256x256.png"
check_file "Design tokens (tokens.css)" "$REPO_ROOT/assets/branding/tokens.css"
check_file "Theme design tokens copy" "$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/css/mereka-design-tokens.css"
check_file "LMS logo.png" "$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/images/logo.png"

echo ""
if [[ $failures -eq 0 ]]; then
  echo "✓ Branding health check passed."
  exit 0
fi

echo "✗ Branding health check failed."
echo ""
echo "Fixes:"
echo "  1. Run: ./scripts/branding/sync-brand-assets.sh"
echo "  2. Re-run: ./scripts/branding/verify-branding-health.sh"
exit 1
