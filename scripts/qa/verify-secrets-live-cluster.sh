#!/usr/bin/env bash
# @covers AC-001, AC-002, AC-003, AC-018
# @spec: secrets-management_spec.md
# Verify secrets pipeline in a live cluster
#
# Checks:
#   AC-001: ExternalSecrets show SecretSynced status
#   AC-002: Deployments have envFrom with secretRef
#   AC-003: Running pods have non-empty secret env vars
#   AC-018: Secret rotation mechanism is configured
#
# Usage:
#   ./scripts/qa/verify-secrets-live-cluster.sh              # Auto-detect cluster
#   ./scripts/qa/verify-secrets-live-cluster.sh --require-cluster  # Fail if no cluster
#   ./scripts/qa/verify-secrets-live-cluster.sh --skip-cluster     # Skip all checks

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
PASS=0
FAIL=0
SKIP=0

# Cluster settings
NAMESPACE="${NAMESPACE:-mereka-lms}"
REQUIRE_CLUSTER=false
SKIP_CLUSTER=false

# Helper functions
pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --require-cluster)
      REQUIRE_CLUSTER=true
      shift
      ;;
    --skip-cluster)
      SKIP_CLUSTER=true
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--require-cluster|--skip-cluster]" >&2
      exit 1
      ;;
  esac
done

# Check for cluster access
CLUSTER_AVAILABLE=false
if [[ "$SKIP_CLUSTER" == "false" ]]; then
  if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    CLUSTER_AVAILABLE=true
  fi
fi

if [[ "$CLUSTER_AVAILABLE" == "false" ]]; then
  if [[ "$REQUIRE_CLUSTER" == "true" ]]; then
    echo -e "${RED}ERROR:${NC} Cluster access required but not available" >&2
    exit 1
  fi

  echo -e "${YELLOW}No cluster access detected. Skipping all checks.${NC}"
  echo ""
  skip "AC-001: ExternalSecrets SecretSynced status (no cluster)"
  skip "AC-002: Deployments have envFrom secretRef (no cluster)"
  skip "AC-003: Pods have non-empty secret env vars (no cluster)"
  skip "AC-018: Secret rotation mechanism configured (no cluster)"

  echo ""
  echo "=== Summary ==="
  echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
  exit 0
fi

echo "=== Secrets Live Cluster Verification ==="
echo "Namespace: $NAMESPACE"
echo ""

# AC-001: Check ExternalSecrets are synced
echo "Checking AC-001: ExternalSecrets SecretSynced status..."

required_externalsecrets=("openedx-secrets" "database-secrets")
ac001_pass=true

for es_name in "${required_externalsecrets[@]}"; do
  if ! kubectl get externalsecret "$es_name" -n "$NAMESPACE" >/dev/null 2>&1; then
    fail "AC-001: ExternalSecret '$es_name' not found"
    ac001_pass=false
    continue
  fi

  # Check if Ready condition is True
  ready_status=$(kubectl get externalsecret "$es_name" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")

  if [[ "$ready_status" == "True" ]]; then
    pass "AC-001: ExternalSecret '$es_name' is SecretSynced"
  else
    fail "AC-001: ExternalSecret '$es_name' is NOT SecretSynced (Ready status: $ready_status)"
    ac001_pass=false
  fi
done

if [[ "$ac001_pass" == "false" ]]; then
  echo "  Troubleshooting: kubectl describe externalsecret -n $NAMESPACE"
fi

echo ""

# AC-002: Check deployments have envFrom with secretRef
echo "Checking AC-002: Deployments have envFrom secretRef..."

required_deployments=("lms" "cms")
ac002_pass=true

for deploy_name in "${required_deployments[@]}"; do
  if ! kubectl get deployment "$deploy_name" -n "$NAMESPACE" >/dev/null 2>&1; then
    skip "AC-002: Deployment '$deploy_name' not found (may not be deployed)"
    continue
  fi

  # Check for envFrom with secretRef to openedx-secrets
  has_openedx_secret=$(kubectl get deployment "$deploy_name" -n "$NAMESPACE" -o json 2>/dev/null | \
    jq -r '.spec.template.spec.containers[].envFrom[]? | select(.secretRef.name == "openedx-secrets") | .secretRef.name' | \
    grep -q "openedx-secrets" && echo "true" || echo "false")

  if [[ "$has_openedx_secret" == "true" ]]; then
    pass "AC-002: Deployment '$deploy_name' has envFrom secretRef to openedx-secrets"
  else
    fail "AC-002: Deployment '$deploy_name' missing envFrom secretRef to openedx-secrets"
    ac002_pass=false
  fi
done

echo ""

# AC-003: Check running pod has non-empty secret env var
echo "Checking AC-003: Running pods have non-empty secret env vars..."

# Try to find a running LMS pod
lms_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=lms --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -z "$lms_pod" ]]; then
  skip "AC-003: No running LMS pod found to test env vars"
