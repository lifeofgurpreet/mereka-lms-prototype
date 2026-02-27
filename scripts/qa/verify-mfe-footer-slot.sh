#!/usr/bin/env bash
# verify-mfe-footer-slot.sh — Verify MFE footer plugin-slot wiring is correct
#
# Checks that the MerekaFooter component is properly defined in the Tutor
# plugin and that the active slot wiring path is in place. Runs without cluster access.
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

if grep -q 'Biji-Biji Initiative' "$PLUGIN"; then
  do_pass "Footer includes partner attribution (Biji-Biji Initiative)"
else
  do_fail "Footer missing partner attribution"
fi

# v2 structural zones
echo ""
echo "--- Footer v2 Structural Zones ---"

if grep -q 'footer-social' "$PLUGIN"; then
  do_pass "v2 Zone 1: Social row present"
else
  do_fail "v2 Zone 1: Social row missing (footer-social)"
fi

if grep -q 'footer-nav' "$PLUGIN"; then
  do_pass "v2 Zone 2: Nav strip present"
else
  do_fail "v2 Zone 2: Nav strip missing (footer-nav)"
fi

if grep -q 'footer-body' "$PLUGIN"; then
  do_pass "v2 Zone 3: Column body present"
else
  do_fail "v2 Zone 3: Column body missing (footer-body)"
fi

if grep -q 'footer-legal' "$PLUGIN"; then
  do_pass "v2 Zone 4: Legal bottom present"
else
  do_fail "v2 Zone 4: Legal bottom missing (footer-legal)"
fi

# Critical links
if grep -q 'corporate.mereka.io' "$PLUGIN"; then
  do_pass "Corporate links present"
else
  do_fail "Corporate links missing"
fi

if grep -q 'legal.mereka.io' "$PLUGIN"; then
  do_pass "Legal links present (terms, privacy, cookies)"
else
  do_fail "Legal links missing"
fi

if grep -q 'wa.me' "$PLUGIN"; then
  do_pass "WhatsApp CTA present"
else
  do_fail "WhatsApp CTA missing"
fi

# Per-site variant mapping
if grep -q 'SITE_VARIANTS' "$PLUGIN"; then
  do_pass "Per-site variant mapping present (AC-FOOTER-203)"
else
  do_fail "Per-site variant mapping missing (AC-FOOTER-203)"
fi

if grep -q 'academy.biji-biji.com' "$PLUGIN"; then
  do_pass "Biji-Biji domain variant configured"
else
  do_fail "Biji-Biji domain variant missing"
fi

if grep -q 'skillourfuture' "$PLUGIN"; then
  do_pass "Skill Our Future domain variant configured"
else
  do_fail "Skill Our Future domain variant missing"
fi

# App store badges (AC-FOOTER-204: no hotlinks)
if grep -q 'apps.apple.com' "$PLUGIN"; then
  do_pass "App Store link present"
else
  do_warn "App Store link not found"
fi

if grep -q 'play.google.com' "$PLUGIN"; then
  do_pass "Google Play link present"
else
  do_warn "Google Play link not found"
fi

# WCAG: verify no hotlinked badge images
if grep -q 'developer.apple.com/assets' "$PLUGIN"; then
  do_fail "Hotlinked Apple badge image found (AC-FOOTER-204 violation)"
else
  do_pass "No hotlinked Apple badge (AC-FOOTER-204)"
fi

if grep -q 'upload.wikimedia.org' "$PLUGIN"; then
  do_fail "Hotlinked Google badge image found (AC-FOOTER-204 violation)"
else
  do_pass "No hotlinked Google badge (AC-FOOTER-204)"
fi

# 5. Plugin-slot forward-compatible registration
echo ""
echo "--- Plugin-Slot Registration ---"

if grep -q 'PLUGIN_SLOTS' "$PLUGIN"; then
  do_pass "PLUGIN_SLOTS registration present (forward-compatible)"
else
  do_fail "PLUGIN_SLOTS registration missing from plugin"
fi

if grep -q '"org.openedx.frontend.layout.footer.v1"' "$PLUGIN"; then
  do_pass "Namespaced footer slot target defined"
else
  do_fail "Namespaced footer slot target missing"
fi

if grep -q 'DIRECT_PLUGIN' "$PLUGIN"; then
  do_pass "Direct plugin type specified (not iFrame)"
else
  do_fail "Direct plugin type not specified"
fi

if grep -q '_PLUGIN_SLOTS_AVAILABLE' "$PLUGIN"; then
  do_warn "Legacy fallback detection flag still present"
fi

# 6. Fallback wiring in apply-patches.sh
echo ""
echo "--- Fallback Wiring (apply-patches.sh) ---"

if [ -f "$PATCHES" ]; then
  do_pass "apply-patches.sh exists"

  if grep -q 'RenderWidget.*MerekaFooter' "$PATCHES"; then
    do_warn "Legacy RenderWidget→MerekaFooter fallback is present in apply-patches.sh"
  else
    do_pass "No RenderWidget→MerekaFooter fallback in apply-patches.sh (active path is plugin-driven)"
  fi

  if grep -q 'const MerekaFooter' "$PATCHES"; then
    do_warn "Legacy MerekaFooter backup still exists in apply-patches.sh"
  else
    do_pass "No legacy MerekaFooter backup in apply-patches.sh (plugin-only path)"
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

# Fallback sync check
echo ""
echo "--- Dual-Path Sync Check ---"

if grep -q 'SITE_VARIANTS' "$PATCHES"; then
  do_warn "Legacy SITE_VARIANTS appears in apply-patches.sh"
else
  do_pass "SITE_VARIANTS is plugin-scoped (no duplicate literal fallback in patches)"
fi

if grep -q 'footer-social' "$PATCHES" && grep -q 'footer-nav' "$PATCHES"; then
  do_warn "Legacy v2 zone structure exists in apply-patches.sh"
else
  do_pass "Footer v2 zone structure is plugin-scoped (no duplicate path in apply-patches.sh)"
fi

echo ""
echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
