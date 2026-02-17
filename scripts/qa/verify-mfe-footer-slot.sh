#!/usr/bin/env bash
# verify-mfe-footer-slot.sh — Verify MFE footer plugin-slot wiring is correct
#
# Checks that the MerekaFooter component is properly defined in the Tutor
# plugin and that the slot wiring (either PLUGIN_SLOTS or apply-patches.sh
# fallback) is in place. Runs without cluster access.
#
# Usage: ./scripts/qa/verify-mfe-footer-slot.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PLUGIN="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
PATCHES="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"

PASS=0
FAIL=0
WARN=0

do_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
do_warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

echo "=== MFE Footer Plugin-Slot Wiring Check ==="
echo ""

# 1. Plugin file exists
echo "--- Plugin Source ---"
if [ -f "$PLUGIN" ]; then
  do_pass "mereka_lms.py exists"
else
  do_fail "mereka_lms.py not found"
  echo ""
  echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="
  exit 1
fi

# 2. MerekaFooter component defined in mfe-env-config patch
if grep -q 'const MerekaFooter' "$PLUGIN"; then
  do_pass "MerekaFooter component defined in plugin"
else
  do_fail "MerekaFooter component missing from plugin mfe-env-config patch"
fi

# 3. Plugin imports mereka.scss
if grep -q "mereka/mereka.scss" "$PLUGIN"; then
  do_pass "Mereka SCSS import present in plugin"
else
  do_fail "Mereka SCSS import missing from plugin"
fi

# 4. Footer component has required content
echo ""
echo "--- Footer Component Content ---"

if grep -q 'role="contentinfo"' "$PLUGIN"; then
  do_pass "Footer has ARIA role=contentinfo"
else
  do_fail "Footer missing ARIA role=contentinfo"
fi

if grep -q 'mereka-footer' "$PLUGIN"; then
  do_pass "Footer uses mereka-footer CSS class"
else
  do_fail "Footer missing mereka-footer CSS class"
fi

if grep -q 'team@mereka.io' "$PLUGIN"; then
  do_pass "Footer includes team contact email"
else
  do_fail "Footer missing team contact email"
fi

if grep -q 'Biji-Biji Initiative' "$PLUGIN"; then
  do_pass "Footer includes partner attribution"
else
  do_fail "Footer missing partner attribution"
fi

if grep -q 'Open edX' "$PLUGIN"; then
  do_pass "Footer includes Open edX credit"
else
  do_fail "Footer missing Open edX credit"
fi

# 5. Plugin-slot forward-compatible registration
echo ""
echo "--- Plugin-Slot Registration ---"

if grep -q 'PLUGIN_SLOTS' "$PLUGIN"; then
  do_pass "PLUGIN_SLOTS registration present (forward-compatible)"
else
  do_fail "PLUGIN_SLOTS registration missing from plugin"
fi

if grep -q 'footer_slot' "$PLUGIN"; then
  do_pass "footer_slot target defined"
else
  do_fail "footer_slot target missing"
fi

if grep -q 'DIRECT_PLUGIN' "$PLUGIN"; then
  do_pass "Direct plugin type specified (not iFrame)"
else
  do_fail "Direct plugin type not specified"
fi

if grep -q '_PLUGIN_SLOTS_AVAILABLE' "$PLUGIN"; then
  do_pass "Fallback flag (_PLUGIN_SLOTS_AVAILABLE) defined"
else
  do_warn "Fallback flag not found — cannot detect slot availability"
fi

# 6. Fallback wiring in apply-patches.sh
echo ""
echo "--- Fallback Wiring (apply-patches.sh) ---"

if [ -f "$PATCHES" ]; then
  do_pass "apply-patches.sh exists"

  if grep -q 'RenderWidget.*MerekaFooter' "$PATCHES"; then
    do_pass "apply-patches.sh has RenderWidget→MerekaFooter fallback"
  else
    do_fail "apply-patches.sh missing RenderWidget→MerekaFooter fallback"
  fi

  if grep -q 'const MerekaFooter' "$PATCHES"; then
    do_pass "apply-patches.sh has MerekaFooter definition (defense-in-depth)"
  else
    do_warn "apply-patches.sh missing MerekaFooter definition backup"
  fi
else
  do_fail "apply-patches.sh not found"
fi

# 7. FPF dependency in MFE build
echo ""
echo "--- FPF Dependency ---"

if grep -q 'frontend-plugin-framework' "$PLUGIN"; then
  do_pass "frontend-plugin-framework installed in MFE build"
else
  do_fail "frontend-plugin-framework not installed in MFE build"
fi

echo ""
echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
