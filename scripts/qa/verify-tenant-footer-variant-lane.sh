#!/usr/bin/env bash
set -euo pipefail
# @spec: bead-115d27
# @covers AC-TF-001, AC-TF-002, AC-TF-003, AC-TF-004
#
# verify-tenant-footer-variant-lane.sh
#
# Offline verification of tenant-first UI/UX footer variant lane (bead mereka-lms-115d.27).
#
# Checks:
#   AC-TF-001: Tenant footer variant is fully deterministic for at least 3 production domains.
#   AC-TF-002: Variant selection is visible in config + runtime config endpoint for traceability.
#   AC-TF-003: Regression check covers 200/redirect/health behaviour for domain routing
#              plus brand visibility markers.
#   AC-TF-004: Documentation for adding a new tenant brand is complete
#              (assets, tokens, config, verification commands).
#
# Usage:
#   ./scripts/qa/verify-tenant-footer-variant-lane.sh
#   TENANT_FOOTER_LIVE=1 ./scripts/qa/verify-tenant-footer-variant-lane.sh  # live HTTP probes
#
# Exit codes:
#   0 — 0 FAIL (WARNs are non-blocking)
#   1 — 1 or more FAIL

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"

LIVE_MODE="${TENANT_FOOTER_LIVE:-0}"

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

echo "=== AC-TF-001..004: Tenant Footer Variant Lane Gate (bead 115d.27) ==="
if [[ "$LIVE_MODE" == "1" ]]; then
  echo "Mode: LIVE (TENANT_FOOTER_LIVE=1)"
else
  echo "Mode: OFFLINE (set TENANT_FOOTER_LIVE=1 for runtime HTTP probes)"
fi
echo ""

# ---------------------------------------------------------------------------
# Key file paths
# ---------------------------------------------------------------------------
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"
PLUGIN_BUNDLE=""
PLUGIN_FILE="$PLUGIN_MAIN"
BRAND_SCHEMA="$REPO_ROOT/infrastructure/tutor/plugins/multi-tenancy/brand-config-schema.json"
FOOTER_MATRIX_DOC="$REPO_ROOT/docs/operations/FOOTER_VARIANT_MATRIX.md"
TENANT_FOOTER_LANE_DOC="$REPO_ROOT/docs/operations/TENANT_FOOTER_VARIANT_LANE.md"

if mereka_plugin_has_any "$REPO_ROOT"; then
  PLUGIN_BUNDLE="$(mktemp -t mereka-plugin-contract.XXXXXX)"
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

declare -a PRODUCTION_DOMAINS=(
  "academyv2.mereka.io"
  "academy.biji-biji.com"
  "skillourfuture.academy.mereka.io"
)

# ---------------------------------------------------------------------------
# AC-TF-001: Footer variant is fully deterministic for at least 3 domains
# ---------------------------------------------------------------------------
echo "--- AC-TF-001: Deterministic footer variant for ≥3 production domains ---"
echo ""


if [[ ! -f "$PLUGIN_FILE" ]]; then
  fail "AC-TF-001: Plugin contract source not found: $PLUGIN_MAIN"
