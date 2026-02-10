#!/usr/bin/env bash
# Verify error budget instrumentation is present.
#
# This is intentionally conservative: true error budget math depends on live SLO queries.
# In local mode we validate the config/contracts exist; in runtime mode we run operations gates.
#
# Usage:
#   ./scripts/qa/verify-error-budget.sh --mode local
#   ./scripts/qa/verify-error-budget.sh --mode runtime
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
  # Contract: alert severity matrix exists + ops gates script exists.
  [[ -f "docs/operations/ALERT_SEVERITY_MATRIX.md" ]] || { echo "[FAIL] Missing docs/operations/ALERT_SEVERITY_MATRIX.md" >&2; exit 1; }
  [[ -x "scripts/qa/run-operations-gates.sh" ]] || { echo "[FAIL] Missing scripts/qa/run-operations-gates.sh" >&2; exit 1; }
  echo "OK"
  exit 0
fi

CHECK_TIMEOUT_SECONDS="${CHECK_TIMEOUT_SECONDS:-1200}" ./scripts/qa/run-operations-gates.sh --env prod
echo "OK"

