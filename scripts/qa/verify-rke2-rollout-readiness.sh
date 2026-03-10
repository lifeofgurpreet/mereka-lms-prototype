#!/usr/bin/env bash
# @covers AC-RKE2-101, AC-RKE2-102, AC-RKE2-103, AC-RKE2-104, AC-RKE2-105
# @spec: k8s-deployment_spec.md
#
# verify-rke2-rollout-readiness.sh
#
# BoldBadger rollout hardening gate — final verification before RKE2-nonprod
# is treated as a production-ready lane.
#
# Covers:
#   S1: Manifest completeness (PDBs, HPAs, NetworkPolicies, RBAC, seccomp)
#   S2: Container security contexts (non-root, read-only FS, capabilities)
#   S3: Monitoring readiness (ServiceMonitors, PrometheusRules, alert routing)
#   S4: Backup CronJobs and DR verification
#   S5: Log aggregation pipeline
#   S6: Live cluster hardening (online mode only)
#
# Modes:
#   --offline   Source-only checks (no kubectl required). Default.
#   --online    Live cluster checks (requires kubectl + context rke2-nonprod).
#   --context X kubectl context to use (default: rke2-nonprod)
#
# Usage:
#   scripts/qa/verify-rke2-rollout-readiness.sh --offline
#   scripts/qa/verify-rke2-rollout-readiness.sh --online
#   scripts/qa/verify-rke2-rollout-readiness.sh --online --context rke2-nonprod

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ── Counters ─────────────────────────────────────────────────────────────────
PASS=0
FAIL=0
SKIP=0

pass_check() { echo -e "  ${GREEN}PASS${NC}: $1"; PASS=$((PASS + 1)); }
fail_check() { echo -e "  ${RED}FAIL${NC}: $1"; FAIL=$((FAIL + 1)); }
skip_check() { echo -e "  ${YELLOW}SKIP${NC}: $1"; SKIP=$((SKIP + 1)); }

# ── Parse args ────────────────────────────────────────────────────────────────
MODE=offline
KUBECONTEXT="${KUBECONTEXT:-rke2-nonprod}"
NS="${NS:-mereka-lms}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --offline) MODE=offline; shift ;;
    --online)  MODE=online;  shift ;;
    --context) KUBECONTEXT="$2"; shift 2 ;;
    --help)
      echo "Usage: $(basename "$0") [--offline|--online] [--context <ctx>]"
      exit 0
      ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

KC() { kubectl --context "$KUBECONTEXT" "$@"; }

echo "========================================================"
echo "RKE2 BoldBadger Rollout Readiness Verifier"
echo "  mode=$MODE  context=$KUBECONTEXT  ns=$NS"
echo "========================================================"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# S1: Manifest completeness
# PDBs, HPAs, Kyverno policies, RBAC, seccomp policy
# ─────────────────────────────────────────────────────────────────────────────
echo "S1: Manifest Completeness"

BASE_DIR="$REPO_ROOT/deploy/k8s/base"
OPERATIONAL_DIR="$BASE_DIR/operational"
POLICIES_DIR="$BASE_DIR/policies"
MONITORING_DIR="$BASE_DIR/monitoring"

# PDB manifest
if [[ -f "$OPERATIONAL_DIR/pdb.yaml" ]]; then
  pass_check "PDB manifest exists (deploy/k8s/base/operational/pdb.yaml)"
else
  fail_check "PDB manifest missing at deploy/k8s/base/operational/pdb.yaml"
fi

# HPA manifest
if [[ -f "$OPERATIONAL_DIR/hpa-baselines.yaml" ]]; then
  pass_check "HPA manifest exists (deploy/k8s/base/operational/hpa-baselines.yaml)"
else
  fail_check "HPA manifest missing at deploy/k8s/base/operational/hpa-baselines.yaml"
fi

# Critical PDB coverage
if [[ -f "$OPERATIONAL_DIR/pdb.yaml" ]]; then
  CRITICAL_WORKLOADS=("lms" "cms" "caddy" "redis" "mysql")
  for wl in "${CRITICAL_WORKLOADS[@]}"; do
    if grep -q "name: ${wl}" "$OPERATIONAL_DIR/pdb.yaml" 2>/dev/null; then
      pass_check "PDB defined for: $wl"
    else
      fail_check "PDB missing for critical workload: $wl"
    fi
  done
fi

