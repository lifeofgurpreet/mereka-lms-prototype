#!/usr/bin/env bash
# Patch: Mereka MFE theme assets — copies SCSS/fonts into the Indigo build directory.
#
# MIGRATION COMPLETE (Tutor v21 / Ulmo):
#   MerekaFooter is now registered via Tutor's plugin slot system:
#     - Component JSX:  mfe-env-config-runtime-definitions patch in mereka_lms.py
#     - Slot wiring:    PLUGIN_SLOTS.add_items() in mereka_lms.py
#     - Slot name:      org.openedx.frontend.layout.footer.v1
#   The old env.config.jsx string surgery (inject MerekaFooter def, replace
#   RenderWidget: IndigoFooter) has been removed. Do NOT re-add it here.
#
# This function now only syncs static assets (SCSS, fonts) needed at MFE build time.

apply_footer_component_patch() {
  # Copy MFE theme SCSS/fonts into Indigo build directory.
  # Some Tutor renders place env.config.jsx at build root, but our patched
  # Dockerfile expects indigo/env.config.jsx and indigo/mereka/.
  local MFE_BUILD_DIR="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe"
  local MFE_INDIGO_DIR="$MFE_BUILD_DIR/indigo"
  local ENV_CONFIG_SOURCE="$MFE_BUILD_DIR/env.config.jsx"
  local THEME_SCSS_SOURCE="$REPO_ROOT/infrastructure/tutor/themes/mereka/scss"
  local THEME_MFE_SOURCE="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe"

  mkdir -p "$MFE_INDIGO_DIR"

  if [ -f "$ENV_CONFIG_SOURCE" ]; then
    cp "$ENV_CONFIG_SOURCE" "$MFE_INDIGO_DIR/env.config.jsx"
  elif [ -n "${MFE_INDIGO_ENV_TEMPLATE:-}" ] && [ -f "$MFE_INDIGO_ENV_TEMPLATE" ]; then
    cp "$MFE_INDIGO_ENV_TEMPLATE" "$MFE_INDIGO_DIR/env.config.jsx"
  fi

  if [ -d "$THEME_SCSS_SOURCE" ] && [ -d "$THEME_MFE_SOURCE/fonts" ] && [ -f "$THEME_MFE_SOURCE/mereka.scss" ]; then
    mkdir -p "$MFE_INDIGO_DIR/mereka"
    rm -rf "$MFE_INDIGO_DIR/mereka/scss"
    cp -R "$THEME_SCSS_SOURCE" "$MFE_INDIGO_DIR/mereka/scss"
    # Merge MFE surface partials (WW-05 split) into the same scss/ slot so that
    # mereka.scss's @import "./scss/X" resolves them at build time.
    if [ -d "$THEME_MFE_SOURCE/scss" ]; then
      cp "$THEME_MFE_SOURCE/scss/"*.scss "$MFE_INDIGO_DIR/mereka/scss/"
    fi
    rm -rf "$MFE_INDIGO_DIR/mereka/fonts"
    cp -R "$THEME_MFE_SOURCE/fonts" "$MFE_INDIGO_DIR/mereka/fonts"
    cp "$THEME_MFE_SOURCE/mereka.scss" "$MFE_INDIGO_DIR/mereka/mereka.scss"
  fi
}
