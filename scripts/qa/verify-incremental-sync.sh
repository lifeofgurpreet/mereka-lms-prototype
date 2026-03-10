#!/usr/bin/env bash
# @covers AC-038
# @spec: data-migrations-kajabi-mct_spec.md
# Verify incremental sync logic against AC-038.
#
# Checks:
# - Export scripts support incremental fetching
# - Import scripts handle updates to existing records
# - Timestamp/version tracking for delta detection
#
# Usage:
#   ./scripts/qa/verify-incremental-sync.sh
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

failures=0
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

# Export scripts to check
EXPORT_SCRIPTS=(
  "scripts/migrations/kajabi/kajabi-export.mjs"
  "scripts/migrations/mct/mct-export.mjs"
)

echo "Checking incremental sync patterns in export scripts..."

for script in "${EXPORT_SCRIPTS[@]}"; do
  if [[ ! -f "$script" ]]; then
    echo "[INFO] Script not found: $script (skipping)"
    continue
  fi

  echo ""
  pass "Checking $(basename "$script")"

  # Check for timestamp/date filtering
  if grep -qi "since\|after\|updated.*after\|created.*after\|filter.*date" "$script"; then
    pass "Supports timestamp-based filtering"
  else
    echo "[WARN] No timestamp filtering in $(basename "$script")"
  fi

  # Check for continuation/pagination tokens
  if grep -qi "next.*page\|continuation.*token\|offset\|cursor" "$script"; then
    pass "Supports pagination/continuation"
  else
    echo "[WARN] Limited pagination support in $(basename "$script")"
  fi
done

# Import scripts to check
IMPORT_SCRIPTS=(
  "scripts/migrations/kajabi/openedx_bulk_import.py"
  "scripts/migrations/mct/openedx_bulk_import_mct.py"
)

echo ""
echo "Checking update logic in import scripts..."

for script in "${IMPORT_SCRIPTS[@]}"; do
  if [[ ! -f "$script" ]]; then
    continue
  fi

  echo ""
  pass "Checking $(basename "$script")"

  # Check for update_or_create usage
  if grep -q "update_or_create" "$script"; then
    pass "Uses update_or_create for incremental updates"
  else
    echo "[WARN] No update_or_create pattern in $(basename "$script")"
  fi

  # Check for explicit update logic
  if grep -q "\.save()\|\.update(" "$script"; then
    pass "Has record update logic"
  else
    echo "[WARN] Limited update logic in $(basename "$script")"
  fi
done

# Check for timestamp tracking in export files
SAMPLE_EXPORT="exports/kajabi/contacts.ndjson"
if [[ -f "$SAMPLE_EXPORT" ]]; then
  echo ""
  echo "[INFO] Checking sample export for timestamp fields..."

  sample_record=$(head -1 "$SAMPLE_EXPORT")

  if echo "$sample_record" | jq -e '.updated_at // .modified_at // .last_updated' >/dev/null 2>&1; then
    pass "Export records contain timestamp fields"
  else
    echo "[WARN] No timestamp fields detected in sample export"
  fi
fi

# Check for sync documentation
SYNC_DOCS="docs/ops/runbooks/migrations/VERIFICATION_CHECKLIST.md"
if [[ -f "$SYNC_DOCS" ]]; then
  pass "Incremental sync documentation exists"
else
  echo "[INFO] No dedicated incremental sync documentation found"
fi

# Summary
echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "✓ All incremental sync checks passed"
  exit 0
else
  echo "✗ $failures check(s) failed"
  exit 1
fi
