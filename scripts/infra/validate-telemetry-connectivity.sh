#!/usr/bin/env bash
# @covers AC-003
# @spec: observability-stack_spec.md
# Validate Grafana -> Prometheus telemetry connectivity for Mereka LMS.
#
# Tests both:
# - GKE Prometheus (in-cluster datasource)
# - VPS Prometheus (external datasource)
#
# Usage:
#   ./scripts/infra/validate-telemetry-connectivity.sh
#   ./scripts/infra/validate-telemetry-connectivity.sh --json
#   ./scripts/infra/validate-telemetry-connectivity.sh --strict

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
MONITORING_NS="${MONITORING_NS:-monitoring}"
APP_NS="${APP_NS:-mereka-lms}"
VPS_PROM_URL="${VPS_PROM_URL:-https://prometheus.mereka.dev}"
GKE_PROM_SVC="${GKE_PROM_SVC:-monitoring-kube-prometheus-prometheus}"
GRAFANA_LABEL="${GRAFANA_LABEL:-app.kubernetes.io/name=grafana}"
OBSERVABILITY_REPO="${OBSERVABILITY_REPO:-/home/gurpreet/projects/observability}"
GRAFANA_CONTRACT_FILE="${GRAFANA_CONTRACT_FILE:-${REPO_ROOT}/infrastructure/monitoring/grafana/dashboard-contract.bbi-mereka-lms.json}"
GRAFANA_DASHBOARD_FILE="${GRAFANA_DASHBOARD_FILE:-${REPO_ROOT}/infrastructure/monitoring/grafana/dashboards/slo-overview.json}"
LEGACY_GRAFANA_DASHBOARD_FILE="${LEGACY_GRAFANA_DASHBOARD_FILE:-${OBSERVABILITY_REPO}/dashboards/03-applications/bbi-mereka-lms.json}"
JSON_OUT=0
STRICT=0
REQUIRE_VPS_PROM_DS="${REQUIRE_VPS_PROM_DS:-0}"
REQUIRE_GRAFANA_RECOMMENDED="${REQUIRE_GRAFANA_RECOMMENDED:-0}"
REQUIRE_DB_EXPORTER_METRICS="${REQUIRE_DB_EXPORTER_METRICS:-0}"
WARN_ON_MISSING_VPS_PROM_DS="${WARN_ON_MISSING_VPS_PROM_DS:-0}"
CHECK_LEGACY_DASHBOARD_UID_DRIFT="${CHECK_LEGACY_DASHBOARD_UID_DRIFT:-0}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CHECK_NAMES=()
CHECK_OK=()
CHECK_MSG=()
failures=0
warnings=0

usage() {
  cat <<EOF
Usage: ./scripts/infra/validate-telemetry-connectivity.sh [--json] [--strict]

Options:
  --json      Emit machine-readable JSON output
  --strict    Fail when optional parity checks are unavailable/missing

Env toggles:
  REQUIRE_VPS_PROM_DS=1           Fail if dashboard has no prometheus-vps refs
  REQUIRE_GRAFANA_RECOMMENDED=1   Fail if recommended dashboard coverage is missing
  REQUIRE_DB_EXPORTER_METRICS=1   Fail if MySQL/Redis exporter metrics are not queryable
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_OUT=1; shift ;;
    --strict) STRICT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

json_escape() {
  local s="${1:-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  printf "%s" "$s"
}

record_check() {
  local name="$1"
  local ok="$2"
  local msg="${3:-}"
  CHECK_NAMES+=("$name")
  CHECK_OK+=("$ok")
  CHECK_MSG+=("$msg")
  if [[ "$ok" -eq 1 ]]; then
    if [[ "$JSON_OUT" -eq 0 ]]; then
      echo -e "${GREEN}✓ PASS${NC}: $name"
    fi
  else
    failures=$((failures + 1))
    if [[ "$JSON_OUT" -eq 0 ]]; then
      echo -e "${RED}✗ FAIL${NC}: $name"
      [[ -n "$msg" ]] && echo -e "  ${YELLOW}↳ $msg${NC}"
    fi
  fi
}

