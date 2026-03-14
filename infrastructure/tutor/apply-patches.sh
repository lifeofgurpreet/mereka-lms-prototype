#!/usr/bin/env bash
# Apply local adjustments to Tutor templates until upstream catches up.
# This script sources modular patch functions from infrastructure/tutor/patches/
# and calls them in order. Each patch is idempotent (safe to run multiple times).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PATCHES_DIR="$REPO_ROOT/infrastructure/tutor/patches"

# Source shared setup (venv activation, template path discovery)
source "$PATCHES_DIR/_common.sh"

# Run branding health check if available
BRANDING_CHECK="$REPO_ROOT/scripts/branding/verify-branding-health.sh"
if [[ -x "$BRANDING_CHECK" ]]; then
  "$BRANDING_CHECK"
fi

# Source all patch modules
source "$PATCHES_DIR/mfe-node.sh"
source "$PATCHES_DIR/brand-package.sh"
source "$PATCHES_DIR/webpack-memory.sh"
source "$PATCHES_DIR/footer-component.sh"
source "$PATCHES_DIR/build-optimizations.sh"

# Apply patches in dependency order
apply_patch() {
  local fn="$1"
  echo "  Applying: $fn ..."
  if "$fn"; then
    echo "  OK: $fn"
  else
    echo "  FAILED: $fn (exit $?)" >&2
    exit 1
  fi
}

apply_patch apply_mfe_node_patch
apply_patch apply_brand_package_patch
apply_patch apply_webpack_memory_patch
apply_patch apply_footer_component_patch
apply_patch apply_build_optimizations_patch

# Sync Mereka theme into Tutor build context.
# tutor config save renders only the indigo theme from tutor-indigo plugin.
# Our custom theme must be copied into the build context so that Dockerfile
# COPY directives (from the mereka_lms.py plugin) can find it.
TUTOR_THEME_DIR="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}/env/build/openedx/themes/mereka"
MEREKA_THEME_SRC="$REPO_ROOT/infrastructure/tutor/themes/mereka"
if [[ -d "$MEREKA_THEME_SRC" ]]; then
  mkdir -p "$TUTOR_THEME_DIR"
  cp -R "$MEREKA_THEME_SRC/." "$TUTOR_THEME_DIR/"
  echo "Synced Mereka theme to build context: $TUTOR_THEME_DIR"
else
  echo "WARNING: Mereka theme source not found at $MEREKA_THEME_SRC"
fi

# Sync build-time helper patches into the Tutor MFE build context.
TUTOR_MFE_BUILD_DIR="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}/env/plugins/mfe/build/mfe"
mkdir -p "$TUTOR_MFE_BUILD_DIR"
cp "$PATCHES_DIR/patch-authn-deep-route-handoff.py" \
  "$TUTOR_MFE_BUILD_DIR/patch-authn-deep-route-handoff.py"
echo "Synced authn deep-route patch helper to build context: $TUTOR_MFE_BUILD_DIR"

echo "Applied local Tutor patches."
