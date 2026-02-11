#!/usr/bin/env bash
# @covers AC-003
# @spec: observability-stack_spec.md
# Audit MySQL/Redis exporter telemetry contract (repo + optional runtime).
#
# Usage:
#   ./scripts/qa/audit-db-exporter-telemetry.sh
#   ./scripts/qa/audit-db-exporter-telemetry.sh --mode runtime
#   STRICT_RUNTIME=1 ./scripts/qa/audit-db-exporter-telemetry.sh --mode all
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

MODE="local" # local | runtime | all
JSON_OUT=0
STRICT_RUNTIME="${STRICT_RUNTIME:-0}"
K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
APP_NS="${APP_NS:-mereka-lms}"
MON_NS="${MON_NS:-monitoring}"
PROM_LABEL="${PROM_LABEL:-app.kubernetes.io/name=prometheus}"

CHECK_NAMES=()
CHECK_OK=()
CHECK_CODE=()
CHECK_MSG=()
failures=0

usage() {
  cat <<'EOF' >&2
Usage: ./scripts/qa/audit-db-exporter-telemetry.sh [--mode local|runtime|all] [--json]
Env:
  STRICT_RUNTIME=1      Fail when runtime cluster is unreachable or runtime checks fail
  K8S_CONTEXT=...       Kubernetes context for runtime checks
  APP_NS=mereka-lms     Application namespace
  MON_NS=monitoring     Monitoring namespace
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="${2:-}"; shift 2 ;;
    --json) JSON_OUT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ "$MODE" != "local" && "$MODE" != "runtime" && "$MODE" != "all" ]]; then
  echo "Invalid --mode: $MODE" >&2
  usage
  exit 1
fi

json_escape() {
  local s="${1:-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  printf "%s" "$s"
}

run_check() {
  local name="$1"; shift
  local tmp
  tmp="$(mktemp -t audit-db-exporter.XXXXXX)"

  set +e
  "$@" >"$tmp" 2>&1
  local code=$?
  set -e

  local ok=0
  [[ "$code" -eq 0 ]] && ok=1

  CHECK_NAMES+=("$name")
  CHECK_OK+=("$ok")
  CHECK_CODE+=("$code")

  if [[ "$ok" -eq 1 ]]; then
    CHECK_MSG+=("")
    [[ "$JSON_OUT" -eq 0 ]] && printf "OK   %s\n" "$name"
  else
    failures=$((failures + 1))
    local tail
    tail="$(tail -n 40 "$tmp" | sed 's/\r$//')"
    CHECK_MSG+=("$tail")
    if [[ "$JSON_OUT" -eq 0 ]]; then
      printf "FAIL %s (exit=%s)\n" "$name" "$code" >&2
      printf "%s\n" "$tail" | sed 's/^/  /' >&2
    fi
  fi

  rm -f "$tmp"
}

local_contract_files_exist() {
  [[ -f deploy/k8s/base/monitoring/servicemonitor-mysql.yaml ]]
  [[ -f deploy/k8s/base/monitoring/servicemonitor-redis.yaml ]]
}

local_contract_kustomize_includes_exporters() {
  rg -Fq -- 'servicemonitor-mysql.yaml' deploy/k8s/base/monitoring/kustomization.yaml
  rg -Fq -- 'servicemonitor-redis.yaml' deploy/k8s/base/monitoring/kustomization.yaml
}

local_contract_workload_wiring() {
  rg -Fq -- 'name: mysqld-exporter' deploy/k8s/base/deployments.yml
  rg -Fq -- 'containerPort: 9104' deploy/k8s/base/deployments.yml
  rg -Fq -- 'name: redis-exporter' deploy/k8s/base/deployments.yml
  rg -Fq -- 'containerPort: 9121' deploy/k8s/base/deployments.yml
  rg -Fq -- 'port: 9104' deploy/k8s/base/services.yml
  rg -Fq -- 'port: 9121' deploy/k8s/base/services.yml
}

local_contract_alerts_present() {
  local required_alerts=(
    MySQLExporterDown
    MySQLHighConnectionUtilization
    MySQLSlowQueriesSpike
    RedisExporterDown
    RedisRejectedConnectionsSpike
    RedisEvictionsSpike
  )
  local alert
  for alert in "${required_alerts[@]}"; do
    rg -Fq -- "alert: ${alert}" deploy/k8s/base/monitoring/prometheusrule-lms.yaml
  done
}

runtime_preflight() {
  command -v kubectl >/dev/null
  command -v jq >/dev/null
  command -v python3 >/dev/null
}

runtime_cluster_reachable_or_skip() {
  if kubectl --context "$K8S_CONTEXT" get namespace "$APP_NS" >/dev/null 2>&1; then
    return 0
  fi
  if [[ "$STRICT_RUNTIME" == "1" ]]; then
    echo "Cannot reach context=$K8S_CONTEXT namespace=$APP_NS"
    return 1
  fi
  echo "SKIP: cannot reach context=$K8S_CONTEXT namespace=$APP_NS"
  return 0
}

runtime_objects_exist() {
  kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get servicemonitor mysql-metrics >/dev/null
  kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get servicemonitor redis-metrics >/dev/null
  kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get svc mysql -o json | jq -e '.spec.ports | any(.name=="metrics" and .port==9104)' >/dev/null
  kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get svc redis -o json | jq -e '.spec.ports | any(.name=="metrics" and .port==9121)' >/dev/null
}

