#!/usr/bin/env bash
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

K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
MONITORING_NS="${MONITORING_NS:-monitoring}"
APP_NS="${APP_NS:-mereka-lms}"
VPS_PROM_URL="${VPS_PROM_URL:-https://prometheus.mereka.dev}"
GKE_PROM_SVC="${GKE_PROM_SVC:-monitoring-kube-prometheus-prometheus}"
GRAFANA_LABEL="${GRAFANA_LABEL:-app.kubernetes.io/name=grafana}"
OBSERVABILITY_REPO="${OBSERVABILITY_REPO:-/home/gurpreet/projects/observability}"
JSON_OUT=0
STRICT=0
REQUIRE_VPS_PROM_DS="${REQUIRE_VPS_PROM_DS:-0}"

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

check_gke_query_from_grafana() {
  local grafana_pod
  grafana_pod="$(grafana_pod_name)"
  [[ -n "$grafana_pod" ]] || { echo "Grafana pod not found in $MONITORING_NS"; return 1; }
  kubectl --context "$K8S_CONTEXT" -n "$MONITORING_NS" exec "$grafana_pod" -- \
    wget -qO- --timeout=5 "http://${GKE_PROM_SVC}.${MONITORING_NS}:9090/api/v1/query?query=up" \
    | jq -e '.status == "success"' >/dev/null
}

check_mereka_metrics_from_grafana() {
  local grafana_pod
  grafana_pod="$(grafana_pod_name)"
  [[ -n "$grafana_pod" ]] || { echo "Grafana pod not found in $MONITORING_NS"; return 1; }
  kubectl --context "$K8S_CONTEXT" -n "$MONITORING_NS" exec "$grafana_pod" -- \
    wget -qO- --timeout=5 "http://${GKE_PROM_SVC}.${MONITORING_NS}:9090/api/v1/query?query=kube_pod_status_phase{namespace=\"${APP_NS}\"}" \
    | jq -e --arg ns "$APP_NS" '.status == "success" and (.data.result | any(.metric.namespace == $ns))' >/dev/null
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
  local dashboard_file="${OBSERVABILITY_REPO}/dashboards/03-applications/bbi-mereka-lms.json"
  if [[ ! -f "$dashboard_file" ]]; then
    if [[ "$STRICT" -eq 1 ]]; then
      echo "Dashboard file missing: $dashboard_file"
      return 1
    fi
    record_warn "Observability repo dashboard file not found; skipping parity check"
    return 0
  fi

  jq -e '
    .uid == "bbi-app-mereka-lms"
    and ((.panels // []) | length > 0)
  ' "$dashboard_file" >/dev/null || {
    echo "Dashboard UID/panels sanity failed in $dashboard_file"
    return 1
  }

  jq -e '
    [.. | objects | select(has("datasource")) | .datasource]
    | any(
        (type == "string" and . == "prometheus")
        or (type == "object" and (.uid // "") == "prometheus")
      )
  ' "$dashboard_file" >/dev/null || {
    echo "Dashboard missing primary prometheus datasource references: $dashboard_file"
    return 1
  }

  if ! jq -e '
      [.. | objects | select(has("datasource")) | .datasource]
      | any(
          (type == "string" and . == "prometheus-vps")
          or (type == "object" and (.uid // "") == "prometheus-vps")
        )
    ' "$dashboard_file" >/dev/null; then
    if [[ "$STRICT" -eq 1 && "$REQUIRE_VPS_PROM_DS" == "1" ]]; then
      echo "Dashboard has no prometheus-vps datasource references: $dashboard_file"
      return 1
    fi
    record_warn "Dashboard currently has no prometheus-vps datasource refs; GKE path is still validated."
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
run_check "GKE Prometheus query from Grafana" check_gke_query_from_grafana
run_check "Mereka LMS pod metrics from Grafana" check_mereka_metrics_from_grafana
run_check "Grafana datasource ConfigMaps present" check_grafana_datasource_configmaps
run_check "Required datasource ConfigMaps exist" check_required_datasource_configmaps
run_check "Grafana dashboard parity file sanity" check_dashboard_parity

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
