#!/usr/bin/env bash
# @covers AC-BRAND-024, AC-BRAND-025
# @spec: oep48-brand-package_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEFAULT_IMAGE="${BRAND_RUNTIME_IMAGE:-tutor_local/openedx-mfe:latest}"
IMAGE="$DEFAULT_IMAGE"
ALLOW_MISSING_IMAGE=0

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }
warn() { WARN=$((WARN + 1)); echo "WARN: $*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      IMAGE="$2"
      shift 2
      ;;
    --allow-missing-image)
      ALLOW_MISSING_IMAGE=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

echo "=== OEP-48 Runtime Brand Package Verification ==="
echo "Image: $IMAGE"

if ! command -v docker >/dev/null 2>&1; then
  fail "docker is required for runtime verification"
  echo "=== Summary: PASS=${PASS} WARN=${WARN} FAIL=${FAIL} ==="
  exit 1
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  if [[ "$ALLOW_MISSING_IMAGE" -eq 1 ]]; then
    warn "Image not found: $IMAGE (allowed by --allow-missing-image)"
    echo "=== Summary: PASS=${PASS} WARN=${WARN} FAIL=${FAIL} ==="
    exit 0
  fi
  fail "Image not found: $IMAGE"
  echo "=== Summary: PASS=${PASS} WARN=${WARN} FAIL=${FAIL} ==="
  exit 1
fi

# AC-BRAND-024 / AC-BRAND-025: the runtime image resolves @edx/brand from
# node_modules and exposes the staged asset package without npm registry lookups.
if docker run --rm "$IMAGE" sh -lc '
set -euo pipefail
pkg_json="$(node -p "require.resolve(\"@edx/brand/package.json\")")"
pkg_dir="$(dirname "$pkg_json")"
pkg_name="$(node -p "require(\"$pkg_json\").name")"
test "$pkg_name" = "@edx/brand"
test -f "$pkg_dir/logo.js"
test -f "$pkg_dir/logo_white.png"
test -f "$pkg_dir/favicon.png"
' >/tmp/brand-assets.$$ 2>&1; then
  pass "AC-BRAND-024 runtime image resolves @edx/brand from node_modules"
  pass "AC-BRAND-025 runtime asset contract exposes logo.js, logo_white.png, and favicon.png"
else
  fail "AC-BRAND-024/025 runtime asset contract failed for resolved @edx/brand package"
fi

rm -f /tmp/brand-assets.$$
echo "=== Summary: PASS=${PASS} WARN=${WARN} FAIL=${FAIL} ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
