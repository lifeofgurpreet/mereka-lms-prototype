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

# OEP-48 compatibility aliases:
# - logo_white.* (underscore form)
# - favicon.png (png alias for 256x256 favicon)
cp "$ASSET_IMG_DIR/logo-white.png" "$BRAND_PACKAGE_DIR/logo_white.png"
cp "$ASSET_IMG_DIR/logo-white.svg" "$BRAND_PACKAGE_DIR/logo_white.svg"
cp "$ASSET_IMG_DIR/favicon-256x256.png" "$BRAND_PACKAGE_DIR/favicon.png"

# Trademark aliases: preserve dedicated files if they exist in source;
# otherwise keep deterministic fallback to primary logo assets.
if [[ -f "$ASSET_IMG_DIR/logo-trademark.png" ]]; then
  cp "$ASSET_IMG_DIR/logo-trademark.png" "$BRAND_PACKAGE_DIR/logo-trademark.png"
else
  cp "$ASSET_IMG_DIR/logo.png" "$BRAND_PACKAGE_DIR/logo-trademark.png"
fi
if [[ -f "$ASSET_IMG_DIR/logo-trademark.svg" ]]; then
  cp "$ASSET_IMG_DIR/logo-trademark.svg" "$BRAND_PACKAGE_DIR/logo-trademark.svg"
else
  cp "$ASSET_IMG_DIR/logo.svg" "$BRAND_PACKAGE_DIR/logo-trademark.svg"
fi

# Keep @edx/brand JS exports deterministic after every sync.
cat > "$BRAND_PACKAGE_DIR/logo.js" <<'EOF'
export { default as logo } from './logo.png';
export { default as logoWhite } from './logo_white.png';
export { default as logoTrademark } from './logo-trademark.png';
export { default as favicon } from './favicon.png';
export { default } from './logo.png';
EOF

echo "Synced OEP-48 brand package assets from assets/branding."
