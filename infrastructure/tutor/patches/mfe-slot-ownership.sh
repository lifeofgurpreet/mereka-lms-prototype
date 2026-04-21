#!/usr/bin/env bash
# Patch: remove legacy Indigo learner MFE layout ownership from generated env.config.jsx.
#
# This is a migration guard for already-rendered or stale environments. Mereka
# owns learner-facing MFE layout via local PLUGIN_SLOTS; any remaining legacy
# Indigo app-specific blocks must be stripped from generated env.config artifacts.

apply_mfe_slot_ownership_patch() {
  local tutor_root="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}"
  local candidates=(
    "$tutor_root/env/plugins/mfe/build/mfe/env.config.jsx"
    "$tutor_root/env/plugins/mfe/build/mfe/mereka/env.config.jsx"
  )
  "${PYTHON_BIN}" "$REPO_ROOT/infrastructure/tutor/patches/mfe_slot_ownership.py" "${candidates[@]}"
}
