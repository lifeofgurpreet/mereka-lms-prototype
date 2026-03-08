#!/usr/bin/env bash
# @covers AC-UISLOT-005
# Verify MFE Plugin-Slot Matrix documentation completeness and correctness
#
# This script validates that the plugin-slot matrix documentation meets
# all requirements from bead 1aj1 acceptance criteria.

set -euo pipefail

PASS=0
FAIL=0
WARN=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MATRIX_DOC="${REPO_ROOT}/docs/reference/operations/MFE_PLUGIN_SLOT_MATRIX.md"
INVENTORY_DOC="${REPO_ROOT}/docs/architecture/MFE_PLUGIN_SLOT_INVENTORY.md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() {
  echo -e "${GREEN}PASS${NC}: $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}FAIL${NC}: $1"
  FAIL=$((FAIL + 1))
}

warn() {
  echo -e "${YELLOW}WARN${NC}: $1"
  WARN=$((WARN + 1))
}

echo "=== MFE Plugin-Slot Matrix Verification ==="
echo ""

# AC-UISLOT-005: Matrix document exists
if [[ -f "$MATRIX_DOC" ]]; then
  pass "Matrix document exists at docs/reference/operations/MFE_PLUGIN_SLOT_MATRIX.md"
else
  fail "Matrix document missing at docs/reference/operations/MFE_PLUGIN_SLOT_MATRIX.md"
  echo "=== Summary: $PASS passed, $FAIL failed, $WARN warnings ==="
  exit 1
fi

# AC-UISLOT-001: Links to canonical inventory
if grep -q "MFE_PLUGIN_SLOT_INVENTORY.md" "$MATRIX_DOC"; then
  pass "Matrix document references canonical inventory"
else
  fail "Matrix document must reference canonical inventory (MFE_PLUGIN_SLOT_INVENTORY.md)"
fi

# AC-UISLOT-001: Required table columns present
REQUIRED_COLUMNS=(
  "Slot ID"
  "Target MFE"
  "Operation Type"
  "Plugin Type"
  "Owner"
  "Rollout Priority"
)

MISSING_COLUMNS=()
for col in "${REQUIRED_COLUMNS[@]}"; do
  if grep -q "$col" "$MATRIX_DOC"; then
    pass "Column present: $col"
  else
    fail "Required column missing: $col"
    MISSING_COLUMNS+=("$col")
  fi
done

# AC-UISLOT-001: Footer slot listed (minimum viable entry)
if grep -q "org.openedx.frontend.layout.footer.v1" "$MATRIX_DOC"; then
  pass "Footer slot (org.openedx.frontend.layout.footer.v1) present in matrix"
else
  fail "Footer slot must be listed in matrix (currently wired)"
fi

# AC-UISLOT-002: env.config.jsx migration mapping section
if grep -q "env.config.jsx Migration Map" "$MATRIX_DOC" || grep -q "Migration Map" "$MATRIX_DOC"; then
  pass "env.config.jsx migration mapping section present"
else
  fail "Missing env.config.jsx migration mapping section (AC-UISLOT-002)"
fi

# AC-UISLOT-002: Migration mapping table structure
if grep -q "Current Approach" "$MATRIX_DOC" && grep -q "Slot-Based Equivalent" "$MATRIX_DOC"; then
  pass "Migration mapping table has required columns"
else
  fail "Migration mapping table must include 'Current Approach' and 'Slot-Based Equivalent' columns"
fi

# AC-UISLOT-003: Direct vs iFrame decision rules section
if grep -q -i "direct.*iframe.*decision" "$MATRIX_DOC" || grep -q "Plugin Type.*When to Use" "$MATRIX_DOC"; then
  pass "Direct vs iFrame decision rules section present"
else
  fail "Missing Direct vs iFrame decision rules section (AC-UISLOT-003)"
fi

# AC-UISLOT-003: Decision table structure
if grep -q "Plugin Type" "$MATRIX_DOC" && grep -q "When to Use" "$MATRIX_DOC"; then
  pass "Decision rules table has required columns"