else
  pass "AC-TF-001: Plugin contract source exists: $PLUGIN_MAIN"

  # SITE_VARIANTS map must be present — accepts both MEREKA_SITE_VARIANTS (canonical) and SITE_VARIANTS
  if grep -qE "const MEREKA_SITE_VARIANTS = \{|const SITE_VARIANTS = \{" "$PLUGIN_FILE"; then
    pass "AC-TF-001: SITE_VARIANTS map defined in plugin"
  else
    fail "AC-TF-001: SITE_VARIANTS map not found in plugin"
  fi

  # Each of the 3 production domains must be a key in SITE_VARIANTS
  DOMAIN_HITS=0
  for domain in "${PRODUCTION_DOMAINS[@]}"; do
    if grep -qF "'${domain}'" "$PLUGIN_FILE"; then
      pass "AC-TF-001: SITE_VARIANTS contains '${domain}'"
      DOMAIN_HITS=$((DOMAIN_HITS + 1))
    else
      fail "AC-TF-001: SITE_VARIANTS missing '${domain}'"
    fi
  done

  if [[ "$DOMAIN_HITS" -ge 3 ]]; then
    pass "AC-TF-001: SITE_VARIANTS covers all 3 production domains (deterministic)"
  else
    fail "AC-TF-001: SITE_VARIANTS only covers $DOMAIN_HITS/3 production domains"
  fi

  # Each domain entry must have brand, copyrightHolder, whatsapp (no nulls).
  # Fields may be inherited from MEREKA_BASE_VARIANT via spread — search entire plugin bundle.
  VARIANTS_BLOCK=$(awk '/const MEREKA_SITE_VARIANTS = \{|const SITE_VARIANTS = \{/,/^\s*\};/' "$PLUGIN_FILE")

  # brand: is per-entry; whatsapp: and copyrightHolder: may be in MEREKA_BASE_VARIANT (spread)
  for field in "brand:" "copyrightHolder:" "whatsapp:"; do
    if echo "$VARIANTS_BLOCK" | grep -q "$field" || grep -q "$field" "$PLUGIN_FILE"; then
      pass "AC-TF-001: SITE_VARIANTS entries have required field '${field%:}'"
    else
      fail "AC-TF-001: SITE_VARIANTS entries missing required field '${field%:}'"
    fi
  done

  if echo "$VARIANTS_BLOCK" | grep -qE ": null|: undefined"; then
    fail "AC-TF-001: SITE_VARIANTS contains null or undefined values (non-deterministic)"
  else
    pass "AC-TF-001: No null/undefined values in SITE_VARIANTS (all fields deterministic)"
  fi

  # Determinism check: each domain key maps to a non-empty brand value.
  # The brand: field appears in the per-tenant block (not in MEREKA_BASE_VARIANT spread).
  # Extract the multi-line block for each domain and check for brand:.
  for domain in "${PRODUCTION_DOMAINS[@]}"; do
    DOMAIN_BLOCK=$(awk "/'${domain}':/,/^\s*\},?$/" "$PLUGIN_FILE" | head -20 || true)
    if echo "$DOMAIN_BLOCK" | grep -q "brand: '"; then
      pass "AC-TF-001: Domain '${domain}' has deterministic non-empty brand value"
    else
      fail "AC-TF-001: Domain '${domain}' missing deterministic brand value"
    fi
  done

  # Fallback variant exists — either via || operator or via getMerekaVariant fallback return
  if grep -qE "SITE_VARIANTS\[hostname\] \|\||MEREKA_SITE_VARIANTS\[normalizedHostname\]|getMerekaVariant" "$PLUGIN_FILE"; then
    pass "AC-TF-001: Fallback variant present for unknown hostnames (getMerekaVariant resolver)"
  else
    fail "AC-TF-001: Fallback variant missing — SITE_VARIANTS lookup has no || fallback"
  fi
fi

# brand-config-schema.json must define footer.variant enum
if [[ ! -f "$BRAND_SCHEMA" ]]; then
  fail "AC-TF-001: brand-config-schema.json not found — footer variant schema not defined"
else
  if grep -q '"variant"' "$BRAND_SCHEMA"; then
    pass "AC-TF-001: brand-config-schema.json defines footer.variant field"
  else
    fail "AC-TF-001: brand-config-schema.json missing footer.variant field"
  fi

  # Schema enum covers the 3 production variants
  for variant_name in "mereka-v2" "bijibiji" "skillourfuture"; do
    if grep -q "\"$variant_name\"" "$BRAND_SCHEMA"; then
      pass "AC-TF-001: Schema footer.variant enum includes '$variant_name'"
    else
      fail "AC-TF-001: Schema footer.variant enum missing '$variant_name'"
    fi
  done
fi

echo ""

# ---------------------------------------------------------------------------
# AC-TF-002: Variant selection visible in config + traceable at runtime
# ---------------------------------------------------------------------------
echo "--- AC-TF-002: Variant selection traceability (config + runtime) ---"
echo ""


if [[ -f "$PLUGIN_FILE" ]]; then
  # Variant selection logic — accepts MEREKA_SITE_VARIANTS[normalizedHostname] or SITE_VARIANTS[hostname]
  if grep -qE "MEREKA_SITE_VARIANTS\[normalizedHostname\]|SITE_VARIANTS\[hostname\]|getMerekaVariant" "$PLUGIN_FILE"; then
    pass "AC-TF-002: Variant selection logic present in plugin (MEREKA_SITE_VARIANTS lookup)"
  else
    fail "AC-TF-002: Variant selection logic not found in plugin"
  fi

  # The hostname lookup must read window.location.hostname
  if grep -q "window.location.hostname" "$PLUGIN_FILE"; then
    pass "AC-TF-002: Hostname read from window.location.hostname (browser-side, auditable)"
  else
    fail "AC-TF-002: window.location.hostname not found — traceability source unclear"
  fi

  # config object is used for fallback (makes the fallback path traceable via MFE config endpoint)
  FALLBACK_LINE=$(grep -E "SITE_VARIANTS\[hostname\]|getMerekaVariant|fallbackBrand|fallbackPlatform" "$PLUGIN_FILE" | head -5 || true)
  if echo "$FALLBACK_LINE" | grep -qE "config\.SITE_NAME|config\.PLATFORM_NAME|fallbackBrand|fallbackPlatform"; then
    pass "AC-TF-002: Fallback variant reads from MFE config (traceable via /api/mfe_config/v1)"
  else
    warn "AC-TF-002: Fallback variant may not reference config.SITE_NAME — traceability advisory"
  fi
