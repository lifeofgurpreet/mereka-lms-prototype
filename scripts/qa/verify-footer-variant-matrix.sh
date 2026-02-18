#!/usr/bin/env bash
set -euo pipefail
# @spec: branding-system_spec.md
# @covers AC-FTVAR-001, AC-FTVAR-002, AC-FTVAR-003, AC-FTVAR-004, AC-FTVAR-005

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }
warn() { WARN=$((WARN + 1)); echo "  WARN: $1"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
MATRIX_DOC="$REPO_ROOT/docs/operations/FOOTER_VARIANT_MATRIX.md"

echo "========================================"
echo "Footer Variant Matrix Verifier"
echo "========================================"
echo ""

# -----------------------------------------------------------------------
# AC-FTVAR-001: SITE_VARIANTS map contains all 3 production domains
# -----------------------------------------------------------------------
echo "AC-FTVAR-001: SITE_VARIANTS contains all 3 production domains"

if [[ ! -f "$PLUGIN" ]]; then
  fail "Plugin file missing: $PLUGIN"
else
  pass "Plugin file exists: infrastructure/tutor/plugins/mereka_lms.py"

  if grep -q "'academyv2.mereka.io'" "$PLUGIN"; then
    pass "SITE_VARIANTS contains 'academyv2.mereka.io'"
  else
    fail "SITE_VARIANTS missing 'academyv2.mereka.io'"
  fi

  if grep -q "'academy.biji-biji.com'" "$PLUGIN"; then
    pass "SITE_VARIANTS contains 'academy.biji-biji.com'"
  else
    fail "SITE_VARIANTS missing 'academy.biji-biji.com'"
  fi

  if grep -q "'skillourfuture.academy.mereka.io'" "$PLUGIN"; then
    pass "SITE_VARIANTS contains 'skillourfuture.academy.mereka.io'"
  else
    fail "SITE_VARIANTS missing 'skillourfuture.academy.mereka.io'"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-FTVAR-002: Each variant has brand, copyrightHolder, whatsapp fields
# -----------------------------------------------------------------------
echo "AC-FTVAR-002: Each variant has required fields (no nulls)"

if [[ -f "$PLUGIN" ]]; then
  # Extract the SITE_VARIANTS block: from "const SITE_VARIANTS = {" to the closing "};"
  VARIANTS_BLOCK=$(awk '/const SITE_VARIANTS = \{/,/^\s*\};/' "$PLUGIN")

  # Check brand field present in variants block
  if echo "$VARIANTS_BLOCK" | grep -q "brand:"; then
    pass "SITE_VARIANTS entries contain 'brand:' field"
  else
    fail "SITE_VARIANTS entries missing 'brand:' field"
  fi

  # Check copyrightHolder field present in variants block
  if echo "$VARIANTS_BLOCK" | grep -q "copyrightHolder:"; then
    pass "SITE_VARIANTS entries contain 'copyrightHolder:' field"
  else
    fail "SITE_VARIANTS entries missing 'copyrightHolder:' field"
  fi

  # Check whatsapp field present in variants block
  if echo "$VARIANTS_BLOCK" | grep -q "whatsapp:"; then
    pass "SITE_VARIANTS entries contain 'whatsapp:' field"
  else
    fail "SITE_VARIANTS entries missing 'whatsapp:' field"
  fi

  # Sanity check: no null/undefined values in SITE_VARIANTS block
  if echo "$VARIANTS_BLOCK" | grep -qE ": null|: undefined"; then
    fail "SITE_VARIANTS contains null or undefined values"
  else
    pass "No null/undefined values in SITE_VARIANTS entries"
  fi

  # Check brand values are non-empty strings for each domain
  for domain in "academyv2.mereka.io" "academy.biji-biji.com" "skillourfuture.academy.mereka.io"; do
    DOMAIN_LINE=$(grep "'${domain}'" "$PLUGIN" || true)
    if echo "$DOMAIN_LINE" | grep -q "brand: '"; then
      pass "Domain '${domain}' has non-empty brand value"
    else
      fail "Domain '${domain}' missing or empty brand value"
    fi
    if echo "$DOMAIN_LINE" | grep -q "copyrightHolder: '"; then
      pass "Domain '${domain}' has non-empty copyrightHolder value"
    else
      fail "Domain '${domain}' missing or empty copyrightHolder value"
    fi
    if echo "$DOMAIN_LINE" | grep -q "whatsapp: '"; then
      pass "Domain '${domain}' has non-empty whatsapp value"
    else
      fail "Domain '${domain}' missing or empty whatsapp value"
    fi
  done
fi

echo ""

# -----------------------------------------------------------------------
# AC-FTVAR-003: Footer variant matrix doc exists with all domains documented
# -----------------------------------------------------------------------
echo "AC-FTVAR-003: Footer variant matrix document"

if [[ ! -f "$MATRIX_DOC" ]]; then
  fail "Matrix document missing: $MATRIX_DOC"
else
  pass "Matrix document exists: docs/operations/FOOTER_VARIANT_MATRIX.md"

  if grep -q "academyv2.mereka.io" "$MATRIX_DOC"; then
    pass "Matrix doc documents 'academyv2.mereka.io'"
  else
    fail "Matrix doc missing 'academyv2.mereka.io'"
  fi

  if grep -q "academy.biji-biji.com" "$MATRIX_DOC"; then
    pass "Matrix doc documents 'academy.biji-biji.com'"
  else
    fail "Matrix doc missing 'academy.biji-biji.com'"
  fi

  if grep -q "skillourfuture.academy.mereka.io" "$MATRIX_DOC"; then
    pass "Matrix doc documents 'skillourfuture.academy.mereka.io'"
  else
    fail "Matrix doc missing 'skillourfuture.academy.mereka.io'"
  fi

  if grep -q "Per-Domain Variant Matrix" "$MATRIX_DOC"; then
    pass "Matrix doc has 'Per-Domain Variant Matrix' section"
  else
    fail "Matrix doc missing 'Per-Domain Variant Matrix' section"
  fi

  if grep -q "Config-First Migration Path" "$MATRIX_DOC"; then
    pass "Matrix doc has 'Config-First Migration Path' section"
  else
    fail "Matrix doc missing 'Config-First Migration Path' section"
  fi

  if grep -q "Adding a New Domain" "$MATRIX_DOC"; then
    pass "Matrix doc has 'Adding a New Domain' section"
  else
    fail "Matrix doc missing 'Adding a New Domain' section"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-FTVAR-004: Fallback variant exists for unknown hostnames
# -----------------------------------------------------------------------
echo "AC-FTVAR-004: Fallback variant for unknown hostnames"

if [[ -f "$PLUGIN" ]]; then
  # The fallback is the || { brand: ... } expression on the variant line
  if grep -q "SITE_VARIANTS\[hostname\] ||" "$PLUGIN"; then
    pass "Fallback variant exists (|| operator after SITE_VARIANTS lookup)"
  else
    fail "Fallback variant missing — SITE_VARIANTS lookup has no || fallback"
  fi

  # Confirm fallback references config.SITE_NAME (dynamic, not hardcoded)
  FALLBACK_LINE=$(grep "SITE_VARIANTS\[hostname\]" "$PLUGIN" || true)
  if echo "$FALLBACK_LINE" | grep -q "config\.SITE_NAME\|config\.PLATFORM_NAME\|siteName"; then
    pass "Fallback variant uses dynamic config values (SITE_NAME / PLATFORM_NAME)"
  else
    warn "Fallback variant may not reference config.SITE_NAME — review line"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-FTVAR-005: DRY check — no domain strings outside SITE_VARIANTS inside
# MerekaFooter component body
# -----------------------------------------------------------------------
echo "AC-FTVAR-005: DRY check — domain strings confined to SITE_VARIANTS"

if [[ -f "$PLUGIN" ]]; then
  DOMAINS=("academyv2.mereka.io" "academy.biji-biji.com" "skillourfuture.academy.mereka.io")

  # Locate the line numbers of MerekaFooter and its closing line
  FOOTER_START=$(grep -nF "const MerekaFooter = ()" "$PLUGIN" | head -1 | cut -d: -f1)
  # Find the first standalone "};" after the footer start (handle CRLF line endings)
  FOOTER_END=$(awk -v start="$FOOTER_START" 'NR > start && /^};\r?$/ { print NR; exit }' "$PLUGIN")

  if [[ -z "$FOOTER_START" || -z "$FOOTER_END" ]]; then
    fail "Could not locate MerekaFooter function boundaries for DRY check"
  else
    # Extract the MerekaFooter body using line numbers (exact, no pattern-stop ambiguity)
    FOOTER_BODY=$(awk -v s="$FOOTER_START" -v e="$FOOTER_END" 'NR>=s && NR<=e' "$PLUGIN")

    # Extract the SITE_VARIANTS block within that body
    VARIANTS_BLOCK=$(echo "$FOOTER_BODY" | awk '/const SITE_VARIANTS = \{/,/^\s*\};/')

    for domain in "${DOMAINS[@]}"; do
      TOTAL_COUNT=$(echo "$FOOTER_BODY" | grep -cF "$domain" || true)
      VARIANTS_COUNT=$(echo "$VARIANTS_BLOCK" | grep -cF "$domain" || true)
      OUTSIDE_COUNT=$((TOTAL_COUNT - VARIANTS_COUNT))

      if [[ "$OUTSIDE_COUNT" -le 0 ]]; then
        pass "Domain '${domain}' only appears inside SITE_VARIANTS in MerekaFooter (DRY)"
      else
        fail "Domain '${domain}' appears ${OUTSIDE_COUNT} time(s) outside SITE_VARIANTS in MerekaFooter (DRY violation)"
      fi
    done
  fi
fi

echo ""
echo "Footer variant matrix: $PASS PASS / $FAIL FAIL / $WARN WARN"
exit $((FAIL > 0 ? 1 : 0))
