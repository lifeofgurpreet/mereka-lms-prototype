#!/usr/bin/env bash
# @covers AC-017, AC-022
# @spec: slo-sla-service-level-management_spec.md
# Generate a lightweight SLA/SLO evidence bundle (repo-safe).
#
# This does NOT compute a true SLA (needs time-series + business rules), but it:
# - captures outputs of key gates into a timestamped artifact directory
# - keeps output deterministic and free of secrets
#
# Usage:
#   ./scripts/qa/generate-sla-report.sh --env prod
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

ENV_SCOPE="prod"
if [[ "${1:-}" == "--env" ]]; then
  ENV_SCOPE="${2:-}"; shift 2
fi

STAMP="$(date -u +%Y%m%d-%H%M%S)"
OUT_DIR="var/slo-sla/${STAMP}"
mkdir -p "$OUT_DIR"

{
  echo "# SLA Evidence Bundle"
  echo ""
  echo "- Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "- Env: $ENV_SCOPE"
  echo ""
} >"$OUT_DIR/README.md"

run() {
  local name="$1"; shift
  local out="$OUT_DIR/${name}.log"
  set +e
  "$@" >"$out" 2>&1
  rc=$?
  set -e
  echo "$rc" >"$OUT_DIR/${name}.rc"
}

run "auth-surfaces" ./scripts/qa/verify-auth-surfaces.sh "$ENV_SCOPE"
run "public-health" ./scripts/qa/public-health-check.sh "$ENV_SCOPE"
run "ops-gates" CHECK_TIMEOUT_SECONDS="${CHECK_TIMEOUT_SECONDS:-1200}" ./scripts/qa/run-operations-gates.sh --env "$ENV_SCOPE"

./scripts/qa/verify-sla-report-security.sh "$OUT_DIR"

echo "OK: $OUT_DIR"

