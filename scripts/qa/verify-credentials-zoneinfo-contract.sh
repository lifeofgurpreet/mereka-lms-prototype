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

require_not_pattern() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if grep -qE "$pattern" "$file"; then
    fail "$label"
  else
    pass "$label"
  fi
}

echo "=== Credentials Zoneinfo Contract ==="
echo

require_file "$PATCH_FILE" "credentials zoneinfo patch"
require_file "$KUSTOMIZATION_FILE" "base kustomization"

if [[ -f "$PATCH_FILE" ]]; then
  require_pattern "$PATCH_FILE" 'name: seed-zoneinfo' "Patch defines zoneinfo initContainer"
  require_pattern "$PATCH_FILE" 'image: debian:12-slim@sha256:f06537653ac770703bc45b4b113475bd402f451e85223f0f2837acbf89ab020a' "Patch pins deterministic offline zoneinfo seed image"
  require_pattern "$PATCH_FILE" 'cp -a /usr/share/zoneinfo/\.\s*/zoneinfo/' "Patch seeds zoneinfo from bundled data"
  require_pattern "$PATCH_FILE" 'name: PYTHONTZPATH' "Patch sets PYTHONTZPATH env var"
  require_pattern "$PATCH_FILE" 'name: TZ' "Patch sets TZ env var"
  require_pattern "$PATCH_FILE" 'value: UTC' "Patch enforces UTC timezone"
  require_pattern "$PATCH_FILE" 'mountPath: /zoneinfo' "Patch mounts zoneinfo path"
  require_pattern "$PATCH_FILE" 'emptyDir: \{\}' "Patch defines ephemeral zoneinfo volume"
  require_pattern "$PATCH_FILE" 'runAsUser: 0' "Patch runs initContainer as root so apk can write"
  require_pattern "$PATCH_FILE" 'runAsNonRoot: false' "Patch explicitly allows root initContainer"
  if grep -qF '|| true' "$PATCH_FILE"; then
    fail "Patch does not swallow zoneinfo initContainer failures"
  else
    pass "Patch does not swallow zoneinfo initContainer failures"
  fi
  if grep -qF 'apk add --no-cache tzdata' "$PATCH_FILE"; then
    fail "Patch does not depend on live package installation"
  else
    pass "Patch does not depend on live package installation"
  fi
fi

if [[ -f "$KUSTOMIZATION_FILE" ]]; then
  require_pattern "$KUSTOMIZATION_FILE" 'patches/credentials-zoneinfo.yaml' "Base kustomization wires credentials zoneinfo patch"
fi

if command -v kubectl >/dev/null 2>&1; then
  rendered="$(kubectl kustomize "$REPO_ROOT/deploy/k8s/base")"
  rendered_credentials="$(
    printf '%s' "$rendered" | python3 -c 'import sys
for doc in sys.stdin.read().split("\n---\n"):
    if "kind: Deployment" in doc and "\n  name: credentials\n" in doc:
        print(doc)
        break'
  )"

  if [[ -z "$rendered_credentials" ]]; then
    fail "Rendered manifests missing credentials Deployment"
  elif grep -q 'name: seed-zoneinfo' <<<"$rendered_credentials"; then
    pass "Rendered manifests include zoneinfo initContainer"
  else
    fail "Rendered manifests missing zoneinfo initContainer"
  fi

  if grep -q 'cp -a /usr/share/zoneinfo/\.' <<<"$rendered_credentials"; then
    pass "Rendered manifests seed zoneinfo from bundled data"
  else
    fail "Rendered manifests missing bundled zoneinfo seed command"
  fi

  if grep -q 'name: PYTHONTZPATH' <<<"$rendered_credentials" && grep -q 'value: /zoneinfo' <<<"$rendered_credentials"; then
    pass "Rendered manifests include PYTHONTZPATH=/zoneinfo"
  else
    fail "Rendered manifests missing PYTHONTZPATH=/zoneinfo"
  fi

  if grep -q 'name: TZ' <<<"$rendered_credentials" && grep -q 'value: UTC' <<<"$rendered_credentials"; then
    pass "Rendered manifests include TZ=UTC"
  else
    fail "Rendered manifests missing TZ=UTC"
  fi

  if grep -q 'runAsUser: 0' <<<"$rendered_credentials" && grep -q 'runAsNonRoot: false' <<<"$rendered_credentials"; then
    pass "Rendered manifests run initContainer as root"
  else
    fail "Rendered manifests missing root initContainer override"
  fi

  if grep -qF '|| true' <<<"$rendered_credentials"; then
    fail "Rendered manifests still swallow zoneinfo initContainer failures"
  else
    pass "Rendered manifests fail loudly if zoneinfo seeding breaks"
  fi

  if grep -qF 'apk add --no-cache tzdata' <<<"$rendered_credentials"; then
    fail "Rendered manifests still depend on live package installation"
  else
    pass "Rendered manifests avoid live package installation"
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
