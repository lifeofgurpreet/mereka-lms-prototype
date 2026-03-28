#!/usr/bin/env bash
# @covers AC-MB-001, AC-MB-002, AC-MB-003, AC-MB-004, AC-MB-005, AC-MB-006
# @spec: bead-115d26
#
# verify-multitenant-brand-platform.sh
#
# Offline verification of the multitenant brand platform gate (bead mereka-lms-115d.26).
#
# Checks:
#   AC-MB-001: Tenant brand config model/schema exists (logos, palette, typography, footer, legal URLs)
#   AC-MB-002: Runtime fallback rules and validation logic for missing/invalid config
#   AC-MB-003: Per-tenant preview smoke paths documented and scripted
#   AC-MB-004: Contract tests present (no hard-coded global brand leakage)
#   AC-MB-005: SkillOurFuture migration guide exists
#   AC-MB-006: Governance documentation (who updates, approval process)
#
# Usage:
#   ./scripts/qa/verify-multitenant-brand-platform.sh
#   BRAND_LIVE=1 ./scripts/qa/verify-multitenant-brand-platform.sh  # also run HTTP probes
#
# Exit codes:
#   0 — 0 FAIL (WARNs are non-blocking)
#   1 — 1 or more FAIL
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"

LIVE_MODE="${BRAND_LIVE:-0}"

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

echo "=== AC-MB-001..006: Multitenant Brand Platform Gate ==="
if [[ "$LIVE_MODE" == "1" ]]; then
  echo "Mode: LIVE (BRAND_LIVE=1)"
else
  echo "Mode: OFFLINE (set BRAND_LIVE=1 for runtime HTTP probes)"
fi
echo ""

# ---------------------------------------------------------------------------
# Key file paths
# ---------------------------------------------------------------------------
BRAND_SCHEMA="$REPO_ROOT/infrastructure/tutor/plugins/multi-tenancy/brand-config-schema.json"
BRAND_PLATFORM_DOC="$REPO_ROOT/docs/reference/operations/MULTITENANT_BRAND_PLATFORM.md"
SOF_MIGRATION_DOC="$REPO_ROOT/docs/ops/runbooks/migrations/SKILLOURFUTURE_BRAND_MIGRATION.md"
MULTISITE_GOV="$REPO_ROOT/docs/policies/operations/MULTISITE_GOVERNANCE.md"
TENANT_MODEL="$REPO_ROOT/infrastructure/tutor/plugins/multi-tenancy/models.py"
FOOTER_MATRIX_SCRIPT="$REPO_ROOT/scripts/qa/verify-footer-variant-matrix.sh"
BRANDING_CONTRACT_SCRIPT="$REPO_ROOT/scripts/qa/verify-tenant-branding-contract.sh"
ISOLATION_SCRIPT="$REPO_ROOT/scripts/qa/verify-tenant-isolation-evidence.sh"

declare -a TENANT_DOMAINS=(
  "academyv2.mereka.io"
  "academy.biji-biji.com"
  "skillourfuture.academy.mereka.io"
)

# ---------------------------------------------------------------------------
# AC-MB-001: Tenant brand config model/schema
# ---------------------------------------------------------------------------
echo "--- AC-MB-001: Tenant Brand Config Model / Schema ---"

if [[ ! -f "$BRAND_SCHEMA" ]]; then
  fail "AC-MB-001: brand-config-schema.json not found at infrastructure/tutor/plugins/multi-tenancy/brand-config-schema.json"
