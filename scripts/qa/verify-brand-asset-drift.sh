#!/usr/bin/env bash
# @covers AC-007
# @spec: branding-system_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

PASS=0
FAIL=0

pass() {
  echo "PASS $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "FAIL $1"
  FAIL=$((FAIL + 1))
}

compare_file() {
  local source="$1"
  local target="$2"
  local label="$3"

  if [[ ! -f "$source" ]]; then
    fail "$label source missing ($source)"
    return
  fi
  if [[ ! -f "$target" ]]; then
    fail "$label target missing ($target)"
    return
  fi

  if cmp -s "$source" "$target"; then
    pass "$label"
  else
    fail "$label drift detected"
  fi
}

FONTS=(
  Poppins-Regular.woff2
  Poppins-SemiBold.woff2
  Poppins-Bold.woff2
  Lato-Regular.woff2
  Lato-Bold.woff2
  Lato-Italic.woff2
  Lato-BoldItalic.woff2
  Lato-Black.woff2
  Lato-BlackItalic.woff2
)

BRAND_ASSETS=(
  logo.png
  logo.svg
  logo-white.png
  logo-white.svg
  favicon.ico
)

brand_source_dir() {
  local brand="$1"
  if [[ "$brand" == "mereka" ]]; then
    echo "$REPO_ROOT/assets/branding"
  else
    echo "$REPO_ROOT/assets/branding/tenants/$brand"
  fi
}

brand_package_dir() {
  local brand="$1"
  echo "$REPO_ROOT/infrastructure/tutor/brand-$brand"
}

discover_brand_slugs() {
  find "$REPO_ROOT/infrastructure/tutor" -mindepth 1 -maxdepth 1 -type d -name 'brand-*' -printf '%f\n' \
    | sed 's/^brand-//' \
    | sort
}

echo "=== Brand Asset Drift Verification ==="

echo
echo "[1/2] Verifying brand package drift"
mapfile -t BRAND_SLUGS < <(discover_brand_slugs)
if [[ ${#BRAND_SLUGS[@]} -eq 0 ]]; then
  fail "No brand-* package directories found under infrastructure/tutor"
fi

for brand in "${BRAND_SLUGS[@]}"; do
  source_dir="$(brand_source_dir "$brand")"
  package_dir="$(brand_package_dir "$brand")"

  if [[ ! -d "$source_dir" ]]; then
    fail "brand-$brand source directory missing ($source_dir)"
    continue
  fi
  if [[ ! -d "$package_dir" ]]; then
    fail "brand-$brand package directory missing ($package_dir)"
    continue
  fi

  for asset in "${BRAND_ASSETS[@]}"; do
    compare_file "$source_dir/$asset" "$package_dir/$asset" "brand-$brand $asset"
  done

  compare_file "$source_dir/logo-white.png" "$package_dir/logo_white.png" "brand-$brand logo_white.png alias"
  compare_file "$source_dir/logo-white.svg" "$package_dir/logo_white.svg" "brand-$brand logo_white.svg alias"

  if [[ -f "$source_dir/logo-trademark.png" ]]; then
    compare_file "$source_dir/logo-trademark.png" "$package_dir/logo-trademark.png" "brand-$brand logo-trademark.png"
  else
    compare_file "$source_dir/logo.png" "$package_dir/logo-trademark.png" "brand-$brand logo-trademark.png fallback"
  fi

  if [[ -f "$source_dir/logo-trademark.svg" ]]; then
    compare_file "$source_dir/logo-trademark.svg" "$package_dir/logo-trademark.svg" "brand-$brand logo-trademark.svg"
  else
    compare_file "$source_dir/logo.svg" "$package_dir/logo-trademark.svg" "brand-$brand logo-trademark.svg fallback"
  fi

  if [[ -f "$source_dir/favicon-256x256.png" ]]; then
    compare_file "$source_dir/favicon-256x256.png" "$package_dir/favicon.png" "brand-$brand favicon.png alias"
  else
    compare_file "$source_dir/favicon.ico" "$package_dir/favicon.png" "brand-$brand favicon.png fallback"
  fi

  for font in "${FONTS[@]}"; do
    compare_file "$REPO_ROOT/assets/branding/fonts/$font" "$package_dir/fonts/$font" "brand-$brand font $font"
  done
done

echo
echo "[2/2] Verifying theme drift (Mereka)"
MEREKA_SOURCE="$REPO_ROOT/assets/branding"

THEME_IMAGE_TARGETS=(
  "$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/images"
  "$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/images"
  "$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/images"
  "$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/images"
)

THEME_FONT_TARGETS=(
  "$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/fonts"
  "$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/fonts"
  "$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/fonts"
  "$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/fonts"
)

THEME_IMAGES=(
  logo-horizontal.png
  logo-horizontal.svg
  logo-horizontal-white.png
  logo-horizontal-white.svg
  logo-square.png
  logo-square.svg
  logo-square-white.png
  logo-square-white.svg
  logo.png
  logo.svg
  logo-white.png
  logo-white.svg
  favicon.ico
  favicon.svg
  favicon-16x16.png
  favicon-32x32.png
  favicon-256x256.png
)

for target_dir in "${THEME_IMAGE_TARGETS[@]}"; do
  for asset in "${THEME_IMAGES[@]}"; do
    compare_file "$MEREKA_SOURCE/$asset" "$target_dir/$asset" "theme image ${asset} -> ${target_dir#"$REPO_ROOT/"}"
  done
done

for target_dir in "${THEME_FONT_TARGETS[@]}"; do
  for font in "${FONTS[@]}"; do
    compare_file "$REPO_ROOT/assets/branding/fonts/$font" "$target_dir/$font" "theme font ${font} -> ${target_dir#"$REPO_ROOT/"}"
  done
done

compare_file \
  "$REPO_ROOT/assets/branding/tokens.css" \
  "$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/css/mereka-design-tokens.css" \
  "theme tokens sync"

compare_file \
  "$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css" \
  "$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css" \
  "theme overrides sync (LMS)"

compare_file \
  "$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css" \
  "$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/css/mereka-overrides.css" \
  "theme overrides sync (CMS)"

echo
echo "Summary: PASS=${PASS} FAIL=${FAIL}"
if [[ "$FAIL" -gt 0 ]]; then
  echo "Run ./scripts/branding/sync-brand-assets.sh to remediate drift."
  exit 1
fi
