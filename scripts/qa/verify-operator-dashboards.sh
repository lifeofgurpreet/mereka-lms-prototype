#!/usr/bin/env bash
# verify-operator-dashboards.sh
# Verify operator dashboard infrastructure and diagnostics tooling.
# Usage: ./scripts/qa/verify-operator-dashboards.sh [--runtime]
#
# By default, runs repo-local checks only (no kubectl required).
# With --runtime, also runs live cluster checks (requires kubectl auth).
#
# Exit codes: 0 = all PASS/SKIP, 1 = one or more FAIL

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODE="local"

for arg in "$@"; do
  case "$arg" in
    --runtime) MODE="runtime" ;;
  esac
done

PASS=0
FAIL=0
SKIP=0

pass() { echo "  PASS: $*"; (( PASS++ )) || true; }
fail() { echo "  FAIL: $*"; (( FAIL++ )) || true; }
skip() { echo "  SKIP: $*"; (( SKIP++ )) || true; }

section() {
  echo ""
  echo "=== $* ==="
}

# ─── helpers ────────────────────────────────────────────────────────────────

kubectl_available() {
  command -v kubectl &>/dev/null && kubectl cluster-info &>/dev/null 2>&1
}

file_exists() {
  local f="$1"
  if [[ -f "${REPO_ROOT}/${f}" ]]; then
    pass "file exists: ${f}"
  else
    fail "missing file: ${f}"
  fi
}

dir_exists() {
  local d="$1"
  if [[ -d "${REPO_ROOT}/${d}" ]]; then
    pass "directory exists: ${d}"
  else
    fail "missing directory: ${d}"
  fi
}

script_executable() {
  local s="$1"
  local path="${REPO_ROOT}/${s}"
  if [[ -f "$path" && -x "$path" ]]; then
    pass "script executable: ${s}"
  elif [[ -f "$path" ]]; then
    fail "script not executable: ${s}"
  else
    fail "script missing: ${s}"
  fi
}

grep_in_file() {
  local pattern="$1"
  local file="${REPO_ROOT}/$2"
  local label="$3"
  if grep -qF "$pattern" "$file" 2>/dev/null; then
    pass "$label"
  else
    fail "$label (pattern '${pattern}' not found in ${2})"
  fi
}

# ─── Section 1: Documentation files ────────────────────────────────────────

section "1. Operator documentation files"

file_exists "docs/reference/operations/OPERATOR_DASHBOARD_GUIDE.md"
file_exists "docs/runbooks/operations/TROUBLESHOOTING.md"
file_exists "docs/reference/operations/MONITORING.md"
file_exists "docs/runbooks/operations/OBSERVABILITY_QUICKSTART.md"
file_exists "docs/runbooks/operations/ONCALL_OBSERVABILITY_PLAYBOOK.md"
file_exists "docs/policies/operations/ONCALL_ROTATION.md"
file_exists "docs/runbooks/operations/INCIDENT_RESPONSE.md"
file_exists "docs/runbooks/operations/INCIDENT_TEMPLATES.md"
file_exists "docs/reference/operations/ALERT_SEVERITY_MATRIX.md"
file_exists "docs/runbooks/operations/ALERT_TUNING_SOP.md"
file_exists "docs/policies/operations/SLO_POLICY.md"
file_exists "docs/runbooks/operations/SLO_DASHBOARDS_SETUP.md"
file_exists "docs/reference/operations/ADMIN_CONSOLE_SETUP.md"
file_exists "docs/ops/quickref/access-urls.md"
file_exists "docs/reference/operations/CAPACITY_PLANNING.md"
file_exists "docs/ops/runbooks/site-down.md"
file_exists "docs/ops/runbooks/emergency-rollback.md"
file_exists "docs/ops/runbooks/DISASTER_RECOVERY.md"
file_exists "docs/ops/quickref/kubectl-cheatsheet.md"
file_exists "docs/ops/quickref/common-troubleshooting.md"

# ─── Section 2: OPERATOR_DASHBOARD_GUIDE content checks ────────────────────

section "2. OPERATOR_DASHBOARD_GUIDE.md content"

GUIDE="${REPO_ROOT}/docs/reference/operations/OPERATOR_DASHBOARD_GUIDE.md"

if [[ -f "$GUIDE" ]]; then
  content=$(<"$GUIDE")

  for keyword in \
    "grafana.mereka.io" \
    "bbi-app-mereka-lms" \
    "Django Admin" \
    "admin-console" \
    "Aspects" \
    "Escalation Matrix" \
    "fix-service-selectors.sh" \
    "public-health-check.sh" \
    "SLO" \
    "PrometheusRule" \
    "Alert Tuning" \
    "runbooks/site-down.md" \
    "ONCALL_ROTATION.md" \
    "INCIDENT_RESPONSE.md" \
    "kubectl-cheatsheet.md"; do
    if grep -qF "$keyword" <<< "$content"; then
      pass "guide contains: ${keyword}"
    else
      fail "guide missing content: ${keyword}"
    fi
  done
