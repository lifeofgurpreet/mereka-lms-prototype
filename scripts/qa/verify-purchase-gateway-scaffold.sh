#!/usr/bin/env bash
set -euo pipefail

# Verify Purchase Gateway scaffold — directory structure, required files.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SVC_DIR="$REPO_ROOT/services/purchase-gateway"

PASS=0
FAIL=0

check_file() {
  local path="$1"
  if [[ -f "$path" ]]; then
    echo "  PASS: $path"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $path missing"
    FAIL=$((FAIL + 1))
  fi
}

check_dir() {
  local path="$1"
  if [[ -d "$path" ]]; then
    echo "  PASS: $path/"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $path/ missing"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Purchase Gateway Scaffold Verification ==="
echo ""

echo "-- Core files --"
check_file "$SVC_DIR/pyproject.toml"
check_file "$SVC_DIR/Dockerfile"
check_file "$SVC_DIR/docker-compose.yml"
check_file "$SVC_DIR/alembic.ini"

echo ""
echo "-- Application modules --"
check_file "$SVC_DIR/app/__init__.py"
check_file "$SVC_DIR/app/main.py"
check_file "$SVC_DIR/app/config.py"
check_file "$SVC_DIR/app/database.py"

echo ""
echo "-- Models --"
check_file "$SVC_DIR/app/models/__init__.py"
check_file "$SVC_DIR/app/models/base.py"
check_file "$SVC_DIR/app/models/order.py"
check_file "$SVC_DIR/app/models/entitlement.py"
check_file "$SVC_DIR/app/models/stripe_event.py"

echo ""
echo "-- Routers --"
check_file "$SVC_DIR/app/routers/__init__.py"
check_file "$SVC_DIR/app/routers/health.py"
check_file "$SVC_DIR/app/routers/checkout.py"
check_file "$SVC_DIR/app/routers/webhooks.py"

echo ""
echo "-- Services --"
check_file "$SVC_DIR/app/services/__init__.py"
check_file "$SVC_DIR/app/services/stripe_service.py"
check_file "$SVC_DIR/app/services/fulfillment.py"
check_file "$SVC_DIR/app/services/lms_client.py"

echo ""
echo "-- Middleware --"
check_file "$SVC_DIR/app/middleware/__init__.py"
check_file "$SVC_DIR/app/middleware/tenant.py"

echo ""
echo "-- Alembic --"
check_file "$SVC_DIR/alembic/env.py"
check_dir "$SVC_DIR/alembic/versions"
check_file "$SVC_DIR/alembic/versions/001_initial_schema.py"

echo ""
echo "-- Tests --"
check_file "$SVC_DIR/tests/__init__.py"
check_file "$SVC_DIR/tests/conftest.py"
check_dir "$SVC_DIR/tests/unit"
check_dir "$SVC_DIR/tests/integration"

echo ""
echo "-- K8s manifests --"
check_file "$SVC_DIR/k8s/deployment.yaml"
check_file "$SVC_DIR/k8s/service.yaml"
check_file "$SVC_DIR/k8s/external-secrets.yaml"
check_file "$SVC_DIR/k8s/hpa.yaml"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && echo "PASS" || { echo "FAIL"; exit 1; }
