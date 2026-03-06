#!/usr/bin/env bash
# verify-ecommerce-worker-health.sh — Diagnose ecommerce-worker CrashLoopBackOff.
#
# The legacy Oscar ecommerce-worker is expected to be unstable on nonprod
# because Oscar is not fully configured there. Payments-gateway is the
# replacement (dark-launched, ENABLE_GATEWAY_FULFILLMENT=false).
#
# Modes:
#   --offline  Source / manifest checks only (no kubectl). Default.
#   --online   Live cluster checks (requires kubectl access).
#
# Usage:
#   scripts/qa/verify-ecommerce-worker-health.sh [--offline] [--online] [--help]
#
# @spec: ecommerce-purchase-gateway_spec.md
# @covers AC-031

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ── Counters ────────────────────────────────────────────────────────────────
PASS=0
FAIL=0
SKIP=0

# ── Helpers ─────────────────────────────────────────────────────────────────
pass() { printf "  [PASS]  %s\n" "$*"; PASS=$((PASS + 1)); }
fail() { printf "  [FAIL]  %s\n" "$*"; FAIL=$((FAIL + 1)); }
skip() { printf "  [SKIP]  %s\n" "$*"; SKIP=$((SKIP + 1)); }
info() { printf "  [INFO]  %s\n" "$*"; }
header() { printf "\n── %s ──\n" "$*"; }

usage() {
  cat <<'EOF'
Usage:
  scripts/qa/verify-ecommerce-worker-health.sh [--offline] [--online] [--help]

Options:
  --offline   Manifest / source checks only (default). No kubectl required.
  --online    Live cluster checks. Requires kubectl + a valid K8s context.
  --help      Show this help.

Environment variables (online mode):
  K8S_NAMESPACE   Kubernetes namespace (default: mereka-lms)
  K8S_CONTEXT     kubectl context to use (default: current context)

Exit codes:
  0  All executed checks pass.
  1  One or more checks failed.
EOF
}

# ── Argument parsing ─────────────────────────────────────────────────────────
MODE=offline
while [[ $# -gt 0 ]]; do
  case "$1" in
    --offline) MODE=offline; shift ;;
    --online)  MODE=online;  shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf "Unknown argument: %s\n" "$1" >&2; usage; exit 1 ;;
  esac
done

NAMESPACE="${K8S_NAMESPACE:-mereka-lms}"
CONTEXT_ARGS=()
if [[ -n "${K8S_CONTEXT:-}" ]]; then
  CONTEXT_ARGS+=(--context "${K8S_CONTEXT}")
fi

printf "=== ecommerce-worker Health Verifier ===\n"
printf "mode=%s  namespace=%s\n" "$MODE" "$NAMESPACE"

