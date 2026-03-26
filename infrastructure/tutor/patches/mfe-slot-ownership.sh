#!/usr/bin/env bash
# Patch: remove tutor-indigo learner MFE layout ownership from generated env.config.jsx.
#
# Tutor Indigo still injects footer/header/theme widgets for learner-facing MFEs
# during `tutor config save`. Mereka owns those same surfaces via local
# PLUGIN_SLOTS, so shipping both produces split ownership and ambiguous runtime
# behavior. This patch strips the Indigo app-specific blocks from the generated
# env.config artifacts after Tutor renders them.

apply_mfe_slot_ownership_patch() {
  local candidates=(
    "$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/env.config.jsx"
    "$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/indigo/env.config.jsx"
  )
  "${PYTHON_BIN}" "$REPO_ROOT/infrastructure/tutor/patches/mfe_slot_ownership.py" "${candidates[@]}"
}
