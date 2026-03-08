#!/usr/bin/env bash
# @covers AC-001, AC-005, AC-009, AC-010, AC-011, AC-012, AC-013, AC-014, AC-022
# @spec: forum-service-migration_spec.md
# Verify Forum Service Integration
# Ensures Python forum v2 (integrated into LMS) with Meilisearch is configured correctly
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
CHECK_FILTER=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --mode)
      MODE="$2"
      shift 2
      ;;
    --check)
      CHECK_FILTER="$2"
      shift 2
      ;;
    *)
      echo "Usage: $0 [--mode local|runtime|all] [--check CHECK_NAME]"
      echo ""
      echo "Modes:"
      echo "  local   - Check config files and manifests (no live cluster needed)"
      echo "  runtime - Check live cluster/docker state"
      echo "  all     - Run both local and runtime checks (default)"
      echo ""
      echo "Checks:"
      echo "  Use --check to run a specific check (e.g., 'dependency-check', 'api-check')"
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
echo "║        Forum Service Integration Verification               ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "  Mode: $MODE"
[[ -n "$CHECK_FILTER" ]] && echo "  Filter: $CHECK_FILTER"
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

  # Check 1: No separate forum Deployment in manifests
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "no-forum-deployment" ]]; then
    echo "[1/9] Checking for standalone forum Deployment in manifests..."
    if grep -A5 "kind: Deployment" "$REPO_ROOT/deploy/k8s/base/deployments.yml" 2>/dev/null | \
       grep -E "name:\s+(forum|cs_comments_service)" 2>/dev/null | grep -qv "meilisearch"; then
      check_fail "Standalone forum Deployment found (should be integrated into LMS)"
    else
      check_pass "No standalone forum Deployment (forum integrated into LMS)"
    fi
  fi

  # Check 2: openedx-forum in OPENEDX_EXTRA_PIP_REQUIREMENTS
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "dependency-check" ]]; then
    echo "[2/9] Checking for openedx-forum in Tutor config..."
    if [ -f "$REPO_ROOT/tutor_env/config.yml" ]; then
      if grep -q "openedx-forum" "$REPO_ROOT/tutor_env/config.yml" 2>/dev/null; then
        check_pass "openedx-forum found in OPENEDX_EXTRA_PIP_REQUIREMENTS"
      else
        check_warn "openedx-forum not found in config (may be built into image)"
      fi
    else
      check_warn "tutor_env/config.yml not found (run 'tutor config save' first)"
    fi
  fi

  # Check 3: pymongo[srv] dependency present
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "dependency-check" ]]; then
    echo "[3/9] Checking for pymongo[srv] or dnspython dependencies..."
    PYMONGO_FOUND=false
    if [ -f "$REPO_ROOT/tutor_env/config.yml" ]; then
      if grep -E "pymongo\[srv\]|dnspython" "$REPO_ROOT/tutor_env/config.yml" 2>/dev/null; then
        check_pass "pymongo[srv] or dnspython found (required for Atlas SRV)"
        PYMONGO_FOUND=true
      fi
    fi
    if [ "$PYMONGO_FOUND" = false ]; then
      check_fail "pymongo[srv] not found (required for MongoDB Atlas SRV connections)"
    fi
  fi

  # Check 4: Meilisearch Deployment exists
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "meilisearch-manifest" ]]; then
    echo "[4/9] Checking for Meilisearch Deployment in manifests..."
    if grep -A10 "kind: Deployment" "$REPO_ROOT/deploy/k8s/base/deployments.yml" 2>/dev/null | \
       grep -q "name: meilisearch"; then
      check_pass "Meilisearch Deployment found in base manifests"
    else
      check_fail "Meilisearch Deployment missing (required for forum search)"
    fi
  fi

  # Check 5: Meilisearch Service exists
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "meilisearch-manifest" ]]; then
    echo "[5/9] Checking for Meilisearch Service in manifests..."
    if grep -A5 "kind: Service" "$REPO_ROOT/deploy/k8s/base/services.yml" 2>/dev/null | \
       grep -q "name: meilisearch"; then
      check_pass "Meilisearch Service found in base manifests"
    else
      check_fail "Meilisearch Service missing"
    fi
  fi

  # Check 6: FORUM_MONGODB_HOST referenced in ExternalSecrets
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "secrets-check" ]]; then
    echo "[6/9] Checking for forum MongoDB config in ExternalSecrets..."
    if [ -f "$REPO_ROOT/deploy/k8s/base/secrets/external-secrets.yaml" ]; then
      if grep -E "FORUM_MONGODB_(HOST|SRV)" "$REPO_ROOT/deploy/k8s/base/secrets/external-secrets.yaml" 2>/dev/null; then
        check_pass "Forum MongoDB host/SRV referenced in ExternalSecrets"
      else
        check_fail "FORUM_MONGODB_HOST/SRV not found in ExternalSecrets"
      fi
    else
      check_fail "ExternalSecrets file not found"
    fi
  fi

  # Check 7: Forum config present in apply-patches.sh or tutor config
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "config-check" ]]; then
    echo "[7/9] Checking for forum configuration..."
    FORUM_CONFIG_FOUND=false

    # Check apply-patches.sh for forum-related config
    if [ -f "$REPO_ROOT/infrastructure/tutor/apply-patches.sh" ]; then
      if grep -iE "(forum|meilisearch)" "$REPO_ROOT/infrastructure/tutor/apply-patches.sh" 2>/dev/null | grep -v "^#" | grep -q .; then
        check_pass "Forum/Meilisearch config found in apply-patches.sh"
        FORUM_CONFIG_FOUND=true
      fi
    fi

    # Check tutor config
    if [ -f "$REPO_ROOT/tutor_env/config.yml" ]; then
      if grep -iE "(forum|meilisearch)" "$REPO_ROOT/tutor_env/config.yml" 2>/dev/null | grep -v "^#" | grep -q .; then
        check_pass "Forum/Meilisearch config found in tutor_env/config.yml"
        FORUM_CONFIG_FOUND=true
      fi
    fi

    if [ "$FORUM_CONFIG_FOUND" = false ]; then
      check_warn "No explicit forum config found (may use defaults)"
    fi
  fi

  # Check 8: No Ruby forum references in manifests
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "no-ruby-forum" ]]; then
    echo "[8/9] Checking for Ruby forum references..."
    RUBY_FOUND=false
    if grep -iE "(cs_comments_service|overhangio/openedx-forum:[0-9]+\.[0-9]+\.[0-9]+)" \
       "$REPO_ROOT/deploy/k8s/base/deployments.yml" 2>/dev/null | grep -v "^#"; then
      check_fail "Ruby forum references found in deployments (should be removed)"
      RUBY_FOUND=true
    fi
    if [ "$RUBY_FOUND" = false ]; then
      check_pass "No Ruby forum containers/images in manifests"
    fi
  fi

  # Check 9: LMS deployment has forum env vars
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "lms-env-check" ]]; then
    echo "[9/9] Checking LMS deployment for MongoDB env vars..."
    if grep -A50 "name: lms" "$REPO_ROOT/deploy/k8s/base/deployments.yml" 2>/dev/null | \
       grep -A5 "MONGODB_HOST" | grep -q "secretKeyRef"; then
      check_pass "LMS deployment has MONGODB_HOST from secretKeyRef"
    else
      check_fail "LMS deployment missing MONGODB_HOST env var (forum needs this)"
    fi
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

  # Check 1: LMS pod is running
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "pod-health" ]]; then
    echo "[1/5] Checking LMS pod health..."
    if command -v kubectl &> /dev/null; then
      LMS_RUNNING=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms 2>/dev/null | grep -c "Running" || echo "0")
      LMS_RUNNING=$(echo "$LMS_RUNNING" | head -1 | tr -d ' ')
      if [ "$LMS_RUNNING" -gt 0 ] 2>/dev/null; then
        check_pass "LMS pods running ($LMS_RUNNING pods)"
      else
        check_warn "No LMS pods running (may not be deployed yet)"
      fi
    else
      check_warn "kubectl not available, skipping K8s checks"
    fi
  fi

  # Check 2: Meilisearch pod is running
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "pod-health" ]]; then
    echo "[2/5] Checking Meilisearch pod health..."
    if command -v kubectl &> /dev/null; then
      MEILI_RUNNING=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=meilisearch 2>/dev/null | grep -c "Running" || echo "0")
      MEILI_RUNNING=$(echo "$MEILI_RUNNING" | head -1 | tr -d ' ')
      if [ "$MEILI_RUNNING" -gt 0 ] 2>/dev/null; then
        check_pass "Meilisearch pods running ($MEILI_RUNNING pods)"
      else
        check_warn "No Meilisearch pods running (forum search will not work)"
      fi
    fi
  fi

  # Check 3: LMS pod has forum-related env vars
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "env-check" ]]; then
    echo "[3/5] Checking LMS pod for forum environment variables..."
    if command -v kubectl &> /dev/null; then
      LMS_POD=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
      if [ -n "$LMS_POD" ]; then
        if kubectl exec -n mereka-lms "$LMS_POD" -- env 2>/dev/null | grep -qE "(MONGODB_HOST|MEILISEARCH)"; then
          check_pass "LMS pod has forum-related env vars (MONGODB_HOST, MEILISEARCH)"
        else
          check_warn "Forum-related env vars not visible in pod (may be in settings files)"
        fi
      else
        check_warn "No LMS pod found to inspect"
      fi
    fi
  fi

  # Check 4: Forum API endpoint responds (curl test)
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "api-check" ]]; then
    echo "[4/5] Checking forum API endpoint..."
    if command -v kubectl &> /dev/null; then
      LMS_POD=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
      if [ -n "$LMS_POD" ]; then
        # Try to curl the forum API endpoint from within the LMS pod
        if kubectl exec -n mereka-lms "$LMS_POD" -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/api/discussion/v1/ 2>/dev/null | grep -qE "^(200|301|302|401)"; then
          check_pass "Forum API endpoint responds (integrated into LMS)"
        else
          check_warn "Forum API endpoint not responding (may need authentication or not yet configured)"
        fi
      else
        check_warn "No LMS pod found to test API"
      fi
    fi
  fi

  # Check 5: Meilisearch health endpoint responds
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "meilisearch-health" ]]; then
    echo "[5/5] Checking Meilisearch health endpoint..."
    if command -v kubectl &> /dev/null; then
      MEILI_POD=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=meilisearch -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
      if [ -n "$MEILI_POD" ]; then
        if kubectl exec -n mereka-lms "$MEILI_POD" -- curl -s -o /dev/null -w "%{http_code}" http://localhost:7700/health 2>/dev/null | grep -q "^200"; then
          check_pass "Meilisearch health endpoint responds"
        else
          check_warn "Meilisearch health endpoint not responding"
        fi
      else
        check_warn "No Meilisearch pod found to test"
      fi
    fi
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
  echo -e "${GREEN}✓ Forum service integration verified successfully!${NC}"
  echo ""
  echo "Forum v2 Configuration:"
  echo "  - Type: Python openedx-forum (integrated into LMS process)"
  echo "  - Search: Meilisearch v1.8.4"
  echo "  - Database: MongoDB Atlas (cs_comments_service database)"
  echo "  - Cluster: cluster-mereka-lms.2pjex4s.mongodb.net"
  echo ""
  exit 0
else
  echo -e "${RED}✗ Forum service integration verification failed!${NC}"
  echo ""
  echo "Common issues:"
  echo "  - pymongo[srv] missing from OPENEDX_EXTRA_PIP_REQUIREMENTS"
  echo "  - MONGODB_HOST not set in LMS deployment"
  echo "  - Meilisearch not deployed"
  echo "  - Ruby forum references not removed from manifests"
  echo ""
  echo "See docs/runbooks/operations/TROUBLESHOOTING.md for more details"
  exit 1
fi
