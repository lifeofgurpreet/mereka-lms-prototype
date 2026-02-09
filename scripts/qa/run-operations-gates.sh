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
FAIL_ON_LEGACY_MONGODB="${FAIL_ON_LEGACY_MONGODB:-1}"
FAIL_ON_LEGACY_MONGODB_SERVICE="${FAIL_ON_LEGACY_MONGODB_SERVICE:-0}"
RUN_ATLAS_ALLOWLIST_AUDIT="${RUN_ATLAS_ALLOWLIST_AUDIT:-0}"
RUN_ALERT_ROUTING_AUDIT="${RUN_ALERT_ROUTING_AUDIT:-1}"
ALERT_ROUTING_RUN_ATLAS_VPS_AUDIT="${ALERT_ROUTING_RUN_ATLAS_VPS_AUDIT:-1}"
RUN_MULTISITE_GOVERNANCE_AUDIT="${RUN_MULTISITE_GOVERNANCE_AUDIT:-1}"
RUN_DB_EXPORTER_TELEMETRY_AUDIT="${RUN_DB_EXPORTER_TELEMETRY_AUDIT:-1}"
DB_EXPORTER_AUDIT_MODE="${DB_EXPORTER_AUDIT_MODE:-local}" # local|runtime|all
RUN_SENTRY_WIRING_AUDIT="${RUN_SENTRY_WIRING_AUDIT:-0}"
SENTRY_AUDIT_MODE="${SENTRY_AUDIT_MODE:-local}" # local|runtime|all
RUN_AUTHENTICATED_SSO_CANARY="${RUN_AUTHENTICATED_SSO_CANARY:-0}"
AUTHENTICATED_SSO_CANARY_REQUIRE_SECRETS="${AUTHENTICATED_SSO_CANARY_REQUIRE_SECRETS:-0}"
CHECK_TIMEOUT_SECONDS="${CHECK_TIMEOUT_SECONDS:-1200}"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
ARTIFACT_DIR="${ARTIFACT_DIR:-var/operations-gates/${STAMP}}"
mkdir -p "$ARTIFACT_DIR"