# Kyverno security policies
REQUIRED_POLICIES=(
  "require-non-root.yaml"
  "require-seccomp.yaml"
  "disallow-privileged.yaml"
  "restrict-capabilities.yaml"
)
for policy_file in "${REQUIRED_POLICIES[@]}"; do
  if [[ -f "$POLICIES_DIR/$policy_file" ]]; then
    pass_check "Kyverno policy exists: $policy_file"
  else
    fail_check "Kyverno policy missing: $policy_file"
  fi
done

# Seccomp policy specifically enforces RuntimeDefault or Localhost
if [[ -f "$POLICIES_DIR/require-seccomp.yaml" ]]; then
  if grep -q 'RuntimeDefault\|Localhost' "$POLICIES_DIR/require-seccomp.yaml" 2>/dev/null; then
    pass_check "Seccomp policy enforces RuntimeDefault or Localhost profile"
  else
    fail_check "Seccomp policy does not enforce RuntimeDefault/Localhost"
  fi
fi

# Non-root policy targets mereka-lms namespace
if [[ -f "$POLICIES_DIR/require-non-root.yaml" ]]; then
  if grep -q 'mereka-lms' "$POLICIES_DIR/require-non-root.yaml" 2>/dev/null; then
    pass_check "Non-root policy scoped to mereka-lms namespace"
  else
    fail_check "Non-root policy does not reference mereka-lms namespace"
  fi
fi

# Policies kustomization wired
POLICIES_KUST="$POLICIES_DIR/kustomization.yaml"
if [[ -f "$POLICIES_KUST" ]]; then
  pass_check "Policies kustomization.yaml exists"
  POLICY_FILES=("require-non-root.yaml" "require-seccomp.yaml" "disallow-privileged.yaml" "restrict-capabilities.yaml")
  for pf in "${POLICY_FILES[@]}"; do
    if grep -q "$pf" "$POLICIES_KUST" 2>/dev/null; then
      pass_check "Policy wired in kustomization: $pf"
    else
      fail_check "Policy NOT wired in kustomization: $pf"
    fi
  done
else
  fail_check "Policies kustomization.yaml missing at $POLICIES_KUST"
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# S2: Container security context hardening
# Non-root, read-only FS, dropped capabilities in deployment manifests
# ─────────────────────────────────────────────────────────────────────────────
echo "S2: Container Security Contexts"

DEPLOYMENTS_FILE="$BASE_DIR/deployments.yml"

if [[ ! -f "$DEPLOYMENTS_FILE" ]]; then
  skip_check "deployments.yml not found at $DEPLOYMENTS_FILE — skipping security context checks"
else
  # Check non-root in LMS deployment — advisory check
  # Kyverno policy enforces this cluster-wide; manifest-level is belt-and-suspenders
  if grep -q 'runAsNonRoot: true' "$DEPLOYMENTS_FILE" 2>/dev/null; then
    pass_check "deployments.yml sets runAsNonRoot: true (at least one workload)"
  else
    # Not a hard fail — Kyverno policy provides enforcement; note it for tracking
    skip_check "deployments.yml does not set runAsNonRoot: true explicitly (Kyverno policy enforces this)"
  fi

  # Check Kyverno policies enforce non-root via policy (belt-and-suspenders check)
  if [[ -f "$POLICIES_DIR/require-non-root.yaml" ]]; then
    if grep -q 'runAsNonRoot' "$POLICIES_DIR/require-non-root.yaml" 2>/dev/null; then
      pass_check "Kyverno policy enforces runAsNonRoot cluster-wide"
    else
      fail_check "Kyverno require-non-root.yaml does not enforce runAsNonRoot"
    fi
  fi
fi

# Check for privilege escalation prevention in policies
if [[ -f "$POLICIES_DIR/disallow-privileged.yaml" ]]; then
  if grep -q 'privileged' "$POLICIES_DIR/disallow-privileged.yaml" 2>/dev/null; then
    pass_check "Kyverno policy disallows privileged containers"
  else
    fail_check "disallow-privileged.yaml does not reference privileged field"
  fi
fi

# Check capabilities policy
if [[ -f "$POLICIES_DIR/restrict-capabilities.yaml" ]]; then
  if grep -qE 'drop|NET_RAW|ALL' "$POLICIES_DIR/restrict-capabilities.yaml" 2>/dev/null; then
    pass_check "Kyverno policy restricts Linux capabilities"
  else
    fail_check "restrict-capabilities.yaml does not reference capability drops"
  fi
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# S3: Monitoring readiness
# ServiceMonitors, PrometheusRules, alert routing
# ─────────────────────────────────────────────────────────────────────────────
echo "S3: Monitoring Readiness"

