#!/usr/bin/env bash
# verify-preview-redirect.sh
# Static verification of preview.academyv2.mereka.io redirect manifests (T048)
#
# Checks:
#   1. All expected manifest files exist
#   2. Deployment does not use :latest tag
#   3. Redirect URL points to academyv2.mereka.io/dashboard
#   4. ConfigMap contains required redirect HTML elements
#
# Usage:
#   ./scripts/qa/verify-preview-redirect.sh
#
# Returns:
#   0 — all checks pass
#   1 — one or more checks fail

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST_DIR="${REPO_ROOT}/deploy/k8s/base/apps/preview-redirect"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  echo -e "${GREEN}✓ PASS${NC}: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo -e "${RED}✗ FAIL${NC}: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

warn() {
  echo -e "${YELLOW}⚠ WARN${NC}: $1"
}

echo "Preview Redirect Manifest Verification"
echo "======================================="
echo ""

# ---------------------------------------------------------------------------
# Check 1: Required files exist
# ---------------------------------------------------------------------------
echo "Check 1: Required manifest files exist"

REQUIRED_FILES=(
  "configmap.yaml"
  "deployment.yaml"
  "service.yaml"
  "kustomization.yaml"
)

for f in "${REQUIRED_FILES[@]}"; do
  if [[ -f "${MANIFEST_DIR}/${f}" ]]; then
    pass "  ${f} exists"
  else
    fail "  ${f} missing at ${MANIFEST_DIR}/${f}"
  fi
done

echo ""

# ---------------------------------------------------------------------------
# Check 2: No :latest image tag in deployment
# ---------------------------------------------------------------------------
echo "Check 2: Deployment does not use :latest image tag"

DEPLOY="${MANIFEST_DIR}/deployment.yaml"

if [[ -f "${DEPLOY}" ]]; then
  if grep -q 'image:' "${DEPLOY}"; then
    if grep 'image:' "${DEPLOY}" | grep -q ':latest'; then
      fail "  deployment.yaml uses :latest tag (must use pinned tag)"
    else
      # Extract the image value for display
      image_line=$(grep 'image:' "${DEPLOY}" | head -1 | sed 's/^[[:space:]]*//')
      pass "  Deployment uses pinned tag — ${image_line}"
    fi
  else
    fail "  No image: field found in deployment.yaml"
  fi
else
  warn "  deployment.yaml not found — skipping image tag check"
fi

echo ""

# ---------------------------------------------------------------------------
# Check 3: Redirect URL targets academyv2.mereka.io/dashboard
# ---------------------------------------------------------------------------
echo "Check 3: Redirect URL points to academyv2.mereka.io/dashboard"

CONFIGMAP="${MANIFEST_DIR}/configmap.yaml"

if [[ -f "${CONFIGMAP}" ]]; then
  if grep -q 'academyv2.mereka.io/dashboard' "${CONFIGMAP}"; then
    pass "  ConfigMap contains redirect to academyv2.mereka.io/dashboard"
  else
    fail "  ConfigMap does not contain redirect URL academyv2.mereka.io/dashboard"
  fi
else
  warn "  configmap.yaml not found — skipping redirect URL check"
fi

echo ""

# ---------------------------------------------------------------------------
# Check 4: ConfigMap contains required HTML elements
# ---------------------------------------------------------------------------
echo "Check 4: ConfigMap HTML contains required elements"

if [[ -f "${CONFIGMAP}" ]]; then
  if grep -q 'meta http-equiv="refresh"' "${CONFIGMAP}"; then
    pass "  ConfigMap has meta refresh tag"
  else
    fail "  ConfigMap missing meta http-equiv=\"refresh\" redirect"
  fi

  if grep -q 'retired\|preview URL' "${CONFIGMAP}"; then
    pass "  ConfigMap explains that the preview URL has been retired"
  else
    fail "  ConfigMap missing explanation that preview URL is retired"
  fi

  if grep -q 'href.*academyv2.mereka.io/dashboard' "${CONFIGMAP}"; then
    pass "  ConfigMap has manual fallback link to dashboard"
  else
    fail "  ConfigMap missing manual fallback link to academyv2.mereka.io/dashboard"
  fi
else
  warn "  configmap.yaml not found — skipping HTML content checks"
fi

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "======================================="
echo "Summary"
echo "======================================="
echo -e "${GREEN}Passed: ${PASS_COUNT}${NC}"
echo -e "${RED}Failed: ${FAIL_COUNT}${NC}"

if [[ ${FAIL_COUNT} -gt 0 ]]; then
  exit 1
fi

exit 0
