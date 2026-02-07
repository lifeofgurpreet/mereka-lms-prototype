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

usage() {
  cat <<'EOF'
Usage: ./scripts/qa/run-operations-gates.sh [--env prod|dev|both]
Env:
  STRICT_RUNTIME=1               Enforce strict runtime checks for observability/Velero
  RUN_ATLAS_ALLOWLIST_AUDIT=1    Also run VPS Atlas allowlist monitor audit
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
  local tmp rc out
  tmp="$(mktemp -t run-operations-gates.XXXXXX)"
  set +e
  "$@" >"$tmp" 2>&1
  rc=$?
  set -e
  out="$(cat "$tmp")"
  rm -f "$tmp"

  if [[ "$rc" -eq 0 ]]; then
    echo "OK   $name"
  else
    failures=$((failures + 1))
    echo "FAIL $name"
    if [[ -n "$out" ]]; then
      echo "$out" | sed 's/^/  /'
    fi
  fi
}

echo "Operations gates"
echo "  env: $ENV_SCOPE"
echo "  strict_runtime: $STRICT_RUNTIME"
echo "  run_atlas_allowlist_audit: $RUN_ATLAS_ALLOWLIST_AUDIT"
echo ""

run_check "auth + permissions + multisite audit" \
  ./scripts/qa/audit-auth-access.sh --mode all --env "$ENV_SCOPE"

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

echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "OK"
else
  echo "FAILED ($failures checks failed)"
fi

[[ "$failures" -eq 0 ]]

