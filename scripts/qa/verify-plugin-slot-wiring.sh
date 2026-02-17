#!/usr/bin/env bash
# verify-plugin-slot-wiring.sh — Comprehensive FPF plugin-slot wiring verification
#
# Validates that the Mereka plugin-slot configuration chain is consistent:
#   mereka_lms.py → apply-patches.sh → env.config.jsx → MFE runtime
#
# This script verifies SOURCE INTEGRITY only (no cluster access needed).
#
# Usage: ./scripts/qa/verify-plugin-slot-wiring.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PLUGIN="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
PATCHES="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
INVENTORY="$REPO_ROOT/docs/architecture/MFE_PLUGIN_SLOT_INVENTORY.md"
ADR014="$REPO_ROOT/docs/adr/014-mfe-branding-strategy.md"

PASS=0
FAIL=0
WARN=0

do_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
do_warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

echo "=== Plugin-Slot Wiring Integrity Check ==="
echo ""

# ── 1. Source files exist ──────────────────────────────────────────────
echo "--- Source file existence ---"
for f in "$PLUGIN" "$PATCHES" "$INVENTORY" "$ADR014"; do
  basename=$(basename "$f")
  if [ -f "$f" ]; then
    do_pass "$basename exists"
  else
    do_fail "$basename not found at $f"
  fi
done

# ── 2. Plugin: slot registration chain ────────────────────────────────
echo ""
echo "--- Plugin slot registration (mereka_lms.py) ---"

# 2a. Forward-compatible PLUGIN_SLOTS registration
if grep -q 'from tutormfe.hooks import PLUGIN_SLOTS' "$PLUGIN"; then
  do_pass "PLUGIN_SLOTS import present (forward-compatible)"
else
  do_fail "PLUGIN_SLOTS import missing"
fi

if grep -q 'PLUGIN_SLOTS.add_item' "$PLUGIN"; then
  do_pass "PLUGIN_SLOTS.add_item call present"
else
  do_fail "PLUGIN_SLOTS.add_item call missing"
fi

# 2b. footer_slot is the registered target
if grep -q '"footer_slot"' "$PLUGIN"; then
  do_pass "footer_slot registered as slot target"
else
  do_fail "footer_slot not found in PLUGIN_SLOTS registration"
fi

# 2c. Fallback flag pattern
if grep -q '_PLUGIN_SLOTS_AVAILABLE' "$PLUGIN"; then
  do_pass "Fallback detection flag (_PLUGIN_SLOTS_AVAILABLE) defined"
else
  do_warn "Fallback detection flag missing"
fi

# 2d. try/except guard for ImportError
if grep -q 'except ImportError' "$PLUGIN"; then
  do_pass "ImportError guard for PLUGIN_SLOTS (graceful fallback)"
else
  do_fail "Missing ImportError guard — will crash on Tutor versions without PLUGIN_SLOTS"
fi

# ── 3. Plugin: MerekaFooter component ─────────────────────────────────
echo ""
echo "--- MerekaFooter component (mereka_lms.py) ---"

if grep -q 'const MerekaFooter' "$PLUGIN"; then
  do_pass "MerekaFooter component defined in plugin"
else
  do_fail "MerekaFooter component missing from plugin"
fi

if grep -q 'DIRECT_PLUGIN' "$PLUGIN"; then
  do_pass "Direct plugin type specified (performance: no iframe overhead)"
else
  do_fail "Direct plugin type not specified"
fi

if grep -q 'PLUGIN_OPERATIONS' "$PLUGIN"; then
  do_pass "PLUGIN_OPERATIONS referenced (Replace/Insert/Hide)"
else
  do_fail "PLUGIN_OPERATIONS not referenced"
fi

# 3a. Footer semantic content
for check in 'role="contentinfo"' 'mereka-footer' 'team@mereka.io'; do
  if grep -q "$check" "$PLUGIN"; then
    do_pass "Footer contains '$check'"
  else
    do_fail "Footer missing '$check'"
  fi
done

# ── 4. Patch chain: apply-patches.sh ──────────────────────────────────
echo ""
echo "--- Patch chain (apply-patches.sh) ---"

# 4a. env.config.jsx patching
if grep -q 'env.config.jsx' "$PATCHES"; then
  do_pass "apply-patches.sh targets env.config.jsx"
else
  do_fail "apply-patches.sh does not reference env.config.jsx"
fi

# 4b. RenderWidget replacement (defense-in-depth)
if grep -q 'RenderWidget.*MerekaFooter' "$PATCHES"; then
  do_pass "RenderWidget→MerekaFooter fallback in apply-patches.sh"
else
  do_fail "RenderWidget→MerekaFooter fallback missing"
