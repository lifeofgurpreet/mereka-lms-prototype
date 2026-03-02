#!/usr/bin/env bash
set -euo pipefail
# @spec: bead-115d9
# @covers AC-TEN-001, AC-TEN-002, AC-TEN-003, AC-TEN-004
#
# Verifies the tenant branding matrix document and SITE_VARIANTS map are
# consistent, each domain entry is complete, and rollback/migration docs exist.

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }
warn() { WARN=$((WARN + 1)); echo "  WARN: $1"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"
PLUGIN_BUNDLE=""
PLUGIN="$PLUGIN_MAIN"
MATRIX_DOC="$REPO_ROOT/docs/operations/TENANT_BRANDING_MATRIX.md"
FOOTER_MATRIX="$REPO_ROOT/docs/operations/FOOTER_VARIANT_MATRIX.md"
TOKENS_CSS="$REPO_ROOT/assets/branding/tokens.css"

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

PRODUCTION_DOMAINS=(
  "academyv2.mereka.io"
  "academy.biji-biji.com"
  "skillourfuture.academy.mereka.io"
)

echo "========================================"
echo "Tenant Branding Matrix Verifier"
echo "========================================"
echo ""

# -----------------------------------------------------------------------
# AC-TEN-001: TENANT_BRANDING_MATRIX.md exists, has >= 2 domain rows,
#             and all required columns are present
# -----------------------------------------------------------------------
echo "AC-TEN-001: Tenant branding matrix document with >= 2 domains and all columns"

if [[ ! -f "$MATRIX_DOC" ]]; then
  fail "TENANT_BRANDING_MATRIX.md missing: $MATRIX_DOC"
else
  pass "TENANT_BRANDING_MATRIX.md exists"

  # Count domain rows in the registry table (lines starting with | ` or containing .io / .com)
  DOMAIN_ROW_COUNT=$(grep -cE '^\| `[a-z]' "$MATRIX_DOC" || true)
  if [[ "$DOMAIN_ROW_COUNT" -ge 2 ]]; then
    pass "Matrix document has >= 2 tenant domain rows (found ${DOMAIN_ROW_COUNT})"
  else
    fail "Matrix document has < 2 tenant domain rows (found ${DOMAIN_ROW_COUNT})"
  fi

  # Check required columns are present in the table header
  for col in "Domain" "Brand Name" "Copyright Holder" "WhatsApp" "Logo" "Tokens Override" "Footer Variant"; do
    if grep -q "$col" "$MATRIX_DOC"; then
      pass "Column '${col}' present in matrix table"
    else
      fail "Column '${col}' missing from matrix table"
    fi
  done

  # Check at least 2 production domains are documented
  DOCUMENTED_COUNT=0
  for domain in "${PRODUCTION_DOMAINS[@]}"; do
    if grep -q "$domain" "$MATRIX_DOC"; then
      DOCUMENTED_COUNT=$((DOCUMENTED_COUNT + 1))
    fi
  done
  if [[ "$DOCUMENTED_COUNT" -ge 2 ]]; then
    pass "At least 2 production domains documented in matrix (${DOCUMENTED_COUNT} found)"
  else
    fail "Fewer than 2 production domains documented in matrix (${DOCUMENTED_COUNT} found)"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-TEN-002: SITE_VARIANTS has >= 2 entries + fallback;
#             tokens.css exists as global theme source
# -----------------------------------------------------------------------
echo "AC-TEN-002: Override inheritance — SITE_VARIANTS entries + fallback + global tokens"

if [[ ! -f "$PLUGIN" ]]; then
  fail "Plugin file missing: $PLUGIN"
else
  pass "Plugin contract source exists: $PLUGIN_MAIN"

  # Extract SITE_VARIANTS block (handle both MEREKA_SITE_VARIANTS and SITE_VARIANTS)
  VARIANTS_BLOCK=$(awk '/const (MEREKA_)?SITE_VARIANTS = \{/,/^\s*\};/' "$PLUGIN")

  # Count domain entries in SITE_VARIANTS block
  VARIANT_COUNT=$(echo "$VARIANTS_BLOCK" | grep -cE "'^[a-z]" || \
    echo "$VARIANTS_BLOCK" | grep -c "mereka\|biji-biji\|skillourfuture" || true)
  # More reliable: count lines with domain key pattern (single-quoted hostname keys)
  VARIANT_COUNT=$(echo "$VARIANTS_BLOCK" | grep -cE "'\S+\.\S+'" || true)

  if [[ "$VARIANT_COUNT" -ge 2 ]]; then
    pass "SITE_VARIANTS has >= 2 domain entries (found ${VARIANT_COUNT})"
  else
    fail "SITE_VARIANTS has fewer than 2 domain entries (found ${VARIANT_COUNT})"
  fi

  # Verify fallback exists
  if grep -qE "(MEREKA_)?SITE_VARIANTS\[" "$PLUGIN"; then
    pass "SITE_VARIANTS fallback exists (variant lookup present)"
  else
    fail "SITE_VARIANTS fallback missing — no variant lookup found"
  fi

  # Verify fallback references dynamic config values (not hardcoded)
  FALLBACK_LINE=$(grep -E "(MEREKA_)?SITE_VARIANTS\[" "$PLUGIN" || true)
  if echo "$FALLBACK_LINE" | grep -qE "config\.SITE_NAME|config\.PLATFORM_NAME|siteName"; then
    pass "Fallback references dynamic config values (not hardcoded brand string)"
  else
    warn "Fallback may not reference config.SITE_NAME — review fallback line in plugin"
  fi
fi

# Verify global tokens.css exists as the base theme source
if [[ ! -f "$TOKENS_CSS" ]]; then
  fail "Global design tokens missing: assets/branding/tokens.css"
else
  pass "Global design tokens exist: assets/branding/tokens.css"

  # Confirm it has :root block (is a real CSS custom properties file)
  if grep -q ":root" "$TOKENS_CSS"; then
    pass "tokens.css contains :root selector (valid CSS custom properties)"
  else
    fail "tokens.css missing :root selector"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-TEN-003: Each domain in SITE_VARIANTS has non-empty brand/
#             copyrightHolder/whatsapp; cross-checked vs FOOTER_VARIANT_MATRIX.md
# -----------------------------------------------------------------------
echo "AC-TEN-003: Brand token + footer rendering fields non-empty per domain"

if [[ -f "$PLUGIN" ]]; then
  # Extract MEREKA_BASE_VARIANT block for spread-operator inheritance checks
  BASE_VARIANT_BLOCK=$(awk '/const MEREKA_BASE_VARIANT = \{/,/^\s*\};/' "$PLUGIN" || true)

  for domain in "${PRODUCTION_DOMAINS[@]}"; do
    # Extract the multi-line block for this domain (from 'domain': { to next },)
    DOMAIN_BLOCK=$(awk "/'${domain}'/"'{found=1} found; /\},/{if(found) exit}' "$PLUGIN" || true)

    if [[ -z "$DOMAIN_BLOCK" ]]; then
      fail "Domain '${domain}' not found in SITE_VARIANTS"
      continue
    fi

    # Check for brand: either directly or inherited via ...MEREKA_BASE_VARIANT
    if echo "$DOMAIN_BLOCK" | grep -qE "brand: '[^']+'" ; then
      pass "Domain '${domain}' has non-empty brand value"
    else
      fail "Domain '${domain}' missing or empty brand value"
    fi

    # Check copyrightHolder: either directly or inherited
    if echo "$DOMAIN_BLOCK" | grep -qE "copyrightHolder: '[^']+'" ; then
      pass "Domain '${domain}' has non-empty copyrightHolder value"
    else
      fail "Domain '${domain}' missing or empty copyrightHolder value"
    fi

    # Check whatsapp: directly on domain block or inherited from MEREKA_BASE_VARIANT
    if echo "$DOMAIN_BLOCK" | grep -qE "whatsapp: '[0-9]+'" ; then
      pass "Domain '${domain}' has non-empty whatsapp number"
    elif echo "$DOMAIN_BLOCK" | grep -qF "...MEREKA_BASE_VARIANT" && \
         echo "$BASE_VARIANT_BLOCK" | grep -qE "whatsapp: '[0-9]+'" ; then
      pass "Domain '${domain}' inherits whatsapp from MEREKA_BASE_VARIANT"
    else
      fail "Domain '${domain}' missing or empty whatsapp value"
    fi
  done

  # Cross-check: verify each production domain also appears in FOOTER_VARIANT_MATRIX.md
  if [[ -f "$FOOTER_MATRIX" ]]; then
    for domain in "${PRODUCTION_DOMAINS[@]}"; do
      if grep -q "$domain" "$FOOTER_MATRIX"; then
        pass "Domain '${domain}' cross-referenced in FOOTER_VARIANT_MATRIX.md"
      else
        warn "Domain '${domain}' not found in FOOTER_VARIANT_MATRIX.md — matrices may be out of sync"
      fi
    done
  else
    warn "FOOTER_VARIANT_MATRIX.md not found — skipping cross-check"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-TEN-004: Migration/rollback documentation present in matrix doc
# -----------------------------------------------------------------------
echo "AC-TEN-004: Migration note + rollback plan documented"

if [[ ! -f "$MATRIX_DOC" ]]; then
  fail "TENANT_BRANDING_MATRIX.md missing — cannot check AC-TEN-004"
else
  if grep -q "Rollback Plan" "$MATRIX_DOC"; then
    pass "Matrix doc has 'Rollback Plan' section"
  else
    fail "Matrix doc missing 'Rollback Plan' section"
  fi

  if grep -q "Adding a New Tenant" "$MATRIX_DOC"; then
    pass "Matrix doc has 'Adding a New Tenant' section (operator checklist)"
  else
    fail "Matrix doc missing 'Adding a New Tenant' section"
  fi

  if grep -q "Migration Note\|migration note\|existing tenants\|Existing Tenants" "$MATRIX_DOC"; then
    pass "Matrix doc includes migration note for existing tenants"
  else
    fail "Matrix doc missing migration note for existing tenants"
  fi

  if grep -q "fallback\|Fallback" "$MATRIX_DOC"; then
    pass "Matrix doc documents fallback inheritance behaviour"
  else
    fail "Matrix doc missing fallback chain documentation"
  fi
fi

echo ""
echo "========================================"
echo "Tenant Branding Matrix: $PASS PASS / $FAIL FAIL / $WARN WARN"
echo "========================================"
exit $((FAIL > 0 ? 1 : 0))
