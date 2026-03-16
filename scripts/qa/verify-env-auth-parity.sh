#!/usr/bin/env bash
# @covers AC-DEP-205
# @spec: k8s-deployment.md
#
# Verify that critical auth/session settings are consistent across
# environment overlays. Detects the class of bug where one env has
# SESSION_COOKIE_SAMESITE="Lax" while others have "None".
#
# Usage:
#   ./scripts/qa/verify-env-auth-parity.sh
#   INFRA_REPO=/path/to/bbi-infrastructure ./scripts/qa/verify-env-auth-parity.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

INFRA_REPO="${INFRA_REPO:-}"
for candidate in \
  "$HOME/projects/k8s/bbi-infrastructure" \
  "$REPO_ROOT/../bbi-infrastructure"; do
  if [[ -d "$candidate/apps/mereka-lms" ]]; then
    INFRA_REPO="$candidate"
    break
  fi
done

if [[ -z "$INFRA_REPO" ]] || [[ ! -d "$INFRA_REPO/apps/mereka-lms" ]]; then
  echo "SKIP: bbi-infrastructure repo not found — set INFRA_REPO"
  exit 0
fi

PASS=0
FAIL=0

OVERLAYS=(
  "dev:apps/mereka-lms/overlays/dev/patches/production-staging.py"
  "staging:apps/mereka-lms/overlays/staging/patches/production-staging.py"
  "prod:apps/mereka-lms/overlays/prod/patches/production-prod.py"
)

# Critical auth settings that MUST be consistent across environments
# or explicitly justified
PARITY_SETTINGS=(
  "SESSION_COOKIE_SAMESITE"
  "CSRF_COOKIE_SAMESITE"
)

echo "=== Environment Auth Parity Check ==="

for setting in "${PARITY_SETTINGS[@]}"; do
  values=()
  envs=()
  for overlay in "${OVERLAYS[@]}"; do
    env="${overlay%%:*}"
    file="${overlay#*:}"
    filepath="$INFRA_REPO/$file"
    if [[ ! -f "$filepath" ]]; then
      continue
    fi
    val=$(grep -v '^\s*#' "$filepath" | grep "^${setting}\b" | tail -1 | sed 's/.*= *//' | tr -d ' "'"'" || true)
    if [[ -n "$val" ]]; then
      values+=("$val")
      envs+=("$env=$val")
    fi
  done

  if [[ ${#values[@]} -lt 2 ]]; then
    echo "SKIP $setting: found in fewer than 2 overlays"
    continue
  fi

  # Check all values are the same
  unique=$(printf '%s\n' "${values[@]}" | sort -u | wc -l)
  if [[ $unique -eq 1 ]]; then
    echo "OK   $setting: consistent (${values[0]}) across ${envs[*]}"
    PASS=$((PASS + 1))
  else
    echo "FAIL $setting: inconsistent across environments"
    for e in "${envs[@]}"; do
      echo "       $e"
    done
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "=== Summary: PASS=$PASS FAIL=$FAIL ==="

if [[ $FAIL -gt 0 ]]; then
  echo "FAIL: auth settings are not consistent across environments."
  exit 1
fi

echo "OK: auth parity verified"
exit 0