usage() {
  cat <<'EOF'
Usage: ./scripts/qa/run-operations-gates.sh [--env prod|dev|both]
Env:
  STRICT_RUNTIME=1               Enforce strict runtime checks for observability/Velero
  FAIL_ON_LEGACY_MONGODB=1       Fail atlas gate if legacy mongodb Deployment exists
  FAIL_ON_LEGACY_MONGODB_SERVICE=1  Fail atlas gate if legacy mongodb Service exists
  RUN_ATLAS_ALLOWLIST_AUDIT=1    Also run VPS Atlas allowlist monitor audit
  RUN_ALERT_ROUTING_AUDIT=0      Skip one-command alert routing verification (enabled by default)
  ALERT_ROUTING_RUN_ATLAS_VPS_AUDIT=0  Skip VPS-only atlas routing check inside alert-routing audit
  RUN_MULTISITE_GOVERNANCE_AUDIT=0  Skip explicit multisite governance gate (enabled by default)
  RUN_DB_EXPORTER_TELEMETRY_AUDIT=0  Skip db exporter telemetry contract/runtime audit (enabled by default)
  DB_EXPORTER_AUDIT_MODE=local   Mode for db exporter audit: local|runtime|all
  RUN_SENTRY_WIRING_AUDIT=1      Run Sentry wiring contract/runtime audit
  SENTRY_AUDIT_MODE=local        Mode for sentry wiring audit: local|runtime|all
  RUN_AUTHENTICATED_SSO_CANARY=1 Run credentialed browser SSO canary check
  AUTHENTICATED_SSO_CANARY_REQUIRE_SECRETS=1  Fail if canary creds are missing
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
SUMMARY_TSV="${ARTIFACT_DIR}/checks.tsv"
SUMMARY_JSON="${ARTIFACT_DIR}/summary.json"
SUMMARY_MD="${ARTIFACT_DIR}/summary.md"
: >"$SUMMARY_TSV"

run_check() {
  local name="$1"; shift
  local out_file rc out slug timed_out start_ts
  slug="$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  out_file="${ARTIFACT_DIR}/${slug}.log"
  timed_out=0
  start_ts="$(date +%s)"

  set +e
  if command -v timeout >/dev/null 2>&1; then
    timeout "${CHECK_TIMEOUT_SECONDS}s" "$@" >"$out_file" 2>&1
  else
    "$@" >"$out_file" 2>&1
  fi
  rc=$?
  set -e
  out="$(cat "$out_file")"

  local status end_ts duration_s
  end_ts="$(date +%s)"
  duration_s=$((end_ts - start_ts))

  if [[ "$rc" -eq 124 ]]; then
    timed_out=1
  fi

  if [[ "$rc" -eq 0 ]]; then
    status="ok"
    echo "OK   $name"
  else
    status="fail"
    failures=$((failures + 1))
    if [[ "$timed_out" -eq 1 ]]; then
      status="timeout"
      echo "FAIL $name (timed out after ${CHECK_TIMEOUT_SECONDS}s)"
    else
      echo "FAIL $name"
    fi
    if [[ -n "$out" ]]; then
      echo "$out" | sed 's/^/  /'
    fi
    echo "  log: $out_file"
  fi

  printf "%s\t%s\t%s\t%s\t%s\n" "$name" "$status" "$rc" "$duration_s" "$out_file" >>"$SUMMARY_TSV"
}

write_summary_artifacts() {
  python3 - "$SUMMARY_TSV" "$SUMMARY_JSON" "$SUMMARY_MD" "$ENV_SCOPE" "$STRICT_RUNTIME" "$CHECK_TIMEOUT_SECONDS" <<'PY'
import json
import pathlib
import sys
from datetime import datetime, timezone

summary_tsv = pathlib.Path(sys.argv[1])
summary_json = pathlib.Path(sys.argv[2])
summary_md = pathlib.Path(sys.argv[3])
env_scope = sys.argv[4]
strict_runtime = sys.argv[5]
timeout_s = sys.argv[6]

checks = []
if summary_tsv.exists():
    for line in summary_tsv.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        name, status, rc, duration_s, log_file = line.split("\t", 4)
        checks.append(
            {
                "name": name,
                "status": status,
                "exit_code": int(rc),
                "duration_seconds": int(duration_s),
                "log": log_file,
            }
        )

total = len(checks)
ok = sum(1 for c in checks if c["status"] == "ok")
timeouts = sum(1 for c in checks if c["status"] == "timeout")
failed = sum(1 for c in checks if c["status"] != "ok")

payload = {
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "env_scope": env_scope,
    "strict_runtime": strict_runtime == "1",
    "check_timeout_seconds": int(timeout_s),
    "totals": {"checks": total, "ok": ok, "failed": failed, "timeouts": timeouts},
    "checks": checks,
}
summary_json.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

lines = []
lines.append("# Operations Gates Summary")
lines.append("")
lines.append(f"- Generated (UTC): `{payload['generated_at_utc']}`")
lines.append(f"- Env scope: `{env_scope}`")
lines.append(f"- Strict runtime: `{payload['strict_runtime']}`")
lines.append(f"- Timeout per check: `{timeout_s}s`")
lines.append(f"- Totals: `{ok} ok / {failed} failed` (timeouts: `{timeouts}`)")
lines.append("")
lines.append("| Check | Status | Duration (s) | Exit | Log |")
lines.append("|---|---|---:|---:|---|")
for c in checks:
    lines.append(
        f"| {c['name']} | {c['status']} | {c['duration_seconds']} | {c['exit_code']} | `{c['log']}` |"
    )
summary_md.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
}

echo "Operations gates"
echo "  env: $ENV_SCOPE"
echo "  strict_runtime: $STRICT_RUNTIME"
echo "  fail_on_legacy_mongodb: $FAIL_ON_LEGACY_MONGODB"
echo "  fail_on_legacy_mongodb_service: $FAIL_ON_LEGACY_MONGODB_SERVICE"
echo "  run_atlas_allowlist_audit: $RUN_ATLAS_ALLOWLIST_AUDIT"
echo "  run_alert_routing_audit: $RUN_ALERT_ROUTING_AUDIT"
echo "  alert_routing_run_atlas_vps_audit: $ALERT_ROUTING_RUN_ATLAS_VPS_AUDIT"
echo "  run_multisite_governance_audit: $RUN_MULTISITE_GOVERNANCE_AUDIT"
echo "  run_db_exporter_telemetry_audit: $RUN_DB_EXPORTER_TELEMETRY_AUDIT"
echo "  db_exporter_audit_mode: $DB_EXPORTER_AUDIT_MODE"
echo "  run_sentry_wiring_audit: $RUN_SENTRY_WIRING_AUDIT"
echo "  sentry_audit_mode: $SENTRY_AUDIT_MODE"
echo "  run_authenticated_sso_canary: $RUN_AUTHENTICATED_SSO_CANARY"
echo "  authenticated_sso_canary_require_secrets: $AUTHENTICATED_SSO_CANARY_REQUIRE_SECRETS"
echo "  check_timeout_seconds: $CHECK_TIMEOUT_SECONDS"
echo "  artifact_dir: $ARTIFACT_DIR"
echo ""

if [[ "$RUN_MULTISITE_GOVERNANCE_AUDIT" == "1" ]]; then
  run_check "multisite governance gate" \
    env STRICT=1 CHECK_TIMEOUT_SECONDS="$CHECK_TIMEOUT_SECONDS" \
    ./scripts/qa/run-multisite-governance-gates.sh --env "$ENV_SCOPE"
fi

if [[ "$RUN_DB_EXPORTER_TELEMETRY_AUDIT" == "1" ]]; then
  run_check "db exporter telemetry audit (${DB_EXPORTER_AUDIT_MODE})" \
    env STRICT_RUNTIME="$STRICT_RUNTIME" K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}" \
    ./scripts/qa/audit-db-exporter-telemetry.sh --mode "$DB_EXPORTER_AUDIT_MODE"
