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
    [--output-mode <push|docker>] \
    [--local-defaults] \
    [--mutable-tag <tag>]

Examples:
  scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast
  scripts/infra/build-openedx-image.sh --local-defaults --build-profile proof
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
OUTPUT_MODE="push"
LOCAL_DEFAULTS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context-dir) CONTEXT_DIR="${2:-}"; shift 2 ;;
    --dockerfile) DOCKERFILE="${2:-}"; shift 2 ;;
    --image-repo) IMAGE_REPO="${2:-}"; shift 2 ;;
    --primary-tag) PRIMARY_TAG="${2:-}"; shift 2 ;;
    --secondary-tag) SECONDARY_TAG="${2:-}"; shift 2 ;;
    --cache-ref) CACHE_REF="${2:-}"; shift 2 ;;
    --build-profile) BUILD_PROFILE="${2:-}"; shift 2 ;;
    --output-mode) OUTPUT_MODE="${2:-}"; shift 2 ;;
    --local-defaults) LOCAL_DEFAULTS=1; OUTPUT_MODE="docker"; shift ;;
    --mutable-tag) MUTABLE_TAG="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ "$LOCAL_DEFAULTS" == "1" ]]; then
  CONTEXT_DIR="${CONTEXT_DIR:-tutor_env/env/build/openedx}"
  DOCKERFILE="${DOCKERFILE:-tutor_env/env/build/openedx/Dockerfile}"
  IMAGE_REPO="${IMAGE_REPO:-openedx}"
  PRIMARY_TAG="${PRIMARY_TAG:-nightly}"
  SECONDARY_TAG="${SECONDARY_TAG:-nightly-${BUILD_PROFILE}}"
fi

REQUIRED_ARGS=(CONTEXT_DIR DOCKERFILE IMAGE_REPO PRIMARY_TAG SECONDARY_TAG)
if [[ "$OUTPUT_MODE" == "push" ]]; then
  REQUIRED_ARGS+=(CACHE_REF)
fi

for required in "${REQUIRED_ARGS[@]}"; do
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

CONTEXT_DIR_ABS="$(cd "$CONTEXT_DIR" && pwd)"
DOCKERFILE_ABS="$(cd "$(dirname "$DOCKERFILE")" && pwd)/$(basename "$DOCKERFILE")"
if [[ "$DOCKERFILE_ABS" == "$CONTEXT_DIR_ABS/"* ]]; then
  DOCKERFILE_RELATIVE="${DOCKERFILE_ABS#"$CONTEXT_DIR_ABS"/}"
else
  echo "Dockerfile must live under the build context for Bake-backed execution: $DOCKERFILE" >&2
  exit 1
fi

case "$BUILD_PROFILE" in
  proof|fast) ;;
  *)
    echo "Unsupported build profile: $BUILD_PROFILE (expected proof or fast)" >&2
    exit 1
    ;;
esac

case "$OUTPUT_MODE" in
  push|docker) ;;
  *)
    echo "Unsupported output mode: $OUTPUT_MODE (expected push or docker)" >&2
    exit 1
    ;;
esac

if [[ "$BUILD_PROFILE" == "fast" && -n "$MUTABLE_TAG" ]]; then
  echo "Fast build profile cannot publish mutable tags; use proof for promotable builds." >&2
  exit 1
fi

IMAGE_TAGS=(
  "${IMAGE_REPO}:${PRIMARY_TAG}"
  "${IMAGE_REPO}:${SECONDARY_TAG}"
)
if [[ -n "$MUTABLE_TAG" ]]; then
  IMAGE_TAGS+=("${IMAGE_REPO}:${MUTABLE_TAG}")
fi

IMAGE_NAME="${IMAGE_REPO##*/}"
GHA_SCOPE="tutor-${IMAGE_NAME}-${BUILD_PROFILE}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BAKE_FILE="$REPO_ROOT/docker-bake.hcl"
BAKE_TARGET="openedx-${BUILD_PROFILE}"
TAGS_CSV="$(IFS=,; printf '%s' "${IMAGE_TAGS[*]}")"
LOCAL_CACHE_ROOT="$REPO_ROOT/.buildx-cache"

if [[ ! -f "$BAKE_FILE" ]]; then
  echo "Bake file not found: $BAKE_FILE" >&2
  exit 1
fi

# Keep local cache imports quiet and deterministic for developer-mode builds.
# buildx warns if the configured local src path does not exist yet.
mkdir -p "$LOCAL_CACHE_ROOT/openedx"

BAKE_ENV=(
  "OPENEDX_CONTEXT=${CONTEXT_DIR}"
  "OPENEDX_DOCKERFILE=${DOCKERFILE_RELATIVE}"
  "OPENEDX_${BUILD_PROFILE^^}_TAGS=${TAGS_CSV}"
)
if [[ -n "$CACHE_REF" ]]; then
  BAKE_ENV+=("OPENEDX_CACHE_REF=${CACHE_REF}")
fi
if [[ "$BUILD_PROFILE" == "proof" ]]; then
  BAKE_ENV+=("OPENEDX_PROOF_GHA_SCOPE=${GHA_SCOPE}")
fi
# Shared registry cache export — only propagated when CACHE_TO_OPENEDX is set
# (trusted main builds set this; all others leave it empty = no cache export)
# See docs/ops/ci-cd/CACHE_AUTHORITY.md and RFC-BUILD-AUTHORITY-001 §Cache Write Policy
if [[ -n "${CACHE_TO_OPENEDX:-}" ]]; then
  BAKE_ENV+=("CACHE_TO_OPENEDX=${CACHE_TO_OPENEDX}")
fi

if [[ "$OUTPUT_MODE" == "push" ]]; then
  printf 'env'
  printf ' %q' "${BAKE_ENV[@]}"
  printf ' docker buildx bake --file %q --progress plain --push %q\n' "$BAKE_FILE" "$BAKE_TARGET"

  env "${BAKE_ENV[@]}" \
    docker buildx bake \
      --file "$BAKE_FILE" \
      --progress plain \
      --push \
      "$BAKE_TARGET"
else
  printf 'env'
  printf ' %q' "${BAKE_ENV[@]}"
  printf ' docker buildx bake --file %q --progress plain %q\n' "$BAKE_FILE" "$BAKE_TARGET"

  env "${BAKE_ENV[@]}" \
    docker buildx bake \
      --file "$BAKE_FILE" \
      --progress plain \
      "$BAKE_TARGET"
fi
