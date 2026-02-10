#!/usr/bin/env bash
# Verify cross-system identity handling against AC-013.
#
# Checks:
# - Find emails that exist in both Kajabi and MCT exports
# - Verify email collision handling logic exists in import scripts
#
# Note: This is a static check of data files and import script logic.
# For runtime verification, use the verification pipeline after import.
#
# Usage:
#   ./scripts/qa/verify-cross-system-identity.sh
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

failures=0
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

KAJABI_USERS="scripts/migrations/kajabi/output/users.csv"
MCT_USERS="exports/mct/users.ndjson"

# Check files exist
if [[ ! -f "$KAJABI_USERS" ]]; then
  fail "Kajabi users file missing: $KAJABI_USERS"
fi

if [[ ! -f "$MCT_USERS" ]]; then
  fail "MCT users file missing: $MCT_USERS"
fi

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi

pass "Both user export files exist"

# Extract sample emails from each source
echo "[INFO] Extracting sample emails..."

kajabi_emails=$(tail -n +2 "$KAJABI_USERS" | awk -F, '{print $1}' | tr -d '"' | sort | head -1000)
mct_emails=$(jq -r '.email // .EmailAddress // .email_address' "$MCT_USERS" 2>/dev/null | sort | head -1000)

# Find overlapping emails in samples
overlap_count=$(comm -12 <(echo "$kajabi_emails") <(echo "$mct_emails") | wc -l | tr -d ' ')

if [[ "$overlap_count" -gt 0 ]]; then
  pass "Found $overlap_count overlapping emails in sample sets"
else
  echo "[WARN] No overlapping emails found in samples (may indicate separate user bases)"
fi

# Check import scripts for email collision handling
IMPORT_SCRIPTS=(
  "scripts/migrations/kajabi/openedx_bulk_import.py"
  "scripts/migrations/mct/openedx_bulk_import_mct.py"
)

collision_handling_found=0

for script in "${IMPORT_SCRIPTS[@]}"; do
  if [[ ! -f "$script" ]]; then
    continue
  fi

  # Check for get_or_create or filter/exists patterns
  if grep -q "get_or_create\|filter.*email.*exists\|IntegrityError" "$script"; then
    pass "Email collision handling found in $(basename "$script")"
    collision_handling_found=$((collision_handling_found + 1))
  else
    fail "No email collision handling found in $(basename "$script")"
  fi
done

if [[ "$collision_handling_found" -eq 0 ]]; then
  fail "No import scripts implement email collision handling"
fi

# Summary
echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "✓ All cross-system identity checks passed"
  exit 0
else
  echo "✗ $failures check(s) failed"
  exit 1
fi
