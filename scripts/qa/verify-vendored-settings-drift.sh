#!/usr/bin/env bash
# @covers AC-DEP-204
# @spec: repository-structure_spec.md
#
# Detect drift between app-repo Django settings (canonical source)
# and the vendored copies in bbi-infrastructure.
#
# The app repo (mereka-lms) owns Django/application settings logic.
# The infra repo (bbi-infrastructure) vendors a copy at:
#   apps/mereka-lms/base/deploy/k8s/base/
#
# This script fails if the vendored copy has diverged from the
# app-repo source, indicating the vendor sync is stale.
#
# Usage:
#   ./scripts/qa/verify-vendored-settings-drift.sh
#   INFRA_REPO=/path/to/bbi-infrastructure ./scripts/qa/verify-vendored-settings-drift.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Auto-detect infra repo location
INFRA_REPO="${INFRA_REPO:-}"
if [[ -z "$INFRA_REPO" ]] && [[ "${GITHUB_ACTIONS:-false}" != "true" ]]; then
  for candidate in \
    "$HOME/projects/k8s/bbi-infrastructure" \
    "$REPO_ROOT/../bbi-infrastructure" \
    "$HOME/bbi-infrastructure"; do
    if [[ -d "$candidate/apps/mereka-lms" ]]; then
      INFRA_REPO="$candidate"
      break
    fi
  done
fi

if [[ -z "$INFRA_REPO" ]] || [[ ! -d "$INFRA_REPO/apps/mereka-lms" ]]; then
  echo "SKIP: bbi-infrastructure repo not found — set INFRA_REPO"
  exit 0
fi

PASS=0
FAIL=0
SKIP=0

# Files that must be identical between app repo and vendored copy
VENDORED_BASE="apps/mereka-lms/base/deploy/k8s/base"
TRACKED_FILES=(
  "apps/openedx/settings/lms/production.py"
  "apps/openedx/settings/cms/production.py"
  "apps/openedx/settings/lms/mereka_multisite.py"
  "apps/openedx/settings/cms/mereka_multisite.py"
  "apps/openedx/settings/lms/mereka_forwarded_headers.py"
  "apps/openedx/settings/cms/mereka_forwarded_headers.py"
  "apps/openedx/settings/lms/mereka_enterprise_channels.py"
  "apps/openedx/settings/lms/mereka_platform_admin.py"
  "apps/openedx/settings/cms/mereka_platform_admin.py"
)

should_skip_for_unchanged_ci_surface() {
  [[ "${VENDORED_SETTINGS_FORCE_FULL_SCAN:-0}" == "1" ]] && return 1
  [[ -n "${INFRA_REPO:-}" && ! -d "${INFRA_REPO}/apps/mereka-lms" ]] && return 1

  case "${GITHUB_EVENT_NAME:-}" in
    pull_request|push) ;;
    *)
      return 1
      ;;
  esac

  local -a changed_paths=()
  if ! mapfile -t changed_paths < <(git -C "$REPO_ROOT" show --pretty='' --name-only --first-parent HEAD 2>/dev/null | sed '/^$/d'); then
    return 1
  fi

  [[ ${#changed_paths[@]} -eq 0 ]] && return 1

  local rel_path=""
  local app_path=""
  local changed=""
  for rel_path in "${TRACKED_FILES[@]}"; do
    app_path="deploy/k8s/base/${rel_path}"
    for changed in "${changed_paths[@]}"; do
      if [[ "$changed" == "$app_path" || "$changed" == "scripts/qa/verify-vendored-settings-drift.sh" ]]; then
        return 1
      fi
    done
  done

  echo "SKIP: no vendored-settings surfaces changed in current CI diff"
  return 0
}

echo "=== Vendored Settings Drift Check ==="
echo "App repo: $REPO_ROOT"
echo "Infra repo: $INFRA_REPO"
echo ""

if should_skip_for_unchanged_ci_surface; then
  exit 0
fi

for rel_path in "${TRACKED_FILES[@]}"; do
  APP_FILE="$REPO_ROOT/deploy/k8s/base/$rel_path"
  INFRA_FILE="$INFRA_REPO/$VENDORED_BASE/$rel_path"

  if [[ ! -f "$APP_FILE" ]]; then
    echo "SKIP $(basename "$rel_path"): not in app repo"
    SKIP=$((SKIP + 1))
    continue
  fi
  if [[ ! -f "$INFRA_FILE" ]]; then
    echo "SKIP $(basename "$rel_path"): not in infra repo"
    SKIP=$((SKIP + 1))
    continue
  fi

  DIFF_LINES=$(diff "$APP_FILE" "$INFRA_FILE" 2>/dev/null | wc -l || true)
  if [[ "$DIFF_LINES" -eq 0 ]]; then
    echo "OK   $(basename "$rel_path"): in sync"
    PASS=$((PASS + 1))
  else
    echo "FAIL $(basename "$rel_path"): diverged ($DIFF_LINES diff lines)"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "=== Summary: PASS=$PASS FAIL=$FAIL SKIP=$SKIP ==="

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "FAIL: $FAIL file(s) diverged between app repo and infra vendored copy."
  echo "The app repo is the canonical source. Run vendor-sync to update infra."
  exit 1
fi

echo "OK: all tracked vendored settings are in sync"
exit 0
