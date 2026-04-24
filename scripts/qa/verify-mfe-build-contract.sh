#!/usr/bin/env bash
# @covers AC-006
# @spec: tutor-configuration_spec.md
# Verify the MFE build contract after patches are applied.
#
# This is a light wrapper that reuses existing prereq checks and enforces the
# Node 24 rendered MFE build contract.
#
# Usage:
#   ./scripts/qa/verify-mfe-build-contract.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

source "$ROOT_DIR/scripts/shared/ci-skip-guards.sh"
require_tutor_env || exit 0

./scripts/qa/verify-mfe-build-prereqs.sh

dockerfile="tutor_env/env/plugins/mfe/build/mfe/Dockerfile"
if [[ ! -f "$dockerfile" ]]; then
  echo "[FAIL] Missing generated MFE Dockerfile: $dockerfile" >&2
  exit 1
fi

if rg -n "FROM.*node:24" "$dockerfile" >/dev/null 2>&1; then
  echo "OK"
  exit 0
fi

echo "[FAIL] Expected Node 24 base image in $dockerfile" >&2
exit 1
