#!/usr/bin/env bash
# @covers AC-024, AC-025, AC-026, AC-027, AC-029, AC-031, AC-033
# @spec: ecommerce-purchase-gateway_spec.md
# Purchase Gateway K8s deployment verification
# Offline mode: static manifest checks (no cluster required)
# Online mode:  live cluster health, pods, endpoints, secrets, HPA
# Usage:
#   ./verify-purchase-gateway-k8s.sh            # offline only
#   ./verify-purchase-gateway-k8s.sh --online   # offline + live cluster checks
#   ./verify-purchase-gateway-k8s.sh --help

set -euo pipefail

# ---------------------------------------------------------------------------
# Counters and helpers
# ---------------------------------------------------------------------------
PASS=0
FAIL=0
SKIP=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}  PASS${NC}: $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}  FAIL${NC}: $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}  SKIP${NC}: $1"; SKIP=$((SKIP + 1)); }
info() { echo "  INFO: $1"; }

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
K8S_DIR="$REPO_ROOT/services/purchase-gateway/k8s"
BASE_KUSTOMIZATION="$REPO_ROOT/deploy/k8s/base/kustomization.yaml"
NAMESPACE="mereka-lms"
DEPLOYMENT_NAME="payments-gateway"
PG_DEPLOYMENT_NAME="postgresql-payments"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
ONLINE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --online)  ONLINE=true; shift ;;
    --help)
      cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Verify Purchase Gateway K8s deployment.

OPTIONS:
  --online   Enable live cluster checks (requires kubectl + kubeconfig)
  --help     Show this message

OFFLINE CHECKS (always run):
  - YAML validity for all manifests
  - Deployment spec: name, probes, ports, securityContext, secrets, resources
  - Service: ClusterIP type, port 8080
  - ExternalSecret: all 7 GCP secret mappings present
  - HPA: target + CPU utilisation configured
  - PostgreSQL: Recreate strategy, 5Gi PVC, readiness probe
  - kustomization.yaml references purchase-gateway path
  - base kustomization includes services/purchase-gateway/k8s

ONLINE CHECKS (--online only):
  - pods Running, no CrashLoopBackOff / ImagePullBackOff
  - service endpoints populated
  - HPA status (min/max replicas)
  - ExternalSecret sync status (Ready)
  - payments-gateway-secrets K8s secret exists with expected keys
  - /health/ returns HTTP 200 (probe via kubectl exec)
  - /ready/ returns HTTP 200 (probe via kubectl exec)
  - PostgreSQL pod running, no restart loops
  - ENABLE_GATEWAY_FULFILLMENT=false (dark launch guard)
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Offline: YAML validity
# ---------------------------------------------------------------------------
echo ""
echo "======================================================="
echo "  Purchase Gateway K8s Verification"
echo "  Repo: $REPO_ROOT"
echo "  Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
if [[ "$ONLINE" == "true" ]]; then
  echo "  Mode: offline + online (live cluster)"
else
  echo "  Mode: offline only"
fi
echo "======================================================="

echo ""
echo "[1/9] YAML validity"

check_yaml() {
  local file="$1"
  local label="$2"
  if [[ ! -f "$file" ]]; then
    fail "$label not found: $file"
    return
  fi
  if python3 -c "import yaml; list(yaml.safe_load_all(open('$file')))" 2>/dev/null; then
    pass "$label is valid YAML"
  else
    fail "$label is invalid YAML"
  fi
}

check_yaml "$K8S_DIR/deployment.yaml"            "deployment.yaml"
check_yaml "$K8S_DIR/service.yaml"               "service.yaml"
check_yaml "$K8S_DIR/hpa.yaml"                   "hpa.yaml"
check_yaml "$K8S_DIR/external-secrets.yaml"      "external-secrets.yaml"
check_yaml "$K8S_DIR/postgresql-deployment.yaml" "postgresql-deployment.yaml"
check_yaml "$K8S_DIR/postgresql-service.yaml"    "postgresql-service.yaml"
check_yaml "$K8S_DIR/postgresql-pvc.yaml"        "postgresql-pvc.yaml"
check_yaml "$K8S_DIR/kustomization.yaml"         "kustomization.yaml"

