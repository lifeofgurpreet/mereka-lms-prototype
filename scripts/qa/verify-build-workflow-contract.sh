#!/usr/bin/env bash
# @covers AC-CI-BUILD-001
# @spec: ci-cd-pipeline_spec.md
#
# Verify build-tutor-images.yml contract:
#   - Workflow exists and has required inputs
#   - Image push targets GHCR only
#   - Digest pinning used in kustomization
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO_ROOT="${REPO_ROOT_OVERRIDE:-$REPO_ROOT}"
BUILD_WF="${BUILD_WF_OVERRIDE:-$REPO_ROOT/.github/workflows/build-tutor-images.yml}"
RELEASE_BUNDLE_BLOCK="$(sed -n '/^  release-bundle:/,/^  update-gitops:/p' "$BUILD_WF")"

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

# Manual build-proof dispatches must skip release-bundle generation when the
# placeholder environment is still selected.
if echo "$RELEASE_BUNDLE_BLOCK" | grep -q "inputs.target_environment != 'select-environment'"; then
  pass "release bundle job skips placeholder manual environment"
else
  fail "release bundle job missing placeholder-environment skip gate"
fi

if echo "$RELEASE_BUNDLE_BLOCK" | grep -q "target_environment must be explicitly selected before generating a release bundle"; then
  fail "release bundle job still hard-fails on placeholder manual environment"
else
  pass "release bundle job no longer hard-fails on placeholder manual environment"
fi

# Release-bundle consistency must compare canonical lane names, not raw workflow aliases.
if grep -q "normalize_lane_to_canonical" "$BUILD_WF" && grep -q "scripts/lib/lane-normalize.sh" "$BUILD_WF"; then
  pass "release bundle consistency gate normalizes target_environment to canonical lane"
else
  fail "release bundle consistency gate missing canonical target_environment normalization"
fi

# Check container registry push target (GHCR only)
if grep -q "ghcr.io" "$BUILD_WF"; then
  pass "Container registry push target is GHCR"
else
  fail "Container registry push target missing (expected ghcr.io)"
fi

if grep -q "asia-southeast1-docker.pkg.dev" "$BUILD_WF"; then
  fail "Legacy GAR push target found (workflow must publish to GHCR only)"
else
  pass "No legacy GAR push targets remain"
fi

# Check permissions block
if grep -q "permissions:" "$BUILD_WF"; then
  pass "permissions block present"
else
  fail "permissions block missing"
fi

# Workflow path filter must include release/build scripts it executes.
required_trigger_paths=(
  "scripts/infra/**"
  "scripts/lib/**"
  "scripts/qa/verify-build-provenance.sh"
  "scripts/qa/verify-release-bundle.sh"
)
for trigger_path in "${required_trigger_paths[@]}"; do
  if grep -qF -- "$trigger_path" "$BUILD_WF"; then
    pass "workflow path filter includes $trigger_path"
  else
    fail "workflow path filter missing $trigger_path"
  fi
done

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
