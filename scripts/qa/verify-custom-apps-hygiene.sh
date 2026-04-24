#!/usr/bin/env bash
# @covers AC-RS-001, AC-RS-002
# @spec: repository-structure_spec.md
# verify-custom-apps-hygiene.sh
#
# Enforce packaging and git hygiene rules for Tutor custom Django apps.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
REPO_ROOT="${REPO_ROOT_OVERRIDE:-$REPO_ROOT}"
CUSTOM_APPS_DIR="$REPO_ROOT/infrastructure/tutor/custom-apps"
cd "$REPO_ROOT"

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
  if [[ "$path" =~ ^infrastructure/tutor/custom-apps/.+\.(sqlite3|sqlite|db)$ ]]; then
    fail "$path is a tracked SQLite runtime database file"
  elif [[ "$path" =~ ^infrastructure/tutor/custom-apps/.+\.(sqlite3|sqlite|db)-(wal|shm|journal)$ ]]; then
    fail "$path is a tracked SQLite sidecar/transaction file"
  elif [[ "$path" =~ ^infrastructure/tutor/custom-apps/.+\.log$ ]]; then
    fail "$path is a tracked runtime log file"
  elif [[ "$path" =~ ^infrastructure/tutor/custom-apps/.+\.coverage(\..+)?$ ]]; then
    fail "$path is a tracked Python coverage artifact"
  elif [[ "$path" == infrastructure/tutor/custom-apps/*"/.pytest_cache/"* ]]; then
    fail "$path is tracked pytest cache content"
  elif [[ "$path" == infrastructure/tutor/custom-apps/*"/.ruff_cache/"* ]]; then
    fail "$path is tracked ruff cache content"
  elif [[ "$path" == infrastructure/tutor/custom-apps/*"/.mypy_cache/"* ]]; then
    fail "$path is tracked mypy cache content"
  elif [[ "$path" == infrastructure/tutor/custom-apps/*"/.hypothesis/"* ]]; then
    fail "$path is tracked hypothesis cache content"
  elif [[ "$path" == infrastructure/tutor/custom-apps/*"/__pycache__/"* ]]; then
    fail "$path is tracked Python bytecode cache content"
  elif [[ "$path" =~ ^infrastructure/tutor/custom-apps/.+\.(pyc|pyo)$ ]]; then
    fail "$path is tracked compiled Python bytecode"
  elif [[ "$path" =~ ^infrastructure/tutor/custom-apps/.+\.(pid|sock)$ ]]; then
    fail "$path is a tracked runtime state file"
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
