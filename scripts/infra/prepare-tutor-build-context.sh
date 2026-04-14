#!/usr/bin/env bash
# Canonical entrypoint for mutating rendered Tutor build context and syncing review snapshots.
set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage:
  prepare-tutor-build-context.sh [--target all|openedx|mfe]
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
PATCHES_SCRIPT="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
SYNC_PLUGIN_MIRROR_SCRIPT="$REPO_ROOT/scripts/infra/sync-tutor-plugin-mirror.sh"
TUTOR_CONFIG_SAVE_SCRIPT="$REPO_ROOT/scripts/infra/tutor-config-save.sh"
PLUGIN_SOURCE_ROOT="$REPO_ROOT/infrastructure/tutor/plugins/_mereka_lms"
ACTIVE_TUTOR_ROOT="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}"
OPENEDX_RENDERED_DOCKERFILE="$ACTIVE_TUTOR_ROOT/env/build/openedx/Dockerfile"
MFE_RENDERED_DOCKERFILE="$ACTIVE_TUTOR_ROOT/env/plugins/mfe/build/mfe/Dockerfile"
MFE_SNAPSHOT_DOCKERFILE="$REPO_ROOT/infrastructure/tutor/mfe-build/Dockerfile"

if [[ ! -x "$PATCHES_SCRIPT" ]]; then
  echo "Canonical patch implementation missing or not executable: $PATCHES_SCRIPT" >&2
  exit 1
fi

if [[ ! -x "$SYNC_PLUGIN_MIRROR_SCRIPT" ]]; then
  echo "Canonical plugin mirror sync script missing or not executable: $SYNC_PLUGIN_MIRROR_SCRIPT" >&2
  exit 1
fi

ensure_patch_runtime() {
  if python3 - <<'PY' >/dev/null 2>&1
import tutormfe
PY
  then
    return 0
  fi

  local activate_script=""

  if [[ -n "${TUTOR_VENV:-}" && -f "${TUTOR_VENV}/bin/activate" ]]; then
    activate_script="${TUTOR_VENV}/bin/activate"
  elif [[ -n "${VIRTUAL_ENV:-}" && -f "${VIRTUAL_ENV}/bin/activate" ]]; then
    activate_script="${VIRTUAL_ENV}/bin/activate"
  elif [[ -f "$REPO_ROOT/.venv/bin/activate" ]]; then
    activate_script="$REPO_ROOT/.venv/bin/activate"
  fi

  if [[ -n "$activate_script" ]]; then
    # shellcheck disable=SC1090
    source "$activate_script"
  fi

  if ! python3 - <<'PY' >/dev/null 2>&1
import tutormfe
PY
  then
    echo "Tutor patch runtime missing Python dependency 'tutormfe'." >&2
    echo "Set TUTOR_VENV or activate a Tutor virtualenv before running $0." >&2
    exit 1
  fi
}

require_fresh_rendered_env() {
  local rendered_file="$1"
  local label="$2"

  if [[ ! -f "$rendered_file" ]]; then
    echo "Rendered $label file missing: $rendered_file" >&2
    echo "Run $TUTOR_CONFIG_SAVE_SCRIPT first so Tutor regenerates env from source hooks." >&2
    exit 1
  fi

  if find "$PLUGIN_SOURCE_ROOT" -type f -newer "$rendered_file" | grep -q .; then
    echo "Rendered $label file is stale relative to Tutor plugin source: $rendered_file" >&2
    echo "Run $TUTOR_CONFIG_SAVE_SCRIPT first so source-hook changes are realized before patch-only prepare steps." >&2
    exit 1
  fi
}

sync_mfe_snapshot() {
  if [[ ! -f "$MFE_RENDERED_DOCKERFILE" ]]; then
    echo "Rendered MFE Dockerfile missing after prepare step: $MFE_RENDERED_DOCKERFILE" >&2
    exit 1
  fi

  cp "$MFE_RENDERED_DOCKERFILE" "$MFE_SNAPSHOT_DOCKERFILE"
}

"$SYNC_PLUGIN_MIRROR_SCRIPT"
ensure_patch_runtime

case "$TARGET" in
  openedx)
    require_fresh_rendered_env "$OPENEDX_RENDERED_DOCKERFILE" "Open edX Dockerfile"
    ;;
  mfe)
    require_fresh_rendered_env "$MFE_RENDERED_DOCKERFILE" "MFE Dockerfile"
    ;;
  all)
    require_fresh_rendered_env "$OPENEDX_RENDERED_DOCKERFILE" "Open edX Dockerfile"
    require_fresh_rendered_env "$MFE_RENDERED_DOCKERFILE" "MFE Dockerfile"
    ;;
esac

"$PATCHES_SCRIPT" --target "$TARGET"

case "$TARGET" in
  all|mfe)
    sync_mfe_snapshot
    ;;
esac
