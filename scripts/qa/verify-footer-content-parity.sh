#!/usr/bin/env bash
# verify-footer-content-parity.sh — Verify both footer renderers contain the same required content.
#
# @spec: branding-system_spec.md
# @covers AC-FTPAR-001: MFE footer component contains all required elements
# @covers AC-FTPAR-002: Django LMS Mako footer contains all required elements
# @covers AC-FTPAR-008: Both footers share the same content contract elements
#
# Reads both footer source files (MFE JS + Django Mako) and verifies they contain
# the same required elements: app badges, WhatsApp, social icons, copyright, legal links.
#
# Usage:
#   scripts/qa/verify-footer-content-parity.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

# NOTE: The shipped MFE runtime is assembled from split modules in mfe_runtime/.
# The monolith (mfe_runtime_definitions.js) is deprecated and may diverge.
# Footer component lives in the split module:
MFE_FOOTER="${REPO_ROOT}/infrastructure/tutor/plugins/_mereka_lms/mfe_runtime/footer.js"
DJANGO_FOOTER="${REPO_ROOT}/infrastructure/tutor/themes/mereka/lms/templates/footer.html"
# Footer content is now hardcoded in the Django Mako template (no separate data-contract file).
# Social links, app badge URLs, etc. are checked directly in the Django footer.

echo "=== Footer Content Parity Verifier ==="
echo ""

# -------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------

check_both() {
  local label="$1"
  local pattern="$2"
  local mfe_ok=0
  local django_ok=0

  if grep -qF "$pattern" "$MFE_FOOTER" 2>/dev/null; then
    mfe_ok=1
  fi
  if grep -qF "$pattern" "$DJANGO_FOOTER" 2>/dev/null; then
    django_ok=1
  fi

  if [[ $mfe_ok -eq 1 && $django_ok -eq 1 ]]; then
    pass "${label} present in both footers"
  elif [[ $mfe_ok -eq 1 && $django_ok -eq 0 ]]; then
    fail "${label} present in MFE but MISSING in Django footer"
  elif [[ $mfe_ok -eq 0 && $django_ok -eq 1 ]]; then
    fail "${label} present in Django but MISSING in MFE footer"
  else
    fail "${label} MISSING in both footers"
  fi
}

check_regex_both() {
  local label="$1"
  local pattern="$2"
  local mfe_ok=0
  local django_ok=0

  if grep -qE "$pattern" "$MFE_FOOTER" 2>/dev/null; then
    mfe_ok=1
  fi
  if grep -qE "$pattern" "$DJANGO_FOOTER" 2>/dev/null; then
    django_ok=1
  fi

  if [[ $mfe_ok -eq 1 && $django_ok -eq 1 ]]; then
    pass "${label} present in both footers"
  elif [[ $mfe_ok -eq 1 && $django_ok -eq 0 ]]; then
    fail "${label} present in MFE but MISSING in Django footer"
  elif [[ $mfe_ok -eq 0 && $django_ok -eq 1 ]]; then
    fail "${label} present in Django but MISSING in MFE footer"
  else
    fail "${label} MISSING in both footers"
  fi
}

# -------------------------------------------------------------------
# Pre-flight: source files exist
# -------------------------------------------------------------------
echo "--- Pre-flight ---"

if [[ -f "$MFE_FOOTER" ]]; then
  pass "MFE footer source exists"
else
  fail "MFE footer source missing: ${MFE_FOOTER}"
fi

if [[ -f "$DJANGO_FOOTER" ]]; then
  pass "Django footer source exists"
else
  fail "Django footer source missing: ${DJANGO_FOOTER}"
fi

# -------------------------------------------------------------------
# CSS class structure: both use mereka-footer--v2
# -------------------------------------------------------------------
echo ""
echo "--- CSS class structure ---"

check_both "mereka-footer--v2 class" "mereka-footer--v2"
check_both "footer-social zone" "footer-social"
check_both "footer-nav zone" "footer-nav"
check_both "footer-body zone" "footer-body"
check_both "footer-legal zone" "footer-legal"
check_both "footer-columns grid" "footer-columns"

