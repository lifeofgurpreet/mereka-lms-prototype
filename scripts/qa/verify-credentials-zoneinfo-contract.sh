#!/usr/bin/env bash
# Verify credentials deployment has zoneinfo runtime contract to prevent ZoneInfo("UTC") failures.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PATCH_FILE="$REPO_ROOT/deploy/k8s/base/patches/credentials-zoneinfo.yaml"
KUSTOMIZATION_FILE="$REPO_ROOT/deploy/k8s/base/kustomization.yaml"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

pass() {
  echo -e "${GREEN}PASS${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}FAIL${NC} $1"
  FAIL=$((FAIL + 1))
}

require_file() {
  local file="$1"
  local label="$2"
  if [[ -f "$file" ]]; then
    pass "$label exists"
  else
    fail "$label missing ($file)"
  fi
}

require_pattern() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if grep -qE "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label"
  fi
}

echo "=== Credentials Zoneinfo Contract ==="
echo

require_file "$PATCH_FILE" "credentials zoneinfo patch"
require_file "$KUSTOMIZATION_FILE" "base kustomization"

if [[ -f "$PATCH_FILE" ]]; then
  require_pattern "$PATCH_FILE" 'name: seed-zoneinfo' "Patch defines zoneinfo initContainer"
  require_pattern "$PATCH_FILE" 'image: alpine:3.20' "Patch pins deterministic initContainer image"
  require_pattern "$PATCH_FILE" 'name: PYTHONTZPATH' "Patch sets PYTHONTZPATH env var"
  require_pattern "$PATCH_FILE" 'name: TZ' "Patch sets TZ env var"
  require_pattern "$PATCH_FILE" 'value: UTC' "Patch enforces UTC timezone"
  require_pattern "$PATCH_FILE" 'mountPath: /zoneinfo' "Patch mounts zoneinfo path"
  require_pattern "$PATCH_FILE" 'emptyDir: \{\}' "Patch defines ephemeral zoneinfo volume"
fi

if [[ -f "$KUSTOMIZATION_FILE" ]]; then
  require_pattern "$KUSTOMIZATION_FILE" 'patches/credentials-zoneinfo.yaml' "Base kustomization wires credentials zoneinfo patch"
fi

if command -v kubectl >/dev/null 2>&1; then
  rendered="$(kubectl kustomize "$REPO_ROOT/deploy/k8s/base")"
  if grep -q 'name: seed-zoneinfo' <<<"$rendered"; then
    pass "Rendered manifests include zoneinfo initContainer"
  else
    fail "Rendered manifests missing zoneinfo initContainer"
  fi

  if grep -q 'name: PYTHONTZPATH' <<<"$rendered" && grep -q 'value: /zoneinfo' <<<"$rendered"; then
    pass "Rendered manifests include PYTHONTZPATH=/zoneinfo"
  else
    fail "Rendered manifests missing PYTHONTZPATH=/zoneinfo"
  fi

  if grep -q 'name: TZ' <<<"$rendered" && grep -q 'value: UTC' <<<"$rendered"; then
    pass "Rendered manifests include TZ=UTC"
  else
    fail "Rendered manifests missing TZ=UTC"
  fi
else
  fail "kubectl not available; cannot render kustomize output"
fi

echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
