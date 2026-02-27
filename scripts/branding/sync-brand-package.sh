#!/usr/bin/env bash
# @covers AC-007
# @spec: specs/oep48-brand-package_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

BRAND_PACKAGE_DIR="$REPO_ROOT/infrastructure/tutor/brand-mereka"
ASSET_FONTS_DIR="$REPO_ROOT/assets/branding/fonts"
ASSET_IMG_DIR="$REPO_ROOT/assets/branding"

FONT_FILES=(
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

IMAGE_FILES=(
  logo.png
  logo-white.png
  logo.svg
  logo-white.svg
  favicon.ico
)

if [[ ! -d "$BRAND_PACKAGE_DIR" ]]; then
  echo "Brand package directory not found: $BRAND_PACKAGE_DIR" >&2
  exit 1
fi

if [[ ! -d "$ASSET_FONTS_DIR" ]]; then
  echo "Source font directory not found: $ASSET_FONTS_DIR" >&2
  exit 1
fi

if [[ ! -d "$ASSET_IMG_DIR" ]]; then
  echo "Source image directory not found: $ASSET_IMG_DIR" >&2
  exit 1
fi

mkdir -p "$BRAND_PACKAGE_DIR/fonts"

for font in "${FONT_FILES[@]}"; do
  source="$ASSET_FONTS_DIR/$font"
  if [[ ! -f "$source" ]]; then
    echo "Missing font source: $source" >&2
    exit 1
  fi
done

for image in "${IMAGE_FILES[@]}"; do
  source="$ASSET_IMG_DIR/$image"
  if [[ ! -f "$source" ]]; then
    echo "Missing image source: $source" >&2
    exit 1
  fi
done

rm -f "$BRAND_PACKAGE_DIR/fonts/"*.woff2
cp "$ASSET_FONTS_DIR"/*.woff2 "$BRAND_PACKAGE_DIR/fonts/"

for image in "${IMAGE_FILES[@]}"; do
  cp "$ASSET_IMG_DIR/$image" "$BRAND_PACKAGE_DIR/$image"
done

echo "Synced OEP-48 brand package assets from assets/branding."
