#!/usr/bin/env bash
# verify-plugin-slot-wiring.sh — Comprehensive FPF plugin-slot wiring verification
#
# Validates that the Mereka plugin-slot configuration chain is consistent:
#   mereka_lms.py → render-time MFE env.config.jsx template values → runtime slots
#
# Usage: ./scripts/qa/verify-plugin-slot-wiring.sh
set -euo pipefail

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

if grep -q 'PLUGIN_SLOTS.add_items\|PLUGIN_SLOTS.add_item' "$PLUGIN"; then
  do_pass "PLUGIN_SLOTS registration call present (add_item or add_items)"
else
  do_fail "No PLUGIN_SLOTS add_item/add_items registration found"
fi

# 2b. Canonical slot IDs are registered
if grep -q '"org.openedx.frontend.layout.footer.v1"' "$PLUGIN"; then
  do_pass "Footer slot registered as footer.v1"
else
  do_fail "Footer canonical slot not found in PLUGIN_SLOTS registration"
fi

if grep -q '"org.openedx.frontend.layout.header_logo.v1"' "$PLUGIN"; then
  do_pass "Header logo slot registered as header_logo.v1"
else
  do_fail "Header logo canonical slot not found in PLUGIN_SLOTS registration"
fi

# learner_dashboard.widget_sidebar.v1 is a planned learner-dashboard widget slot.
# Warn when absent so the script remains accurate while acknowledging
# implementation scope.
if grep -q '"org.openedx.frontend.learner_dashboard.widget_sidebar.v1"' "$PLUGIN"; then
  do_pass "Learner-dashboard slot registered as org.openedx.frontend.learner_dashboard.widget_sidebar.v1"
else
  do_warn "org.openedx.frontend.learner_dashboard.widget_sidebar.v1 slot not yet registered in mereka_lms.py"
fi

# 2c. Plugin defines runtime helper components used by slot registrations
if grep -q 'const MerekaHeaderLogo' "$PLUGIN"; then
  do_pass "MerekaHeaderLogo component defined for header_logo slot"
else
  do_fail "MerekaHeaderLogo component missing"
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
for check in 'role="contentinfo"' 'mereka-footer' 'supportEmail'; do
  if grep -q "$check" "$PLUGIN"; then
    do_pass "Footer contains '$check'"
  else
    do_fail "Footer missing '$check'"
  fi
done

# ── 4. Patch chain: apply-patches.sh ──────────────────────────────────
echo ""
echo "--- Patch chain (apply-patches.sh) ---"

# 4a. Slot runtime definitions are in plugin, not patch file
if grep -q 'mfe-env-config-runtime-definitions' "$PLUGIN"; then
  do_pass "Slot component definitions are injected via plugin hooks"
else
  do_fail "Plugin runtime definition hook for slot components missing"
fi

# 4b. No string-surgery fallback remains in patches
if grep -q 'RenderWidget.*MerekaFooter\|RenderWidget: <Footer />' "$PATCHES"; then
  do_fail "String-surgery fallback still present in apply-patches.sh"
else
  do_pass "No RenderWidget→MerekaFooter string-surgery fallback in apply-patches.sh"
fi

# 4c. Single-source plugin definition (preferred path)
if grep -q 'const MerekaFooter' "$PATCHES"; then
  do_warn "MerekaFooter is still defined in apply-patches.sh (legacy fallback path)"
else
  do_pass "MerekaFooter intentionally defined only in plugin runtime definitions"
fi

# 4d. SCSS theme import injection is via plugin env-config patch
if grep -q "mfe-env-config-buildtime-imports" "$PLUGIN" && grep -q 'mereka/mereka.scss' "$PLUGIN"; then
  do_pass "mereka.scss import is injected via plugin env-config hook"
else
  do_fail "mereka.scss import not found in plugin env-config buildtime hook"
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