else
  pass "AC-MB-001: brand-config-schema.json exists"

  # Required top-level schema sections
  for section in "logos" "palette" "typography" "footer" "legal_doc_urls" "tenant_id" "display_name"; do
    if grep -q "\"$section\"" "$BRAND_SCHEMA"; then
      pass "AC-MB-001: schema defines '$section' field"
    else
      fail "AC-MB-001: schema missing '$section' field"
    fi
  done

  # Logo sub-fields
  for logo_field in "primary" "white" "favicon" "footer"; do
    if grep -q "\"$logo_field\"" "$BRAND_SCHEMA"; then
      pass "AC-MB-001: logos.$logo_field defined in schema"
    else
      fail "AC-MB-001: logos.$logo_field missing from schema"
    fi
  done

  # Palette sub-fields
  for color in "primary" "secondary" "accent" "background" "text"; do
    if grep -q "\"$color\"" "$BRAND_SCHEMA"; then
      pass "AC-MB-001: palette.$color defined in schema"
    else
      fail "AC-MB-001: palette.$color missing from schema"
    fi
  done

  # Typography sub-fields
  for typo in "font_family" "heading_font" "font_source_url"; do
    if grep -q "\"$typo\"" "$BRAND_SCHEMA"; then
      pass "AC-MB-001: typography.$typo defined in schema"
    else
      fail "AC-MB-001: typography.$typo missing from schema"
    fi
  done

  # Legal doc URL sub-fields
  for legal in "terms" "privacy"; do
    if grep -q "\"$legal\"" "$BRAND_SCHEMA"; then
      pass "AC-MB-001: legal_doc_urls.$legal defined in schema"
    else
      fail "AC-MB-001: legal_doc_urls.$legal missing from schema"
    fi
  done

  # Footer variant enum
  if grep -q "\"variant\"" "$BRAND_SCHEMA"; then
    pass "AC-MB-001: footer.variant field defined in schema"
  else
    fail "AC-MB-001: footer.variant missing from schema"
  fi

  # Schema has examples
  if grep -q '"examples"' "$BRAND_SCHEMA"; then
    pass "AC-MB-001: schema includes examples"
  else
    warn "AC-MB-001: schema has no examples — consider adding at least one"
  fi

  if grep -q 'PRIMARY_COLOR/SECONDARY_COLOR' "$BRAND_SCHEMA" && grep -q 'not a guaranteed live plugin-injected --mereka-color-\* runtime surface today' "$BRAND_SCHEMA"; then
    pass "AC-MB-001: schema distinguishes runtime MFE color keys from direct runtime CSS-var injection"
  else
    fail "AC-MB-001: schema still blurs runtime MFE color keys and direct CSS-var injection"
  fi
fi

# Django model has branding_config field
if [[ -f "$TENANT_MODEL" ]]; then
  if grep -q "branding_config" "$TENANT_MODEL"; then
    pass "AC-MB-001: TenantConfig.branding_config field exists in models.py"
  else
    fail "AC-MB-001: TenantConfig.branding_config field not found in models.py"
  fi
else
  warn "AC-MB-001: models.py not found — cannot verify TenantConfig.branding_config"
fi

# Platform doc covers the config model
if [[ -f "$BRAND_PLATFORM_DOC" ]]; then
  pass "AC-MB-001: MULTITENANT_BRAND_PLATFORM.md exists"
  if grep -qiE "brand config model|config model" "$BRAND_PLATFORM_DOC"; then
    pass "AC-MB-001: platform doc covers the brand config model"
  else
    fail "AC-MB-001: platform doc does not document the brand config model"
  fi
else
  fail "AC-MB-001: docs/reference/operations/MULTITENANT_BRAND_PLATFORM.md missing"
fi

echo ""

# ---------------------------------------------------------------------------
# AC-MB-002: Runtime fallback rules and validation logic
# ---------------------------------------------------------------------------
echo "--- AC-MB-002: Runtime Fallback Rules + Validation Logic ---"

