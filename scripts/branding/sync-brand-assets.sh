#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SRC_FONTS="$REPO_ROOT/assets/branding/fonts"
THEME_FONT_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/fonts"
MFE_FONT_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/fonts"
IMG_SRC_DIR="$REPO_ROOT/assets/branding"
IMG_DEST_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/images"
MFE_IMG_DEST_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/images"

if [[ ! -d "$SRC_FONTS" ]]; then
  echo "Missing font source directory: $SRC_FONTS" >&2
  exit 1
fi

mkdir -p "$THEME_FONT_DIR" "$MFE_FONT_DIR" "$IMG_DEST_DIR" "$MFE_IMG_DEST_DIR"
cp "$SRC_FONTS"/*.woff2 "$THEME_FONT_DIR"/
cp "$SRC_FONTS"/*.woff2 "$MFE_FONT_DIR"/

for asset in logo-horizontal.png logo-square.png favicon.ico; do
  if [[ -f "$IMG_SRC_DIR/$asset" ]]; then
    cp "$IMG_SRC_DIR/$asset" "$IMG_DEST_DIR/$asset"
    cp "$IMG_SRC_DIR/$asset" "$MFE_IMG_DEST_DIR/$asset"
  fi
done

echo "Brand assets synced to theme directories."
