#!/usr/bin/env bash
# @covers AC-001, AC-002, AC-003, AC-005, AC-006
# @spec: analytics-pipeline_spec.md
set -euo pipefail

# verify-analytics-pipeline.sh - Verifies Aspects analytics plugin configuration
#
# Usage:
#   scripts/qa/verify-analytics-pipeline.sh              # Run all checks
#   scripts/qa/verify-analytics-pipeline.sh --check manifests # Run specific check

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ASPECTS_DIR="${REPO_ROOT}/deploy/k8s/base/plugins/aspects"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASS=0
FAIL=0

# Helper functions
pass() {
  echo -e "${GREEN}✓${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}✗${NC} $1"
  FAIL=$((FAIL + 1))
}

warn() {
  echo -e "${YELLOW}⚠${NC} $1"
}

# Check 1: Aspects directory and required files
check_manifests() {
  echo "Checking Aspects K8s manifests..."

  if [[ ! -d "$ASPECTS_DIR" ]]; then
    fail "Aspects directory not found: $ASPECTS_DIR"
    return
  fi
  pass "Aspects directory exists: $ASPECTS_DIR"

  # Required manifest files
  local required_files=(
    "deployments.yml"
    "services.yml"
    "configmaps.yml"
    "secrets.yml"
    "kustomization.yaml"
  )

  for file in "${required_files[@]}"; do
    if [[ -f "$ASPECTS_DIR/$file" ]]; then
      pass "Found required file: $file"
    else
      fail "Missing required file: $file"
    fi
  done
}

# Check 2: ClickHouse deployment configuration
check_clickhouse() {
  echo "Checking ClickHouse deployment configuration..."

  local deployment_file="$ASPECTS_DIR/deployments.yml"

  if [[ ! -f "$deployment_file" ]]; then
    fail "ClickHouse deployment file not found: $deployment_file"
    return
  fi

  # Check for ClickHouse deployment
  if grep -q "name: clickhouse" "$deployment_file"; then
    pass "ClickHouse deployment defined"
  else
    fail "ClickHouse deployment not found in $deployment_file"
    return
  fi

  # Check image reference
  if grep -qE "image:.*clickhouse/clickhouse-server" "$deployment_file"; then
    local image
    image=$(grep -E "image:.*clickhouse/clickhouse-server" "$deployment_file" | head -1 | awk '{print $2}')
    pass "ClickHouse image reference found: $image"
  else
    fail "ClickHouse image reference not found"
  fi

  # Check port configuration (8123 HTTP, 9000 Native)
  if grep -qE "containerPort:\s+8123" "$deployment_file"; then
    pass "ClickHouse HTTP port (8123) configured"
  else
    fail "ClickHouse HTTP port (8123) not configured"
  fi

  if grep -qE "containerPort:\s+9000" "$deployment_file"; then
    pass "ClickHouse Native port (9000) configured"
  else
    fail "ClickHouse Native port (9000) not configured"
  fi

  # Check secret reference for password
  if grep -qE "secretKeyRef:.*clickhouse-password" "$deployment_file"; then
    pass "ClickHouse password references secret (not hardcoded)"
  else
    warn "ClickHouse password may not reference secret properly"
  fi
}

# Check 3: ConfigMap has retention TTL settings
check_retention() {
  echo "Checking ClickHouse retention configuration..."

  local configmap_file="$ASPECTS_DIR/configmaps.yml"

  if [[ ! -f "$configmap_file" ]]; then
    fail "ConfigMap file not found: $configmap_file"
    return
  fi

  # Check for clickhouse-config ConfigMap
  if grep -q "name: clickhouse-config" "$configmap_file"; then
    pass "clickhouse-config ConfigMap exists"
  else
    fail "clickhouse-config ConfigMap not found"
    return
  fi

  # Check for any retention or TTL configuration
  # (Note: actual TTL is set via SQL or config XML, not always in ConfigMap)
  if grep -qiE "(retention|ttl|expire)" "$configmap_file"; then
    pass "Retention/TTL configuration mentioned in ConfigMap"
  else
    warn "No explicit retention/TTL configuration found (may be in SQL migrations)"
  fi

  # Check logging configuration exists
  if grep -q "logging.xml" "$configmap_file"; then
    pass "ClickHouse logging configuration present"
  else
    warn "ClickHouse logging configuration not found"
  fi
}

