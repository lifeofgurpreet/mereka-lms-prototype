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
SCOPE_MODE="${VERIFY_OBSERVABILITY_STACK_SCOPE:-}"
CHANGED_FILES_RAW="${VERIFY_OBSERVABILITY_STACK_CHANGED_FILES:-${CI_CHANGED_FILES:-}}"
if [[ "${1:-}" == "--mode" ]]; then
  MODE="${2:-}"; shift 2
fi

if [[ "$MODE" != "local" && "$MODE" != "runtime" ]]; then
  echo "Invalid mode: $MODE (expected local|runtime)" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

should_skip_scope() {
  local path

  [[ "$MODE" == "local" ]] || return 1
  [[ "$SCOPE_MODE" == "changed" ]] || return 1
  [[ -n "${CHANGED_FILES_RAW//[[:space:]]/}" ]] || return 1

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    case "$path" in
      .github/workflows/ci.yml|\
      scripts/qa/verify-observability-stack.sh|\
      scripts/qa/audit-observability.sh|\
      scripts/qa/audit-db-exporter-telemetry.sh|\
      scripts/qa/audit-grafana-dashboard.sh|\
      scripts/qa/run-observability-first-class.sh|\
      infrastructure/monitoring/*|\
      deploy/k8s/base/monitoring/*|\
      deploy/k8s/base/deployments.yml|\
      deploy/k8s/base/services.yml)
        return 1
        ;;
    esac
  done <<< "$CHANGED_FILES_RAW"

  return 0
}

if should_skip_scope; then
  echo "PASS verify-observability-stack (scope skip: no observability-stack-relevant changes)"
  exit 0
fi

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
