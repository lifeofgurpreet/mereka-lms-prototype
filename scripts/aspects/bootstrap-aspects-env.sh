#!/usr/bin/env bash
# bootstrap-aspects-env.sh — Idempotent Aspects environment bootstrap.
#
# Replaces ad-hoc manual init steps for the Aspects analytics stack.
# Checks/creates the MySQL superset database, force-syncs ExternalSecrets,
# and verifies all Aspects pods and init Jobs are in the expected state.
#
# Usage:
#   ./scripts/aspects/bootstrap-aspects-env.sh --env dev
#   ./scripts/aspects/bootstrap-aspects-env.sh --env staging
#   ./scripts/aspects/bootstrap-aspects-env.sh --env dev --check   # dry-run: verify only
#
# No --env prod — ADR-017 defers production Aspects to a later phase.

set -euo pipefail

# ---------------------------------------------------------------------------
# Colors and counters
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# shellcheck source=../shared/config.sh
source "${REPO_ROOT}/scripts/shared/config.sh"

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
pass() {
  echo -e "  ${GREEN}PASS${NC} $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo -e "  ${RED}FAIL${NC} $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

warn() {
  echo -e "  ${YELLOW}WARN${NC} $1"
  WARN_COUNT=$((WARN_COUNT + 1))
}

section() {
  echo ""
  echo -e "${CYAN}--- $1 ---${NC}"
}

usage() {
  echo "Usage: $0 --env <dev|staging> [--check]"
  echo ""
  echo "  --env dev|staging   Target environment (no prod — ADR-017)"
  echo "  --check             Dry-run: verify only, skip create/sync steps"
  exit 1
}

# kctl — kubectl with fixed context and namespace
kctl() {
  kubectl --context "$K8S_CTX" -n "$NS" "$@"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
ENV=""
CHECK_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV="$2"
      shift 2
      ;;
    --check)
      CHECK_ONLY=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      ;;
  esac
done

if [[ -z "$ENV" ]]; then
  echo "ERROR: --env is required" >&2
  usage
fi

# Reject prod
case "$ENV" in
  dev|staging) ;;
  prod|production)
    echo "ERROR: Production Aspects is deferred (ADR-017). Use --env dev or --env staging." >&2
    exit 1
    ;;
  *)
    echo "ERROR: Unsupported environment: $ENV" >&2
    usage
    ;;
esac

# ---------------------------------------------------------------------------
# Resolve K8s context and namespace
# ---------------------------------------------------------------------------
K8S_CTX="$(mereka_lms_default_context_for_env "$ENV")"
NS="$(mereka_lms_default_namespace_for_env "$ENV")"

echo "========================================================"
echo "  Aspects Bootstrap — env=${ENV}"
echo "  context=${K8S_CTX}  namespace=${NS}"
if $CHECK_ONLY; then
  echo "  mode: CHECK ONLY (dry-run)"
fi
echo "========================================================"

# ---------------------------------------------------------------------------
# Verify cluster connectivity
# ---------------------------------------------------------------------------
section "[0/6] Cluster Connectivity"

if kubectl --context "$K8S_CTX" cluster-info >/dev/null 2>&1; then
  pass "kubectl can reach cluster (context: ${K8S_CTX})"
else
  fail "Cannot reach cluster (context: ${K8S_CTX})"
  echo ""
  echo "Cannot proceed without cluster access. Aborting."
  exit 1
fi

if kctl get namespace "$NS" >/dev/null 2>&1; then
  pass "Namespace ${NS} exists"
else
  fail "Namespace ${NS} does not exist"
  echo ""
  echo "Cannot proceed without namespace. Aborting."
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 1: MySQL superset database
# ---------------------------------------------------------------------------
section "[1/6] MySQL Superset Database"

mysql_pod="$(kctl get pod -l app.kubernetes.io/name=mysql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "$mysql_pod" ]]; then
  # Also try the tutor-generated label
  mysql_pod="$(kctl get pod -l app=mysql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
fi

if [[ -z "$mysql_pod" ]]; then
  fail "No MySQL pod found in ${NS}"
else
  pass "MySQL pod found: ${mysql_pod}"

  if $CHECK_ONLY; then
    # In check mode, just verify the database exists
    db_exists="$(kctl exec "$mysql_pod" -- bash -c 'mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='"'"'superset'"'"'" -sN 2>/dev/null' || true)"
    if [[ "$db_exists" == "superset" ]]; then
      pass "MySQL database 'superset' exists"
    else
      warn "MySQL database 'superset' does not exist (run without --check to create)"
    fi
  else
    # Create database if not exists (idempotent)
    if kctl exec "$mysql_pod" -- bash -c 'mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS superset" 2>/dev/null'; then
      pass "MySQL database 'superset' created or already exists"
    else
      fail "Failed to create MySQL database 'superset'"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Step 2: Force-sync ExternalSecret
# ---------------------------------------------------------------------------
section "[2/6] ExternalSecret Force-Sync"

es_exists="$(kctl get externalsecret aspects-secrets -o name 2>/dev/null || true)"
if [[ -z "$es_exists" ]]; then
  warn "ExternalSecret 'aspects-secrets' not found in ${NS} — may not be deployed yet"
