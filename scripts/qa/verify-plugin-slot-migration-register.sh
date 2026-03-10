#!/usr/bin/env bash
set -euo pipefail

# @covers AC-8JAO9-001: Migration register document exists with comprehensive inventory
# @covers AC-8JAO9-002: Each entry classifies by risk/tenant-impact/effort/priority
# @covers AC-8JAO9-003: Each entry has a plugin-slot-first replacement pattern
# @covers AC-8JAO9-004: Summary matrix present with status tracking
# @covers AC-8JAO9-005: All MIGRATED items have verification scripts
# @spec: bead-8jao9

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REGISTER_DOC="$REPO_ROOT/docs/reference/architecture/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md"

PASS=0
FAIL=0
WARN=0

pass_check() { echo "✅ $1"; PASS=$((PASS + 1)); }
fail_check() { echo "❌ $1"; FAIL=$((FAIL + 1)); }

warn() {
  local msg="$1"
  echo "⚠️  $msg"
  WARN=$((WARN + 1))
}

# AC-8JAO9-001: Migration register document exists
if [[ -f "$REGISTER_DOC" ]]; then pass_check "Register doc exists"; else fail_check "Register doc exists"; fi

if [[ ! -f "$REGISTER_DOC" ]]; then
  echo ""
  echo "=== SUMMARY ==="
  echo "PASS: $PASS"
  echo "FAIL: $FAIL"
  echo "WARN: $WARN"
  exit 1
fi

# AC-8JAO9-001: Register has at least 10 migration entries
ENTRY_COUNT=$(grep -c '^### [0-9]\+\.' "$REGISTER_DOC" || true)
if [[ $ENTRY_COUNT -ge 10 ]]; then pass_check "Register has at least 10 entries (found: $ENTRY_COUNT)"; else fail_check "Register has at least 10 entries (found: $ENTRY_COUNT)"; fi

# AC-8JAO9-002: Each entry has required classification fields
for field in "Current approach" "Target slot" "Status" "Risk" "Tenant impact" "Priority" "Effort" "Owner" "Files" "Migration path"; do
  FIELD_COUNT=$(grep -c "| \*\*$field\*\* |" "$REGISTER_DOC" || true)
  if [[ $FIELD_COUNT -ge 10 ]]; then pass_check "All entries have '$field' field (found: $FIELD_COUNT >= 10)"; else fail_check "All entries have '$field' field (found: $FIELD_COUNT >= 10)"; fi
done

# AC-8JAO9-003: Plugin-slot replacement patterns present
SLOT_REFS=$(grep -c 'org\.openedx\.frontend\.' "$REGISTER_DOC" || true)
if [[ $SLOT_REFS -ge 5 ]]; then pass_check "Plugin-slot IDs referenced (found: $SLOT_REFS >= 5)"; else fail_check "Plugin-slot IDs referenced (found: $SLOT_REFS >= 5)"; fi

# AC-8JAO9-004: Summary matrix present
if grep -q '^## Summary Matrix' "$REGISTER_DOC"; then pass_check "Summary Matrix section exists"; else fail_check "Summary Matrix section exists"; fi
if grep -q '| # | Override | Slot Available | Status | Priority | Effort | Risk |' "$REGISTER_DOC"; then pass_check "Summary Matrix has header row"; else fail_check "Summary Matrix has header row"; fi

# Count rows in summary matrix
MATRIX_ROWS=$(grep -c '^| [0-9]' "$REGISTER_DOC" || true)
if [[ $MATRIX_ROWS -ge 10 ]]; then pass_check "Summary Matrix has at least 10 rows (found: $MATRIX_ROWS)"; else fail_check "Summary Matrix has at least 10 rows (found: $MATRIX_ROWS)"; fi

# AC-8JAO9-004: No P0 items remain open (all should be Done or migrated)
P0_COUNT=$(grep -cF '| P0 |' "$REGISTER_DOC" 2>/dev/null || true)
if [[ ${P0_COUNT} -gt 0 ]]; then
  warn "Found $P0_COUNT P0 priority items — should all be migrated or in progress"
fi