else
  # Check if OPENEDX_SECRET_KEY is non-empty
  secret_key=$(kubectl exec "$lms_pod" -n "$NAMESPACE" -- sh -c 'echo ${OPENEDX_SECRET_KEY:-EMPTY}' 2>/dev/null || echo "ERROR")

  if [[ "$secret_key" == "ERROR" ]]; then
    fail "AC-003: Failed to exec into pod '$lms_pod'"
  elif [[ "$secret_key" == "EMPTY" ]]; then
    fail "AC-003: OPENEDX_SECRET_KEY is empty in pod '$lms_pod'"
  elif [[ ${#secret_key} -lt 20 ]]; then
    fail "AC-003: OPENEDX_SECRET_KEY suspiciously short (${#secret_key} chars) in pod '$lms_pod'"
  else
    pass "AC-003: OPENEDX_SECRET_KEY is non-empty in pod '$lms_pod' (${#secret_key} chars)"
  fi
fi

echo ""

# AC-018: Check secret rotation mechanism is configured
echo "Checking AC-018: Secret rotation mechanism configured..."

ac018_pass=true

# Check refreshInterval is set to 1h
for es_name in "${required_externalsecrets[@]}"; do
  if ! kubectl get externalsecret "$es_name" -n "$NAMESPACE" >/dev/null 2>&1; then
    continue
  fi

  refresh_interval=$(kubectl get externalsecret "$es_name" -n "$NAMESPACE" -o jsonpath='{.spec.refreshInterval}' 2>/dev/null || echo "")

  if [[ "$refresh_interval" == "1h" ]]; then
    pass "AC-018: ExternalSecret '$es_name' has refreshInterval: 1h"
  else
    fail "AC-018: ExternalSecret '$es_name' has refreshInterval: $refresh_interval (expected: 1h)"
    ac018_pass=false
  fi

  # Check that refresh has happened recently (within last 2 hours)
  last_refresh=$(kubectl get externalsecret "$es_name" -n "$NAMESPACE" -o jsonpath='{.status.refreshTime}' 2>/dev/null || echo "")

  if [[ -n "$last_refresh" ]]; then
    # Check if refresh was within last 2 hours (7200 seconds)
    current_time=$(date +%s)
    refresh_time=$(date -d "$last_refresh" +%s 2>/dev/null || echo "0")

    if [[ "$refresh_time" -gt 0 ]]; then
      age=$((current_time - refresh_time))

      if [[ $age -lt 7200 ]]; then
        pass "AC-018: ExternalSecret '$es_name' refreshed recently (${age}s ago)"
      else
        fail "AC-018: ExternalSecret '$es_name' last refresh was ${age}s ago (>2 hours)"
        ac018_pass=false
      fi
    else
      skip "AC-018: Could not parse refreshTime for '$es_name'"
    fi
  else
    skip "AC-018: No refreshTime status for '$es_name'"
  fi
done

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "Some checks failed. Review the output above."
  exit 1
fi

exit 0
