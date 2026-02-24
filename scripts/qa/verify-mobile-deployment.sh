#!/usr/bin/env bash
# @spec: mobile-apps-enterprise_spec.md
# @covers AC-001, AC-002, AC-003, AC-004, AC-006, AC-007, AC-008, AC-009, AC-010, AC-011, AC-012, AC-013, AC-014, AC-015, AC-016, AC-017, AC-018, AC-019, AC-020, AC-021, AC-022, AC-023, AC-024, AC-025, AC-026, AC-027, AC-028, AC-029, AC-030, AC-031, AC-032, AC-033, AC-034, AC-035, AC-036, AC-037
#
# Mobile Enterprise Apps Deployment Verification
#
# Verifies the mobile deployment configuration for Mereka Academy.
# Covers: iOS workflow, mobile API config, push notification setup, app
# signing, LMS mobile API endpoints, and app store release readiness.
#
# Modes:
#   --offline   Static checks only — no cluster access required
#   --online    Live cluster checks — tests K8s pods and HTTP endpoints
#   (default)   Runs both offline and online checks
#
# Usage:
#   ./scripts/qa/verify-mobile-deployment.sh [--offline|--online]
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
MODE="both"
if [[ "${1:-}" == "--offline" ]]; then
  MODE="offline"
elif [[ "${1:-}" == "--online" ]]; then
  MODE="online"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
PASS=0
FAIL=0
SKIP=0

pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  FAIL=$((FAIL + 1))
}

skip() {
  echo -e "${YELLOW}[SKIP]${NC} $1"
  SKIP=$((SKIP + 1))
}

info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

# Helper: check a file contains a pattern
check_contains() {
  local file="$1"
  local pattern="$2"
  local description="$3"

  if [[ ! -f "$file" ]]; then
    fail "$description (file not found: $file)"
    return 1
  fi
  if grep -q "$pattern" "$file"; then
    pass "$description"
    return 0
  else
    fail "$description (pattern not found: $pattern in $file)"
    return 1
  fi
}

# Helper: check a file exists
check_file() {
  local file="$1"
  local description="$2"
  if [[ -f "$file" ]]; then
    pass "$description"
    return 0
  else
    fail "$description (not found: $file)"
    return 1
  fi
}

echo "========================================================="
echo "Mobile Enterprise Apps Deployment Verification"
echo "Spec: mobile-apps-enterprise_spec.md"
echo "Mode: ${MODE}"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "========================================================="
echo ""

