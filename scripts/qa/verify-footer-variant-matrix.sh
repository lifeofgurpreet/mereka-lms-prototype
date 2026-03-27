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
RUNTIME_DEFS="$REPO_ROOT/infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js"
MATRIX_DOC="$REPO_ROOT/docs/reference/operations/FOOTER_VARIANT_MATRIX.md"

echo "========================================"
echo "Footer Variant Matrix Verifier"
echo "========================================"
echo ""

# -----------------------------------------------------------------------
# AC-FTVAR-001: MEREKA_SITE_VARIANTS map contains all 3 production domains
# -----------------------------------------------------------------------
echo "AC-FTVAR-001: MEREKA_SITE_VARIANTS contains all 3 production domains"

if [[ ! -f "$RUNTIME_DEFS" ]]; then
  fail "Canonical footer runtime definitions missing: $RUNTIME_DEFS"
else
  pass "Canonical footer runtime definitions exist: infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js"

  if grep -q "'academyv2.mereka.io'" "$RUNTIME_DEFS"; then
    pass "MEREKA_SITE_VARIANTS contains 'academyv2.mereka.io'"
  else
    fail "MEREKA_SITE_VARIANTS missing 'academyv2.mereka.io'"
  fi

  if grep -q "'academy.biji-biji.com'" "$RUNTIME_DEFS"; then
    pass "MEREKA_SITE_VARIANTS contains 'academy.biji-biji.com'"
  else
    fail "MEREKA_SITE_VARIANTS missing 'academy.biji-biji.com'"
  fi

  if grep -q "'skillourfuture.academy.mereka.io'" "$RUNTIME_DEFS"; then
    pass "MEREKA_SITE_VARIANTS contains 'skillourfuture.academy.mereka.io'"
  else
    fail "MEREKA_SITE_VARIANTS missing 'skillourfuture.academy.mereka.io'"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-FTVAR-002: Each variant has brand, copyrightHolder, whatsapp fields
# -----------------------------------------------------------------------
echo "AC-FTVAR-002: Each variant has required fields (no nulls)"

if [[ -f "$RUNTIME_DEFS" ]]; then
  # Extract the MEREKA_SITE_VARIANTS block.
  VARIANTS_BLOCK=$(awk '/const MEREKA_SITE_VARIANTS = \{/,/^\s*\};/' "$RUNTIME_DEFS")

  # Check brand field present in variants block
  if echo "$VARIANTS_BLOCK" | grep -q "brand:"; then
    pass "MEREKA_SITE_VARIANTS entries contain 'brand:' field"
  else
    fail "MEREKA_SITE_VARIANTS entries missing 'brand:' field"
  fi

  # Check copyrightHolder field present in variants block
  if echo "$VARIANTS_BLOCK" | grep -q "copyrightHolder:"; then
    pass "MEREKA_SITE_VARIANTS entries contain 'copyrightHolder:' field"
  else
    fail "MEREKA_SITE_VARIANTS entries missing 'copyrightHolder:' field"
  fi

  # Check whatsapp field present in variants block or base variant (via spread)
  if echo "$VARIANTS_BLOCK" | grep -q "whatsapp:"; then
    pass "MEREKA_SITE_VARIANTS entries contain 'whatsapp:' field"
  elif grep -q "MEREKA_BASE_VARIANT" "$RUNTIME_DEFS" && grep -q "whatsapp:" "$RUNTIME_DEFS"; then
    pass "MEREKA_SITE_VARIANTS inherits 'whatsapp:' from MEREKA_BASE_VARIANT"
  else
    fail "MEREKA_SITE_VARIANTS entries missing 'whatsapp:' field"
  fi

  # Sanity check: no null/undefined values in variant block
  if echo "$VARIANTS_BLOCK" | grep -qE ": null|: undefined"; then
    fail "MEREKA_SITE_VARIANTS contains null or undefined values"
  else
    pass "No null/undefined values in MEREKA_SITE_VARIANTS entries"
  fi

# Check brand values are non-empty strings for each domain
extract_variant_field() {
  local domain="$1"
  local field_name="$2"
  python3 - "$RUNTIME_DEFS" "$domain" "$field_name" <<'PY'
import re
import sys

path, domain, field = sys.argv[1:4]
text = open(path, encoding="utf-8").read()

block_match = re.search(r"const MEREKA_SITE_VARIANTS = \{(.*?)\n\s*\};", text, re.S)
if not block_match:
    raise SystemExit(1)

variants = block_match.group(1)
entry_pattern = rf"['\"]{re.escape(domain)}['\"]\s*:\s*\{{(.*?)\n\s*\}},"
entry_match = re.search(entry_pattern, variants, re.S)
if not entry_match:
    raise SystemExit(2)

entry = entry_match.group(1)
pattern = rf"{re.escape(field)}\s*:\s*'([^'\\]|\\.)*'"
field_match = re.search(pattern, entry)
if field_match:
    value = re.search(r"'([^'\\]|\\.)*'", field_match.group(0)).group(0)[1:-1]
    if value:
        print("found")
    else:
        raise SystemExit(4)
elif "...MEREKA_BASE_VARIANT" in entry:
    # Field may be inherited from base variant via spread operator
    base_match = re.search(r"const MEREKA_BASE_VARIANT = \{(.*?)\n\s*\};", text, re.S)
    if base_match:
        base_field = re.search(pattern, base_match.group(1))
        if base_field:
            print("found (inherited)")
        else:
            raise SystemExit(3)
    else:
        raise SystemExit(3)
else:
    raise SystemExit(3)
PY
}

