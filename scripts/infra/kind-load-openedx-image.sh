#!/usr/bin/env bash
# @covers AC-003
# @spec: k8s-deployment_spec.md
# Load the Open edX and MFE images into kind nodes (dev cluster).
#
# Usage:
#   ./scripts/infra/kind-load-openedx-image.sh
#   IMAGE_REF=asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:TAG ./scripts/infra/kind-load-openedx-image.sh
#   MFE_IMAGE_REF=asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-mfe:TAG ./scripts/infra/kind-load-openedx-image.sh
#   CLUSTER=dev RESTART=1 ./scripts/infra/kind-load-openedx-image.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

CLUSTER="${CLUSTER:-dev}"
RESTART="${RESTART:-0}"

infer_image_ref() {
  local source_name="$1"
  local image_ref
  image_ref="$(
    awk -v source_name="$source_name" '
      $1=="-" && $2=="name:" {
        in_block=($3==source_name)
        next
      }
      in_block && $1=="newName:" {new_name=$2}
      in_block && $1=="newTag:" {
        if (new_name != "") {
          print new_name ":" $2
          exit
        }
      }
    ' "$REPO_ROOT/deploy/k8s/overlays/local/kustomization.yaml"
  )"
  if [[ -z "$image_ref" ]]; then
    echo "Failed to infer image ref for ${source_name} from deploy/k8s/overlays/local/kustomization.yaml" >&2
    exit 2
  fi
  echo "$image_ref"
}

OPENEDX_IMAGE_REF="${IMAGE_REF:-$(infer_image_ref "asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx")}"
MFE_IMAGE_REF="${MFE_IMAGE_REF:-$(infer_image_ref "docker.io/overhangio/openedx-mfe")}"

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

log "Target kind cluster: ${CLUSTER}"
log "Open edX image: ${OPENEDX_IMAGE_REF}"
log "MFE image: ${MFE_IMAGE_REF}"

if ! command -v kind >/dev/null 2>&1; then
  echo "kind is not installed or not on PATH" >&2
  exit 2
fi

if ! kind get clusters | grep -qx "${CLUSTER}"; then
  echo "kind cluster '${CLUSTER}' not found. Existing clusters:" >&2
  kind get clusters >&2 || true
  exit 2
fi

for image_ref in "${OPENEDX_IMAGE_REF}" "${MFE_IMAGE_REF}"; do
  if ! docker image inspect "${image_ref}" >/dev/null 2>&1; then
    log "Image not present locally, pulling ${image_ref}..."
    docker pull "${image_ref}"
  fi

  log "Loading image into kind nodes: ${image_ref}"
  kind load docker-image "${image_ref}" --name "${CLUSTER}"
done

if [[ "${RESTART}" == "1" ]]; then
  log "Restarting Open edX deployments in kind (best-effort)..."
  kubectl --context "kind-${CLUSTER}" -n mereka-lms rollout restart deployment/lms deployment/cms deployment/lms-worker deployment/cms-worker deployment/mfe || true
fi

log "OK"
