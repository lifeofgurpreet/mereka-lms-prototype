#!/usr/bin/env bash
# @covers AC-022, AC-023
# @spec: k8s-deployment_spec.md
set -euo pipefail

# verify-k8s-externalsecrets.sh - Verifies ExternalSecret YAML manifests
#
# Usage:
#   scripts/qa/verify-k8s-externalsecrets.sh              # Run all checks
#   scripts/qa/verify-k8s-externalsecrets.sh --check spec # Run specific check

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EXTERNAL_SECRETS_FILE="${REPO_ROOT}/deploy/k8s/base/secrets/external-secrets.yaml"

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

# Check 1: ExternalSecret spec configuration
check_spec() {
  echo "Checking ExternalSecret spec configuration..."

  if [[ ! -f "$EXTERNAL_SECRETS_FILE" ]]; then
    fail "File not found: $EXTERNAL_SECRETS_FILE"
    return
  fi

  # Count total ExternalSecret resources
  local total
  total=$(grep -c "kind: ExternalSecret" "$EXTERNAL_SECRETS_FILE" || true)

  if [[ $total -eq 0 ]]; then
    fail "No ExternalSecret resources found in $EXTERNAL_SECRETS_FILE"
    return
  fi

  # Check required fields (each ExternalSecret should have these)
  local refresh_count
  refresh_count=$(grep -c "refreshInterval: 1h" "$EXTERNAL_SECRETS_FILE" || true)

  local store_count
  store_count=$(grep -c "name: gcp-secret-manager" "$EXTERNAL_SECRETS_FILE" || true)

  local deletion_count
  deletion_count=$(grep -c "deletionPolicy: Retain" "$EXTERNAL_SECRETS_FILE" || true)

  # Verify counts match
  local all_valid=true

  if [[ $refresh_count -ne $total ]]; then
    fail "refreshInterval: 1h - expected $total, found $refresh_count"
    all_valid=false
  else
    pass "All $total ExternalSecret resources have refreshInterval: 1h"
  fi

  if [[ $store_count -lt $total ]]; then
    fail "gcp-secret-manager reference - expected at least $total, found $store_count"
    all_valid=false
  else
    pass "All $total ExternalSecret resources reference gcp-secret-manager"
  fi

  if [[ $deletion_count -ne $total ]]; then
    fail "deletionPolicy: Retain - expected $total, found $deletion_count"
    all_valid=false
  else
    pass "All $total ExternalSecret resources have deletionPolicy: Retain"
  fi
}

# Check 2: MEREKA_LMS_ prefix convention
check_prefix() {
  echo "Checking MEREKA_LMS_ prefix convention..."

  if [[ ! -f "$EXTERNAL_SECRETS_FILE" ]]; then
    fail "File not found: $EXTERNAL_SECRETS_FILE"
    return
  fi

  # Extract all remoteRef.key values
  local keys
  keys=$(grep -E '^\s+key:\s+' "$EXTERNAL_SECRETS_FILE" | sed -E 's/^\s+key:\s+//' || true)

  if [[ -z "$keys" ]]; then
    fail "No remoteRef.key entries found"
    return
  fi

  local total=0
  local valid=0
  local invalid_keys=()

  while IFS= read -r key; do
    total=$((total + 1))
    if [[ "$key" =~ ^MEREKA_LMS_ ]]; then
      valid=$((valid + 1))
    else
      invalid_keys+=("$key")
    fi
  done <<< "$keys"

  if [[ ${#invalid_keys[@]} -eq 0 ]]; then
    pass "All $total remoteRef.key values follow MEREKA_LMS_ prefix convention"
  else
    fail "Found ${#invalid_keys[@]} keys without MEREKA_LMS_ prefix:"
    for key in "${invalid_keys[@]}"; do
      echo "    - $key"
    done
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
      echo "Usage: $0 [--check spec|prefix]"
      exit 1
    fi
  fi

  echo "=== K8s ExternalSecrets Verification ==="
  echo "File: $EXTERNAL_SECRETS_FILE"
  echo

  # Run checks
  case "$check_type" in
    spec)
      check_spec
      ;;
    prefix)
      check_prefix
      ;;
    all)
      check_spec
      echo
      check_prefix
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