runtime_alerts_loaded() {
  kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get prometheusrule lms-alerts -o json \
    | jq -e '
      [ .spec.groups[].rules[].alert ] as $alerts
      | (
          $alerts | index("MySQLExporterDown")
        ) != null
      and (
          $alerts | index("MySQLHighConnectionUtilization")
        ) != null
      and (
          $alerts | index("MySQLSlowQueriesSpike")
        ) != null
      and (
          $alerts | index("RedisExporterDown")
        ) != null
      and (
          $alerts | index("RedisRejectedConnectionsSpike")
        ) != null
      and (
          $alerts | index("RedisEvictionsSpike")
        ) != null
    ' >/dev/null
}

prom_query_json() {
  local query="$1"
  local prom_pod encoded
  prom_pod="$(
    kubectl --context "$K8S_CONTEXT" -n "$MON_NS" get pods \
      -l "$PROM_LABEL" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
  )"
  [[ -n "$prom_pod" ]] || { echo "Prometheus pod not found in namespace=$MON_NS"; return 1; }
  encoded="$(python3 - <<PY
import urllib.parse
print(urllib.parse.quote("""$query""", safe=''))
PY
)"
  kubectl --context "$K8S_CONTEXT" -n "$MON_NS" exec "$prom_pod" -- \
    wget -qO- --timeout=5 "http://localhost:9090/api/v1/query?query=${encoded}"
}

runtime_metrics_present() {
  local mysql_up redis_up mysql_conn redis_conn redis_reject

  # Use stable scrape labels; ServiceMonitor job labels can vary by operator defaults.
  mysql_up="$(prom_query_json "up{namespace=\"${APP_NS}\",service=\"mysql\",endpoint=\"metrics\"}")"
  redis_up="$(prom_query_json "up{namespace=\"${APP_NS}\",service=\"redis\",endpoint=\"metrics\"}")"
  mysql_conn="$(prom_query_json "mysql_global_status_threads_connected{namespace=\"${APP_NS}\",service=\"mysql\"}")"
  redis_conn="$(prom_query_json "redis_connected_clients{namespace=\"${APP_NS}\",service=\"redis\"}")"
  redis_reject="$(prom_query_json "redis_rejected_connections_total{namespace=\"${APP_NS}\",service=\"redis\"}")"

  jq -e '.status=="success" and ((.data.result // []) | length > 0) and ((.data.result[0].value[1] | tonumber) >= 1)' <<<"$mysql_up" >/dev/null
  jq -e '.status=="success" and ((.data.result // []) | length > 0) and ((.data.result[0].value[1] | tonumber) >= 1)' <<<"$redis_up" >/dev/null
  jq -e '.status=="success" and ((.data.result // []) | length > 0)' <<<"$mysql_conn" >/dev/null
  jq -e '.status=="success" and ((.data.result // []) | length > 0)' <<<"$redis_conn" >/dev/null
  jq -e '.status=="success" and ((.data.result // []) | length > 0)' <<<"$redis_reject" >/dev/null
}

if [[ "$JSON_OUT" -eq 0 ]]; then
  echo "Audit: DB exporter telemetry"
  echo "  mode:           $MODE"
  echo "  strict runtime: $STRICT_RUNTIME"
  echo "  context:        $K8S_CONTEXT"
  echo "  app namespace:  $APP_NS"
  echo "  monitor ns:     $MON_NS"
  echo
fi

if [[ "$MODE" == "local" || "$MODE" == "all" ]]; then
  run_check "local: exporter files exist" local_contract_files_exist
  run_check "local: monitoring kustomization includes exporter monitors" local_contract_kustomize_includes_exporters
  run_check "local: workload and service exporter wiring exists" local_contract_workload_wiring
  run_check "local: exporter alert rules are present" local_contract_alerts_present
fi

if [[ "$MODE" == "runtime" || "$MODE" == "all" ]]; then
  run_check "runtime: command/tooling preflight" runtime_preflight
  run_check "runtime: cluster reachable or skipped" runtime_cluster_reachable_or_skip
  run_check "runtime: exporter monitoring objects exist" runtime_objects_exist
  run_check "runtime: exporter alert names loaded in PrometheusRule" runtime_alerts_loaded
  run_check "runtime: exporter metrics are queryable in Prometheus" runtime_metrics_present
fi

if [[ "$JSON_OUT" -eq 1 ]]; then
  printf "{"
  printf "\"mode\":\"%s\"," "$(json_escape "$MODE")"
  printf "\"strict_runtime\":%s," "$STRICT_RUNTIME"
  printf "\"context\":\"%s\"," "$(json_escape "$K8S_CONTEXT")"
  printf "\"checks\":["
  for i in "${!CHECK_NAMES[@]}"; do
    [[ "$i" -gt 0 ]] && printf ","
    printf "{"
    printf "\"name\":\"%s\"," "$(json_escape "${CHECK_NAMES[$i]}")"
    printf "\"ok\":%s," "${CHECK_OK[$i]}"
    printf "\"exit_code\":%s" "${CHECK_CODE[$i]}"
    if [[ -n "${CHECK_MSG[$i]}" ]]; then
      printf ",\"message\":\"%s\"" "$(json_escape "${CHECK_MSG[$i]}")"
    fi
    printf "}"
  done
  printf "],"
  printf "\"failures\":%s" "$failures"
  printf "}\n"
else
  echo
  if [[ "$failures" -gt 0 ]]; then
    echo "FAILED ($failures checks failed)"
  else
    echo "OK"
  fi
fi

[[ "$failures" -eq 0 ]]
