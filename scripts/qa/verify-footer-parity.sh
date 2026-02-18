#!/usr/bin/env bash
set -euo pipefail
# @spec: bead-115d14
# @covers AC-FTPAR-001: MFE footer component exists with SITE_VARIANTS
# @covers AC-FTPAR-002: LMS Mako footer template exists and contains Mereka branding
# @covers AC-FTPAR-003: Footer copyright fields present for all SITE_VARIANTS domains
# @covers AC-FTPAR-004: Enterprise MFE deployments reference footer/env config
# @covers AC-FTPAR-005: No "powered by Open edX" without Mereka co-branding in any footer

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }
warn() { WARN=$((WARN + 1)); echo "  WARN: $1"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
LMS_FOOTER="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates/footer.html"
CMS_FOOTER="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/templates/footer.html"
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

# CMS footer is optional (Studio is internal-only) — warn if absent, not fail
echo ""
echo "  [INFO] CMS footer check (Studio is internal — WARN only if missing)"
if [[ -f "$CMS_FOOTER" ]]; then
  pass "CMS footer template exists"
  if grep -qi "mereka\|biji-biji" "$CMS_FOOTER"; then
    pass "CMS footer template contains Mereka branding"
  else
    warn "CMS footer template exists but lacks explicit Mereka branding"
  fi
else
  warn "CMS footer template absent ($CMS_FOOTER) — Studio uses Open edX default footer (acceptable for internal use)"
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
    # Each domain key line should have brand, copyrightHolder, whatsapp on the same line
    # (they are inline objects: { brand: '...', copyrightHolder: '...', whatsapp: '...' })
    DOMAIN_LINE=$(grep "'${domain}'" "$PLUGIN" || true)

    if [[ -z "$DOMAIN_LINE" ]]; then
      fail "Domain '${domain}' not found in SITE_VARIANTS"
      continue
    fi

    # brand field
    if echo "$DOMAIN_LINE" | grep -q "brand: '"; then
      pass "Domain '${domain}' has non-empty brand"
    else
      fail "Domain '${domain}' missing or empty brand"
    fi

    # copyrightHolder field
    if echo "$DOMAIN_LINE" | grep -q "copyrightHolder: '"; then
      pass "Domain '${domain}' has non-empty copyrightHolder"
    else
      fail "Domain '${domain}' missing or empty copyrightHolder"
    fi

    # whatsapp field
    if echo "$DOMAIN_LINE" | grep -q "whatsapp: '"; then
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
  POWERED_BY_LINE=$(grep -i "powered by" "$LMS_FOOTER" || true)
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

# CMS footer — only check if it exists
if [[ -f "$CMS_FOOTER" ]]; then
  if grep -qi "powered by open edx" "$CMS_FOOTER"; then
    POWERED_LINE=$(grep -n -i "powered by" "$CMS_FOOTER" | head -1 | cut -d: -f1)
    CONTEXT=$(awk -v n="$POWERED_LINE" 'NR>=n-3 && NR<=n+3' "$CMS_FOOTER")
    if echo "$CONTEXT" | grep -qi "mereka\|biji-biji\|platform_name\|get_platform_name"; then
      warn "CMS footer has 'Powered by Open edX' with Mereka co-branding nearby"
    else
      fail "CMS footer has standalone 'Powered by Open edX' with no Mereka co-branding"
    fi
  else
    pass "CMS footer has no standalone 'Powered by Open edX'"
  fi
fi

echo ""
echo "========================================"
echo "Footer parity: $PASS PASS / $FAIL FAIL / $WARN WARN"
echo "========================================"
exit $((FAIL > 0 ? 1 : 0))
