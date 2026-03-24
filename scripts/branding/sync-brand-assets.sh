#!/usr/bin/env bash
# @covers AC-007
# @spec: branding-system_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

SRC_FONTS="$REPO_ROOT/assets/branding/fonts"
THEME_FONT_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/fonts"
LMS_FONT_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/fonts"
CMS_FONT_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/fonts"
MFE_FONT_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/fonts"
MFE_THEME_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/theme"
IMG_SRC_DIR="$REPO_ROOT/assets/branding"
IMG_DEST_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/images"
MFE_IMG_DEST_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/images"
LMS_IMG_DEST_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/images"
CMS_IMG_DEST_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/images"
TOKENS_SRC="$REPO_ROOT/assets/branding/tokens.css"
TOKEN_GENERATOR="$REPO_ROOT/scripts/branding/generate-tokens-from-canonical.sh"
OVERRIDES_SRC="$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css"
OVERRIDES_LMS_DEST="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css"
OVERRIDES_CMS_DEST="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/css/mereka-overrides.css"
BRAND_REPO_TOKENS="${BRAND_REPO_TOKENS:-}"
AUTO_BRAND_REPO_TOKENS="${AUTO_BRAND_REPO_TOKENS:-0}"
if [[ -z "$BRAND_REPO_TOKENS" && "$AUTO_BRAND_REPO_TOKENS" == "1" ]]; then
  AUTO_BRAND_REPO_TOKENS_PATH="$REPO_ROOT/../bbbi-mereka-brand-assets/brands/mereka/tokens/tokens.css"
  if [[ -f "$AUTO_BRAND_REPO_TOKENS_PATH" ]]; then
    BRAND_REPO_TOKENS="$AUTO_BRAND_REPO_TOKENS_PATH"
  fi
fi
BRAND_PACKAGE_SYNC="$REPO_ROOT/scripts/branding/sync-brand-package.sh"
THEME_BUILDER="$REPO_ROOT/scripts/branding/build-tokens.sh"

if [[ ! -d "$SRC_FONTS" ]]; then
  echo "Missing font source directory: $SRC_FONTS" >&2
  exit 1
fi

# Optional: refresh tokens.css from an explicit upstream export path.
# Default is deterministic (no implicit local sibling repo probing).
if [[ -n "$BRAND_REPO_TOKENS" ]]; then
  if [[ ! -f "$BRAND_REPO_TOKENS" ]]; then
    echo "BRAND_REPO_TOKENS points to a missing file: $BRAND_REPO_TOKENS" >&2
    exit 1
  fi
  cp "$BRAND_REPO_TOKENS" "$TOKENS_SRC"
  echo "  ✓ Refreshed tokens.css from $BRAND_REPO_TOKENS"
fi

mkdir -p "$THEME_FONT_DIR" "$MFE_FONT_DIR" "$IMG_DEST_DIR" "$MFE_IMG_DEST_DIR" "$LMS_IMG_DEST_DIR" "$CMS_IMG_DEST_DIR"
cp "$SRC_FONTS"/*.woff2 "$THEME_FONT_DIR"/
mkdir -p "$LMS_FONT_DIR" "$CMS_FONT_DIR"
cp "$SRC_FONTS"/*.woff2 "$LMS_FONT_DIR"/
cp "$SRC_FONTS"/*.woff2 "$CMS_FONT_DIR"/
cp "$SRC_FONTS"/*.woff2 "$MFE_FONT_DIR"/

# Regenerate all token layers from canonical source. This keeps generated
# markers intact while synchronizing SCSS + CSS consumers.
if [[ ! -x "$TOKEN_GENERATOR" ]]; then
  echo "Missing token generator script: $TOKEN_GENERATOR" >&2
  exit 1
fi
"$TOKEN_GENERATOR"
echo "  ✓ Regenerated token layers from canonical source"

if [[ ! -x "$THEME_BUILDER" ]]; then
  echo "Missing theme builder script: $THEME_BUILDER" >&2
  exit 1
fi
"$THEME_BUILDER"
echo "  ✓ Regenerated runtime theme bundles"

# Keep runtime override CSS in sync across common + LMS so deploy checks are deterministic.
if [[ -f "$OVERRIDES_SRC" ]]; then
  mkdir -p "$(dirname "$OVERRIDES_LMS_DEST")"
  mkdir -p "$(dirname "$OVERRIDES_CMS_DEST")"
  cp "$OVERRIDES_SRC" "$OVERRIDES_LMS_DEST"
  cp "$OVERRIDES_SRC" "$OVERRIDES_CMS_DEST"
  echo "  ✓ Synced runtime overrides -> $(basename "$OVERRIDES_LMS_DEST")"
  echo "  ✓ Synced runtime overrides -> $(basename "$OVERRIDES_CMS_DEST")"
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

sync_tenant_mfe_theme_assets() {
  local tenant_slug="$1"
  local source_dir="$REPO_ROOT/assets/branding/tenants/$tenant_slug"
  local target_dir="$MFE_THEME_DIR/$tenant_slug"

  if [[ ! -d "$source_dir" ]]; then
    echo "Missing tenant branding source: $source_dir" >&2
    exit 1
  fi

  mkdir -p "$target_dir"
  cp "$source_dir/logo.svg" "$target_dir/logo.svg"
  cp "$source_dir/logo.png" "$target_dir/logo.png"
  cp "$source_dir/logo.svg" "$target_dir/logo-horizontal.svg"
  cp "$source_dir/logo.png" "$target_dir/logo-horizontal.png"
  cp "$source_dir/logo-white.svg" "$target_dir/logo-white.svg"
  cp "$source_dir/logo-white.png" "$target_dir/logo-white.png"
  cp "$source_dir/logo-white.svg" "$target_dir/logo-horizontal-white.svg"
  cp "$source_dir/logo-white.png" "$target_dir/logo-horizontal-white.png"
  cp "$source_dir/logo-trademark.svg" "$target_dir/logo-trademark.svg"
  cp "$source_dir/logo-trademark.png" "$target_dir/logo-trademark.png"
  cp "$source_dir/favicon.ico" "$target_dir/favicon.ico"
  if [[ -f "$source_dir/favicon-256x256.png" ]]; then
    cp "$source_dir/favicon-256x256.png" "$target_dir/favicon.png"
  fi
  echo "  ✓ Synced tenant MFE theme assets -> theme/${tenant_slug}/"
}

sync_tenant_mfe_theme_assets "biji-biji"
sync_tenant_mfe_theme_assets "skillourfuture"

# Keep OEP-48 local brand package asset bundle in sync as well.
if [[ -x "$BRAND_PACKAGE_SYNC" ]]; then
  "$BRAND_PACKAGE_SYNC" --all
fi

echo "Brand assets synced to theme directories."