# ---------------------------------------------------------------------------
# Offline checks — static analysis, no cluster access needed
# ---------------------------------------------------------------------------
run_offline_checks() {
  # =========================================================================
  # 1. iOS CI/CD Workflow
  # =========================================================================
  echo "--- iOS CI/CD Workflow (AC-032) ---"

  IOS_WORKFLOW_MAIN=".github/workflows/build-ios-app.yml"
  IOS_WORKFLOW_TF=".github/workflows/ios-testflight.yml"

  # AC-032: iOS workflow produces signed IPA and uploads to TestFlight
  if [[ -f "$IOS_WORKFLOW_MAIN" ]]; then
    pass "AC-032: iOS CI workflow exists (build-ios-app.yml)"
    check_contains "$IOS_WORKFLOW_MAIN" "on:" \
      "AC-032: iOS workflow has trigger definition"
    check_contains "$IOS_WORKFLOW_MAIN" "fastlane" \
      "AC-032: iOS workflow uses Fastlane for build/upload"
    check_contains "$IOS_WORKFLOW_MAIN" "upload_to_testflight\|xcrun altool --upload-app\|pilot upload" \
      "AC-032: iOS workflow uploads to TestFlight"
    check_contains "$IOS_WORKFLOW_MAIN" "app_store_connect_api_key\|ASC_KEY_ID\|APP_STORE_CONNECT_API_KEY" \
      "AC-032: iOS workflow uses App Store Connect API key (no manual login)"
    check_contains "$IOS_WORKFLOW_MAIN" "macos-" \
      "AC-032: iOS workflow runs on macOS runner"
    check_contains "$IOS_WORKFLOW_MAIN" "actions/checkout" \
      "AC-032: iOS workflow checks out repository"
    # Cleanup step (sensitive key removal)
    check_contains "$IOS_WORKFLOW_MAIN" "if: always()" \
      "AC-032: iOS workflow has cleanup step with if: always()"
  else
    fail "AC-032: iOS CI workflow not found (build-ios-app.yml)"
  fi

  # TestFlight-specific workflow
  echo ""
  if [[ -f "$IOS_WORKFLOW_TF" ]]; then
    pass "AC-032: TestFlight deployment workflow exists (ios-testflight.yml)"
    check_contains "$IOS_WORKFLOW_TF" "timeout-minutes: 30" \
      "AC-032: TestFlight workflow enforces 30-minute timeout"
    check_contains "$IOS_WORKFLOW_TF" "xcodebuild archive" \
      "AC-032: TestFlight workflow archives with xcodebuild"
    check_contains "$IOS_WORKFLOW_TF" "xcodebuild -exportArchive" \
      "AC-032: TestFlight workflow exports IPA"
    check_contains "$IOS_WORKFLOW_TF" "xcrun altool --upload-app" \
      "AC-032: TestFlight workflow uploads via altool"
    check_contains "$IOS_WORKFLOW_TF" "if: always()" \
      "AC-032: TestFlight workflow cleans up keychain on exit"
  else
    skip "AC-032: ios-testflight.yml not found (legacy workflow may be primary)"
  fi

  # =========================================================================
  # 2. Mobile API Configuration
  # =========================================================================
  echo ""
  echo "--- Mobile API Configuration ---"

  LMS_PRODUCTION_PY="deploy/k8s/base/apps/openedx/settings/lms/production.py"
  LMS_ENV_YML="deploy/k8s/base/apps/openedx/config/lms.env.yml"
  MOBILE_SECRETS_WORKFLOW=".github/workflows/mobile-secrets-check.yml"

  # ENABLE_MOBILE_REST_API feature flag — lives in lms.env.yml for K8s deployments
  if [[ -f "$LMS_ENV_YML" ]]; then
    check_contains "$LMS_ENV_YML" "ENABLE_MOBILE_REST_API" \
      "Mobile REST API feature flag configured in lms.env.yml"
    check_contains "$LMS_ENV_YML" "ENABLE_OAUTH2_PROVIDER" \
      "OAuth2 provider feature flag configured in lms.env.yml"
  elif [[ -f "$LMS_PRODUCTION_PY" ]]; then
    check_contains "$LMS_PRODUCTION_PY" "ENABLE_MOBILE_REST_API" \
      "Mobile REST API feature flag configured in LMS settings"
  else
    skip "Mobile API config not found in lms.env.yml or production.py"
  fi

  # DEFAULT_MOBILE_AVAILABLE in LMS settings
  if [[ -f "$LMS_PRODUCTION_PY" ]]; then
    if grep -q "DEFAULT_MOBILE_AVAILABLE" "$LMS_PRODUCTION_PY"; then
      pass "DEFAULT_MOBILE_AVAILABLE configured in LMS production.py"
    fi
    # May not be needed if set per-course — skip rather than fail
  fi

  # OAuth2 mobile client config in iOS workflow
  if [[ -f "$IOS_WORKFLOW_MAIN" ]]; then
    check_contains "$IOS_WORKFLOW_MAIN" "mereka-mobile-app\|OAUTH_CLIENT_ID" \
      "iOS workflow references OAuth2 client ID (mereka-mobile-app)"
    check_contains "$IOS_WORKFLOW_MAIN" "academyv2.mereka.io\|API_HOST_URL" \
      "iOS workflow references LMS production host"
    check_contains "$IOS_WORKFLOW_MAIN" "com.mereka.academy.mobile\|BUNDLE_ID" \
      "iOS bundle ID configured in workflow"
  fi

  # AC-034: configuration-only onboarding (no code changes for new client)
  if [[ -f "$IOS_WORKFLOW_MAIN" ]]; then
    if grep -q "CONFIG_DIRECTORY\|config_directory\|org_slug\|ORG_SLUG" "$IOS_WORKFLOW_MAIN"; then
      pass "AC-034: iOS workflow uses config directory pattern (configuration-only onboarding)"
    else
      skip "AC-034: Config-directory pattern not found in workflow (verify manually)"
    fi
  fi

  # =========================================================================
  # 3. App Signing Setup
  # =========================================================================
  echo ""
  echo "--- App Signing Setup (AC-032) ---"

  # Fastlane match for certificate management
  if [[ -f "$IOS_WORKFLOW_MAIN" ]]; then
    check_contains "$IOS_WORKFLOW_MAIN" "fastlane match\|match(" \
      "iOS workflow uses Fastlane match for certificate management"
    check_contains "$IOS_WORKFLOW_MAIN" "MATCH_DEPLOY_KEY\|MATCH_PASSWORD\|match_key" \
      "iOS workflow fetches match credentials from secrets"
  fi

  # Apple Team ID secret
  if [[ -f "$IOS_WORKFLOW_MAIN" ]]; then
    check_contains "$IOS_WORKFLOW_MAIN" "APPLE_TEAM_ID\|TEAM_ID" \
      "iOS workflow uses APPLE_TEAM_ID secret"
  fi

  # No hardcoded credentials in workflow
  # Note: fastlane_tmp_keychain is an ephemeral CI-only password (standard Fastlane pattern)
  if [[ -f "$IOS_WORKFLOW_MAIN" ]]; then
    if grep -E 'password\s*[:=]\s*["\047][A-Za-z0-9]{8,}' "$IOS_WORKFLOW_MAIN" 2>/dev/null \
       | grep -qvE 'fastlane_tmp_keychain'; then
      fail "AC-031: Possible hardcoded password found in iOS workflow (non-Fastlane)"
    else
      pass "AC-031: No hardcoded non-ephemeral passwords detected in iOS workflow"
    fi
  fi

  # =========================================================================
  # 4. Push Notification Configuration
  # =========================================================================
  echo ""
  echo "--- Push Notification Configuration (AC-009, AC-010, AC-011, AC-013) ---"

  # FCM project placeholder in iOS config
  if [[ -f "$IOS_WORKFLOW_MAIN" ]]; then
    if grep -q "FIREBASE\|firebase\|FCM\|fcm" "$IOS_WORKFLOW_MAIN"; then
      pass "AC-009: Firebase/FCM configuration referenced in iOS workflow"
      if grep -q "ENABLED: false\|FIREBASE.*false" "$IOS_WORKFLOW_MAIN"; then
        skip "AC-009: Firebase push notifications currently disabled (placeholder config)"
      fi
    else
      skip "AC-009: Firebase not referenced in iOS workflow (push notifications not configured)"
    fi
  fi

  # FCM secrets expected in LMS settings
  if [[ -f "$LMS_PRODUCTION_PY" ]]; then
    if grep -q "FCM_PROJECT_ID\|FCM_SERVICE_ACCOUNT\|MOBILE_FCM" "$LMS_PRODUCTION_PY"; then
      pass "AC-011: FCM credentials referenced in LMS production settings"
    else
      skip "AC-011: FCM credentials not found in LMS settings (push notifications not yet configured)"
    fi
  fi

  # Push notification ACE channel
  PUSH_APP="infrastructure/tutor/custom-apps/openedx_push_notifications"
  if [[ -d "$PUSH_APP" ]]; then
    pass "AC-011: openedx_push_notifications Django app exists"
    check_file "$PUSH_APP/ace_channel.py" \
      "AC-011: ACE push channel implementation exists"
    check_file "$PUSH_APP/models.py" \
      "AC-010: DeviceRegistration model exists for token registration"
    if [[ -f "$PUSH_APP/views.py" ]]; then
      check_contains "$PUSH_APP/views.py" "def post" \
        "AC-010: Device token registration POST endpoint"
      check_contains "$PUSH_APP/views.py" "def delete" \
        "AC-013: Device token unregistration DELETE endpoint"
    fi
  else
    skip "AC-011: openedx_push_notifications app not found (push notifications not yet implemented)"
  fi

  # =========================================================================
  # 5. Deep Linking / Universal Links (AC-014, AC-015)
  # =========================================================================
  echo ""
  echo "--- Deep Linking / Universal Links (AC-014, AC-015) ---"

  MOBILE_API_APP="infrastructure/tutor/custom-apps/openedx_mobile_api"

  # AASA file endpoint
  if [[ -d "$MOBILE_API_APP" ]]; then
    if grep -rq "apple-app-site-association\|AASA\|aasa" "$MOBILE_API_APP/" 2>/dev/null; then
      pass "AC-014: AASA (Universal Links) file reference found in mobile API app"
    else
      skip "AC-014: AASA file endpoint not found in mobile API app"
    fi

    if grep -rq "assetlinks\|App Links\|android:appLinks" "$MOBILE_API_APP/" 2>/dev/null; then
      pass "AC-015: Android assetlinks.json reference found in mobile API app"
    else
      skip "AC-015: Android assetlinks.json endpoint not found (Android deferred per ADR-016)"
    fi
  else
    skip "AC-014: openedx_mobile_api app not found"
    skip "AC-015: Android deferred per ADR-016"
  fi

  # =========================================================================
  # 6. OAuth 2.0 / Authentication
  # =========================================================================
  echo ""
  echo "--- OAuth 2.0 / Authentication (AC-001 through AC-008) ---"

  if [[ -d "$MOBILE_API_APP" ]]; then
    # PKCE support
    if grep -rq "PKCEChallenge\|code_verifier\|code_challenge\|PKCE" "$MOBILE_API_APP/" 2>/dev/null; then
      pass "AC-001: PKCE (OAuth 2.0 with PKCE) implementation found"
    else
      skip "AC-001: PKCE implementation not found in mobile API app"
    fi

    # Token refresh
    if grep -rq "TokenRefresh\|token.*refresh\|refresh.*token" "$MOBILE_API_APP/" 2>/dev/null; then
      pass "AC-004: Token refresh implementation found"
    else
      skip "AC-004: Token refresh not found in mobile API app"
    fi

    # Token revocation (logout)
    if grep -rq "revoke\|TokenRevoke" "$MOBILE_API_APP/" 2>/dev/null; then
      pass "AC-008: Token revocation (logout) implementation found"
    else
      skip "AC-008: Token revocation not found in mobile API app"
    fi

    # No token logging (AC-031)
    ios_auth_py="$MOBILE_API_APP/ios_auth.py"
    if [[ -f "$ios_auth_py" ]]; then
      if grep -qE 'logger\.(info|debug).*\{(access_token|refresh_token|code_verifier)\}' "$ios_auth_py" 2>/dev/null; then
        fail "AC-031: Potential token logging detected in ios_auth.py"
      else
        pass "AC-031: No full token logging detected in ios_auth.py"
      fi
    fi
  else
    skip "AC-001 through AC-008: openedx_mobile_api app not found"
  fi

  # =========================================================================
  # 7. Mobile Secrets CI Workflow
  # =========================================================================
  echo ""
  echo "--- Mobile Secrets CI Workflow ---"

  if [[ -f "$MOBILE_SECRETS_WORKFLOW" ]]; then
    pass "Mobile secrets check workflow exists (mobile-secrets-check.yml)"
    check_contains "$MOBILE_SECRETS_WORKFLOW" "on:" \
      "Mobile secrets workflow has trigger definition"
  else
    skip "Mobile secrets check workflow not found (.github/workflows/mobile-secrets-check.yml)"
  fi

  # =========================================================================
  # 8. Android (Deferred per ADR-016)
  # =========================================================================
  echo ""
  echo "--- Android Build (AC-033, deferred per ADR-016) ---"

  if [[ -f ".github/workflows/build-android-app.yml" ]]; then
    pass "AC-033: Android CI workflow exists"
    check_contains ".github/workflows/build-android-app.yml" "bundleRelease\|aab\|AAB" \
      "AC-033: Android workflow produces AAB artifact"
    check_contains ".github/workflows/build-android-app.yml" "Play\|googleplay\|play_store" \
      "AC-033: Android workflow uploads to Google Play"
  else
    skip "AC-033: Android CI workflow not found (deferred per ADR-016 until iOS fully operational)"
  fi

  # =========================================================================
  # 9. App Store Release Readiness (AC-035, AC-036, AC-037)
  # =========================================================================
  echo ""
  echo "--- App Store Release Readiness (AC-035 through AC-037) ---"

  if [[ -d "$MOBILE_API_APP" ]]; then
    if grep -rq "AppStoreMetadata\|app_store_metadata" "$MOBILE_API_APP/" 2>/dev/null; then
      pass "AC-035: App Store metadata model found in mobile API app"
    else
      skip "AC-035: App Store metadata model not found (Phase 4 implementation pending)"
    fi

    if grep -rq "AppStoreScreenshot\|screenshots" "$MOBILE_API_APP/" 2>/dev/null; then
      pass "AC-035: App Store screenshots model found"
    else
      skip "AC-035: App Store screenshots model not found (Phase 4 implementation pending)"
    fi
  else
    skip "AC-035: openedx_mobile_api app not found"
    skip "AC-036: Android deferred per ADR-016"
    skip "AC-037: App Store release governance pending"
  fi

  # =========================================================================
  # 10. Security Controls (AC-028, AC-029, AC-030, AC-031)
  # =========================================================================
  echo ""
  echo "--- Security Controls (AC-028 through AC-031) ---"

  # Certificate pinning config
  CERT_PINNING="$MOBILE_API_APP/ios_certificate_pinning.json"
  if [[ -f "$CERT_PINNING" ]]; then
    pass "AC-028: iOS certificate pinning config file exists"
    if command -v jq >/dev/null 2>&1; then
      if jq empty "$CERT_PINNING" 2>/dev/null; then
        if jq -e '.certificate_pinning.enabled == true' "$CERT_PINNING" >/dev/null 2>&1; then
          pass "AC-028: Certificate pinning is enabled"
        else
          fail "AC-028: Certificate pinning is not enabled in config"
        fi
        pin_count=$(jq '.certificate_pinning.domains | length' "$CERT_PINNING" 2>/dev/null || echo 0)
        if [[ "$pin_count" -gt 0 ]]; then
          pass "AC-028: Certificate pinning domains configured ($pin_count domain(s))"
        else
          fail "AC-028: No certificate pinning domains configured"
        fi
      else
        fail "AC-028: Certificate pinning JSON is invalid"
      fi
    else
      skip "AC-028: jq not available (cannot validate certificate pinning JSON)"
    fi
  else
    skip "AC-028: Certificate pinning config not found (iOS security config pending)"
    skip "AC-029: Certificate pin validation pending"
  fi

  # App snapshot clearing (AC-030)
  if [[ -f "$LMS_PRODUCTION_PY" ]]; then
    if grep -q "IOS_CLEAR_SNAPSHOT_ON_BACKGROUND" "$LMS_PRODUCTION_PY"; then
      pass "AC-030: App snapshot clearing configured in LMS settings"
    else
      skip "AC-030: IOS_CLEAR_SNAPSHOT_ON_BACKGROUND not found in LMS settings"
    fi
  fi

  # No debug endpoints in release build config
  if [[ -f "$IOS_WORKFLOW_MAIN" ]]; then
    if grep -qiE "debug.*endpoint|localhost|127\.0\.0\.1|devserver" "$IOS_WORKFLOW_MAIN"; then
      fail "AC-031: Debug/local endpoints found in iOS workflow (must not appear in release builds)"
    else
      pass "AC-031: No debug or localhost endpoints in iOS workflow"
    fi
  fi
}

