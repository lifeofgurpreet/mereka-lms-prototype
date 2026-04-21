#!/usr/bin/env bash
# Patch: sync-footer-assets.sh — Syncs Mereka MFE theme assets (SCSS/fonts) into the MFE build directory.
#
# SINGLE-SOURCE PATTERN (Tutor v21 / Ulmo):
#   MerekaFooter JSX is defined in a single place:
#     - Component JSX:  infrastructure/tutor/plugins/_mereka_lms/mfe_runtime/footer.js
#     - Slot wiring:    PLUGIN_SLOTS.add_items() in mereka_lms_mfe_slots.py
#     - Slot name:      org.openedx.frontend.layout.footer.v1
#   This script ONLY syncs static assets (SCSS, fonts) needed at MFE build time.
#   Do NOT add JSX component definitions here — the plugin slot system is canonical.

sync_footer_assets() {
  # Copy MFE theme SCSS/fonts into the repo-owned Mereka build directory.
  # The rendered Dockerfile expects mereka/env.config.jsx and mereka/theme assets.
  local tutor_root="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}"
  local MFE_BUILD_DIR="$tutor_root/env/plugins/mfe/build/mfe"
  local MFE_MEREKA_DIR="$MFE_BUILD_DIR/mereka"
  local ENV_CONFIG_SOURCE="$MFE_BUILD_DIR/env.config.jsx"
  local THEME_SCSS_SOURCE="$REPO_ROOT/infrastructure/tutor/themes/mereka/scss"
  local THEME_MFE_SOURCE="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe"

  mkdir -p "$MFE_MEREKA_DIR"

  if [ -f "$ENV_CONFIG_SOURCE" ]; then
    cp "$ENV_CONFIG_SOURCE" "$MFE_MEREKA_DIR/env.config.jsx"
  fi

  if [ -d "$THEME_SCSS_SOURCE" ] && [ -d "$THEME_MFE_SOURCE/fonts" ] && [ -f "$THEME_MFE_SOURCE/mereka.scss" ]; then
    mkdir -p "$MFE_MEREKA_DIR/theme-source"
    rm -rf "$MFE_MEREKA_DIR/theme-source/scss"
    cp -R "$THEME_SCSS_SOURCE" "$MFE_MEREKA_DIR/theme-source/scss"
    # Merge MFE surface partials (WW-05 split) into the same scss/ slot so that
    # mereka.scss's @import "./scss/X" resolves them at build time.
    if [ -d "$THEME_MFE_SOURCE/scss" ]; then
      cp "$THEME_MFE_SOURCE/scss/"*.scss "$MFE_MEREKA_DIR/theme-source/scss/"
    fi
    rm -rf "$MFE_MEREKA_DIR/theme-source/fonts"
    cp -R "$THEME_MFE_SOURCE/fonts" "$MFE_MEREKA_DIR/theme-source/fonts"
    cp "$THEME_MFE_SOURCE/mereka.scss" "$MFE_MEREKA_DIR/theme-source/mereka.scss"
  fi
}
