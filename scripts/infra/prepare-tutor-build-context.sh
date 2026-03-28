#!/usr/bin/env bash
# Canonical entrypoint for mutating rendered Tutor build context.
set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage:
  prepare-tutor-build-context.sh [--target all|openedx|mfe]
EOF
}

TARGET="${MEREKA_BUILD_TARGET:-all}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      TARGET="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

case "$TARGET" in
  all|openedx|mfe) ;;
  *)
    echo "Unsupported target: $TARGET" >&2
    usage
    exit 2
    ;;
esac

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PATCHES_SCRIPT="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"

if [[ ! -x "$PATCHES_SCRIPT" ]]; then
  echo "Canonical patch implementation missing or not executable: $PATCHES_SCRIPT" >&2
  exit 1
fi

exec "$PATCHES_SCRIPT" --target "$TARGET"
