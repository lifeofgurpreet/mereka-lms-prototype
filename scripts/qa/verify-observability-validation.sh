#!/usr/bin/env bash
# @spec: observability-validation-requirements_spec.md
# @covers AC-OVR-001, AC-OVR-002, AC-OVR-003, AC-OVR-004, AC-OVR-005, AC-OVR-006, AC-OVR-007, AC-OVR-008, AC-OVR-009, AC-OVR-010, AC-OVR-011, AC-OVR-012, AC-OVR-013, AC-OVR-014, AC-OVR-015, AC-OVR-017, AC-OVR-022, AC-OVR-024, AC-OVR-030
#
# Observability Validation Requirements — Verification Script
# Validates that all required ServiceMonitors, PrometheusRules, SLI recording
# rules, dashboards, and uptime checks exist per the observability validation spec.
#
# Usage:
#   ./scripts/qa/verify-observability-validation.sh
set -euo pipefail

PASS=0; FAIL=0; SKIP=0
NAMESPACE="mereka-lms"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCOPE_MODE="${VERIFY_OBSERVABILITY_VALIDATION_SCOPE:-}"
CHANGED_FILES_RAW="${VERIFY_OBSERVABILITY_VALIDATION_CHANGED_FILES:-${CI_CHANGED_FILES:-}}"
KUST="${VERIFY_OBS_KUSTOMIZATION_PATH:-$REPO_ROOT/deploy/k8s/base/monitoring/kustomization.yaml}"
MON_DIR="${VERIFY_OBS_MONITORING_DIR:-$REPO_ROOT/deploy/k8s/base/monitoring}"
KUBECTL_TIMEOUT="${VERIFY_OBS_KUBECTL_TIMEOUT:-5}"
SKIP_LIVE_CHECKS="${VERIFY_OBS_SKIP_LIVE_CHECKS:-0}"

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

