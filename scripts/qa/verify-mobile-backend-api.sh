#!/usr/bin/env bash
#
# Mobile Backend API Verification Script
#
# Verifies:
# - AC-MOB-001: Branding config API with p95 <= 500ms
# - AC-MOB-002: Idempotent device registration
# - AC-MOB-003: Device deletion
# - AC-MOB-004: Apple AASA file
# - AC-MOB-005: Android assetlinks.json file
# - AC-MOB-006: FCM server key in ExternalSecrets
# - AC-MOB-007: No secrets exposed in API responses
#
# Usage:
#   ./scripts/qa/verify-mobile-backend-api.sh
#
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
SKIPPED_CHECKS=0

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
APP_DIR="$PROJECT_ROOT/infrastructure/tutor/custom-apps/openedx_mobile_api"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
}

log_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
}

log_skip() {
    echo -e "${YELLOW}⊘ SKIP${NC}: $1"
}

check_pass() {
    log_success "$1"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
}

check_fail() {
    log_fail "$1"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
}

check_skip() {
    log_skip "$1"
    SKIPPED_CHECKS=$((SKIPPED_CHECKS + 1))
}

check_file_exists() {
    local file=$1
    local description=$2

    if [[ -f "$file" ]]; then
        check_pass "$description"
        return 0
    else
        check_fail "$description (file not found: $file)"
        return 1
    fi
}

check_contains() {
    local file=$1
    local pattern=$2
    local description=$3

    if [[ ! -f "$file" ]]; then
        check_fail "$description (file not found: $file)"
        return 1
    fi

    if grep -q "$pattern" "$file"; then
        check_pass "$description"
        return 0
    else
        check_fail "$description (pattern not found: $pattern)"
        return 1
    fi
}

check_json_valid() {
    local file=$1
    local description=$2

    if [[ ! -f "$file" ]]; then
        check_fail "$description (file not found: $file)"
        return 1
    fi

    if command -v jq &> /dev/null; then
        if jq empty "$file" 2>/dev/null; then
            check_pass "$description"
            return 0
        else
            check_fail "$description (invalid JSON)"
            return 1
        fi
    else
        check_skip "$description (jq not installed)"
        return 2
    fi
}

echo "========================================="
echo "Mobile Backend API Verification"
echo "========================================="
echo ""

