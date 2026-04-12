#!/usr/bin/env bash
# Patch: remove deprecated default-path residue from generated MFE artifacts.
#
# Tutor's rendered MFE Dockerfile can still include legacy orders/payment shells
# and other environment-coupled residue even though this lane no longer treats
# them as part of the active default MFE estate. This patch trims those
# generated sections from the Dockerfile and matching Caddy routes so image
# truth follows the current estate contract.

apply_mfe_prune_deprecated_shells_patch() {
  local dockerfile="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/Dockerfile"
  local caddyfile="$REPO_ROOT/tutor_env/env/plugins/mfe/apps/mfe/Caddyfile"
  "${PYTHON_BIN}" "$REPO_ROOT/infrastructure/tutor/patches/mfe_prune_deprecated_shells.py" \
    "$dockerfile" \
    "$caddyfile"
}
