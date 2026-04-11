#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/infra/build-openedx-image.sh \
    --context-dir <dir> \
    --dockerfile <path> \
    --image-repo <repo> \
    --primary-tag <tag> \
    --secondary-tag <tag> \
    --cache-ref <repo:tag> \
    [--build-profile <proof|fast>] \
    [--mutable-tag <tag>]
EOF
}

CONTEXT_DIR=""
DOCKERFILE=""
IMAGE_REPO=""
PRIMARY_TAG=""
SECONDARY_TAG=""
CACHE_REF=""
MUTABLE_TAG=""
BUILD_PROFILE="proof"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context-dir) CONTEXT_DIR="${2:-}"; shift 2 ;;
    --dockerfile) DOCKERFILE="${2:-}"; shift 2 ;;
    --image-repo) IMAGE_REPO="${2:-}"; shift 2 ;;
    --primary-tag) PRIMARY_TAG="${2:-}"; shift 2 ;;
    --secondary-tag) SECONDARY_TAG="${2:-}"; shift 2 ;;
    --cache-ref) CACHE_REF="${2:-}"; shift 2 ;;
    --build-profile) BUILD_PROFILE="${2:-}"; shift 2 ;;
    --mutable-tag) MUTABLE_TAG="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

for required in CONTEXT_DIR DOCKERFILE IMAGE_REPO PRIMARY_TAG SECONDARY_TAG CACHE_REF; do
  if [[ -z "${!required}" ]]; then
    echo "Missing required argument: ${required}" >&2
    usage >&2
    exit 1
  fi
done

if [[ ! -d "$CONTEXT_DIR" ]]; then
  echo "Context directory not found: $CONTEXT_DIR" >&2
  exit 1
fi

if [[ ! -f "$DOCKERFILE" ]]; then
  echo "Dockerfile not found: $DOCKERFILE" >&2
  exit 1
fi

case "$BUILD_PROFILE" in
  proof|fast) ;;
  *)
    echo "Unsupported build profile: $BUILD_PROFILE (expected proof or fast)" >&2
    exit 1
    ;;
esac

TAGS=(
  "--tag" "${IMAGE_REPO}:${PRIMARY_TAG}"
  "--tag" "${IMAGE_REPO}:${SECONDARY_TAG}"
)
if [[ -n "$MUTABLE_TAG" ]]; then
  TAGS+=("--tag" "${IMAGE_REPO}:${MUTABLE_TAG}")
fi

IMAGE_NAME="${IMAGE_REPO##*/}"
GHA_SCOPE="tutor-${IMAGE_NAME}-${BUILD_PROFILE}"

docker buildx build \
  --file "$DOCKERFILE" \
  "${TAGS[@]}" \
  --cache-from "type=gha,scope=${GHA_SCOPE}" \
  --cache-to "type=gha,mode=max,scope=${GHA_SCOPE}" \
  --cache-from "type=registry,ref=${CACHE_REF}" \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  --label "io.mereka.build-profile=${BUILD_PROFILE}" \
  --progress plain \
  --push \
  "$CONTEXT_DIR"
