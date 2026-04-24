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
# shellcheck source=infrastructure/tutor/patches/_common.sh
source "$PATCHES_DIR/_common.sh"

# Run branding health check if available
BRANDING_CHECK="$REPO_ROOT/scripts/branding/verify-branding-health.sh"
if [[ -x "$BRANDING_CHECK" ]]; then
  "$BRANDING_CHECK"
fi

# Source all patch modules
# NOTE: MFE node patch module removed in tracker #32; durable MFE Dockerfile
# ownership now lives in Tutor plugin hooks in _mereka_lms/mfe_dockerfile.py.
# Remaining direct rendered-Dockerfile rewrites must be named patch modules or
# explicitly documented wrappers with fixture coverage and retirement triggers.
# shellcheck source=infrastructure/tutor/patches/brand-package.sh
source "$PATCHES_DIR/brand-package.sh"
# shellcheck source=infrastructure/tutor/patches/webpack-memory.sh
source "$PATCHES_DIR/webpack-memory.sh"
# shellcheck source=infrastructure/tutor/patches/sync-footer-assets.sh
source "$PATCHES_DIR/sync-footer-assets.sh"
# shellcheck source=infrastructure/tutor/patches/mysql-root-host.sh
source "$PATCHES_DIR/mysql-root-host.sh"
# shellcheck source=infrastructure/tutor/patches/mfe-npm-install-resilience.sh
source "$PATCHES_DIR/mfe-npm-install-resilience.sh"
# shellcheck source=infrastructure/tutor/patches/mfe-slot-ownership.sh
source "$PATCHES_DIR/mfe-slot-ownership.sh"
# shellcheck source=infrastructure/tutor/patches/mfe-prune-deprecated-shells.sh
source "$PATCHES_DIR/mfe-prune-deprecated-shells.sh"
# shellcheck source=infrastructure/tutor/patches/dependency-image-mirrors.sh
source "$PATCHES_DIR/dependency-image-mirrors.sh"
# shellcheck source=infrastructure/tutor/patches/openedx-obsolete-activation-key-patch-removal.sh
source "$PATCHES_DIR/openedx-obsolete-activation-key-patch-removal.sh"
# shellcheck source=infrastructure/tutor/patches/build-optimizations.sh
source "$PATCHES_DIR/build-optimizations.sh"

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

mirror_tree() {
  local source_dir="$1"
  local dest_dir="$2"
  local label="$3"

  if [[ ! -d "$source_dir" ]]; then
    echo "WARNING: $label source not found at $source_dir" >&2
    return 0
  fi

  rm -rf "$dest_dir"
  mkdir -p "$dest_dir"
  cp -R "$source_dir/." "$dest_dir/"
  echo "Synced $label to build context: $dest_dir"
}

sync_openedx_theme() {
  local tutor_theme_dir="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}/env/build/openedx/themes/mereka"
  local mereka_theme_src="$REPO_ROOT/infrastructure/tutor/themes/mereka"

  mirror_tree "$mereka_theme_src" "$tutor_theme_dir" "Mereka Open edX theme"
}

sync_openedx_custom_apps() {
  local tutor_openedx_root="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}/env/build/openedx"
  local custom_apps_src="$REPO_ROOT/infrastructure/tutor/custom-apps"
  local custom_apps_dest="$tutor_openedx_root/infrastructure/tutor/custom-apps"

  if [[ ! -d "$tutor_openedx_root" ]]; then
    echo "WARNING: Open edX build root missing at $tutor_openedx_root" >&2
    return 0
  fi

  mirror_tree "$custom_apps_src" "$custom_apps_dest" "Open edX custom apps"
}

sync_openedx_multi_tenancy_plugin() {
  local tutor_openedx_root="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}/env/build/openedx"
  local multi_tenancy_src="$REPO_ROOT/infrastructure/tutor/plugins/multi-tenancy"
  local multi_tenancy_dest="$tutor_openedx_root/infrastructure/tutor/plugins/multi-tenancy"

  if [[ ! -d "$tutor_openedx_root" ]]; then
    echo "WARNING: Open edX build root missing at $tutor_openedx_root" >&2
    return 0
  fi

  mirror_tree "$multi_tenancy_src" "$multi_tenancy_dest" "Open edX multi-tenancy plugin"
}

remove_retired_indigo_theme() {
  local indigo_theme_dir="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}/env/build/openedx/themes/indigo"

  if [[ -d "$indigo_theme_dir" ]]; then
    rm -rf "$indigo_theme_dir"
    echo "Removed retired Indigo theme from generated Open edX build context: $indigo_theme_dir"
  fi
}