fi

if [[ "$RUN_SENTRY_WIRING_AUDIT" == "1" ]]; then
  run_check "sentry wiring audit (${SENTRY_AUDIT_MODE})" \
    env STRICT_RUNTIME="$STRICT_RUNTIME" K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}" \
    ./scripts/qa/verify-sentry-wiring.sh --mode "$SENTRY_AUDIT_MODE"
fi

if [[ "$RUN_AUTHENTICATED_SSO_CANARY" == "1" ]]; then
  run_check "authenticated SSO canary (${ENV_SCOPE})" \
    env REQUIRE_SECRETS="$AUTHENTICATED_SSO_CANARY_REQUIRE_SECRETS" \
    ./scripts/qa/verify-authenticated-sso-canary.sh --env "$ENV_SCOPE"
fi

run_check "auth + permissions + multisite audit" \
  env CHECK_TIMEOUT_SECONDS="$CHECK_TIMEOUT_SECONDS" ./scripts/qa/audit-auth-access.sh --mode all --env "$ENV_SCOPE"

run_check "gitops image override contract" \
  ./scripts/qa/verify-gitops-image-overrides.sh

run_check "atlas modulestore path guard" \
  env STRICT_RUNTIME="$STRICT_RUNTIME" FAIL_ON_LEGACY_MONGODB="$FAIL_ON_LEGACY_MONGODB" FAIL_ON_LEGACY_MONGODB_SERVICE="$FAIL_ON_LEGACY_MONGODB_SERVICE" ./scripts/qa/verify-atlas-modulestore-path.sh --mode all

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
    env STRICT_RUNTIME="$STRICT_RUNTIME" STRICT_WEBHOOK=1 RUN_ATLAS_VPS_AUDIT="$ALERT_ROUTING_RUN_ATLAS_VPS_AUDIT" CHECK_TIMEOUT_SECONDS="$CHECK_TIMEOUT_SECONDS" ./scripts/qa/verify-alert-routing.sh
fi

write_summary_artifacts

echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "OK"
else
  echo "FAILED ($failures checks failed)"
fi
echo "Logs: $ARTIFACT_DIR"
echo "Summary: $SUMMARY_MD"
echo "Summary JSON: $SUMMARY_JSON"

[[ "$failures" -eq 0 ]]