if [[ -f "$BRAND_PLATFORM_DOC" ]]; then
  # Fallback hierarchy documented
  if grep -qiE "fallback.*hierarch|fallback.*rule|fallback rule" "$BRAND_PLATFORM_DOC"; then
    pass "AC-MB-002: fallback hierarchy documented in platform doc"
  else
    fail "AC-MB-002: fallback hierarchy not documented in MULTITENANT_BRAND_PLATFORM.md"
  fi

  # Platform default fallback documented
  if grep -qiE "platform default|mereka.*default|default.*mereka" "$BRAND_PLATFORM_DOC"; then
    pass "AC-MB-002: platform-default fallback (mereka tenant) documented"
  else
    fail "AC-MB-002: platform-default fallback not documented"
  fi

  # Missing field fallback documented
  if grep -qiE "missing.*field|field.*missing|empty.*dict|branding_config.*\{\}" "$BRAND_PLATFORM_DOC"; then
    pass "AC-MB-002: missing-field fallback behaviour documented"
  else
    fail "AC-MB-002: missing-field fallback not documented in platform doc"
  fi

  if grep -q 'sync-tenant-branding.sh' "$BRAND_PLATFORM_DOC" \
    && grep -q 'PRIMARY_COLOR' "$BRAND_PLATFORM_DOC" \
    && grep -q 'remains future work' "$BRAND_PLATFORM_DOC"; then
    pass "AC-MB-002: platform doc distinguishes generated tenant tokens, runtime MFE color keys, and future CSS-var injection"
  else
    fail "AC-MB-002: platform doc still blurs generated tenant tokens, runtime MFE color keys, and future CSS-var injection"
  fi

  # Validation at provisioning documented
  if grep -qiE "validation.*provisioning|validate.*provisioning|provisioning.*valid" "$BRAND_PLATFORM_DOC"; then
    pass "AC-MB-002: validation-at-provisioning behaviour documented"
  else
    fail "AC-MB-002: validation-at-provisioning not documented"
  fi

  # Runtime invalid config handling (log + fallback, no crash)
  if grep -qiE "invalid.*config.*runtime|runtime.*invalid|WARNING.*branding_config" "$BRAND_PLATFORM_DOC"; then
    pass "AC-MB-002: runtime invalid-config handling documented (log + fallback, no crash)"
  else
    fail "AC-MB-002: runtime invalid-config handling not documented"
  fi
else
  fail "AC-MB-002: MULTITENANT_BRAND_PLATFORM.md missing — cannot check fallback rules"
fi

# Schema has fallback_tenant_id field
if [[ -f "$BRAND_SCHEMA" ]]; then
  if grep -q "fallback_tenant_id" "$BRAND_SCHEMA"; then
    pass "AC-MB-002: fallback_tenant_id field defined in schema"
  else
    warn "AC-MB-002: fallback_tenant_id not in schema — fallback chain only relies on platform defaults"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# AC-MB-003: Per-tenant preview smoke paths
# ---------------------------------------------------------------------------
echo "--- AC-MB-003: Per-Tenant Preview Smoke Paths ---"

if [[ -f "$BRAND_PLATFORM_DOC" ]]; then
  # Smoke paths section exists
  if grep -qiE "smoke path|preview smoke|preview.*path" "$BRAND_PLATFORM_DOC"; then
    pass "AC-MB-003: per-tenant preview smoke paths section exists"
  else
    fail "AC-MB-003: per-tenant preview smoke paths not documented in platform doc"
  fi

  # All 3 tenant domains covered in smoke paths
  for domain in "${TENANT_DOMAINS[@]}"; do
    if grep -qF "$domain" "$BRAND_PLATFORM_DOC"; then
      pass "AC-MB-003: smoke path for '$domain' documented"
    else
      fail "AC-MB-003: smoke path for '$domain' not found in platform doc"
    fi
  done

  # Required branded screens documented
  for screen in "LMS Home" "authn" "dashboard" "Studio"; do
    if grep -qi "$screen" "$BRAND_PLATFORM_DOC"; then
      pass "AC-MB-003: '$screen' smoke path screen documented"
    else
      fail "AC-MB-003: '$screen' smoke path screen not documented"
    fi
  done

  # Screenshot capture script referenced
  if grep -q "capture-branding-screenshots.sh" "$BRAND_PLATFORM_DOC"; then
    pass "AC-MB-003: capture-branding-screenshots.sh smoke script referenced"
  else
    warn "AC-MB-003: capture-branding-screenshots.sh not referenced in platform doc"
  fi
else
  fail "AC-MB-003: MULTITENANT_BRAND_PLATFORM.md missing — cannot check smoke paths"
fi

