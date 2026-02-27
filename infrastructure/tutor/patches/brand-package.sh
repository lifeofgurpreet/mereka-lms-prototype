#!/usr/bin/env bash
# Patch: Copy the local OEP-48 brand package into the MFE Indigo build context.

apply_brand_package_patch() {
  local MFE_INDIGO_DIR="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/indigo"
  local SOURCE_DIR="$REPO_ROOT/infrastructure/tutor/brand-mereka"

  if [ ! -d "$SOURCE_DIR" ]; then
    echo "Skipping brand-mereka sync: source not found at $SOURCE_DIR" >&2
    return 0
  fi

  if [ ! -d "$MFE_INDIGO_DIR" ]; then
    echo "Skipping brand-mereka sync: target dir not found at $MFE_INDIGO_DIR" >&2
    return 0
  fi

  rm -rf "$MFE_INDIGO_DIR/brand-mereka"
  mkdir -p "$MFE_INDIGO_DIR"
  cp -R "$SOURCE_DIR"/. "$MFE_INDIGO_DIR/brand-mereka"
}
