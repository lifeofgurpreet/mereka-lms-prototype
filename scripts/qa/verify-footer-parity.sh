#!/usr/bin/env bash
# verify-footer-parity.sh — Verify Mereka v2 footer parity across LMS and MFEs.
#
# @spec: branding-system_spec.md
# @covers AC-003, AC-007, AC-008
# @covers AC-FTPAR-001: MFE footer component exists with SITE_VARIANTS
# @covers AC-FTPAR-002: LMS Mako footer template exists and contains Mereka branding
# @covers AC-FTPAR-003: Footer copyright fields present for all SITE_VARIANTS domains
# @covers AC-FTPAR-004: Enterprise MFE deployments reference footer/env config
# @covers AC-FTPAR-005: No "powered by Open edX" without Mereka co-branding in any footer
# @covers AC-FTPAR-007: Live footer class + section markers present on all 3 production domains (--live/--online)
# @covers AC-FTPAR-008: Tenant footer data contract fields present in SITE_VARIANTS + LMS footer
#
# Usage:
#   scripts/qa/verify-footer-parity.sh [--offline|--source-only] [--online] [--live] [--lms-url URL] [--mfe-url URL]
#
# Modes:
#   --offline / --source-only
#              (default) Check source files: plugin slot/runtime wiring, patch module
#              asset sync, env.config.jsx template, LMS theme template, branding assets.
#   --online   Live URL checks: curl LMS homepage, MFE app, verify footer links.
#   --live     Alias for --online (checks all three production domains directly).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../shared/config.sh" 2>/dev/null || true

PASS=0
FAIL=0
WARN=0
SKIP=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }
warn() { WARN=$((WARN + 1)); echo "  WARN: $1"; }
skip() { SKIP=$((SKIP + 1)); echo "  SKIP: $1"; }

# Parse flags
LIVE_MODE=0
LMS_URL="https://${LMS_DOMAIN:-academyv2.mereka.io}"
MFE_URL="https://${MFE_DOMAIN:-apps.academyv2.mereka.io}"
EXPLICIT_LIVE_URLS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --live|--online) LIVE_MODE=1; shift ;;
    --offline|--source-only)
                     shift ;;  # default, no-op
    --lms-url)       LMS_URL="$2"; EXPLICIT_LIVE_URLS=1; shift 2 ;;
    --mfe-url)       MFE_URL="$2"; EXPLICIT_LIVE_URLS=1; shift 2 ;;
    -h|--help)
      sed -n '3,20p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"
PLUGIN_BUNDLE=""
PLUGIN="$PLUGIN_MAIN"
FOOTER_PATCH="$REPO_ROOT/infrastructure/tutor/patches/footer-component.sh"
APPLY_PATCHES="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
MEREKA_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss"
MFE_INDIGO_RENDERED="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/indigo/env.config.jsx"
MFE_ENV_CONFIG_RENDERED="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/env.config.jsx"
MFE_FONTS_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/fonts"
LMS_FOOTER="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates/footer.html"
CMS_FOOTER="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/templates/footer.html"
CMS_FOOTER_WIDGET="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/templates/widgets/footer.html"
ENTERPRISE_ENV="$REPO_ROOT/deploy/k8s/base/apps/enterprise/mfe/enterprise-mfe-env.js"
ENTERPRISE_KUSTOMIZE="$REPO_ROOT/deploy/k8s/base/apps/enterprise/mfe/kustomization.yaml"
FOOTER_HELPER="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/mereka_footer.py"
LMS_PRODUCTION_SETTINGS="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"
LMS_DEVELOPMENT_SETTINGS="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/development.py"

if mereka_plugin_has_any "$REPO_ROOT"; then
  PLUGIN_BUNDLE="$(mktemp -t mereka-plugin-contract.XXXXXX)"
  while IFS= read -r plugin_file; do
    cat "$plugin_file" >>"$PLUGIN_BUNDLE"
    printf '\n' >>"$PLUGIN_BUNDLE"
  done < <(mereka_plugin_contract_files "$REPO_ROOT")
  PLUGIN="$PLUGIN_BUNDLE"
fi

cleanup() {
  if [[ -n "$PLUGIN_BUNDLE" && -f "$PLUGIN_BUNDLE" ]]; then
    rm -f "$PLUGIN_BUNDLE"
  fi
}
trap cleanup EXIT

echo "========================================"
echo "Footer Parity Verifier"
echo "Repo: $REPO_ROOT"
echo "========================================"
echo ""

