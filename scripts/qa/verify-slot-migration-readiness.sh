#!/usr/bin/env bash
# @covers AC-UISEL-002
# Verify slot-first migration readiness for Mereka MFE customizations.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0; WARN=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
warn() { echo -e "${YELLOW}WARN${NC} $1"; WARN=$((WARN + 1)); }

echo "Verifying Slot-First Migration Readiness (AC-UISEL-002)..."
echo ""

# ---------------------------------------------------------------------------
# Check 1: MFE_PLUGIN_SLOT_INVENTORY.md exists and has comprehensive inventory
# ---------------------------------------------------------------------------
INVENTORY_DOC="docs/concepts/architecture/MFE_PLUGIN_SLOT_INVENTORY.md"

if [[ ! -f "$INVENTORY_DOC" ]]; then
  fail "MFE_PLUGIN_SLOT_INVENTORY.md not found at $INVENTORY_DOC"
else
  pass "MFE_PLUGIN_SLOT_INVENTORY.md exists at $INVENTORY_DOC"

  # Count documented slots (should be >80 based on upstream Open edX FPF)
  SLOT_COUNT=$(grep -cE 'org\.openedx\.frontend\.' "$INVENTORY_DOC" || echo 0)

  echo "Documented plugin slots: $SLOT_COUNT"

  if [[ $SLOT_COUNT -ge 80 ]]; then
    pass "Slot inventory has $SLOT_COUNT slots (≥80 threshold)"
  else
    warn "Slot inventory has only $SLOT_COUNT slots (expected ≥80)"
  fi
fi

# ---------------------------------------------------------------------------
# Check 2: Footer slot is actively wired (ACTIVE status)
# ---------------------------------------------------------------------------
if ! mereka_plugin_has_any "$REPO_ROOT"; then
  fail "Plugin contract sources not found (expected at least $PLUGIN_MAIN)"
else
  pass "Plugin contract sources exist"

  # Check for footer slot registration (either full slot ID or Python variable name)
  if mereka_plugin_has_regex "$REPO_ROOT" "org\.openedx\.frontend\.layout\.footer\.v1|footer_slot"; then
    pass "Footer slot (org.openedx.frontend.layout.footer.v1 / footer_slot) registered in plugin"
  else
    fail "Footer slot not registered in plugin contract sources"
  fi

  # Check for MerekaFooter component reference
  if mereka_plugin_has_fixed "$REPO_ROOT" "MerekaFooter"; then
    pass "MerekaFooter component referenced in plugin"
  else
    fail "MerekaFooter component not found in plugin contract sources"
  fi
fi

# ---------------------------------------------------------------------------
# Check 3: env.config.jsx patches are documented in apply-patches.sh
# ---------------------------------------------------------------------------
APPLY_PATCHES="infrastructure/tutor/apply-patches.sh"

if [[ ! -f "$APPLY_PATCHES" ]]; then
  fail "apply-patches.sh not found at $APPLY_PATCHES"
else
  pass "apply-patches.sh exists"

  # Count env.config.jsx customizations
  ENV_CONFIG_PATCHES=$(grep -c "env.config.jsx" "$APPLY_PATCHES" 2>/dev/null || true)
  ENV_CONFIG_PATCHES=$(printf '%s' "$ENV_CONFIG_PATCHES" | tr -cd '0-9')

  if [[ -z "$ENV_CONFIG_PATCHES" ]]; then
    ENV_CONFIG_PATCHES=0
  fi

  echo "env.config.jsx references in apply-patches.sh: $ENV_CONFIG_PATCHES"

  if [[ $ENV_CONFIG_PATCHES -gt 0 ]]; then
    pass "apply-patches.sh contains $ENV_CONFIG_PATCHES env.config.jsx customizations"
  else
    warn "apply-patches.sh has no env.config.jsx customizations documented"
  fi
fi

# ---------------------------------------------------------------------------
# Check 4: Current customizations vs slot-wirable count
# ---------------------------------------------------------------------------
echo ""
echo "--- Customization Migration Assessment ---"