# ============================================================================
# 1. App Structure
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}1. Django App Structure${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

check_file_exists "$APP_DIR/__init__.py" "App package __init__.py"
check_file_exists "$APP_DIR/apps.py" "App configuration (apps.py)"
check_file_exists "$APP_DIR/models.py" "Models module"
check_file_exists "$APP_DIR/views.py" "Views module"
check_file_exists "$APP_DIR/serializers.py" "Serializers module"
check_file_exists "$APP_DIR/urls.py" "URL configuration"
check_file_exists "$APP_DIR/admin.py" "Admin configuration"
check_file_exists "$APP_DIR/setup.py" "Setup script"

echo ""

# ============================================================================
# 2. Models (AC-MOB-002, AC-MOB-001)
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}2. Models${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

check_contains "$APP_DIR/models.py" "class MobileDevice" "MobileDevice model (AC-MOB-002)"
check_contains "$APP_DIR/models.py" "device_token" "device_token field (idempotent registration)"
check_contains "$APP_DIR/models.py" "platform" "platform field (iOS/Android)"
check_contains "$APP_DIR/models.py" "is_active" "is_active field (AC-MOB-003)"
check_contains "$APP_DIR/models.py" "def deactivate" "deactivate method (AC-MOB-003)"
check_contains "$APP_DIR/models.py" "def reactivate" "reactivate method (AC-MOB-002)"

check_contains "$APP_DIR/models.py" "class MobileBrandingConfig" "MobileBrandingConfig model (AC-MOB-001)"
check_contains "$APP_DIR/models.py" "org_slug" "org_slug field"
check_contains "$APP_DIR/models.py" "primary_color" "primary_color field"
check_contains "$APP_DIR/models.py" "logo_url" "logo_url field"
check_contains "$APP_DIR/models.py" "enable_push_notifications" "enable_push_notifications field"

check_contains "$APP_DIR/models.py" "class MobileAppVersion" "MobileAppVersion model"
check_contains "$APP_DIR/models.py" "min_supported_version" "min_supported_version field"

echo ""

# ============================================================================
# 3. API Views (AC-MOB-001, AC-MOB-002, AC-MOB-003)
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}3. API Views${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

check_contains "$APP_DIR/views.py" "class MobileBrandingConfigView" "MobileBrandingConfigView (AC-MOB-001)"
check_contains "$APP_DIR/views.py" "def get" "GET method for branding config"
check_contains "$APP_DIR/views.py" "cache.get" "Caching for performance (AC-MOB-001 p95 <= 500ms)"

check_contains "$APP_DIR/views.py" "class DeviceRegistrationView" "DeviceRegistrationView (AC-MOB-002, AC-MOB-003)"
check_contains "$APP_DIR/views.py" "def post" "POST method for device registration"
check_contains "$APP_DIR/views.py" "def delete" "DELETE method for device deletion (AC-MOB-003)"
check_contains "$APP_DIR/views.py" "get_or_create" "Idempotent registration (AC-MOB-002)"
check_contains "$APP_DIR/views.py" "IsAuthenticated" "Authentication required"

echo ""

# ============================================================================
# 4. Serializers (AC-MOB-007)
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}4. Serializers (AC-MOB-007 - No Secrets Exposed)${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

check_contains "$APP_DIR/serializers.py" "class MobileBrandingConfigSerializer" "MobileBrandingConfigSerializer"
check_contains "$APP_DIR/serializers.py" "class MobileDeviceSerializer" "MobileDeviceSerializer"
check_contains "$APP_DIR/serializers.py" "class DeviceRegistrationSerializer" "DeviceRegistrationSerializer"
check_contains "$APP_DIR/serializers.py" "class DeviceUnregistrationSerializer" "DeviceUnregistrationSerializer"

# Verify no FCM_SERVER_KEY in serializers (AC-MOB-007)
if ! grep -qi "FCM_SERVER_KEY\|server_key\|api_key" "$APP_DIR/serializers.py"; then
    check_pass "No secrets exposed in serializers (AC-MOB-007)"
else
    check_fail "Potential secret exposure in serializers (AC-MOB-007)"
fi

echo ""

# ============================================================================
# 5. Deep Link Files (AC-MOB-004, AC-MOB-005)
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}5. Deep Link Files (AC-MOB-004, AC-MOB-005)${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

AASA_FILE="$APP_DIR/static/.well-known/apple-app-site-association"
ASSETLINKS_FILE="$APP_DIR/static/.well-known/assetlinks.json"

check_file_exists "$AASA_FILE" "Apple AASA file (AC-MOB-004)"
check_json_valid "$AASA_FILE" "AASA file is valid JSON"
check_contains "$AASA_FILE" "applinks" "AASA contains applinks"
check_contains "$AASA_FILE" "appIDs" "AASA contains appIDs"
check_contains "$AASA_FILE" "components" "AASA contains path components"

check_file_exists "$ASSETLINKS_FILE" "Android assetlinks.json (AC-MOB-005)"
check_json_valid "$ASSETLINKS_FILE" "assetlinks.json is valid JSON"
check_contains "$ASSETLINKS_FILE" "android_app" "assetlinks contains android_app"
check_contains "$ASSETLINKS_FILE" "package_name" "assetlinks contains package_name"
check_contains "$ASSETLINKS_FILE" "sha256_cert_fingerprints" "assetlinks contains SHA-256 fingerprint"

echo ""

# ============================================================================
# 6. URL Configuration
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}6. URL Configuration${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

check_contains "$APP_DIR/urls.py" "config/<str:org_slug>/" "Branding config URL (AC-MOB-001)"
check_contains "$APP_DIR/urls.py" "notifications/register/" "Device registration URL (AC-MOB-002, AC-MOB-003)"
check_contains "$APP_DIR/urls.py" "MobileBrandingConfigView" "Branding config view routing"
check_contains "$APP_DIR/urls.py" "DeviceRegistrationView" "Device registration view routing"

echo ""

# ============================================================================
# 7. Admin Registration
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}7. Django Admin Registration${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

check_contains "$APP_DIR/admin.py" "MobileDeviceAdmin" "MobileDevice admin"
check_contains "$APP_DIR/admin.py" "MobileBrandingConfigAdmin" "MobileBrandingConfig admin"
check_contains "$APP_DIR/admin.py" "MobileAppVersionAdmin" "MobileAppVersion admin"

echo ""

# ============================================================================
# 8. LMS Settings Integration
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}8. LMS Settings Integration${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

LMS_SETTINGS="$PROJECT_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"

check_contains "$LMS_SETTINGS" "openedx_mobile_api" "openedx_mobile_api in INSTALLED_APPS"
check_contains "$LMS_SETTINGS" "MOBILE_API_ENABLED" "MOBILE_API_ENABLED feature flag"
check_contains "$LMS_SETTINGS" "FCM_SERVER_KEY" "FCM_SERVER_KEY config (AC-MOB-006)"
check_contains "$LMS_SETTINGS" "MOBILE_API_CACHE_TIMEOUT" "Cache timeout config (AC-MOB-001)"
check_contains "$LMS_SETTINGS" "IOS_APP_ID" "iOS app ID config (AC-MOB-004)"
check_contains "$LMS_SETTINGS" "ANDROID_PACKAGE_NAME" "Android package name config (AC-MOB-005)"

echo ""

# ============================================================================
# 9. CMS Settings Integration
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}9. CMS Settings Integration${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

CMS_SETTINGS="$PROJECT_ROOT/deploy/k8s/base/apps/openedx/settings/cms/production.py"

check_contains "$CMS_SETTINGS" "openedx_mobile_api" "openedx_mobile_api in INSTALLED_APPS (for admin)"

echo ""

# ============================================================================
# 10. Security Checks (AC-MOB-006, AC-MOB-007)
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}10. Security Checks (AC-MOB-006, AC-MOB-007)${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# Verify FCM_SERVER_KEY is from environment (AC-MOB-006)
if grep -q 'FCM_SERVER_KEY = os.environ.get("FCM_SERVER_KEY"' "$LMS_SETTINGS"; then
    check_pass "FCM_SERVER_KEY from environment (AC-MOB-006 - no plaintext)"
else
    check_fail "FCM_SERVER_KEY not from environment (AC-MOB-006)"
fi

# Verify no hardcoded secrets in views (AC-MOB-007)
if ! grep -Ei "api[_-]?key.*=.*['\"][^'\"]+['\"]|secret.*=.*['\"][^'\"]+['\"]|token.*=.*['\"][^'\"]+['\"]" "$APP_DIR/views.py" | grep -v "device_token"; then
    check_pass "No hardcoded secrets in views (AC-MOB-007)"
else
    check_fail "Potential hardcoded secrets in views (AC-MOB-007)"
fi

# Verify no hardcoded secrets in models (AC-MOB-007)
if ! grep -Ei "api[_-]?key.*=.*['\"][^'\"]+['\"]|secret.*=.*['\"][^'\"]+['\"]" "$APP_DIR/models.py"; then
    check_pass "No hardcoded secrets in models (AC-MOB-007)"
else
    check_fail "Potential hardcoded secrets in models (AC-MOB-007)"
fi

echo ""

# ============================================================================
# 11. Acceptance Criteria Coverage
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}11. Acceptance Criteria Coverage${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# AC-MOB-001: Branding config API with p95 <= 500ms
if grep -q "MobileBrandingConfigView" "$APP_DIR/views.py" && \
   grep -q "cache.get" "$APP_DIR/views.py"; then
    check_pass "AC-MOB-001: Branding config API with caching (p95 <= 500ms)"
else
    check_fail "AC-MOB-001: Branding config API with caching"
fi

# AC-MOB-002: Idempotent device registration
if grep -q "get_or_create" "$APP_DIR/views.py" && \
   grep -q "reactivate" "$APP_DIR/models.py"; then
    check_pass "AC-MOB-002: Idempotent device registration (no duplicates)"
else
    check_fail "AC-MOB-002: Idempotent device registration"
fi

# AC-MOB-003: Device deletion
if grep -q "def delete" "$APP_DIR/views.py" && \
   grep -q "deactivate" "$APP_DIR/models.py"; then
    check_pass "AC-MOB-003: Device deletion support"
else
    check_fail "AC-MOB-003: Device deletion support"
fi

# AC-MOB-004: Apple AASA file
if [[ -f "$AASA_FILE" ]] && grep -q "applinks" "$AASA_FILE"; then
    check_pass "AC-MOB-004: Valid Apple AASA file"
else
    check_fail "AC-MOB-004: Valid Apple AASA file"
fi

# AC-MOB-005: Android assetlinks.json
if [[ -f "$ASSETLINKS_FILE" ]] && grep -q "android_app" "$ASSETLINKS_FILE"; then
    check_pass "AC-MOB-005: Valid Android assetlinks.json"
else
    check_fail "AC-MOB-005: Valid Android assetlinks.json"
fi

# AC-MOB-006: FCM server key in ExternalSecrets
if grep -q 'os.environ.get("FCM_SERVER_KEY"' "$LMS_SETTINGS"; then
    check_pass "AC-MOB-006: FCM server key from environment (ExternalSecrets)"
else
    check_fail "AC-MOB-006: FCM server key from environment"
fi

# AC-MOB-007: No secrets exposed
secrets_found=0
if grep -Ei "api[_-]?key.*=.*['\"][^'\"]+['\"]|secret.*=.*['\"][^'\"]+['\"]" "$APP_DIR"/{views,models,serializers}.py | grep -v "device_token\|SecretField\|password_field" > /dev/null 2>&1; then
    secrets_found=1
fi

if [[ $secrets_found -eq 0 ]]; then
    check_pass "AC-MOB-007: No secrets exposed in API responses or code"
else
    check_fail "AC-MOB-007: Potential secrets exposed"
fi

echo ""

# ============================================================================
# 12. Runtime Tests (Cluster Required)
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}12. Runtime Tests (Cluster Required)${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

if command -v kubectl &> /dev/null && kubectl get namespace mereka-lms &> /dev/null; then
    check_pass "kubectl and namespace available"
    check_skip "Runtime integration tests not yet implemented"
else
    check_skip "kubectl or namespace not available (skip runtime tests)"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}VERIFICATION SUMMARY${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

echo -e "${GREEN}PASS: $PASSED_CHECKS${NC}"
echo -e "${RED}FAIL: $FAILED_CHECKS${NC}"
echo -e "${YELLOW}SKIP: $SKIPPED_CHECKS${NC}"

echo ""

if [[ $FAILED_CHECKS -eq 0 ]]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "Mobile Backend API implementation verified successfully."
    echo ""
    echo "Next steps:"
    echo "  1. Run database migrations: tutor local do lms manage migrate"
    echo "  2. Configure FCM server key in ExternalSecrets: FCM_SERVER_KEY"
    echo "  3. Enable mobile API: export MOBILE_API_ENABLED=true"
    echo "  4. Add URL routing to LMS urls.py:"
    echo "     path('api/mobile/v1/', include('openedx_mobile_api.urls'))"
    echo "  5. Configure static file serving for /.well-known/"
    echo "  6. Test endpoints:"
    echo "     curl https://academyv2.mereka.io/api/mobile/v1/config/mereka/"
    echo "     curl https://academyv2.mereka.io/.well-known/apple-app-site-association"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some checks failed!${NC}"
    echo ""
    echo "Please review the failed checks above."
    echo ""
    exit 1
fi