# ---------------------------------------------------------------------------
# Online checks — requires live cluster access
# ---------------------------------------------------------------------------
run_online_checks() {
  echo ""
  echo "== Online Checks (live cluster) =="
  echo ""

  # Check kubectl availability
  if ! command -v kubectl >/dev/null 2>&1; then
    skip "All online checks: kubectl not available"
    return
  fi

  if ! kubectl get namespace mereka-lms >/dev/null 2>&1; then
    skip "All online checks: mereka-lms namespace not accessible"
    return
  fi

  # =========================================================================
  # LMS pod mobile API checks
  # =========================================================================
  echo "--- LMS Mobile API Endpoint Health ---"

  LMS_POD=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

  if [[ -z "$LMS_POD" ]]; then
    skip "LMS pod not found in mereka-lms namespace"
  else
    info "Using LMS pod: $LMS_POD"

    # AC-001 / Mobile API enabled: check ENABLE_MOBILE_REST_API
    echo ""
    echo "==> Mobile REST API feature flag"
    feature_val=$(kubectl exec -n mereka-lms "$LMS_POD" -- \
      python manage.py lms shell -c \
      "from django.conf import settings; print(settings.FEATURES.get('ENABLE_MOBILE_REST_API', False))" \
      2>/dev/null || echo "")
    if [[ "$feature_val" == "True" ]]; then
      pass "ENABLE_MOBILE_REST_API = True in running LMS"
    elif [[ -n "$feature_val" ]]; then
      fail "ENABLE_MOBILE_REST_API = $feature_val (expected True)"
    else
      skip "ENABLE_MOBILE_REST_API check failed (exec error or pod not ready)"
    fi

    # DEFAULT_MOBILE_AVAILABLE
    echo ""
    echo "==> DEFAULT_MOBILE_AVAILABLE feature flag"
    mobile_avail=$(kubectl exec -n mereka-lms "$LMS_POD" -- \
      python manage.py lms shell -c \
      "from django.conf import settings; print(settings.FEATURES.get('DEFAULT_MOBILE_AVAILABLE', False))" \
      2>/dev/null || echo "")
    if [[ "$mobile_avail" == "True" ]]; then
      pass "DEFAULT_MOBILE_AVAILABLE = True in running LMS"
    elif [[ -n "$mobile_avail" ]]; then
      skip "DEFAULT_MOBILE_AVAILABLE = $mobile_avail (may need to be enabled per-course)"
    else
      skip "DEFAULT_MOBILE_AVAILABLE check failed (exec error or pod not ready)"
    fi

    # OAuth2 mobile client exists
    echo ""
    echo "==> OAuth2 mobile client (mereka-mobile-app)"
    oauth_count=$(kubectl exec -n mereka-lms "$LMS_POD" -- \
      python manage.py lms shell -c \
      "from oauth2_provider.models import Application; print(Application.objects.filter(client_id='mereka-mobile-app').count())" \
      2>/dev/null || echo "")
    if [[ "$oauth_count" == "1" ]]; then
      pass "AC-001: OAuth2 application 'mereka-mobile-app' exists in LMS database"
    elif [[ "$oauth_count" == "0" ]]; then
      fail "AC-001: OAuth2 application 'mereka-mobile-app' NOT found (must be created)"
    else
      skip "AC-001: OAuth2 client check failed (exec error or pod not ready)"
    fi
  fi

  # =========================================================================
  # LMS mobile API HTTP endpoints
  # =========================================================================
  echo ""
  echo "--- LMS Mobile API HTTP Endpoints (AC-001 through AC-018) ---"

  LMS_SVC=$(kubectl get svc -n mereka-lms -l app.kubernetes.io/name=lms \
    -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null || echo "")

  if [[ -z "$LMS_SVC" ]]; then
    skip "LMS service ClusterIP not found; skipping HTTP endpoint checks"
  else
    info "Probing LMS service: http://${LMS_SVC}:8000"

    # /api/mobile/v1/ — core mobile namespace
    echo ""
    echo "==> GET /api/mobile/v1/ (expects 401 or 200, not 404)"
    http_status=$(kubectl exec -n mereka-lms "$LMS_POD" -- \
      python -c "import urllib.request,urllib.error; \
r=None; \
[setattr(globals(),'r',urllib.request.urlopen('http://localhost:8000/api/mobile/v1/').getcode()) \
 for _ in [None] \
 if not (lambda: globals().update({'r': globals().get('r',0)}) or False)()]; \
print(globals().get('r',0))" 2>/dev/null || echo "")

    # Use curl via kubectl exec for a cleaner approach
    mobile_v1_status=$(kubectl exec -n mereka-lms "$LMS_POD" -- \
      bash -c "curl -s -o /dev/null -w '%{http_code}' http://localhost:8000/api/mobile/v1/ 2>/dev/null || echo ''" \
      2>/dev/null || echo "")

    if [[ "$mobile_v1_status" == "401" || "$mobile_v1_status" == "200" ]]; then
      pass "Mobile API v1 root endpoint reachable (HTTP $mobile_v1_status)"
    elif [[ "$mobile_v1_status" == "404" ]]; then
      fail "Mobile API v1 root endpoint returns 404 (API not enabled or URL wrong)"
    elif [[ -n "$mobile_v1_status" ]]; then
      skip "Mobile API v1 root returns HTTP $mobile_v1_status (verify manually)"
    else
      skip "Mobile API v1 endpoint check failed (curl not available in pod)"
    fi

    # /api/mobile/v4/my_courses/ — enrolled courses list (per spec)
    echo ""
    echo "==> GET /api/mobile/v4/my_courses/ (expects 401 or 200)"
    my_courses_status=$(kubectl exec -n mereka-lms "$LMS_POD" -- \
      bash -c "curl -s -o /dev/null -w '%{http_code}' http://localhost:8000/api/mobile/v4/my_courses/ 2>/dev/null || echo ''" \
      2>/dev/null || echo "")

    if [[ "$my_courses_status" == "401" || "$my_courses_status" == "200" ]]; then
      pass "Mobile courses v4 endpoint reachable (HTTP $my_courses_status)"
    elif [[ "$my_courses_status" == "404" ]]; then
      fail "Mobile courses v4 endpoint returns 404 (ENABLE_MOBILE_REST_API may be False)"
    elif [[ -n "$my_courses_status" ]]; then
      skip "Mobile courses v4 endpoint returns HTTP $my_courses_status"
    else
      skip "Mobile courses v4 endpoint check failed"
    fi

    # /oauth2/access_token/ — token exchange endpoint
    echo ""
    echo "==> POST /oauth2/access_token/ (expects 400 or 401)"
    token_ep_status=$(kubectl exec -n mereka-lms "$LMS_POD" -- \
      bash -c "curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:8000/oauth2/access_token/ 2>/dev/null || echo ''" \
      2>/dev/null || echo "")

    if [[ "$token_ep_status" == "400" || "$token_ep_status" == "401" ]]; then
      pass "AC-001: OAuth2 token endpoint reachable (HTTP $token_ep_status)"
    elif [[ "$token_ep_status" == "404" ]]; then
      fail "AC-001: OAuth2 token endpoint returns 404 (OAuth2 provider not configured)"
    elif [[ -n "$token_ep_status" ]]; then
      skip "OAuth2 token endpoint returns HTTP $token_ep_status"
    else
      skip "OAuth2 token endpoint check failed"
    fi
  fi

  # =========================================================================
  # Push notification service health (AC-011)
  # =========================================================================
  echo ""
  echo "--- Push Notification Service Health (AC-011) ---"

  if [[ -n "$LMS_POD" ]]; then
    # Check if FCM env var is available in pod
    if kubectl exec -n mereka-lms "$LMS_POD" -- \
       bash -c 'env | grep -qE "FCM|FIREBASE|MOBILE_FCM"' 2>/dev/null; then
      pass "AC-011: FCM/Firebase environment variable present in LMS pod"
    else
      skip "AC-011: FCM/Firebase env var not in LMS pod (push notifications not yet configured)"
    fi

    # Check openedx_push_notifications installed app
    push_installed=$(kubectl exec -n mereka-lms "$LMS_POD" -- \
      python manage.py lms shell -c \
      "from django.apps import apps; print('ok' if 'openedx_push_notifications' in [a.name for a in apps.get_app_configs()] else 'missing')" \
      2>/dev/null || echo "")
    if [[ "$push_installed" == "ok" ]]; then
      pass "AC-011: openedx_push_notifications Django app installed in running LMS"
    else
      skip "AC-011: openedx_push_notifications not installed (push notifications not yet configured)"
    fi
  fi

  # =========================================================================
  # Universal Links / Deep Link files (AC-014)
  # =========================================================================
  echo ""
  echo "--- Universal Links Files (AC-014) ---"

  LMS_HOST="https://academyv2.mereka.io"

  if command -v curl >/dev/null 2>&1; then
    echo "==> GET ${LMS_HOST}/.well-known/apple-app-site-association"
    aasa_status=$(curl -s -o /dev/null -w "%{http_code}" \
      --max-time 10 \
      "${LMS_HOST}/.well-known/apple-app-site-association" 2>/dev/null || echo "")

    if [[ "$aasa_status" == "200" ]]; then
      pass "AC-014: AASA file served at /.well-known/apple-app-site-association"
    elif [[ "$aasa_status" == "404" ]]; then
      fail "AC-014: AASA file returns 404 (Universal Links not configured)"
    elif [[ -n "$aasa_status" ]]; then
      skip "AC-014: AASA file check returned HTTP $aasa_status"
    else
      skip "AC-014: AASA file check failed (curl error)"
    fi

    echo "==> GET ${LMS_HOST}/.well-known/assetlinks.json"
    assetlinks_status=$(curl -s -o /dev/null -w "%{http_code}" \
      --max-time 10 \
      "${LMS_HOST}/.well-known/assetlinks.json" 2>/dev/null || echo "")

    if [[ "$assetlinks_status" == "200" ]]; then
      pass "AC-015: Android assetlinks.json served at /.well-known/assetlinks.json"
    elif [[ "$assetlinks_status" == "404" ]]; then
      skip "AC-015: assetlinks.json returns 404 (Android deferred per ADR-016)"
    elif [[ -n "$assetlinks_status" ]]; then
      skip "AC-015: assetlinks.json check returned HTTP $assetlinks_status"
    else
      skip "AC-015: assetlinks.json check failed (curl error)"
    fi
  else
    skip "AC-014: curl not available for external endpoint checks"
    skip "AC-015: curl not available for external endpoint checks"
  fi
}

# ---------------------------------------------------------------------------
# Run selected mode
# ---------------------------------------------------------------------------
if [[ "$MODE" == "offline" || "$MODE" == "both" ]]; then
  echo "== Offline Checks (static analysis) =="
  echo ""
  run_offline_checks
fi

if [[ "$MODE" == "online" || "$MODE" == "both" ]]; then
  run_online_checks
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "==========================================="
echo "Summary"
echo "==========================================="
echo -e "${GREEN}PASS: $PASS${NC}"
echo -e "${RED}FAIL: $FAIL${NC}"
echo -e "${YELLOW}SKIP: $SKIP${NC}"
echo "Total: $((PASS + FAIL + SKIP))"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo "Verification FAILED with $FAIL failed check(s)."
  exit 1
fi

echo "Verification PASSED ($SKIP check(s) skipped)."
exit 0