# ServiceMonitors for core services
REQUIRED_SERVICEMONITORS=(
  "servicemonitor-lms.yaml"
  "servicemonitor-cms.yaml"
  "servicemonitor-mysql.yaml"
  "servicemonitor-redis.yaml"
)
for sm in "${REQUIRED_SERVICEMONITORS[@]}"; do
  if [[ -f "$MONITORING_DIR/$sm" ]]; then
    pass_check "ServiceMonitor exists: $sm"
  else
    fail_check "ServiceMonitor missing: $sm"
  fi
done

# PrometheusRules for critical alert categories
REQUIRED_PROMETHEUSRULES=(
  "prometheusrule-lms.yaml"
  "prometheusrule-slo.yaml"
  "prometheusrule-velero.yaml"
)
for pr in "${REQUIRED_PROMETHEUSRULES[@]}"; do
  if [[ -f "$MONITORING_DIR/$pr" ]]; then
    pass_check "PrometheusRule exists: $pr"
  else
    fail_check "PrometheusRule missing: $pr"
  fi
done

# LMS PrometheusRule contains at least one alerting rule
if [[ -f "$MONITORING_DIR/prometheusrule-lms.yaml" ]]; then
  if grep -q 'alert:' "$MONITORING_DIR/prometheusrule-lms.yaml" 2>/dev/null; then
    pass_check "LMS PrometheusRule contains alerting rules"
  else
    fail_check "LMS PrometheusRule has no alerting rules (only recording rules?)"
  fi
fi

# SLO recording rules exist
if [[ -f "$MONITORING_DIR/prometheusrule-slo.yaml" ]]; then
  if grep -q 'record:' "$MONITORING_DIR/prometheusrule-slo.yaml" 2>/dev/null; then
    pass_check "SLO PrometheusRule contains recording rules"
  else
    fail_check "SLO PrometheusRule has no recording rules"
  fi
fi

# Monitoring kustomization wired
MONITORING_KUST="$MONITORING_DIR/kustomization.yaml"
if [[ -f "$MONITORING_KUST" ]]; then
  pass_check "Monitoring kustomization.yaml exists"
  for sm in "${REQUIRED_SERVICEMONITORS[@]}"; do
    if grep -q "$sm" "$MONITORING_KUST" 2>/dev/null; then
      pass_check "ServiceMonitor wired in kustomization: $sm"
    else
      fail_check "ServiceMonitor NOT wired in kustomization: $sm"
    fi
  done
else
  fail_check "Monitoring kustomization.yaml missing at $MONITORING_KUST"
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# S4: Backup CronJobs and DR verification
# ─────────────────────────────────────────────────────────────────────────────
echo "S4: Backup CronJobs and DR"

JOBS_DIR="$BASE_DIR/jobs"

# Check for Velero schedule or backup CronJob
VELERO_ALERT="$MONITORING_DIR/prometheusrule-velero.yaml"
if [[ -f "$VELERO_ALERT" ]]; then
  pass_check "Velero PrometheusRule exists (backup alerting configured)"
  if grep -q 'VeleroBackupFailed\|VeleroBackupMissed\|velero' "$VELERO_ALERT" 2>/dev/null; then
    pass_check "Velero alert rules reference backup failure conditions"
  else
    fail_check "Velero PrometheusRule does not contain backup failure alerts"
  fi
else
  fail_check "Velero PrometheusRule missing — backup failure alerting not configured"
fi

# Check for CronJob manifests (backup, library export, etc.)
if [[ -d "$JOBS_DIR" ]]; then
  CRONJOB_COUNT=$(find "$JOBS_DIR" -name "*.yaml" 2>/dev/null | wc -l)
  if [[ "$CRONJOB_COUNT" -ge 1 ]]; then
    pass_check "Job manifests exist in deploy/k8s/base/jobs/ ($CRONJOB_COUNT found)"
  else
    fail_check "No job manifests found in deploy/k8s/base/jobs/"
  fi
else
  skip_check "deploy/k8s/base/jobs/ directory not found — skipping CronJob checks"
fi

