#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_LIST="${SCRIPT_LIST:-$REPO_ROOT/.github/ci-scripts-static.txt}"
PARALLELISM="${PARALLELISM:-4}"
TIMEOUT_SECS="${TIMEOUT_SECS:-120}"

if [[ ! -f "$SCRIPT_LIST" ]]; then
  echo "Missing script list: $SCRIPT_LIST" >&2
  exit 1
fi

"$REPO_ROOT/.github/run-scripts-parallel.sh" "$SCRIPT_LIST" "$PARALLELISM" "$TIMEOUT_SECS"
