#!/usr/bin/env bash
# Patch: Copy the local OEP-48 brand package and compiled MFE theme CSS
# into the Tutor MFE Mereka build context.

apply_brand_package_patch() {
  local tutor_root="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}"
  local MFE_MEREKA_DIR="$tutor_root/env/plugins/mfe/build/mfe/mereka"
  local SOURCE_DIR="$REPO_ROOT/infrastructure/tutor/brand-mereka"
  local THEME_SOURCE_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/theme"
  local THEME_TARGET_DIR="$MFE_MEREKA_DIR/theme"
  local BUILD_TOKENS_SCRIPT="$REPO_ROOT/scripts/branding/build-tokens.sh"

  if [ ! -d "$SOURCE_DIR" ]; then
    echo "Skipping brand-mereka sync: source not found at $SOURCE_DIR" >&2
    return 0
  fi

  mkdir -p "$MFE_MEREKA_DIR"
  rm -rf "$MFE_MEREKA_DIR/brand-mereka"
  cp -R "$SOURCE_DIR"/. "$MFE_MEREKA_DIR/brand-mereka"

  # Keep compiled runtime theme CSS in sync with MFE Docker context.
  if [ ! -d "$THEME_SOURCE_DIR" ] && [ -x "$BUILD_TOKENS_SCRIPT" ]; then
    "$BUILD_TOKENS_SCRIPT"
  fi

  rm -rf "$THEME_TARGET_DIR"
  if [ -d "$THEME_SOURCE_DIR" ]; then
    mkdir -p "$THEME_TARGET_DIR"
    cp -R "$THEME_SOURCE_DIR"/. "$THEME_TARGET_DIR"
    return
  fi

  echo "Skipping theme sync: source not found at $THEME_SOURCE_DIR (build script: $BUILD_TOKENS_SCRIPT)" >&2
}
