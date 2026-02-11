#!/usr/bin/env bash
# @covers AC-006
# @spec: analytics-pipeline_spec.md
set -euo pipefail

# audit-analytics-pii.sh - Scan analytics configuration for PII field exposure
#
# Usage:
#   scripts/qa/audit-analytics-pii.sh

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ASPECTS_DIR="${REPO_ROOT}/deploy/k8s/base/plugins/aspects"
SCRIPTS_DIR="${REPO_ROOT}/scripts/analytics"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASS=0
FAIL=0
WARN=0

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
  WARN=$((WARN + 1))
}

# PII patterns to search for
declare -a PII_PATTERNS=(
  "email"
  "first_name"
  "last_name"
  "ip_address"
  "phone"
  "ssn"
  "date_of_birth"
  "address"
  "postal_code"
  "credit_card"
)

# Safe patterns (these are OK if they appear in analytics)
declare -a SAFE_PATTERNS=(
  "hashed_email"
  "user_id"
  "username_hash"
  "anonymized_id"
  "pseudonym"
)

echo "=== Analytics PII Audit ==="
echo "Scanning for PII field exposure in analytics configuration"
echo

# Check 1: Scan configmaps for PII fields
echo "[1] Scanning ConfigMaps for PII patterns..."
if [[ -d "$ASPECTS_DIR" ]]; then
  found_pii=false

  for pattern in "${PII_PATTERNS[@]}"; do
    matches=$(grep -riE "\b${pattern}\b" "$ASPECTS_DIR"/*.yml 2>/dev/null | grep -v "^#" || true)

    if [[ -n "$matches" ]]; then
      # Check if it's in a safe context (commented, in quotes as example, etc.)
      unsafe_matches=$(echo "$matches" | grep -vE "(#.*${pattern}|example|sample|test|comment|description)" || true)

      if [[ -n "$unsafe_matches" ]]; then
        fail "Found PII pattern '$pattern' in ConfigMaps:"
        echo "$unsafe_matches" | while IFS= read -r line; do
          echo "    $line"
        done
        found_pii=true
      fi
    fi
  done

  if [[ "$found_pii" == "false" ]]; then
    pass "No PII patterns found in ConfigMaps"
  fi
else
  warn "Aspects directory not found: $ASPECTS_DIR"
fi
echo

# Check 2: Scan analytics scripts for PII extraction
echo "[2] Scanning analytics scripts for PII extraction..."
if [[ -d "$SCRIPTS_DIR" ]]; then
  found_pii=false

  for script in "$SCRIPTS_DIR"/*.py "$SCRIPTS_DIR"/*.sh; do
    [[ -f "$script" ]] || continue

    for pattern in "${PII_PATTERNS[@]}"; do
      # Look for field selections/exports
      matches=$(grep -nE "(SELECT|select|\.${pattern}|['\"']${pattern}['\"'])" "$script" 2>/dev/null | grep -v "^#" || true)

      if [[ -n "$matches" ]]; then
        # Check if it's being anonymized/hashed
        context=$(grep -B2 -A2 -E "\b${pattern}\b" "$script" || true)

        if ! echo "$context" | grep -qE "(hash|anonymize|pseudonym|md5|sha|encrypt)"; then
          fail "Script $(basename "$script") may expose PII field '$pattern':"
          echo "$matches" | head -3 | while IFS= read -r line; do
            echo "    $line"
          done
          found_pii=true
        fi
      fi
    done
  done

  if [[ "$found_pii" == "false" ]]; then
    pass "No PII extraction found in analytics scripts"
  fi
else
  warn "Analytics scripts directory not found: $SCRIPTS_DIR"
fi
echo

# Check 3: Check for anonymization/hashing patterns
echo "[3] Checking for anonymization patterns..."
anonymization_found=false

for pattern in "${SAFE_PATTERNS[@]}"; do
  if grep -rqE "\b${pattern}\b" "$ASPECTS_DIR" "$SCRIPTS_DIR" 2>/dev/null; then
    pass "Found anonymization pattern: $pattern"
    anonymization_found=true
  fi
done

if [[ "$anonymization_found" == "false" ]]; then
  warn "No explicit anonymization patterns found (may use external transformation)"
fi
echo

# Check 4: Scan for SQL/queries that might export PII
echo "[4] Scanning for SELECT queries with PII fields..."
sql_files=()
mapfile -t sql_files < <(find "$REPO_ROOT" -type f \( -name "*.sql" -o -name "*.py" -o -name "*.sh" \) 2>/dev/null | grep -E "(analytics|export|query)" || true)

if [[ ${#sql_files[@]} -gt 0 ]]; then
  found_unsafe=false

  for file in "${sql_files[@]}"; do
    for pattern in "${PII_PATTERNS[@]}"; do
      if grep -qE "SELECT.*\b${pattern}\b" "$file" 2>/dev/null; then
        # Check if there's anonymization in the same query
        local query_context
        query_context=$(grep -A5 "SELECT.*\b${pattern}\b" "$file" || true)

        if ! echo "$query_context" | grep -qE "(hash|md5|sha|anonymize|CONCAT|SUBSTR)"; then
          fail "SQL query in $(basename "$file") may select PII field '$pattern' without anonymization"
          found_unsafe=true
        fi
      fi
    done
  done

  if [[ "$found_unsafe" == "false" ]]; then
    pass "SQL queries do not expose PII fields directly"
  fi
else
  warn "No SQL/query files found to audit"
fi
echo

# Check 5: Verify event tracking configs exclude PII
echo "[5] Checking event tracking configuration..."
tracking_configs=()
mapfile -t tracking_configs < <(find "$REPO_ROOT" -type f -name "*tracking*" -o -name "*event*.yml" 2>/dev/null || true)

if [[ ${#tracking_configs[@]} -gt 0 ]]; then
  found_issue=false

  for config in "${tracking_configs[@]}"; do
    for pattern in "${PII_PATTERNS[@]}"; do
      if grep -qE "^\s*-?\s*${pattern}" "$config" 2>/dev/null; then
        fail "Event tracking config $(basename "$config") may include PII field: $pattern"
        found_issue=true
      fi
    done
  done

  if [[ "$found_issue" == "false" ]]; then
    pass "Event tracking configs do not explicitly include PII fields"
  fi
else
  warn "No event tracking configuration files found"
fi

# Summary
echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS"
echo -e "${YELLOW}WARN:${NC} $WARN"
echo -e "${RED}FAIL:${NC} $FAIL"

if [[ $FAIL -gt 0 ]]; then
  echo
  echo "ACTION REQUIRED: Review flagged PII exposures and ensure:"
  echo "  1. PII fields are hashed/anonymized before storage"
  echo "  2. Analytics queries use pseudonymized identifiers"
  echo "  3. Event tracking excludes sensitive personal data"
  exit 1
fi

if [[ $WARN -gt 0 ]]; then
  echo
  echo "REVIEW RECOMMENDED: Some configurations could not be verified."
fi

exit 0