# ════════════════════════════════════════════════════════════════════════════
# OFFLINE CHECKS
# ════════════════════════════════════════════════════════════════════════════
run_offline_checks() {
  # ── 1. Deployment manifest exists ────────────────────────────────────────
  header "1. Deployment manifest"

  LEGACY_DEPLOYMENTS_FILE="${REPO_ROOT}/deploy/k8s/base/deployments.yml"
  SPLIT_WORKER_DEPLOYMENT="${REPO_ROOT}/deploy/k8s/base/apps/ecommerce-worker/deployment.yaml"
  WORKER_SETTINGS="${REPO_ROOT}/deploy/k8s/base/plugins/ecommerce/apps/ecommerce-worker/settings/production.py"
  ECOM_SETTINGS="${REPO_ROOT}/deploy/k8s/base/plugins/ecommerce/apps/ecommerce/settings/production.py"
  WORKER_PRESENT=false
  WORKER_MANIFEST=""

  if [[ -f "$SPLIT_WORKER_DEPLOYMENT" ]]; then
    WORKER_PRESENT=true
    WORKER_MANIFEST="$SPLIT_WORKER_DEPLOYMENT"
    pass "ecommerce-worker Deployment manifest exists (${WORKER_MANIFEST##"$REPO_ROOT"/})"
  elif [[ -f "$LEGACY_DEPLOYMENTS_FILE" ]] && grep -q "name: ecommerce-worker$" "$LEGACY_DEPLOYMENTS_FILE" 2>/dev/null; then
    WORKER_PRESENT=true
    WORKER_MANIFEST="$LEGACY_DEPLOYMENTS_FILE"
    pass "ecommerce-worker Deployment found in legacy deployments manifest"
  else
    skip "ecommerce-worker Deployment manifest not present (consistent with Oscar deprecation path)"
    info "Worker-specific checks below will be skipped unless manifest is restored"
  fi

  # ── 2. Required env vars ─────────────────────────────────────────────────
  header "2. Required environment variables"

  if [[ "$WORKER_PRESENT" == "true" ]] && grep -q "WORKER_CONFIGURATION_MODULE" "$WORKER_MANIFEST" 2>/dev/null; then
    pass "WORKER_CONFIGURATION_MODULE env var set in Deployment"
  elif [[ "$WORKER_PRESENT" == "true" ]]; then
    fail "WORKER_CONFIGURATION_MODULE env var missing from ecommerce-worker Deployment"
    info "Expected value: ecommerce_worker.configuration.tutor.production"
  else
    skip "WORKER_CONFIGURATION_MODULE check skipped (ecommerce-worker Deployment not present)"
  fi

  if [[ "$WORKER_PRESENT" == "true" ]] && grep -q "C_FORCE_ROOT" "$WORKER_MANIFEST" 2>/dev/null; then
    pass "C_FORCE_ROOT env var present (required for Celery running as root)"
  elif [[ "$WORKER_PRESENT" == "true" ]]; then
    fail "C_FORCE_ROOT env var missing — Celery will refuse to run as root (uid=0)"
  else
    skip "C_FORCE_ROOT check skipped (ecommerce-worker Deployment not present)"
  fi

  # ── 3. ConfigMap / settings volume ───────────────────────────────────────
  header "3. Worker settings ConfigMap"

  if [[ "$WORKER_PRESENT" == "true" ]] && [[ -f "$WORKER_SETTINGS" ]]; then
    pass "ecommerce-worker settings file exists"
  elif [[ "$WORKER_PRESENT" == "true" ]]; then
    fail "ecommerce-worker settings file missing (deploy/k8s/base/plugins/ecommerce/apps/ecommerce-worker/settings/production.py)"
  else
    skip "ecommerce-worker settings check skipped (worker manifest not present)"
  fi

  if [[ "$WORKER_PRESENT" == "true" ]] && grep -q "ecommerce-worker-settings" "$WORKER_MANIFEST" 2>/dev/null; then
    pass "ecommerce-worker-settings ConfigMap referenced in Deployment volumes"
  elif [[ "$WORKER_PRESENT" == "true" ]]; then
    fail "ecommerce-worker-settings ConfigMap not referenced — settings will not be mounted"
  else
    skip "ecommerce-worker-settings ConfigMap reference check skipped (worker manifest not present)"
  fi

  # ── 4. Celery broker config ───────────────────────────────────────────────
  header "4. Celery broker configuration"

  if [[ "$WORKER_PRESENT" == "true" ]] && [[ -f "$WORKER_SETTINGS" ]]; then
    if grep -q "BROKER_URL" "$WORKER_SETTINGS"; then
      pass "BROKER_URL defined in worker production.py settings"
    else
      fail "BROKER_URL not defined in worker production settings — Celery cannot start"
      info "Expected: BROKER_URL = 'redis://redis:6379'"
    fi
  elif [[ "$WORKER_PRESENT" == "true" ]]; then
    skip "Worker settings file missing; cannot check Celery broker config"
  else
    skip "Celery broker check skipped (ecommerce-worker Deployment not present)"
  fi

  # ── 5. ExternalSecrets — required ecommerce keys ─────────────────────────
  header "5. ExternalSecrets coverage"

  SECRETS_FILE="${REPO_ROOT}/deploy/k8s/base/secrets/external-secrets.yaml"
  REQUIRED_SECRETS=(
    "MEREKA_LMS_JWT_SECRET_KEY_ECOMMERCE"
    "MEREKA_LMS_ECOMMERCE_SECRET_KEY"
    "MEREKA_LMS_ECOMMERCE_BACKEND_OAUTH2_SECRET"
    "MEREKA_LMS_ECOMMERCE_OAUTH2_SECRET"
    "MEREKA_LMS_MYSQL_ECOMMERCE_PASSWORD"
  )

  if [[ "$WORKER_PRESENT" != "true" ]]; then
    skip "Legacy Oscar secret coverage skipped (ecommerce-worker is decommissioned in manifests)"
  elif [[ -f "$SECRETS_FILE" ]]; then
    pass "ExternalSecrets manifest exists"
    for secret_key in "${REQUIRED_SECRETS[@]}"; do
      if grep -q "$secret_key" "$SECRETS_FILE"; then
        pass "ExternalSecret maps $secret_key"
      else
        fail "ExternalSecret does NOT map $secret_key — pod will crash if key is needed"
      fi
    done
  else
    skip "ExternalSecrets manifest not found at deploy/k8s/base/secrets/external-secrets.yaml"
  fi

  # ── 6. Database connection config ────────────────────────────────────────
  header "6. Database connection"

  if [[ "$WORKER_PRESENT" == "true" ]] && [[ -f "$ECOM_SETTINGS" ]]; then
    pass "Ecommerce main service settings file exists"
    if grep -qE "MYSQL|DATABASE|DB_HOST" "$ECOM_SETTINGS"; then
      pass "Database connection config present in ecommerce settings"
    else
      fail "No database connection config found in ecommerce main settings"
      info "Expected: DATABASES with MySQL host, user, password, db name"
    fi
  elif [[ "$WORKER_PRESENT" == "true" ]]; then
    skip "Ecommerce main settings not found; cannot verify DB config"
    info "Expected path: deploy/k8s/base/plugins/ecommerce/apps/ecommerce/settings/production.py"
  else
    skip "Database connection check skipped (ecommerce-worker Deployment not present)"
  fi

  # The worker itself does NOT connect to MySQL directly (only via Celery tasks
  # that are dispatched from the ecommerce main pod). Its settings don't need
  # DATABASES — but it does require a Redis broker.
  if [[ "$WORKER_PRESENT" == "true" ]] && [[ -f "$WORKER_SETTINGS" ]]; then
    if grep -q "redis" "$WORKER_SETTINGS"; then
      pass "Redis broker reference present in worker settings"
    else
      fail "No Redis reference in worker settings — broker may not be configured"
    fi
  elif [[ "$WORKER_PRESENT" == "true" ]]; then
    skip "Redis broker reference check skipped (worker settings file missing)"
  fi

  # ── 7. Purchase Gateway (replacement service) ────────────────────────────
  header "7. Purchase Gateway replacement status"

  PG_DIR="${REPO_ROOT}/services/purchase-gateway"
  PG_DEPLOY_BASE="${REPO_ROOT}/deploy/k8s/base/apps/purchase-gateway/deployment.yaml"
  PG_DEPLOY_LEGACY="${PG_DIR}/k8s/deployment.yaml"
  PG_DEPLOY=""

  if [[ -d "$PG_DIR" ]]; then
    pass "Purchase Gateway service directory exists (services/purchase-gateway/)"
  else
    fail "Purchase Gateway service directory missing — replacement not scaffolded"
  fi

  if [[ -f "$PG_DEPLOY_BASE" ]]; then
    PG_DEPLOY="$PG_DEPLOY_BASE"
    pass "Purchase Gateway Deployment manifest present (deploy/k8s/base/apps/purchase-gateway)"
  elif [[ -f "$PG_DEPLOY_LEGACY" ]]; then
    PG_DEPLOY="$PG_DEPLOY_LEGACY"
    pass "Purchase Gateway Deployment manifest present (services/purchase-gateway/k8s legacy mirror)"
  else
    fail "Purchase Gateway Deployment manifest missing in both canonical and legacy paths"
  fi

  if [[ -n "$PG_DEPLOY" ]]; then
    if grep -q "ENABLE_GATEWAY_FULFILLMENT.*false" "$PG_DEPLOY"; then
      pass "ENABLE_GATEWAY_FULFILLMENT=false — Purchase Gateway is dark-launched (Oscar still active)"
      info "ecommerce-worker CrashLoop on nonprod is expected until Gateway is activated"
    elif grep -q "ENABLE_GATEWAY_FULFILLMENT" "$PG_DEPLOY"; then
      info "ENABLE_GATEWAY_FULFILLMENT is set; verify value before assuming Oscar is inactive"
    else
      fail "ENABLE_GATEWAY_FULFILLMENT flag not found in Purchase Gateway deployment"
    fi
  fi

  # ── 8. ADR for deprecation decision ─────────────────────────────────────
  header "8. Deprecation documentation"

  ADR_FILE="${REPO_ROOT}/docs/adr/018-purchase-gateway-replaces-oscar-ecommerce.md"
  if [[ -f "$ADR_FILE" ]]; then
    pass "ADR-018 (Oscar deprecation decision) documented"
  else
    skip "ADR-018 not found at docs/adr/018-purchase-gateway-replaces-oscar-ecommerce.md"
  fi

  RUNBOOK="${REPO_ROOT}/docs/operations/ECOMMERCE_WORKER_TROUBLESHOOTING.md"
  if [[ -f "$RUNBOOK" ]]; then
    pass "ecommerce-worker troubleshooting runbook exists"
  else
    skip "Runbook not found at docs/operations/ECOMMERCE_WORKER_TROUBLESHOOTING.md"
  fi
}

