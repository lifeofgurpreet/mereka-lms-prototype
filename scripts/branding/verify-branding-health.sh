#!/usr/bin/env bash
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
  if grep -q "$needle" "$path"; then
    echo "  ✓ $label"
  else
    echo "  ✗ $label (missing: $needle)"
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
CMS_THEME_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/sass/theme.scss"

check_file "Shared tokens" "$TOKENS_SCSS"
check_file "Shared fonts" "$FONTS_SCSS"
check_contains "Theme imports fonts" "$THEME_SCSS" '@import "fonts";'
check_contains "Theme imports tokens" "$THEME_SCSS" '@import "tokens";'
check_contains "LMS theme imports shared tokens" "$LMS_THEME_SCSS" '@import "../../../scss/theme";'
check_contains "CMS theme imports shared tokens" "$CMS_THEME_SCSS" '@import "../../../scss/theme";'
check_contains "MFE theme sets font path" "$MFE_SCSS" '$mereka-font-path'
check_contains "MFE theme imports shared tokens" "$MFE_SCSS" '@import "./scss/theme";'
check_contains "MFE theme styles Paragon card" "$MFE_SCSS" '.pgn__card'
check_contains "MFE theme styles Paragon alert" "$MFE_SCSS" '.pgn__alert'
check_contains "MFE theme styles Paragon modal" "$MFE_SCSS" '.pgn__modal-content'
check_contains "MFE theme targets account/settings surfaces" "$MFE_SCSS" 'account-settings'
check_contains "MFE theme targets learner dashboard surfaces" "$MFE_SCSS" 'learner-dashboard'

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
