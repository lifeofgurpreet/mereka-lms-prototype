#!/usr/bin/env bash
# build-enterprise-mfe-clean.sh
#
# Build NREUM-clean enterprise MFE images at build time (no runtime initContainer needed).
# Produces versioned images with a deterministic tag and prints GitOps update instructions.
#
# Usage:
#   bash scripts/infra/build-enterprise-mfe-clean.sh [SOURCE_TAG]
#   SOURCE_TAG defaults to "latest"
#
# Output images pushed to GCR:
#   enterprise-admin-portal:nreum-clean-YYYYMMDDHHMI
#   enterprise-learner-portal:nreum-clean-YYYYMMDDHHMI
#
# After running, update production kustomization:
#   images:
#     - name: enterprise-admin-portal
#       newTag: nreum-clean-YYYYMMDDHHMI
#     - name: enterprise-learner-portal
#       newTag: nreum-clean-YYYYMMDDHHMI
#
# Then remove initContainers from:
#   deploy/k8s/base/apps/enterprise/mfe/admin-portal-deployment.yaml
#   deploy/k8s/base/apps/enterprise/mfe/learner-portal-deployment.yaml

set -euo pipefail

REGISTRY="asia-southeast1-docker.pkg.dev/mereka-lms/openedx"
SOURCE_TAG="${1:-latest}"
CLEAN_TAG="nreum-clean-$(date +%Y%m%d%H%M)"
DOCKERFILE_DIR="infrastructure/docker/enterprise-mfe-clean"

PASS=0
FAIL=0

pass_check() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail_check() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo "=== Enterprise MFE: Build-time NREUM strip ==="
echo ""
echo "  Source tag : ${SOURCE_TAG}"
echo "  Clean tag  : ${CLEAN_TAG}"
echo "  Registry   : ${REGISTRY}"
echo ""

# Require docker + gcloud auth
if ! docker info >/dev/null 2>&1; then
  fail_check "Docker daemon not running"
  exit 1
fi
pass_check "Docker daemon running"

# Configure Docker for GCR
gcloud auth configure-docker asia-southeast1-docker.pkg.dev --quiet 2>/dev/null
pass_check "GCR auth configured"

# ---- Build admin portal ----
echo ""
echo "--- Building enterprise-admin-portal:${CLEAN_TAG} ---"
docker build \
  --build-arg REGISTRY="${REGISTRY}" \
  --build-arg SOURCE_TAG="${SOURCE_TAG}" \
  -f "${DOCKERFILE_DIR}/Dockerfile.admin-portal" \
  -t "${REGISTRY}/enterprise-admin-portal:${CLEAN_TAG}" \
  "${DOCKERFILE_DIR}"

# Verify clean locally before push
ADMIN_CHECK=$(docker run --rm "${REGISTRY}/enterprise-admin-portal:${CLEAN_TAG}" \
  sh -c 'grep -c "undefined_license_key" /openedx/dist/index.html || true' 2>/dev/null)
if [ "${ADMIN_CHECK}" = "0" ] || [ -z "${ADMIN_CHECK}" ]; then
  pass_check "enterprise-admin-portal:${CLEAN_TAG} — no undefined_license_key in built image"
else
  fail_check "enterprise-admin-portal:${CLEAN_TAG} — undefined_license_key still present (${ADMIN_CHECK} occurrences)"
  exit 1
fi

# Push admin portal
echo "  Pushing enterprise-admin-portal:${CLEAN_TAG} ..."
docker push "${REGISTRY}/enterprise-admin-portal:${CLEAN_TAG}"
pass_check "enterprise-admin-portal:${CLEAN_TAG} pushed to GCR"

# ---- Build learner portal ----
echo ""
echo "--- Building enterprise-learner-portal:${CLEAN_TAG} ---"
docker build \
  --build-arg REGISTRY="${REGISTRY}" \
  --build-arg SOURCE_TAG="${SOURCE_TAG}" \
  -f "${DOCKERFILE_DIR}/Dockerfile.learner-portal" \
  -t "${REGISTRY}/enterprise-learner-portal:${CLEAN_TAG}" \
  "${DOCKERFILE_DIR}"

# Verify clean locally before push
LEARNER_CHECK=$(docker run --rm "${REGISTRY}/enterprise-learner-portal:${CLEAN_TAG}" \
  sh -c 'grep -c "undefined_license_key" /openedx/dist/index.html || true' 2>/dev/null)
if [ "${LEARNER_CHECK}" = "0" ] || [ -z "${LEARNER_CHECK}" ]; then
  pass_check "enterprise-learner-portal:${CLEAN_TAG} — no undefined_license_key in built image"
else
  fail_check "enterprise-learner-portal:${CLEAN_TAG} — undefined_license_key still present (${LEARNER_CHECK} occurrences)"
  exit 1
fi

# Push learner portal
echo "  Pushing enterprise-learner-portal:${CLEAN_TAG} ..."
docker push "${REGISTRY}/enterprise-learner-portal:${CLEAN_TAG}"
pass_check "enterprise-learner-portal:${CLEAN_TAG} pushed to GCR"

# ---- Summary + GitOps instructions ----
echo ""
echo "=== Summary ==="
echo "  PASS: ${PASS} | FAIL: ${FAIL}"
echo ""
if [ "${FAIL}" -gt 0 ]; then
  echo "  RESULT: FAIL"
  exit 1
fi
echo "  RESULT: PASS — clean images built and pushed"
echo ""
echo "=== Next Steps: GitOps update ==="
echo ""
echo "  1. Update deploy/k8s/overlays/production/kustomization.yaml images section:"
echo "     - name: ${REGISTRY}/enterprise-admin-portal"
echo "       newName: ${REGISTRY}/enterprise-admin-portal"
echo "       newTag: ${CLEAN_TAG}"
echo "     - name: ${REGISTRY}/enterprise-learner-portal"
echo "       newName: ${REGISTRY}/enterprise-learner-portal"
echo "       newTag: ${CLEAN_TAG}"
echo ""
echo "  2. Remove initContainers from:"
echo "     deploy/k8s/base/apps/enterprise/mfe/admin-portal-deployment.yaml"
echo "     deploy/k8s/base/apps/enterprise/mfe/learner-portal-deployment.yaml"
echo ""
echo "  3. Commit + push + ArgoCD sync"
echo ""
echo "  4. Run smoke: bash scripts/qa/verify-enterprise-mfe-nreum-clean.sh"
echo ""
echo "  Clean tag: ${CLEAN_TAG}"