record_warn() {
  local msg="$1"
  warnings=$((warnings + 1))
  if [[ "$JSON_OUT" -eq 0 ]]; then
    echo -e "${YELLOW}⚠ WARN${NC}: $msg"
  fi
}

run_check() {
  local name="$1"; shift
  local out tmp rc
  tmp="$(mktemp -t validate-telemetry.XXXXXX)"
  set +e
  "$@" >"$tmp" 2>&1
  rc=$?
  set -e
  out="$(cat "$tmp")"
  rm -f "$tmp"
  if [[ "$rc" -eq 0 ]]; then
    record_check "$name" 1 ""
    if [[ "$JSON_OUT" -eq 0 && -n "${out//[[:space:]]/}" ]]; then
      printf "%s\n" "$out"
    fi
  else
    record_check "$name" 0 "$out"
  fi
}

check_vps_prometheus() {
  curl -sS --max-time 10 "${VPS_PROM_URL}/api/v1/query?query=up" | jq -e '.status == "success"' >/dev/null
}

check_vps_external_urls() {
  curl -sS --max-time 10 "${VPS_PROM_URL}/api/v1/query?query=up" \
    | jq -e '.status == "success" and ((.data.result // []) | any((.metric.job // "") | test("external")))' >/dev/null
}

check_gke_prometheus_service() {
  kubectl --context "$K8S_CONTEXT" -n "$MONITORING_NS" get svc "$GKE_PROM_SVC" >/dev/null
}

check_gke_prometheus_pod() {
  kubectl --context "$K8S_CONTEXT" -n "$MONITORING_NS" get pods -l app.kubernetes.io/name=prometheus \
    -o json | jq -e '.items | any(.status.phase == "Running")' >/dev/null
}

grafana_pod_name() {
  kubectl --context "$K8S_CONTEXT" -n "$MONITORING_NS" get pods \
    -l "$GRAFANA_LABEL" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
}

grafana_exec_container_name() {
  local grafana_pod="${1:-}"
  local pod_json
  local container

  [[ -n "$grafana_pod" ]] || grafana_pod="$(grafana_pod_name)"
  [[ -n "$grafana_pod" ]] || return 1

  if [[ -n "${GRAFANA_CONTAINER:-}" ]]; then
    echo "$GRAFANA_CONTAINER"
    return 0
  fi

  pod_json="$(kubectl --context "$K8S_CONTEXT" -n "$MONITORING_NS" get pod "$grafana_pod" -o json)"

  for container in grafana grafana-sc-dashboard grafana-sc-datasources; do
    if jq -e --arg name "$container" '.status.containerStatuses[]? | select(.name == $name and .ready == true)' <<<"$pod_json" >/dev/null; then
      echo "$container"
      return 0
    fi
  done

  container="$(jq -r '.status.containerStatuses[]? | select(.ready == true) | .name' <<<"$pod_json" | head -n1)"
  [[ -n "$container" ]] || return 1
  echo "$container"
}

