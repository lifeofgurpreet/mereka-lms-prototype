#!/usr/bin/env bash
# Apply local adjustments to Tutor templates until upstream catches up.
# This script sources modular patch functions from infrastructure/tutor/patches/
# and applies them by target. Each patch is idempotent (safe to run multiple times).
# Operator note: for local iteration and CI build prep, use
# `./scripts/infra/prepare-tutor-build-context.sh --target <openedx|mfe|all>`
# as the front door. This script remains the compatibility implementation detail
# because existing verifiers still inspect its patch wiring directly.
set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage:
  apply-patches.sh [--target all|openedx|mfe]
EOF
}

TARGET="${MEREKA_BUILD_TARGET:-all}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      TARGET="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

case "$TARGET" in
  all|openedx|mfe) ;;
  *)
    echo "Unsupported target: $TARGET" >&2
    usage
    exit 2
    ;;
esac

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
source "$PATCHES_DIR/mfe-slot-ownership.sh"
source "$PATCHES_DIR/build-optimizations.sh"
source "$PATCHES_DIR/learner-record-node18.sh"

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

sync_openedx_theme() {
  local tutor_theme_dir="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}/env/build/openedx/themes/mereka"
  local mereka_theme_src="$REPO_ROOT/infrastructure/tutor/themes/mereka"

  if [[ -d "$mereka_theme_src" ]]; then
    mkdir -p "$tutor_theme_dir"
    cp -R "$mereka_theme_src/." "$tutor_theme_dir/"
    echo "Synced Mereka theme to Open edX build context: $tutor_theme_dir"
  else
    echo "WARNING: Mereka theme source not found at $mereka_theme_src"
  fi
}

sync_mfe_patch_helpers() {
  local tutor_mfe_build_dir="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}/env/plugins/mfe/build/mfe"
  mkdir -p "$tutor_mfe_build_dir"
  cp "$PATCHES_DIR/patch-authn-deep-route-handoff.py" \
    "$tutor_mfe_build_dir/patch-authn-deep-route-handoff.py"
  echo "Synced authn deep-route patch helper to MFE build context: $tutor_mfe_build_dir"
}

apply_openedx_patches() {
  apply_patch apply_webpack_memory_patch
  apply_patch apply_build_optimizations_patch
  sync_openedx_theme
}

apply_mfe_patches() {
  apply_patch apply_mfe_node_patch
  apply_patch apply_brand_package_patch
  apply_patch apply_footer_component_patch
  apply_patch apply_mfe_slot_ownership_patch
  apply_patch apply_learner_record_node18_patch
  sync_mfe_patch_helpers
}

case "$TARGET" in
  openedx)
    apply_openedx_patches
    ;;
  mfe)
    apply_mfe_patches
    ;;
  all)
    apply_openedx_patches
    apply_mfe_patches
    ;;
esac

echo "Applied Tutor patches for target: $TARGET"
