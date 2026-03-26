#!/usr/bin/env bash
# verify-mfe-header-branding.sh — Verify MFE header logo plugin-slot wiring (Phase 1)
#
# @covers AC-SLOT-001, AC-SLOT-002, AC-SLOT-003, AC-SLOT-004, AC-SLOT-007, AC-SLOT-016, AC-SLOT-017, AC-SLOT-018
# @spec: mfe-plugin-slots_spec
#
# Checks that the MerekaHeaderLogo component and header logo slot registration are
# correctly wired in the Tutor plugin. Runs without cluster access (source-only checks).
#
# Usage: ./scripts/qa/verify-mfe-header-branding.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"

PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"
PLUGIN_BUNDLE=""
PLUGIN_FILE="$PLUGIN_MAIN"

PASS=0
FAIL=0
WARN=0

if mereka_plugin_has_any "$REPO_ROOT"; then
  PLUGIN_BUNDLE="$(mktemp -t mereka-header-branding-check.XXXXXX)"
  while IFS= read -r plugin_file; do
    cat "$plugin_file" >>"$PLUGIN_BUNDLE"
    printf '\n' >>"$PLUGIN_BUNDLE"
  done < <(mereka_plugin_contract_files "$REPO_ROOT")
  PLUGIN_FILE="$PLUGIN_BUNDLE"
fi

cleanup() {
  if [[ -n "$PLUGIN_BUNDLE" && -f "$PLUGIN_BUNDLE" ]]; then
    rm -f "$PLUGIN_BUNDLE"
  fi
}
trap cleanup EXIT

do_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
do_warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

echo "=== MFE Header Branding Plugin-Slot Check (Phase 1) ==="
echo ""

# ── Plugin file existence ─────────────────────────────────────────────────────
echo "--- Plugin Source ---"
if [[ -f "$PLUGIN_FILE" ]]; then
  do_pass "Plugin source bundle assembled"
else
  do_fail "Plugin source not found"
  echo ""
  echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="
  exit 1
fi

# ── Slot registration (AC-SLOT-007, AC-SLOT-016) ─────────────────────────────
echo ""
echo "--- Header Logo Slot Registration ---"

HEADER_LOGO_SLOT="org.openedx.frontend.layout.header_logo.v1"
if grep -qF "$HEADER_LOGO_SLOT" "$PLUGIN_FILE"; then
  do_pass "Header logo slot registered: $HEADER_LOGO_SLOT"
else
  do_fail "Header logo slot missing: $HEADER_LOGO_SLOT"
fi

if grep -qF "mereka_header_logo" "$PLUGIN_FILE"; then
  do_pass "Header logo widget ID present: mereka_header_logo"
else
  do_fail "Header logo widget ID missing: mereka_header_logo"
fi

# Header logo replacement must use the supported Hide+Insert pattern.
if grep -qF "org.openedx.frontend.layout.header_logo.v1" "$PLUGIN_FILE" && \
   grep -qF "PLUGIN_OPERATIONS.Hide" "$PLUGIN_FILE" && \
   grep -qF "widgetId: 'default_contents'" "$PLUGIN_FILE" && \
   grep -qF "mereka_header_logo" "$PLUGIN_FILE"; then
  do_pass "Header logo slot uses supported Hide+Insert replacement pattern"
else
  do_fail "Header logo slot must use Hide+Insert replacement pattern"
fi

# PLUGIN_SLOTS API must be imported (AC-SLOT-016)
if grep -q "from tutormfe.hooks import PLUGIN_SLOTS\|PLUGIN_SLOTS" "$PLUGIN_FILE"; then
  do_pass "PLUGIN_SLOTS API present in plugin (AC-SLOT-016)"
else
  do_fail "PLUGIN_SLOTS API missing — registration pattern not followed (AC-SLOT-016)"
fi

# ── MerekaHeaderLogo component (AC-SLOT-001, AC-SLOT-002, AC-SLOT-017) ───────
echo ""
echo "--- MerekaHeaderLogo Component Definition ---"

if grep -qF "const MerekaHeaderLogo" "$PLUGIN_FILE"; then
  do_pass "MerekaHeaderLogo component defined (AC-SLOT-001, AC-SLOT-017)"
else
  do_fail "MerekaHeaderLogo component missing — must be defined inline in plugin (AC-SLOT-017)"
fi

