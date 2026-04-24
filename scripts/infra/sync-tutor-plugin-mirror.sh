#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TUTOR_ROOT="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}"
PLUGIN_SRC_DIR="$REPO_ROOT/infrastructure/tutor/plugins"
PLUGIN_DIR="${TUTOR_PLUGINS_ROOT:-${TUTOR_PLUGINS_DIR:-$TUTOR_ROOT/plugins}}"
export TUTOR_ROOT
export TUTOR_PLUGINS_ROOT="$PLUGIN_DIR"
export TUTOR_PLUGINS_DIR="$PLUGIN_DIR"

mkdir -p "$PLUGIN_DIR"

install -m 0644 "$PLUGIN_SRC_DIR/mereka_lms.py" "$PLUGIN_DIR/mereka_lms.py"
install -m 0644 "$PLUGIN_SRC_DIR/mereka_lms_mfe_slots.py" "$PLUGIN_DIR/mereka_lms_mfe_slots.py"
install -m 0644 "$PLUGIN_SRC_DIR/mfe_oauth_fix.py" "$PLUGIN_DIR/mfe_oauth_fix.py"

rm -rf "$PLUGIN_DIR/_mereka_lms"
cp -R "$PLUGIN_SRC_DIR/_mereka_lms" "$PLUGIN_DIR/_mereka_lms"

echo "Synced Tutor plugin mirror at $PLUGIN_DIR"