# Count current SCSS-based customizations (fragile selectors)
# Sum all counts from grep -rc (which outputs per-file counts)
FRAGILE_SELECTORS=0
if [[ -d infrastructure/tutor/themes/mereka/ ]]; then
  FRAGILE_SELECTORS=$(grep -hrcE '^\s*\.[a-zA-Z0-9_-]+\s+\.[a-zA-Z0-9_-]+\s+\.[a-zA-Z0-9_-]+\s+\.[a-zA-Z0-9_-]+' \
    infrastructure/tutor/themes/mereka/ 2>/dev/null | awk '{s+=$1} END {print s+0}')
fi

# Count documented slot-wirable customizations from policy doc
POLICY_DOC="docs/concepts/architecture/SELECTOR_HARDENING_POLICY.md"
SLOT_WIRABLE=0

if [[ -f "$POLICY_DOC" ]]; then
  # Count entries in "Slot-Wirable Customizations" table
  SLOT_WIRABLE=$(grep -cE '^\|.*\|.*org\.openedx\.frontend\.' "$POLICY_DOC" 2>/dev/null || echo 0)
fi

echo "Current fragile selectors (SCSS-based): $FRAGILE_SELECTORS"
echo "Documented slot-wirable customizations: $SLOT_WIRABLE"

if [[ $SLOT_WIRABLE -gt 0 ]]; then
  pass "Slot migration opportunities documented ($SLOT_WIRABLE candidates)"
  if [[ $((FRAGILE_SELECTORS + SLOT_WIRABLE)) -gt 0 ]]; then
    MIGRATION_RATIO=$((SLOT_WIRABLE * 100 / (FRAGILE_SELECTORS + SLOT_WIRABLE)))
    echo "Potential migration coverage: ${MIGRATION_RATIO}%"
  fi
else
  warn "No slot-wirable customizations documented in $POLICY_DOC"
fi

# ---------------------------------------------------------------------------
# Check 5: Slot inventory has wiring status tracking
# ---------------------------------------------------------------------------
echo ""
echo "--- Verifying Slot Wiring Status Tracking ---"

if [[ -f "$INVENTORY_DOC" ]]; then
  # Check for status markers (ACTIVE, INDIGO, AVAILABLE)
  if grep -q "ACTIVE" "$INVENTORY_DOC" && \
     grep -q "INDIGO" "$INVENTORY_DOC" && \
     grep -q "AVAILABLE" "$INVENTORY_DOC"; then
    pass "Slot inventory tracks wiring status (ACTIVE/INDIGO/AVAILABLE)"
  else
    warn "Slot inventory missing wiring status tracking"
  fi

  # Count active slots
  ACTIVE_SLOTS=$(grep -c "ACTIVE" "$INVENTORY_DOC" || echo 0)
  echo "Active Mereka-wired slots: $ACTIVE_SLOTS"

  if [[ $ACTIVE_SLOTS -ge 1 ]]; then
    pass "At least 1 slot actively wired (footer)"
  else
    fail "No active slots found (expected footer slot)"
  fi
fi

# ---------------------------------------------------------------------------
# Check 6: Verify footer slot implementation is testable
# ---------------------------------------------------------------------------
FOOTER_VERIFY="scripts/qa/verify-mfe-footer-slot.sh"

if [[ -f "$FOOTER_VERIFY" ]]; then
  pass "Footer slot verification script exists at $FOOTER_VERIFY"

  if [[ -x "$FOOTER_VERIFY" ]]; then
    pass "Footer slot verification script is executable"
  else
    warn "Footer slot verification script is not executable"
  fi
else
  warn "Footer slot verification script not found (optional)"
fi

# ---------------------------------------------------------------------------
# Check 7: Migration roadmap exists in policy doc
# ---------------------------------------------------------------------------
if [[ -f "$POLICY_DOC" ]]; then
  if grep -q "Slot-Wirable Customizations" "$POLICY_DOC" || \
     grep -q "Migration Path" "$POLICY_DOC"; then
    pass "Migration roadmap documented in $POLICY_DOC"
  else
    warn "Migration roadmap section missing in $POLICY_DOC"
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${YELLOW}WARN:${NC} $WARN | ${RED}FAIL:${NC} $FAIL"

if [[ $FAIL -gt 0 ]]; then
  exit 1
else
  exit 0
fi
