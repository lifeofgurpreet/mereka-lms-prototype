#!/usr/bin/env bash
# @covers AC-RELEASE-001
# @spec: cross-cutting-requirements_spec.md
set -euo pipefail

# verify-proof-lineage-chain.sh — Verify the runtime proof chain is unbroken
#
# Statically verifies that the chain from build to runtime proof is wired:
#   release-object-schema projection → generator → bundle generator → workflow → proof gates
#
# Does NOT require cluster access. Proves the wiring exists, not the state.

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

passes=0
failures=0

pass() { echo "  [PASS] $*"; passes=$((passes + 1)); }
fail() { echo "  [FAIL] $*" >&2; failures=$((failures + 1)); }

echo "=== Proof Lineage Chain Verification ==="

# ── Link 1: Schema → Generator ──────────────────────────────────────
echo "--- Link 1: Release object schema projection → generator ---"

SCHEMA="$REPO_ROOT/schemas/release-object.schema.json"
GENERATOR="$REPO_ROOT/scripts/release/generate_release_object.py"

if [[ -f "$SCHEMA" ]]; then
  pass "release-object.schema.json exists"
else
  fail "release-object.schema.json missing"
fi

if [[ -f "$GENERATOR" ]]; then
  pass "generate_release_object.py exists"
  # Generator must consume the release bundle
  if grep -q 'release-bundle-json\|release_bundle' "$GENERATOR"; then
    pass "generator consumes release bundle"
  else
    fail "generator does not reference release bundle input"
  fi
  # Generator must produce standard fields used by the JSON schema projection.
  for field in release_id app_commit_sha images build_origin_environment promotion; do
    if grep -q "$field" "$GENERATOR"; then
      pass "generator produces $field"
    else
      fail "generator missing $field output"
    fi
  done
else
  fail "generate_release_object.py missing"
fi

# ── Link 2: Bundle generator → Release object generator ─────────────
echo "--- Link 2: Release bundle → release object ---"

BUNDLE_GEN="$REPO_ROOT/scripts/infra/generate-release-bundle.sh"
if [[ -f "$BUNDLE_GEN" ]]; then
  pass "generate-release-bundle.sh exists"
  # Bundle must produce image digests
  if grep -q 'digest\|sha256' "$BUNDLE_GEN"; then
    pass "bundle generator produces digests"
  else
    fail "bundle generator missing digest output"
  fi
else
  fail "generate-release-bundle.sh missing"
fi

# ── Link 3: Build workflow wiring ────────────────────────────────────
echo "--- Link 3: Build workflow → bundle → release object ---"

BUILD_WF="$REPO_ROOT/.github/workflows/build-tutor-images.yml"
if [[ -f "$BUILD_WF" ]]; then
  # Bundle generation job must exist
  if grep -q 'release-bundle:' "$BUILD_WF"; then
    pass "build workflow has release-bundle job"
  else
    fail "build workflow missing release-bundle job"
  fi
  # Release object generation must exist
  if grep -q 'generate_release_object\|release-object' "$BUILD_WF"; then
    pass "build workflow references release object generation"
  else
    fail "build workflow missing release object reference"
  fi
  # Bundle generator script must be referenced
  if grep -q 'generate-release-bundle.sh' "$BUILD_WF"; then
    pass "build workflow calls generate-release-bundle.sh"
  else
    fail "build workflow does not call generate-release-bundle.sh"
  fi
else
  fail "build-tutor-images.yml missing"
fi

# ── Link 4: Release workflow consumes release object ─────────────────
echo "--- Link 4: Release workflow → release object schema ---"

RELEASE_WF="$REPO_ROOT/.github/workflows/release.yml"
if [[ -f "$RELEASE_WF" ]]; then
  if grep -q 'schemas/release-object\.schema\.json\|release-object schema projection' "$RELEASE_WF"; then
    pass "release workflow validates release-object schema"
  else
    fail "release workflow does not reference release-object schema"
  fi
  # Promotion must depend on release job
  if grep -A5 'promote-to-production' "$RELEASE_WF" | grep -q 'needs:.*create-github-release'; then
    pass "promotion depends on release creation"
  else
    fail "promotion does not depend on release creation"
  fi
else
  fail "release.yml missing"
fi

# ── Link 5: Smoke workflow gates on live assets ──────────────────────
echo "--- Link 5: Smoke workflow → live-asset gate → runtime proof ---"

SMOKE_WF="$REPO_ROOT/.github/workflows/smoke-authenticated.yml"
if [[ -f "$SMOKE_WF" ]]; then
  if grep -q 'Live-asset gate' "$SMOKE_WF"; then
    pass "smoke workflow has live-asset gate"
  else
    fail "smoke workflow missing live-asset gate"
  fi
  if grep -A30 'Live-asset gate' "$SMOKE_WF" | grep -q 'exit 1'; then
    pass "live-asset gate is structural (exit 1)"
  else
    fail "live-asset gate is advisory (no exit 1)"
  fi
else
  fail "smoke-authenticated.yml missing"
fi

# ── Link 6: Proof gate contract covers the full chain ────────────────
echo "--- Link 6: Proof gate contract covers full chain ---"

PROOF_GATES="$REPO_ROOT/config/proof-gate-contract.yaml"
if [[ -f "$PROOF_GATES" ]]; then
  REQUIRED_GATES=(
    "release-object-before-promotion"
    "live-asset-before-canary"
    "realization-before-runtime-proof"
  )
  for gate in "${REQUIRED_GATES[@]}"; do
    if grep -q "$gate" "$PROOF_GATES"; then
      pass "proof-gate-contract has $gate"
    else
      fail "proof-gate-contract missing $gate"
    fi
  done
else
  fail "proof-gate-contract.yaml missing"
fi

# ── Link 7: Incident record schema exists ────────────────────────────
echo "--- Link 7: Incident records close the loop ---"

if [[ -d "$REPO_ROOT/config/incidents" ]]; then
  pass "incident records directory exists"
  incident_count=$(find "$REPO_ROOT/config/incidents" -name '*.yaml' | wc -l)
  if [[ "$incident_count" -gt 0 ]]; then
    pass "at least 1 incident record exists ($incident_count found)"
  else
    fail "no incident records found"
  fi
else
  fail "config/incidents/ directory missing"
fi

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo "=== Summary ==="
echo "PASS: $passes | FAIL: $failures"
echo ""

if [[ "$failures" -gt 0 ]]; then
  echo "Proof lineage chain has gaps."
  exit 1
fi

echo "Proof lineage chain is wired end-to-end."
echo "  schema projection → generator → bundle → workflow → release → promotion → smoke → proof gates → incidents"
