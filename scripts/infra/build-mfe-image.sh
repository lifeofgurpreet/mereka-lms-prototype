#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/infra/build-mfe-image.sh \
    --context-dir <dir> \
    --dockerfile <path> \
    --image-repo <repo> \
    --primary-tag <tag> \
    --secondary-tag <tag> \
    --cache-ref <repo:tag> \
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context-dir) CONTEXT_DIR="${2:-}"; shift 2 ;;
    --dockerfile) DOCKERFILE="${2:-}"; shift 2 ;;
    --image-repo) IMAGE_REPO="${2:-}"; shift 2 ;;
    --primary-tag) PRIMARY_TAG="${2:-}"; shift 2 ;;
    --secondary-tag) SECONDARY_TAG="${2:-}"; shift 2 ;;
    --cache-ref) CACHE_REF="${2:-}"; shift 2 ;;
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

build_failed_due_to_transient_github_fetch() {
  local log_path="$1"
  [[ -f "$log_path" ]] || return 1
  # Buildx logs can contain NUL bytes, so force text-mode matching.
  grep -aEq \
    'Could not resolve host: github\.com|DNS server returned answer with no data|failed to fetch remote https://github\.com/' \
    "$log_path"
}

TAGS=(
  "--tag" "${IMAGE_REPO}:${PRIMARY_TAG}"
  "--tag" "${IMAGE_REPO}:${SECONDARY_TAG}"
)
if [[ -n "$MUTABLE_TAG" ]]; then
  TAGS+=("--tag" "${IMAGE_REPO}:${MUTABLE_TAG}")
fi

# BUILDKIT_MAX_PARALLELISM — if exported by caller, buildkitd reads it directly.
# docker buildx build has no --opt flag; the env var is the correct mechanism.

max_attempts=2
attempt=1

while (( attempt <= max_attempts )); do
  attempt_log="var/ci/build-mfe-attempt-${attempt}.log"
  mkdir -p "$(dirname "$attempt_log")"

  if docker buildx build \
    --file "$DOCKERFILE" \
    "${TAGS[@]}" \
    --cache-from "type=gha" \
    --cache-to "type=gha,mode=max" \
    --cache-from "type=registry,ref=${CACHE_REF}" \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    --progress plain \
    --push \
    "$CONTEXT_DIR" \
    2>&1 | tee "$attempt_log"; then
    cp "$attempt_log" var/ci/build-mfe.log
    exit 0
  fi

  cp "$attempt_log" var/ci/build-mfe.log

  if (( attempt < max_attempts )) && build_failed_due_to_transient_github_fetch "$attempt_log"; then
    echo "Transient GitHub fetch failure detected during MFE build; retrying once..." >&2
    attempt=$((attempt + 1))
    sleep 5
    continue
  fi

  echo "MFE image build failed." >&2
  exit 1
done
