#!/usr/bin/env bash
# build-credentials-image.sh
#
# Build a derivative credentials image that adds tzdata (and cryptography) on top
# of the upstream docker.io/overhangio/openedx-credentials image.
#
# The upstream image lacks the tzdata Python package, so ZoneInfo("UTC") fails at
# runtime on the deployed pod.  The Tutor plugin installs tzdata during local builds
# via credentials-dockerfile-post-python-requirements, but production uses the
# pre-built upstream image, so a wrapper image is required.
#
# Usage:
#   bash scripts/infra/build-credentials-image.sh [UPSTREAM_TAG]
#   UPSTREAM_TAG defaults to "21.0.0"
#
# Output image pushed to Artifact Registry:
#   asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-credentials:<UPSTREAM_TAG>-tzdata
#
# After running, update the credentials Deployment image reference:
#   deploy/k8s/base/deployments.yml  (credentials Deployment, image field)
# Change:
#   image: docker.io/overhangio/openedx-credentials:21.0.0
# To:
#   image: asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-credentials:21.0.0-tzdata

set -euo pipefail

REGISTRY="asia-southeast1-docker.pkg.dev/mereka-lms/openedx"
UPSTREAM_TAG="${1:-21.0.0}"
OUTPUT_TAG="${UPSTREAM_TAG}-tzdata"
DOCKERFILE_DIR="infrastructure/docker/credentials-tzdata"

PASS=0
FAIL=0

pass_check() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail_check() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo "=== Credentials image: tzdata fix ==="
echo ""
echo "  Upstream  : docker.io/overhangio/openedx-credentials:${UPSTREAM_TAG}"
echo "  Output    : ${REGISTRY}/openedx-credentials:${OUTPUT_TAG}"
echo ""

# Require docker daemon
if ! docker info >/dev/null 2>&1; then
  fail_check "Docker daemon not running"
  exit 1
fi
pass_check "Docker daemon running"

# Configure Docker for Artifact Registry
gcloud auth configure-docker asia-southeast1-docker.pkg.dev --quiet 2>/dev/null
pass_check "Artifact Registry auth configured"

# Build
echo ""
echo "--- Building openedx-credentials:${OUTPUT_TAG} ---"
docker build \
  --build-arg "UPSTREAM_TAG=${UPSTREAM_TAG}" \
  -f "${DOCKERFILE_DIR}/Dockerfile" \
  -t "${REGISTRY}/openedx-credentials:${OUTPUT_TAG}" \
  "${DOCKERFILE_DIR}"
pass_check "Image built: openedx-credentials:${OUTPUT_TAG}"

# Verify tzdata is present
echo ""
echo "--- Verifying tzdata is installed ---"
if docker run --rm "${REGISTRY}/openedx-credentials:${OUTPUT_TAG}" \
    python -c "import zoneinfo; zoneinfo.ZoneInfo('UTC'); print('ZoneInfo OK')" 2>&1 | grep -q "ZoneInfo OK"; then
  pass_check "ZoneInfo('UTC') resolves correctly"
else
  fail_check "ZoneInfo('UTC') failed — tzdata may not be installed"
  docker run --rm "${REGISTRY}/openedx-credentials:${OUTPUT_TAG}" \
    python -c "import zoneinfo; zoneinfo.ZoneInfo('UTC')" || true
fi

# Verify cryptography package
if docker run --rm "${REGISTRY}/openedx-credentials:${OUTPUT_TAG}" \
    python -c "import cryptography; print(cryptography.__version__)" >/dev/null 2>&1; then
  pass_check "cryptography package present"
else
  fail_check "cryptography package missing"
fi

# Push if checks pass
echo ""
if [ "${FAIL}" -gt 0 ]; then
  echo "=== Summary: PASS=${PASS} FAIL=${FAIL} ==="
  echo "  RESULT: FAIL — image NOT pushed"
  exit 1
fi

echo "--- Pushing ${REGISTRY}/openedx-credentials:${OUTPUT_TAG} ---"
docker push "${REGISTRY}/openedx-credentials:${OUTPUT_TAG}"
pass_check "Image pushed to Artifact Registry"

# Summary + GitOps instructions
echo ""
echo "=== Summary: PASS=${PASS} FAIL=${FAIL} ==="
echo "  RESULT: PASS"
echo ""
echo "=== Next Steps: GitOps update ==="
echo ""
echo "  1. Update the credentials Deployment image reference:"
echo "     File: deploy/k8s/base/deployments.yml"
echo "     Change:"
echo "       image: docker.io/overhangio/openedx-credentials:${UPSTREAM_TAG}"
echo "     To:"
echo "       image: ${REGISTRY}/openedx-credentials:${OUTPUT_TAG}"
echo ""
echo "  2. Commit and push:"
echo "     git add deploy/k8s/base/deployments.yml"
echo "     git commit -m 'fix(credentials): use tzdata-patched image for production'"
echo "     git push"
echo ""
echo "  3. Wait for ArgoCD to reconcile (or trigger manual sync)"
echo ""
echo "  4. Verify pod restarts without tzdata-related errors:"
echo "     kubectl logs -n mereka-lms -l app.kubernetes.io/name=credentials --tail=50"
echo ""
echo "  Built tag: ${OUTPUT_TAG}"