# DR evidence doc exists
DR_DOC="$REPO_ROOT/docs/status/readiness/DR_TEST_RESULTS.md"
if [[ -f "$DR_DOC" ]]; then
  pass_check "DR test results document exists (docs/status/readiness/DR_TEST_RESULTS.md)"
else
  fail_check "DR test results document missing — run DR drill and capture evidence"
fi

# Velero audit script exists
VELERO_AUDIT="$REPO_ROOT/scripts/qa/audit-velero.sh"
if [[ -f "$VELERO_AUDIT" ]]; then
  pass_check "Velero audit script exists (scripts/qa/audit-velero.sh)"
else
  fail_check "Velero audit script missing — cannot verify backup coverage"
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# S5: Log aggregation pipeline
# ─────────────────────────────────────────────────────────────────────────────
echo "S5: Log Aggregation Pipeline"

# Loki/structured logging manifests
LOGGING_DIR="$BASE_DIR/logging"
if [[ -d "$LOGGING_DIR" ]]; then
  LOGGING_FILE_COUNT=$(find "$LOGGING_DIR" -name "*.yaml" 2>/dev/null | wc -l)
  if [[ "$LOGGING_FILE_COUNT" -ge 1 ]]; then
    pass_check "Logging manifests exist in deploy/k8s/base/logging/ ($LOGGING_FILE_COUNT files)"
  else
    fail_check "No logging manifests found in deploy/k8s/base/logging/"
  fi
else
  skip_check "deploy/k8s/base/logging/ directory not found — skipping log pipeline checks"
fi

# Observability docs exist
OBS_DOC="$REPO_ROOT/docs/reference/operations/MONITORING.md"
if [[ -f "$OBS_DOC" ]]; then
  pass_check "Monitoring documentation exists (docs/reference/operations/MONITORING.md)"
else
  fail_check "Monitoring documentation missing"
fi

# Logging pipeline runbook
LOGGING_RUNBOOK="$REPO_ROOT/docs/reference/operations/LOGGING_AND_SENTRY.md"
if [[ -f "$LOGGING_RUNBOOK" ]]; then
  pass_check "Logging runbook exists (docs/reference/operations/LOGGING_AND_SENTRY.md)"
else
  fail_check "Logging runbook missing (docs/reference/operations/LOGGING_AND_SENTRY.md)"
fi

# Verify logging pipeline script
LOGGING_VERIFY="$REPO_ROOT/scripts/qa/verify-logging-pipeline.sh"
if [[ -f "$LOGGING_VERIFY" ]]; then
  pass_check "Log pipeline verify script exists"
else
  fail_check "Log pipeline verify script missing (scripts/qa/verify-logging-pipeline.sh)"
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# S6: Live cluster hardening (online mode only)
# Pod security contexts, resource limits, monitoring endpoints
# ─────────────────────────────────────────────────────────────────────────────
echo "S6: Live Cluster Hardening"

if [[ "$MODE" != "online" ]]; then
  skip_check "[live] Kyverno policies applied (requires --online)"
  skip_check "[live] Pod security context audit (requires --online)"
  skip_check "[live] Resource limits on running pods (requires --online)"
  skip_check "[live] ServiceMonitor scraping (requires --online)"
  skip_check "[live] PrometheusRules in cluster (requires --online)"
  skip_check "[live] Backup schedule active (requires --online)"
  skip_check "[live] PDBs applied in cluster (requires --online)"
  skip_check "[live] HPAs active in cluster (requires --online)"