check_grafana_runtime_ready() {
  local grafana_pod
  local pod_json
  local reason
  local message
  local missing_secret

  grafana_pod="$(grafana_pod_name)"
  [[ -n "$grafana_pod" ]] || { echo "Grafana pod not found in $MONITORING_NS"; return 1; }

  pod_json="$(kubectl --context "$K8S_CONTEXT" -n "$MONITORING_NS" get pod "$grafana_pod" -o json)"

  if jq -e '.status.containerStatuses[]? | select(.name == "grafana" and .ready == true)' <<<"$pod_json" >/dev/null; then
    return 0
  fi

  reason="$(jq -r '.status.containerStatuses[]? | select(.name == "grafana") | (.state.waiting.reason // .state.terminated.reason // "unknown")' <<<"$pod_json" | head -n1)"
  message="$(jq -r '.status.containerStatuses[]? | select(.name == "grafana") | (.state.waiting.message // .state.terminated.message // "no message")' <<<"$pod_json" | head -n1)"

  missing_secret="$(sed -n 's/.*secret "\([^"]\+\)".*/\1/p' <<<"$message" | head -n1)"
  if [[ -n "$missing_secret" ]]; then
    if kubectl --context "$K8S_CONTEXT" -n "$MONITORING_NS" get secret "$missing_secret" >/dev/null 2>&1; then
      echo "Grafana container not ready (${reason}): ${message}"
      return 1
    fi
    echo "Grafana container not ready (${reason}): missing Secret/${missing_secret} in namespace ${MONITORING_NS}"
    return 1
  fi

  echo "Grafana container not ready (${reason}): ${message}"
  return 1
}

check_gke_query_from_grafana() {
  local grafana_pod
  local grafana_container
  grafana_pod="$(grafana_pod_name)"
  [[ -n "$grafana_pod" ]] || { echo "Grafana pod not found in $MONITORING_NS"; return 1; }
  grafana_container="$(grafana_exec_container_name "$grafana_pod")"
  [[ -n "$grafana_container" ]] || { echo "No ready Grafana pod container available for exec"; return 1; }
  kubectl --context "$K8S_CONTEXT" -n "$MONITORING_NS" exec -c "$grafana_container" "$grafana_pod" -- \
    wget -qO- --timeout=5 "http://${GKE_PROM_SVC}.${MONITORING_NS}:9090/api/v1/query?query=up" \
    | jq -e '.status == "success"' >/dev/null
}

check_mereka_metrics_from_grafana() {
  local grafana_pod
  local grafana_container
  grafana_pod="$(grafana_pod_name)"
  [[ -n "$grafana_pod" ]] || { echo "Grafana pod not found in $MONITORING_NS"; return 1; }
  grafana_container="$(grafana_exec_container_name "$grafana_pod")"
  [[ -n "$grafana_container" ]] || { echo "No ready Grafana pod container available for exec"; return 1; }
  kubectl --context "$K8S_CONTEXT" -n "$MONITORING_NS" exec -c "$grafana_container" "$grafana_pod" -- \
    wget -qO- --timeout=5 "http://${GKE_PROM_SVC}.${MONITORING_NS}:9090/api/v1/query?query=kube_pod_status_phase{namespace=\"${APP_NS}\"}" \
    | jq -e --arg ns "$APP_NS" '.status == "success" and (.data.result | any(.metric.namespace == $ns))' >/dev/null
}

check_db_exporter_metrics_from_grafana() {
  local grafana_pod
  local grafana_container
  grafana_pod="$(grafana_pod_name)"
  [[ -n "$grafana_pod" ]] || { echo "Grafana pod not found in $MONITORING_NS"; return 1; }
  grafana_container="$(grafana_exec_container_name "$grafana_pod")"
  [[ -n "$grafana_container" ]] || { echo "No ready Grafana pod container available for exec"; return 1; }

  local queries=(
    "mysql_global_status_threads_connected{namespace=\"${APP_NS}\",service=\"mysql\"}"
    "mysql_global_variables_max_connections{namespace=\"${APP_NS}\",service=\"mysql\"}"
    "mysql_global_status_slow_queries{namespace=\"${APP_NS}\",service=\"mysql\"}"
    "redis_rejected_connections_total{namespace=\"${APP_NS}\",service=\"redis\"}"
    "redis_evicted_keys_total{namespace=\"${APP_NS}\",service=\"redis\"}"
  )

  local q encoded resp
  for q in "${queries[@]}"; do
    encoded="$(python3 - <<PY
import urllib.parse
print(urllib.parse.quote("""$q""", safe=''))
PY
)"
    resp="$(
      kubectl --context "$K8S_CONTEXT" -n "$MONITORING_NS" exec -c "$grafana_container" "$grafana_pod" -- \
        wget -qO- --timeout=5 "http://${GKE_PROM_SVC}.${MONITORING_NS}:9090/api/v1/query?query=${encoded}" 2>/dev/null || true
    )"
    if [[ -z "$resp" ]]; then
      if [[ "$STRICT" -eq 1 && "$REQUIRE_DB_EXPORTER_METRICS" == "1" ]]; then
        echo "Empty response for exporter query: $q"
        return 1
      fi
      record_warn "Exporter query returned empty response (rollout may be pending): $q"
      return 0
    fi
    if ! jq -e '.status == "success" and ((.data.result // []) | length > 0)' <<<"$resp" >/dev/null; then
      if [[ "$STRICT" -eq 1 && "$REQUIRE_DB_EXPORTER_METRICS" == "1" ]]; then
        echo "Exporter metric missing or not queryable: $q"
        return 1
      fi
      record_warn "Exporter metric not queryable yet (rollout may be pending): $q"
      return 0
    fi
  done
}

