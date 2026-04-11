#!/usr/bin/env bash
# Canonical generated-surface drift gate for deterministic CI artifacts.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

PASS=0
FAIL=0

pass() {
  PASS=$((PASS + 1))
  printf 'PASS %s\n' "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  printf 'FAIL %s\n' "$1" >&2
}

require_fixed() {
  local path="$1"
  local needle="$2"
  local label="$3"
  if grep -Fq -- "$needle" "$path"; then
    pass "$label"
  else
    fail "$label"
  fi
}

run_check() {
  local label="$1"
  shift
  if "$@"; then
    pass "$label"
  else
    fail "$label"
  fi
}

run_check "ci static inventory is current" \
  python3 scripts/governance/generate-ci-static-inventory.py --check

run_check "verification catalog is current" \
  bash scripts/qa/verify-verification-catalog.sh

run_check "ci runtime inventory is current" \
  python3 scripts/governance/generate-ci-runtime-inventory.py --check

require_fixed "deploy/k8s/base/kustomization.yaml" \
  "apps/openedx/settings/lms/mereka_video_urls.py" \
  "base openedx settings generator includes video url shim"

require_fixed "scripts/infra/sync-vendored-openedx-settings.sh" \
  "\"apps/openedx/settings/lms/mereka_video_urls.py\"" \
  "vendored settings sync tracks the video url shim"

mapfile -t matrix_files < <(find generated/tenant-runtime -maxdepth 1 -name 'browser-matrix-*.json' | sort)
if [[ "${#matrix_files[@]}" -eq 0 ]]; then
  fail "runtime-routing matrices are missing under generated/tenant-runtime"
else
  for matrix_file in "${matrix_files[@]}"; do
    env_name="${matrix_file##*/browser-matrix-}"
    env_name="${env_name%.json}"
    run_check "runtime-routing matrix ${env_name} is current" \
      python3 scripts/acceptance/generate_runtime_routing_matrix.py --env "$env_name" --check
  done
fi

printf '=== Generated surfaces: %s PASS / %s FAIL ===\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