else
  if $CHECK_ONLY; then
    # In check mode, report the sync status
    sync_status="$(kctl get externalsecret aspects-secrets -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
    if [[ "$sync_status" == "True" ]]; then
      pass "ExternalSecret 'aspects-secrets' is synced (Ready=True)"
    else
      warn "ExternalSecret 'aspects-secrets' sync status: ${sync_status:-unknown}"
    fi
  else
    if kctl annotate externalsecret aspects-secrets force-sync="$(date +%s)" --overwrite 2>/dev/null; then
      pass "ExternalSecret 'aspects-secrets' force-sync triggered"
    else
      fail "Failed to annotate ExternalSecret 'aspects-secrets' for force-sync"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Step 3: Aspects pods — Running check
# ---------------------------------------------------------------------------
section "[3/6] Aspects Pods — Running"

EXPECTED_PODS=("clickhouse" "superset" "superset-worker" "ralph")

for pod_label in "${EXPECTED_PODS[@]}"; do
  # Try app.kubernetes.io/name label first, then fall back to app label
  pod_name="$(kctl get pod -l "app.kubernetes.io/name=${pod_label}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [[ -z "$pod_name" ]]; then
    pod_name="$(kctl get pod -l "app=${pod_label}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  fi

  if [[ -z "$pod_name" ]]; then
    fail "Pod '${pod_label}' not found in ${NS}"
    continue
  fi

  phase="$(kctl get pod "$pod_name" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  if [[ "$phase" == "Running" ]]; then
    pass "Pod '${pod_label}' is Running (${pod_name})"
  else
    fail "Pod '${pod_label}' is ${phase:-unknown} (expected Running) — ${pod_name}"
  fi
done

# ---------------------------------------------------------------------------
# Step 4: Init Jobs — Completed check
# ---------------------------------------------------------------------------
section "[4/6] Init Jobs — Completed"

EXPECTED_JOBS=("superset-init" "clickhouse-init")

for job_name in "${EXPECTED_JOBS[@]}"; do
  job_exists="$(kctl get job "$job_name" -o name 2>/dev/null || true)"
  if [[ -z "$job_exists" ]]; then
    warn "Job '${job_name}' not found in ${NS} — may not have run yet"
    continue
  fi

  succeeded="$(kctl get job "$job_name" -o jsonpath='{.status.succeeded}' 2>/dev/null || true)"
  if [[ "${succeeded:-0}" -ge 1 ]]; then
    pass "Job '${job_name}' completed successfully"
  else
    conditions="$(kctl get job "$job_name" -o jsonpath='{.status.conditions[0].type}' 2>/dev/null || true)"
    fail "Job '${job_name}' not succeeded (status: ${conditions:-unknown})"
  fi
done

# ---------------------------------------------------------------------------
# Step 5: Secret exists
# ---------------------------------------------------------------------------
section "[5/6] Aspects Secret"

if kctl get secret aspects-secrets -o name >/dev/null 2>&1; then
  pass "Secret 'aspects-secrets' exists in ${NS}"
  # Check key count
  key_count="$(kctl get secret aspects-secrets -o json 2>/dev/null | python3 -c 'import sys,json; print(len(json.load(sys.stdin).get("data",{})))' 2>/dev/null || echo "0")"
  if [[ "$key_count" -ge 1 ]]; then
    pass "Secret 'aspects-secrets' has ${key_count} key(s)"
  else
    warn "Secret 'aspects-secrets' appears empty"
  fi
else
  fail "Secret 'aspects-secrets' not found in ${NS}"
fi

# ---------------------------------------------------------------------------
# Step 6: Services exist
# ---------------------------------------------------------------------------
section "[6/6] Aspects Services"

EXPECTED_SVCS=("clickhouse" "superset")
for svc_name in "${EXPECTED_SVCS[@]}"; do
  if kctl get svc "$svc_name" -o name >/dev/null 2>&1; then
    pass "Service '${svc_name}' exists"
  else
    warn "Service '${svc_name}' not found in ${NS}"
  fi
done

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "========================================================"
echo -e "  PASS: ${GREEN}${PASS_COUNT}${NC}  FAIL: ${RED}${FAIL_COUNT}${NC}  WARN: ${YELLOW}${WARN_COUNT}${NC}"
echo "========================================================"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo ""
  echo "Bootstrap check FAILED. Debug commands:"
  echo ""
  echo "  Pods:       kubectl --context ${K8S_CTX} -n ${NS} get pods"
  echo "  Jobs:       kubectl --context ${K8S_CTX} -n ${NS} get jobs"
  echo "  Secrets:    kubectl --context ${K8S_CTX} -n ${NS} get externalsecrets"
  echo "  Logs:       kubectl --context ${K8S_CTX} -n ${NS} logs -l app.kubernetes.io/name=superset --tail=50"
  echo ""
  exit 1
fi

echo ""
if $CHECK_ONLY; then
  echo "RESULT: PASS — all verification checks passed (check-only mode)"
else
  echo "RESULT: PASS — Aspects environment bootstrap complete"
fi
exit 0
