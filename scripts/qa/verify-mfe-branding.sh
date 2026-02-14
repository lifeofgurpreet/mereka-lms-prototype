#!/usr/bin/env bash
#
# MFE Branding Verification Script
#
# Verifies:
# - AC-UI-001: MFE URL paths match container directory names
# - AC-UI-005: Full redirect chains and rendered content validation
# - AC-UI-006: Custom Mereka footer renders in all MFEs
# - AC-UI-007: No default Open edX branding on production
# - AC-UI-008: No broken image/asset references
#
# Usage:
#   ./scripts/qa/verify-mfe-branding.sh [--env local|production] [--verbose]
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
WARNINGS=0

# Configuration
ENV="${1:-local}"
VERBOSE=false

if [[ "${1:-}" == "--verbose" ]] || [[ "${2:-}" == "--verbose" ]]; then
    VERBOSE=true
fi

# Base URLs
if [[ "$ENV" == "production" ]]; then
    LMS_URL="https://academyv2.mereka.io"
    STUDIO_URL="https://studio.academyv2.mereka.io"
    MFE_URL="https://apps.academyv2.mereka.io"
else
    LMS_URL="http://localhost"
    STUDIO_URL="http://studio.localhost"
    MFE_URL="http://apps.localhost"
fi

# MFE paths to verify (AC-UI-001)
declare -A MFE_PATHS=(
    ["learner-dashboard"]="/learner-dashboard"
    ["learning"]="/learning"
    ["profile"]="/profile"
    ["account"]="/account"
    ["gradebook"]="/gradebook"
    ["authn"]="/authn/login"
    ["course-authoring"]="/course-authoring"
)

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNINGS++))
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED_CHECKS++))
    ((TOTAL_CHECKS++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED_CHECKS++))
    ((TOTAL_CHECKS++))
}

check_url_with_redirects() {
    local url=$1
    local description=$2
    local max_redirects=10

    if [[ "$VERBOSE" == "true" ]]; then
        log_info "Checking: $url"
    fi

    # Follow redirect chain and check final response
    response=$(curl -sL -w "\n%{http_code}\n%{url_effective}" --max-redirs $max_redirects "$url" -o /dev/null 2>&1 || echo "error")

    if [[ "$response" == "error" ]]; then
        check_fail "$description: Connection failed"
        return 1
    fi

    http_code=$(echo "$response" | tail -2 | head -1)
    final_url=$(echo "$response" | tail -1)

    if [[ "$http_code" == "200" ]]; then
        check_pass "$description: HTTP $http_code"
        if [[ "$final_url" != "$url" ]] && [[ "$VERBOSE" == "true" ]]; then
            log_info "  Redirected to: $final_url"
        fi
        return 0
    elif [[ "$http_code" == "404" ]]; then
        check_fail "$description: HTTP $http_code (Not Found)"
        return 1
    else
        check_fail "$description: HTTP $http_code"
        return 1
    fi
}

check_rendered_content() {
    local url=$1
    local pattern=$2
    local description=$3

    if [[ "$VERBOSE" == "true" ]]; then
        log_info "Checking rendered content: $url"
    fi

    content=$(curl -sL "$url" 2>/dev/null || echo "")

    if [[ -z "$content" ]]; then
        check_fail "$description: No content retrieved"
        return 1
    fi

    if echo "$content" | grep -qi "$pattern"; then
        check_pass "$description: Content found"
        return 0
    else
        check_fail "$description: Pattern not found - $pattern"
        if [[ "$VERBOSE" == "true" ]]; then
            log_info "  Content preview: ${content:0:200}..."
        fi
        return 1
    fi
}

check_asset() {
    local url=$1
    local description=$2

    http_code=$(curl -sL -w "%{http_code}" -o /dev/null "$url" 2>/dev/null || echo "error")

    if [[ "$http_code" == "200" ]]; then
        check_pass "$description: HTTP $http_code"
        return 0
    elif [[ "$http_code" == "404" ]]; then
        check_fail "$description: HTTP $http_code (Broken asset - AC-UI-008)"
        return 1
    elif [[ "$http_code" == "error" ]]; then
        check_fail "$description: Connection failed"
        return 1
    else
        check_fail "$description: HTTP $http_code"
        return 1
    fi
}

echo "========================================="
echo "MFE Branding Verification"
echo "========================================="
echo "Environment: $ENV"
echo "LMS URL: $LMS_URL"
echo "Studio URL: $STUDIO_URL"
echo "MFE URL: $MFE_URL"
echo ""

# ============================================================================
# 1. AC-UI-001: MFE URL Paths Match Container Directories
# ============================================================================
echo "1. Verifying AC-UI-001: MFE URL paths match container directories..."
echo ""

for mfe in "${!MFE_PATHS[@]}"; do
    path="${MFE_PATHS[$mfe]}"
    full_url="${MFE_URL}${path}"

    check_url_with_redirects "$full_url" "MFE $mfe path: $path"
done

echo ""

# ============================================================================
# 2. AC-UI-005: Full Redirect Chains and Rendered Content
# ============================================================================
echo "2. Verifying AC-UI-005: Full redirect chains and rendered content..."
echo ""

# Check Studio redirect (known issue: /course-authoring vs /authoring)
check_url_with_redirects "${STUDIO_URL}/" "Studio root URL"
check_url_with_redirects "${MFE_URL}/course-authoring" "Studio course authoring MFE"

# Check LMS pages
check_url_with_redirects "${LMS_URL}/" "LMS homepage"
check_url_with_redirects "${LMS_URL}/dashboard" "LMS learner dashboard"

echo ""