# Screenshot script exists
SCREENSHOT_SCRIPT="$REPO_ROOT/scripts/qa/capture-branding-screenshots.sh"
if [[ -f "$SCREENSHOT_SCRIPT" ]]; then
  pass "AC-MB-003: capture-branding-screenshots.sh script exists"
else
  warn "AC-MB-003: capture-branding-screenshots.sh not found (may not be implemented yet)"
fi

echo ""

# ---------------------------------------------------------------------------
# AC-MB-004: Contract tests ensuring no global brand leakage
# ---------------------------------------------------------------------------
echo "--- AC-MB-004: Contract Tests (No Global Brand Leakage) ---"

if [[ -f "$BRAND_PLATFORM_DOC" ]]; then
  # Contract test strategy documented
  if grep -qiE "contract test|global brand leakage|brand leakage|no.*leakage" "$BRAND_PLATFORM_DOC"; then
    pass "AC-MB-004: contract test strategy / no-global-brand-leakage documented"
  else
    fail "AC-MB-004: contract test strategy not documented in platform doc"
  fi

  # Prohibited patterns documented
  if grep -qiE "forbidden|prohibited|hard.coded.*brand|hardcoded.*brand" "$BRAND_PLATFORM_DOC"; then
    pass "AC-MB-004: hard-coded brand prohibition documented"
  else
    fail "AC-MB-004: hard-coded brand value prohibition not documented"
  fi
fi

# Footer variant DRY contract script exists
if [[ -f "$FOOTER_MATRIX_SCRIPT" ]]; then
  pass "AC-MB-004: verify-footer-variant-matrix.sh (DRY/leakage contract) exists"
else
  fail "AC-MB-004: verify-footer-variant-matrix.sh missing — DRY domain contract not enforced"
fi

# Tenant branding contract script exists
if [[ -f "$BRANDING_CONTRACT_SCRIPT" ]]; then
  pass "AC-MB-004: verify-tenant-branding-contract.sh exists"
else
  fail "AC-MB-004: verify-tenant-branding-contract.sh missing — no branding contract tests"
fi

# Tenant isolation evidence script exists (cross-tenant no-bleed)
if [[ -f "$ISOLATION_SCRIPT" ]]; then
  pass "AC-MB-004: verify-tenant-isolation-evidence.sh exists (cross-tenant isolation)"
else
  fail "AC-MB-004: verify-tenant-isolation-evidence.sh missing — no isolation contract"
fi

# SITE_VARIANTS in plugin contract sources covers all domains (leakage guard)
if mereka_plugin_has_any "$REPO_ROOT"; then
  DOMAIN_COUNT=0
  for domain in "${TENANT_DOMAINS[@]}"; do
    if mereka_plugin_has_fixed "$REPO_ROOT" "'${domain}'" || mereka_plugin_has_fixed "$REPO_ROOT" "\"${domain}\""; then
      DOMAIN_COUNT=$((DOMAIN_COUNT + 1))
    fi
  done
  if [[ "$DOMAIN_COUNT" -ge 3 ]]; then
    pass "AC-MB-004: SITE_VARIANTS in plugin contract sources covers all 3 tenant domains (leakage guard)"
  else
    fail "AC-MB-004: SITE_VARIANTS only covers $DOMAIN_COUNT/3 tenant domains"
  fi
else
  warn "AC-MB-004: plugin contract sources not found (expected at least $PLUGIN_MAIN) — cannot check SITE_VARIANTS"
fi

echo ""

# ---------------------------------------------------------------------------
# AC-MB-005: SkillOurFuture migration guide
# ---------------------------------------------------------------------------
echo "--- AC-MB-005: SkillOurFuture Brand Migration Guide ---"

if [[ ! -f "$SOF_MIGRATION_DOC" ]]; then
  fail "AC-MB-005: SKILLOURFUTURE_BRAND_MIGRATION.md not found at docs/ops/runbooks/migrations/"