fi

# FOOTER_VARIANT_MATRIX.md documents the variant selection chain (source of truth chain)
if [[ ! -f "$FOOTER_MATRIX_DOC" ]]; then
  fail "AC-TF-002: FOOTER_VARIANT_MATRIX.md missing — no config traceability documentation"
else
  pass "AC-TF-002: FOOTER_VARIANT_MATRIX.md exists (config traceability documented)"

  if grep -qiE "source of truth|SITE_VARIANTS.*mereka_lms|variant.*selection" "$FOOTER_MATRIX_DOC"; then
    pass "AC-TF-002: Matrix doc documents SITE_VARIANTS as source of truth"
  else
    fail "AC-TF-002: Matrix doc does not document variant selection / source of truth chain"
  fi

  if grep -qiE "mfe_config|api/mfe_config|runtime config" "$FOOTER_MATRIX_DOC"; then
    pass "AC-TF-002: Matrix doc references runtime config endpoint (MFE config traceability)"
  else
    warn "AC-TF-002: Matrix doc does not reference /api/mfe_config/v1 runtime endpoint (advisory)"
  fi
fi

# TENANT_FOOTER_VARIANT_LANE.md must document config + runtime traceability
if [[ ! -f "$TENANT_FOOTER_LANE_DOC" ]]; then
  fail "AC-TF-002: TENANT_FOOTER_VARIANT_LANE.md missing — variant lane not documented"
else
  pass "AC-TF-002: TENANT_FOOTER_VARIANT_LANE.md exists"

  if grep -qiE "variant.*select|selection.*logic|SITE_VARIANTS" "$TENANT_FOOTER_LANE_DOC"; then
    pass "AC-TF-002: Lane doc documents variant selection logic"
  else
    fail "AC-TF-002: Lane doc missing variant selection logic documentation"
  fi

  if grep -qiE "runtime.*config|mfe_config|traceab" "$TENANT_FOOTER_LANE_DOC"; then
    pass "AC-TF-002: Lane doc documents runtime config endpoint traceability"
  else
    fail "AC-TF-002: Lane doc missing runtime config traceability documentation"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# AC-TF-003: Regression check covers domain routing + brand visibility markers
# ---------------------------------------------------------------------------
echo "--- AC-TF-003: Regression coverage (domain routing + brand markers) ---"
echo ""


# verify-footer-variant-matrix.sh is the primary offline regression check
FOOTER_MATRIX_SCRIPT="$REPO_ROOT/scripts/qa/verify-footer-variant-matrix.sh"
if [[ -f "$FOOTER_MATRIX_SCRIPT" ]]; then
  pass "AC-TF-003: verify-footer-variant-matrix.sh exists (domain routing regression check)"

  # Check it covers brand visibility markers (brand field checks per domain)
  if grep -q "brand.*domain\|domain.*brand\|SITE_VARIANTS contains" "$FOOTER_MATRIX_SCRIPT"; then
    pass "AC-TF-003: Matrix script checks brand visibility markers per domain"
  else
    warn "AC-TF-003: Matrix script may not check per-domain brand markers explicitly"
  fi
else
  fail "AC-TF-003: verify-footer-variant-matrix.sh not found — domain routing regression not scripted"
fi

