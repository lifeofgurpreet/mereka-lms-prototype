#!/usr/bin/env bash
# @covers AC-001, AC-002, AC-003, AC-004, AC-005, AC-TCR-004, AC-TCR-008
# @spec: tutor-configuration_spec.md
# @spec: tutor-configuration-resilience_spec.md
# Compatibility entrypoint for rendered Tutor verification.
#
# The source of truth is scripts/infra/verify-tutor-config.sh. Keep this QA path
# as a stable CI/manual entrypoint so older callers do not grow a second set of
# rendered-marker expectations.
#
# Usage:
#   ./scripts/qa/verify-tutor-patches.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

TUTOR_ROOT="${TUTOR_ROOT:-$ROOT_DIR/tutor_env}"
export TUTOR_ROOT

"$ROOT_DIR/scripts/qa/verify-tutor-patch-manifest-contract.sh"

if [[ ! -d "$TUTOR_ROOT/env" ]]; then
  echo "SKIP: Tutor env not found at $TUTOR_ROOT (set TUTOR_ROOT or run ./scripts/infra/tutor-config-save.sh)"
  exit 0
fi

exec "$ROOT_DIR/scripts/infra/verify-tutor-config.sh" "$@"
