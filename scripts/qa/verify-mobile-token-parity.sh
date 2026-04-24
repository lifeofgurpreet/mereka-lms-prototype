#!/usr/bin/env bash
# Verify mobile token parity: design token alignment, API endpoint inventory,
# and critical theming gaps identified in docs/reference/architecture/MOBILE_TOKEN_PARITY.md
#
# @spec: proposals/mobile-apps-enterprise_spec.md
# @covers: AC-MOB-001, AC-MOB-023
#
# Usage:
#   ./scripts/qa/verify-mobile-token-parity.sh
#
# Exit code: 0 if FAIL == 0, 1 otherwise.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

pass() { echo -e "  ${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "  ${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

TOKENS_CSS="assets/branding/tokens.css"
MOBILE_API_DIR="infrastructure/tutor/custom-apps/openedx_mobile_api"
PUSH_NOTIF_DIR="infrastructure/tutor/custom-apps/openedx_push_notifications"
PARITY_DOC="docs/reference/architecture/MOBILE_TOKEN_PARITY.md"
AASA_FILE="$MOBILE_API_DIR/static/.well-known/apple-app-site-association"

# ---------------------------------------------------------------------------
# Section 1: Prerequisite files exist
# ---------------------------------------------------------------------------
echo ""
echo "=== Mobile Token Parity Verification ==="
echo ""
echo "--- Section 1: Required files ---"

[[ -f "$TOKENS_CSS" ]] \
  && pass "Canonical token file exists ($TOKENS_CSS)" \
  || fail "Canonical token file missing ($TOKENS_CSS)"

[[ -f "$MOBILE_API_DIR/models.py" ]] \
  && pass "Mobile API models file exists" \
  || fail "Mobile API models file missing ($MOBILE_API_DIR/models.py)"

[[ -f "$MOBILE_API_DIR/views.py" ]] \
  && pass "Mobile API views file exists" \
  || fail "Mobile API views file missing ($MOBILE_API_DIR/views.py)"

[[ -f "$MOBILE_API_DIR/ios_views.py" ]] \
  && pass "iOS views file exists" \
  || fail "iOS views file missing ($MOBILE_API_DIR/ios_views.py)"

[[ -f "$MOBILE_API_DIR/ios_release.py" ]] \
  && pass "iOS release/branding model file exists" \
  || fail "iOS release/branding model file missing ($MOBILE_API_DIR/ios_release.py)"

[[ -f "$PUSH_NOTIF_DIR/models.py" ]] \
  && pass "Push notifications models file exists" \
  || fail "Push notifications models file missing"

[[ -f "$PARITY_DOC" ]] \
  && pass "Parity assessment document exists ($PARITY_DOC)" \
  || fail "Parity assessment document missing ($PARITY_DOC)"

# ---------------------------------------------------------------------------
# Section 2: Canonical token values
# ---------------------------------------------------------------------------
echo ""
echo "--- Section 2: Canonical token values ---"

extract_token_value() {
  local token="$1"
  grep -E "^\s+${token}:" "$TOKENS_CSS" | grep -oE '#[0-9a-fA-F]{6}' | head -1
}

TEAL_VAL=$(extract_token_value "--color-teal" 2>/dev/null || true)
MAGENTA_VAL=$(extract_token_value "--color-magenta" 2>/dev/null || true)
WHITE_VAL=$(extract_token_value "--color-white" 2>/dev/null || true)

[[ -n "$TEAL_VAL" ]] \
  && pass "Canonical --color-teal present (value: $TEAL_VAL)" \
  || fail "Canonical --color-teal not found in $TOKENS_CSS"

[[ -n "$MAGENTA_VAL" ]] \
  && pass "Canonical --color-magenta present (value: $MAGENTA_VAL)" \
  || fail "Canonical --color-magenta not found in $TOKENS_CSS"

[[ -n "$WHITE_VAL" ]] \
  && pass "Canonical --color-white present (value: $WHITE_VAL)" \
  || fail "Canonical --color-white not found in $TOKENS_CSS"

# ---------------------------------------------------------------------------
# Section 3: Mobile API branding config fields
# ---------------------------------------------------------------------------
echo ""
echo "--- Section 3: MobileBrandingConfig model fields ---"

grep -q "primary_color" "$MOBILE_API_DIR/models.py" \
  && pass "MobileBrandingConfig.primary_color field exists" \
  || fail "MobileBrandingConfig.primary_color field missing"

grep -q "secondary_color" "$MOBILE_API_DIR/models.py" \
  && pass "MobileBrandingConfig.secondary_color field exists" \
  || fail "MobileBrandingConfig.secondary_color field missing"

grep -q "splash_background_color" "$MOBILE_API_DIR/models.py" \
  && pass "MobileBrandingConfig.splash_background_color field exists" \
  || fail "MobileBrandingConfig.splash_background_color field missing"

# ---------------------------------------------------------------------------
# Section 4: iOS branding extension fields
# ---------------------------------------------------------------------------
echo ""
echo "--- Section 4: IOSBrandingExtension model fields ---"

grep -q "tint_color" "$MOBILE_API_DIR/ios_release.py" \
  && pass "IOSBrandingExtension.tint_color field exists" \
  || fail "IOSBrandingExtension.tint_color field missing"

grep -q "navigation_bar_color" "$MOBILE_API_DIR/ios_release.py" \
  && pass "IOSBrandingExtension.navigation_bar_color field exists" \
  || fail "IOSBrandingExtension.navigation_bar_color field missing"

grep -q "tab_bar_color" "$MOBILE_API_DIR/ios_release.py" \
  && pass "IOSBrandingExtension.tab_bar_color field exists" \
  || fail "IOSBrandingExtension.tab_bar_color field missing"

# ---------------------------------------------------------------------------
# Section 5: Model default color drift detection
# ---------------------------------------------------------------------------
echo ""
echo "--- Section 5: Model default color drift (Gap 1) ---"

# primary_color default should match --color-magenta (#ab3b78), not Google Blue
if [[ -n "$MAGENTA_VAL" ]]; then
  if grep -A5 "primary_color" "$MOBILE_API_DIR/models.py" \
    | grep -q "default=\"${MAGENTA_VAL}\""; then
    pass "MobileBrandingConfig.primary_color default matches canonical --color-magenta ($MAGENTA_VAL)"
  else
    CURRENT_DEFAULT=$(grep -A5 "primary_color" "$MOBILE_API_DIR/models.py" \
      | grep 'default=' | grep -oE '"#[0-9a-fA-F]+"' | head -1 || echo "(not found)")
    fail "MobileBrandingConfig.primary_color default ($CURRENT_DEFAULT) does not match canonical --color-magenta ($MAGENTA_VAL)"
  fi
else
  skip "Cannot check primary_color default: --color-magenta not found in tokens.css"
fi

# secondary_color default should match --color-teal (#237072), not Google Green
if [[ -n "$TEAL_VAL" ]]; then
  if grep -A5 "secondary_color" "$MOBILE_API_DIR/models.py" \
    | grep -q "default=\"${TEAL_VAL}\""; then
    pass "MobileBrandingConfig.secondary_color default matches canonical --color-teal ($TEAL_VAL)"
  else
    CURRENT_DEFAULT=$(grep -A5 "secondary_color" "$MOBILE_API_DIR/models.py" \
      | grep 'default=' | grep -oE '"#[0-9a-fA-F]+"' | head -1 || echo "(not found)")
    fail "MobileBrandingConfig.secondary_color default ($CURRENT_DEFAULT) does not match canonical --color-teal ($TEAL_VAL)"
  fi
else
  skip "Cannot check secondary_color default: --color-teal not found in tokens.css"
fi

# tint_color default should match --color-magenta (#ab3b78), not Google Blue
if [[ -n "$MAGENTA_VAL" ]]; then
  if grep -A5 "tint_color" "$MOBILE_API_DIR/ios_release.py" \
    | grep -q "default=\"${MAGENTA_VAL}\""; then
    pass "IOSBrandingExtension.tint_color default matches canonical --color-magenta ($MAGENTA_VAL)"
  else
    CURRENT_DEFAULT=$(grep -A5 "tint_color" "$MOBILE_API_DIR/ios_release.py" \
      | grep 'default=' | grep -oE '"#[0-9a-fA-F]+"' | head -1 || echo "(not found)")
    fail "IOSBrandingExtension.tint_color default ($CURRENT_DEFAULT) does not match canonical --color-magenta ($MAGENTA_VAL)"
  fi
else
  skip "Cannot check tint_color default: --color-magenta not found in tokens.css"
fi

# ---------------------------------------------------------------------------
# Section 6: Token refresh stub detection (Gap 2)
# ---------------------------------------------------------------------------
echo ""
echo "--- Section 6: Token refresh stub detection (Gap 2) ---"

# The stub uses secrets.token_urlsafe which is not an OAuth2 integration
if grep -q "token_urlsafe" "$MOBILE_API_DIR/ios_views.py"; then
  fail "TokenRefreshView uses secrets.token_urlsafe stub — not integrated with django-oauth-toolkit"
else
  pass "TokenRefreshView does not use secrets.token_urlsafe stub"
fi

# There should be integration with the LMS OAuth2 endpoint
if grep -qE "(oauth2_provider|access_token.*token.*endpoint|proxy.*oauth)" \
    "$MOBILE_API_DIR/ios_views.py" 2>/dev/null; then
  pass "TokenRefreshView references OAuth2 provider or upstream token endpoint"
else
  skip "TokenRefreshView OAuth2 provider integration not detected (may be stub)"
fi

# ---------------------------------------------------------------------------
# Section 7: APNs delivery stub detection (Gap 3)
# ---------------------------------------------------------------------------
echo ""
echo "--- Section 7: APNs delivery stub detection (Gap 3) ---"

# The view should either delegate to Celery or call APNs HTTP/2 directly
if grep -q "In production, send to APNs here" "$MOBILE_API_DIR/ios_views.py"; then
  fail "APNsDeliveryView contains 'In production, send to APNs here' placeholder — notifications not sent"
else
  pass "APNsDeliveryView does not contain unimplemented placeholder comment"
fi

# Check if push notifications tasks are referenced
if grep -q "openedx_push_notifications" "$MOBILE_API_DIR/ios_views.py" || \
   grep -q "push_notification" "$MOBILE_API_DIR/ios_views.py"; then
  pass "APNsDeliveryView references push notification delivery logic"
else
  skip "APNsDeliveryView does not reference push_notification tasks (expected if stub)"
fi

# ---------------------------------------------------------------------------
# Section 8: AASA file correctness (Gap 4)
# ---------------------------------------------------------------------------
echo ""
echo "--- Section 8: AASA file (apple-app-site-association) correctness (Gap 4) ---"

if [[ ! -f "$AASA_FILE" ]]; then
  fail "AASA file missing: $AASA_FILE"
else
  pass "AASA file exists"

  # Team ID placeholder check
  if grep -q "TEAM_ID" "$AASA_FILE"; then
    fail "AASA file contains 'TEAM_ID' placeholder — replace with '44F7G2D7U6'"
  else
    pass "AASA file does not contain TEAM_ID placeholder"
  fi

  # Bundle ID consistency check: should match com.mereka.academy.mobile
  EXPECTED_BUNDLE="com.mereka.academy.mobile"
  if grep -q "$EXPECTED_BUNDLE" "$AASA_FILE"; then
    pass "AASA file references correct bundle ID ($EXPECTED_BUNDLE)"
  else
    ACTUAL_BUNDLE=$(grep -oE '[A-Z0-9]+\.[a-z.]+' "$AASA_FILE" | head -1 || echo "(not found)")
    fail "AASA bundle ID ($ACTUAL_BUNDLE) does not match expected ($EXPECTED_BUNDLE)"
  fi
fi

# ---------------------------------------------------------------------------
# Section 9: URL conflict between device registration apps (Gap 5)
# ---------------------------------------------------------------------------
echo ""
echo "--- Section 9: Push notification URL conflict check ---"

MOBILE_API_REG_URL="notifications/register/"
PUSH_NOTIF_REG_URL="notifications/register/"

MOBILE_API_URLS="$MOBILE_API_DIR/urls.py"
PUSH_NOTIF_URLS="$PUSH_NOTIF_DIR/urls.py"

if [[ -f "$MOBILE_API_URLS" ]] && [[ -f "$PUSH_NOTIF_URLS" ]]; then
  if grep -q "$MOBILE_API_REG_URL" "$MOBILE_API_URLS" && \
     grep -q "$PUSH_NOTIF_REG_URL" "$PUSH_NOTIF_URLS"; then
    fail "Both openedx_mobile_api and openedx_push_notifications define '$MOBILE_API_REG_URL' — URL conflict; only one can win in LMS urlconf"
  else
    pass "No URL conflict detected between device registration endpoints"
  fi
else
  skip "Cannot check URL conflict: one or both urls.py files missing"
fi

# ---------------------------------------------------------------------------
# Section 10: Branding config API endpoint structure
# ---------------------------------------------------------------------------
echo ""
echo "--- Section 10: Branding config API endpoint structure ---"

# MobileBrandingConfigView should be AllowAny (unauthenticated mobile clients need branding)
if grep -A10 "class MobileBrandingConfigView" "$MOBILE_API_DIR/views.py" \
    | grep -q "AllowAny"; then
  pass "MobileBrandingConfigView uses AllowAny (unauthenticated access for app boot)"
else
  fail "MobileBrandingConfigView does not use AllowAny — mobile app boot will fail without auth"
fi

# Branding API should include primary_color in serializer output
if grep -q "\"primary_color\"" "$MOBILE_API_DIR/serializers.py" || \
   grep -q "'primary_color'" "$MOBILE_API_DIR/serializers.py"; then
  pass "MobileBrandingConfigSerializer includes primary_color field"
else
  fail "MobileBrandingConfigSerializer does not include primary_color field"
fi

# Branding API should include secondary_color in serializer output
if grep -q "\"secondary_color\"" "$MOBILE_API_DIR/serializers.py" || \
   grep -q "'secondary_color'" "$MOBILE_API_DIR/serializers.py"; then
  pass "MobileBrandingConfigSerializer includes secondary_color field"
else
  fail "MobileBrandingConfigSerializer does not include secondary_color field"
fi

# ---------------------------------------------------------------------------
# Section 11: iOS branding API endpoint structure
# ---------------------------------------------------------------------------
echo ""
echo "--- Section 11: iOS branding API endpoint structure ---"

IOS_RELEASE_URLS="$MOBILE_API_DIR/ios_release_urls.py"

if [[ -f "$IOS_RELEASE_URLS" ]]; then
  if grep -q "ios-branding" "$IOS_RELEASE_URLS"; then
    pass "iOS branding URL pattern registered (ios-branding)"
  else
    fail "iOS branding URL pattern not found in $IOS_RELEASE_URLS"
  fi

  if grep -q "org_slug" "$IOS_RELEASE_URLS"; then
    pass "iOS branding URL supports per-tenant org_slug parameter"
  else
    fail "iOS branding URL does not support org_slug parameter"
  fi
else
  fail "iOS release URL config missing: $IOS_RELEASE_URLS"
fi

# IOSBrandingView should be AllowAny
if grep -A10 "class IOSBrandingView" "$MOBILE_API_DIR/ios_release_views.py" \
    | grep -q "AllowAny"; then
  pass "IOSBrandingView uses AllowAny (unauthenticated access for app boot)"
else
  fail "IOSBrandingView does not use AllowAny"
fi

# ---------------------------------------------------------------------------
# Section 12: Parity doc completeness
# ---------------------------------------------------------------------------
echo ""
echo "--- Section 12: Parity documentation completeness ---"

# Doc should identify the three critical gaps
grep -q "Model defaults do not reflect canonical tokens" "$PARITY_DOC" \
  && pass "Parity doc documents Gap 1 (model defaults)" \
  || fail "Parity doc missing Gap 1 (model defaults)"

grep -q "Token refresh endpoint is a stub" "$PARITY_DOC" \
  && pass "Parity doc documents Gap 2 (token refresh stub)" \
  || fail "Parity doc missing Gap 2 (token refresh stub)"

grep -q "APNs delivery view does not send" "$PARITY_DOC" \
  && pass "Parity doc documents Gap 3 (APNs stub)" \
  || fail "Parity doc missing Gap 3 (APNs stub)"

grep -q "AASA.*placeholder" "$PARITY_DOC" || grep -q "placeholder team ID" "$PARITY_DOC" \
  && pass "Parity doc documents Gap 4 (AASA placeholder)" \
  || fail "Parity doc missing Gap 4 (AASA placeholder)"

# Doc should contain token-to-mobile mapping table
grep -q "Token.*Mobile Mapping" "$PARITY_DOC" \
  && pass "Parity doc contains token-to-mobile mapping section" \
  || fail "Parity doc missing token-to-mobile mapping section"

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=== Results: ${PASS} PASS / ${FAIL} FAIL / ${SKIP} SKIP ==="
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "${RED}Verification FAILED — ${FAIL} check(s) require attention.${NC}"
  echo "See docs/reference/architecture/MOBILE_TOKEN_PARITY.md for remediation guidance."
  exit 1
else
  echo -e "${GREEN}Verification PASSED.${NC}"
  exit 0
fi