for domain in "academyv2.mereka.io" "academy.biji-biji.com" "skillourfuture.academy.mereka.io"; do
    if extract_variant_field "$domain" "brand" >/dev/null 2>&1; then
      pass "Domain '${domain}' has non-empty brand value"
    else
      fail "Domain '${domain}' missing or empty brand value"
    fi

    if extract_variant_field "$domain" "copyrightHolder" >/dev/null 2>&1; then
      pass "Domain '${domain}' has non-empty copyrightHolder value"
    else
      fail "Domain '${domain}' missing or empty copyrightHolder value"
    fi

    if extract_variant_field "$domain" "whatsapp" >/dev/null 2>&1; then
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
  pass "Matrix document exists: docs/reference/operations/FOOTER_VARIANT_MATRIX.md"

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

  if grep -q "_mereka_lms/mfe_runtime_definitions.js" "$MATRIX_DOC" \
    && grep -q "MEREKA_SITE_VARIANTS" "$MATRIX_DOC"; then
    pass "Matrix doc points to the canonical runtime definitions module and MEREKA_SITE_VARIANTS"
  else
    fail "Matrix doc missing canonical runtime definitions reference (_mereka_lms/mfe_runtime_definitions.js + MEREKA_SITE_VARIANTS)"
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

if [[ -f "$RUNTIME_DEFS" ]]; then
  # Current architecture resolves canonical LMS hostnames first, then derives
  # MFE/staging candidates, then falls back to a deterministic default shell.
  if grep -q "const exactVariant = MEREKA_SITE_VARIANTS\\[normalizedHostname\\]" "$RUNTIME_DEFS" \
    && grep -q "for (const candidate of deriveVariantCandidates(normalizedHostname))" "$RUNTIME_DEFS" \
    && grep -q "const variant = MEREKA_SITE_VARIANTS\\[candidate\\]" "$RUNTIME_DEFS" \
    && grep -q "Unknown host fallback" "$RUNTIME_DEFS"; then
    pass "Fallback variant exists in getMerekaVariant() (exact match + derived candidate lookup + explicit fallback)"
  else
    fail "Fallback variant missing — expected exact match, derived candidate lookup, and explicit unknown-host fallback in getMerekaVariant()"
  fi

  # Confirm fallback references dynamic config values (SITE_NAME / PLATFORM_NAME).
  if grep -q "fallbackBrand.*config\\.SITE_NAME" "$RUNTIME_DEFS" \
    && grep -q "fallbackPlatform.*config\\.PLATFORM_NAME" "$RUNTIME_DEFS"; then
    pass "Fallback variant uses dynamic config values (config.SITE_NAME / config.PLATFORM_NAME)"
  else
    warn "Fallback variant may not reference config.SITE_NAME/config.PLATFORM_NAME — review getMerekaVariant()"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-FTVAR-005: DRY check — no domain strings outside MEREKA_SITE_VARIANTS in the
# canonical footer runtime definitions module.
# -----------------------------------------------------------------------
echo "AC-FTVAR-005: DRY check — domain strings confined to MEREKA_SITE_VARIANTS"

if [[ -f "$RUNTIME_DEFS" ]]; then
  DOMAINS=("academyv2.mereka.io" "academy.biji-biji.com" "skillourfuture.academy.mereka.io")
  VARIANTS_BLOCK=$(awk '/const MEREKA_SITE_VARIANTS = \{/,/^\s*\};/' "$RUNTIME_DEFS")

  for domain in "${DOMAINS[@]}"; do
    TOTAL_COUNT=$(grep -cF "$domain" "$RUNTIME_DEFS" || true)
    VARIANTS_COUNT=$(echo "$VARIANTS_BLOCK" | grep -cF "$domain" || true)
    OUTSIDE_COUNT=$((TOTAL_COUNT - VARIANTS_COUNT))

    if [[ "$OUTSIDE_COUNT" -le 0 ]]; then
      pass "Domain '${domain}' only appears inside MEREKA_SITE_VARIANTS in mfe_runtime_definitions.js (DRY)"
    else
      fail "Domain '${domain}' appears ${OUTSIDE_COUNT} time(s) outside MEREKA_SITE_VARIANTS in mfe_runtime_definitions.js (DRY violation)"
    fi
  done
fi

echo ""
echo "Footer variant matrix: $PASS PASS / $FAIL FAIL / $WARN WARN"
exit $((FAIL > 0 ? 1 : 0))