# Desktop logo: logoUrl from variant (AC-SLOT-001)
if grep -qF "variant.logoUrl" "$PLUGIN_FILE"; then
  do_pass "Desktop logo uses variant.logoUrl from SITE_VARIANTS (AC-SLOT-001)"
else
  do_fail "Desktop logo variant.logoUrl reference missing (AC-SLOT-001)"
fi

# Mobile logo: mobileLogoUrl via viewport guard (AC-SLOT-002)
if grep -qF "mobileLogoUrl" "$PLUGIN_FILE" && grep -qF "isMobileViewport" "$PLUGIN_FILE"; then
  do_pass "Mobile logo uses mobileLogoUrl with viewport guard (AC-SLOT-002)"
else
  do_fail "Mobile logo selection logic missing — must check mobileLogoUrl + isMobileViewport (AC-SLOT-002)"
fi

if grep -qF "window.matchMedia('(max-width: 767px)').matches" "$PLUGIN_FILE"; then
  do_pass "Mobile viewport breakpoint: 767px media query present"
else
  do_fail "Mobile viewport breakpoint missing — expected window.matchMedia('(max-width: 767px)').matches"
fi

if grep -qF "selectedLogo = isMobileViewport && variant.mobileLogoUrl ? variant.mobileLogoUrl : variant.logoUrl" "$PLUGIN_FILE"; then
  do_pass "Mobile/desktop logo selection: conditional assignment present"
else
  do_fail "Mobile/desktop logo selection conditional missing"
fi

# ── Logo click → dashboard navigation (AC-SLOT-003) ─────────────────────────
echo ""
echo "--- Logo Click Navigation (AC-SLOT-003) ---"

if grep -qF "getLogoHref" "$PLUGIN_FILE"; then
  do_pass "getLogoHref helper used for logo click href (AC-SLOT-003)"
else
  do_fail "getLogoHref helper missing — logo must navigate to /learner-dashboard/ (AC-SLOT-003)"
fi

if grep -qF "const getLearnerHomeHref = () => '/learner-dashboard/';" "$PLUGIN_FILE" || \
   grep -qF "return '/learner-dashboard/';" "$PLUGIN_FILE"; then
  do_pass "Logo href resolves to canonical learner home"
else
  do_fail "Learner-home href resolution logic missing — expected canonical /learner-dashboard/"
fi

if grep -qF "aria-label=" "$PLUGIN_FILE"; then
  do_pass "Logo anchor has aria-label attribute (accessibility)"
else
  do_warn "Logo anchor aria-label not found — check WCAG keyboard/screen-reader compliance"
fi

# ── Multi-site SITE_VARIANTS (AC-SLOT-004, AC-SLOT-018) ─────────────────────
echo ""
echo "--- Multi-Site Tenant Branding (AC-SLOT-004, AC-SLOT-018) ---"

if grep -qF "const MEREKA_SITE_VARIANTS = {" "$PLUGIN_FILE"; then
  do_pass "MEREKA_SITE_VARIANTS tenant map defined (AC-SLOT-018)"
else
  do_fail "MEREKA_SITE_VARIANTS missing — header logo must use hostname lookup (AC-SLOT-018)"
fi

if grep -qF "'academyv2.mereka.io'" "$PLUGIN_FILE"; then
  do_pass "Tenant: academyv2.mereka.io configured"
else
  do_fail "Tenant: academyv2.mereka.io missing from SITE_VARIANTS"
fi

if grep -qF "'academy.biji-biji.com'" "$PLUGIN_FILE"; then
  do_pass "Tenant: academy.biji-biji.com configured (AC-SLOT-004)"
else
  do_fail "Tenant: academy.biji-biji.com missing — multi-site logo variant required (AC-SLOT-004)"
fi

if grep -qF "'skillourfuture.academy.mereka.io'" "$PLUGIN_FILE"; then
  do_pass "Tenant: skillourfuture.academy.mereka.io configured"
else
  do_fail "Tenant: skillourfuture.academy.mereka.io missing from SITE_VARIANTS"
fi

if grep -qF "getMerekaVariant" "$PLUGIN_FILE"; then
  do_pass "getMerekaVariant runtime hostname lookup function present"
else
  do_fail "getMerekaVariant missing — header logo must perform hostname lookup"
fi

if grep -qF "normalizeHostname" "$PLUGIN_FILE"; then
  do_pass "normalizeHostname helper strips www. prefix for robust matching"