fi

# 4c. MerekaFooter backup definition in patches
if grep -q 'const MerekaFooter' "$PATCHES"; then
  do_pass "MerekaFooter defined in apply-patches.sh (defense-in-depth)"
else
  do_warn "MerekaFooter not defined in apply-patches.sh (single-source risk)"
fi

# 4d. SCSS theme import injection
if grep -q 'mereka/mereka.scss' "$PATCHES"; then
  do_pass "SCSS theme import (mereka.scss) present in patch chain"
else
  do_fail "SCSS theme import missing from patch chain"
fi

# 4e. FPF framework import
if grep -q 'frontend-plugin-framework' "$PATCHES" || grep -q 'frontend-plugin-framework' "$PLUGIN"; then
  do_pass "frontend-plugin-framework dependency referenced"
else
  do_fail "frontend-plugin-framework dependency not found in plugin or patches"
fi

# ── 5. Consistency: plugin ↔ patches ──────────────────────────────────
echo ""
echo "--- Consistency checks ---"

# 5a. Both sources define the same component name
PLUGIN_FOOTER=$(grep -o 'const [A-Z][a-zA-Z]*Footer' "$PLUGIN" | head -1 || true)
PATCHES_FOOTER=$(grep -o 'const [A-Z][a-zA-Z]*Footer' "$PATCHES" | head -1 || true)

if [ -n "$PLUGIN_FOOTER" ] && [ -n "$PATCHES_FOOTER" ]; then
  if [ "$PLUGIN_FOOTER" = "$PATCHES_FOOTER" ]; then
    do_pass "Plugin and patches define same footer component ($PLUGIN_FOOTER)"
  else
    do_fail "Footer component name mismatch: plugin=$PLUGIN_FOOTER, patches=$PATCHES_FOOTER"
  fi
elif [ -n "$PLUGIN_FOOTER" ]; then
  do_pass "Footer component defined in plugin ($PLUGIN_FOOTER)"
else
  do_fail "No footer component found in either source"
fi

# 5b. Indigo footer import removal (prevents duplicate footers)
if grep -q "import Footer from '@edly-io/indigo-frontend-component-footer'" "$PATCHES"; then
  # The patches should REMOVE this import, not add it
  if grep -q "replace.*import Footer.*''" "$PATCHES" || grep -q 'updated.replace.*import Footer' "$PATCHES"; then
    do_pass "Indigo footer import stripped in patches (prevents duplicate)"
  else
    do_warn "Indigo footer import referenced but removal unclear"
  fi
else
  do_pass "No raw Indigo footer import in patches (clean)"
fi

# ── 6. Inventory document consistency ─────────────────────────────────
echo ""
echo "--- Inventory document consistency ---"

if [ -f "$INVENTORY" ]; then
  # 6a. Inventory mentions footer as ACTIVE
  if grep -q 'ACTIVE.*MerekaFooter\|MerekaFooter.*ACTIVE' "$INVENTORY"; then
    do_pass "Inventory marks footer slot as ACTIVE"
  else
    do_fail "Inventory does not mark footer slot as ACTIVE"
  fi

  # 6b. Inventory references the correct slot ID
  if grep -q 'org.openedx.frontend.layout.footer.v1' "$INVENTORY"; then
    do_pass "Inventory references namespaced footer slot ID"
  else
    do_fail "Inventory missing namespaced footer slot ID"
  fi

  # 6c. Inventory has migration map
  if grep -q '## 4\. Migration Map' "$INVENTORY"; then
    do_pass "Inventory includes migration map"
  else
    do_warn "Inventory missing migration map section"
  fi

  # 6d. Inventory cross-references ADR-014
  if grep -q 'ADR-014\|014-mfe-branding-strategy' "$INVENTORY"; then
    do_pass "Inventory cross-references ADR-014"
  else
    do_warn "Inventory missing ADR-014 cross-reference"
  fi
fi

# ── 7. ADR-014 consistency ────────────────────────────────────────────
echo ""
echo "--- ADR-014 slot table consistency ---"

if [ -f "$ADR014" ]; then
  # 7a. ADR references inventory
  if grep -q 'MFE_PLUGIN_SLOT_INVENTORY' "$ADR014"; then
    do_pass "ADR-014 references plugin-slot inventory"
  else
    do_fail "ADR-014 missing reference to plugin-slot inventory"
  fi

  # 7b. ADR uses namespaced IDs
  if grep -q 'org.openedx.frontend.layout.footer.v1' "$ADR014"; then
    do_pass "ADR-014 uses namespaced slot IDs"
  else
    do_warn "ADR-014 missing namespaced slot IDs"
  fi
fi

echo ""
echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
