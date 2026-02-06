#!/usr/bin/env bash
# Load the Open edX image into kind nodes (dev cluster) to avoid Artifact Registry auth failures.
#
# Usage:
#   ./scripts/infra/kind-load-openedx-image.sh
#   IMAGE_REF=asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:TAG ./scripts/infra/kind-load-openedx-image.sh
#   CLUSTER=dev RESTART=1 ./scripts/infra/kind-load-openedx-image.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

CLUSTER="${CLUSTER:-dev}"
RESTART="${RESTART:-0}"

default_image_ref() {
  # Parse the Open edX image tag from the local overlay (no yq dependency).
  local tag
  tag="$(
    awk '
      $1=="-" && $2=="name:" && $3=="asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx" {in_openedx=1; next}
      in_openedx && $1=="newTag:" {print $2; exit}
    ' "$REPO_ROOT/deploy/k8s/overlays/local/kustomization.yaml"
  )"
  if [[ -z "$tag" ]]; then
    echo "Failed to infer image tag from deploy/k8s/overlays/local/kustomization.yaml" >&2
    exit 2
  fi
  echo "asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:${tag}"
}

IMAGE_REF="${IMAGE_REF:-$(default_image_ref)}"

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

log "Target kind cluster: ${CLUSTER}"
log "Image: ${IMAGE_REF}"

if ! command -v kind >/dev/null 2>&1; then
  echo "kind is not installed or not on PATH" >&2
  exit 2
fi

if ! kind get clusters | grep -qx "${CLUSTER}"; then
  echo "kind cluster '${CLUSTER}' not found. Existing clusters:" >&2
  kind get clusters >&2 || true
  exit 2
fi

if ! docker image inspect "${IMAGE_REF}" >/dev/null 2>&1; then
  log "Image not present locally, pulling..."
  docker pull "${IMAGE_REF}"
fi

log "Loading image into kind nodes..."
kind load docker-image "${IMAGE_REF}" --name "${CLUSTER}"

if [[ "${RESTART}" == "1" ]]; then
  log "Restarting Open edX deployments in kind (best-effort)..."
  kubectl --context "kind-${CLUSTER}" -n mereka-lms rollout restart deployment/lms deployment/cms deployment/lms-worker deployment/cms-worker || true
fi

log "OK"
