#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN_SRC_DIR="$REPO_ROOT/infrastructure/tutor/plugins"
PLUGIN_DIR="${TUTOR_PLUGINS_DIR:-$HOME/.local/share/tutor-plugins}"

mkdir -p "$PLUGIN_DIR"

install -m 0644 "$PLUGIN_SRC_DIR/mereka_lms.py" "$PLUGIN_DIR/mereka_lms.py"
install -m 0644 "$PLUGIN_SRC_DIR/mereka_lms_mfe_slots.py" "$PLUGIN_DIR/mereka_lms_mfe_slots.py"
install -m 0644 "$PLUGIN_SRC_DIR/mfe_oauth_fix.py" "$PLUGIN_DIR/mfe_oauth_fix.py"

rm -rf "$PLUGIN_DIR/_mereka_lms"
cp -R "$PLUGIN_SRC_DIR/_mereka_lms" "$PLUGIN_DIR/_mereka_lms"

echo "Synced Tutor plugin mirror at $PLUGIN_DIR"
