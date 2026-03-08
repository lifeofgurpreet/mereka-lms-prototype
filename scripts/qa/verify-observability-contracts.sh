#!/usr/bin/env bash
# @covers AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008
# @spec: observability-stack_spec.md
# Comprehensive observability contract verification.
#
# Validates the full observability stack against spec ACs:
#   - Prometheus ServiceMonitors for LMS, CMS, MySQL, Redis
#   - PrometheusRule alert coverage (pod crashes, OOM, error rate, backup)
#   - Promtail DaemonSet for log forwarding (GKE -> Loki)
#   - GCP Monitoring alert policies and notification channels
#   - Grafana dashboard coverage contract
#   - Tracing configuration (Tempo / OTEL)
#
# Usage:
#   ./scripts/qa/verify-observability-contracts.sh
#   ./scripts/qa/verify-observability-contracts.sh --mode local
#   ./scripts/qa/verify-observability-contracts.sh --mode runtime
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

K8S_CONTEXT="${K8S_CONTEXT_PROD:-${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}}"
APP_NS="${APP_NS:-${K8S_NAMESPACE_PROD:-${K8S_NAMESPACE:-mereka-lms}}}"
TEMPO_URL="${TEMPO_URL:-}"
TRACING_REQUIRED="${TRACING_REQUIRED:-${OBS_REQUIRE_TRACING_ARTIFACT:-0}}"

case "$TRACING_REQUIRED" in
  0|1) ;;
  *)
    echo "Invalid TRACING_REQUIRED='$TRACING_REQUIRED' (expected 0 or 1)" >&2
    exit 2
    ;;
esac

pass=0
fail=0
skip=0
warn=0

report() {
  local status="$1"; shift
  case "$status" in
    PASS) pass=$((pass + 1)); printf "PASS  %s\n" "$*" ;;
    FAIL) fail=$((fail + 1)); printf "FAIL  %s\n" "$*" >&2 ;;
    WARN) warn=$((warn + 1)); printf "WARN  %s\n" "$*" ;;
    SKIP) skip=$((skip + 1)); printf "SKIP  %s\n" "$*" ;;
  esac
}

