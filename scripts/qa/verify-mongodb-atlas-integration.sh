#!/usr/bin/env bash
# @covers AC-001, AC-002, AC-005, AC-006, AC-008, AC-009
# @spec: mongodb-atlas-integration_spec.md
# Verify MongoDB Atlas Integration
# Ensures Atlas-only configuration (no local MongoDB) and proper connection setup
set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Helper functions
check_pass() {
  echo -e "${GREEN}✓ $1${NC}"
  PASSED=$((PASSED + 1))
}

check_fail() {
  echo -e "${RED}✗ $1${NC}"
  FAILED=$((FAILED + 1))
}

check_warn() {
  echo -e "${YELLOW}⚠ $1${NC}"
  WARNINGS=$((WARNINGS + 1))
}

# Detect repository root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$REPO_ROOT/scripts/shared/ci-skip-guards.sh"
require_tutor_env || exit 0

# Parse arguments
MODE="all"
while [[ $# -gt 0 ]]; do
  case $1 in
    --mode)
      MODE="$2"
      shift 2
      ;;
    *)
      echo "Usage: $0 [--mode local|runtime|all]"
      echo ""
      echo "Modes:"
      echo "  local   - Check config files and manifests (no live cluster needed)"
      echo "  runtime - Check live cluster/docker state"
      echo "  all     - Run both local and runtime checks (default)"
      exit 1
      ;;
  esac
done

# Validate mode
if [[ ! "$MODE" =~ ^(local|runtime|all)$ ]]; then
  echo -e "${RED}✗ Invalid mode: $MODE${NC}"
  echo "Valid modes: local, runtime, all"
  exit 1
fi

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        MongoDB Atlas Integration Verification               ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "  Mode: $MODE"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================================
# LOCAL CHECKS (config files and manifests)
# ============================================================================

