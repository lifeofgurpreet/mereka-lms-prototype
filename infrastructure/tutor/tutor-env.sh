#!/usr/bin/env bash
# Helper to load the local Tutor environment variables. Source this file from the repo root.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export TUTOR_ROOT="$REPO_ROOT/tutor_env"
export OPENEDX_RELEASE="nightly"
if [ -d "$REPO_ROOT/.venv" ]; then
  # shellcheck disable=SC1090
  source "$REPO_ROOT/.venv/bin/activate"
else
  echo "Python virtualenv not found at $REPO_ROOT/.venv" >&2
  exit 1
fi
