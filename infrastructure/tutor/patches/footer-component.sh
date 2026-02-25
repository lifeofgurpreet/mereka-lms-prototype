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
  # Copy MFE theme SCSS/fonts into indigo build directory
  local MFE_INDIGO_DIR="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/indigo"
  if [ -d "$MFE_INDIGO_DIR" ]; then
    mkdir -p "$MFE_INDIGO_DIR/mereka"
    rm -rf "$MFE_INDIGO_DIR/mereka/scss"
    cp -R "$REPO_ROOT/infrastructure/tutor/themes/mereka/scss" "$MFE_INDIGO_DIR/mereka/scss"
    rm -rf "$MFE_INDIGO_DIR/mereka/fonts"
    cp -R "$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/fonts" "$MFE_INDIGO_DIR/mereka/fonts"
    cp "$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss" "$MFE_INDIGO_DIR/mereka/mereka.scss"
  fi
}
