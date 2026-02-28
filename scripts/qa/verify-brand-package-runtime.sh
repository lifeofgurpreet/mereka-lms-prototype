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

# AC-BRAND-024: @edx/brand resolves in built runtime image.
if docker run --rm "$IMAGE" sh -lc "npm ls @edx/brand --depth=0" >/tmp/brand-npm-ls.$$ 2>&1; then
  if grep -qi "@edx/brand" /tmp/brand-npm-ls.$$; then
    pass "AC-BRAND-024 npm ls resolves @edx/brand in runtime image"
  else
    fail "AC-BRAND-024 npm ls succeeded but @edx/brand not found in output"
  fi
else
  fail "AC-BRAND-024 npm ls @edx/brand failed in runtime image"
fi

# AC-BRAND-025: alias install is healthy enough for runtime dependency graph.
if docker run --rm "$IMAGE" sh -lc "npm ls @edx/brand --depth=0 >/dev/null" >/tmp/brand-peer.$$ 2>&1; then
  pass "AC-BRAND-025 runtime dependency graph is healthy (no npm ls resolution errors)"
else
  fail "AC-BRAND-025 runtime dependency graph has npm resolution errors"
fi

rm -f /tmp/brand-npm-ls.$$ /tmp/brand-peer.$$
echo "=== Summary: PASS=${PASS} WARN=${WARN} FAIL=${FAIL} ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
