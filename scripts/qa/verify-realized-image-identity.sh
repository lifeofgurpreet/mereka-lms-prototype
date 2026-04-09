#!/usr/bin/env bash
# @covers AC-RELEASE-002
# @spec: cross-cutting-requirements_spec.md
set -euo pipefail

# verify-realized-image-identity.sh — Verify deployed image matches release object
#
# Implements the realization-before-runtime-proof gate (INV-002):
# "Live image hash must match release object before runtime proof is meaningful."
#
# Compares the running pod image digests against the release object's recorded
# digests. If they don't match, runtime proof is meaningless — you're proving
# the wrong build.
#
# Usage:
#   scripts/qa/verify-realized-image-identity.sh --release-object-json var/ci/release-object.json
#   scripts/qa/verify-realized-image-identity.sh --release-object-json var/ci/release-object.json \
#     --namespace mereka-lms-dev --context rke2-nonprod
#
# Requires: kubectl with cluster access

RELEASE_OBJECT_JSON=""
NAMESPACE="${NAMESPACE:-mereka-lms-dev}"
CONTEXT="${KUBE_CONTEXT:-rke2-nonprod}"
PASSES=0
FAILURES=0

pass() { echo "  [PASS] $*"; PASSES=$((PASSES + 1)); }
fail() { echo "  [FAIL] $*" >&2; FAILURES=$((FAILURES + 1)); }
skip() { echo "  [SKIP] $*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release-object-json) RELEASE_OBJECT_JSON="${2:-}"; shift 2 ;;
    --namespace) NAMESPACE="${2:-}"; shift 2 ;;
    --context) CONTEXT="${2:-}"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 --release-object-json <path> [--namespace <ns>] [--context <ctx>]"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

echo "=== Realized Image Identity Verification (INV-002) ==="
echo "Namespace: $NAMESPACE"
echo "Context:   $CONTEXT"

# ── Check 1: Release object provided and valid ──────────────────────
echo "--- Check 1: Release object ---"

if [[ -z "$RELEASE_OBJECT_JSON" ]]; then
  echo "ERROR: --release-object-json is required" >&2
  exit 2
fi

if [[ ! -f "$RELEASE_OBJECT_JSON" ]]; then
  echo "ERROR: Release object not found: $RELEASE_OBJECT_JSON" >&2
  exit 1
fi

# Extract expected digests from release object
EXPECTED_OPENEDX_DIGEST=$(python3 -c "
import json, sys
ro = json.load(open(sys.argv[1]))
images = ro.get('images', {})
openedx = images.get('openedx', {})
print(openedx.get('digest', ''))
" "$RELEASE_OBJECT_JSON" 2>/dev/null)

EXPECTED_MFE_DIGEST=$(python3 -c "
import json, sys
ro = json.load(open(sys.argv[1]))
images = ro.get('images', {})
mfe = images.get('mfe', {})
print(mfe.get('digest', ''))
" "$RELEASE_OBJECT_JSON" 2>/dev/null)

RELEASE_ID=$(python3 -c "
import json, sys
ro = json.load(open(sys.argv[1]))
print(ro.get('release_id', 'unknown'))
" "$RELEASE_OBJECT_JSON" 2>/dev/null)

echo "Release ID: $RELEASE_ID"

if [[ -z "$EXPECTED_OPENEDX_DIGEST" || -z "$EXPECTED_MFE_DIGEST" ]]; then
  fail "Release object missing image digests"
  echo "  openedx: ${EXPECTED_OPENEDX_DIGEST:-MISSING}"
  echo "  mfe:     ${EXPECTED_MFE_DIGEST:-MISSING}"
  echo ""
  echo "=== Summary: PASS=$PASSES FAIL=$FAILURES ==="
  exit 1
fi

pass "Release object has both image digests"
echo "  Expected openedx: ${EXPECTED_OPENEDX_DIGEST}"
echo "  Expected mfe:     ${EXPECTED_MFE_DIGEST}"

# ── Check 2: kubectl accessible ─────────────────────────────────────
echo "--- Check 2: Cluster access ---"

if ! kubectl --context "$CONTEXT" get namespace "$NAMESPACE" >/dev/null 2>&1; then
  skip "Cannot reach namespace $NAMESPACE on context $CONTEXT — skipping live checks"
  echo ""
  echo "=== Summary: PASS=$PASSES FAIL=$FAILURES ==="
  exit 0
fi

pass "Cluster accessible ($CONTEXT / $NAMESPACE)"

# ── Check 3: LMS deployment image matches ───────────────────────────
echo "--- Check 3: LMS image identity ---"

LIVE_LMS_IMAGE=$(kubectl --context "$CONTEXT" -n "$NAMESPACE" \
  get deployment lms -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "")

if [[ -z "$LIVE_LMS_IMAGE" ]]; then
  fail "Cannot read LMS deployment image (deployment 'lms' not found)"
else
  # Extract digest from image reference (name@sha256:...)
  if [[ "$LIVE_LMS_IMAGE" == *"@"* ]]; then
    LIVE_LMS_DIGEST="${LIVE_LMS_IMAGE##*@}"
  else
    LIVE_LMS_DIGEST="tag-only:${LIVE_LMS_IMAGE##*:}"
  fi

  if [[ "$LIVE_LMS_DIGEST" == "$EXPECTED_OPENEDX_DIGEST" ]]; then
    pass "LMS image digest matches release object"
  else
    fail "LMS image digest MISMATCH"
    echo "    Expected: $EXPECTED_OPENEDX_DIGEST"
    echo "    Live:     $LIVE_LMS_DIGEST"
    echo "    Image:    $LIVE_LMS_IMAGE"
  fi
fi

# ── Check 4: MFE deployment image matches ───────────────────────────
echo "--- Check 4: MFE image identity ---"

LIVE_MFE_IMAGE=$(kubectl --context "$CONTEXT" -n "$NAMESPACE" \
  get deployment mfe -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null \
  || kubectl --context "$CONTEXT" -n "$NAMESPACE" \
    get deployment caddy -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null \
  || echo "")

if [[ -z "$LIVE_MFE_IMAGE" ]]; then
  fail "Cannot read MFE deployment image (deployment 'mfe' or 'caddy' not found)"
else
  if [[ "$LIVE_MFE_IMAGE" == *"@"* ]]; then
    LIVE_MFE_DIGEST="${LIVE_MFE_IMAGE##*@}"
  else
    LIVE_MFE_DIGEST="tag-only:${LIVE_MFE_IMAGE##*:}"
  fi

  if [[ "$LIVE_MFE_DIGEST" == "$EXPECTED_MFE_DIGEST" ]]; then
    pass "MFE image digest matches release object"
  else
    fail "MFE image digest MISMATCH"
    echo "    Expected: $EXPECTED_MFE_DIGEST"
    echo "    Live:     $LIVE_MFE_DIGEST"
    echo "    Image:    $LIVE_MFE_IMAGE"
  fi
fi

# ── Summary ─────────────────────────────────────────────────────────
echo ""
echo "=== Summary: PASS=$PASSES FAIL=$FAILURES ==="

if [[ "$FAILURES" -gt 0 ]]; then
  echo ""
  echo "FAIL: Deployed images do not match release object."
  echo "Runtime proof is not meaningful until realization matches the release."
  exit 1
fi

echo "Realized image identity verified — safe to proceed with runtime proof."