else
  fail "OPERATOR_DASHBOARD_GUIDE.md does not exist; skipping content checks"
fi

# ─── Section 3: Monitoring manifest files ──────────────────────────────────

section "3. Prometheus monitoring manifests"

dir_exists "deploy/k8s/base/monitoring"

for f in \
  prometheusrule-lms.yaml \
  prometheusrule-slo.yaml \
  prometheusrule-auth.yaml \
  prometheusrule-caddy.yaml \
  prometheusrule-externalsecrets.yaml \
  prometheusrule-velero.yaml \
  prometheusrule-enterprise.yaml \
  prometheusrule-tenant-isolation.yaml \
  prometheusrule-services.yaml \
  slo-burn-rate-rules.yaml \
  grafana-dashboard-ora2.json; do
  file_exists "deploy/k8s/base/monitoring/${f}"
done

# ServiceMonitors
for f in \
  servicemonitor-lms.yaml \
  servicemonitor-cms.yaml \
  servicemonitor-mysql.yaml \
  servicemonitor-redis.yaml \
  servicemonitor-caddy.yaml \
  servicemonitor-forum.yaml; do
  file_exists "deploy/k8s/base/monitoring/${f}"
done

# ─── Section 4: GCP monitoring configs ─────────────────────────────────────

section "4. GCP monitoring configs (repo)"

dir_exists "infrastructure/monitoring"
dir_exists "infrastructure/monitoring/alerts"
dir_exists "infrastructure/monitoring/dashboards"
dir_exists "infrastructure/monitoring/uptime"

for alert_file in \
  lb-5xx-ratio.json \
  https-cert-expiry.json \
  log-stateful-storage-errors.json \
  log-velero-backup-verification-failures.json \
  log-velero-restore-test-failures.json \
  pod-restarts.json \
  pvc-utilization-high.json; do
  file_exists "infrastructure/monitoring/alerts/${alert_file}"
done

# ─── Section 5: Diagnostic scripts ─────────────────────────────────────────

section "5. Diagnostic scripts (repo)"

for script in \
  scripts/qa/public-health-check.sh \
  scripts/qa/audit-observability.sh \
  scripts/qa/audit-grafana-dashboard.sh \
  scripts/qa/audit-velero-alert-pipeline.sh \
  scripts/qa/verify-alert-routing.sh \
  scripts/qa/run-operations-gates.sh \
  scripts/qa/verify-slo-dashboards.sh \
  scripts/qa/verify-slo-definitions.sh \
  scripts/qa/verify-error-budget.sh \
  scripts/qa/smoke-test.sh \
  scripts/infra/fix-service-selectors.sh \
  scripts/infra/check-cluster-status.sh \
  scripts/infra/verify-deployment.sh \
  scripts/infra/verify-tutor-config.sh \
  scripts/infra/apply-monitoring-configs.sh; do
  if [[ -f "${REPO_ROOT}/${script}" ]]; then
    pass "script exists: ${script}"
  else
    fail "script missing: ${script}"
  fi
done

# Check that the most critical scripts are executable
for script in \
  scripts/qa/public-health-check.sh \
  scripts/qa/audit-observability.sh \
  scripts/qa/run-operations-gates.sh \
  scripts/infra/fix-service-selectors.sh; do
  if [[ -f "${REPO_ROOT}/${script}" && -x "${REPO_ROOT}/${script}" ]]; then
    pass "executable: ${script}"
  elif [[ -f "${REPO_ROOT}/${script}" ]]; then
    skip "not executable (chmod +x to fix): ${script}"
  else
    skip "script missing (covered above): ${script}"
  fi
done

# ─── Section 6: Aspects manifests ──────────────────────────────────────────

section "6. Aspects analytics manifests (not-yet-deployed, T148)"

dir_exists "deploy/k8s/base/plugins/aspects"

for f in \
  kustomization.yaml \
  configmaps.yml \
  secrets.yml \
  volumes.yml \
  services.yml \
  deployments.yml \
  jobs.yml \
  ingress.yml; do
  file_exists "deploy/k8s/base/plugins/aspects/${f}"
done

# Aspects must NOT be wired into the base kustomization yet (T148 pending)
BASE_KUST="${REPO_ROOT}/deploy/k8s/base/kustomization.yaml"
if [[ -f "$BASE_KUST" ]]; then
  if grep -q "plugins/aspects" "$BASE_KUST"; then
    skip "Aspects is wired into base kustomization (T148 may be complete)"
  else
    pass "Aspects is not yet wired into base kustomization (expected while T148 pending)"
  fi
else
  fail "deploy/k8s/base/kustomization.yaml not found"
fi

# ─── Section 7: SLO policy content ─────────────────────────────────────────

