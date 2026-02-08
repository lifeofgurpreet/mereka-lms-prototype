#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/infra/resolve-image-digest.sh --image-ref IMAGE[:TAG|@DIGEST] [--output-key KEY]

Options:
  --image-ref REF   Required image reference to inspect.
  --output-key KEY  Optional key to append to $GITHUB_OUTPUT.
  -h, --help        Show this help.
EOF
}

IMAGE_REF=""
OUTPUT_KEY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image-ref)
      IMAGE_REF="${2:-}"
      shift 2
      ;;
    --output-key)
      OUTPUT_KEY="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$IMAGE_REF" ]]; then
  echo "--image-ref is required." >&2
  usage
  exit 1
fi

DIGEST="$(docker buildx imagetools inspect "$IMAGE_REF" --format '{{json .Manifest.Digest}}' | tr -d '"')"

if [[ ! "$DIGEST" =~ ^sha256:[0-9a-fA-F]{64}$ ]]; then
  echo "Failed to resolve valid digest for $IMAGE_REF: $DIGEST" >&2
  exit 1
fi

if [[ -n "$OUTPUT_KEY" ]]; then
  if [[ -z "${GITHUB_OUTPUT:-}" ]]; then
    echo "--output-key was provided but GITHUB_OUTPUT is not set." >&2
    exit 1
  fi
  echo "${OUTPUT_KEY}=${DIGEST}" >> "$GITHUB_OUTPUT"
fi

echo "$DIGEST"
