#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

SRC_FONTS="$REPO_ROOT/assets/branding/fonts"
THEME_FONT_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/fonts"
LMS_FONT_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/fonts"
CMS_FONT_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/fonts"
MFE_FONT_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/fonts"
IMG_SRC_DIR="$REPO_ROOT/assets/branding"
IMG_DEST_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/images"
MFE_IMG_DEST_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/images"
LMS_IMG_DEST_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/images"
CMS_IMG_DEST_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/images"
TOKENS_SRC="$REPO_ROOT/assets/branding/tokens.css"
TOKENS_DEST="$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/css/mereka-design-tokens.css"

if [[ ! -d "$SRC_FONTS" ]]; then
  echo "Missing font source directory: $SRC_FONTS" >&2
  exit 1
fi

mkdir -p "$THEME_FONT_DIR" "$MFE_FONT_DIR" "$IMG_DEST_DIR" "$MFE_IMG_DEST_DIR" "$LMS_IMG_DEST_DIR" "$CMS_IMG_DEST_DIR"
cp "$SRC_FONTS"/*.woff2 "$THEME_FONT_DIR"/
mkdir -p "$LMS_FONT_DIR" "$CMS_FONT_DIR"
cp "$SRC_FONTS"/*.woff2 "$LMS_FONT_DIR"/
cp "$SRC_FONTS"/*.woff2 "$CMS_FONT_DIR"/
cp "$SRC_FONTS"/*.woff2 "$MFE_FONT_DIR"/

# Optional: keep a copy of the canonical design-token CSS in the theme tree
# so operators can inspect it on live hosts.
if [[ -f "$TOKENS_SRC" ]]; then
  mkdir -p "$(dirname "$TOKENS_DEST")"
  cp "$TOKENS_SRC" "$TOKENS_DEST"
  echo "  ✓ Copied tokens.css -> $(basename "$TOKENS_DEST")"
fi

# Copy logo assets to all theme directories
for asset in logo-horizontal.png logo-horizontal.svg logo-horizontal-white.png logo-horizontal-white.svg logo-square.png logo-square.svg logo-square-white.png logo-square-white.svg logo.png logo.svg logo-white.png logo-white.svg favicon.ico favicon.svg favicon-16x16.png favicon-32x32.png favicon-256x256.png; do
  if [[ -f "$IMG_SRC_DIR/$asset" ]]; then
    cp "$IMG_SRC_DIR/$asset" "$IMG_DEST_DIR/$asset"
    cp "$IMG_SRC_DIR/$asset" "$MFE_IMG_DEST_DIR/$asset"
    cp "$IMG_SRC_DIR/$asset" "$LMS_IMG_DEST_DIR/$asset"
    cp "$IMG_SRC_DIR/$asset" "$CMS_IMG_DEST_DIR/$asset"
    echo "  ✓ Copied $asset"
  fi
done

echo "Brand assets synced to theme directories."
