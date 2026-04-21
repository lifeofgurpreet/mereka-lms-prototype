#!/usr/bin/env bash
# Select a BuildKit builder that pulls Docker Hub dependencies through a mirror.
set -euo pipefail

BUILDER_NAME="${MEREKA_BUILDX_BUILDER:-mereka-dependency-mirror}"
DOCKERHUB_MIRROR="${MEREKA_DOCKERHUB_MIRROR:-mirror.gcr.io}"
BUILDKIT_IMAGE="${MEREKA_BUILDKIT_IMAGE:-mirror.gcr.io/moby/buildkit:buildx-stable-1}"
RECREATE="${MEREKA_RECREATE_BUILDX_MIRROR:-0}"

if ! docker buildx version >/dev/null 2>&1; then
  echo "docker buildx is required for local image builds." >&2
  exit 1
fi

CONFIG_FILE="$(mktemp "${TMPDIR:-/tmp}/mereka-buildkitd.XXXXXX.toml")"
trap 'rm -f "$CONFIG_FILE"' EXIT

cat >"$CONFIG_FILE" <<EOF
[registry."docker.io"]
  mirrors = ["$DOCKERHUB_MIRROR"]
EOF

if [[ "$RECREATE" == "1" ]]; then
  docker buildx rm "$BUILDER_NAME" >/dev/null 2>&1 || true
fi

if docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
  docker buildx use "$BUILDER_NAME" >/dev/null
else
  docker buildx create \
    --name "$BUILDER_NAME" \
    --driver docker-container \
    --driver-opt "image=$BUILDKIT_IMAGE" \
    --config "$CONFIG_FILE" \
    --use >/dev/null
fi

docker buildx inspect --bootstrap "$BUILDER_NAME" >/dev/null
echo "Buildx builder ready: $BUILDER_NAME (docker.io mirror: $DOCKERHUB_MIRROR)"
