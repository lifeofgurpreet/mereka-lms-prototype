#!/usr/bin/env bash
# Verify the MFE build contract after patches are applied.
#
# This is a light wrapper that reuses existing prereq checks and enforces Node 18
# appears in the generated MFE Dockerfile.
#
# Usage:
#   ./scripts/qa/verify-mfe-build-contract.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

./scripts/qa/verify-mfe-build-prereqs.sh

dockerfile="tutor_env/env/plugins/mfe/build/mfe/Dockerfile"
if [[ ! -f "$dockerfile" ]]; then
  echo "[FAIL] Missing generated MFE Dockerfile: $dockerfile" >&2
  exit 1
fi

if rg -n "FROM.*node:18" "$dockerfile" >/dev/null 2>&1; then
  echo "OK"
  exit 0
fi

echo "[FAIL] Expected Node 18 base image in $dockerfile" >&2
exit 1

