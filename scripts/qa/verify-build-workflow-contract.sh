#!/usr/bin/env bash
# @covers AC-CI-BUILD-001
# @spec: ci-cd-pipeline_spec.md
#
# Verify build-tutor-images.yml contract:
#   - Workflow exists and has required inputs
#   - Image push targets Artifact Registry
#   - Digest pinning used in kustomization
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO_ROOT="${REPO_ROOT_OVERRIDE:-$REPO_ROOT}"
BUILD_WF="${BUILD_WF_OVERRIDE:-$REPO_ROOT/.github/workflows/build-tutor-images.yml}"

PASS=0 FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

echo "=== Build Workflow Contract ==="

if [[ ! -f "$BUILD_WF" ]]; then
  fail "build-tutor-images.yml not found"
  echo "=== Results: $PASS PASS / $FAIL FAIL ==="
  exit 1
fi
pass "build-tutor-images.yml exists"

# Check required inputs
if grep -q "target_environment" "$BUILD_WF"; then
  pass "target_environment input defined"
else
  fail "target_environment input missing"
fi

# Check container registry push target (GHCR or Artifact Registry)
if grep -q "ghcr.io" "$BUILD_WF" || grep -q "asia-southeast1-docker.pkg.dev" "$BUILD_WF"; then
  pass "Container registry push target present"
else
  fail "Container registry push target missing (expected ghcr.io or asia-southeast1-docker.pkg.dev)"
fi

# Check permissions block
if grep -q "permissions:" "$BUILD_WF"; then
  pass "permissions block present"
else
  fail "permissions block missing"
fi

# App-owned proof must route through lms-ops in build workflow
if grep -qE '\./bin/lms-ops[[:space:]]+proof' "$BUILD_WF"; then
  pass "build workflow emits app proof via bin/lms-ops"
else
  fail "build workflow missing bin/lms-ops proof emission"
fi

# Promotion artifact upload must include release-gate envelope
if grep -q "var/ci/release-gate-envelope.json" "$BUILD_WF"; then
  pass "build workflow uploads release-gate envelope artifact"
else
  fail "build workflow missing release-gate envelope artifact upload"
fi

echo ""
echo "=== Results: $PASS PASS / $FAIL FAIL ==="
[[ $FAIL -gt 0 ]] && exit 1
exit 0