# -----------------------------------------------------------------------
# Offline: Patch module exists and is sourced in apply-patches.sh
# -----------------------------------------------------------------------
echo "[OFFLINE] Patch module and apply-patches.sh wiring"

if [[ -f "$FOOTER_PATCH" ]]; then
  pass "footer-component.sh patch module exists"
else
  fail "footer-component.sh patch module missing: $FOOTER_PATCH"
fi

if [[ -f "$APPLY_PATCHES" ]]; then
  if grep -q "footer-component.sh" "$APPLY_PATCHES"; then
    pass "apply-patches.sh sources footer-component.sh"
  else
    fail "apply-patches.sh does not source footer-component.sh"
  fi
  if grep -q "apply_footer_component_patch" "$APPLY_PATCHES"; then
    pass "apply-patches.sh calls apply_footer_component_patch"
  else
    fail "apply-patches.sh does not call apply_footer_component_patch"
  fi
else
  fail "apply-patches.sh not found: $APPLY_PATCHES"
fi

echo ""

# -----------------------------------------------------------------------
# Offline: legacy env.config JSX surgery must NOT be in patch module
# -----------------------------------------------------------------------
echo "[OFFLINE] Patch module migration guard (no legacy footer JSX surgery)"

if [[ -f "$FOOTER_PATCH" ]]; then
  if grep -q "const MerekaFooter" "$FOOTER_PATCH"; then
    fail "footer-component.sh still injects const MerekaFooter (legacy path should be removed)"
  else
    pass "footer-component.sh does not inject const MerekaFooter (plugin-slot path active)"
  fi
  if grep -q "mereka-footer--v2" "$FOOTER_PATCH"; then
    fail "footer-component.sh still contains mereka-footer--v2 markup hooks (legacy path should be removed)"
  else
    pass "footer-component.sh contains no legacy footer markup hooks"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# Offline: SCSS import wiring (env.config.jsx template + rendered files)
# -----------------------------------------------------------------------
echo "[OFFLINE] SCSS import wiring"

if [[ -f "$FOOTER_PATCH" ]]; then
  if grep -q "mereka/mereka.scss" "$FOOTER_PATCH"; then
    pass "footer-component.sh syncs mereka.scss into Indigo build context"
  else
    fail "footer-component.sh does not sync mereka.scss into Indigo build context"
  fi
fi

if [[ -f "$MEREKA_SCSS" ]]; then
  pass "mereka.scss source file exists"
else
  fail "mereka.scss source file missing: $MEREKA_SCSS"
fi

if [[ -f "$MFE_INDIGO_RENDERED" ]]; then
  if grep -q "mereka/mereka.scss" "$MFE_INDIGO_RENDERED"; then
    pass "mereka.scss imported in rendered indigo/env.config.jsx"
  else
    fail "mereka.scss import missing from rendered indigo/env.config.jsx"
  fi
  if grep -q "const MerekaFooter" "$MFE_INDIGO_RENDERED"; then
    pass "MerekaFooter component present in rendered indigo/env.config.jsx"
  else
    fail "MerekaFooter component missing from rendered indigo/env.config.jsx"
  fi
else
  skip "Rendered indigo/env.config.jsx not found — run apply-patches.sh first"
fi

if [[ -f "$MFE_ENV_CONFIG_RENDERED" ]]; then
  if grep -q "mereka/mereka.scss" "$MFE_ENV_CONFIG_RENDERED"; then
    pass "mereka.scss imported in rendered top-level env.config.jsx"
  else
    fail "mereka.scss import missing from rendered top-level env.config.jsx"
  fi
else
  skip "Rendered top-level env.config.jsx not found — run apply-patches.sh first"
fi

echo ""

# -----------------------------------------------------------------------
# Offline: Footer legal links in plugin runtime definitions
# -----------------------------------------------------------------------
echo "[OFFLINE] Footer legal links in plugin runtime definitions"

if [[ -f "$PLUGIN" ]]; then
  if grep -q "https://legal.mereka.io/privacy-policy/" "$PLUGIN"; then
    pass "Privacy Policy link present in plugin runtime definitions"
  else
    fail "Privacy Policy link missing from plugin runtime definitions"
  fi
  if grep -q "https://legal.mereka.io/" "$PLUGIN"; then
    pass "Terms of Use link present in plugin runtime definitions"
  else
    fail "Terms of Use link missing from plugin runtime definitions"
  fi
  if grep -q "https://legal.mereka.io/#cookie-policy" "$PLUGIN"; then
    pass "Cookies Policy link present in plugin runtime definitions"
  else
    fail "Cookies Policy link missing from plugin runtime definitions"
  fi
  if grep -q "https://help.mereka.io/" "$PLUGIN"; then
    pass "Help Centre link present in plugin runtime definitions"
  else
    fail "Help Centre link missing from plugin runtime definitions"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# Offline: Branding assets (logo, fonts — self-hosted, no Google Fonts)