sync_mfe_patch_helpers() {
  local tutor_mfe_build_dir="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}/env/plugins/mfe/build/mfe"
  mkdir -p "$tutor_mfe_build_dir"
  cp "$PATCHES_DIR/patch-authn-deep-route-handoff.py" \
    "$tutor_mfe_build_dir/patch-authn-deep-route-handoff.py"
  cp "$PATCHES_DIR/patch-authn-dashboard-fallbacks.py" \
    "$tutor_mfe_build_dir/patch-authn-dashboard-fallbacks.py"
  cp "$PATCHES_DIR/verify-authn-dashboard-fallbacks.py" \
    "$tutor_mfe_build_dir/verify-authn-dashboard-fallbacks.py"
  echo "Synced authn patch helpers to MFE build context: $tutor_mfe_build_dir"
}

wrap_mfe_pull_translations_retry() {
  # This is one of the remaining allowed rendered-MFE-Dockerfile rewrites in
  # apply-patches.sh. Other direct mutations must be named patch modules with
  # docs and contract checks, or live in Tutor plugin hooks/build-context sync.
  #
  # CI reliability fix — DinD/BuildKit DNS to github.com intermittently fails
  # during the MFE build, causing `make OPENEDX_ATLAS_PULL=true ... pull_translations`
  # to abort with:
  #   fatal: unable to access 'https://github.com/openedx/openedx-translations.git/':
  #   Could not resolve host: github.com
  #
  # Complementary to PR #1567 (trivy bootstrap retry), #1568 (MFE git fetch retry
  # at workflow level), and #1569 (stop rewriting DinD MTU). Those fix the
  # runner-side surface; this wraps the actual in-container RUN layer with a
  # bash retry loop so transient DNS blips inside the docker build don't take
  # down a 45-minute cold build at layer 155.
  #
  # Post-render sed-wrap each `RUN make OPENEDX_ATLAS_PULL=true ... pull_translations`
  # with: RUN for i in 1 2 3; do <cmd> && exit 0; sleep 15; done; exit 1
  local rendered_dockerfile="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}/env/plugins/mfe/build/mfe/Dockerfile"

  if [[ ! -f "$rendered_dockerfile" ]]; then
    echo "WARNING: Rendered MFE Dockerfile not found at $rendered_dockerfile — skip retry wrap" >&2
    return 0
  fi

  if grep -q "pull_translations_retry_sentinel" "$rendered_dockerfile"; then
    echo "MFE Dockerfile pull_translations already wrapped with retry — skip"
    return 0
  fi

  python3 - <<'PY' "$rendered_dockerfile"
import re
import sys
from pathlib import Path

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8")

pattern = re.compile(
    r'^RUN make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="([^"]*)" pull_translations\s*$',
    re.MULTILINE,
)

def wrap(match):
    atlas_opts = match.group(1)
    cmd = (
        f'make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="{atlas_opts}" pull_translations'
    )
    return (
        "# pull_translations_retry_sentinel — apply-patches.sh wrap_mfe_pull_translations_retry\n"
        "RUN bash -o pipefail -c 'for attempt in 1 2 3; do "
        f"{cmd} && exit 0; "
        "echo \"pull_translations attempt ${attempt} failed; retrying in 15s\" >&2; "
        "sleep 15; done; exit 1'"
    )

new_text, count = pattern.subn(wrap, text)
if count == 0:
    print("No pull_translations lines matched — nothing to wrap", file=sys.stderr)
    sys.exit(0)

p.write_text(new_text, encoding="utf-8")
print(f"Wrapped {count} pull_translations RUN line(s) with retry loop")
PY
}

apply_openedx_patches() {
  apply_patch apply_mysql_root_host_patch
  apply_patch apply_webpack_memory_patch
  apply_patch apply_dependency_image_mirrors_patch
  apply_patch apply_openedx_obsolete_activation_key_patch_removal_patch
  apply_patch apply_build_optimizations_patch
  sync_openedx_theme
  sync_openedx_custom_apps
  sync_openedx_multi_tenancy_plugin
  remove_retired_indigo_theme
}

apply_mfe_patches() {
  apply_patch apply_brand_package_patch
  apply_patch sync_footer_assets
  apply_patch apply_mfe_slot_ownership_patch
  apply_patch apply_mfe_prune_deprecated_shells_patch
  apply_patch apply_mfe_npm_install_resilience_patch
  apply_patch apply_dependency_image_mirrors_patch
  sync_mfe_patch_helpers
  wrap_mfe_pull_translations_retry
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
