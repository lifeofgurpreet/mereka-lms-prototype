#!/usr/bin/env bash
# @covers AC-009, AC-020
# @spec: ci-cd-pipeline_spec.md
# Verify SLSA-style build provenance and attestation for OCI images.
#
# Offline checks (default):
#   1. Workflow references cosign-installer action
#   2. Workflow contains 'cosign attest' step
#   3. Provenance artifact upload step exists
#   4. cosign-installer is pinned to a commit SHA
#   5. Provenance job has id-token: write permission
#
# Online checks (--online):
#   6. Latest openedx image has a cosign attestation
#   7. Latest mfe image has a cosign attestation
#
# Usage:
#   ./scripts/qa/verify-slsa-provenance.sh [--online]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

pass() { echo -e "${GREEN}OK${NC}   $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAILED=$((FAILED + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIPPED=$((SKIPPED + 1)); }

ONLINE=false
if [[ "${1:-}" == "--online" ]]; then
  ONLINE=true
fi

BUILD_WORKFLOW=".github/workflows/build-tutor-images.yml"
REGISTRY="ghcr.io/biji-biji-initiative/mereka-lms"

# ---------------------------------------------------------------------------
# Offline checks
# ---------------------------------------------------------------------------
echo "== Offline: SLSA provenance workflow checks =="

if [[ ! -f "$BUILD_WORKFLOW" ]]; then
  fail "Missing workflow: $BUILD_WORKFLOW"
  echo ""
  echo "PASSED=$PASSED FAILED=$FAILED SKIPPED=$SKIPPED"
  exit 1
fi

# 1. cosign-installer action referenced
WORKFLOW_CONTENT="$(< "$BUILD_WORKFLOW")"
if grep -q 'sigstore/cosign-installer@' <<< "$WORKFLOW_CONTENT"; then
  pass "Workflow references sigstore/cosign-installer"
else
  fail "Workflow does not reference sigstore/cosign-installer"
fi

# 2. cosign attest step
if grep -q 'cosign attest' <<< "$WORKFLOW_CONTENT"; then
  pass "Workflow contains 'cosign attest' command"
else
  fail "Workflow missing 'cosign attest' command"
fi

# 3. Provenance artifact upload
if grep -q 'slsa-provenance' <<< "$WORKFLOW_CONTENT"; then
  pass "Provenance artifact upload step exists (name: slsa-provenance)"
else
  fail "No provenance artifact upload step found"
fi

# 4. cosign-installer pinned to SHA (not floating tag)
if grep -E 'sigstore/cosign-installer@[0-9a-f]{40}' <<< "$WORKFLOW_CONTENT" >/dev/null; then
  pass "cosign-installer is pinned to commit SHA"
else
  fail "cosign-installer is NOT pinned to commit SHA"
fi

# 5. id-token: write permission for provenance job
# Look for the slsa-provenance job block and check for id-token
if grep -A 10 'slsa-provenance' <<< "$WORKFLOW_CONTENT" | grep -q 'id-token: write'; then
  pass "slsa-provenance job has id-token: write permission"
else
  fail "slsa-provenance job missing id-token: write permission"
fi

# 6. Provenance predicate type is slsaprovenance
if grep -q 'type slsaprovenance' <<< "$WORKFLOW_CONTENT"; then
  pass "Attestation predicate type is slsaprovenance"
else
  fail "Attestation predicate type is not slsaprovenance"
fi

# 7. Provenance JSON includes materials and subject
if grep -q '"materials"' <<< "$WORKFLOW_CONTENT" && grep -q '"subject"' <<< "$WORKFLOW_CONTENT"; then
  pass "Provenance predicate includes materials and subject fields"
else
  fail "Provenance predicate missing materials or subject fields"
fi

# ---------------------------------------------------------------------------
# Online checks (require cosign + registry access)
# ---------------------------------------------------------------------------
if [[ "$ONLINE" == "true" ]]; then
  echo ""
  echo "== Online: verify attestation on latest images =="

  if ! command -v cosign &>/dev/null; then
    skip "cosign not installed (required for online checks)"
    skip "openedx attestation verification"
    skip "mfe attestation verification"
  else
    for IMAGE_NAME in openedx mfe; do
      IMAGE_REF="${REGISTRY}/${IMAGE_NAME}:latest"
      # Try to get the latest tag; fall back to 'latest'
      if cosign verify-attestation \
        --type slsaprovenance \
        --certificate-oidc-issuer https://token.actions.githubusercontent.com \
        --certificate-identity-regexp 'https://github.com/Biji-Biji-Initiative/mereka-lms/' \
        "${IMAGE_REF}" >/dev/null 2>&1; then
        pass "${IMAGE_NAME} image has valid SLSA attestation"
      else
        fail "${IMAGE_NAME} image attestation verification failed (ref: ${IMAGE_REF})"
      fi
    done
  fi
else
  echo ""
  echo "(Run with --online to verify attestations on live images)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "PASSED=$PASSED FAILED=$FAILED SKIPPED=$SKIPPED"
if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
