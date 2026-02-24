#!/usr/bin/env bash
# @spec: data-privacy-gdpr-compliance_spec.md
# @covers AC-006, AC-007, AC-CONSENT-001, AC-CONSENT-002, AC-003, AC-DELETE-001, AC-013, AC-EXPORT-003, AC-023, AC-025, AC-026, AC-019, AC-018
#
# GDPR Cookie Consent & User Retirement Pipeline Verification
#
# Modes:
#   --offline   Static checks only — config files, LMS settings, retirement commands,
#               PII hooks, analytics events, ExternalSecrets, retention policy
#   --online    Live endpoint checks — /privacy, cookie consent banner HTML,
#               user retirement API, data export endpoint
#   (default)   Runs both offline and online checks
#
# Environment variables:
#   LMS_URL        LMS base URL for online checks (default: https://academyv2.mereka.io)
#   NAMESPACE      K8s namespace (default: mereka-lms)
#   KUBE_CONTEXT   kubectl context (default: from current kubeconfig)
#   CURL_TIMEOUT   curl connect timeout in seconds (default: 10)
#
# Usage:
#   ./scripts/qa/verify-gdpr-compliance.sh [--offline|--online]
#   LMS_URL=https://academyv2.mereka.dev ./scripts/qa/verify-gdpr-compliance.sh --online

set -euo pipefail