# AC-8JAO9-005: All MIGRATED items have verification scripts
# Count MIGRATED entries in the table (before Summary Matrix)
MIGRATED_COUNT=$(awk '/^### [0-9]+\./,/^## Summary Matrix/ {if (/MIGRATED/) count++} END {print count+0}' "$REGISTER_DOC" 2>/dev/null | tr -d '[:space:]' || echo 0)
if [[ ${MIGRATED_COUNT} -gt 0 ]]; then
  # Extract verification script references (should be in the same table entries)
  VERIFICATION_REFS=$(grep -c '| \*\*Verification\*\*' "$REGISTER_DOC" || true)
  if [[ $VERIFICATION_REFS -ge $MIGRATED_COUNT ]]; then pass_check "MIGRATED items have verification references (found: $VERIFICATION_REFS >= $MIGRATED_COUNT)"; else fail_check "MIGRATED items have verification references (found: $VERIFICATION_REFS >= $MIGRATED_COUNT)"; fi

  # Check that referenced verification scripts exist
  for script in verify-mfe-footer-slot.sh verify-footer-slot-migration.sh; do
    SCRIPT_PATH="$REPO_ROOT/scripts/qa/$script"
    if grep -q "$script" "$REGISTER_DOC"; then
      if [[ -f "$SCRIPT_PATH" ]]; then pass_check "Referenced verification script exists: $script"; else fail_check "Referenced verification script exists: $script"; fi
    fi
  done
fi

# AC-8JAO9-004: Migration roadmap present
if grep -q '^## Migration Roadmap' "$REGISTER_DOC"; then pass_check "Migration Roadmap section exists"; else fail_check "Migration Roadmap section exists"; fi
if grep -q '^### Now' "$REGISTER_DOC"; then pass_check "Roadmap has 'Now' section"; else fail_check "Roadmap has 'Now' section"; fi
if grep -q '^### Next Sprint' "$REGISTER_DOC"; then pass_check "Roadmap has 'Next Sprint' section"; else fail_check "Roadmap has 'Next Sprint' section"; fi
if grep -q '^### Backlog' "$REGISTER_DOC"; then pass_check "Roadmap has 'Backlog' section"; else fail_check "Roadmap has 'Backlog' section"; fi
if grep -q '^### Keep as CSS' "$REGISTER_DOC"; then pass_check "Roadmap has 'Keep as CSS' section"; else fail_check "Roadmap has 'Keep as CSS' section"; fi

# AC-8JAO9-001: Cross-references to source docs
if grep -q 'MFE_SELECTOR_AUDIT.md' "$REGISTER_DOC"; then pass_check "References MFE_SELECTOR_AUDIT.md"; else fail_check "References MFE_SELECTOR_AUDIT.md"; fi
if grep -q 'MFE_PLUGIN_SLOT_MATRIX.md' "$REGISTER_DOC"; then pass_check "References MFE_PLUGIN_SLOT_MATRIX.md"; else fail_check "References MFE_PLUGIN_SLOT_MATRIX.md"; fi

# Check bead reference
if grep -q '8jao.9' "$REGISTER_DOC"; then pass_check "Bead 8jao.9 referenced"; else fail_check "Bead 8jao.9 referenced"; fi

# Check last updated date is recent (within last 30 days)
LAST_UPDATED=$(grep -oP 'Last updated.*:\s*\K[0-9]{4}-[0-9]{2}-[0-9]{2}' "$REGISTER_DOC" | head -1)
if [[ -n "$LAST_UPDATED" ]]; then
  UPDATED_EPOCH=$(date -d "$LAST_UPDATED" +%s 2>/dev/null || echo 0)
  NOW_EPOCH=$(date +%s)
  DAYS_OLD=$(( (NOW_EPOCH - UPDATED_EPOCH) / 86400 ))
  if [[ $DAYS_OLD -gt 30 ]]; then
    warn "Register doc is $DAYS_OLD days old (last updated: $LAST_UPDATED)"
  fi
fi

echo ""
echo "=== SUMMARY ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo "WARN: $WARN"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "RESULT: FAIL"
  exit 1
fi

echo ""
echo "RESULT: PASS"
exit 0
