#!/usr/bin/env bash
# Canonical generated-surface drift gate for deterministic CI artifacts.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SELECTED_CHECKS=()

usage() {
  cat <<'EOF'
Usage: scripts/qa/verify-generated-surfaces.sh [--check <name>]

Available checks:
  ci-static-inventory
  verification-catalog
  ci-runtime-inventory
  fixed-surface-markers
  runtime-routing-matrices
EOF
}

known_check() {
  case "$1" in
    ci-static-inventory|verification-catalog|ci-runtime-inventory|fixed-surface-markers|runtime-routing-matrices)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

check_enabled() {
  local wanted="$1"
  local selected

  if [[ "${#SELECTED_CHECKS[@]}" -eq 0 ]]; then
    return 0
  fi

  for selected in "${SELECTED_CHECKS[@]}"; do
    if [[ "$selected" == "$wanted" ]]; then
      return 0
    fi
  done

  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --check" >&2
        usage >&2
        exit 2
      fi
      if ! known_check "$2"; then
        echo "Unknown check: $2" >&2
        usage >&2
        exit 2
      fi
      SELECTED_CHECKS+=("$2")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

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

if check_enabled "ci-static-inventory"; then
  run_check "ci static inventory is current" \
    python3 scripts/governance/generate-ci-static-inventory.py --check
fi

if check_enabled "verification-catalog"; then
  run_check "verification catalog is current" \
    bash scripts/qa/verify-verification-catalog.sh
fi

if check_enabled "ci-runtime-inventory"; then
  run_check "ci runtime inventory is current" \
    python3 scripts/governance/generate-ci-runtime-inventory.py --check
fi

if check_enabled "fixed-surface-markers"; then
  require_fixed "deploy/k8s/base/kustomization.yaml" \
    "apps/openedx/settings/lms/mereka_video_urls.py" \
    "base openedx settings generator includes video url shim"

  require_fixed "scripts/infra/sync-vendored-openedx-settings.sh" \
    "\"apps/openedx/settings/lms/mereka_video_urls.py\"" \
    "vendored settings sync tracks the video url shim"
fi

if check_enabled "runtime-routing-matrices"; then
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
fi

printf '=== Generated surfaces: %s PASS / %s FAIL ===\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