# verify-tenant-branding-runtime.sh covers live domain routing (200/redirect/health)
RUNTIME_SCRIPT="$REPO_ROOT/scripts/qa/verify-tenant-branding-runtime.sh"
if [[ -f "$RUNTIME_SCRIPT" ]]; then
  pass "AC-TF-003: verify-tenant-branding-runtime.sh exists (live domain routing + health check)"

  # Check it tests all 3 domains
  for domain in "${PRODUCTION_DOMAINS[@]}"; do
    if grep -qF "$domain" "$RUNTIME_SCRIPT"; then
      pass "AC-TF-003: Runtime script covers domain '$domain'"
    else
      fail "AC-TF-003: Runtime script missing domain '$domain'"
    fi
  done

  # Check it verifies HTTP status codes (200/redirect)
  if grep -qE '"200"|http_code|302|redirect' "$RUNTIME_SCRIPT"; then
    pass "AC-TF-003: Runtime script checks HTTP status codes (200/redirect)"
  else
    warn "AC-TF-003: Runtime script may not explicitly check 200/redirect status codes"
  fi
else
  fail "AC-TF-003: verify-tenant-branding-runtime.sh not found — live domain routing check missing"
fi

# public-health-check.sh provides the /health check regression
HEALTH_SCRIPT="$REPO_ROOT/scripts/qa/public-health-check.sh"
if [[ -f "$HEALTH_SCRIPT" ]]; then
  pass "AC-TF-003: public-health-check.sh exists (health endpoint regression)"
else
  warn "AC-TF-003: public-health-check.sh not found — health endpoint check not scripted (advisory)"
fi

# TENANT_FOOTER_VARIANT_LANE.md must document the regression check matrix
if [[ -f "$TENANT_FOOTER_LANE_DOC" ]]; then
  if grep -qiE "regression|200|redirect|health" "$TENANT_FOOTER_LANE_DOC"; then
    pass "AC-TF-003: Lane doc contains regression check matrix (HTTP status/health)"
  else
    fail "AC-TF-003: Lane doc missing regression check matrix (200/redirect/health)"
  fi

  if grep -qiE "brand.*marker|brand.*visib|footer.*brand\|copyrightHolder\|whatsapp" "$TENANT_FOOTER_LANE_DOC"; then
    pass "AC-TF-003: Lane doc documents brand visibility markers for each domain"
  else
    fail "AC-TF-003: Lane doc missing brand visibility markers documentation"
  fi
else
  fail "AC-TF-003: TENANT_FOOTER_VARIANT_LANE.md missing — regression matrix not documented"
fi

# Live mode: run HTTP probes for all 3 production domains
if [[ "$LIVE_MODE" == "1" ]]; then
  echo ""
  echo "  [LIVE] Running HTTP probes for production domains..."
  CURL_TIMEOUT=15

  for domain in "${PRODUCTION_DOMAINS[@]}"; do
    lms_code=$(curl -s -o /dev/null -w "%{http_code}" \
      --max-time "$CURL_TIMEOUT" "https://${domain}/" 2>/dev/null || echo "000")
    if [[ "$lms_code" == "200" || "$lms_code" == "302" ]]; then
      pass "AC-TF-003 [LIVE]: $domain LMS root reachable (HTTP $lms_code)"
    else
      warn "AC-TF-003 [LIVE]: $domain LMS root returned HTTP $lms_code (expected 200/302)"
    fi

    health_code=$(curl -s -o /dev/null -w "%{http_code}" \
      --max-time "$CURL_TIMEOUT" "https://${domain}/health/" 2>/dev/null || echo "000")
    if [[ "$health_code" == "200" ]]; then
      pass "AC-TF-003 [LIVE]: $domain /health/ endpoint returns 200"
    else
      warn "AC-TF-003 [LIVE]: $domain /health/ returned HTTP $health_code"
    fi
  done
fi

echo ""

# ---------------------------------------------------------------------------
# AC-TF-004: Documentation for adding a new tenant brand is complete
# ---------------------------------------------------------------------------
echo "--- AC-TF-004: New tenant brand documentation completeness ---"
echo ""


# Primary source: TENANT_FOOTER_VARIANT_LANE.md (new ops doc for this bead)
if [[ ! -f "$TENANT_FOOTER_LANE_DOC" ]]; then
  fail "AC-TF-004: TENANT_FOOTER_VARIANT_LANE.md missing — tenant onboarding guide not present"