else
  pass "AC-MB-005: SKILLOURFUTURE_BRAND_MIGRATION.md exists"

  # Step-by-step format
  if grep -qiE "Step [0-9]|## Step" "$SOF_MIGRATION_DOC"; then
    pass "AC-MB-005: step-by-step migration format present"
  else
    fail "AC-MB-005: step-by-step migration steps not found in guide"
  fi

  # Asset mapping section
  if grep -qiE "asset.*mapping|field.*mapping|existing.*asset|map.*schema" "$SOF_MIGRATION_DOC"; then
    pass "AC-MB-005: asset-to-schema field mapping present"
  else
    fail "AC-MB-005: field mapping from existing assets to schema not documented"
  fi

  # Validation checklist
  if grep -qiE "validation checklist|checklist|PASS|validate-tenant-brand-pack" "$SOF_MIGRATION_DOC"; then
    pass "AC-MB-005: validation checklist present in migration guide"
  else
    fail "AC-MB-005: validation checklist missing from migration guide"
  fi

  # SkillOurFuture domain referenced
  if grep -q "skillourfuture.academy.mereka.io" "$SOF_MIGRATION_DOC"; then
    pass "AC-MB-005: SkillOurFuture domain referenced in migration guide"
  else
    fail "AC-MB-005: SkillOurFuture domain not found in migration guide"
  fi

  # Schema reference
  if grep -q "brand-config-schema.json" "$SOF_MIGRATION_DOC"; then
    pass "AC-MB-005: migration guide references brand-config-schema.json"
  else
    fail "AC-MB-005: brand-config-schema.json not referenced in migration guide"
  fi

  # Rollback documented
  if grep -qiE "rollback|revert" "$SOF_MIGRATION_DOC"; then
    pass "AC-MB-005: rollback procedure documented in migration guide"
  else
    warn "AC-MB-005: rollback procedure not documented — consider adding"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# AC-MB-006: Governance documentation
# ---------------------------------------------------------------------------
echo "--- AC-MB-006: Governance Policy (Who Updates, Approval Flow) ---"

if [[ -f "$BRAND_PLATFORM_DOC" ]]; then
  # Governance section exists
  if grep -qiE "governance|approval.*flow|who.*update|who owns" "$BRAND_PLATFORM_DOC"; then
    pass "AC-MB-006: governance policy section present in platform doc"
  else
    fail "AC-MB-006: governance policy not documented in MULTITENANT_BRAND_PLATFORM.md"
  fi

  # Roles defined
  if grep -qiE "platform.*engineer|academic.*ops|brand.*design|team.*role|role.*responsib" "$BRAND_PLATFORM_DOC"; then
    pass "AC-MB-006: team roles and responsibilities documented"
  else
    fail "AC-MB-006: team roles not defined in governance section"
  fi

  # Approval flow
  if grep -qiE "approval.*flow|PR.*review|pull.*request.*review|review.*process" "$BRAND_PLATFORM_DOC"; then
    pass "AC-MB-006: PR approval flow documented"
  else
    fail "AC-MB-006: PR approval flow not documented in governance section"
  fi

  # Prohibited changes requiring review
  if grep -qiE "prohibited.*without.*PR|prohibited.*change|require.*PR|forbidden.*without" "$BRAND_PLATFORM_DOC"; then
    pass "AC-MB-006: prohibited-without-PR changes listed"
  else
    fail "AC-MB-006: prohibited changes without PR review not documented"
  fi

  # Audit trail / _meta requirement
  if grep -qiE "_meta|audit trail|approved_by|approved_at" "$BRAND_PLATFORM_DOC"; then
    pass "AC-MB-006: audit trail requirement documented (_meta block)"
  else
    fail "AC-MB-006: audit trail (_meta block) not documented"
  fi

  # Quarterly review
  if grep -qiE "quarterly|periodic.*review|review.*schedule" "$BRAND_PLATFORM_DOC"; then
    pass "AC-MB-006: periodic review cadence documented"
  else
    warn "AC-MB-006: quarterly review cadence not documented — consider adding"
  fi
else
  fail "AC-MB-006: MULTITENANT_BRAND_PLATFORM.md missing — cannot check governance"
fi