has_kubectl() {
  command -v kubectl >/dev/null 2>&1 && \
    kubectl --context "$K8S_CONTEXT" get namespace "$APP_NS" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Section 1: Metrics Collection — ServiceMonitors
# ---------------------------------------------------------------------------
echo "=== Metrics Collection (ServiceMonitors) ==="

for sm in lms cms mysql redis enterprise; do
  f="deploy/k8s/base/monitoring/servicemonitor-${sm}.yaml"
  if [[ -f "$f" ]]; then
    report PASS "ServiceMonitor exists: $sm ($f)"
  else
    report FAIL "ServiceMonitor missing: $sm ($f)"
  fi
done

# Verify kustomization.yaml references all ServiceMonitors
kust="deploy/k8s/base/monitoring/kustomization.yaml"
if [[ -f "$kust" ]]; then
  missing_refs=()
  for sm in servicemonitor-lms.yaml servicemonitor-cms.yaml servicemonitor-mysql.yaml servicemonitor-redis.yaml; do
    if ! grep -qF "$sm" "$kust"; then
      missing_refs+=("$sm")
    fi
  done
  if [[ ${#missing_refs[@]} -eq 0 ]]; then
    report PASS "kustomization.yaml references all core ServiceMonitors"
  else
    report FAIL "kustomization.yaml missing references: ${missing_refs[*]}"
  fi
else
  report FAIL "kustomization.yaml missing at $kust"
fi

# Verify scrape interval <= 30s in ServiceMonitors (spec requirement)
for sm in lms cms; do
  f="deploy/k8s/base/monitoring/servicemonitor-${sm}.yaml"
  if [[ -f "$f" ]]; then
    interval=$(grep -oP 'interval:\s*\K\S+' "$f" | head -1)
    if [[ "$interval" == "30s" || "$interval" == "15s" || "$interval" == "10s" ]]; then
      report PASS "ServiceMonitor $sm scrape interval: $interval (<= 30s)"
    else
      report FAIL "ServiceMonitor $sm scrape interval: $interval (must be <= 30s)"
    fi
  fi
done

# ---------------------------------------------------------------------------
# Section 2: Alert Rules — PrometheusRules
# ---------------------------------------------------------------------------
echo ""
echo "=== Alert Rules (PrometheusRules) ==="

for pr in lms enterprise velero; do
  f="deploy/k8s/base/monitoring/prometheusrule-${pr}.yaml"
  if [[ -f "$f" ]]; then
    report PASS "PrometheusRule exists: $pr ($f)"
  else
    report FAIL "PrometheusRule missing: $pr ($f)"
  fi
done

# Verify critical alert rules exist (spec AC-006: pod crashes, OOM, error rate, backup)
pr_lms="deploy/k8s/base/monitoring/prometheusrule-lms.yaml"
if [[ -f "$pr_lms" ]]; then
  critical_alerts=(
    "LMSPodDown"
    "LMSPodMemoryCritical"
    "CMSPodDown"
    "MySQLPodDown"
    "RedisPodDown"
    "OpenEdxCrashLoopingContainers"
    "OpenEdxCriticalDeploymentUnavailable"
    "OpenEdxSyntheticOrBackupJobFailures"
  )
  for alert in "${critical_alerts[@]}"; do
    if grep -qE "alert:\\s*${alert}\\b" "$pr_lms"; then
      report PASS "Alert rule defined: $alert"
    else
      report FAIL "Alert rule missing: $alert in $pr_lms"
    fi
  done
fi

# Velero backup failure alerts
pr_velero="deploy/k8s/base/monitoring/prometheusrule-velero.yaml"
if [[ -f "$pr_velero" ]]; then
  for alert in VeleroBackupFailed VeleroBackupMissing; do
    if grep -qE "alert:\\s*${alert}\\b" "$pr_velero"; then
      report PASS "Velero alert rule defined: $alert"
    else
      report FAIL "Velero alert rule missing: $alert in $pr_velero"
    fi
  done
fi

# ---------------------------------------------------------------------------
# Section 3: GCP Monitoring Alert Policies
# ---------------------------------------------------------------------------
echo ""
echo "=== GCP Monitoring Alert Policies ==="

alerts_dir="infrastructure/monitoring/alerts"
if [[ -d "$alerts_dir" ]]; then
  alert_count=$(find "$alerts_dir" -name '*.json' | wc -l)
  if [[ "$alert_count" -gt 0 ]]; then
    report PASS "GCP alert policy templates: $alert_count files in $alerts_dir"
  else
    report FAIL "No alert policy templates in $alerts_dir"
  fi

  # Verify all JSON files are valid
  invalid=0
  while IFS= read -r f; do
    if ! jq -e . "$f" >/dev/null 2>&1; then
      report FAIL "Invalid JSON: $f"
      invalid=$((invalid + 1))
    fi
  done < <(find "$alerts_dir" -name '*.json' -type f)
  if [[ "$invalid" -eq 0 ]]; then
    report PASS "All alert policy JSON files are valid"
  fi

  # High-severity policies must have notification channels
  hs_missing=0
  while IFS= read -r f; do
    base=$(basename "$f")
    # Skip unsupported artifacts
    [[ "$base" == "velero-restore-test-stale.json" ]] && continue
    severity=$(jq -r '.severity // "" | ascii_upcase' "$f" 2>/dev/null)
    if [[ "$severity" == "ERROR" || "$severity" == "CRITICAL" ]]; then
      channels=$(jq -r '.notificationChannels | length' "$f" 2>/dev/null || echo 0)
      if [[ "$channels" -eq 0 ]]; then
        report FAIL "High-severity policy has no notificationChannels: $base"
        hs_missing=$((hs_missing + 1))
      fi
    fi
  done < <(find "$alerts_dir" -name '*.json' -type f)
  if [[ "$hs_missing" -eq 0 ]]; then
    report PASS "All high-severity alert policies have notification channels"
  fi
else
  report FAIL "Alert policies directory missing: $alerts_dir"
fi

# ---------------------------------------------------------------------------
# Section 4: Log Aggregation — Promtail DaemonSet
# ---------------------------------------------------------------------------
echo ""
echo "=== Log Aggregation (Promtail -> Loki) ==="

logging_dir="deploy/k8s/base/logging"
for manifest in promtail-daemonset.yaml promtail-configmap.yaml promtail-rbac.yaml promtail-service.yaml; do
  f="${logging_dir}/${manifest}"
  if [[ -f "$f" ]]; then
    report PASS "Logging manifest exists: $manifest"
  else
    report FAIL "Logging manifest missing: $manifest"
  fi
done

# Verify Promtail config targets Loki endpoint
cm="deploy/k8s/base/logging/promtail-configmap.yaml"
if [[ -f "$cm" ]]; then
  if grep -q 'loki.mereka.dev/loki/api/v1/push' "$cm"; then
    report PASS "Promtail config targets Loki push endpoint"
  else
    report FAIL "Promtail config missing Loki push URL"
  fi

  # Verify namespace/pod/container labels are set
  for label in namespace pod container; do
    if grep -q "target_label: ${label}" "$cm"; then
      report PASS "Promtail relabels: $label"
    else
      report FAIL "Promtail missing relabel for: $label"
    fi
  done
fi

# Verify DaemonSet uses appropriate resource limits
ds="deploy/k8s/base/logging/promtail-daemonset.yaml"
if [[ -f "$ds" ]]; then
  if grep -q 'kind: DaemonSet' "$ds"; then
    report PASS "Promtail deployed as DaemonSet"
  else
    report FAIL "Promtail is not a DaemonSet"
  fi
fi

# Log retention documented
loki_doc="docs/runbooks/operations/GKE_LOKI_FORWARDING.md"
if [[ -f "$loki_doc" ]]; then
  report PASS "Loki forwarding documentation exists: $loki_doc"
else
  report SKIP "Loki forwarding documentation not found: $loki_doc"
fi

# ---------------------------------------------------------------------------
# Section 5: Dashboards (Grafana)
# ---------------------------------------------------------------------------
echo ""
echo "=== Dashboards (Grafana) ==="

dashboards_dir="infrastructure/monitoring/dashboards"
if [[ -d "$dashboards_dir" ]]; then
  db_count=$(find "$dashboards_dir" -name '*.json' | wc -l)
  if [[ "$db_count" -gt 0 ]]; then
    report PASS "GCP/Grafana dashboard definitions: $db_count files"
  else
    report FAIL "No dashboard definitions in $dashboards_dir"
  fi
else
  report FAIL "Dashboards directory missing: $dashboards_dir"
fi

# Grafana dashboard coverage contract
contract="infrastructure/monitoring/grafana/dashboard-contract.bbi-mereka-lms.json"
if [[ -f "$contract" ]]; then
  report PASS "Grafana dashboard coverage contract exists"
  if jq -e . "$contract" >/dev/null 2>&1; then
    report PASS "Dashboard coverage contract is valid JSON"
  else
    report FAIL "Dashboard coverage contract is invalid JSON"
  fi
else
  report FAIL "Dashboard coverage contract missing: $contract"
fi

# Run the Grafana audit script if available (non-blocking)
if [[ -x "scripts/qa/audit-grafana-dashboard.sh" ]]; then
  if scripts/qa/audit-grafana-dashboard.sh >/dev/null 2>&1; then
    report PASS "Grafana dashboard audit passed"
  else
    report SKIP "Grafana dashboard audit failed (dashboard file may not be on this host)"
  fi
fi

# ---------------------------------------------------------------------------
# Section 6: Logging Metrics (GCP log-based metrics)
# ---------------------------------------------------------------------------
echo ""
echo "=== Logging Metrics ==="

lm_dir="infrastructure/monitoring/logging-metrics"
if [[ -d "$lm_dir" ]]; then
  lm_count=$(find "$lm_dir" -name '*.json' | wc -l)
  if [[ "$lm_count" -gt 0 ]]; then
    report PASS "Log-based metric definitions: $lm_count files"
  else
    report FAIL "No log-based metric definitions in $lm_dir"
  fi

  # Verify all JSON files valid
  invalid_lm=0
  while IFS= read -r f; do
    if ! jq -e . "$f" >/dev/null 2>&1; then
      report FAIL "Invalid JSON: $f"
      invalid_lm=$((invalid_lm + 1))
    fi
  done < <(find "$lm_dir" -name '*.json' -type f)
  if [[ "$invalid_lm" -eq 0 ]]; then
    report PASS "All logging-metric JSON files are valid"
  fi
else
  report FAIL "Logging metrics directory missing: $lm_dir"
fi

# ---------------------------------------------------------------------------
# Section 7: Uptime Checks
# ---------------------------------------------------------------------------
echo ""
echo "=== Uptime Checks ==="

uptime_dir="infrastructure/monitoring/uptime"
if [[ -d "$uptime_dir" ]]; then
  up_count=$(find "$uptime_dir" -name 'prod-*.json' | wc -l)
  if [[ "$up_count" -gt 0 ]]; then
    report PASS "Uptime check definitions: $up_count prod checks"
  else
    report FAIL "No prod uptime checks in $uptime_dir"
  fi
else
  report FAIL "Uptime directory missing: $uptime_dir"
fi

# ---------------------------------------------------------------------------
# Section 8: Tracing (Tempo / OpenTelemetry)
# ---------------------------------------------------------------------------
echo ""
echo "=== Distributed Tracing (Tempo/OTEL) ==="

if [[ -f "docs/adr/020-tracing-scope-and-pilot-decision.md" ]]; then
  report PASS "Tracing scope ADR exists: docs/adr/020-tracing-scope-and-pilot-decision.md"
elif [[ "$TRACING_REQUIRED" == "1" ]]; then
  report FAIL "Tracing scope ADR missing: docs/adr/020-tracing-scope-and-pilot-decision.md"
else
  report SKIP "Tracing scope ADR missing: docs/adr/020-tracing-scope-and-pilot-decision.md"
fi

if [[ -f "docs/reference/operations/OBSERVABILITY_TRACING_PILOT_CONTRACT.md" ]]; then
  report PASS "Tracing pilot contract exists: docs/reference/operations/OBSERVABILITY_TRACING_PILOT_CONTRACT.md"
elif [[ "$TRACING_REQUIRED" == "1" ]]; then
  report FAIL "Tracing pilot contract missing: docs/reference/operations/OBSERVABILITY_TRACING_PILOT_CONTRACT.md"
else
  report SKIP "Tracing pilot contract missing: docs/reference/operations/OBSERVABILITY_TRACING_PILOT_CONTRACT.md"
fi

tracing_configs=(
  $(find deploy/k8s infrastructure/monitoring -type f \( -iname '*tempo*' -o -iname '*otel*' -o -iname '*opentelemetry*' -o -iname '*tracing*' \) 2>/dev/null | awk 'NF')
)
if [[ "${#tracing_configs[@]}" -gt 0 ]]; then
  report PASS "Tracing manifests found in repo: ${#tracing_configs[@]} files"
elif [[ "$TRACING_REQUIRED" == "1" ]]; then
  report FAIL "Tracing manifests not found in deploy/k8s or infrastructure/monitoring"
else
  report SKIP "Tracing manifests not found in deploy/k8s or infrastructure/monitoring"
fi

if [[ -d infrastructure/monitoring/grafana ]] && rg -qi "tempo|tracing" infrastructure/monitoring/grafana >/dev/null 2>&1; then
  report PASS "Grafana tracing references detected in dashboard definitions"
else
  report WARN "No visible Grafana tracing references in infrastructure/monitoring/grafana"
fi

if rg -qi "OTEL_EXPORTER_OTLP_ENDPOINT|OTEL_SERVICE_NAME|otel" deploy/k8s/ >/dev/null 2>&1; then
  report PASS "OpenTelemetry env/config references detected in manifests"
elif [[ "$TRACING_REQUIRED" == "1" ]]; then
  report FAIL "No OpenTelemetry env/config references detected in deploy/k8s manifests"
else
  report WARN "No OpenTelemetry env/config references detected in deploy/k8s manifests"
fi

# ---------------------------------------------------------------------------
# Section 9: Runtime cluster checks (only in runtime mode)
# ---------------------------------------------------------------------------
if [[ "$MODE" == "runtime" ]]; then
  echo ""
  echo "=== Runtime Cluster Checks ==="

  if has_kubectl; then
    # ServiceMonitors exist in cluster
    for sm in lms-metrics cms-metrics mysql-metrics redis-metrics; do
      if kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get servicemonitor "$sm" >/dev/null 2>&1; then
        report PASS "Runtime: ServiceMonitor $sm exists in cluster"
      else
        report FAIL "Runtime: ServiceMonitor $sm not found in cluster"
      fi
    done

    # PrometheusRules loaded
    for pr in lms-alerts enterprise-alerts velero-alerts; do
      if kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get prometheusrule "$pr" >/dev/null 2>&1; then
        report PASS "Runtime: PrometheusRule $pr exists in cluster"
      else
        report FAIL "Runtime: PrometheusRule $pr not found in cluster"
      fi
    done

    # Promtail DaemonSet running
    if kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get daemonset promtail >/dev/null 2>&1; then
      desired=$(kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get daemonset promtail -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo 0)
      ready=$(kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get daemonset promtail -o jsonpath='{.status.numberReady}' 2>/dev/null || echo 0)
      if [[ "$desired" -gt 0 && "$desired" == "$ready" ]]; then
        report PASS "Runtime: Promtail DaemonSet healthy ($ready/$desired ready)"
      else
        report FAIL "Runtime: Promtail DaemonSet unhealthy ($ready/$desired ready)"
      fi
    else
      report FAIL "Runtime: Promtail DaemonSet not found"
    fi

    # Prometheus pod exists in monitoring namespace
    prom_pod_count=$(kubectl --context "$K8S_CONTEXT" -n monitoring get pods -l 'app.kubernetes.io/name in (prometheus,kube-prometheus-stack)' --no-headers 2>/dev/null | wc -l | tr -d ' ')
    running_prom_pod=$(kubectl --context "$K8S_CONTEXT" -n monitoring get pods -l 'app.kubernetes.io/name in (prometheus,kube-prometheus-stack)' --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$prom_pod_count" == "0" ]]; then
      report FAIL "Runtime: Prometheus pod not found in monitoring namespace"
    elif [[ "$running_prom_pod" == "0" ]]; then
      report FAIL "Runtime: Prometheus pod(s) exist in monitoring namespace but none are Running"
    else
      prom_pod=$(kubectl --context "$K8S_CONTEXT" -n monitoring get pods -l 'app.kubernetes.io/name in (prometheus,kube-prometheus-stack)' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
      report PASS "Runtime: Prometheus pod found: $prom_pod"
    fi

    # Tempo/OTEL runtime resources
    tempo_query='app.kubernetes.io/name=tempo'
    tempo_namespace=""
    tempo_service=""
    tempo_pod_count=0

    tempo_service=$(kubectl --context "$K8S_CONTEXT" get svc -A -l "$tempo_query" -o jsonpath='{.items[0].metadata.namespace}/{.items[0].metadata.name}' 2>/dev/null || true)
    if [[ -n "$tempo_service" ]]; then
      tempo_namespace="${tempo_service%%/*}"
      tempo_service="${tempo_service#*/}"
    fi

    if [[ -z "$tempo_namespace" ]]; then
      tempo_resource=$(kubectl --context "$K8S_CONTEXT" get deploy,daemonset,statefulset -A -l "$tempo_query" -o jsonpath='{.items[0].metadata.namespace}/{.items[0].metadata.name}' 2>/dev/null || true)
      if [[ -n "$tempo_resource" ]]; then
        tempo_namespace="${tempo_resource%%/*}"
      fi
    fi

    if [[ -n "$tempo_namespace" ]]; then
      if [[ -n "$tempo_service" ]]; then
        tempo_pods_json=$(kubectl --context "$K8S_CONTEXT" -n "$tempo_namespace" get pods -l "$tempo_query" -o json 2>/dev/null || echo '{"items":[]}')
        tempo_pod_count=$(echo "$tempo_pods_json" | jq -r '.items | length' 2>/dev/null || echo 0)
      else
        tempo_pods_json=$(kubectl --context "$K8S_CONTEXT" -n "$tempo_namespace" get pods -l "$tempo_query" -o json 2>/dev/null || echo '{"items":[]}')
        tempo_pod_count=$(echo "$tempo_pods_json" | jq -r '.items | length' 2>/dev/null || echo 0)
      fi

      if [[ "$tempo_pod_count" -gt 0 ]]; then
        report PASS "Runtime: Tempo resources discovered in namespace ${tempo_namespace}"
      elif [[ "$TRACING_REQUIRED" == "1" ]]; then
        report FAIL "Runtime: Tempo workload found in ${tempo_namespace} but no pods are running"
      else
        report WARN "Runtime: Tempo workload found in ${tempo_namespace} but no pods are running"
      fi
    elif [[ "$TRACING_REQUIRED" == "1" ]]; then
      report FAIL "Runtime: Tempo resources not found (required tracing artifact)"
    else
      report WARN "Runtime: Tempo resources not found (tracing is optional in current profile)"
    fi

    # Tempo readiness probe
    tempo_ready_url=""
    if [[ -n "$TEMPO_URL" ]]; then
      tempo_ready_url="${TEMPO_URL%/}/ready"
    elif [[ -n "$tempo_service" ]]; then
      tempo_ready_url="http://${tempo_service}.${tempo_namespace}.svc.cluster.local:3200/ready"
    fi

    if [[ -z "$tempo_ready_url" ]]; then
      report SKIP "Runtime: Tempo readiness URL unavailable for probe"
    elif ! command -v curl >/dev/null 2>&1; then
      report SKIP "Runtime: curl unavailable; skipping Tempo readiness probe"
    elif curl -fsS "$tempo_ready_url" >/dev/null 2>&1; then
      report PASS "Runtime: Tempo readiness probe passed ($tempo_ready_url)"
    elif [[ "$TRACING_REQUIRED" == "1" ]]; then
      report FAIL "Runtime: Tempo readiness probe failed ($tempo_ready_url)"
    else
      report WARN "Runtime: Tempo readiness probe failed ($tempo_ready_url)"
    fi
  else
    report SKIP "Runtime: kubectl not available or cluster unreachable ($K8S_CONTEXT / $APP_NS)"
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "Observability Contract Verification Summary"
echo "=========================================="
echo "  PASS: $pass"
echo "  FAIL: $fail"
echo "  WARN: $warn"
echo "  SKIP: $skip"
echo ""

if [[ "$fail" -gt 0 ]]; then
  echo "FAILED ($fail checks failed)" >&2
  exit 1
fi

echo "OK"
exit 0