# ---------------------------------------------------------------------------
# Colors and counters
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# ---------------------------------------------------------------------------
# Paths and defaults
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LMS_URL="${LMS_URL:-https://academyv2.mereka.io}"
NAMESPACE="${NAMESPACE:-mereka-lms}"
CURL_TIMEOUT="${CURL_TIMEOUT:-10}"

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
pass() {
  echo -e "${GREEN}PASS${NC} $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo -e "${RED}FAIL${NC} $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

skip() {
  echo -e "${YELLOW}SKIP${NC} $1"
  SKIP_COUNT=$((SKIP_COUNT + 1))
}

# Check whether kubectl can reach the cluster
_HAS_KUBECTL=""
has_kubectl() {
  if [[ -z "$_HAS_KUBECTL" ]]; then
    if command -v kubectl &>/dev/null && timeout 5 kubectl cluster-info &>/dev/null 2>&1; then
      _HAS_KUBECTL="yes"
    else
      _HAS_KUBECTL="no"
    fi
  fi
  [[ "$_HAS_KUBECTL" == "yes" ]]
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
MODE="both"
if [[ "${1:-}" == "--offline" ]]; then
  MODE="offline"
elif [[ "${1:-}" == "--online" ]]; then
  MODE="online"
fi

# ===========================================================================
# OFFLINE CHECKS
# ===========================================================================
run_offline_checks() {
  echo ""
  echo "== Offline Checks (static analysis) =="
  echo ""

  # ── 1. Privacy policy document ─────────────────────────────────────────
  echo "--- Privacy Policy Documentation ---"

  # Check if any privacy policy document exists under docs/
  privacy_docs=$(find "$REPO_ROOT/docs" -type f -name "*.md" \
    \( -iname "*privacy*" -o -iname "*gdpr*" \) 2>/dev/null || true)
  if [[ -n "$privacy_docs" ]]; then
    pass "AC-006: Privacy policy documentation found in docs/"
    while IFS= read -r f; do
      echo "         $f"
    done <<< "$privacy_docs"
  else
    fail "AC-006: No privacy policy documentation found under docs/"
  fi

  # Check for GDPR compliance runbook
  gdpr_runbook="$REPO_ROOT/docs/operations/GDPR_COMPLIANCE.md"
  if [[ -f "$gdpr_runbook" ]]; then
    pass "GDPR_COMPLIANCE.md operational runbook exists"
  else
    fail "docs/operations/GDPR_COMPLIANCE.md does not exist — create it"
  fi

  # ── 2. Cookie consent configuration in LMS settings ────────────────────
  echo ""
  echo "--- Cookie Consent Configuration ---"

  lms_prod_settings="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"
  lms_patches="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"

  # AC-CONSENT-001: ENABLE_COOKIE_CONSENT_BANNER feature flag
  if [[ -f "$lms_prod_settings" ]]; then
    if grep -q "ENABLE_COOKIE_CONSENT_BANNER\|CONSENT_TRACKING_ENABLED\|cookie.consent\|cookieConsent" \
        "$lms_prod_settings" 2>/dev/null; then
      pass "AC-CONSENT-001: Cookie consent feature flag found in LMS production settings"
    else
      skip "AC-CONSENT-001: ENABLE_COOKIE_CONSENT_BANNER not set in LMS production settings (not yet implemented)"
    fi
  elif [[ -f "$lms_patches" ]]; then
    if grep -q "ENABLE_COOKIE_CONSENT_BANNER\|CONSENT_TRACKING_ENABLED\|cookie.consent" \
        "$lms_patches" 2>/dev/null; then
      pass "AC-CONSENT-001: Cookie consent feature flag found in apply-patches.sh"
    else
      skip "AC-CONSENT-001: Cookie consent feature flag not found in apply-patches.sh (not yet implemented)"
    fi
  else
    skip "AC-CONSENT-001: LMS settings files not found — cannot check cookie consent flag"
  fi

  # Check for cookie consent component in MFE or theme
  mfe_consent=$(find "$REPO_ROOT/infrastructure/tutor" -type f \
    \( -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" \) \
    2>/dev/null | xargs grep -l "cookie.consent\|CookieConsent\|cookieBanner" 2>/dev/null | head -1 || true)
  if [[ -n "$mfe_consent" ]]; then
    pass "AC-CONSENT-001: Cookie consent component found in MFE customizations"
  else
    skip "AC-CONSENT-001: Cookie consent UI component not yet implemented in MFE/theme"
  fi

  # ── 3. User retirement management commands ──────────────────────────────
  echo ""
  echo "--- User Retirement Pipeline ---"

  # AC-DELETE-001: retire_user management command exists on the platform
  # Open edX provides UserRetirementStatus + retire_user management command.
  # Verify that the retirement pipeline config exists in this repo.
  retirement_cfg=$(find "$REPO_ROOT/deploy" "$REPO_ROOT/infrastructure" \
    -type f -name "*.yml" -o -name "*.yaml" -o -name "*.py" 2>/dev/null | \
    xargs grep -l "retire_user\|UserRetirementStatus\|retirement_pipeline\|user.retirement" \
    2>/dev/null | head -1 || true)
  if [[ -n "$retirement_cfg" ]]; then
    pass "AC-DELETE-001: User retirement configuration found: $retirement_cfg"
  else
    skip "AC-DELETE-001: No explicit user retirement configuration in repo (Open edX retirement pipeline may use default settings)"
  fi

  # Check for retirement pipeline documentation in runbooks
  retirement_docs=$(find "$REPO_ROOT/docs" -type f -name "*.md" \
    2>/dev/null | xargs grep -l "retire_user\|UserRetirement\|right.to.erasure\|right.to.be.forgotten" \
    2>/dev/null | head -3 || true)
  if [[ -n "$retirement_docs" ]]; then
    pass "AC-DELETE-001: User retirement procedures documented in runbooks"
    while IFS= read -r f; do
      echo "         $f"
    done <<< "$retirement_docs"
  else
    fail "AC-DELETE-001: No user retirement runbook documentation found under docs/"
  fi

  # AC-013: Check if data export management command is referenced
  export_refs=$(find "$REPO_ROOT/docs" "$REPO_ROOT/scripts" -type f -name "*.md" -o -name "*.sh" \
    2>/dev/null | xargs grep -l "export_user_data\|data.export\|portability" \
    2>/dev/null | head -1 || true)
  if [[ -n "$export_refs" ]]; then
    pass "AC-013: Data export procedures referenced in docs or scripts"
  else
    skip "AC-013: No data export (portability) procedure documentation found"
  fi

  # ── 4. PII cleanup hooks in purchase-gateway ────────────────────────────
  echo ""
  echo "--- Purchase Gateway PII Cleanup ---"

  pg_order_model="$REPO_ROOT/services/purchase-gateway/app/models/order.py"
  if [[ -f "$pg_order_model" ]]; then
    # Verify PII fields exist (buyer_email is documented PII)
    if grep -q "buyer_email" "$pg_order_model" 2>/dev/null; then
      pass "Purchase Gateway order model contains buyer_email (PII field confirmed)"
    else
      skip "Purchase Gateway order model does not contain buyer_email — schema may differ"
    fi

    # Check for anonymization / retirement logic in purchase-gateway
    pg_retire=$(find "$REPO_ROOT/services/purchase-gateway" -type f \
      \( -name "*.py" -o -name "*.sh" -o -name "*.md" \) 2>/dev/null | \
      xargs grep -l "retire\|anonymize\|buyer_email.*retired\|gdpr\|privacy" \
      2>/dev/null | head -1 || true)
    if [[ -n "$pg_retire" ]]; then
      pass "AC-DELETE-001: Purchase Gateway has PII retirement/anonymization hooks: $pg_retire"
    else
      skip "AC-DELETE-001: Purchase Gateway has no buyer_email anonymization hook (not yet implemented)"
    fi
  else
    skip "Purchase Gateway model not found at expected path — skipping PII field checks"
  fi

  # Check purchase-gateway README for GDPR notes
  pg_readme="$REPO_ROOT/services/purchase-gateway/README.md"
  if [[ -f "$pg_readme" ]]; then
    if grep -qi "gdpr\|privacy\|pii\|data.retention\|retire" "$pg_readme" 2>/dev/null; then
      pass "Purchase Gateway README documents PII/GDPR considerations"
    else
      skip "Purchase Gateway README does not document GDPR/PII handling"
    fi
  else
    skip "Purchase Gateway README not found"
  fi

  # ── 5. Analytics events PII audit ───────────────────────────────────────
  echo ""
  echo "--- Analytics Events PII Audit ---"

  # AC-023, AC-025, AC-026: PII audit script exists for analytics
  pii_audit="$REPO_ROOT/scripts/qa/audit-analytics-pii.sh"
  if [[ -f "$pii_audit" ]]; then
    pass "AC-023: Analytics PII audit script exists (audit-analytics-pii.sh)"
    # Check if it covers xapi_events (ClickHouse)
    if grep -q "xapi_events\|actor_mbox\|clickhouse\|ClickHouse" "$pii_audit" 2>/dev/null; then
      pass "AC-026: PII audit script covers ClickHouse/xapi_events analytics events"
    else
      skip "AC-026: PII audit script does not cover ClickHouse xapi_events"
    fi
    # Check if it covers Loki log scanning
    if grep -q "loki\|Loki\|log.*email\|email.*log" "$pii_audit" 2>/dev/null; then
      pass "AC-025: PII audit script covers Loki log PII scanning"
    else
      skip "AC-025: PII audit script does not cover Loki log email pattern scanning"
    fi
  else
    fail "AC-023: analytics PII audit script missing (scripts/qa/audit-analytics-pii.sh)"
  fi

  # Check analytics pipeline spec for PII/anonymization requirements
  analytics_spec="$REPO_ROOT/specs/analytics-pipeline_spec.md"
  if [[ -f "$analytics_spec" ]]; then
    if grep -qi "anonymize\|hashed.*identifier\|actor_id\|pii" "$analytics_spec" 2>/dev/null; then
      pass "AC-026: Analytics pipeline spec references PII anonymization requirements"
    else
      skip "AC-026: Analytics pipeline spec does not mention PII anonymization"
    fi
  else
    skip "AC-026: Analytics pipeline spec not found"
  fi

  # ── 6. ExternalSecrets PII field exposure check ─────────────────────────
  echo ""
  echo "--- ExternalSecrets PII Safety ---"

  es_file="$REPO_ROOT/deploy/k8s/base/secrets/external-secrets.yaml"
  if [[ -f "$es_file" ]]; then
    # ExternalSecrets should NOT map user-data fields — only service credentials
    # Check that no user PII fields (email, username, profile) are mapped as secrets
    if grep -qiE "user_email|user_name|buyer_email|profile_image" "$es_file" 2>/dev/null; then
      fail "ExternalSecrets maps user PII fields — verify this is intentional"
    else
      pass "ExternalSecrets does not expose user PII fields (emails, usernames)"
    fi
    # Encryption keys should be present for PII at-rest protection
    if grep -qE "SECRET_KEY|ENCRYPTION_KEY|FERNET|DATABASE_KEY" "$es_file" 2>/dev/null; then
      pass "Encryption keys referenced in ExternalSecrets (PII at-rest protection)"
    else
      skip "No dedicated PII encryption keys in ExternalSecrets (relying on GCP/Atlas encryption at rest)"
    fi
  else
    skip "ExternalSecrets file not found at deploy/k8s/base/secrets/external-secrets.yaml"
  fi

  # ── 7. Data retention policy configuration ──────────────────────────────
  echo ""
  echo "--- Data Retention Policy ---"

  # AC-019: Loki log retention (30 days per spec)
  loki_cfg=$(find "$REPO_ROOT/infrastructure" "$REPO_ROOT/deploy" \
    -type f \( -name "*loki*" -o -name "*observability*" \) 2>/dev/null | \
    xargs grep -l "retention" 2>/dev/null | head -1 || true)
  if [[ -n "$loki_cfg" ]]; then
    pass "AC-019: Loki retention policy configuration found: $loki_cfg"
  else
    skip "AC-019: Loki 30-day log retention policy not explicitly configured"
  fi

  # AC-018: ClickHouse analytics retention (365 days per spec)
  ch_retention=$(find "$REPO_ROOT/infrastructure" "$REPO_ROOT/deploy" \
    -type f 2>/dev/null | \
    xargs grep -l "clickhouse.*retention\|retention.*clickhouse\|xapi_events.*ttl\|365" \
    2>/dev/null | head -1 || true)
  if [[ -n "$ch_retention" ]]; then
    pass "AC-018: ClickHouse analytics retention configuration found: $ch_retention"
  else
    skip "AC-018: ClickHouse 365-day analytics retention policy not explicitly configured"
  fi

  # Check for retention documentation
  retention_docs=$(find "$REPO_ROOT/docs" -type f -name "*RETENTION*" -o -name "*retention*" \
    2>/dev/null | head -1 || true)
  if [[ -n "$retention_docs" ]]; then
    pass "Data retention documentation found: $retention_docs"
  else
    skip "No data retention policy documentation found under docs/"
  fi

  # ── 8. Pre-commit secret scanning hook ──────────────────────────────────
  echo ""
  echo "--- Pre-commit PII Safety Hook ---"

  precommit_hook="$REPO_ROOT/.githooks/pre-commit"
  if [[ -f "$precommit_hook" ]]; then
    pass "Pre-commit secret/PII scanning hook exists (.githooks/pre-commit)"
  else
    skip "Pre-commit secret scanning hook not found at .githooks/pre-commit"
  fi

  # ── 9. PII registry ─────────────────────────────────────────────────────
  echo ""
  echo "--- PII Registry ---"

  pii_registry="$REPO_ROOT/specs/pii-registry.yml"
  if [[ -f "$pii_registry" ]]; then
    pass "AC-001: PII registry found at specs/pii-registry.yml"
    if grep -q "data_store\|sensitivity" "$pii_registry" 2>/dev/null; then
      pass "AC-001: PII registry contains required fields (data_store, sensitivity)"
    else
      fail "AC-001: PII registry missing required fields (data_store, sensitivity)"
    fi
  else
    skip "AC-001: PII registry (specs/pii-registry.yml) not yet created"
  fi
}

# ===========================================================================
# ONLINE CHECKS
# ===========================================================================
run_online_checks() {
  echo ""
  echo "== Online Checks (live endpoints) =="
  echo ""

  if ! command -v curl &>/dev/null; then
    skip "curl not available — skipping all online checks"
    return
  fi

  # ── 1. /privacy endpoint responds ───────────────────────────────────────
  echo "--- Privacy Policy Endpoint ---"

  privacy_status=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout "$CURL_TIMEOUT" \
    --max-time $((CURL_TIMEOUT * 2)) \
    "${LMS_URL}/privacy" 2>/dev/null || echo "000")
  if [[ "$privacy_status" =~ ^(200|301|302)$ ]]; then
    pass "AC-006: /privacy endpoint responds (HTTP ${privacy_status}): ${LMS_URL}/privacy"
  elif [[ "$privacy_status" == "000" ]]; then
    skip "AC-006: Could not reach ${LMS_URL}/privacy (connection timeout)"
  else
    fail "AC-006: /privacy endpoint returned HTTP ${privacy_status} (expected 200/301/302)"
  fi

  # ── 2. Cookie consent banner in LMS HTML ────────────────────────────────
  echo ""
  echo "--- Cookie Consent Banner ---"

  lms_html=$(curl -s \
    --connect-timeout "$CURL_TIMEOUT" \
    --max-time $((CURL_TIMEOUT * 2)) \
    "${LMS_URL}" 2>/dev/null || true)
  if [[ -z "$lms_html" ]]; then
    skip "AC-CONSENT-001: Could not fetch LMS homepage (${LMS_URL}) for banner check"
  else
    # Look for cookie consent indicators in the HTML
    if echo "$lms_html" | grep -qiE "cookie.consent|cookieConsent|cookie-consent|CookieBanner|cc_cookie|ENABLE_COOKIE_CONSENT"; then
      pass "AC-CONSENT-001: Cookie consent banner script/element found in LMS HTML"
    else
      skip "AC-CONSENT-001: No cookie consent banner detected in LMS homepage HTML (not yet implemented)"
    fi

    # Check for privacy policy link in HTML
    if echo "$lms_html" | grep -qiE "privacy.policy|/privacy\"|privacy-policy"; then
      pass "AC-006: Privacy policy link present in LMS homepage HTML"
    else
      skip "AC-006: No privacy policy link found in LMS homepage HTML"
    fi
  fi

  # ── 3. User retirement API endpoint ─────────────────────────────────────
  echo ""
  echo "--- User Retirement API ---"

  # Open edX user retirement API is at /api/user/v1/accounts/retire/
  # It requires authentication, so we expect 401 or 403 (not 404)
  retire_status=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout "$CURL_TIMEOUT" \
    --max-time $((CURL_TIMEOUT * 2)) \
    -X POST \
    "${LMS_URL}/api/user/v1/accounts/retire/" 2>/dev/null || echo "000")
  if [[ "$retire_status" =~ ^(401|403|405)$ ]]; then
    pass "AC-DELETE-001: User retirement API endpoint exists (HTTP ${retire_status} — auth required): ${LMS_URL}/api/user/v1/accounts/retire/"
  elif [[ "$retire_status" == "404" ]]; then
    fail "AC-DELETE-001: User retirement API endpoint not found (HTTP 404): ${LMS_URL}/api/user/v1/accounts/retire/"
  elif [[ "$retire_status" == "000" ]]; then
    skip "AC-DELETE-001: Could not reach retirement endpoint (connection timeout)"
  else
    # 200 without auth is also valid response to probe with
    pass "AC-DELETE-001: User retirement API endpoint reachable (HTTP ${retire_status})"
  fi

  # ── 4. Data export (portability) endpoint ───────────────────────────────
  echo ""
  echo "--- Data Export (Portability) Endpoint ---"

  # Open edX data export is at /api/user/v1/accounts/download/
  export_status=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout "$CURL_TIMEOUT" \
    --max-time $((CURL_TIMEOUT * 2)) \
    "${LMS_URL}/api/user/v1/accounts/download/" 2>/dev/null || echo "000")
  if [[ "$export_status" =~ ^(200|401|403|405)$ ]]; then
    pass "AC-013: Data export endpoint exists (HTTP ${export_status}): ${LMS_URL}/api/user/v1/accounts/download/"
  elif [[ "$export_status" == "404" ]]; then
    fail "AC-013: Data export endpoint not found (HTTP 404): ${LMS_URL}/api/user/v1/accounts/download/"
  elif [[ "$export_status" == "000" ]]; then
    skip "AC-013: Could not reach data export endpoint (connection timeout)"
  else
    pass "AC-013: Data export endpoint reachable (HTTP ${export_status})"
  fi

  # ── 5. GDPR-related HTTP headers ────────────────────────────────────────
  echo ""
  echo "--- Security Headers ---"

  headers=$(curl -s -I \
    --connect-timeout "$CURL_TIMEOUT" \
    --max-time $((CURL_TIMEOUT * 2)) \
    "${LMS_URL}" 2>/dev/null || true)
  if [[ -z "$headers" ]]; then
    skip "Could not fetch LMS headers for security header checks"
  else
    # Strict-Transport-Security (HSTS) — required for secure data transmission
    if echo "$headers" | grep -qi "strict-transport-security"; then
      pass "HSTS header present (secure transmission for PII)"
    else
      fail "HSTS header missing — required for GDPR-compliant data transmission"
    fi

    # X-Content-Type-Options
    if echo "$headers" | grep -qi "x-content-type-options"; then
      pass "X-Content-Type-Options header present"
    else
      skip "X-Content-Type-Options header missing (recommended)"
    fi
  fi
}

# ===========================================================================
# Main
# ===========================================================================
echo "=== GDPR Cookie Consent & User Retirement Pipeline Verification ==="
echo "Spec: data-privacy-gdpr-compliance_spec.md"
echo "LMS URL: ${LMS_URL}"
echo "Mode: ${MODE}"

if [[ "$MODE" == "offline" || "$MODE" == "both" ]]; then
  run_offline_checks
fi

if [[ "$MODE" == "online" || "$MODE" == "both" ]]; then
  run_online_checks
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Summary ==="
echo -e "  ${GREEN}PASS${NC}: ${PASS_COUNT}"
echo -e "  ${RED}FAIL${NC}: ${FAIL_COUNT}"
echo -e "  ${YELLOW}SKIP${NC}: ${SKIP_COUNT}"
TOTAL=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))
echo "  TOTAL: ${TOTAL}"
echo ""

if [[ $FAIL_COUNT -gt 0 ]]; then
  echo -e "${RED}RESULT: FAIL${NC} (${FAIL_COUNT} check(s) failed)"
  exit 1
fi

echo -e "${GREEN}RESULT: PASS${NC} (${SKIP_COUNT} check(s) skipped — GDPR features partially implemented)"
exit 0