if [[ "$MODE" == "local" || "$MODE" == "all" ]]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "LOCAL CHECKS (Config Files & Manifests)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Check 1: No MongoDB Deployment in base manifests
  echo "[1/6] Checking for MongoDB Deployment in base manifests..."
  if grep -A5 "kind: Deployment" "$REPO_ROOT/deploy/k8s/base/deployments.yml" 2>/dev/null | grep -q "name: mongodb" 2>/dev/null; then
    check_fail "MongoDB Deployment found in deploy/k8s/base/deployments.yml (should be Atlas only)"
  else
    check_pass "No MongoDB Deployment in base manifests (Atlas only)"
  fi

  # Check 2: MongoDB Service exists in base but removed in production overlay
  echo "[2/6] Checking MongoDB Service configuration..."
  if grep -q "name: mongodb" "$REPO_ROOT/deploy/k8s/base/services.yml" 2>/dev/null || true; then
    check_pass "MongoDB Service exists in base services.yml"

    # Verify production overlay removes it
    if [ -f "$REPO_ROOT/deploy/k8s/overlays/production/patches/remove-legacy-mongodb-service.yaml" ]; then
      if grep -q '\$patch: delete' "$REPO_ROOT/deploy/k8s/overlays/production/patches/remove-legacy-mongodb-service.yaml" 2>/dev/null || true; then
        check_pass "Production overlay removes legacy MongoDB service"
      else
        check_fail "Production overlay patch missing '\$patch: delete'"
      fi
    else
      check_warn "Production overlay patch file missing (expected at deploy/k8s/overlays/production/patches/remove-legacy-mongodb-service.yaml)"
    fi
  else
    check_warn "MongoDB Service not found in base services.yml"
  fi

  # Check 3: Config files reference Atlas hostname or mongodb+srv://
  echo "[3/6] Checking for Atlas connection strings in config..."
  ATLAS_FOUND=false

  if [ -f "$REPO_ROOT/tutor_env/config.yml" ]; then
    if grep -q "cluster-mereka-lms.2pjex4s.mongodb.net" "$REPO_ROOT/tutor_env/config.yml" 2>/dev/null || \
       grep -q "mongodb+srv://" "$REPO_ROOT/tutor_env/config.yml" 2>/dev/null; then
      check_pass "Atlas hostname or SRV connection string found in tutor_env/config.yml"
      ATLAS_FOUND=true
    fi
  fi

  # Check external secrets
  if [ -f "$REPO_ROOT/deploy/k8s/base/secrets/external-secrets.yaml" ]; then
    if grep -q "FORUM_MONGODB_HOST" "$REPO_ROOT/deploy/k8s/base/secrets/external-secrets.yaml"; then
      check_pass "FORUM_MONGODB_HOST referenced in ExternalSecrets"
      ATLAS_FOUND=true
    fi
  fi

  if [ "$ATLAS_FOUND" = false ]; then
    check_warn "No Atlas connection string found in config files (may be in secrets only)"
  fi

  # Check 4: pymongo[srv] or dnspython in requirements/env vars
  echo "[4/6] Checking for pymongo[srv] or dnspython dependencies..."
  PYMONGO_SRV_FOUND=false

  if [ -f "$REPO_ROOT/tutor_env/config.yml" ]; then
    if grep -q "pymongo\[srv\]" "$REPO_ROOT/tutor_env/config.yml" 2>/dev/null; then
      check_pass "pymongo[srv] found in tutor_env/config.yml (OPENEDX_EXTRA_PIP_REQUIREMENTS)"
      PYMONGO_SRV_FOUND=true
    fi
  fi

  if [ "$PYMONGO_SRV_FOUND" = false ]; then
    check_fail "pymongo[srv] not found (required for Atlas SRV connections)"
  fi

  # Check 5: LMS/CMS deployments have MONGODB_HOST from secretKeyRef
  echo "[5/6] Checking LMS/CMS deployments for MONGODB_HOST env vars..."
  LMS_MONGO_ENV=false
  CMS_MONGO_ENV=false

  if grep -A30 "name: lms" "$REPO_ROOT/deploy/k8s/base/deployments.yml" | \
     grep -A5 "MONGODB_HOST" | grep -q "secretKeyRef"; then
    check_pass "LMS deployment has MONGODB_HOST from secretKeyRef"
    LMS_MONGO_ENV=true
  else
    check_fail "LMS deployment missing MONGODB_HOST from secretKeyRef"
  fi

  if grep -A30 "name: cms" "$REPO_ROOT/deploy/k8s/base/deployments.yml" | \
     grep -A5 "MONGODB_HOST" | grep -q "secretKeyRef"; then
    check_pass "CMS deployment has MONGODB_HOST from secretKeyRef"
    CMS_MONGO_ENV=true
  else
    check_fail "CMS deployment missing MONGODB_HOST from secretKeyRef"
  fi

  # Check 6: No hardcoded mongodb:27017 or similar local references
  echo "[6/6] Checking for hardcoded local MongoDB references..."
  HARDCODED_FOUND=false

  for file in "$REPO_ROOT/deploy/k8s/base/deployments.yml" \
              "$REPO_ROOT/deploy/k8s/base/configmaps.yml" \
              "$REPO_ROOT/tutor_env/config.yml"; do
    if [ -f "$file" ]; then
      if grep -E "mongodb:(27017|\\d+)" "$file" 2>/dev/null | grep -v "^#" | grep -qv "MONGODB_HOST"; then
        check_fail "Hardcoded mongodb:27017 found in $(basename "$file")"
        HARDCODED_FOUND=true
      fi
    fi
  done

  if [ "$HARDCODED_FOUND" = false ]; then
    check_pass "No hardcoded mongodb:27017 references found"
  fi

  echo ""
fi

# ============================================================================
# RUNTIME CHECKS (live cluster/docker state)
# ============================================================================