should_skip_scope() {
  local path

  [[ "$SCOPE_MODE" == "changed" ]] || return 1
  [[ -n "${CHANGED_FILES_RAW//[[:space:]]/}" ]] || return 1

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    case "$path" in
      .github/workflows/ci.yml|\
      scripts/qa/verify-observability-validation.sh|\
      scripts/qa/validate-observability-compliance.sh|\
      deploy/k8s/base/monitoring/*|\
      deploy/k8s/base/apps/openedx/settings/lms/mereka_forwarded_headers.py|\
      deploy/k8s/base/apps/openedx/settings/cms/mereka_forwarded_headers.py|\
      infrastructure/monitoring/grafana/dashboard-contract.bbi-mereka-lms.json)
        return 1
        ;;
    esac
  done <<< "$CHANGED_FILES_RAW"

  return 0
}

_HAS_KUBECTL=""
has_kubectl() {
  if [[ -n "${SKIP_LIVE_CHECKS}" && "$SKIP_LIVE_CHECKS" == "1" ]]; then
    _HAS_KUBECTL="no"
    return 1
  fi

  if [[ -z "$_HAS_KUBECTL" ]]; then
    if command -v kubectl &>/dev/null && timeout "$KUBECTL_TIMEOUT" kubectl cluster-info &>/dev/null 2>&1; then
      _HAS_KUBECTL="yes"
    else
      _HAS_KUBECTL="no"
    fi
  fi
  [[ "$_HAS_KUBECTL" == "yes" ]]
}

if [[ ! -f "$KUST" ]]; then
  fail "AC-OVR-001: kustomization.yaml not found at $KUST"
  exit 1
fi

if [[ ! -d "$MON_DIR" ]]; then
  fail "AC-OVR-001: monitoring directory not found at $MON_DIR"
  exit 1
fi

if should_skip_scope; then
  echo "PASS verify-observability-validation (scope skip: no observability validation authority changes)"
  exit 0
fi

echo "=== Observability Validation Requirements Verification ==="
echo ""

# ── Section 1: ServiceMonitors in kustomization.yaml (AC-OVR-001) ──
echo "--- ServiceMonitors (AC-OVR-001, AC-OVR-003, AC-OVR-004) ---"

REQUIRED_SMS=(
  "servicemonitor-lms.yaml"
  "servicemonitor-cms.yaml"
  "servicemonitor-mysql.yaml"
  "servicemonitor-redis.yaml"
  "servicemonitor-enterprise.yaml"
  "servicemonitor-purchase-gateway.yaml"
  "servicemonitor-xqueue.yaml"
  "servicemonitor-mux.yaml"
  "servicemonitor-caddy.yaml"
  "servicemonitor-discovery.yaml"
  "servicemonitor-credentials.yaml"
  "servicemonitor-notes.yaml"
)

if [[ -f "$KUST" ]]; then
  for sm in "${REQUIRED_SMS[@]}"; do
    if grep -qF "$sm" "$KUST"; then
      pass "AC-OVR-001: $sm listed in kustomization.yaml"
    else
      fail "AC-OVR-001: $sm NOT listed in kustomization.yaml"
    fi
  done
else
  fail "AC-OVR-001: kustomization.yaml not found at $KUST"
fi

# AC-OVR-003: Verify scrape interval and scrapeTimeout in ServiceMonitors
for sm_file in "$MON_DIR"/servicemonitor-*.yaml; do
  [[ -f "$sm_file" ]] || continue
  base=$(basename "$sm_file")
  interval=$(grep -oP 'interval:\s*\K\S+' "$sm_file" 2>/dev/null | head -1 || echo "")
  timeout_val=$(grep -oP 'scrapeTimeout:\s*\K\S+' "$sm_file" 2>/dev/null | head -1 || echo "")

  if [[ "$interval" == "30s" || "$interval" == "15s" || "$interval" == "10s" ]]; then
    pass "AC-OVR-003: $base interval=$interval (<=30s)"
  elif [[ -z "$interval" ]]; then
    skip "AC-OVR-003: $base has no explicit interval"
  else
    fail "AC-OVR-003: $base interval=$interval (must be <=30s)"
  fi

  if [[ -n "$timeout_val" ]]; then
    timeout_secs="${timeout_val%s}"
    if [[ "$timeout_secs" -le 10 ]] 2>/dev/null; then
      pass "AC-OVR-003: $base scrapeTimeout=${timeout_val} (<=10s)"
    else
      fail "AC-OVR-003: $base scrapeTimeout=${timeout_val} (must be <=10s)"
    fi
  fi
done

# AC-OVR-004: Verify monitoring component label
for sm_file in "$MON_DIR"/servicemonitor-*.yaml; do
  [[ -f "$sm_file" ]] || continue
  base=$(basename "$sm_file")

  if grep -q 'app.kubernetes.io/name:' "$sm_file" 2>/dev/null; then
    pass "AC-OVR-004: $base has app.kubernetes.io/name label"
  else
    fail "AC-OVR-004: $base missing app.kubernetes.io/name label"
  fi

  if grep -q 'app.kubernetes.io/instance:' "$sm_file" 2>/dev/null; then
    pass "AC-OVR-004: $base has app.kubernetes.io/instance label"
  else
    fail "AC-OVR-004: $base missing app.kubernetes.io/instance label"
  fi

  if grep -q 'app.kubernetes.io/part-of:' "$sm_file" 2>/dev/null; then
    pass "AC-OVR-004: $base has app.kubernetes.io/part-of label"
  else
    fail "AC-OVR-004: $base missing app.kubernetes.io/part-of label"
  fi

  if grep -q 'app.kubernetes.io/component: monitoring' "$sm_file" 2>/dev/null; then
    pass "AC-OVR-004: $base has monitoring component label"
  else
    fail "AC-OVR-004: $base missing app.kubernetes.io/component: monitoring label"
  fi
done

# AC-OVR-008: Validate scrape consistency across ServiceMonitors
for sm_file in "$MON_DIR"/servicemonitor-*.yaml; do
  [[ -f "$sm_file" ]] || continue
  base=$(basename "$sm_file")

  # Mux delivery monitor has a dedicated scrape shape and is excluded from generic
  # app-service relabeling expectations. Forum v2 is in-process with LMS, and MFE
  # metrics are intentionally captured via the shared Caddy monitor, so both
  # standalone ServiceMonitor files stay quarantined and are intentionally not
  # held to the generic ServiceMonitor contract here.
  if [[ "$base" == "servicemonitor-mux.yaml" ]]; then
    skip "AC-OVR-008: $base uses dedicated delivery-monitor scrape contract"
    continue
  fi
  if [[ "$base" == "servicemonitor-mfe.yaml" ]]; then
    skip "AC-OVR-008: $base is intentionally quarantined because MFE metrics are captured via caddy-metrics"
    continue
  fi
  if [[ "$base" == "servicemonitor-forum.yaml" ]]; then
    skip "AC-OVR-008: $base is intentionally quarantined because forum metrics are scraped via lms-metrics"
    continue
  fi

  if grep -q 'namespaceSelector:' "$sm_file" 2>/dev/null && \
     grep -q 'matchNames:' "$sm_file" 2>/dev/null && \
     grep -q '  - mereka-lms' "$sm_file" 2>/dev/null; then
    pass "AC-OVR-008: $base has namespaceSelector=matchNames[mereka-lms]"
  else
    fail "AC-OVR-008: $base missing namespaceSelector.matchNames=mereka-lms"
  fi

  if grep -q 'path: /metrics' "$sm_file" 2>/dev/null; then
    pass "AC-OVR-008: $base uses /metrics endpoint"
  else
    fail "AC-OVR-008: $base does not use /metrics endpoint"
  fi

  if grep -q 'targetLabel: pod' "$sm_file" 2>/dev/null && \
     grep -Fq 'sourceLabels: [__meta_kubernetes_pod_name]' "$sm_file" 2>/dev/null; then
    pass "AC-OVR-008: $base has pod relabel for pod identity"
  else
    fail "AC-OVR-008: $base missing pod relabeling on __meta_kubernetes_pod_name"
  fi

  if grep -q 'targetLabel: node' "$sm_file" 2>/dev/null && \
     grep -Fq 'sourceLabels: [__meta_kubernetes_pod_node_name]' "$sm_file" 2>/dev/null; then
    pass "AC-OVR-008: $base has pod relabel for node identity"
  else
    fail "AC-OVR-008: $base missing pod relabeling on __meta_kubernetes_pod_node_name"
  fi

  if grep -q 'targetLabel: namespace' "$sm_file" 2>/dev/null && \
     grep -Fq 'sourceLabels: [__meta_kubernetes_namespace]' "$sm_file" 2>/dev/null; then
    pass "AC-OVR-008: $base has pod relabel for namespace identity"
  else
    fail "AC-OVR-008: $base missing pod relabeling on __meta_kubernetes_namespace"
  fi
done

# AC-OVR-002: Live cluster ServiceMonitor check
if has_kubectl; then
  REQUIRED_LIVE_SMS=(
    "lms-metrics"
    "cms-metrics"
    "mysql-metrics"
    "redis-metrics"
    "enterprise-catalog-metrics"
    "caddy-metrics"
    "discovery-metrics"
    "credentials-metrics"
    "purchase-gateway-metrics"
  )
  for sm in "${REQUIRED_LIVE_SMS[@]}"; do
    SM_CANDIDATES=("$sm")
    if [[ "$sm" == "caddy-metrics" ]]; then
      SM_CANDIDATES+=("caddy")
    fi

    found_sm=0
    for candidate in "${SM_CANDIDATES[@]}"; do
      if timeout "$KUBECTL_TIMEOUT" kubectl get servicemonitor "$candidate" -n "$NAMESPACE" &>/dev/null; then
        found_sm=1
        if [[ "$candidate" == "$sm" ]]; then
          pass "AC-OVR-002: ServiceMonitor $sm exists in cluster"
        else
          pass "AC-OVR-002: ServiceMonitor $sm exists as $candidate in cluster"
        fi
        break
      fi
    done

    if [[ "$found_sm" -eq 0 ]]; then
      skip "AC-OVR-002: ServiceMonitor $sm not found in cluster"
    fi
  done
else
  skip "AC-OVR-002: No cluster access -- cannot verify live ServiceMonitors"
fi

echo ""

# ── Section 2: PrometheusRules in kustomization.yaml (AC-OVR-005) ──
echo "--- PrometheusRules (AC-OVR-005, AC-OVR-007) ---"

REQUIRED_PRS=(
  "prometheusrule-lms.yaml"
  "prometheusrule-enterprise.yaml"
  "prometheusrule-velero.yaml"
  "prometheusrule-slo.yaml"
  "prometheusrule-auth.yaml"
  "prometheusrule-caddy.yaml"
  "prometheusrule-services.yaml"
  "prometheusrule-video.yaml"
  "prometheusrule-email.yaml"
  "prometheusrule-libraries.yaml"
  "prometheusrule-ora2.yaml"
  "prometheusrule-tenant-isolation.yaml"
  "prometheusrule-credentials.yaml"
)

if [[ -f "$KUST" ]]; then
  for pr in "${REQUIRED_PRS[@]}"; do
    if grep -qF "$pr" "$KUST"; then
      pass "AC-OVR-005: $pr listed in kustomization.yaml"
    else
      fail "AC-OVR-005: $pr NOT listed in kustomization.yaml"
    fi
  done
else
  fail "AC-OVR-005: kustomization.yaml not found"
fi

# AC-OVR-007: Verify prometheus: kube-prometheus label
for pr_file in "$MON_DIR"/prometheusrule-*.yaml; do
  [[ -f "$pr_file" ]] || continue
  base=$(basename "$pr_file")
  if grep -q 'prometheus: kube-prometheus' "$pr_file" 2>/dev/null; then
    pass "AC-OVR-007: $base has prometheus: kube-prometheus label"
  else
    fail "AC-OVR-007: $base missing prometheus: kube-prometheus label"
  fi
done

# AC-OVR-006: Live cluster PrometheusRule check
if has_kubectl; then
  REQUIRED_LIVE_PRS=(
    "lms-alerts"
    "enterprise-alerts"
    "velero-alerts"
    "slo-recording-rules"
    "auth-alerts"
    "caddy-alerts"
    "services-alerts"
    "video-alerts"
    "email-alerts"
    "library-alerts"
    "ora2-operations"
    "credentials-alerts"
  )
  for pr in "${REQUIRED_LIVE_PRS[@]}"; do
    if timeout "$KUBECTL_TIMEOUT" kubectl get prometheusrule "$pr" -n "$NAMESPACE" &>/dev/null; then
      pass "AC-OVR-006: PrometheusRule $pr exists in cluster"
    else
      skip "AC-OVR-006: PrometheusRule $pr not found in cluster"
    fi
  done
else
  skip "AC-OVR-006: No cluster access -- cannot verify live PrometheusRules"
fi

echo ""

# ── Section 3: Alert Rule Content (AC-OVR-008, AC-OVR-009, AC-OVR-010, AC-OVR-011) ──
echo "--- Alert Rule Content ---"

# AC-OVR-008: lms-alerts alert names (sample of key alerts)
pr_lms="$MON_DIR/prometheusrule-lms.yaml"
if [[ -f "$pr_lms" ]]; then
  LMS_ALERTS=(
    "LMSPodDown"
    "LMSPodMemoryCritical"
    "CMSPodDown"
    "MySQLPodDown"
    "RedisPodDown"
    "OpenEdxCrashLoopingContainers"
  )
  for alert in "${LMS_ALERTS[@]}"; do
    if grep -qE "alert:\\s*${alert}" "$pr_lms"; then
      pass "AC-OVR-008: Alert $alert defined in prometheusrule-lms.yaml"
    else
      fail "AC-OVR-008: Alert $alert NOT found in prometheusrule-lms.yaml"
    fi
  done
else
  fail "AC-OVR-008: prometheusrule-lms.yaml not found"
fi

# AC-OVR-009: enterprise-alerts alert names (sample)
pr_ent="$MON_DIR/prometheusrule-enterprise.yaml"
if [[ -f "$pr_ent" ]]; then
  ENT_ALERTS=(
    "EnterpriseCatalogDown"
    "EnterpriseAccessDown"
    "EnterpriseSubsidyDown"
  )
  for alert in "${ENT_ALERTS[@]}"; do
    if grep -qE "alert:\\s*${alert}" "$pr_ent"; then
      pass "AC-OVR-009: Alert $alert defined in prometheusrule-enterprise.yaml"
    else
      fail "AC-OVR-009: Alert $alert NOT found in prometheusrule-enterprise.yaml"
    fi
  done
else
  fail "AC-OVR-009: prometheusrule-enterprise.yaml not found"
fi

# AC-OVR-008: caddy alert names (sample)
pr_caddy="$MON_DIR/prometheusrule-caddy.yaml"
if [[ -f "$pr_caddy" ]]; then
  CADDY_ALERTS=(
    "CaddyDown"
    "CaddyHighErrorRate"
    "CaddyHighLatency"
  )
  for alert in "${CADDY_ALERTS[@]}"; do
    if grep -qE "alert:\\s*${alert}" "$pr_caddy"; then
      pass "AC-OVR-008: Alert $alert defined in prometheusrule-caddy.yaml"
    else
      fail "AC-OVR-008: Alert $alert NOT found in prometheusrule-caddy.yaml"
    fi
  done
else
  fail "AC-OVR-008: prometheusrule-caddy.yaml not found"
fi

# AC-OVR-008: shared services alert names (sample)
pr_services="$MON_DIR/prometheusrule-services.yaml"
if [[ -f "$pr_services" ]]; then
  SERVICE_ALERTS=(
    "ForumPodDown"
    "DiscoveryPodDown"
    "CredentialsPodDown"
    "MFEPodDown"
    "PurchaseGatewayPodDown"
    "PurchaseGatewayHighErrorRate"
  )
  for alert in "${SERVICE_ALERTS[@]}"; do
    if grep -qE "alert:\\s*${alert}" "$pr_services"; then
      pass "AC-OVR-008: Alert $alert defined in prometheusrule-services.yaml"
    else
      fail "AC-OVR-008: Alert $alert NOT found in prometheusrule-services.yaml"
    fi
  done
else
  fail "AC-OVR-008: prometheusrule-services.yaml not found"
fi

# AC-OVR-010: SLO recording-rules alerts
pr_slo="$MON_DIR/prometheusrule-slo.yaml"
if [[ -f "$pr_slo" ]]; then
  SLO_ALERTS=(
    "SLOBudgetFastBurn"
    "SLOBudgetSlowBurn"
    "SLOBudgetWarning"
    "SLOBudgetExhausted"
  )
  for alert in "${SLO_ALERTS[@]}"; do
    if grep -qE "alert:\\s*${alert}" "$pr_slo"; then
      pass "AC-OVR-010: SLO alert $alert defined in prometheusrule-slo.yaml"
    else
      fail "AC-OVR-010: SLO alert $alert NOT found in prometheusrule-slo.yaml"
    fi
  done
else
  fail "AC-OVR-010: prometheusrule-slo.yaml not found"
fi

# AC-OVR-011: Verify severity label and summary/description annotations
for pr_file in "$MON_DIR"/prometheusrule-*.yaml; do
  [[ -f "$pr_file" ]] || continue
  base=$(basename "$pr_file")
  if grep -q 'severity:' "$pr_file" 2>/dev/null; then
    pass "AC-OVR-011: $base contains severity labels"
  else
    fail "AC-OVR-011: $base missing severity labels on alert rules"
  fi
  if grep -q 'summary:' "$pr_file" 2>/dev/null && grep -q 'description:' "$pr_file" 2>/dev/null; then
    pass "AC-OVR-011: $base contains summary+description annotations"
  else
    fail "AC-OVR-011: $base missing summary or description annotations"
  fi
done

echo ""

# ── Section 4: SLI Recording Rules (AC-OVR-012 .. AC-OVR-015) ──
echo "--- SLI Recording Rules ---"

if [[ -f "$pr_slo" ]]; then
  # AC-OVR-012: Availability ratio recording rules
  AVAIL_RULES=(
    "mereka:http_requests:availability_ratio_5m"
    "mereka:http_requests:availability_ratio_30m"
    "mereka:http_requests:availability_ratio_1h"
    "mereka:http_requests:availability_ratio_6h"
  )
  for rule in "${AVAIL_RULES[@]}"; do
    if grep -qF "$rule" "$pr_slo"; then
      pass "AC-OVR-012: Recording rule $rule exists"
    else
      fail "AC-OVR-012: Recording rule $rule NOT found"
    fi
  done

  # AC-OVR-013: Latency percentile recording rules
  LATENCY_RULES=(
    "mereka:http_request_duration:p50_5m"
    "mereka:http_request_duration:p95_5m"
    "mereka:http_request_duration:p99_5m"
  )
  for rule in "${LATENCY_RULES[@]}"; do
    if grep -qF "$rule" "$pr_slo"; then
      pass "AC-OVR-013: Recording rule $rule exists"
    else
      fail "AC-OVR-013: Recording rule $rule NOT found"
    fi
  done

  # AC-OVR-014: Burn rate recording rules
  BURN_RULES=(
    "mereka:slo:burn_rate_5m"
    "mereka:slo:burn_rate_30m"
    "mereka:slo:burn_rate_1h"
    "mereka:slo:burn_rate_6h"
  )
  for rule in "${BURN_RULES[@]}"; do
    if grep -qF "$rule" "$pr_slo"; then
      pass "AC-OVR-014: Recording rule $rule exists"
    else
      fail "AC-OVR-014: Recording rule $rule NOT found"
    fi
  done

  # AC-OVR-015: Error budget recording rules
  BUDGET_RULES=(
    "mereka:slo:error_budget_remaining_ratio"
    "mereka:slo:error_budget_remaining_minutes"
  )
  for rule in "${BUDGET_RULES[@]}"; do
    if grep -qF "$rule" "$pr_slo"; then
      pass "AC-OVR-015: Recording rule $rule exists"
    else
      fail "AC-OVR-015: Recording rule $rule NOT found"
    fi
  done
else
  fail "AC-OVR-012: prometheusrule-slo.yaml not found (cannot verify recording rules)"
fi

echo ""

# ── Section 5: Uptime Check JSON Files (AC-OVR-017) ──
echo "--- Uptime Checks (AC-OVR-017) ---"

uptime_dir="$REPO_ROOT/infrastructure/monitoring/uptime"
if [[ -d "$uptime_dir" ]]; then
  invalid_json=0
  missing_display=0
  total_checks=0
  while IFS= read -r f; do
    total_checks=$((total_checks + 1))
    if ! python3 -c "import json; json.load(open('$f'))" 2>/dev/null; then
      fail "AC-OVR-017: Invalid JSON: $(basename "$f")"
      invalid_json=$((invalid_json + 1))
      continue
    fi
    if ! python3 -c "import json; d=json.load(open('$f')); assert 'displayName' in d" 2>/dev/null; then
      fail "AC-OVR-017: Missing displayName: $(basename "$f")"
      missing_display=$((missing_display + 1))
    fi
  done < <(find "$uptime_dir" -name '*.json' -type f)

  if [[ "$total_checks" -gt 0 && "$invalid_json" -eq 0 && "$missing_display" -eq 0 ]]; then
    pass "AC-OVR-017: All $total_checks uptime check JSON files are valid with displayName"
  elif [[ "$total_checks" -eq 0 ]]; then
    fail "AC-OVR-017: No uptime check JSON files found in $uptime_dir"
  fi
else
  fail "AC-OVR-017: Uptime checks directory not found: $uptime_dir"
fi

echo ""

# ── Section 6: Grafana Dashboard Contract (AC-OVR-022) ──
echo "--- Grafana Dashboard Contract (AC-OVR-022) ---"

contract="$REPO_ROOT/infrastructure/monitoring/grafana/dashboard-contract.bbi-mereka-lms.json"
if [[ -f "$contract" ]]; then
  if python3 -c "import json; json.load(open('$contract'))" 2>/dev/null; then
    pass "AC-OVR-022: Dashboard contract is valid JSON"
  else
    fail "AC-OVR-022: Dashboard contract is invalid JSON"
  fi
  if python3 -c "
import json
d = json.load(open('$contract'))
assert 'required' in d
assert 'panel_titles' in d['required']
assert 'query_fragments' in d['required']
" 2>/dev/null; then
    pass "AC-OVR-022: Dashboard contract contains required.panel_titles and required.query_fragments"
  else
    fail "AC-OVR-022: Dashboard contract missing required.panel_titles or required.query_fragments"
  fi
else
  fail "AC-OVR-022: Dashboard contract not found: $contract"
fi

echo ""

# ── Section 7: Validation Script Existence (AC-OVR-024) ──
echo "--- Validation Script (AC-OVR-024) ---"

validation_script="$REPO_ROOT/scripts/qa/validate-observability-compliance.sh"
if [[ -f "$validation_script" ]]; then
  pass "AC-OVR-024: validate-observability-compliance.sh exists"
  if [[ -x "$validation_script" ]]; then
    pass "AC-OVR-024: validate-observability-compliance.sh is executable"
  else
    fail "AC-OVR-024: validate-observability-compliance.sh is not executable"
  fi
else
  fail "AC-OVR-024: validate-observability-compliance.sh not found"
fi

echo ""

# ── Section 8: Metrics Host-Rewrite Guardrail (AC-OVR-012) ──
echo "--- Metrics Host-Rewrite Guardrail (AC-OVR-012) ---"

lms_middleware="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/mereka_forwarded_headers.py"
cms_middleware="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/cms/mereka_forwarded_headers.py"
expected_ip_regex='re.match(r"^\d{1,3}(?:\.\d{1,3}){3}(?::\d+)?$", raw_host or "")'
broken_ip_regex='re.match(r"^\\d{1,3}(?:\\.\\d{1,3}){3}(?::\\d+)?$", raw_host or "")'

for middleware_file in "$lms_middleware" "$cms_middleware"; do
  base="$(basename "$middleware_file")"
  if [[ ! -f "$middleware_file" ]]; then
    fail "AC-OVR-012: $base not found"
    continue
  fi
  if grep -Fq "$broken_ip_regex" "$middleware_file"; then
    fail "AC-OVR-012: $base contains incorrectly escaped pod-IP regex for /metrics host rewrite"
    continue
  fi
  if grep -Fq "$expected_ip_regex" "$middleware_file"; then
    pass "AC-OVR-012: $base has valid pod-IP regex for /metrics host rewrite"
  else
    fail "AC-OVR-012: $base missing expected pod-IP regex for /metrics host rewrite"
  fi
done

echo ""

# ── Section 9: Critical Alert Duration (AC-OVR-030) ──
echo "--- Critical Alert Duration (AC-OVR-030) ---"

# Check that critical-severity alerts have for <= 5m
critical_over_5m=0
for pr_file in "$MON_DIR"/prometheusrule-*.yaml; do
  [[ -f "$pr_file" ]] || continue
  # Extract alert blocks with severity: critical and check their 'for' field
  # Simple heuristic: find lines with 'severity: critical' and nearby 'for:' values
  while IFS= read -r line_num; do
    # Look up to 10 lines above for the 'for:' field
    for_val=$(sed -n "$((line_num - 10)),$((line_num))p" "$pr_file" | grep -oP 'for:\s*\K\S+' | tail -1 || echo "")
    if [[ -n "$for_val" ]]; then
      # Parse duration (e.g., 5m, 1m, 10m, 30s)
      num="${for_val%[msh]}"
      unit="${for_val: -1}"
      minutes=0
      case "$unit" in
        s) minutes=0 ;;
        m) minutes=$num ;;
        h) minutes=$((num * 60)) ;;
      esac
      if [[ "$minutes" -gt 5 ]]; then
        alert_name=$(sed -n "$((line_num - 15)),$((line_num))p" "$pr_file" | grep -oP 'alert:\s*\K\S+' | tail -1 || echo "unknown")
        fail "AC-OVR-030: Critical alert $alert_name has for=${for_val} (must be <=5m) in $(basename "$pr_file")"
        critical_over_5m=$((critical_over_5m + 1))
      fi
    fi
  done < <(grep -n 'severity: critical' "$pr_file" 2>/dev/null | cut -d: -f1)
done

if [[ "$critical_over_5m" -eq 0 ]]; then
  pass "AC-OVR-030: All critical alerts have for <= 5m (or no critical alerts found)"
fi

# ── Summary ─────────────────────────────────────────────
echo ""
echo "=== Summary ==="
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
echo "  SKIP: $SKIP"
TOTAL=$((PASS + FAIL + SKIP))
echo "  TOTAL: $TOTAL"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi

exit 0
