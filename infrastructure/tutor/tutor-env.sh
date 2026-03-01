#!/usr/bin/env bash
# Helper to load the local Tutor environment variables. Source this file from the repo root.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export TUTOR_ROOT="$REPO_ROOT/tutor_env"
export OPENEDX_RELEASE="nightly"

# Keep the active Tutor plugin in sync with repo source to avoid config-render drift.
PLUGIN_SRC="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
PLUGIN_DIR="${TUTOR_PLUGINS_DIR:-$HOME/.local/share/tutor-plugins}"
PLUGIN_DST="$PLUGIN_DIR/mereka_lms.py"

if [ -f "$PLUGIN_SRC" ]; then
  mkdir -p "$PLUGIN_DIR"
  if [ ! -f "$PLUGIN_DST" ] || ! cmp -s "$PLUGIN_SRC" "$PLUGIN_DST"; then
    cp "$PLUGIN_SRC" "$PLUGIN_DST"
    echo "Synced Tutor plugin: $PLUGIN_DST"
  fi
fi

if [ -d "$REPO_ROOT/.venv" ]; then
  # shellcheck disable=SC1090
  source "$REPO_ROOT/.venv/bin/activate"
else
  echo "Python virtualenv not found at $REPO_ROOT/.venv" >&2
  exit 1
fi
