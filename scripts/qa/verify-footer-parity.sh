#!/usr/bin/env bash
set -euo pipefail
# @spec: bead-115d14
# @covers AC-FTPAR-001: MFE footer component exists with SITE_VARIANTS
# @covers AC-FTPAR-002: LMS Mako footer template exists and contains Mereka branding
# @covers AC-FTPAR-003: Footer copyright fields present for all SITE_VARIANTS domains
# @covers AC-FTPAR-004: Enterprise MFE deployments reference footer/env config
# @covers AC-FTPAR-005: No "powered by Open edX" without Mereka co-branding in any footer
# @covers AC-FTPAR-007: Live footer class + section markers present on all 3 production domains (--live)
# @covers AC-FTPAR-008: Tenant footer data contract fields present in SITE_VARIANTS + LMS footer

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
for _arg in "$@"; do
  if [[ "$_arg" == "--live" ]]; then LIVE_MODE=1; fi
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
LMS_FOOTER="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates/footer.html"
CMS_FOOTER="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/templates/footer.html"
CMS_FOOTER_WIDGET="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/templates/widgets/footer.html"
ENTERPRISE_ENV="$REPO_ROOT/deploy/k8s/base/apps/enterprise/mfe/enterprise-mfe-env.js"
ENTERPRISE_KUSTOMIZE="$REPO_ROOT/deploy/k8s/base/apps/enterprise/mfe/kustomization.yaml"

echo "========================================"
echo "Footer Parity Verifier"
echo "========================================"
echo ""

# -----------------------------------------------------------------------
# AC-FTPAR-001: MFE footer component exists with SITE_VARIANTS
# -----------------------------------------------------------------------
echo "AC-FTPAR-001: MFE footer component exists with SITE_VARIANTS"

if [[ ! -f "$PLUGIN" ]]; then
  fail "Plugin file missing: infrastructure/tutor/plugins/mereka_lms.py"
else
  pass "Plugin file exists"

  # MerekaFooter component defined
  if grep -q "const MerekaFooter" "$PLUGIN"; then
    pass "MerekaFooter component defined in plugin"
  else
    fail "MerekaFooter component not found in plugin"
  fi

  # SITE_VARIANTS map present
  VARIANTS_CONTENT=$(grep -o "const SITE_VARIANTS = {" "$PLUGIN" || true)
  if [[ -n "$VARIANTS_CONTENT" ]]; then
    pass "SITE_VARIANTS map defined in MerekaFooter"
  else
    fail "SITE_VARIANTS map not found in plugin"
  fi

  # Minimum 2 SITE_VARIANTS entries (we have 3 production domains)
  DOMAIN_COUNT=$(grep -c "'academyv2.mereka.io'\|'academy.biji-biji.com'\|'skillourfuture.academy.mereka.io'" "$PLUGIN" || true)
  if [[ "$DOMAIN_COUNT" -ge 2 ]]; then
    pass "SITE_VARIANTS has >= 2 production domain entries ($DOMAIN_COUNT found)"
  else
    fail "SITE_VARIANTS has fewer than 2 domain entries ($DOMAIN_COUNT found)"
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
# AC-FTPAR-003: Footer copyright fields present for all SITE_VARIANTS domains
# -----------------------------------------------------------------------
echo "AC-FTPAR-003: copyright fields present for all SITE_VARIANTS domains"

if [[ ! -f "$PLUGIN" ]]; then
  fail "Plugin file missing — cannot check SITE_VARIANTS copyright fields"
else
  DOMAINS=("academyv2.mereka.io" "academy.biji-biji.com" "skillourfuture.academy.mereka.io")

  for domain in "${DOMAINS[@]}"; do
    # Extract the domain object block (from the domain key line to the closing '},')
    # Supports both single-line and multi-line object formats
    DOMAIN_BLOCK=$(awk "/'${domain}':/,/^[[:space:]]*\}/" "$PLUGIN" | head -30)

    if [[ -z "$DOMAIN_BLOCK" ]]; then
      fail "Domain '${domain}' not found in SITE_VARIANTS"
      continue
    fi

    # brand field
    if echo "$DOMAIN_BLOCK" | grep -q "brand: '"; then
      pass "Domain '${domain}' has non-empty brand"
    else
      fail "Domain '${domain}' missing or empty brand"
    fi

    # copyrightHolder field
    if echo "$DOMAIN_BLOCK" | grep -q "copyrightHolder: '"; then
      pass "Domain '${domain}' has non-empty copyrightHolder"
    else
      fail "Domain '${domain}' missing or empty copyrightHolder"
    fi

    # whatsapp field
    if echo "$DOMAIN_BLOCK" | grep -q "whatsapp: '"; then
      pass "Domain '${domain}' has non-empty whatsapp"
    else
      fail "Domain '${domain}' missing or empty whatsapp"
    fi
  done

  # Confirm no null/undefined values in the SITE_VARIANTS block
  VARIANTS_BLOCK=$(awk '/const SITE_VARIANTS = \{/,/^\s*\};/' "$PLUGIN")
  if echo "$VARIANTS_BLOCK" | grep -qE ": null|: undefined"; then
    fail "SITE_VARIANTS contains null or undefined values"
  else
    pass "No null/undefined values in SITE_VARIANTS"
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
    if echo "$FOOTER_BODY" | grep -qi "powered by open edx"; then
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
    if echo "$CONTEXT" | grep -qi "mereka\|biji-biji\|platform_name\|get_platform_name"; then
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
    if echo "$CONTEXT" | grep -qi "mereka\|biji-biji\|platform_name\|get_platform_name"; then
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
# AC-FTPAR-008: Tenant footer data contract fields present in SITE_VARIANTS
# Checks that all required contract fields exist for every tenant domain:
# supportEmail, helpUrl, privacyUrl, termsUrl, cookiesUrl (in addition to
# brand / copyrightHolder / whatsapp verified by AC-FTPAR-003)
# -----------------------------------------------------------------------
echo "AC-FTPAR-008: Tenant footer data contract fields (SITE_VARIANTS + LMS footer)"

