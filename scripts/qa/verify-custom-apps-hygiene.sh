#!/usr/bin/env bash
# verify-custom-apps-hygiene.sh
#
# Enforce packaging and git hygiene rules for Tutor custom Django apps.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CUSTOM_APPS_DIR="$REPO_ROOT/infrastructure/tutor/custom-apps"

if [[ ! -d "$CUSTOM_APPS_DIR" ]]; then
  echo "ERROR: custom apps directory not found: $CUSTOM_APPS_DIR" >&2
  exit 2
fi

violations=0
checks=0

fail() {
  echo "  FAIL: $*" >&2
  violations=$((violations + 1))
}

pass() {
  checks=$((checks + 1))
}

echo "=== Custom Apps Hygiene Verification ==="
echo "Directory: $CUSTOM_APPS_DIR"
echo ""

# 1) Every custom app directory must be pip-installable (setup.py or pyproject.toml).
while IFS= read -r app_dir; do
  app_name="$(basename "$app_dir")"
  if [[ -f "$app_dir/setup.py" || -f "$app_dir/pyproject.toml" ]]; then
    pass
  else
    fail "$app_name missing setup.py/pyproject.toml (Tutor openedx_dockerfile hook install contract)"
  fi
done < <(find "$CUSTOM_APPS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

# 2) No tracked stateful/runtime artifacts in custom-apps.
while IFS= read -r path; do
  if [[ "$path" == infrastructure/tutor/custom-apps/*/db.sqlite3 ]]; then
    fail "$path is a tracked SQLite runtime database"
  elif [[ "$path" == infrastructure/tutor/custom-apps/* && "$path" == *.log ]]; then
    fail "$path is a tracked runtime log file"
  elif [[ "$path" == infrastructure/tutor/custom-apps/* && "$path" == *"/__pycache__/"* ]]; then
    fail "$path is tracked Python bytecode cache content"
  elif [[ "$path" == infrastructure/tutor/custom-apps/* && ( "$path" == *.pyc || "$path" == *.pyo ) ]]; then
    fail "$path is tracked compiled Python bytecode"
  else
    pass
  fi
done < <(git ls-files infrastructure/tutor/custom-apps)

echo "=== Summary ==="
echo "Checks     : $checks"
echo "Violations : $violations"
echo ""

if [[ "$violations" -gt 0 ]]; then
  echo "FAIL — custom-app hygiene violations found." >&2
  exit 1
fi

echo "PASS — custom apps satisfy packaging and hygiene rules."