# -------------------------------------------------------------------
# App Store / Google Play badges
# -------------------------------------------------------------------
echo ""
echo "--- App store badges ---"

# Badge URLs are hardcoded in the Django footer; MFE reads from runtime config.
if grep -qF "play.google.com/store/apps" "$DJANGO_FOOTER" 2>/dev/null; then
  pass "Google Play badge URL in Django footer"
else
  fail "Google Play badge URL MISSING from Django footer"
fi

if grep -qF "apps.apple.com" "$DJANGO_FOOTER" 2>/dev/null; then
  pass "App Store badge URL in Django footer"
else
  fail "App Store badge URL MISSING from Django footer"
fi

check_regex_both "App badge rendering (appBadges loop)" "(appBadges|footer-badge)"
check_both "footer-badge class" "footer-badge"

# -------------------------------------------------------------------
# WhatsApp
# -------------------------------------------------------------------
echo ""
echo "--- WhatsApp ---"

check_both "WhatsApp link (wa.me)" "wa.me/"
check_both "WhatsApp button class" "footer-whatsapp-btn"
check_both "WhatsApp SVG icon path" "M.057 24l1.687-6.163"

# -------------------------------------------------------------------
# Social icons (check icon SVG paths in data contract + rendering in both)
# -------------------------------------------------------------------
echo ""
echo "--- Social icons ---"

# Django footer has all 5 social links hardcoded; MFE reads from config at runtime.
for platform in TikTok Instagram Facebook LinkedIn YouTube; do
  if grep -qF "\"name\": \"${platform}\"" "$DJANGO_FOOTER" 2>/dev/null; then
    pass "${platform} social link in Django footer"
  else
    fail "${platform} social link MISSING from Django footer"
  fi
done

# Both footers render social icons with SVG
check_both "Social icon SVG rendering" "viewBox=\"0 0 24 24\""
check_regex_both "Social link loop (MFE .map / Mako for)" "(socialLinks\\.map|for social_link in)"

# -------------------------------------------------------------------
# Copyright
# -------------------------------------------------------------------
echo ""
echo "--- Copyright ---"

check_both "Copyright symbol" "footer-copyright"
check_regex_both "Dynamic year" "(currentYear|datetime\\.now\\(\\)\\.year|getFullYear)"

# -------------------------------------------------------------------
# Legal links
# -------------------------------------------------------------------
echo ""
echo "--- Legal links ---"

check_regex_both "Terms of Use link" "(termsLabel|TERMS OF USE)"
check_regex_both "Privacy Policy link" "(privacyLabel|PRIVACY POLICY)"
check_regex_both "Cookies Policy link" "(cookiesLabel|COOKIES POLICY)"

# -------------------------------------------------------------------
# Support / contact
# -------------------------------------------------------------------
echo ""
echo "--- Support & contact ---"

check_regex_both "Help Centre link" "(helpLabel|Help Centre)"
check_regex_both "Contact Support link" "(contactSupportLabel|Contact Support)"
check_regex_both "Support email reference" "(supportEmail|support_email|mailto:)"

# -------------------------------------------------------------------
# 4-column sections
# -------------------------------------------------------------------
echo ""
echo "--- Column sections ---"

check_regex_both "Corporate column" "(corporate|Corporate)"
check_regex_both "Marketplace column" "(marketplace|Marketplace)"
check_regex_both "Academy column" "(academy|Academy)"
check_regex_both "Space column" "(space|Space)"
check_both "Become a Hub CTA" "footer-cta-btn"
check_regex_both "App badges container" "footer-app-badges"

# -------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------
echo ""
echo "=== Results: ${PASS} PASS / ${FAIL} FAIL ==="

if [[ $FAIL -gt 0 ]]; then
  echo "RESULT: FAIL"
  exit 1
fi

echo "RESULT: PASS"
exit 0