# Check 4: Aspects service port configuration
check_service() {
  echo "Checking Aspects service configuration..."

  local service_file="$ASPECTS_DIR/services.yml"

  if [[ ! -f "$service_file" ]]; then
    fail "Service file not found: $service_file"
    return
  fi

  # Check for ClickHouse service
  if grep -q "name: clickhouse" "$service_file"; then
    pass "ClickHouse service defined"
  else
    fail "ClickHouse service not found"
    return
  fi

  # Verify service ports (8123 and/or 9000)
  local port_count
  port_count=$(grep -cE "port:\s+(8123|9000)" "$service_file" || true)

  if [[ $port_count -ge 1 ]]; then
    pass "ClickHouse service has port configuration ($port_count ports)"
  else
    fail "ClickHouse service missing port configuration"
  fi
}

# Check 5: OpenEdX-Aspects plugin reference
check_plugin_reference() {
  echo "Checking OpenEdX-Aspects plugin reference..."

  # Check tutor config or requirements files
  local tutor_config="$REPO_ROOT/tutor_env/config.yml"
  local requirements_file="$REPO_ROOT/infrastructure/tutor/requirements.txt"

  local found=false

  # Check tutor config (if exists)
  if [[ -f "$tutor_config" ]]; then
    if grep -qiE "(aspects|xapi|clickhouse)" "$tutor_config"; then
      pass "Aspects plugin referenced in tutor config"
      found=true
    fi
  fi

  # Check requirements.txt
  if [[ -f "$requirements_file" ]]; then
    if grep -qiE "(aspects|tutor-contrib-aspects)" "$requirements_file"; then
      pass "Aspects plugin in requirements.txt"
      found=true
    fi
  fi

  # Check kustomization for plugin reference
  local kustomize_file="$ASPECTS_DIR/kustomization.yaml"
  if [[ -f "$kustomize_file" ]]; then
    if grep -qE "(clickhouse|superset|aspects)" "$kustomize_file"; then
      pass "Aspects resources included in kustomization"
      found=true
    fi
  fi

  if [[ "$found" == "false" ]]; then
    warn "No Aspects plugin reference found in tutor config or requirements"
  fi
}

# Main execution
main() {
  local check_type="all"

  # Parse arguments
  if [[ $# -gt 0 ]]; then
    if [[ "$1" == "--check" && $# -eq 2 ]]; then
      check_type="$2"
    else
      echo "Usage: $0 [--check manifests|clickhouse|retention|service|plugin]"
      exit 1
    fi
  fi

  echo "=== Analytics Pipeline (Aspects) Verification ==="
  echo "Aspects directory: $ASPECTS_DIR"
  echo

  # Run checks
  case "$check_type" in
    manifests)
      check_manifests
      ;;
    clickhouse)
      check_clickhouse
      ;;
    retention)
      check_retention
      ;;
    service)
      check_service
      ;;
    plugin)
      check_plugin_reference
      ;;
    all)
      check_manifests
      echo
      check_clickhouse
      echo
      check_retention
      echo
      check_service
      echo
      check_plugin_reference
      ;;
    *)
      echo "Unknown check type: $check_type"
      exit 1
      ;;
  esac

  # Summary
  echo
  echo "=== Summary ==="
  echo -e "${GREEN}PASS:${NC} $PASS"
  echo -e "${RED}FAIL:${NC} $FAIL"

  if [[ $FAIL -gt 0 ]]; then
    exit 1
  fi

  exit 0
}

main "$@"