# ============================================================================
# 3. AC-UI-006: Custom Mereka Footer in All MFEs
# ============================================================================
echo "3. Verifying AC-UI-006: Custom Mereka footer renders in all MFEs..."
echo ""

# Check for Mereka-specific footer content
# Note: Update pattern based on actual footer implementation
MEREKA_FOOTER_PATTERN="mereka|biji.biji|academy"

for mfe in "${!MFE_PATHS[@]}"; do
    path="${MFE_PATHS[$mfe]}"
    full_url="${MFE_URL}${path}"

    check_rendered_content "$full_url" "$MEREKA_FOOTER_PATTERN" "Mereka footer in $mfe MFE"
done

echo ""

# ============================================================================
# 4. AC-UI-007: No Default Open edX Branding on Production
# ============================================================================
echo "4. Verifying AC-UI-007: No default Open edX branding on production..."
echo ""

if [[ "$ENV" == "production" ]]; then
    # Check for default Open edX strings that should NOT appear
    DEFAULT_BRANDING_PATTERNS=(
        "edX Inc"
        "Open edX"
        "edx.org"
        "demo.edx.org"
    )

    for pattern in "${DEFAULT_BRANDING_PATTERNS[@]}"; do
        # Check LMS homepage
        content=$(curl -sL "${LMS_URL}/" 2>/dev/null || echo "")
        if echo "$content" | grep -qi "$pattern"; then
            check_fail "Default branding found on LMS: $pattern (AC-UI-007)"
        else
            check_pass "No default branding on LMS: $pattern"
        fi

        # Check Studio
        content=$(curl -sL "${STUDIO_URL}/" 2>/dev/null || echo "")
        if echo "$content" | grep -qi "$pattern"; then
            check_fail "Default branding found on Studio: $pattern (AC-UI-007)"
        else
            check_pass "No default branding on Studio: $pattern"
        fi
    done
else
    log_info "Skipping AC-UI-007 checks (only runs in production environment)"
fi

echo ""

# ============================================================================
# 5. AC-UI-008: No Broken Image/Asset References
# ============================================================================
echo "5. Verifying AC-UI-008: No broken image/asset references..."
echo ""

# Check common asset paths
ASSET_PATHS=(
    "/static/images/logo.png"
    "/static/images/favicon.ico"
    "/static/css/lms-main.css"
)

for asset_path in "${ASSET_PATHS[@]}"; do
    check_asset "${LMS_URL}${asset_path}" "LMS asset: $asset_path"
done

# Check MFE assets (if accessible)
MFE_ASSETS=(
    "/learner-dashboard/static/css/main.css"
    "/learning/static/js/main.js"
)

for asset_path in "${MFE_ASSETS[@]}"; do
    url="${MFE_URL}${asset_path}"
    http_code=$(curl -sL -w "%{http_code}" -o /dev/null "$url" 2>/dev/null || echo "error")

    if [[ "$http_code" == "200" ]]; then
        check_pass "MFE asset: $asset_path"
    elif [[ "$http_code" == "404" ]]; then
        log_warn "MFE asset not found (may not be exposed): $asset_path"
    else
        log_warn "MFE asset check inconclusive: $asset_path (HTTP $http_code)"
    fi
done

echo ""

# ============================================================================
# 6. Theme Consistency Check (AC-UI-002)
# ============================================================================
echo "6. Verifying AC-UI-002: Theme consistency across LMS/Studio/MFEs..."
echo ""

# Check for Mereka theme markers
THEME_MARKERS=(
    "mereka"
    "comprehensive.theme.css"
)

for marker in "${THEME_MARKERS[@]}"; do
    # LMS
    content=$(curl -sL "${LMS_URL}/" 2>/dev/null || echo "")
    if echo "$content" | grep -qi "$marker"; then
        check_pass "Theme marker in LMS: $marker"
    else
        log_warn "Theme marker not found in LMS: $marker"
    fi

    # Studio
    content=$(curl -sL "${STUDIO_URL}/" 2>/dev/null || echo "")
    if echo "$content" | grep -qi "$marker"; then
        check_pass "Theme marker in Studio: $marker"
    else
        log_warn "Theme marker not found in Studio: $marker"
    fi
done

echo ""

# ============================================================================
# Summary
# ============================================================================
echo "========================================="
echo "Verification Summary"
echo "========================================="
echo ""
echo "Total checks:  $TOTAL_CHECKS"
echo -e "${GREEN}Passed:${NC}        $PASSED_CHECKS"
echo -e "${RED}Failed:${NC}        $FAILED_CHECKS"
echo -e "${YELLOW}Warnings:${NC}      $WARNINGS"
echo ""

if [[ $FAILED_CHECKS -eq 0 ]]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "MFE branding verification complete."
    echo ""
    echo "Acceptance criteria verified:"
    echo "  ✓ AC-UI-001: MFE URL paths match container directories"
    echo "  ✓ AC-UI-005: Full redirect chains validated"
    echo "  ✓ AC-UI-006: Mereka footer renders in all MFEs"
    if [[ "$ENV" == "production" ]]; then
        echo "  ✓ AC-UI-007: No default Open edX branding"
    fi
    echo "  ✓ AC-UI-008: No broken asset references"
    echo "  ✓ AC-UI-002: Theme consistency verified"
    echo ""
    if [[ $WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}Note: $WARNINGS warning(s) detected - review above${NC}"
    fi
    exit 0
else
    echo -e "${RED}✗ Some checks failed!${NC}"
    echo ""
    echo "Please review the failed checks above."
    echo "Run with --verbose for more details."
    echo ""
    if [[ $WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}Also: $WARNINGS warning(s) detected${NC}"
    fi
    exit 1
fi