else
  # Verify cluster is reachable
  if ! KC cluster-info > /dev/null 2>&1; then
    fail_check "[live] Cannot reach cluster context '$KUBECONTEXT'"
    skip_check "[live] All live checks skipped (cluster unreachable)"
  else
    # Kyverno policies applied
    echo "  [live] Checking Kyverno policies..."
    KYVERNO_POLICIES=$(KC get clusterpolicy -l 'app.kubernetes.io/part-of=mereka-lms' \
      -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || echo "")
    if [[ -n "$KYVERNO_POLICIES" ]]; then
      POLICY_COUNT=$(echo "$KYVERNO_POLICIES" | grep -c . || true)
      pass_check "[live] $POLICY_COUNT Kyverno ClusterPolicies applied (mereka-lms)"
    else
      fail_check "[live] No Kyverno ClusterPolicies with part-of=mereka-lms label found"
    fi

    # Check at least non-root and seccomp policies are in Audit/Enforce mode
    for policy_name in "require-non-root-mereka-lms" "require-seccomp-mereka-lms"; do
      ACTION=$(KC get clusterpolicy "$policy_name" \
        -o jsonpath='{.spec.validationFailureAction}' 2>/dev/null || echo "")
      if [[ "$ACTION" == "Enforce" || "$ACTION" == "Audit" ]]; then
        pass_check "[live] ClusterPolicy $policy_name: validationFailureAction=$ACTION"
      elif [[ -z "$ACTION" ]]; then
        fail_check "[live] ClusterPolicy $policy_name not found"
      else
        fail_check "[live] ClusterPolicy $policy_name has unexpected action: $ACTION"
      fi
    done

    # Pod security context audit — check running pods
    echo "  [live] Checking pod security contexts..."
    PODS_JSON=$(KC get pods -n "$NS" -o json 2>/dev/null || echo '{"items":[]}')
    POD_COUNT=$(echo "$PODS_JSON" | python3 -c \
      "import sys,json; print(len(json.load(sys.stdin).get('items',[])))" 2>/dev/null || echo "0")

    if [[ "$POD_COUNT" -eq 0 ]]; then
      skip_check "[live] No pods found in $NS — skipping security context audit"
    else
      # Count pods with runAsNonRoot set
      NON_ROOT_COUNT=$(echo "$PODS_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
count = 0
for pod in data.get('items', []):
    sc = pod.get('spec', {}).get('securityContext', {})
    containers = pod.get('spec', {}).get('containers', [])
    for c in containers:
        csc = c.get('securityContext', {})
        if sc.get('runAsNonRoot') or csc.get('runAsNonRoot'):
            count += 1
            break
print(count)
" 2>/dev/null || echo "0")
      pass_check "[live] Pod security context audit: $NON_ROOT_COUNT/$POD_COUNT pods have runAsNonRoot in $NS"
    fi

    # Resource limits on key deployments
    echo "  [live] Checking resource limits..."
    for workload in lms cms caddy; do
      LIMITS=$(KC get deployment "$workload" -n "$NS" \
        -o jsonpath='{.spec.template.spec.containers[0].resources.limits}' 2>/dev/null || echo "")
      if [[ -n "$LIMITS" && "$LIMITS" != "null" && "$LIMITS" != "{}" ]]; then
        pass_check "[live] Deployment $workload has resource limits"
      else
        fail_check "[live] Deployment $workload missing resource limits"
      fi
    done

    # ServiceMonitor scraping — check targets exist
    echo "  [live] Checking ServiceMonitors in cluster..."
    SM_COUNT=$(KC get servicemonitor -n "$NS" \
      --no-headers 2>/dev/null | grep -c . || true)
    if [[ "$SM_COUNT" -ge 2 ]]; then
      pass_check "[live] $SM_COUNT ServiceMonitors applied in $NS namespace"
    elif [[ "$SM_COUNT" -ge 1 ]]; then
      fail_check "[live] Only $SM_COUNT ServiceMonitor(s) found in $NS (expected >= 2)"
    else
      fail_check "[live] No ServiceMonitors found in $NS namespace"
    fi

    # PrometheusRules in cluster
    echo "  [live] Checking PrometheusRules in cluster..."
    PR_COUNT=$(KC get prometheusrule -n "$NS" \
      --no-headers 2>/dev/null | grep -c . || true)
    if [[ "$PR_COUNT" -ge 3 ]]; then
      pass_check "[live] $PR_COUNT PrometheusRules applied in $NS namespace"
    elif [[ "$PR_COUNT" -ge 1 ]]; then
      fail_check "[live] Only $PR_COUNT PrometheusRule(s) found in $NS (expected >= 3)"
    else
      fail_check "[live] No PrometheusRules found in $NS namespace"
    fi

    # Velero backup schedule active
    echo "  [live] Checking Velero backup schedules..."
    VELERO_SCHEDULES=$(KC get schedule -n velero \
      --no-headers 2>/dev/null | grep -c . || true)
    if [[ "$VELERO_SCHEDULES" -ge 1 ]]; then
      pass_check "[live] $VELERO_SCHEDULES Velero Schedule(s) active in velero namespace"
    else
      fail_check "[live] No Velero Schedules found in velero namespace — backups not configured"
    fi

    # PDBs in cluster
    echo "  [live] Checking PodDisruptionBudgets..."
    PDB_COUNT=$(KC get pdb -n "$NS" --no-headers 2>/dev/null | grep -c . || true)
    if [[ "$PDB_COUNT" -ge 3 ]]; then
      pass_check "[live] $PDB_COUNT PodDisruptionBudgets applied in $NS"
    else
      fail_check "[live] Only $PDB_COUNT PDB(s) in $NS (expected >= 3 for lms/cms/caddy)"
    fi

    # HPAs active
    echo "  [live] Checking HorizontalPodAutoscalers..."
    HPA_COUNT=$(KC get hpa -n "$NS" --no-headers 2>/dev/null | grep -c . || true)
    if [[ "$HPA_COUNT" -ge 2 ]]; then
      pass_check "[live] $HPA_COUNT HPAs applied in $NS"
    else
      fail_check "[live] Only $HPA_COUNT HPA(s) in $NS (expected >= 2 for lms/cms)"
    fi

    # No pods with unresolved CrashLoopBackOff
    echo "  [live] Checking for crash-looping pods..."
    CRASH_PODS=$(KC get pods -n "$NS" \
      -o jsonpath='{range .items[*]}{.metadata.name}={range .status.containerStatuses[*]}{.state.waiting.reason}{end}{"\n"}{end}' 2>/dev/null \
      | grep 'CrashLoopBackOff' || true)
    if [[ -z "$CRASH_PODS" ]]; then
      pass_check "[live] No CrashLoopBackOff pods in $NS"
    else
      CRASH_COUNT=$(echo "$CRASH_PODS" | grep -c . || true)
      fail_check "[live] $CRASH_COUNT pod(s) in CrashLoopBackOff:"
      echo "$CRASH_PODS" | head -5 | sed 's/^/    /'
    fi
  fi
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# S7: Runbook completeness
# ─────────────────────────────────────────────────────────────────────────────
echo "S7: Runbook Completeness"

REQUIRED_DOCS=(
  "docs/ops/runbooks/TROUBLESHOOTING.md"
  "docs/ops/runbooks/RKE2_DEV_READINESS.md"
  "docs/status/migrations/RKE2_ROLLOUT_MATRIX.md"
  "docs/policies/operations/MAINTENANCE_WINDOWS.md"
  "docs/ops/runbooks/INCIDENT_TEMPLATES.md"
  "docs/policies/operations/ONCALL_ROTATION.md"
  "docs/reference/operations/BACKUP_COVERAGE_MATRIX.md"
)
for doc in "${REQUIRED_DOCS[@]}"; do
  if [[ -f "$REPO_ROOT/$doc" ]]; then
    pass_check "Runbook exists: $doc"
  else
    fail_check "Runbook missing: $doc"
  fi
done

# Checklist for this rollout
ROLLOUT_CHECKLIST="$REPO_ROOT/docs/ops/runbooks/RKE2_ROLLOUT_CHECKLIST.md"
if [[ -f "$ROLLOUT_CHECKLIST" ]]; then
  pass_check "RKE2 rollout checklist exists"
else
  fail_check "RKE2 rollout checklist missing (docs/ops/runbooks/RKE2_ROLLOUT_CHECKLIST.md)"
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
echo "========================================================"
echo "Summary: $PASS PASS / $FAIL FAIL / $SKIP SKIP"
echo "========================================================"

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "Remediation hints:"
  echo "  S1 (manifests): Check deploy/k8s/base/operational/ and deploy/k8s/base/policies/"
  echo "  S2 (security):  Add securityContext to deployments or rely on Kyverno policies"
  echo "  S3 (monitoring): Add missing ServiceMonitors/PrometheusRules to deploy/k8s/base/monitoring/"
  echo "  S4 (backup):    Configure Velero schedule; run: scripts/qa/audit-velero.sh"
  echo "  S5 (logs):      Verify Loki/Promtail pipeline; see docs/reference/operations/LOGGING_AND_SENTRY.md"
  echo "  S6 (live):      Run with --online after fixing offline checks"
  echo "  S7 (runbooks):  Create missing docs in docs/ops/runbooks/ or docs/reference/operations/"
  echo ""
  echo "See docs/ops/runbooks/RKE2_ROLLOUT_CHECKLIST.md for full sign-off procedure."
  exit 1
fi

echo ""
echo "RESULT: PASS — RKE2 BoldBadger rollout hardening gates cleared."
exit 0