# ---------------------------------------------------------------------------
# Offline: Deployment manifest
# ---------------------------------------------------------------------------
echo ""
echo "[2/9] Deployment manifest"

DEPLOYMENT="$K8S_DIR/deployment.yaml"

check_contains() {
  local file="$1" pattern="$2" label="$3"
  if [[ ! -f "$file" ]]; then
    fail "$label (file missing: $file)"
    return
  fi
  if grep -q "$pattern" "$file" 2>/dev/null; then
    pass "$label"
  else
    fail "$label"
  fi
}

check_contains "$DEPLOYMENT" "name: $DEPLOYMENT_NAME"            "Deployment named $DEPLOYMENT_NAME"
check_contains "$DEPLOYMENT" "containerPort: 8080"               "Container port 8080"
check_contains "$DEPLOYMENT" "readinessProbe"                    "readinessProbe configured"
check_contains "$DEPLOYMENT" "livenessProbe"                     "livenessProbe configured"
check_contains "$DEPLOYMENT" "/ready/"                           "readinessProbe uses /ready/"
check_contains "$DEPLOYMENT" "/health/"                          "livenessProbe uses /health/"
check_contains "$DEPLOYMENT" "runAsUser: 1000"                   "Pod securityContext runAsUser: 1000"
check_contains "$DEPLOYMENT" "runAsGroup: 1000"                  "Pod securityContext runAsGroup: 1000"
check_contains "$DEPLOYMENT" "allowPrivilegeEscalation: false"   "allowPrivilegeEscalation: false"
check_contains "$DEPLOYMENT" "secretKeyRef"                      "Secrets injected via secretKeyRef"
check_contains "$DEPLOYMENT" "payments-gateway-secrets"          "References payments-gateway-secrets secret"
check_contains "$DEPLOYMENT" "ADMIN_API_KEY"                     "ADMIN_API_KEY env var present"
check_contains "$DEPLOYMENT" "ENABLE_GATEWAY_FULFILLMENT"        "ENABLE_GATEWAY_FULFILLMENT env var present"
check_contains "$DEPLOYMENT" "TENANT_ISOLATION_ENABLED"          "TENANT_ISOLATION_ENABLED env var present"
check_contains "$DEPLOYMENT" 'command: \["python".*"alembic"'   "Alembic migration init container present" || \
  check_contains "$DEPLOYMENT" '"alembic"'                       "Alembic referenced in init container"
check_contains "$DEPLOYMENT" "requests:"                         "Resource requests set"
check_contains "$DEPLOYMENT" "limits:"                           "Resource limits set"

# ---------------------------------------------------------------------------
# Offline: Service manifest
# ---------------------------------------------------------------------------
echo ""
echo "[3/9] Service manifest"

SERVICE="$K8S_DIR/service.yaml"

check_contains "$SERVICE" "ClusterIP"                 "Service type is ClusterIP"
check_contains "$SERVICE" "port: 8080"                "Service port 8080"
check_contains "$SERVICE" "app.kubernetes.io/name: $DEPLOYMENT_NAME" "Service selector targets $DEPLOYMENT_NAME"

# ---------------------------------------------------------------------------
# Offline: ExternalSecret (7 GCP SM keys)
# ---------------------------------------------------------------------------
echo ""
echo "[4/9] ExternalSecret — 7 GCP Secret Manager references"

ES="$K8S_DIR/external-secrets.yaml"

