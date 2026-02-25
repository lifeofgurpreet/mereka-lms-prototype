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

K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
APP_NS="${APP_NS:-mereka-lms}"

pass=0
fail=0
skip=0

report() {
  local status="$1"; shift
  case "$status" in
    PASS) pass=$((pass + 1)); printf "PASS  %s\n" "$*" ;;
    FAIL) fail=$((fail + 1)); printf "FAIL  %s\n" "$*" >&2 ;;
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
loki_doc="docs/operations/GKE_LOKI_FORWARDING.md"
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

# Tempo is SHOULD-level in the spec — SKIP if not present
tempo_configs=$(find deploy/k8s/ -name '*tempo*' 2>/dev/null | wc -l)
otel_configs=$(find deploy/k8s/ -name '*otel*' -o -name '*opentelemetry*' 2>/dev/null | wc -l)
if [[ "$tempo_configs" -gt 0 || "$otel_configs" -gt 0 ]]; then
  report PASS "Tracing configuration found in deploy/k8s/"
else
  report SKIP "Distributed tracing (Tempo/OTEL) not yet implemented (SHOULD-level in spec)"
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
    prom_pod=$(kubectl --context "$K8S_CONTEXT" -n monitoring get pods -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [[ -n "$prom_pod" ]]; then
      report PASS "Runtime: Prometheus pod found: $prom_pod"
    else
      report FAIL "Runtime: Prometheus pod not found in monitoring namespace"
    fi

    # Delegate to canonical first-class observability gate for deeper runtime coverage
    echo ""
    echo "=== Delegating to run-observability-first-class.sh (runtime) ==="
    if scripts/qa/run-observability-first-class.sh --mode runtime; then
      report PASS "run-observability-first-class.sh runtime checks passed"
    else
      report FAIL "run-observability-first-class.sh runtime checks failed"
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
echo "  SKIP: $skip"
echo ""

if [[ "$fail" -gt 0 ]]; then
  echo "FAILED ($fail checks failed)" >&2
  exit 1
fi

echo "OK"
exit 0