# -----------------------------------------------------------------------
echo "[OFFLINE] Branding assets"

if [[ -d "$MFE_FONTS_DIR" ]] && ls "$MFE_FONTS_DIR"/*.woff2 >/dev/null 2>&1; then
  font_count="$(ls "$MFE_FONTS_DIR"/*.woff2 | wc -l | tr -d ' ')"
  pass "MFE self-hosted fonts present ($font_count .woff2 files)"
else
  fail "MFE font directory missing or empty: $MFE_FONTS_DIR"
fi

if [[ -f "$FOOTER_PATCH" ]]; then
  if grep -q "fonts.googleapis.com" "$FOOTER_PATCH" 2>/dev/null; then
    fail "footer-component.sh references fonts.googleapis.com (privacy violation)"
  else
    pass "Footer patch module has no Google Fonts references"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-FTPAR-001: MFE footer component exists with site variants
# -----------------------------------------------------------------------
echo "AC-FTPAR-001: MFE footer component exists with site variants"

if [[ ! -f "$PLUGIN" ]]; then
  fail "Plugin contract source missing: $PLUGIN_MAIN"
else
  pass "Plugin file exists"

  # MerekaFooter component defined
  if grep -q "const MerekaFooter" "$PLUGIN"; then
    pass "MerekaFooter component defined in plugin"
  else
    fail "MerekaFooter component not found in plugin"
  fi

  # Canonical variant map present
  if grep -q "const MEREKA_SITE_VARIANTS = {" "$PLUGIN"; then
    pass "MEREKA_SITE_VARIANTS map defined in plugin runtime definitions"
  else
    fail "MEREKA_SITE_VARIANTS map not found in plugin"
  fi

  if grep -q "const getMerekaVariant = " "$PLUGIN"; then
    pass "getMerekaVariant runtime resolver present"
  else
    fail "getMerekaVariant runtime resolver missing"
  fi

  if grep -q "getMerekaPublicFooter" "$PLUGIN" && grep -q "config.MEREKA_PUBLIC_FOOTER" "$PLUGIN"; then
    pass "MFE footer consumes shared MEREKA_PUBLIC_FOOTER content"
  else
    fail "MFE footer missing shared MEREKA_PUBLIC_FOOTER content consumption"
  fi

  # Minimum 2 production domain entries (we expect 3)
  DOMAIN_COUNT=$(grep -c "'academyv2.mereka.io'\|'academy.biji-biji.com'\|'skillourfuture.academy.mereka.io'" "$PLUGIN" || true)
  if [[ "$DOMAIN_COUNT" -ge 2 ]]; then
    pass "MEREKA_SITE_VARIANTS has >= 2 production domain entries ($DOMAIN_COUNT found)"
  else
    fail "MEREKA_SITE_VARIANTS has fewer than 2 domain entries ($DOMAIN_COUNT found)"
  fi

  # footer.v1 slot reference (either direct PLUGIN_SLOTS or mfe-env-config patch)
  if grep -q "footer_slot\|footer\.v1\|mfe-env-config" "$PLUGIN"; then
    pass "Footer slot reference present in plugin (footer_slot / footer.v1 / mfe-env-config)"
  else
    fail "No footer slot reference found in plugin"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-FTPAR-002: LMS Mako footer template exists and contains Mereka branding
# -----------------------------------------------------------------------
echo "AC-FTPAR-002: LMS Mako footer template with Mereka branding"

if [[ ! -f "$LMS_FOOTER" ]]; then
  fail "LMS footer template missing: infrastructure/tutor/themes/mereka/lms/templates/footer.html"
else
  pass "LMS footer template exists"

  # Mereka branding markers — at least one must be present
  if grep -qi "mereka\|biji-biji\|mereka-footer" "$LMS_FOOTER"; then
    pass "LMS footer template contains Mereka branding content"
  else
    fail "LMS footer template has no Mereka branding content (no 'mereka', 'biji-biji', or 'mereka-footer')"
  fi

  # Mereka logo reference
  if grep -q "logo.png\|mereka-footer\|mereka_footer" "$LMS_FOOTER"; then
    pass "LMS footer template references Mereka logo or footer CSS class"
  else
    warn "LMS footer template may be missing Mereka logo or mereka-footer CSS class"
  fi

  if grep -q "MEREKA_PUBLIC_FOOTER" "$LMS_FOOTER"; then
    pass "LMS footer template renders shared MEREKA_PUBLIC_FOOTER content"
  else
    fail "LMS footer template missing shared MEREKA_PUBLIC_FOOTER content wiring"
  fi
fi

# CMS footer widget override (canonical — cms/templates/widgets/footer.html is what Studio renders)
echo ""
echo "  [INFO] CMS footer widget check (cms/templates/widgets/footer.html is the rendering template)"
if [[ -f "$CMS_FOOTER_WIDGET" ]]; then
  pass "CMS footer widget override exists (canonical Studio footer)"
  if grep -qi "mereka\|biji-biji" "$CMS_FOOTER_WIDGET"; then
    pass "CMS footer widget contains Mereka branding"
  else
    warn "CMS footer widget exists but lacks explicit Mereka branding"
  fi
elif [[ -f "$CMS_FOOTER" ]]; then
  warn "CMS footer at wrong path (cms/templates/footer.html) — upstream widgets/footer.html renders instead"
else
  fail "CMS footer widget missing — Studio renders upstream Open edX footer with 'Powered by Open edX'"
fi

echo ""

# -----------------------------------------------------------------------
# AC-FTPAR-003: Footer copyright fields present for all site-variant domains
# -----------------------------------------------------------------------
echo "AC-FTPAR-003: copyright fields present for all site-variant domains"

if [[ ! -f "$PLUGIN" ]]; then
  fail "Plugin file missing — cannot check site-variant copyright fields"
else
  DOMAINS=("academyv2.mereka.io" "academy.biji-biji.com" "skillourfuture.academy.mereka.io")
  VARIANTS_BLOCK=$(awk '/const MEREKA_SITE_VARIANTS = \{/,/^\s*\};/' "$PLUGIN")
  # Also extract MEREKA_BASE_VARIANT for fields inherited via spread
  BASE_VARIANT_BLOCK=$(awk '/const MEREKA_BASE_VARIANT = \{/,/^\s*\};/' "$PLUGIN")

  for domain in "${DOMAINS[@]}"; do
    # Extract the domain object block (from the domain key line to the closing '},')
    # Supports both single-line and multi-line object formats
    DOMAIN_BLOCK=$(awk "/'${domain}':/,/^[[:space:]]*},/" <<<"$VARIANTS_BLOCK")

    if [[ -z "$DOMAIN_BLOCK" ]]; then
      fail "Domain '${domain}' not found in MEREKA_SITE_VARIANTS"
      continue
    fi

    # brand field — must be per-tenant (not in base)
    if grep -q "brand: '" <<<"$DOMAIN_BLOCK"; then
      pass "Domain '${domain}' has non-empty brand"
    else
      fail "Domain '${domain}' missing or empty brand"
    fi

    # copyrightHolder field — must be per-tenant (not in base)
    if grep -q "copyrightHolder: '" <<<"$DOMAIN_BLOCK"; then
      pass "Domain '${domain}' has non-empty copyrightHolder"
    else
      fail "Domain '${domain}' missing or empty copyrightHolder"
    fi

    # whatsapp field — may be in MEREKA_BASE_VARIANT (inherited via spread ...MEREKA_BASE_VARIANT)
    if grep -q "whatsapp: '" <<<"$DOMAIN_BLOCK" || grep -q "whatsapp: '" <<<"$BASE_VARIANT_BLOCK"; then
      pass "Domain '${domain}' has non-empty whatsapp"
    else
      fail "Domain '${domain}' missing or empty whatsapp"
    fi
  done

  # Confirm no null/undefined values in the MEREKA_SITE_VARIANTS block
  if grep -qE ": null|: undefined" <<<"$VARIANTS_BLOCK"; then
    fail "MEREKA_SITE_VARIANTS contains null or undefined values"
  else
    pass "No null/undefined values in MEREKA_SITE_VARIANTS"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-FTPAR-004: Enterprise MFE deployments reference footer/env config
# -----------------------------------------------------------------------
echo "AC-FTPAR-004: Enterprise MFE deployments reference env config"

if [[ ! -f "$ENTERPRISE_ENV" ]]; then
  fail "Enterprise MFE env config missing: deploy/k8s/base/apps/enterprise/mfe/enterprise-mfe-env.js"
else
  pass "Enterprise MFE env config exists (enterprise-mfe-env.js)"

  # LMS_BASE_URL must be present (required for footer to resolve logo/links)
  if grep -q "LMS_BASE_URL" "$ENTERPRISE_ENV"; then
    pass "Enterprise MFE env config defines LMS_BASE_URL"
  else
    fail "Enterprise MFE env config missing LMS_BASE_URL"
  fi
fi

if [[ ! -f "$ENTERPRISE_KUSTOMIZE" ]]; then
  fail "Enterprise MFE kustomization.yaml missing"
else
  pass "Enterprise MFE kustomization.yaml exists"

  # enterprise-mfe-env ConfigMap must be referenced
  if grep -q "enterprise-mfe-env" "$ENTERPRISE_KUSTOMIZE"; then
    pass "Enterprise kustomization references enterprise-mfe-env ConfigMap"
  else
    fail "Enterprise kustomization does not reference enterprise-mfe-env ConfigMap"
  fi

  # Both portal deployments must be referenced
  if grep -q "admin-portal-deployment.yaml" "$ENTERPRISE_KUSTOMIZE"; then
    pass "Enterprise kustomization includes admin-portal-deployment.yaml"
  else
    fail "Enterprise kustomization missing admin-portal-deployment.yaml"
  fi

  if grep -q "learner-portal-deployment.yaml" "$ENTERPRISE_KUSTOMIZE"; then
    pass "Enterprise kustomization includes learner-portal-deployment.yaml"
  else
    fail "Enterprise kustomization missing learner-portal-deployment.yaml"
  fi
fi

# Note gap: enterprise MFEs have no MerekaFooter wiring — record as informational warn
warn "Enterprise MFE env config does not wire MerekaFooter — enterprise portals use Open edX default footer (see FOOTER_PARITY_AUDIT.md recommendation #4)"

echo ""

# -----------------------------------------------------------------------
# AC-FTPAR-005: No "powered by Open edX" without Mereka co-branding
# -----------------------------------------------------------------------
echo "AC-FTPAR-005: No unbranded 'powered by Open edX' in footer files"

# MFE footer in mereka_lms.py — MerekaFooter component body should not contain
# "powered by Open edX" at all
if [[ -f "$PLUGIN" ]]; then
  # Extract MerekaFooter body
  FOOTER_START=$(grep -nF "const MerekaFooter = ()" "$PLUGIN" | head -1 | cut -d: -f1)
  FOOTER_END=$(awk -v start="$FOOTER_START" 'NR > start && /^};\r?$/ { print NR; exit }' "$PLUGIN")

  if [[ -z "$FOOTER_START" || -z "$FOOTER_END" ]]; then
    warn "Could not determine MerekaFooter boundaries for 'powered by' check"
  else
    FOOTER_BODY=$(awk -v s="$FOOTER_START" -v e="$FOOTER_END" 'NR>=s && NR<=e' "$PLUGIN")
    if grep -qi "powered by open edx" <<<"$FOOTER_BODY"; then
      fail "MFE MerekaFooter body contains unbranded 'Powered by Open edX'"
    else
      pass "MFE MerekaFooter body has no 'Powered by Open edX'"
    fi
  fi
fi

# LMS Mako footer — "powered by" is present; check if Mereka name co-appears nearby
if [[ -f "$LMS_FOOTER" ]]; then
  # Exclude Mako comment lines (##) — comments may reference the removed string for documentation
  POWERED_BY_LINE=$(grep -i "powered by" "$LMS_FOOTER" | grep -v '^\s*##' || true)
  if [[ -z "$POWERED_BY_LINE" ]]; then
    pass "LMS Mako footer has no 'Powered by' string"
  else
    # Check if co-branded (Mereka, Biji-Biji, or platform name appears on the same line/nearby)
    POWERED_BY_LINE_NUMBER=$(grep -n -i "powered by" "$LMS_FOOTER" | head -1 | cut -d: -f1)
    # Look ±3 lines around the "powered by" line for Mereka co-branding
    CONTEXT=$(awk -v n="$POWERED_BY_LINE_NUMBER" 'NR>=n-3 && NR<=n+3' "$LMS_FOOTER")
    if grep -qi "mereka\|biji-biji\|platform_name\|get_platform_name" <<<"$CONTEXT"; then
      warn "LMS Mako footer has 'Powered by Open edX' — Mereka name appears nearby (partial co-branding). Recommend removing per FOOTER_PARITY_AUDIT.md"
    else
      fail "LMS Mako footer has standalone 'Powered by Open edX' with no Mereka co-branding — see FOOTER_PARITY_AUDIT.md recommendation #2"
    fi
  fi
fi

# CMS footer widget (canonical path — overrides cms/templates/widgets/footer.html upstream)
# This is the file that actually renders in Studio. Must exist and must not have Open edX branding.
if [[ -f "$CMS_FOOTER_WIDGET" ]]; then
  pass "CMS footer widget override exists (cms/templates/widgets/footer.html)"
  if grep -qi "mereka\|biji-biji" "$CMS_FOOTER_WIDGET"; then
    pass "CMS footer widget has Mereka branding"
  else
    warn "CMS footer widget exists but lacks explicit Mereka branding"
  fi
  if grep -qi "powered by open edx\|footer-about-openedx\|open-edx-logo-tag" "$CMS_FOOTER_WIDGET"; then
    fail "CMS footer widget has 'Powered by Open edX' — must be removed for white-label Studio"
    grep -n -i "powered by\|footer-about-openedx\|open-edx-logo-tag" "$CMS_FOOTER_WIDGET" | sed 's/^/    /'
  else
    pass "CMS footer widget has no 'Powered by Open edX' (white-label Studio)"
  fi
else
  fail "CMS footer widget override missing (cms/templates/widgets/footer.html) — Studio renders upstream Open edX footer"
  echo "    Fix: create infrastructure/tutor/themes/mereka/cms/templates/widgets/footer.html"
fi

# CMS footer legacy file (cms/templates/footer.html — may not be the rendering template)
if [[ -f "$CMS_FOOTER" ]]; then
  if grep -qi "powered by open edx" "$CMS_FOOTER"; then
    POWERED_LINE=$(grep -n -i "powered by" "$CMS_FOOTER" | head -1 | cut -d: -f1)
    CONTEXT=$(awk -v n="$POWERED_LINE" 'NR>=n-3 && NR<=n+3' "$CMS_FOOTER")
    if grep -qi "mereka\|biji-biji\|platform_name\|get_platform_name" <<<"$CONTEXT"; then
      warn "CMS footer (cms/templates/footer.html) has 'Powered by Open edX' with co-branding"
    else
      fail "CMS footer (cms/templates/footer.html) has standalone 'Powered by Open edX'"
    fi
  else
    pass "CMS footer (cms/templates/footer.html) has no 'Powered by Open edX'"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-FTPAR-006: Positive allowlist — required content MUST be present
# (guards against accidental blank/stubbed templates)
# -----------------------------------------------------------------------
echo "AC-FTPAR-006: Positive allowlist — required content present"

# LMS footer must have at least one mereka.io link (not just branding classes)
if [[ -f "$LMS_FOOTER" ]]; then
  if grep -q "mereka\.io\|mereka\.my" "$LMS_FOOTER"; then
    pass "LMS footer contains at least one mereka.io/mereka.my link"
  else
    fail "LMS footer has no mereka.io or mereka.my links — may be empty/stubbed"
  fi

  # LMS footer must have copyright year expression
  # Use -E (ERE) so \( \) are literal parens; avoid BRE empty-group interpretation
  if grep -qE "datetime\.now\(\)\.year|%Y|\{year\}" "$LMS_FOOTER"; then
    pass "LMS footer has dynamic copyright year expression"
  else
    fail "LMS footer missing dynamic copyright year — may be hardcoded or removed"
  fi

  # LMS footer must NOT have hardcoded year (e.g. 2024 or 2025 as literal)
  HARDCODED_YEAR=$(grep -oE "© [0-9]{4}" "$LMS_FOOTER" || true)
  if [[ -n "$HARDCODED_YEAR" ]]; then
    fail "LMS footer has hardcoded copyright year: ${HARDCODED_YEAR} — use datetime.now().year"
  else
    pass "LMS footer has no hardcoded copyright year"
  fi
fi

# MFE plugin must have all 4 v2 structural zones
if [[ -f "$PLUGIN" ]]; then
  ZONE_COUNT=$(grep -c "Zone [1-4]:" "$PLUGIN" || true)
  if [[ "$ZONE_COUNT" -ge 4 ]]; then
    pass "MFE MerekaFooter has all 4 v2 structural zones ($ZONE_COUNT zone comments found)"
  else
    fail "MFE MerekaFooter missing v2 structural zones (found $ZONE_COUNT of 4 expected)"
  fi

  # Legal section must have copyright and at least one legal link
  if grep -q "footer-legal" "$PLUGIN" && grep -q "privacy\|terms\|cookie" "$PLUGIN"; then
    pass "MFE footer legal zone has copyright block and legal links"
  else
    fail "MFE footer legal zone missing copyright or legal links"
  fi
fi

# CMS footer widget must have a copyright or brand statement (not just CSS classes)
if [[ -f "$CMS_FOOTER_WIDGET" ]]; then
  if grep -qi "Mereka Academy\|Mereka\|biji-biji\|academy" "$CMS_FOOTER_WIDGET"; then
    pass "CMS footer widget has explicit brand content (not empty template)"
  else
    fail "CMS footer widget may be empty — no brand content found"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-FTPAR-008: Tenant footer data contract fields present in site variants
# Checks that all required contract fields exist for every tenant domain:
# supportEmail, helpUrl, privacyUrl, termsUrl, cookiesUrl (in addition to
# brand / copyrightHolder / whatsapp verified by AC-FTPAR-003)
# -----------------------------------------------------------------------
echo "AC-FTPAR-008: Tenant footer data contract fields (MEREKA_SITE_VARIANTS + LMS footer)"

if [[ -f "$PLUGIN" ]]; then
  CONTRACT_FIELDS=("supportEmail" "helpUrl" "privacyUrl" "termsUrl" "cookiesUrl")
  DOMAINS=("academyv2.mereka.io" "academy.biji-biji.com" "skillourfuture.academy.mereka.io")

  VARIANTS_BLOCK=$(awk '/const MEREKA_SITE_VARIANTS = \{/,/^\s*\};/' "$PLUGIN")
  # MEREKA_BASE_VARIANT is spread into each tenant block — its fields are inherited
  BASE_VARIANT_BLOCK=$(awk '/const MEREKA_BASE_VARIANT = \{/,/^\s*\};/' "$PLUGIN")

  for domain in "${DOMAINS[@]}"; do
    DOMAIN_BLOCK=$(awk "/'${domain}':/,/^[[:space:]]*},/" <<<"$VARIANTS_BLOCK")
    if [[ -z "$DOMAIN_BLOCK" ]]; then
      fail "Domain '${domain}' block not found for contract field check"
      continue
    fi
    for field in "${CONTRACT_FIELDS[@]}"; do
      # Check per-tenant block first, then MEREKA_BASE_VARIANT (fields inherited via spread)
      if grep -q "${field}:" <<<"$DOMAIN_BLOCK" || grep -q "${field}:" <<<"$BASE_VARIANT_BLOCK"; then
        pass "Domain '${domain}' has contract field '${field}'"
      else
        fail "Domain '${domain}' missing contract field '${field}'"
      fi
    done
  done

  # Fallback return object must also have all contract fields (directly or via spread)
  FALLBACK_BLOCK="$(
    awk '/const getMerekaVariant = /,/^};/' "$PLUGIN" \
      | awk '/return \{/,/^\s*\};/' \
      | head -20
  )"
  for field in "${CONTRACT_FIELDS[@]}"; do
    # Fallback uses ...MEREKA_BASE_VARIANT spread — check both fallback and base block
    if grep -q "${field}:" <<<"$FALLBACK_BLOCK" || grep -q "${field}:" <<<"$BASE_VARIANT_BLOCK"; then
      pass "Fallback variant has contract field '${field}'"
    else
      fail "Fallback variant missing contract field '${field}'"
    fi
  done
else
  fail "Plugin file missing — cannot check SITE_VARIANTS contract fields"
fi

# LMS footer must use configuration_helpers for support email and help URL
LMS_FOOTER_TPL="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates/footer.html"
if [[ -f "$LMS_FOOTER_TPL" ]]; then
  if grep -q "configuration_helpers" "$LMS_FOOTER_TPL"; then
    pass "LMS footer imports configuration_helpers (SiteConfiguration-aware)"
  else
    fail "LMS footer does not import configuration_helpers — support email/help URL are hardcoded"
  fi
  if grep -q "SUPPORT_EMAIL\|HELP_CENTER_URL" "$LMS_FOOTER_TPL"; then
    pass "LMS footer reads SUPPORT_EMAIL / HELP_CENTER_URL from SiteConfiguration"
  else
    fail "LMS footer missing SiteConfiguration keys for support email / help URL"
  fi
fi

if [[ -f "$FOOTER_HELPER" ]]; then
  pass "Shared footer helper exists: deploy/k8s/base/apps/openedx/settings/lms/mereka_footer.py"
else
  fail "Shared footer helper missing: deploy/k8s/base/apps/openedx/settings/lms/mereka_footer.py"
fi

for settings_file in "$LMS_PRODUCTION_SETTINGS" "$LMS_DEVELOPMENT_SETTINGS"; do
  if [[ -f "$settings_file" ]] && grep -q "MFE_CONFIG\\[\"MEREKA_PUBLIC_FOOTER\"\\]" "$settings_file"; then
    pass "${settings_file#$REPO_ROOT/} exports MEREKA_PUBLIC_FOOTER into MFE_CONFIG"
  else
    fail "${settings_file#$REPO_ROOT/} missing MEREKA_PUBLIC_FOOTER export into MFE_CONFIG"
  fi
done

echo ""

# -----------------------------------------------------------------------
# AC-FTPAR-007: Live footer content verification (requires --live flag)
# Checks rendered HTML on all three production domains for structural
# correctness: mereka-footer class, section markers, no "Powered by Open edX"
# -----------------------------------------------------------------------
echo "AC-FTPAR-007: Live footer content checks"

if [[ "$LIVE_MODE" -eq 1 ]]; then
  echo "  LMS URL: $LMS_URL"
  echo "  MFE URL: $MFE_URL"
  echo ""
  # @covers AC-FTPAR-007: live footer class + section markers present on all domains
  if [[ "$EXPLICIT_LIVE_URLS" -eq 1 ]]; then
    LIVE_TARGETS=(
      "lms|${LMS_URL}"
      "mfe|${MFE_URL}"
    )
  else
    LIVE_TARGETS=(
      "lms-primary|https://academyv2.mereka.io"
      "lms-biji|https://academy.biji-biji.com"
      "lms-sof|https://skillourfuture.academy.mereka.io"
    )
  fi

  for target in "${LIVE_TARGETS[@]}"; do
    name="${target%%|*}"
    url="${target#*|}"
    echo "  [target: $name]"
    HTML=$(curl -sSLf --max-time 15 "$url" 2>/dev/null || true)
    if [[ -z "$HTML" ]]; then
      fail "${name}: failed to fetch ${url} (curl error, timeout, or 5xx)"
      continue
    fi

    # mereka-footer class must be present
    if grep -q "mereka-footer" <<<"$HTML"; then
      pass "${name}: mereka-footer class present"
    else
      fail "${name}: mereka-footer class NOT present (may be deployment gap — image rebuild required)"
    fi

    # No unbranded "Powered by Open edX"
    if grep -qi "powered by open edx" <<<"$HTML"; then
      fail "${name}: contains 'Powered by Open edX'"
    else
      pass "${name}: no unbranded 'Powered by Open edX'"
    fi

    # Copyright line present
    if grep -qE "©|&copy;|copyright|MEREKA|Biji-Biji" <<<"$HTML"; then
      pass "${name}: copyright/brand line present"
    else
      fail "${name}: copyright/brand line NOT present"
    fi
  done

  # The broad section inventory belongs to branding acceptance, not runtime-routing.
  if [[ "$EXPLICIT_LIVE_URLS" -eq 1 ]]; then
    skip "Explicit live URLs provided — skipping broad LMS section inventory (tenant-branding concern)"
  else
    echo "  [LMS structural sections: academyv2.mereka.io]"
    LMS_HTML=$(curl -sf --max-time 15 "https://academyv2.mereka.io" 2>/dev/null || true)
    if [[ -n "$LMS_HTML" ]]; then
      for section in "Future of Work" "Creative Tech" "Explore" "Support" "Partners"; do
        if grep -q "$section" <<<"$LMS_HTML"; then
          pass "LMS footer section '${section}' present"
        else
          fail "LMS footer section '${section}' NOT present (may be image deployment gap)"
        fi
      done
    else
      warn "Could not fetch academyv2.mereka.io for section checks"
    fi
  fi
else
  skip "AC-FTPAR-007 skipped — pass --live to run live footer content checks"
  echo "  Usage: ./scripts/qa/verify-footer-parity.sh --live"
fi

echo ""

# -----------------------------------------------------------------------
# WARN ALLOWLIST — accepted warnings (for CI interpretation)
# -----------------------------------------------------------------------
echo "WARN allowlist (accepted warnings — not gate failures):"
echo "  WARN-001: Enterprise MFE portals use Open edX default footer (P4 backlog, no MerekaFooter wiring)"
echo "  WARN-002: LMS nav links (emails, help URL) are Mereka-specific — multi-tenant via bead 2rcf"
echo ""

echo "========================================"
echo "Footer parity: PASS=$PASS FAIL=$FAIL WARN=$WARN SKIP=$SKIP"
echo "========================================"

if [[ "$FAIL" -gt 0 ]]; then
  echo "RESULT: FAIL ($FAIL failure(s))" >&2
  exit 1
fi
echo "RESULT: PASS"
exit 0