check_contains "$ES" "MEREKA_LMS_PAYMENTS_GATEWAY_SECRET_KEY"          "GCP key: GATEWAY_SECRET_KEY"
check_contains "$ES" "MEREKA_LMS_PAYMENTS_GATEWAY_DATABASE_URL"        "GCP key: DATABASE_URL"
check_contains "$ES" "MEREKA_LMS_STRIPE_SECRET_KEY"                    "GCP key: STRIPE_SECRET_KEY"
check_contains "$ES" "MEREKA_LMS_STRIPE_WEBHOOK_SECRET_GATEWAY"        "GCP key: STRIPE_WEBHOOK_SECRET_GATEWAY"
check_contains "$ES" "MEREKA_LMS_PAYMENTS_GATEWAY_OAUTH2_SECRET"       "GCP key: OAUTH2_SECRET"
check_contains "$ES" "MEREKA_LMS_ADMIN_API_KEY"                        "GCP key: ADMIN_API_KEY"
check_contains "$ES" "MEREKA_LMS_PAYMENTS_GATEWAY_POSTGRESQL_PASSWORD" "GCP key: POSTGRESQL_PASSWORD"
check_contains "$ES" "gcp-secret-manager"                              "Uses gcp-secret-manager ClusterSecretStore"
check_contains "$ES" "refreshInterval: 1h"                             "refreshInterval: 1h"
check_contains "$ES" "creationPolicy: Owner"                           "creationPolicy: Owner"

# ---------------------------------------------------------------------------
# Offline: HPA
# ---------------------------------------------------------------------------
echo ""
echo "[5/9] HorizontalPodAutoscaler"

HPA="$K8S_DIR/hpa.yaml"

check_contains "$HPA" "kind: HorizontalPodAutoscaler"         "Kind is HorizontalPodAutoscaler"
check_contains "$HPA" "name: $DEPLOYMENT_NAME"                "HPA targets $DEPLOYMENT_NAME"
check_contains "$HPA" "averageUtilization: 70"                "CPU target: 70%"
check_contains "$HPA" "maxReplicas:"                          "maxReplicas configured"

# Verify min ≥ 1 and max ≥ 2 (spec: 1-10 replica range)
if [[ -f "$HPA" ]]; then
  MIN_REPLICAS=$(grep "minReplicas:" "$HPA" | awk '{print $2}' | head -1)
  MAX_REPLICAS=$(grep "maxReplicas:" "$HPA" | awk '{print $2}' | head -1)
  if [[ -n "$MIN_REPLICAS" ]] && [[ "$MIN_REPLICAS" -ge 1 ]]; then
    pass "minReplicas >= 1 (actual: $MIN_REPLICAS)"
  else
    fail "minReplicas < 1 or not found (actual: ${MIN_REPLICAS:-unset})"
  fi
  if [[ -n "$MAX_REPLICAS" ]] && [[ "$MAX_REPLICAS" -ge 2 ]]; then
    pass "maxReplicas >= 2 (actual: $MAX_REPLICAS)"
  else
    fail "maxReplicas < 2 (actual: ${MAX_REPLICAS:-unset})"
  fi
fi

# ---------------------------------------------------------------------------
# Offline: PostgreSQL manifests
# ---------------------------------------------------------------------------
echo ""
echo "[6/9] PostgreSQL manifests"

PG_DEPLOY="$K8S_DIR/postgresql-deployment.yaml"
PG_PVC="$K8S_DIR/postgresql-pvc.yaml"
PG_SVC="$K8S_DIR/postgresql-service.yaml"

check_contains "$PG_DEPLOY" "name: $PG_DEPLOYMENT_NAME"          "PostgreSQL Deployment named $PG_DEPLOYMENT_NAME"
check_contains "$PG_DEPLOY" "postgres:16"                        "PostgreSQL 16 image"
check_contains "$PG_DEPLOY" "type: Recreate"                     "PostgreSQL strategy: Recreate"
check_contains "$PG_DEPLOY" "runAsUser: 999"                     "PostgreSQL runAsUser: 999 (postgres uid)"
check_contains "$PG_DEPLOY" "POSTGRESQL_PASSWORD"                "PostgreSQL password from secret"
check_contains "$PG_DEPLOY" "pg_isready"                         "PostgreSQL readiness probe via pg_isready"
check_contains "$PG_DEPLOY" "payments_gateway"                   "Database name: payments_gateway"
check_contains "$PG_PVC"    "storage: 5Gi"                       "PVC size: 5Gi"
check_contains "$PG_PVC"    "ReadWriteOnce"                      "PVC accessMode: ReadWriteOnce"
check_contains "$PG_SVC"    "port: 5432"                         "PostgreSQL service port: 5432"