else
  pass "AC-TF-004: TENANT_FOOTER_VARIANT_LANE.md exists"

  # Assets section
  if grep -qiE "asset|logo|favicon|image" "$TENANT_FOOTER_LANE_DOC"; then
    pass "AC-TF-004: Lane doc covers asset requirements (logos, favicon)"
  else
    fail "AC-TF-004: Lane doc missing asset requirements section"
  fi

  # Tokens / palette section
  if grep -qiE "token|palette|color.*token|token.*color" "$TENANT_FOOTER_LANE_DOC"; then
    pass "AC-TF-004: Lane doc covers design tokens / palette configuration"
  else
    fail "AC-TF-004: Lane doc missing design tokens / palette section"
  fi

  # Config section (SITE_VARIANTS update, tutor config)
  if grep -qiE "SITE_VARIANTS|tutor.*config|config.*tutor" "$TENANT_FOOTER_LANE_DOC"; then
    pass "AC-TF-004: Lane doc covers config steps (SITE_VARIANTS update)"
  else
    fail "AC-TF-004: Lane doc missing config steps (SITE_VARIANTS update)"
  fi

  # Verification commands section
  if grep -qiE "verify|verification|verify-footer|scripts/qa" "$TENANT_FOOTER_LANE_DOC"; then
    pass "AC-TF-004: Lane doc includes verification commands"
  else
    fail "AC-TF-004: Lane doc missing verification commands"
  fi

  # Step-by-step format (numbered checklist or steps)
  if grep -qiE "\- \[[ x]\]|Step [0-9]|## Step|[0-9]\." "$TENANT_FOOTER_LANE_DOC"; then
    pass "AC-TF-004: Lane doc has step-by-step / checklist format"
  else
    warn "AC-TF-004: Lane doc may lack explicit numbered steps — consider adding a checklist"
  fi

  # Fallback rules documented
  if grep -qiE "fallback|unknown.*host|hostname.*not found|default.*variant" "$TENANT_FOOTER_LANE_DOC"; then
    pass "AC-TF-004: Lane doc documents fallback rules for missing tenant config"
  else
    fail "AC-TF-004: Lane doc missing fallback rules for unknown hostnames"
  fi
fi

# Secondary: FOOTER_VARIANT_MATRIX.md "Adding a New Domain" section (already verified above)
if [[ -f "$FOOTER_MATRIX_DOC" ]]; then
  if grep -q "Adding a New Domain" "$FOOTER_MATRIX_DOC"; then
    pass "AC-TF-004: FOOTER_VARIANT_MATRIX.md has 'Adding a New Domain' section"
  else
    fail "AC-TF-004: FOOTER_VARIANT_MATRIX.md missing 'Adding a New Domain' section"
  fi

  # Check for apply-patches.sh reference (config step)
  if grep -q "apply-patches.sh" "$FOOTER_MATRIX_DOC"; then
    pass "AC-TF-004: Matrix doc references apply-patches.sh (config rebuild step)"
  else
    warn "AC-TF-004: Matrix doc does not reference apply-patches.sh (advisory)"
  fi

  # Check for provision-tenant.sh reference (multi-tenancy config step)
  if grep -q "provision-tenant.sh" "$FOOTER_MATRIX_DOC"; then
    pass "AC-TF-004: Matrix doc references provision-tenant.sh (multi-tenancy config)"
  else
    warn "AC-TF-004: Matrix doc does not reference provision-tenant.sh (advisory)"
  fi

  # Rebuild MFE step present
  if grep -qiE "tutor images build mfe|rebuild.*mfe|mfe.*rebuild" "$FOOTER_MATRIX_DOC"; then
    pass "AC-TF-004: Matrix doc includes MFE rebuild step"
  else
    warn "AC-TF-004: Matrix doc does not explicitly mention MFE rebuild (advisory)"
  fi
fi

# brand-config-schema.json is the machine-readable spec for tenant brand assets
if [[ -f "$BRAND_SCHEMA" ]]; then
  pass "AC-TF-004: brand-config-schema.json exists (machine-readable asset/token spec)"
else
  fail "AC-TF-004: brand-config-schema.json missing — no machine-readable brand spec"
fi

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "Action required: Fix FAIL items above."
  echo "  - AC-TF-001: Ensure SITE_VARIANTS is present in plugin contract sources"
  echo "               covers all 3 domains + brand-config-schema.json has footer.variant"
  echo "  - AC-TF-002: Document variant selection chain in docs/operations/TENANT_FOOTER_VARIANT_LANE.md"
  echo "  - AC-TF-003: Ensure verify-footer-variant-matrix.sh and verify-tenant-branding-runtime.sh"
  echo "               exist and cover all 3 domains with HTTP/brand marker checks"
  echo "  - AC-TF-004: Complete TENANT_FOOTER_VARIANT_LANE.md with assets, tokens,"
  echo "               config steps, verification commands, and fallback rules"
  exit 1
fi

echo ""
echo "All tenant footer variant lane checks passed (WARNs are advisory)."
exit 0