# ════════════════════════════════════════════════════════════════════════════
# ONLINE CHECKS
# ════════════════════════════════════════════════════════════════════════════
run_online_checks() {
  header "Online: kubectl availability"

  if ! command -v kubectl >/dev/null 2>&1; then
    skip "kubectl not found — skipping all live cluster checks"
    return
  fi
  pass "kubectl is available"

  if ! kubectl "${CONTEXT_ARGS[@]}" get namespace "$NAMESPACE" >/dev/null 2>&1; then
    skip "Namespace $NAMESPACE not reachable — skipping live cluster checks"
    info "Verify kubectl context and cluster connectivity"
    return
  fi
  pass "Namespace $NAMESPACE is reachable"

  # ── 9. ecommerce-worker pod status ───────────────────────────────────────
  header "9. ecommerce-worker pod status (live)"

  WORKER_PODS="$(kubectl "${CONTEXT_ARGS[@]}" get pods \
    -n "$NAMESPACE" \
    -l "app.kubernetes.io/name=ecommerce-worker" \
    --no-headers 2>/dev/null || true)"

  if [[ -z "$WORKER_PODS" ]]; then
    skip "No ecommerce-worker pods found in namespace $NAMESPACE"
    info "The Deployment may have replicas=0 or may not be deployed to this cluster"
    return
  fi

  info "ecommerce-worker pods:"
  echo "$WORKER_PODS" | while IFS= read -r line; do
    printf "    %s\n" "$line"
  done

  # Check for CrashLoopBackOff
  if echo "$WORKER_PODS" | grep -q "CrashLoopBackOff"; then
    fail "ecommerce-worker pod(s) in CrashLoopBackOff"
    info "This is expected on nonprod if Oscar is not fully configured"
    info "See docs/operations/ECOMMERCE_WORKER_TROUBLESHOOTING.md for decision tree"
  elif echo "$WORKER_PODS" | grep -q "Running"; then
    pass "ecommerce-worker pod(s) in Running state"
  elif echo "$WORKER_PODS" | grep -q "Error"; then
    fail "ecommerce-worker pod(s) in Error state"
  else
    info "ecommerce-worker pod state is neither Running nor CrashLoopBackOff — check status above"
  fi

  # ── 10. Restart count ────────────────────────────────────────────────────
  header "10. Restart count"

  RESTART_COUNT="$(kubectl "${CONTEXT_ARGS[@]}" get pods \
    -n "$NAMESPACE" \
    -l "app.kubernetes.io/name=ecommerce-worker" \
    --no-headers \
    -o custom-columns="RESTARTS:.status.containerStatuses[0].restartCount" \
    2>/dev/null | grep -v "^$" | head -1 || echo "unknown")"

  info "ecommerce-worker restart count: ${RESTART_COUNT}"

  if [[ "$RESTART_COUNT" =~ ^[0-9]+$ ]]; then
    if [[ "$RESTART_COUNT" -gt 5 ]]; then
      fail "Restart count is ${RESTART_COUNT} — pod is crash-looping"
      info "Run: kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=ecommerce-worker --tail=50"
    elif [[ "$RESTART_COUNT" -gt 0 ]]; then
      info "Restart count is ${RESTART_COUNT} — some restarts have occurred"
    else
      pass "Restart count is 0 — no crashes observed"
    fi
  fi

  # ── 11. Recent pod logs ───────────────────────────────────────────────────
  header "11. Recent pod logs (last 20 lines)"

  POD_NAME="$(kubectl "${CONTEXT_ARGS[@]}" get pods \
    -n "$NAMESPACE" \
    -l "app.kubernetes.io/name=ecommerce-worker" \
    --no-headers \
    -o custom-columns="NAME:.metadata.name" \
    2>/dev/null | head -1 || true)"

  if [[ -z "$POD_NAME" ]]; then
    skip "Could not determine ecommerce-worker pod name for log capture"
  else
    info "Capturing last 20 lines from pod: $POD_NAME"
    printf "\n"
    kubectl "${CONTEXT_ARGS[@]}" logs \
      -n "$NAMESPACE" \
      "$POD_NAME" \
      --tail=20 \
      --previous 2>/dev/null \
      | sed 's/^/    /' \
      || kubectl "${CONTEXT_ARGS[@]}" logs \
        -n "$NAMESPACE" \
        "$POD_NAME" \
        --tail=20 \
        2>/dev/null \
        | sed 's/^/    /' \
      || info "(no logs available)"
    printf "\n"
    pass "Log capture completed (review above for crash cause)"
  fi

  # ── 12. Ecommerce main pod health ─────────────────────────────────────────
  header "12. Ecommerce main pod health (worker dependency)"

  ECOM_PODS="$(kubectl "${CONTEXT_ARGS[@]}" get pods \
    -n "$NAMESPACE" \
    -l "app.kubernetes.io/name=ecommerce" \
    --no-headers 2>/dev/null || true)"

  if [[ -z "$ECOM_PODS" ]]; then
    skip "No ecommerce (main) pods found — worker may fail due to missing upstream service"
    info "The worker dispatches tasks that require the main ecommerce pod to be healthy"
  elif echo "$ECOM_PODS" | grep -q "Running"; then
    pass "Ecommerce main pod is Running (worker dependency satisfied)"
  else
    fail "Ecommerce main pod is NOT Running — worker tasks will fail"
    info "ecommerce pod status:"
    echo "$ECOM_PODS" | while IFS= read -r line; do
      printf "    %s\n" "$line"
    done
  fi

  # ── 13. Purchase Gateway pod health ─────────────────────────────────────
  header "13. Purchase Gateway pod health"

  PG_PODS="$(kubectl "${CONTEXT_ARGS[@]}" get pods \
    -n "$NAMESPACE" \
    -l "app.kubernetes.io/name=payments-gateway" \
    --no-headers 2>/dev/null || true)"

  if [[ -z "$PG_PODS" ]]; then
    skip "No payments-gateway pods found — Purchase Gateway not yet deployed to this cluster"
    info "Deploy with: kubectl apply -k services/purchase-gateway/k8s/"
  elif echo "$PG_PODS" | grep -q "Running"; then
    pass "Payments-gateway pod is Running (replacement service active)"
  else
    fail "Payments-gateway pod is NOT Running"
    echo "$PG_PODS" | while IFS= read -r line; do
      printf "    %s\n" "$line"
    done
  fi
}

# ════════════════════════════════════════════════════════════════════════════
# Main
# ════════════════════════════════════════════════════════════════════════════
cd "$REPO_ROOT"

if [[ "$MODE" == "offline" ]]; then
  run_offline_checks
elif [[ "$MODE" == "online" ]]; then
  run_offline_checks
  run_online_checks
fi

# ── Summary ──────────────────────────────────────────────────────────────────
printf "\n=== Results ===\n"
printf "  PASS  %d\n" "$PASS"
printf "  FAIL  %d\n" "$FAIL"
printf "  SKIP  %d\n" "$SKIP"
printf "\n"

if [[ "$FAIL" -gt 0 ]]; then
  printf "RESULT: FAIL — %d check(s) failed\n\n" "$FAIL"
  printf "See docs/operations/ECOMMERCE_WORKER_TROUBLESHOOTING.md for the decision\n"
  printf "tree: fix Oscar worker OR scale to 0 and rely on Purchase Gateway.\n\n"
  exit 1
else
  printf "RESULT: PASS\n\n"
  if [[ "$MODE" == "offline" ]]; then
    printf "Offline manifest checks passed. Run --online for live cluster checks.\n\n"
  fi
  exit 0
fi