# ---------------------------------------------------------------------------
# Offline: Kustomize wiring
# ---------------------------------------------------------------------------
echo ""
echo "[7/9] Kustomize wiring"

PGW_KUSTOMIZATION="$K8S_DIR/kustomization.yaml"

check_contains "$PGW_KUSTOMIZATION" "deployment.yaml"            "kustomization.yaml includes deployment.yaml"
check_contains "$PGW_KUSTOMIZATION" "service.yaml"               "kustomization.yaml includes service.yaml"
check_contains "$PGW_KUSTOMIZATION" "hpa.yaml"                   "kustomization.yaml includes hpa.yaml"
check_contains "$PGW_KUSTOMIZATION" "external-secrets.yaml"      "kustomization.yaml includes external-secrets.yaml"
check_contains "$PGW_KUSTOMIZATION" "postgresql-deployment.yaml" "kustomization.yaml includes postgresql-deployment.yaml"
check_contains "$PGW_KUSTOMIZATION" "postgresql-pvc.yaml"        "kustomization.yaml includes postgresql-pvc.yaml"
check_contains "$PGW_KUSTOMIZATION" "postgresql-service.yaml"    "kustomization.yaml includes postgresql-service.yaml"

if [[ -f "$BASE_KUSTOMIZATION" ]]; then
  if grep -q "apps/purchase-gateway" "$BASE_KUSTOMIZATION"; then
    pass "deploy/k8s/base/kustomization.yaml references apps/purchase-gateway"
  elif grep -q "services/purchase-gateway/k8s" "$BASE_KUSTOMIZATION"; then
    pass "deploy/k8s/base/kustomization.yaml references services/purchase-gateway/k8s (legacy layout)"
  else
    fail "deploy/k8s/base/kustomization.yaml does not reference purchase-gateway path"
  fi
else
  skip "Base kustomization not found: $BASE_KUSTOMIZATION"
fi

# ---------------------------------------------------------------------------
# Online: live cluster checks
# ---------------------------------------------------------------------------
if [[ "$ONLINE" == "false" ]]; then
  echo ""
  echo "[8/9] Live cluster checks — SKIPPED (pass --online to enable)"
  SKIP=$((SKIP + 1))
  echo ""
  echo "[9/9] Health endpoints — SKIPPED (pass --online to enable)"
  SKIP=$((SKIP + 1))
