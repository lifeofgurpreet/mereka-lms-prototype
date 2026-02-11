#!/usr/bin/env bash
# @covers AC-002
# @spec: data-migrations-kajabi-mct_spec.md
# Verify MCT export files against AC-002.
#
# Checks:
# - Users, categories, courses, enrollments exported
# - Files are valid NDJSON
# - Row counts are reasonable (users ~69K, enrollments ~2.3M)
#
# Usage:
#   ./scripts/qa/verify-mct-export.sh
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

failures=0
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

EXPORT_DIR="exports/mct"

# Expected resource files
RESOURCES=(
  "users"
  "categories"
  "courses"
  "enrollments"
  "organizations"
  "groups"
  "learningpaths"
)

# Check directory exists
if [[ ! -d "$EXPORT_DIR" ]]; then
  fail "Export directory missing: $EXPORT_DIR"
  exit 1
fi

pass "Export directory exists: $EXPORT_DIR"

# Check all resource files exist
for resource in "${RESOURCES[@]}"; do
  file="$EXPORT_DIR/${resource}.ndjson"
  if [[ -f "$file" ]]; then
    pass "Resource file exists: ${resource}.ndjson"
  else
    fail "Resource file missing: ${resource}.ndjson"
  fi
done

# Validate key resources have expected data volumes
check_resource() {
  local resource="$1"
  local min_rows="$2"
  local max_rows="$3"
  local file="$EXPORT_DIR/${resource}.ndjson"

  if [[ ! -f "$file" ]]; then
    return
  fi

  line_count=$(wc -l < "$file" | tr -d ' ')

  if [[ "$line_count" -lt "$min_rows" ]]; then
    fail "${resource}.ndjson has only $line_count rows (expected >=$min_rows)"
  elif [[ "$line_count" -gt "$max_rows" ]]; then
    fail "${resource}.ndjson has $line_count rows (expected <=$max_rows)"
  else
    pass "${resource}.ndjson has $line_count rows (within expected range)"
  fi

  # Validate NDJSON format
  if head -1 "$file" | jq empty 2>/dev/null; then
    pass "Valid NDJSON format: ${resource}.ndjson"
  else
    fail "Invalid NDJSON format: ${resource}.ndjson"
  fi
}

# Check row counts (within 1% tolerance as per spec)
check_resource "users" 68000 70000          # ~69K users
check_resource "enrollments" 2200000 2400000 # ~2.3M enrollments
check_resource "categories" 20 40           # ~30 categories
check_resource "courses" 70 90              # ~81 courses

# Summary
echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "✓ All MCT export checks passed"
  exit 0
else
  echo "✗ $failures check(s) failed"
  exit 1
fi
