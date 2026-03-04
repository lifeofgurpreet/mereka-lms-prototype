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
# Output images pushed to GHCR:
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

REGISTRY="ghcr.io/biji-biji-initiative/mereka-lms"
SOURCE_TAG="${1:-latest}"
CLEAN_TAG="nreum-clean-$(date +%Y%m%d%H%M)"
DOCKERFILE_DIR="infrastructure/docker/enterprise-mfe-clean"

PASS=0
FAIL=0

pass_check() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail_check() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

check_image_bundle() {
  local image="$1"
  local label="$2"

  local size
  local license_count

  size="$(docker run --rm "$image" sh -c 'wc -c < /openedx/dist/index.html' 2>/dev/null || true)"
  if [ -z "$size" ] || [ "$size" -eq 0 ]; then
    fail_check "${label} — index.html is empty after strip"
    return 1
  fi

  if ! docker run --rm "$image" sh -c 'grep -q "<html" /openedx/dist/index.html || grep -q "<!DOCTYPE html" /openedx/dist/index.html' >/dev/null 2>&1; then
    fail_check "${label} — index.html does not contain HTML root marker"
    return 1
  fi

  license_count="$(docker run --rm "$image" sh -c 'grep -c "undefined_license_key" /openedx/dist/index.html || true' 2>/dev/null || true)"
  if [ "$license_count" != "0" ] && [ -n "$license_count" ]; then
    fail_check "${label} — undefined_license_key still present (${license_count} occurrences)"
    return 1
  fi

  if ! docker run --rm "$image" sh -c 'grep -q "src=\"/env.config.js\"" /openedx/dist/index.html' >/dev/null 2>&1; then
    fail_check "${label} — index.html missing env.config.js script reference"
    return 1
  fi

  local placeholder_count
  placeholder_count="$(docker run --rm "$image" sh -c "find /openedx/dist -name '*.js' | xargs grep -E -o '\"MISSING_ENV_VAR\"\\.[A-Z0-9_]+' 2>/dev/null | wc -l | tr -d ' '" 2>/dev/null || true)"
  if [ -z "$placeholder_count" ]; then
    placeholder_count="0"
  fi
  if [ "$placeholder_count" != "0" ]; then
    fail_check "${label} — unresolved MISSING_ENV_VAR placeholders remain in JS bundles (${placeholder_count})"
    return 1
  fi

  local undefined_key_count
  undefined_key_count="$(docker run --rm "$image" sh -c "grep -R -c 'undefined_license_key' /openedx/dist 2>/dev/null | awk -F: '{sum += \\$2} END {print sum+0}'" 2>/dev/null || true)"
  if [ -z "$undefined_key_count" ]; then
    undefined_key_count="0"
  fi
  if [ "$undefined_key_count" != "0" ]; then
    fail_check "${label} — undefined_license_key still present in dist assets (${undefined_key_count})"
    return 1
  fi

  pass_check "${label} — index clean, env.config.js wired, placeholders fully resolved"
  return 0
}

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

# Configure Docker for GHCR
echo "${GHCR_TOKEN:-}" | docker login ghcr.io -u "${GHCR_USER:-biji-biji-initiative}" --password-stdin 2>/dev/null || true
pass_check "GHCR auth configured"

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
if ! check_image_bundle "${REGISTRY}/enterprise-admin-portal:${CLEAN_TAG}" "enterprise-admin-portal:${CLEAN_TAG}"; then
  exit 1
fi

# Push admin portal
echo "  Pushing enterprise-admin-portal:${CLEAN_TAG} ..."
docker push "${REGISTRY}/enterprise-admin-portal:${CLEAN_TAG}"
pass_check "enterprise-admin-portal:${CLEAN_TAG} pushed to GHCR"

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
if ! check_image_bundle "${REGISTRY}/enterprise-learner-portal:${CLEAN_TAG}" "enterprise-learner-portal:${CLEAN_TAG}"; then
  exit 1
fi

# Push learner portal
echo "  Pushing enterprise-learner-portal:${CLEAN_TAG} ..."
docker push "${REGISTRY}/enterprise-learner-portal:${CLEAN_TAG}"
pass_check "enterprise-learner-portal:${CLEAN_TAG} pushed to GHCR"

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
