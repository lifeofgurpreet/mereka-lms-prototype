#!/usr/bin/env bash
# @covers AC-010, AC-011, AC-012
# @spec: slo-sla-service-level-management_spec.md
# One-shot deployment gate wrapper (world-state, not just manifests).
#
# Intended use:
# - run before promotion to prod
# - run after GitOps sync to validate runtime is healthy
#
# Usage:
#   CHECK_TIMEOUT_SECONDS=1200 ./scripts/qa/verify-deployment-gate.sh --env prod
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

ENV_SCOPE="prod"
if [[ "${1:-}" == "--env" ]]; then
  ENV_SCOPE="${2:-}"; shift 2
fi

CHECK_TIMEOUT_SECONDS="${CHECK_TIMEOUT_SECONDS:-1200}" ./scripts/qa/run-operations-gates.sh --env "$ENV_SCOPE"
echo "OK"