else
  do_warn "normalizeHostname helper missing — may fail on www. prefixed hostnames"
fi

# ── Logo asset paths (AC-SLOT-028 dependency) ────────────────────────────────
echo ""
echo "--- Logo Asset Paths ---"

if grep -qF "logoUrl: '/theme/logo-horizontal.svg'" "$PLUGIN_FILE"; then
  do_pass "Desktop logo base path: /theme/logo-horizontal.svg"
else
  do_fail "Desktop logo base path missing — expected /theme/logo-horizontal.svg"
fi

if grep -qF "mobileLogoUrl: '/theme/logo.svg'" "$PLUGIN_FILE"; then
  do_pass "Mobile logo base path: /theme/logo.svg"
else
  do_fail "Mobile logo base path missing — expected /theme/logo.svg"
fi

# LMS_BASE_URL prefix on asset path (avoids 404 on sub-path deployments)
if grep -qF "baseUrl ? \`\${baseUrl}\${selectedLogo}\` : selectedLogo" "$PLUGIN_FILE"; then
  do_pass "Logo src includes LMS_BASE_URL prefix for sub-path deployments"
else
  do_fail "Logo src missing LMS_BASE_URL prefix — may cause 404 on sub-path deployments"
fi

# ── CSS class convention (AC-SLOT-017) ───────────────────────────────────────
echo ""
echo "--- CSS Class Convention ---"

if grep -qF "className=\"mereka-header-logo\"" "$PLUGIN_FILE"; then
  do_pass "Header logo anchor uses mereka-header-logo CSS class"
else
  do_fail "Header logo CSS class missing — expected mereka-header-logo (AC-SLOT-017)"
fi

# ── Menu slot registrations (Phase 1 AC-SLOT-005, AC-SLOT-006) ───────────────
echo ""
echo "--- Header Navigation Menu Slots (AC-SLOT-005, AC-SLOT-006) ---"

DESKTOP_MENU_SLOT="org.openedx.frontend.layout.header_desktop_main_menu.v1"
MOBILE_MENU_SLOT="org.openedx.frontend.layout.header_mobile_main_menu.v1"

if grep -qF "$DESKTOP_MENU_SLOT" "$PLUGIN_FILE"; then
  do_pass "Desktop main menu slot registered: $DESKTOP_MENU_SLOT (AC-SLOT-005)"
else
  do_fail "Desktop main menu slot missing: $DESKTOP_MENU_SLOT (AC-SLOT-005)"
fi

if grep -qF "$MOBILE_MENU_SLOT" "$PLUGIN_FILE"; then
  do_pass "Mobile main menu slot registered: $MOBILE_MENU_SLOT (AC-SLOT-006)"
else
  do_fail "Mobile main menu slot missing: $MOBILE_MENU_SLOT (AC-SLOT-006)"
fi

if grep -qF "content: 'Dashboard'" "$PLUGIN_FILE"; then
  do_pass "Menu wiring: Dashboard link present (AC-SLOT-005)"
else
  do_fail "Menu wiring: Dashboard link missing (AC-SLOT-005)"
fi

if grep -qF "content: 'Course Catalog'" "$PLUGIN_FILE"; then
  do_pass "Menu wiring: Course Catalog link present (AC-SLOT-005)"
else
  do_fail "Menu wiring: Course Catalog link missing (AC-SLOT-005)"
fi

if grep -qF "content: 'Support'" "$PLUGIN_FILE"; then
  do_pass "Menu wiring: Support link (from helpUrl) present (AC-SLOT-005)"
else
  do_fail "Menu wiring: Support link missing (AC-SLOT-005)"
fi

# Desktop and mobile menus should share the same helper (parity check — AC-SLOT-006)
if grep -qF "withMerekaMenuItems" "$PLUGIN_FILE"; then
  do_pass "Desktop/mobile menus share withMerekaMenuItems helper (AC-SLOT-006 parity)"
else
  do_fail "withMerekaMenuItems helper missing — desktop/mobile menus must share same items (AC-SLOT-006)"
fi

# ── FPF dependency (required for all slot activations) ───────────────────────
echo ""
echo "--- FPF Dependency ---"

if grep -qF "frontend-plugin-framework" "$PLUGIN_FILE"; then
  do_pass "frontend-plugin-framework dependency present in plugin"
else
  do_fail "frontend-plugin-framework not referenced in plugin"
fi

echo ""
echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
