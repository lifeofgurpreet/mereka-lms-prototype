#!/usr/bin/env bash
# Helper to load the local Tutor environment variables. Source this file from the repo root.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export TUTOR_ROOT="$REPO_ROOT/tutor_env"
export OPENEDX_RELEASE="nightly"

# Keep the active Tutor plugin in sync with repo source to avoid config-render drift.
# The plugin entrypoint (mereka_lms.py) imports from _mereka_lms/ package and
# mereka_lms_mfe_slots.py — all three must be synced together.
PLUGIN_SRC_DIR="$REPO_ROOT/infrastructure/tutor/plugins"
PLUGIN_DIR="${TUTOR_PLUGINS_DIR:-$HOME/.local/share/tutor-plugins}"

if [ -f "$PLUGIN_SRC_DIR/mereka_lms.py" ]; then
  mkdir -p "$PLUGIN_DIR"

  # Sync entrypoint
  if [ ! -f "$PLUGIN_DIR/mereka_lms.py" ] || ! cmp -s "$PLUGIN_SRC_DIR/mereka_lms.py" "$PLUGIN_DIR/mereka_lms.py"; then
    cp "$PLUGIN_SRC_DIR/mereka_lms.py" "$PLUGIN_DIR/mereka_lms.py"
    echo "Synced Tutor plugin: mereka_lms.py"
  fi

  # Sync MFE slots module
  if [ -f "$PLUGIN_SRC_DIR/mereka_lms_mfe_slots.py" ]; then
    if [ ! -f "$PLUGIN_DIR/mereka_lms_mfe_slots.py" ] || ! cmp -s "$PLUGIN_SRC_DIR/mereka_lms_mfe_slots.py" "$PLUGIN_DIR/mereka_lms_mfe_slots.py"; then
      cp "$PLUGIN_SRC_DIR/mereka_lms_mfe_slots.py" "$PLUGIN_DIR/mereka_lms_mfe_slots.py"
      echo "Synced Tutor plugin: mereka_lms_mfe_slots.py"
    fi
  fi

  # Sync _mereka_lms/ package (required for plugin submodule imports)
  if [ -d "$PLUGIN_SRC_DIR/_mereka_lms" ]; then
    if command -v rsync >/dev/null 2>&1; then
      if rsync -a --checksum --delete --itemize-changes "$PLUGIN_SRC_DIR/_mereka_lms/" "$PLUGIN_DIR/_mereka_lms/" | grep -q .; then
        echo "Synced Tutor plugin package: _mereka_lms/"
      fi
    else
      # Fallback for environments without rsync (CI runners)
      rm -rf "$PLUGIN_DIR/_mereka_lms"
      cp -R "$PLUGIN_SRC_DIR/_mereka_lms" "$PLUGIN_DIR/_mereka_lms"
      echo "Synced Tutor plugin package: _mereka_lms/"
    fi
  fi
fi

if [ -d "$REPO_ROOT/.venv" ]; then
  # shellcheck disable=SC1090
  source "$REPO_ROOT/.venv/bin/activate"
else
  echo "Python virtualenv not found at $REPO_ROOT/.venv" >&2
  exit 1
fi