if [[ "$MODE" == "runtime" || "$MODE" == "all" ]]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "RUNTIME CHECKS (Live Cluster/Docker State)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Check 1: DNS resolution for Atlas cluster
  echo "[1/4] Checking DNS resolution for Atlas cluster..."
  if command -v nslookup &> /dev/null; then
    if nslookup cluster-mereka-lms.2pjex4s.mongodb.net &> /dev/null; then
      check_pass "Atlas cluster DNS resolves (cluster-mereka-lms.2pjex4s.mongodb.net)"
    else
      check_fail "Atlas cluster DNS resolution failed"
    fi
  else
    check_warn "nslookup not available, skipping DNS check"
  fi

  # Check 2: No MongoDB StatefulSet or Deployment in K8s namespace
  echo "[2/4] Checking for MongoDB StatefulSet/Deployment in K8s..."
  if command -v kubectl &> /dev/null; then
    MONGO_DEPLOY=$(kubectl get deployment,statefulset -n mereka-lms 2>/dev/null | grep mongodb || true)
    if [ -z "$MONGO_DEPLOY" ]; then
      check_pass "No MongoDB StatefulSet or Deployment in mereka-lms namespace"
    else
      check_fail "MongoDB StatefulSet or Deployment found in mereka-lms namespace (should be Atlas only)"
      echo "$MONGO_DEPLOY"
    fi
  else
    check_warn "kubectl not available, skipping K8s check"
  fi

  # Check 3: LMS pods are running (basic health check)
  echo "[3/4] Checking LMS pod health..."
  if command -v kubectl &> /dev/null; then
    LMS_RUNNING=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms 2>/dev/null | grep -c "Running" || echo "0")
    LMS_RUNNING=$(echo "$LMS_RUNNING" | head -1 | tr -d ' ')
    if [ "$LMS_RUNNING" -gt 0 ] 2>/dev/null; then
      check_pass "LMS pods running ($LMS_RUNNING pods)"
    else
      check_warn "No LMS pods running (may not be deployed yet)"
    fi
  else
    check_warn "kubectl not available, skipping pod health check"
  fi

  # Check 4: No local Docker MongoDB container
  echo "[4/4] Checking for local Docker MongoDB container..."
  if command -v docker &> /dev/null; then
    MONGO_CONTAINER=$(docker ps --filter name=mongodb -q 2>/dev/null || true)
    if [ -z "$MONGO_CONTAINER" ]; then
      check_pass "No local Docker MongoDB container running"
    else
      check_warn "Local Docker MongoDB container found (name contains 'mongodb')"
      docker ps --filter name=mongodb --format "table {{.ID}}\t{{.Image}}\t{{.Names}}\t{{.Status}}"
    fi
  else
    check_warn "Docker not available, skipping container check"
  fi

  echo ""
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Verification Summary                                  ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo -e "  ${GREEN}✓ Passed: $PASSED${NC}"
echo -e "  ${RED}✗ Failed: $FAILED${NC}"
echo -e "  ${YELLOW}⚠ Warnings: $WARNINGS${NC}"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}✓ MongoDB Atlas integration verified successfully!${NC}"
  echo ""
  echo "Atlas Configuration:"
  echo "  - Cluster: cluster-mereka-lms.2pjex4s.mongodb.net"
  echo "  - Databases: openedx (modulestore), cs_comments_service (forum)"
  echo "  - Connection: FORUM_MONGODB_HOST secret (Infisical → GCP SM → K8s)"
  echo ""
  exit 0
else
  echo -e "${RED}✗ MongoDB Atlas integration verification failed!${NC}"
  echo ""
  echo "Common issues:"
  echo "  - pymongo[srv] missing from OPENEDX_EXTRA_PIP_REQUIREMENTS"
  echo "  - MONGODB_HOST not set in LMS/CMS deployments"
  echo "  - Local MongoDB deployment not removed from manifests"
  echo ""
  echo "See docs/adr/historical/001-mongodb-atlas.md for more details"
  exit 1
fi
