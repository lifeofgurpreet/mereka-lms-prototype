#!/usr/bin/env bash
# @covers AC-001
# @spec: data-migrations-kajabi-mct_spec.md
# Verify Kajabi export files against AC-001.
#
# Checks:
# - All 17 resource types exported to exports/kajabi/
# - Files are valid NDJSON
# - Row counts are non-zero for expected resources
#
# Usage:
#   ./scripts/qa/verify-kajabi-export.sh
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

failures=0
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

EXPORT_DIR="exports/kajabi"

# Expected resource types (17 total)
RESOURCES=(
  "blog_posts"
  "completions"
  "contact_notes"
  "contact_tags"
  "contacts"
  "courses_errors"
  "courses_full"
  "courses_index"
  "custom_fields"
  "customers"
  "form_submissions"
  "forms"
  "landing_pages"
  "offers"
  "order_items"
  "orders"
  "products"
)

# Resources expected to have data
NON_EMPTY_RESOURCES=(
  "completions"
  "contacts"
  "courses_full"
  "courses_index"
  "customers"
  "offers"
  "products"
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

# Validate NDJSON format and check row counts
for resource in "${NON_EMPTY_RESOURCES[@]}"; do
  file="$EXPORT_DIR/${resource}.ndjson"
  if [[ ! -f "$file" ]]; then
    continue
  fi

  # Check if file is empty
  if [[ ! -s "$file" ]]; then
    fail "Expected non-empty file: ${resource}.ndjson"
    continue
  fi

  # Count lines
  line_count=$(wc -l < "$file" | tr -d ' ')

  if [[ "$line_count" -eq 0 ]]; then
    fail "Zero rows in ${resource}.ndjson"
    continue
  fi

  # Validate first line is valid JSON
  if head -1 "$file" | jq empty 2>/dev/null; then
    pass "Valid NDJSON format: ${resource}.ndjson ($line_count rows)"
  else
    fail "Invalid NDJSON format: ${resource}.ndjson"
  fi
done

# Summary
echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "✓ All Kajabi export checks passed"
  exit 0
else
  echo "✗ $failures check(s) failed"
  exit 1
fi
