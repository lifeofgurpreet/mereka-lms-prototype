#!/usr/bin/env bash
# verify-custom-app-drift.sh — Detect mismatches between custom apps
# referenced in LMS/CMS settings and those installed in the Docker image.
#
# Usage: ./scripts/qa/verify-custom-app-drift.sh
# Exit code: 0 = no drift, 1 = drift detected
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$REPO_ROOT/infrastructure/tutor/plugins/_mereka_lms/openedx_dockerfile.py"
CUSTOM_APPS_DIR="$REPO_ROOT/infrastructure/tutor/custom-apps"
LMS_SETTINGS="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"
CMS_SETTINGS="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/cms/production.py"

PASS=0
FAIL=0
WARN=0

do_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
do_warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

contains() {
  local needle="$1"; shift
  for item in "$@"; do
    [ "$item" = "$needle" ] && return 0
  done
  return 1
}

echo "=== Custom App Install Drift Check ==="
echo ""

# 1. Extract apps from plugin's _CUSTOM_APPS list
echo "--- Plugin (_CUSTOM_APPS in openedx_dockerfile.py) ---"
plugin_apps=()
if [[ ! -f "$PLUGIN_MAIN" ]]; then
  do_fail "plugin main file missing: $PLUGIN_MAIN"
  echo ""
  echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="
  exit 1
fi
while IFS= read -r app; do
  [[ -n "$app" ]] && plugin_apps+=("$app")
done < <(python3 - "$PLUGIN_MAIN" <<'PY'
from __future__ import annotations

import ast
import sys
from pathlib import Path

plugin = Path(sys.argv[1])
tree = ast.parse(plugin.read_text(encoding="utf-8"), filename=str(plugin))
lists: dict[str, list[str]] = {}


def eval_string_list(node: ast.AST) -> list[str]:
    if isinstance(node, ast.List):
        values: list[str] = []
        for elt in node.elts:
            if isinstance(elt, ast.Constant) and isinstance(elt.value, str):
                values.append(elt.value)
            elif isinstance(elt, ast.Starred) and isinstance(elt.value, ast.Name):
                values.extend(lists[elt.value.id])
            else:
                raise ValueError(f"unsupported list element: {ast.dump(elt)}")
        return values
    if isinstance(node, ast.Name):
        return list(lists[node.id])
    raise ValueError(f"unsupported list expression: {ast.dump(node)}")


for node in tree.body:
    if not isinstance(node, ast.Assign):
        continue
    for target in node.targets:
        if isinstance(target, ast.Name) and target.id.endswith("_CUSTOM_APPS"):
            lists[target.id] = eval_string_list(node.value)

for app in lists.get("_CUSTOM_APPS", []):
    print(app)
PY
)
echo "  Found ${#plugin_apps[@]} apps in plugin"

# 2. Extract apps from custom-apps directory
echo ""
echo "--- Custom Apps Directory ---"
dir_apps=()
if [ -d "$CUSTOM_APPS_DIR" ]; then
  while IFS= read -r d; do
    app=$(basename "$d")
    if [ -f "$d/setup.py" ] || [ -f "$d/pyproject.toml" ]; then
      dir_apps+=("$app")
    fi
  done < <(find "$CUSTOM_APPS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
fi
echo "  Found ${#dir_apps[@]} apps in directory"

# 3. Extract custom apps from LMS/CMS settings
echo ""
echo "--- Settings References ---"
settings_apps=()
for settings_file in "$LMS_SETTINGS" "$CMS_SETTINGS"; do
  [ -f "$settings_file" ] || continue
  # Match INSTALLED_APPS.append("app_name")
  while IFS= read -r app; do
    if [[ "$app" =~ ^(openedx_|mfe_|credentials_) ]]; then
      contains "$app" "${settings_apps[@]+"${settings_apps[@]}"}" || settings_apps+=("$app")
    fi
  done < <(grep -oP 'INSTALLED_APPS\.append\("\K\w+' "$settings_file" || true)
  # Match INSTALLED_APPS += ['app_name', ...]
  while IFS= read -r app; do
    if [[ "$app" =~ ^(openedx_|mfe_|credentials_) ]]; then
      contains "$app" "${settings_apps[@]+"${settings_apps[@]}"}" || settings_apps+=("$app")
    fi
  done < <(grep -oP "INSTALLED_APPS \+= \[.*?\]" "$settings_file" | grep -oP "'[^']+'" | tr -d "'" || true)
done
echo "  Found ${#settings_apps[@]} custom apps in settings"

# 4. Cross-check: settings apps must be in plugin
echo ""
echo "--- Cross-Check: Settings -> Plugin ---"
for app in "${settings_apps[@]+"${settings_apps[@]}"}"; do
  if contains "$app" "${plugin_apps[@]+"${plugin_apps[@]}"}"; then
    do_pass "$app in plugin"
  else
    do_fail "$app referenced in settings but MISSING from plugin _CUSTOM_APPS"
  fi
done

# 5. Cross-check: plugin apps must exist in directory
echo ""
echo "--- Cross-Check: Plugin -> Directory ---"
for app in "${plugin_apps[@]+"${plugin_apps[@]}"}"; do
  if [ -d "$CUSTOM_APPS_DIR/$app" ]; then
    do_pass "$app directory exists"
  else
    do_fail "$app in plugin but MISSING from custom-apps directory"
  fi
done

# 6. Cross-check: directory apps should be in plugin (warn only)
echo ""
echo "--- Cross-Check: Directory -> Plugin ---"
for app in "${dir_apps[@]+"${dir_apps[@]}"}"; do
  if contains "$app" "${plugin_apps[@]+"${plugin_apps[@]}"}"; then
    do_pass "$app in plugin"
  else
    do_warn "$app in directory but not in plugin (may be unused)"
  fi
done

echo ""
echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
