#!/usr/bin/env bash
# @covers AC-001, AC-002, AC-003, AC-004, AC-005, AC-006
# @spec: slo-sla-service-level-management_spec.md
# Verify the SLI/SLO foundation exists (repo + optional runtime).
#
# Usage:
#   ./scripts/qa/verify-sli-foundation.sh --mode local
#   ./scripts/qa/verify-sli-foundation.sh --mode runtime
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
  # Ensure reliability alert contract exists in-repo.
  f="deploy/k8s/base/monitoring/prometheusrule-lms.yaml"
  if [[ ! -f "$f" ]]; then
    echo "[FAIL] Missing $f" >&2
    exit 1
  fi
  for alert in \
    OpenEdxCriticalDeploymentUnavailable \
    OpenEdxPodsPendingTooLong \
    OpenEdxCrashLoopingContainers \
    OpenEdxSyntheticOrBackupJobFailures; do
    rg -n "alert:\\s*${alert}\\b" "$f" >/dev/null 2>&1 || { echo "[FAIL] Missing alert in $f: $alert" >&2; exit 1; }
  done
  echo "OK"
  exit 0
fi

./scripts/qa/run-observability-first-class.sh --mode runtime
echo "OK"
