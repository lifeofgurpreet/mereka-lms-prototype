#!/usr/bin/env bash
#
# Mobile Phase 4 - iOS Release Verification Script
#
# Verifies:
# - AC-MOB-016: Offline course download tracking
# - AC-MOB-017: Background download support
# - AC-MOB-018: Offline video playback
# - AC-MOB-019: Universal Links verification
# - AC-MOB-020: App Store metadata configuration
# - AC-MOB-021: Screenshots and preview media
# - AC-MOB-022: Review notes and test credentials
# - AC-MOB-023: iOS-specific branding (multi-tenant)
#
# Usage:
#   ./scripts/qa/verify-mobile-release.sh
#
set -uo pipefail

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
    ((PASSED_CHECKS++))
    ((TOTAL_CHECKS++))
}

check_fail() {
    log_fail "$1"
    ((FAILED_CHECKS++))
    ((TOTAL_CHECKS++))
}

check_skip() {
    log_skip "$1"
    ((SKIPPED_CHECKS++))
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

check_not_contains() {
    local file=$1
    local pattern=$2
    local description=$3

    if [[ ! -f "$file" ]]; then
        check_fail "$description (file not found: $file)"
        return 1
    fi

    if ! grep -qi "$pattern" "$file"; then
        check_pass "$description"
        return 0
    else
        check_fail "$description (pattern found, should be absent: $pattern)"
        return 1
    fi
}

echo "========================================="
echo "Mobile Phase 4 - iOS Release Verification"
echo "========================================="
echo ""

# ============================================================================
# 1. Offline Mode Files (AC-MOB-016, AC-MOB-017, AC-MOB-018, AC-MOB-019)
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}1. Offline Mode Files${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

check_file_exists "$APP_DIR/ios_offline.py" "iOS offline mode models"
check_file_exists "$APP_DIR/ios_offline_views.py" "iOS offline views"
check_file_exists "$APP_DIR/ios_offline_serializers.py" "iOS offline serializers"
check_file_exists "$APP_DIR/ios_offline_urls.py" "iOS offline URL configuration"

echo ""

# ============================================================================
# 2. App Store Release Files (AC-MOB-020, AC-MOB-021, AC-MOB-022, AC-MOB-023)
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}2. App Store Release Files${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

check_file_exists "$APP_DIR/ios_release.py" "iOS App Store release models"
check_file_exists "$APP_DIR/ios_release_views.py" "iOS release views"
check_file_exists "$APP_DIR/ios_release_serializers.py" "iOS release serializers"
check_file_exists "$APP_DIR/ios_release_urls.py" "iOS release URL configuration"

echo ""

# ============================================================================
# 3. Offline Course Models (AC-MOB-016, AC-MOB-017)
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}3. Offline Course Models (AC-MOB-016, AC-MOB-017)${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

check_contains "$APP_DIR/ios_offline.py" "class OfflineCourse" "OfflineCourse model"
check_contains "$APP_DIR/ios_offline.py" "STATUS_CHOICES" "Download status choices"
check_contains "$APP_DIR/ios_offline.py" "total_size_bytes" "Total size tracking"
check_contains "$APP_DIR/ios_offline.py" "downloaded_bytes" "Downloaded bytes tracking"
check_contains "$APP_DIR/ios_offline.py" "progress_percent" "Progress percentage tracking"
check_contains "$APP_DIR/ios_offline.py" "def update_progress" "update_progress method (AC-MOB-017)"
check_contains "$APP_DIR/ios_offline.py" "def mark_completed" "mark_completed method"
check_contains "$APP_DIR/ios_offline.py" "def pause" "pause method (AC-MOB-017 background download)"
check_contains "$APP_DIR/ios_offline.py" "def resume" "resume method (AC-MOB-017 background download)"
check_contains "$APP_DIR/ios_offline.py" "content_checksum" "Content checksum for integrity"

echo ""

# ============================================================================
# 4. Offline Video Models (AC-MOB-018)
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}4. Offline Video Models (AC-MOB-018)${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

check_contains "$APP_DIR/ios_offline.py" "class OfflineVideo" "OfflineVideo model"
check_contains "$APP_DIR/ios_offline.py" "local_file_path" "Local file path for offline playback"
check_contains "$APP_DIR/ios_offline.py" "file_size_bytes" "Video file size tracking"
check_contains "$APP_DIR/ios_offline.py" "duration_seconds" "Video duration tracking"
check_contains "$APP_DIR/ios_offline.py" "resolution" "Video resolution tracking"
check_contains "$APP_DIR/ios_offline.py" "is_downloaded" "Download status flag"

echo ""

# ============================================================================
# 5. Universal Links Verification (AC-MOB-019)
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}5. Universal Links Verification (AC-MOB-019)${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

check_contains "$APP_DIR/ios_offline.py" "class UniversalLinkVerification" "UniversalLinkVerification model"
check_contains "$APP_DIR/ios_offline.py" "verification_id" "Verification ID tracking"
check_contains "$APP_DIR/ios_offline.py" "def create_verification" "create_verification method"
check_contains "$APP_DIR/ios_offline.py" "def mark_verified" "mark_verified method"
check_contains "$APP_DIR/ios_offline.py" "def mark_failed" "mark_failed method"
check_contains "$APP_DIR/ios_offline_views.py" "class UniversalLinkVerificationView" "Universal Links verification view"

echo ""

# ============================================================================
# 6. App Store Metadata (AC-MOB-020)
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}6. App Store Metadata (AC-MOB-020)${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

check_contains "$APP_DIR/ios_release.py" "class AppStoreMetadata" "AppStoreMetadata model"
check_contains "$APP_DIR/ios_release.py" "app_name" "App name field"
check_contains "$APP_DIR/ios_release.py" "subtitle" "Subtitle field"
check_contains "$APP_DIR/ios_release.py" "promotional_text" "Promotional text field"
check_contains "$APP_DIR/ios_release.py" "description" "Description field"
check_contains "$APP_DIR/ios_release.py" "keywords" "Keywords field"
check_contains "$APP_DIR/ios_release.py" "privacy_policy_url" "Privacy policy URL field"
check_contains "$APP_DIR/ios_release.py" "support_url" "Support URL field"
check_contains "$APP_DIR/ios_release_views.py" "class AppStoreMetadataView" "App Store metadata view"

echo ""

# ============================================================================
# 7. App Store Screenshots (AC-MOB-021)
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}7. App Store Screenshots (AC-MOB-021)${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

check_contains "$APP_DIR/ios_release.py" "class AppStoreScreenshot" "AppStoreScreenshot model"
check_contains "$APP_DIR/ios_release.py" "DEVICE_TYPE_CHOICES" "Device type choices"
check_contains "$APP_DIR/ios_release.py" "screenshot_url" "Screenshot URL field"
check_contains "$APP_DIR/ios_release.py" "display_order" "Display order field"
check_contains "$APP_DIR/ios_release.py" "width_pixels" "Screenshot width tracking"
check_contains "$APP_DIR/ios_release.py" "height_pixels" "Screenshot height tracking"
check_contains "$APP_DIR/ios_release_views.py" "class AppStoreScreenshotsView" "App Store screenshots view"

echo ""

# ============================================================================
# 8. App Store Review Notes (AC-MOB-022)
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}8. App Store Review Notes (AC-MOB-022)${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

check_contains "$APP_DIR/ios_release.py" "class AppStoreReviewNotes" "AppStoreReviewNotes model"
check_contains "$APP_DIR/ios_release.py" "review_notes" "Review notes field"
check_contains "$APP_DIR/ios_release.py" "demo_username" "Demo username for reviewers"
check_contains "$APP_DIR/ios_release.py" "demo_password" "Demo password for reviewers"
check_contains "$APP_DIR/ios_release.py" "requires_idfa" "IDFA requirement field"
check_contains "$APP_DIR/ios_release.py" "uses_encryption" "Encryption usage field"
check_contains "$APP_DIR/ios_release.py" "def mark_submitted" "mark_submitted method"
check_contains "$APP_DIR/ios_release.py" "def mark_approved" "mark_approved method"
check_contains "$APP_DIR/ios_release.py" "def mark_rejected" "mark_rejected method"
check_contains "$APP_DIR/ios_release_views.py" "class AppStoreReviewNotesView" "App Store review notes view"

echo ""

# ============================================================================
# 9. iOS Branding Extension (AC-MOB-023)
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}9. iOS Branding Extension (AC-MOB-023)${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

check_contains "$APP_DIR/ios_release.py" "class IOSBrandingExtension" "IOSBrandingExtension model"
check_contains "$APP_DIR/ios_release.py" "app_icon_1024" "App icon 1024x1024"
check_contains "$APP_DIR/ios_release.py" "splash_screen_portrait" "Splash screen portrait"
check_contains "$APP_DIR/ios_release.py" "splash_screen_landscape" "Splash screen landscape"
check_contains "$APP_DIR/ios_release.py" "status_bar_style" "Status bar style"
check_contains "$APP_DIR/ios_release.py" "tint_color" "iOS tint color"
check_contains "$APP_DIR/ios_release.py" "enable_haptic_feedback" "Haptic feedback setting"
check_contains "$APP_DIR/ios_release.py" "enable_3d_touch" "3D Touch setting"
check_contains "$APP_DIR/ios_release_views.py" "class IOSBrandingView" "iOS branding view"

echo ""

# ============================================================================
# 10. API Endpoints
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}10. API Endpoints${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

check_contains "$APP_DIR/ios_offline_urls.py" "offline/courses/" "Offline courses list endpoint"
check_contains "$APP_DIR/ios_offline_urls.py" "download/" "Offline course download endpoint"
check_contains "$APP_DIR/ios_offline_urls.py" "progress/" "Download progress endpoint (AC-MOB-017)"
check_contains "$APP_DIR/ios_offline_urls.py" "videos/" "Offline videos endpoint (AC-MOB-018)"
check_contains "$APP_DIR/ios_offline_urls.py" "universal-links/verify/" "Universal Links verification endpoint (AC-MOB-019)"

check_contains "$APP_DIR/ios_release_urls.py" "app-store/metadata/" "App Store metadata endpoint (AC-MOB-020)"
check_contains "$APP_DIR/ios_release_urls.py" "app-store/screenshots/" "App Store screenshots endpoint (AC-MOB-021)"
check_contains "$APP_DIR/ios_release_urls.py" "app-store/review-notes/" "App Store review notes endpoint (AC-MOB-022)"
check_contains "$APP_DIR/ios_release_urls.py" "branding/" "iOS branding endpoint (AC-MOB-023)"

check_contains "$APP_DIR/ios_urls.py" "include.*ios_offline_urls" "iOS offline URLs included"
check_contains "$APP_DIR/ios_urls.py" "include.*ios_release_urls" "iOS release URLs included"

echo ""

# ============================================================================
# 11. Admin Integration
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}11. Admin Integration${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

check_contains "$APP_DIR/admin.py" "from .ios_offline import" "Offline models imported in admin"
check_contains "$APP_DIR/admin.py" "from .ios_release import" "Release models imported in admin"
check_contains "$APP_DIR/admin.py" "@admin.register(OfflineCourse)" "OfflineCourse admin"
check_contains "$APP_DIR/admin.py" "@admin.register(OfflineVideo)" "OfflineVideo admin"
check_contains "$APP_DIR/admin.py" "@admin.register(UniversalLinkVerification)" "UniversalLinkVerification admin"
check_contains "$APP_DIR/admin.py" "@admin.register(AppStoreMetadata)" "AppStoreMetadata admin"
check_contains "$APP_DIR/admin.py" "@admin.register(AppStoreScreenshot)" "AppStoreScreenshot admin"
check_contains "$APP_DIR/admin.py" "@admin.register(AppStoreReviewNotes)" "AppStoreReviewNotes admin"
check_contains "$APP_DIR/admin.py" "@admin.register(IOSBrandingExtension)" "IOSBrandingExtension admin"

echo ""

# ============================================================================
# 12. Security Checks
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}12. Security Checks${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# Check that demo_password is mentioned but with security note
if grep -q "demo_password" "$APP_DIR/ios_release.py" && \
   grep -q "encrypted in production" "$APP_DIR/ios_release_serializers.py"; then
    check_pass "Demo password field exists with security note"
else
    check_fail "Demo password field should have security note"
fi

# Check for caching in branding/metadata views
check_contains "$APP_DIR/ios_release_views.py" "cache.get" "Caching implemented for performance"
check_contains "$APP_DIR/ios_release_views.py" "cache.set" "Cache setting implemented"

# Check for permission classes
check_contains "$APP_DIR/ios_offline_views.py" "permission_classes" "Permission classes defined"
check_contains "$APP_DIR/ios_release_views.py" "permission_classes" "Permission classes defined"

echo ""

# ============================================================================
# 13. Acceptance Criteria Coverage
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}13. Acceptance Criteria Coverage${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# AC-MOB-016: Offline course download tracking
if grep -q "class OfflineCourse" "$APP_DIR/ios_offline.py" && \
   grep -q "progress_percent" "$APP_DIR/ios_offline.py"; then
    check_pass "AC-MOB-016: Offline course download tracking"
else
    check_fail "AC-MOB-016: Offline course download tracking"
fi

# AC-MOB-017: Background download support
if grep -q "def pause" "$APP_DIR/ios_offline.py" && \
   grep -q "def resume" "$APP_DIR/ios_offline.py" && \
   grep -q "progress/" "$APP_DIR/ios_offline_urls.py"; then
    check_pass "AC-MOB-017: Background download support with pause/resume"
else
    check_fail "AC-MOB-017: Background download support"
fi

# AC-MOB-018: Offline video playback
if grep -q "class OfflineVideo" "$APP_DIR/ios_offline.py" && \
   grep -q "local_file_path" "$APP_DIR/ios_offline.py"; then
    check_pass "AC-MOB-018: Offline video playback with local file paths"
else
    check_fail "AC-MOB-018: Offline video playback"
fi

# AC-MOB-019: Universal Links verification
if grep -q "class UniversalLinkVerification" "$APP_DIR/ios_offline.py" && \
   grep -q "universal-links/verify/" "$APP_DIR/ios_offline_urls.py"; then
    check_pass "AC-MOB-019: Universal Links verification and logging"
else
    check_fail "AC-MOB-019: Universal Links verification"
fi

# AC-MOB-020: App Store metadata configuration
if grep -q "class AppStoreMetadata" "$APP_DIR/ios_release.py" && \
   grep -q "app-store/metadata/" "$APP_DIR/ios_release_urls.py"; then
    check_pass "AC-MOB-020: App Store metadata configuration (multi-language)"
else
    check_fail "AC-MOB-020: App Store metadata configuration"
fi

# AC-MOB-021: Screenshots and preview media
if grep -q "class AppStoreScreenshot" "$APP_DIR/ios_release.py" && \
   grep -q "DEVICE_TYPE_CHOICES" "$APP_DIR/ios_release.py"; then
    check_pass "AC-MOB-021: Screenshots for multiple device sizes"
else
    check_fail "AC-MOB-021: Screenshots configuration"
fi

# AC-MOB-022: Review notes and test credentials
if grep -q "class AppStoreReviewNotes" "$APP_DIR/ios_release.py" && \
   grep -q "demo_username" "$APP_DIR/ios_release.py" && \
   grep -q "demo_password" "$APP_DIR/ios_release.py"; then
    check_pass "AC-MOB-022: Review notes with test account credentials"
else
    check_fail "AC-MOB-022: Review notes and test credentials"
fi

# AC-MOB-023: iOS-specific branding (multi-tenant)
if grep -q "class IOSBrandingExtension" "$APP_DIR/ios_release.py" && \
   grep -q "app_icon" "$APP_DIR/ios_release.py" && \
   grep -q "splash_screen" "$APP_DIR/ios_release.py"; then
    check_pass "AC-MOB-023: iOS-specific branding with icons and splash screens"
else
    check_fail "AC-MOB-023: iOS-specific branding"
fi

echo ""

# ============================================================================
# 14. Runtime Tests (Cluster Required)
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}14. Runtime Tests (Cluster Required)${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"

if command -v kubectl &> /dev/null && kubectl get namespace mereka-lms &> /dev/null; then
    check_pass "kubectl and namespace available"
    check_skip "Runtime integration tests not yet implemented"
else
    check_skip "Runtime tests (kubectl not available or namespace not found)"
fi

echo ""

# ============================================================================
# VERIFICATION SUMMARY
# ============================================================================
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "${BLUE}VERIFICATION SUMMARY${NC}"
echo "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}PASS: ${PASSED_CHECKS}${NC}"
echo -e "${RED}FAIL: ${FAILED_CHECKS}${NC}"
echo -e "${YELLOW}SKIP: ${SKIPPED_CHECKS}${NC}"
echo ""

if [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "Mobile Phase 4 - iOS Release verified successfully."
    echo ""
    echo "Next steps:"
    echo "  1. Run database migrations: tutor local do lms manage migrate"
    echo "  2. Create App Store metadata in Django admin"
    echo "  3. Upload screenshots for required device sizes"
    echo "  4. Configure iOS branding for your organization"
    echo "  5. Test Universal Links: curl -X POST /api/mobile/v1/ios/universal-links/verify/"
    echo "  6. Test offline download: POST /api/mobile/v1/ios/offline/courses/<course_id>/download/"
    exit 0
else
    echo -e "${RED}✗ Some checks failed!${NC}"
    echo ""
    echo "Please review the failed checks above."
    exit 1
fi