else
  fail "Decision rules table must include 'Plugin Type' and 'When to Use' columns"
fi

# AC-UISLOT-003: Default to Direct plugin type documented
if grep -q -i "default.*direct" "$MATRIX_DOC"; then
  pass "Default plugin type (Direct) documented"
else
  warn "Document should state default plugin type is Direct"
fi

# AC-UISLOT-004: Discovery method section
if grep -q -i "discovery.*method" "$MATRIX_DOC" || grep -q "Plugin-Slot Discovery" "$MATRIX_DOC"; then
  pass "Discovery method section present"
else
  fail "Missing discovery method section (AC-UISLOT-004)"
fi

# AC-UISLOT-004: /src/plugin-slots reference
if grep -q "/src/plugin-slots" "$MATRIX_DOC"; then
  pass "Discovery method documents /src/plugin-slots directory"
else
  fail "Discovery method must reference /src/plugin-slots directory in MFE repos"
fi

# AC-UISLOT-004: Evidence links present
if grep -q "github.com/openedx" "$MATRIX_DOC" || grep -q "Evidence" "$MATRIX_DOC"; then
  pass "Evidence links to upstream repos present"
else
  warn "Consider adding evidence links to upstream MFE repos"
fi

# AC-UISLOT-001: Cross-reference canonical inventory exists
if [[ -f "$INVENTORY_DOC" ]]; then
  pass "Canonical inventory document exists (cross-reference valid)"
else
  fail "Canonical inventory document missing at docs/architecture/MFE_PLUGIN_SLOT_INVENTORY.md"
fi

# AC-UISLOT-005: Matrix includes at least one ACTIVE slot
if grep -q "ACTIVE" "$MATRIX_DOC"; then
  pass "Matrix includes at least one ACTIVE slot"
else
  warn "Matrix should list currently active slots (e.g., footer)"
fi

# AC-UISLOT-005: Matrix table is parseable (basic check)
TABLE_ROWS=$(grep -c "^|.*|.*|.*|$" "$MATRIX_DOC" || echo 0)
if [[ $TABLE_ROWS -ge 3 ]]; then
  pass "Matrix table has $TABLE_ROWS rows (minimum viable)"
else
  fail "Matrix table should have at least 3 rows (header + separator + 1 data row)"
fi

# AC-UISLOT-002: Migration checklist present
if grep -q -i "migration.*checklist" "$MATRIX_DOC" || grep -q "When migrating" "$MATRIX_DOC"; then
  pass "Migration checklist or workflow documented"
else
  warn "Consider adding migration checklist for operators"
fi

# AC-UISLOT-003: iFrame justification checklist
if grep -q -i "justification.*checklist" "$MATRIX_DOC" || grep -q "Before choosing iFrame" "$MATRIX_DOC"; then
  pass "iFrame justification checklist present"
else
  warn "Consider adding iFrame justification checklist"
fi

# AC-UISLOT-004: Discovery command examples
if grep -q "grep.*PluginSlot" "$MATRIX_DOC" || grep -q "docker exec" "$MATRIX_DOC"; then
  pass "Discovery command examples documented"
else
  warn "Consider adding practical discovery command examples"
fi

# AC-UISLOT-001: Slot naming conventions documented
if grep -q -i "naming.*convention" "$MATRIX_DOC" || grep -q "Namespaced" "$MATRIX_DOC"; then
  pass "Slot naming conventions documented"
else
  warn "Consider documenting slot naming conventions (namespaced vs shorthand)"
fi

# Summary
echo ""
echo "=== Summary: $PASS passed, $FAIL failed, $WARN warnings ==="
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo "Matrix documentation verification FAILED"
  exit 1
else
  echo "Matrix documentation verification PASSED"
  if [[ $WARN -gt 0 ]]; then
    echo "Note: $WARN warnings (non-blocking)"
  fi
  exit 0
fi
