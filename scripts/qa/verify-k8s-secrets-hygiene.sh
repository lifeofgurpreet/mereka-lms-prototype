#!/usr/bin/env bash
# @covers AC-012, AC-CCR-004
# @spec: cross-cutting-requirements_spec.md
set -euo pipefail

# verify-k8s-secrets-hygiene.sh - Scans K8s manifests for hardcoded secrets
#
# Usage:
#   scripts/qa/verify-k8s-secrets-hygiene.sh

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."&& pwd)"
K8S_DIR="${REPO_ROOT}/deploy/k8s"

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

# Check for hardcoded secrets in K8s Secret manifests
check_secret_manifests() {
  echo "Checking for hardcoded secrets in K8s Secret manifests..."

  # Find all Secret manifests
  local secret_files
  secret_files=$(find "$K8S_DIR" -type f -name "*.yaml" -o -name "*.yml" | \
    xargs grep -l "kind: Secret" 2>/dev/null || true)

  if [[ -z "$secret_files" ]]; then
    warn "No Secret manifests found in $K8S_DIR"
    return
  fi

  local issues_found=false

  while IFS= read -r file; do
    local rel_path="${file#$REPO_ROOT/}"

    # Check if this is the placeholder file with empty values
    if grep -q 'stringData:' "$file"; then
      # Extract lines with actual values (not empty strings)
      local non_empty_secrets
      non_empty_secrets=$(awk '/stringData:/,/^---$|^[^ ]/ {
        if ($0 ~ /: ".+"/ && $0 !~ /: ""$/) {
          print
        }
      }' "$file" || true)

      if [[ -n "$non_empty_secrets" ]]; then
        fail "Hardcoded secret values found in $rel_path:"
        echo "$non_empty_secrets" | sed 's/^/    /'
        issues_found=true
        continue
      fi
    fi

    # Check for base64-encoded data fields (data: section)
    if grep -q 'data:' "$file"; then
      local base64_secrets
      base64_secrets=$(awk '/^data:/,/^---$|^[^ ]/ {
        if ($0 ~ /: [A-Za-z0-9+/=]{10,}$/ && $0 !~ /: ""$/) {
          print
        }
      }' "$file" || true)

      if [[ -n "$base64_secrets" ]]; then
        fail "Base64-encoded secret values found in $rel_path:"
        echo "$base64_secrets" | sed 's/^/    /'
        issues_found=true
        continue
      fi
    fi

    # If we got here, the file is clean (likely a placeholder)
    pass "$rel_path (placeholder with empty values)"

  done <<< "$secret_files"

  if [[ "$issues_found" == false ]]; then
    pass "No hardcoded secrets found in Secret manifests"
  fi
}

# Check for sensitive patterns in all YAML files
check_sensitive_patterns() {
  echo "Checking for sensitive patterns in K8s YAML files..."

  # Patterns to detect (case-insensitive)
  local patterns=(
    "password:[[:space:]]*['\"][^'\"]{8,}['\"]"  # Actual password values (8+ chars)
    "api_key:[[:space:]]*['\"][A-Za-z0-9]{16,}['\"]"  # API key values
    "secret_key:[[:space:]]*['\"][A-Za-z0-9]{16,}['\"]"  # Secret key values
    "bearer [A-Za-z0-9_-]{20,}"  # Bearer tokens
    "AKIA[0-9A-Z]{16}"  # AWS Access Key
    "BEGIN (RSA|DSA|EC|OPENSSH) PRIVATE KEY"
    'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}'  # JWT token (substantial length)
  )

  # Exempt patterns (safe to ignore)
  local exempt_patterns=(
    ': ""'  # Empty strings
    'secretKey:'  # Just field names in ExternalSecret mappings
    'remoteRef:'  # References, not actual values
    'valueFrom:'  # References, not actual values
    'secretKeyRef:'  # References, not actual values
    'name: gcp-secret-manager'  # Store reference
    'CHANGE_ME'  # Obvious placeholder
    'changeme'  # Obvious placeholder
    'example'  # Documentation
    'token_key'  # Field name (not value)
    'token/'  # URL path segment
    '_token'  # Field name suffix
    '_url'  # URL field
  )

  local issues_found=false

  for pattern in "${patterns[@]}"; do
    local matches
    matches=$(grep -rniE "$pattern" "$K8S_DIR" --include="*.yaml" --include="*.yml" 2>/dev/null || true)

    if [[ -n "$matches" ]]; then
      # Filter out exempt patterns
      local filtered_matches=""
      while IFS= read -r match; do
        local is_exempt=false
        for exempt in "${exempt_patterns[@]}"; do
          if echo "$match" | grep -qi "$exempt"; then
            is_exempt=true
            break
          fi
        done

        if [[ "$is_exempt" == false ]]; then
          filtered_matches+="$match"$'\n'
        fi
      done <<< "$matches"

      if [[ -n "$filtered_matches" ]]; then
        fail "Sensitive pattern detected: $pattern"
        echo "$filtered_matches" | sed 's/^/    /' | head -10
        if [[ $(echo "$filtered_matches" | wc -l) -gt 10 ]]; then
          echo "    ... (showing first 10 of $(echo "$filtered_matches" | wc -l) matches)"
        fi
        issues_found=true
      fi
    fi
  done

  if [[ "$issues_found" == false ]]; then
    pass "No sensitive patterns detected in YAML files"
  fi
}

# Main execution
main() {
  echo "=== K8s Secrets Hygiene Verification ==="
  echo "Directory: $K8S_DIR"
  echo

  check_secret_manifests
  echo
  check_sensitive_patterns

  # Summary
  echo
  echo "=== Summary ==="
  echo -e "${GREEN}PASS:${NC} $PASS"
  echo -e "${RED}FAIL:${NC} $FAIL"

  if [[ $FAIL -gt 0 ]]; then
    echo
    warn "Hardcoded secrets detected. Please use ExternalSecrets or environment variable references."
    exit 1
  fi

  exit 0
}

main "$@"
