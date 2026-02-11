#!/usr/bin/env bash
# @covers AC-026, AC-027
# @spec: ecommerce-purchase-gateway_spec.md
set -euo pipefail

# Verify Purchase Gateway K8s manifests are syntactically valid YAML
# and contain required fields.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
K8S_DIR="$REPO_ROOT/services/purchase-gateway/k8s"

PASS=0
FAIL=0

check_yaml() {
  local file="$1"
  local desc="$2"
  if python3 -c "import yaml; yaml.safe_load_all(open('$file'))" 2>/dev/null; then
    echo "  PASS: $desc is valid YAML"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc is invalid YAML"
    FAIL=$((FAIL + 1))
  fi
}

check_contains() {
  local file="$1"
  local pattern="$2"
  local desc="$3"
  if grep -q "$pattern" "$file" 2>/dev/null; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Purchase Gateway K8s Manifest Verification ==="
echo ""

echo "-- YAML validity --"
check_yaml "$K8S_DIR/deployment.yaml" "deployment.yaml"
check_yaml "$K8S_DIR/service.yaml" "service.yaml"
check_yaml "$K8S_DIR/external-secrets.yaml" "external-secrets.yaml"
check_yaml "$K8S_DIR/hpa.yaml" "hpa.yaml"

echo ""
echo "-- Deployment checks --"
check_contains "$K8S_DIR/deployment.yaml" 'payments-gateway' "Deployment named payments-gateway"
check_contains "$K8S_DIR/deployment.yaml" 'readinessProbe' "Deployment has readiness probe"
check_contains "$K8S_DIR/deployment.yaml" 'livenessProbe' "Deployment has liveness probe"
check_contains "$K8S_DIR/deployment.yaml" '/health/' "Liveness probe uses /health/"
check_contains "$K8S_DIR/deployment.yaml" '/ready/' "Readiness probe uses /ready/"
check_contains "$K8S_DIR/deployment.yaml" 'containerPort: 8080' "Container port is 8080"
check_contains "$K8S_DIR/deployment.yaml" 'secretKeyRef' "Deployment uses secretKeyRef for secrets"

echo ""
echo "-- Service checks --"
check_contains "$K8S_DIR/service.yaml" 'ClusterIP' "Service type is ClusterIP"
check_contains "$K8S_DIR/service.yaml" 'port: 8080' "Service port is 8080"

echo ""
echo "-- ExternalSecrets checks --"
check_contains "$K8S_DIR/external-secrets.yaml" 'MEREKA_LMS_STRIPE_SECRET_KEY' "References Stripe secret key"
check_contains "$K8S_DIR/external-secrets.yaml" 'MEREKA_LMS_STRIPE_WEBHOOK_SECRET_GATEWAY' "References gateway webhook secret"
check_contains "$K8S_DIR/external-secrets.yaml" 'MEREKA_LMS_PAYMENTS_GATEWAY_OAUTH2_SECRET' "References OAuth2 secret"
check_contains "$K8S_DIR/external-secrets.yaml" 'MEREKA_LMS_PAYMENTS_GATEWAY_DATABASE_URL' "References database URL"

echo ""
echo "-- HPA checks --"
check_contains "$K8S_DIR/hpa.yaml" 'minReplicas: 2' "HPA min replicas is 2"
check_contains "$K8S_DIR/hpa.yaml" 'maxReplicas: 10' "HPA max replicas is 10"
check_contains "$K8S_DIR/hpa.yaml" 'averageUtilization: 70' "HPA target CPU is 70%"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && echo "PASS" || { echo "FAIL"; exit 1; }
