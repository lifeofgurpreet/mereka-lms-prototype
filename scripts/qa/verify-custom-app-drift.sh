#!/usr/bin/env bash
# verify-custom-app-drift.sh — Detect mismatches between custom apps
# referenced in LMS/CMS settings and those installed in the Docker image.
#
# Usage: ./scripts/qa/verify-custom-app-drift.sh
# Exit code: 0 = no drift, 1 = drift detected
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
# Search all plugin contract files (main + submodules)
PLUGIN_BUNDLE="$(mktemp -t mereka-plugin-drift.XXXXXX)"
trap 'rm -f "$PLUGIN_BUNDLE"' EXIT
while IFS= read -r _pf; do
  cat "$_pf" >>"$PLUGIN_BUNDLE"
  printf '\n' >>"$PLUGIN_BUNDLE"
done < <(mereka_plugin_contract_files "$REPO_ROOT")
PLUGIN="$PLUGIN_BUNDLE"
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
echo "--- Plugin (_CUSTOM_APPS in mereka_lms.py) ---"
plugin_apps=()
while IFS= read -r line; do
  app=$(echo "$line" | grep -oP '"(\w+)"' | tr -d '"' || true)
  [ -n "$app" ] && plugin_apps+=("$app")
done < <(sed -n '/_CUSTOM_APPS = \[/,/^\]/p' "$PLUGIN")
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