# MULTISITE_GOVERNANCE.md should cross-reference brand governance
if [[ -f "$MULTISITE_GOV" ]]; then
  if grep -qiE "brand.*policy|brand.*governance|branding.*change.*control|change.*control.*brand" "$MULTISITE_GOV"; then
    pass "AC-MB-006: MULTISITE_GOVERNANCE.md references brand change control"
  else
    warn "AC-MB-006: MULTISITE_GOVERNANCE.md does not explicitly reference brand change control (consider cross-linking)"
  fi
else
  warn "AC-MB-006: MULTISITE_GOVERNANCE.md not found — governance cross-reference cannot be verified"
fi

# Schema has _meta approval fields
if [[ -f "$BRAND_SCHEMA" ]]; then
  if grep -q '"approved_by"' "$BRAND_SCHEMA" && grep -q '"approved_at"' "$BRAND_SCHEMA"; then
    pass "AC-MB-006: JSON schema enforces _meta.approved_by and _meta.approved_at"
  else
    fail "AC-MB-006: JSON schema missing _meta.approved_by / _meta.approved_at enforcement"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# Live mode: HTTP probes for per-tenant branded screens
# ---------------------------------------------------------------------------
if [[ "$LIVE_MODE" == "1" ]]; then
  echo "--- Live Mode: Per-Tenant Branded Screen Probes ---"
  echo ""

  CURL_TIMEOUT=15

  for domain in "${TENANT_DOMAINS[@]}"; do
    echo "  Probing $domain..."

    # LMS root
    lms_code=$(curl -s -o /dev/null -w "%{http_code}" \
      --max-time "$CURL_TIMEOUT" "https://${domain}/" 2>/dev/null || echo "000")
    if [[ "$lms_code" == "200" || "$lms_code" == "302" ]]; then
      pass "[LIVE] AC-MB-003: $domain LMS root reachable (HTTP $lms_code)"
    else
      warn "[LIVE] AC-MB-003: $domain LMS root returned HTTP $lms_code (expected 200/302)"
    fi

    # Logo URL (MFE config)
    mfe_url="https://${domain}/api/mfe_config/v1"
    mfe_resp=$(curl -sf --max-time "$CURL_TIMEOUT" "$mfe_url" 2>/dev/null || echo "")
    if [[ -n "$mfe_resp" ]]; then
      logo_url=$(echo "$mfe_resp" | grep -o '"LOGO_URL"[[:space:]]*:[[:space:]]*"[^"]*"' \
        | sed 's/.*"LOGO_URL"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || echo "")
      if [[ -n "$logo_url" ]] && ! echo "$logo_url" | grep -qi "openedx"; then
        pass "[LIVE] AC-MB-004: $domain LOGO_URL is tenant-specific (no global brand leakage)"
      elif echo "$logo_url" | grep -qi "openedx"; then
        fail "[LIVE] AC-MB-004: $domain LOGO_URL contains default 'openedx' (global brand leakage)"
      else
        warn "[LIVE] AC-MB-004: $domain LOGO_URL empty in MFE config"
      fi
    else
      warn "[LIVE] AC-MB-003: $domain MFE config endpoint unreachable ($mfe_url)"
    fi
  done

  echo ""
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "Action required: Fix FAIL items above."
  echo "  - AC-MB-001: Create infrastructure/tutor/plugins/multi-tenancy/brand-config-schema.json"
  echo "  - AC-MB-002: Document fallback rules in docs/reference/operations/MULTITENANT_BRAND_PLATFORM.md"
  echo "  - AC-MB-003: Document per-tenant smoke paths in MULTITENANT_BRAND_PLATFORM.md"
  echo "  - AC-MB-004: Ensure contract test scripts exist (verify-footer-variant-matrix.sh, etc.)"
  echo "  - AC-MB-005: Create docs/ops/runbooks/migrations/SKILLOURFUTURE_BRAND_MIGRATION.md"
  echo "  - AC-MB-006: Add governance policy to MULTITENANT_BRAND_PLATFORM.md"
  exit 1
fi

echo ""
echo "All multitenant brand platform checks passed (WARNs are advisory)."
exit 0