check_grafana_datasource_configmaps() {
  local count
  count="$(kubectl --context "$K8S_CONTEXT" -n "$MONITORING_NS" get configmap -l grafana_datasource=1 -o name | wc -l | xargs)"
  [[ "$count" -ge 2 ]] || { echo "Expected >=2 datasource ConfigMaps, found $count"; return 1; }
}

check_required_datasource_configmaps() {
  kubectl --context "$K8S_CONTEXT" -n "$MONITORING_NS" get configmap monitoring-kube-prometheus-grafana-datasource >/dev/null
  kubectl --context "$K8S_CONTEXT" -n "$MONITORING_NS" get configmap grafana-datasource-vps-prometheus >/dev/null
}

check_dashboard_parity() {
  local dashboard_file="${GRAFANA_DASHBOARD_FILE}"
  if [[ ! -f "$dashboard_file" ]]; then
    if [[ "$STRICT" -eq 1 ]]; then
      echo "Dashboard file missing: $dashboard_file"
      return 1
    fi
    record_warn "Observability repo dashboard file not found; skipping parity check"
    return 0
  fi

  jq -e '((.uid // "") | length > 0) and ((.panels // []) | length > 0)' "$dashboard_file" >/dev/null || {
    echo "Dashboard UID/panels sanity failed for $dashboard_file"
    return 1
  }

  jq -e '
    [.. | objects | select(has("datasource")) | .datasource]
    | any(
        (type == "string" and . == "prometheus")
        or (type == "object" and (
          (.uid // "") == "prometheus"
          or (.type // "") == "prometheus"
        ))
      )
  ' "$dashboard_file" >/dev/null || {
    echo "Dashboard missing primary prometheus datasource references: $dashboard_file"
    return 1
  }

  if ! jq -e '
      [.. | objects | select(has("datasource")) | .datasource]
      | any(
          (type == "string" and . == "prometheus-vps")
          or (type == "object" and (
            (.uid // "") == "prometheus-vps"
            or (.uid // "") == "${DS_PROMETHEUS_VPS}"
          ))
        )
    ' "$dashboard_file" >/dev/null; then
    if [[ "$STRICT" -eq 1 && "$REQUIRE_VPS_PROM_DS" == "1" ]]; then
      echo "Dashboard has no prometheus-vps datasource references: $dashboard_file"
      return 1
    fi
    if [[ "$WARN_ON_MISSING_VPS_PROM_DS" == "1" ]]; then
      record_warn "Dashboard currently has no prometheus-vps datasource refs; GKE path is still validated."
    fi
  fi

  local audit_script="${REPO_ROOT}/scripts/qa/audit-grafana-dashboard.sh"
  if [[ ! -x "$audit_script" ]]; then
    if [[ "$STRICT" -eq 1 ]]; then
      echo "Grafana audit script missing or not executable: $audit_script"
      return 1
    fi
    record_warn "Grafana coverage audit script missing; skipping contract validation"
    return 0
  fi

  local audit_args=(
    --dashboard-file "$dashboard_file"
    --contract-file "$GRAFANA_CONTRACT_FILE"
    --strict-required
  )
  if [[ "$STRICT" -eq 1 && "$REQUIRE_GRAFANA_RECOMMENDED" == "1" ]]; then
    audit_args+=(--strict-recommended)
  fi

  local out
  if ! out="$("$audit_script" "${audit_args[@]}" 2>&1)"; then
    echo "$out"
    return 1
  fi

  local warn_count
  warn_count="$("$audit_script" --dashboard-file "$dashboard_file" --contract-file "$GRAFANA_CONTRACT_FILE" --json \
    | jq -r '(.recommended_warnings // []) | length' 2>/dev/null || echo 0)"
  if [[ "$warn_count" -gt 0 ]]; then
    if [[ "$STRICT" -eq 1 && "$REQUIRE_GRAFANA_RECOMMENDED" == "1" ]]; then
      echo "Grafana dashboard has $warn_count recommended coverage gaps"
      return 1
    fi
    record_warn "Grafana dashboard has $warn_count recommended coverage gaps. Run ./scripts/qa/audit-grafana-dashboard.sh."
  fi

  if [[ "$CHECK_LEGACY_DASHBOARD_UID_DRIFT" == "1" ]] && [[ -f "$LEGACY_GRAFANA_DASHBOARD_FILE" ]]; then
    local repo_uid legacy_uid
    repo_uid="$(jq -r '.uid // ""' "$dashboard_file" 2>/dev/null || true)"
    legacy_uid="$(jq -r '.uid // ""' "$LEGACY_GRAFANA_DASHBOARD_FILE" 2>/dev/null || true)"
    if [[ -n "$repo_uid" && -n "$legacy_uid" && "$repo_uid" != "$legacy_uid" ]]; then
      record_warn "Dashboard UID drift between repo (${repo_uid}) and legacy observability repo (${legacy_uid})"
    fi
  fi
}

if [[ "$JSON_OUT" -eq 0 ]]; then
  echo "=========================================="
  echo "Mereka LMS Telemetry Connectivity Validator"
  echo "=========================================="
  echo "context: ${K8S_CONTEXT}"
  echo "monitoring namespace: ${MONITORING_NS}"
  echo "app namespace: ${APP_NS}"
  echo ""
fi

run_check "VPS Prometheus HTTPS endpoint" check_vps_prometheus
run_check "VPS Prometheus external-urls job" check_vps_external_urls
run_check "GKE Prometheus service exists" check_gke_prometheus_service
run_check "GKE Prometheus pod running" check_gke_prometheus_pod
run_check "Grafana runtime ready" check_grafana_runtime_ready
run_check "GKE Prometheus query from Grafana" check_gke_query_from_grafana
run_check "Mereka LMS pod metrics from Grafana" check_mereka_metrics_from_grafana
run_check "Grafana datasource ConfigMaps present" check_grafana_datasource_configmaps
run_check "Required datasource ConfigMaps exist" check_required_datasource_configmaps
run_check "Grafana dashboard parity file sanity" check_dashboard_parity
run_check "DB exporter metrics from Grafana" check_db_exporter_metrics_from_grafana

if [[ "$JSON_OUT" -eq 1 ]]; then
  printf "{"
  printf "\"context\":\"%s\"," "$(json_escape "$K8S_CONTEXT")"
  printf "\"monitoring_namespace\":\"%s\"," "$(json_escape "$MONITORING_NS")"
  printf "\"app_namespace\":\"%s\"," "$(json_escape "$APP_NS")"
  printf "\"checks\":["
  for i in "${!CHECK_NAMES[@]}"; do
    [[ "$i" -gt 0 ]] && printf ","
    printf "{"
    printf "\"name\":\"%s\"," "$(json_escape "${CHECK_NAMES[$i]}")"
    printf "\"ok\":%s" "${CHECK_OK[$i]}"
    if [[ -n "${CHECK_MSG[$i]}" ]]; then
      printf ",\"message\":\"%s\"" "$(json_escape "${CHECK_MSG[$i]}")"
    fi
    printf "}"
  done
  printf "],"
  printf "\"warnings\":%s," "$warnings"
  printf "\"failures\":%s" "$failures"
  printf "}\n"
else
  echo ""
  echo "=========================================="
  echo "Summary"
  echo "=========================================="
  echo -e "${GREEN}Passed: $(( ${#CHECK_NAMES[@]} - failures ))${NC}"
  echo -e "${RED}Failed: ${failures}${NC}"
  if [[ "$warnings" -gt 0 ]]; then
    echo -e "${YELLOW}Warnings: ${warnings}${NC}"
  fi
  echo ""
  if [[ "$failures" -eq 0 ]]; then
    echo -e "${GREEN}✓ Telemetry connectivity validation passed.${NC}"
    echo "Open Grafana: https://grafana.mereka.dev/d/bbi-app-mereka-lms"
  else
    echo -e "${RED}✗ Telemetry connectivity validation failed.${NC}"
    echo "See docs/operations/SLO_DASHBOARDS_SETUP.md for remediation."
  fi
fi

[[ "$failures" -eq 0 ]]
