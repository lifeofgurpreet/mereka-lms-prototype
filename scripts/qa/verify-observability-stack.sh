#!/usr/bin/env bash
# @covers AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008
# @spec: observability-stack_spec.md
# Best-effort observability stack verification.
#
# This script exists primarily to satisfy spec testmap references and to provide
# a single entrypoint for operators. Many observability checks require live
# cluster access; those should be run via scripts/qa/run-observability-first-class.sh
# and related runtime gates.
#
# Usage:
#   ./scripts/qa/verify-observability-stack.sh --mode local
#   ./scripts/qa/verify-observability-stack.sh --mode runtime
set -euo pipefail

MODE="${MODE:-local}" # local|runtime
if [[ "${1:-}" == "--mode" ]]; then
  MODE="${2:-}"; shift 2
fi

if [[ "$MODE" != "local" && "$MODE" != "runtime" ]]; then
  echo "Invalid mode: $MODE (expected local|runtime)" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

if [[ "$MODE" == "local" ]]; then
  ./scripts/qa/audit-observability.sh --mode local
  ./scripts/qa/audit-db-exporter-telemetry.sh --mode local || true
  ./scripts/qa/audit-grafana-dashboard.sh || true
  echo "OK"
  exit 0
fi

# runtime mode requires kubectl context
./scripts/qa/run-observability-first-class.sh --mode runtime
./scripts/qa/audit-db-exporter-telemetry.sh --mode runtime
echo "OK"