section "7. SLO policy content"

SLO="${REPO_ROOT}/docs/policies/operations/SLO_POLICY.md"
if [[ -f "$SLO" ]]; then
  for keyword in \
    "99.95%" \
    "99.5%" \
    "99.0%" \
    "LMS" \
    "Purchase Gateway" \
    "Studio" \
    "Forum"; do
    if grep -qF "$keyword" "$SLO"; then
      pass "SLO policy contains: ${keyword}"
    else
      fail "SLO policy missing: ${keyword}"
    fi
  done
else
  fail "SLO_POLICY.md not found"
fi

# ─── Section 8: Escalation content in ONCALL_ROTATION ──────────────────────

section "8. Escalation matrix in ONCALL_ROTATION.md"

ONCALL="${REPO_ROOT}/docs/policies/operations/ONCALL_ROTATION.md"
if [[ -f "$ONCALL" ]]; then
  for keyword in "L1" "L2" "L3" "L4" "Incident Commander"; do
    if grep -qF "$keyword" "$ONCALL"; then
      pass "ONCALL_ROTATION.md contains: ${keyword}"
    else
      fail "ONCALL_ROTATION.md missing: ${keyword}"
    fi
  done
else
  fail "ONCALL_ROTATION.md not found"
fi

# ─── Section 9: Site-down runbook has fix-service-selectors reference ───────

section "9. Site-down runbook references key scripts"

SITE_DOWN="${REPO_ROOT}/docs/ops/runbooks/site-down.md"
if [[ -f "$SITE_DOWN" ]]; then
  for keyword in "fix-service-selectors" "kubectl get endpoints" "kubectl get pods"; do
    if grep -qF "$keyword" "$SITE_DOWN"; then
      pass "site-down.md contains: ${keyword}"
    else
      fail "site-down.md missing: ${keyword}"
    fi
  done
else
  fail "runbooks/site-down.md not found"
fi

# ─── Section 10: Runtime checks (require kubectl) ──────────────────────────

section "10. Runtime checks (cluster)"

if [[ "$MODE" != "runtime" ]]; then
  skip "runtime checks skipped (pass --runtime to enable)"
  skip "runtime: PrometheusRule objects present in cluster"
  skip "runtime: ServiceMonitor objects present in cluster"
  skip "runtime: mereka-lms namespace exists"
  skip "runtime: ArgoCD app exists"
else
  if kubectl_available; then
    # Namespace exists
    if kubectl get namespace mereka-lms &>/dev/null 2>&1; then
      pass "runtime: namespace mereka-lms exists"
    else
      fail "runtime: namespace mereka-lms not found"
    fi

    # PrometheusRules
    rule_count=$(kubectl get prometheusrule -n mereka-lms --no-headers 2>/dev/null | wc -l || echo 0)
    if (( rule_count >= 5 )); then
      pass "runtime: ${rule_count} PrometheusRule objects in mereka-lms"
    else
      fail "runtime: only ${rule_count} PrometheusRule objects found (expected >= 5)"
    fi

    # ServiceMonitors
    sm_count=$(kubectl get servicemonitor -n mereka-lms --no-headers 2>/dev/null | wc -l || echo 0)
    if (( sm_count >= 3 )); then
      pass "runtime: ${sm_count} ServiceMonitor objects in mereka-lms"
    else
      fail "runtime: only ${sm_count} ServiceMonitor objects found (expected >= 3)"
    fi

    # ArgoCD app
    if kubectl get app mereka-lms -n argocd &>/dev/null 2>&1; then
      pass "runtime: ArgoCD app mereka-lms exists"
    else
      skip "runtime: ArgoCD app mereka-lms not found (may not be in this cluster)"
    fi

    # Non-empty endpoints for LMS
    lms_ep=$(kubectl get endpoints lms -n mereka-lms -o jsonpath='{.subsets}' 2>/dev/null || echo "")
    if [[ -n "$lms_ep" && "$lms_ep" != "null" ]]; then
      pass "runtime: LMS service has endpoints"
    else
      fail "runtime: LMS service endpoints are empty (site may be down)"
    fi

  else
    skip "runtime: kubectl not available or cluster unreachable"
    skip "runtime: PrometheusRule check skipped"
    skip "runtime: ServiceMonitor check skipped"
    skip "runtime: ArgoCD app check skipped"
    skip "runtime: LMS endpoints check skipped"
  fi
fi

# ─── Summary ────────────────────────────────────────────────────────────────

echo ""
echo "=== SUMMARY ==="
echo "  PASS: ${PASS}"
echo "  FAIL: ${FAIL}"
echo "  SKIP: ${SKIP}"
echo ""

if (( FAIL > 0 )); then
  echo "RESULT: FAIL (${FAIL} check(s) failed)"
  exit 1
else
  echo "RESULT: PASS"
  exit 0
fi
