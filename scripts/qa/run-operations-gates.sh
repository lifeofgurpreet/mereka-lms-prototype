#!/usr/bin/env bash
# Unified operations gate for auth + multisite + observability + Velero posture.
#
# Usage:
#   ./scripts/qa/run-operations-gates.sh
#   ./scripts/qa/run-operations-gates.sh --env prod
#   RUN_ATLAS_ALLOWLIST_AUDIT=1 ./scripts/qa/run-operations-gates.sh --env both
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

ENV_SCOPE="${ENV_SCOPE:-both}"
STRICT_RUNTIME="${STRICT_RUNTIME:-1}"
RUN_ATLAS_ALLOWLIST_AUDIT="${RUN_ATLAS_ALLOWLIST_AUDIT:-0}"
RUN_ALERT_ROUTING_AUDIT="${RUN_ALERT_ROUTING_AUDIT:-0}"
ALERT_ROUTING_RUN_ATLAS_VPS_AUDIT="${ALERT_ROUTING_RUN_ATLAS_VPS_AUDIT:-1}"
CHECK_TIMEOUT_SECONDS="${CHECK_TIMEOUT_SECONDS:-1200}"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
ARTIFACT_DIR="${ARTIFACT_DIR:-var/operations-gates/${STAMP}}"
mkdir -p "$ARTIFACT_DIR"

usage() {
  cat <<'EOF'
Usage: ./scripts/qa/run-operations-gates.sh [--env prod|dev|both]
Env:
  STRICT_RUNTIME=1               Enforce strict runtime checks for observability/Velero
  RUN_ATLAS_ALLOWLIST_AUDIT=1    Also run VPS Atlas allowlist monitor audit
  RUN_ALERT_ROUTING_AUDIT=1      Also run one-command alert routing verification
  ALERT_ROUTING_RUN_ATLAS_VPS_AUDIT=0  Skip VPS-only atlas routing check inside alert-routing audit
  CHECK_TIMEOUT_SECONDS=1200      Per-check timeout in seconds
  ARTIFACT_DIR=var/...            Directory for per-check logs
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_SCOPE="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ "$ENV_SCOPE" != "prod" && "$ENV_SCOPE" != "dev" && "$ENV_SCOPE" != "both" ]]; then
  echo "Invalid --env: $ENV_SCOPE" >&2
  usage
  exit 1
fi

failures=0

run_check() {
  local name="$1"; shift
  local out_file rc out slug timed_out
  slug="$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  out_file="${ARTIFACT_DIR}/${slug}.log"
  timed_out=0

  set +e
  if command -v timeout >/dev/null 2>&1; then
    timeout "${CHECK_TIMEOUT_SECONDS}s" "$@" >"$out_file" 2>&1
  else
    "$@" >"$out_file" 2>&1
  fi
  rc=$?
  set -e
  out="$(cat "$out_file")"

  if [[ "$rc" -eq 124 ]]; then
    timed_out=1
  fi

  if [[ "$rc" -eq 0 ]]; then
    echo "OK   $name"
  else
    failures=$((failures + 1))
    if [[ "$timed_out" -eq 1 ]]; then
      echo "FAIL $name (timed out after ${CHECK_TIMEOUT_SECONDS}s)"
    else
      echo "FAIL $name"
    fi
    if [[ -n "$out" ]]; then
      echo "$out" | sed 's/^/  /'
    fi
    echo "  log: $out_file"
  fi
}

echo "Operations gates"
echo "  env: $ENV_SCOPE"
echo "  strict_runtime: $STRICT_RUNTIME"
echo "  run_atlas_allowlist_audit: $RUN_ATLAS_ALLOWLIST_AUDIT"
echo "  run_alert_routing_audit: $RUN_ALERT_ROUTING_AUDIT"
echo "  alert_routing_run_atlas_vps_audit: $ALERT_ROUTING_RUN_ATLAS_VPS_AUDIT"
echo "  check_timeout_seconds: $CHECK_TIMEOUT_SECONDS"
echo "  artifact_dir: $ARTIFACT_DIR"
echo ""

run_check "auth + permissions + multisite audit" \
  ./scripts/qa/audit-auth-access.sh --mode all --env "$ENV_SCOPE"

run_check "atlas modulestore path guard" \
  env STRICT_RUNTIME="$STRICT_RUNTIME" ./scripts/qa/verify-atlas-modulestore-path.sh --mode all

run_check "observability runtime audit" \
  env STRICT_RUNTIME="$STRICT_RUNTIME" ./scripts/qa/audit-observability.sh --mode runtime

run_check "velero alert pipeline audit" \
  env STRICT_RUNTIME="$STRICT_RUNTIME" ./scripts/qa/audit-velero-alert-pipeline.sh

run_check "grafana dashboard coverage audit" \
  ./scripts/qa/audit-grafana-dashboard.sh --strict-required

if [[ "$RUN_ATLAS_ALLOWLIST_AUDIT" == "1" ]]; then
  run_check "atlas allowlist monitor audit (VPS)" \
    env STRICT_WEBHOOK=1 ./scripts/qa/audit-atlas-allowlist-monitor.sh
fi

if [[ "$RUN_ALERT_ROUTING_AUDIT" == "1" ]]; then
  run_check "alert routing verification" \
    env STRICT_RUNTIME="$STRICT_RUNTIME" STRICT_WEBHOOK=1 RUN_ATLAS_VPS_AUDIT="$ALERT_ROUTING_RUN_ATLAS_VPS_AUDIT" ./scripts/qa/verify-alert-routing.sh
fi

echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "OK"
else
  echo "FAILED ($failures checks failed)"
fi
echo "Logs: $ARTIFACT_DIR"

[[ "$failures" -eq 0 ]]