if [[ -f "$PLUGIN" ]]; then
  CONTRACT_FIELDS=("supportEmail" "helpUrl" "privacyUrl" "termsUrl" "cookiesUrl")
  DOMAINS=("academyv2.mereka.io" "academy.biji-biji.com" "skillourfuture.academy.mereka.io")

  for domain in "${DOMAINS[@]}"; do
    DOMAIN_BLOCK=$(awk "/'${domain}':/,/\}/" "$PLUGIN" | head -20)
    if [[ -z "$DOMAIN_BLOCK" ]]; then
      fail "Domain '${domain}' block not found for contract field check"
      continue
    fi
    for field in "${CONTRACT_FIELDS[@]}"; do
      if echo "$DOMAIN_BLOCK" | grep -q "${field}:"; then
        pass "Domain '${domain}' has contract field '${field}'"
      else
        fail "Domain '${domain}' missing contract field '${field}'"
      fi
    done
  done

  # Fallback variant must also have all contract fields
  FALLBACK_LINE=$(awk '/const variant = SITE_VARIANTS/,/\};/' "$PLUGIN" | head -15)
  for field in "${CONTRACT_FIELDS[@]}"; do
    if echo "$FALLBACK_LINE" | grep -q "${field}:"; then
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

echo ""

# -----------------------------------------------------------------------
# AC-FTPAR-007: Live footer content verification (requires --live flag)
# Checks rendered HTML on all three production domains for structural
# correctness: mereka-footer class, section markers, no "Powered by Open edX"
# -----------------------------------------------------------------------
echo "AC-FTPAR-007: Live footer content checks"

if [[ "$LIVE_MODE" -eq 1 ]]; then
  # @covers AC-FTPAR-007: live footer class + section markers present on all domains
  LIVE_DOMAINS=(
    "academyv2.mereka.io"
    "academy.biji-biji.com"
    "skillourfuture.academy.mereka.io"
  )

  for domain in "${LIVE_DOMAINS[@]}"; do
    echo "  [domain: $domain]"
    HTML=$(curl -sf --max-time 15 "https://${domain}" 2>/dev/null || true)
    if [[ -z "$HTML" ]]; then
      fail "${domain}: failed to fetch (curl error, timeout, or 5xx)"
      continue
    fi

    # mereka-footer class must be present
    if echo "$HTML" | grep -q "mereka-footer"; then
      pass "${domain}: mereka-footer class present"
    else
      fail "${domain}: mereka-footer class NOT present (may be deployment gap — image rebuild required)"
    fi

    # No unbranded "Powered by Open edX"
    if echo "$HTML" | grep -qi "powered by open edx"; then
      fail "${domain}: contains 'Powered by Open edX'"
    else
      pass "${domain}: no unbranded 'Powered by Open edX'"
    fi

    # Copyright line present
    if echo "$HTML" | grep -qE "©|&copy;|copyright|MEREKA|Biji-Biji"; then
      pass "${domain}: copyright/brand line present"
    else
      fail "${domain}: copyright/brand line NOT present"
    fi
  done

  # LMS structural section checks (single LMS pod serves all three domains)
  echo "  [LMS structural sections: academyv2.mereka.io]"
  LMS_HTML=$(curl -sf --max-time 15 "https://academyv2.mereka.io" 2>/dev/null || true)
  if [[ -n "$LMS_HTML" ]]; then
    for section in "Future of Work" "Creative Tech" "Explore" "Support" "Partners"; do
      if echo "$LMS_HTML" | grep -q "$section"; then
        pass "LMS footer section '${section}' present"
      else
        fail "LMS footer section '${section}' NOT present (may be image deployment gap)"
      fi
    done
  else
    warn "Could not fetch academyv2.mereka.io for section checks"
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
echo "Footer parity: $PASS PASS / $FAIL FAIL / $WARN WARN / $SKIP SKIP"
echo "========================================"
exit $((FAIL > 0 ? 1 : 0))