else
  # Verify kubectl is available
  if ! command -v kubectl &>/dev/null; then
    echo ""
    echo "[8/9] Live cluster checks — SKIPPED (kubectl not found)"
    SKIP=$((SKIP + 1))
    echo ""
    echo "[9/9] Health endpoints — SKIPPED (kubectl not found)"
    SKIP=$((SKIP + 1))
  else
    echo ""
    echo "[8/9] Live cluster checks"

    # Deployment health
    if kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" &>/dev/null; then
      READY=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
      DESIRED=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" \
        -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
      if [[ "${READY:-0}" -ge 1 ]]; then
        pass "$DEPLOYMENT_NAME: ${READY}/${DESIRED} pods ready"
      else
        fail "$DEPLOYMENT_NAME: ${READY:-0}/${DESIRED} pods ready (expected >= 1)"
      fi
    else
      fail "$DEPLOYMENT_NAME Deployment not found in namespace $NAMESPACE"
    fi

    # PostgreSQL health
    if kubectl get deployment "$PG_DEPLOYMENT_NAME" -n "$NAMESPACE" &>/dev/null; then
      PG_READY=$(kubectl get deployment "$PG_DEPLOYMENT_NAME" -n "$NAMESPACE" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
      if [[ "${PG_READY:-0}" -ge 1 ]]; then
        pass "$PG_DEPLOYMENT_NAME: ${PG_READY}/1 pods ready"
      else
        fail "$PG_DEPLOYMENT_NAME: not ready (readyReplicas=${PG_READY:-0})"
      fi
    else
      fail "$PG_DEPLOYMENT_NAME Deployment not found in namespace $NAMESPACE"
    fi

    # Check for crash/image pull failures
    WAITING_REASONS=$(kubectl get pods -n "$NAMESPACE" \
      -l "app.kubernetes.io/name=$DEPLOYMENT_NAME" \
      --field-selector=status.phase!=Succeeded \
      -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}' 2>/dev/null || true)
    CRASH_LOOPS=$(tr ' ' '\n' <<<"${WAITING_REASONS:-}" | awk '$0=="CrashLoopBackOff"{n++} END{print n+0}')
    IMAGE_ERRORS=$(tr ' ' '\n' <<<"${WAITING_REASONS:-}" | awk '$0=="ImagePullBackOff"{n++} END{print n+0}')
    if [[ "$CRASH_LOOPS" -eq 0 ]]; then
      pass "No CrashLoopBackOff for payments-gateway pods"
    else
      fail "$CRASH_LOOPS pod(s) in CrashLoopBackOff"
    fi
    if [[ "$IMAGE_ERRORS" -eq 0 ]]; then
      pass "No ImagePullBackOff for payments-gateway pods"
    else
      fail "$IMAGE_ERRORS pod(s) in ImagePullBackOff"
    fi

    # Excessive restart check
    RESTART_COUNT=$(kubectl get pods -n "$NAMESPACE" \
      -l "app.kubernetes.io/name=$DEPLOYMENT_NAME" \
      -o jsonpath='{.items[*].status.containerStatuses[*].restartCount}' 2>/dev/null | \
      tr ' ' '\n' | awk '$1>5{print}' | wc -l || echo "0")
    if [[ "${RESTART_COUNT:-0}" -eq 0 ]]; then
      pass "No payments-gateway pods with >5 restarts"
    else
      fail "${RESTART_COUNT} pod(s) with >5 restarts (possible crash loop)"
    fi

    # Service endpoints
    if kubectl get service "$DEPLOYMENT_NAME" -n "$NAMESPACE" &>/dev/null; then
      ENDPOINT_COUNT=$(kubectl get endpoints "$DEPLOYMENT_NAME" -n "$NAMESPACE" \
        -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w || echo "0")
      if [[ "${ENDPOINT_COUNT:-0}" -gt 0 ]]; then
        pass "$DEPLOYMENT_NAME service has ${ENDPOINT_COUNT} endpoint(s)"
      else
        fail "$DEPLOYMENT_NAME service has no endpoints (pod selector mismatch?)"
      fi
    else
      fail "$DEPLOYMENT_NAME Service not found in namespace $NAMESPACE"
    fi

    # HPA status
    if kubectl get hpa "$DEPLOYMENT_NAME" -n "$NAMESPACE" &>/dev/null; then
      HPA_MIN=$(kubectl get hpa "$DEPLOYMENT_NAME" -n "$NAMESPACE" \
        -o jsonpath='{.spec.minReplicas}' 2>/dev/null || echo "?")
      HPA_MAX=$(kubectl get hpa "$DEPLOYMENT_NAME" -n "$NAMESPACE" \
        -o jsonpath='{.spec.maxReplicas}' 2>/dev/null || echo "?")
      pass "HPA exists: minReplicas=${HPA_MIN}, maxReplicas=${HPA_MAX}"
    else
      fail "HPA $DEPLOYMENT_NAME not found in namespace $NAMESPACE"
    fi

    # ExternalSecret sync status
    if kubectl get externalsecret "payments-gateway-secrets" -n "$NAMESPACE" &>/dev/null; then
      ES_STATUS=$(kubectl get externalsecret "payments-gateway-secrets" -n "$NAMESPACE" \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
      if [[ "$ES_STATUS" == "True" ]]; then
        pass "ExternalSecret payments-gateway-secrets: Ready=True"
      else
        fail "ExternalSecret payments-gateway-secrets: Ready=${ES_STATUS} (expected True)"
      fi
    else
      fail "ExternalSecret payments-gateway-secrets not found in namespace $NAMESPACE"
    fi

    # K8s Secret keys
    if kubectl get secret "payments-gateway-secrets" -n "$NAMESPACE" &>/dev/null; then
      SECRET_KEYS=$(kubectl get secret "payments-gateway-secrets" -n "$NAMESPACE" \
        -o jsonpath='{.data}' 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d))" 2>/dev/null || echo "0")
      if [[ "${SECRET_KEYS:-0}" -ge 7 ]]; then
        pass "payments-gateway-secrets: ${SECRET_KEYS} keys synced (expected >= 7)"
      else
        fail "payments-gateway-secrets: only ${SECRET_KEYS:-0} keys (expected >= 7)"
      fi
      ADMIN_API_KEY_VALUE=$(kubectl get secret "payments-gateway-secrets" -n "$NAMESPACE" \
        -o jsonpath='{.data.ADMIN_API_KEY}' 2>/dev/null || echo "")
      if [[ -n "$ADMIN_API_KEY_VALUE" ]]; then
        pass "payments-gateway-secrets includes ADMIN_API_KEY key"
      else
        fail "payments-gateway-secrets missing ADMIN_API_KEY key"
      fi
    else
      fail "K8s Secret payments-gateway-secrets not found (ExternalSecret not synced?)"
    fi

    # Dark launch guard: ENABLE_GATEWAY_FULFILLMENT must be false
    GW_POD=$(kubectl get pods -n "$NAMESPACE" \
      -l "app.kubernetes.io/name=$DEPLOYMENT_NAME" \
      --field-selector=status.phase=Running \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$GW_POD" ]]; then
      FULFILLMENT_FLAG=$(kubectl exec -n "$NAMESPACE" "$GW_POD" -- \
        env 2>/dev/null | grep "ENABLE_GATEWAY_FULFILLMENT" | cut -d= -f2 || echo "")
      if [[ "$FULFILLMENT_FLAG" == "false" ]]; then
        pass "ENABLE_GATEWAY_FULFILLMENT=false (dark launch mode confirmed)"
      else
        fail "ENABLE_GATEWAY_FULFILLMENT=${FULFILLMENT_FLAG:-unset} (expected false — not ready for live traffic)"
      fi
    else
      skip "No running payments-gateway pod found, skipping fulfillment flag check"
    fi

    # Health endpoint checks
    echo ""
    echo "[9/9] Health endpoints"

    if [[ -n "$GW_POD" ]]; then
      HEALTH_CHECK="import urllib.request,sys; r=urllib.request.urlopen('http://127.0.0.1:8080/health/',timeout=5); print(r.status)"
      HTTP_CODE=$(kubectl exec -n "$NAMESPACE" "$GW_POD" -- \
        python3 -c "$HEALTH_CHECK" 2>/dev/null || echo "000")
      if [[ "$HTTP_CODE" == "200" ]]; then
        pass "/health/ returns HTTP 200"
      else
        fail "/health/ returns HTTP ${HTTP_CODE} (expected 200)"
      fi

      READY_CHECK="import urllib.request,sys; r=urllib.request.urlopen('http://127.0.0.1:8080/ready/',timeout=5); print(r.status)"
      READY_CODE=$(kubectl exec -n "$NAMESPACE" "$GW_POD" -- \
        python3 -c "$READY_CHECK" 2>/dev/null || echo "000")
      if [[ "$READY_CODE" == "200" ]]; then
        pass "/ready/ returns HTTP 200"
      else
        fail "/ready/ returns HTTP ${READY_CODE} (expected 200)"
      fi
    else
      skip "No running pod found — skipping /health/ and /ready/ checks"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "======================================================="
echo -e "  ${GREEN}PASS: $PASS${NC}  |  ${RED}FAIL: $FAIL${NC}  |  ${YELLOW}SKIP: $SKIP${NC}"
echo "======================================================="

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "Troubleshooting:"
  echo "  kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=$DEPLOYMENT_NAME"
  echo "  kubectl describe deployment $DEPLOYMENT_NAME -n $NAMESPACE"
  echo "  kubectl logs -n $NAMESPACE deploy/$DEPLOYMENT_NAME --tail=50"
  echo "  kubectl get externalsecret payments-gateway-secrets -n $NAMESPACE -o yaml"
  echo "  See docs/runbooks/operations/PURCHASE_GATEWAY_K8S.md"
  echo ""
  exit 1
fi

exit 0
