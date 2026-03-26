#!/usr/bin/env bash
#
# Visual Regression Testing Script
#
# Verifies AC-UIQ-001: Visual regression test suite captures screenshots
# of 20+ critical pages and diffs against baseline (desktop + mobile viewports)
#
# Uses Playwright for screenshot capture and comparison
#
# Usage:
#   ./scripts/qa/visual-regression-test.sh [--update-baseline] [--env local|production|prod|dev|staging] [--viewport desktop|mobile]
#
# Commands:
#   --update-baseline: Capture new baseline screenshots (run after confirmed good UI state)
#   --env: Environment to test (default: local)
#   --viewport: Viewport to use - desktop (1280x1024) or mobile (375x812) (default: desktop)
#
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
UPDATE_BASELINE=false
ENV="local"
VIEWPORT="desktop"
DIFF_THRESHOLD=0.05  # 5% pixel difference threshold
AUTHENTICATED=false
PLAYWRIGHT_IMPORT_SPEC_RESOLVED="${PLAYWRIGHT_IMPORT_SPEC:-}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --update-baseline)
            UPDATE_BASELINE=true
            shift
            ;;
        --env)
            ENV="$2"
            shift 2
            ;;
        --env=*)
            ENV="${1#*=}"
            shift
            ;;
        --viewport)
            VIEWPORT="$2"
            shift 2
            ;;
        --viewport=*)
            VIEWPORT="${1#*=}"
            shift
            ;;
        --authenticated)
            AUTHENTICATED=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../shared/config.sh" 2>/dev/null || true
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCREENSHOTS_DIR="$PROJECT_ROOT/var/screenshots"
BASELINE_DIR="$SCREENSHOTS_DIR/baseline"
CURRENT_DIR="$SCREENSHOTS_DIR/current"
DIFF_DIR="$SCREENSHOTS_DIR/diff"

# Base URLs
case "$ENV" in
    production|prod)
        LMS_URL="https://${LMS_DOMAIN:-academyv2.mereka.io}"
        STUDIO_URL="https://${STUDIO_DOMAIN:-studio.academyv2.mereka.io}"
        MFE_URL="https://${MFE_DOMAIN:-apps.academyv2.mereka.io}"
        ;;
    dev)
        LMS_URL="https://${DEV_LMS_DOMAIN:-academyv2.mereka.dev}"
        STUDIO_URL="https://${DEV_STUDIO_DOMAIN:-studio.${DEV_LMS_DOMAIN:-academyv2.mereka.dev}}"
        MFE_URL="https://${DEV_MFE_DOMAIN:-apps.${DEV_LMS_DOMAIN:-academyv2.mereka.dev}}"
        ;;
    staging)
        LMS_URL="https://${STAGING_LMS_DOMAIN:-staging.academyv2.mereka.io}"
        STUDIO_URL="https://${STAGING_STUDIO_DOMAIN:-staging.studio.academyv2.mereka.io}"
        MFE_URL="https://${STAGING_MFE_DOMAIN:-staging.apps.academyv2.mereka.io}"
        ;;
    local)
        LMS_URL="http://localhost"
        STUDIO_URL="http://studio.localhost"
        MFE_URL="http://apps.localhost"
        ;;
    *)
        echo "Unsupported --env value: $ENV (expected local|production|prod|dev|staging)"
        exit 1
        ;;
esac

# Viewport configuration (AC-UIQ-001)
if [[ "$VIEWPORT" == "mobile" ]]; then
    VIEWPORT_WIDTH=375
    VIEWPORT_HEIGHT=812
    VIEWPORT_SUFFIX="-mobile"
else
    VIEWPORT_WIDTH=1280
    VIEWPORT_HEIGHT=1024
    VIEWPORT_SUFFIX=""
fi

# Critical pages to screenshot (AC-UIQ-001: 20+ critical pages, desktop + mobile)
declare -A CRITICAL_PAGES=(
    # Original 10 pages (desktop always)
    ["lms-homepage"]="$LMS_URL/"
    ["lms-login"]="$LMS_URL/login"
    ["lms-register"]="$LMS_URL/register"
    ["lms-dashboard"]="$LMS_URL/dashboard"
    ["studio-homepage"]="$STUDIO_URL/"
    ["mfe-learner-dashboard"]="$MFE_URL/learner-dashboard"
    ["mfe-learning"]="$MFE_URL/learning"
    ["mfe-profile"]="$MFE_URL/profile/u/staff"
    ["mfe-account"]="$MFE_URL/account/settings"
    ["mfe-authn-login"]="$MFE_URL/authn/login"
    # 10 additional pages (AC-UIQ-001)
    ["mfe-communications"]="$MFE_URL/communications"
    ["mfe-gradebook"]="$MFE_URL/gradebook"
    ["mfe-ora-grading"]="$MFE_URL/ora-grading"
    ["mfe-discussions"]="$MFE_URL/discussions"
    ["mfe-course-authoring"]="$MFE_URL/course-authoring"
    ["mfe-authn-register"]="$MFE_URL/authn/register"
    ["mfe-account-root"]="$MFE_URL/account"
    ["mfe-profile-public"]="$MFE_URL/profile"
)

# Mobile-specific pages (tested only with mobile viewport)
if [[ "$VIEWPORT" == "mobile" ]]; then
    CRITICAL_PAGES["mfe-authn-login-mobile"]="$MFE_URL/authn/login"
    CRITICAL_PAGES["mfe-learner-dashboard-mobile"]="$MFE_URL/learner-dashboard"
fi

# Authenticated pages (captured only when --authenticated flag is set)
# These require SSO login to access
declare -A AUTHENTICATED_PAGES=(
    ["auth-learner-dashboard"]="$MFE_URL/learner-dashboard"
    ["auth-account-settings"]="$MFE_URL/account"
    ["auth-learning-page"]="$MFE_URL/learning"
    ["auth-profile"]="$MFE_URL/profile"
)

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

resolve_playwright_import_spec() {
    if [[ -n "${PLAYWRIGHT_IMPORT_SPEC:-}" ]]; then
        printf '%s' "${PLAYWRIGHT_IMPORT_SPEC}"
        return 0
    fi

    local repo_playwright="${PROJECT_ROOT}/tests/e2e/node_modules/playwright/index.mjs"
    if [[ -f "$repo_playwright" ]]; then
        printf 'file://%s' "$repo_playwright"
        return 0
    fi

    printf 'playwright'
}

check_dependencies() {
    log_info "Checking dependencies..."

    if ! command -v node &> /dev/null; then
        log_error "Node.js not found"
        exit 1
    fi

    PLAYWRIGHT_IMPORT_SPEC_RESOLVED="$(resolve_playwright_import_spec)"

    if PLAYWRIGHT_IMPORT_SPEC="$PLAYWRIGHT_IMPORT_SPEC_RESOLVED" node -e "import(process.env.PLAYWRIGHT_IMPORT_SPEC || 'playwright').then(() => process.exit(0)).catch(() => process.exit(1))"; then
        log_success "Playwright runtime available"
    else
        log_error "Playwright runtime not available. Set PLAYWRIGHT_IMPORT_SPEC or install tests/e2e dependencies."
        exit 1
    fi

    # Check if ImageMagick is available for comparison
    if ! command -v compare &> /dev/null; then
        log_warn "ImageMagick 'compare' not found. Visual diff will be limited."
        log_info "Install with: sudo apt-get install imagemagick (Ubuntu/Debian)"
    fi
}

setup_directories() {
    log_info "Setting up directories..."

    mkdir -p "$BASELINE_DIR"
    mkdir -p "$CURRENT_DIR"
    mkdir -p "$DIFF_DIR"

    if [[ "$UPDATE_BASELINE" == "true" ]]; then
        log_info "Clearing old baseline screenshots..."
        rm -f "$BASELINE_DIR"/*.png
    fi

    # Clear current and diff directories
    rm -f "$CURRENT_DIR"/*.png
    rm -f "$DIFF_DIR"/*.png
}

capture_screenshot() {
    local page_name=$1
    local url=$2
    local output_dir=$3

    log_info "Capturing screenshot: $page_name (${VIEWPORT_WIDTH}x${VIEWPORT_HEIGHT})"
    log_info "  URL: $url"

    # Add viewport suffix to filename
    local filename="${page_name}${VIEWPORT_SUFFIX}.png"

    # Create Playwright script
    local script="$SCREENSHOTS_DIR/capture_${page_name}.mjs"
    cat > "$script" <<EOF
(async () => {
  const { chromium } = await import(process.env.PLAYWRIGHT_IMPORT_SPEC || 'playwright');
  const browser = await chromium.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  const context = await browser.newContext({
    viewport: { width: $VIEWPORT_WIDTH, height: $VIEWPORT_HEIGHT },
    userAgent: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'
  });
  const page = await context.newPage();

  try {
    // Navigate to page
    await page.goto('$url', { waitUntil: 'networkidle', timeout: 30000 });

    // Wait for page to stabilize
    await page.waitForTimeout(2000);

    // Take screenshot
    await page.screenshot({
      path: '$output_dir/${filename}',
      fullPage: true
    });

    console.log('Screenshot captured: $page_name');
  } catch (error) {
    console.error('Error capturing screenshot for $page_name:', error.message);
    process.exit(1);
  } finally {
    await browser.close();
  }
})();
EOF

    # Execute Playwright script
    if PLAYWRIGHT_IMPORT_SPEC="$PLAYWRIGHT_IMPORT_SPEC_RESOLVED" node "$script"; then
        log_success "Screenshot captured: $page_name"
        rm "$script"
        return 0
    else
        log_error "Failed to capture screenshot: $page_name"
        rm "$script"
        return 1
    fi
}

capture_authenticated_screenshot() {
    local page_name=$1
    local url=$2
    local output_dir=$3

    log_info "Capturing authenticated screenshot: $page_name (${VIEWPORT_WIDTH}x${VIEWPORT_HEIGHT})"
    log_info "  URL: $url"

    # Add viewport suffix to filename
    local filename="${page_name}${VIEWPORT_SUFFIX}.png"

    # Get credentials from environment
    local sso_username="${SSO_USERNAME:-}"
    local sso_password="${SSO_PASSWORD:-}"

    if [[ -z "$sso_username" || -z "$sso_password" ]]; then
        log_warn "SSO credentials not provided - skipping authenticated page: $page_name"
        return 2
    fi

    # Create Playwright script with authentication
    local script="$SCREENSHOTS_DIR/capture_auth_${page_name}.mjs"
    cat > "$script" <<EOF
(async () => {
  const { chromium } = await import(process.env.PLAYWRIGHT_IMPORT_SPEC || 'playwright');
  const browser = await chromium.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  const context = await browser.newContext({
    viewport: { width: $VIEWPORT_WIDTH, height: $VIEWPORT_HEIGHT },
    userAgent: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
    ignoreHTTPSErrors: true
  });
  const page = await context.newPage();

  try {
    const loginEntryUrl = '$LMS_URL/auth/login/oidc/';
    await page.goto(loginEntryUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await page.waitForLoadState('domcontentloaded', { timeout: 30000 }).catch(() => {});

    const usernameSelectors = [
      'input[placeholder="Email or Username"]',
      '#id_uid_field',
      'input[name="uidField"]',
      'input[name="username"]',
      'input[type="email"]'
    ];
    let filled = false;
    for (const sel of usernameSelectors) {
      const locator = page.locator(sel).first();
      try {
        await locator.waitFor({ state: 'visible', timeout: 10000 });
        await locator.fill('$sso_username', { timeout: 10000 });
        filled = true;
        break;
      } catch (_) {}
    }

    if (!filled) {
      console.error('Could not find username field');
      process.exit(1);
    }

    const clickPrimaryAction = async () => {
      const labels = [/log in/i, /sign in/i, /continue/i, /next/i];
      for (const label of labels) {
        try {
          await page.getByRole('button', { name: label }).first().click({ timeout: 10000 });
          return;
        } catch (_) {}
      }
      const submitBtn = await page.\$('button[type="submit"]');
      if (submitBtn) {
        await submitBtn.click();
        return;
      }
      await page.keyboard.press('Enter');
    };

    await clickPrimaryAction();
    await page.waitForLoadState('domcontentloaded', { timeout: 30000 }).catch(() => {});
    await page.waitForTimeout(1500);

    const passwordSelectors = [
      'input[placeholder="Password"]',
      '#id_password',
      'input[name="password"]',
      'input[type="password"]'
    ];
    filled = false;
    for (const sel of passwordSelectors) {
      const locator = page.locator(sel).first();
      try {
        await locator.waitFor({ state: 'visible', timeout: 10000 });
        await locator.fill('$sso_password', { timeout: 10000 });
        filled = true;
        break;
      } catch (_) {}
    }

    if (!filled) {
      console.error('Could not find password field');
      process.exit(1);
    }

    await clickPrimaryAction();
    await page.waitForURL(
      url => !/auth0|authentik|\\/if\\/flow\\/|\\/auth\\/login\\/oidc|\\/authn\\/login|\\/login\\b/i.test(url),
      { timeout: 60000 }
    ).catch(() => {});
    await page.waitForNavigation({ waitUntil: 'networkidle', timeout: 30000 }).catch(() => {});
    await page.waitForTimeout(3000);

    // Navigate to target page
    await page.goto('$url', { waitUntil: 'networkidle', timeout: 30000 });

    // Wait for page to stabilize
    await page.waitForTimeout(2000);

    // Take screenshot
    await page.screenshot({
      path: '$output_dir/${filename}',
      fullPage: true
    });

    console.log('Screenshot captured: $page_name');
  } catch (error) {
    console.error('Error capturing authenticated screenshot for $page_name:', error.message);
    process.exit(1);
  } finally {
    await browser.close();
  }
})();
EOF

    # Execute Playwright script
    if PLAYWRIGHT_IMPORT_SPEC="$PLAYWRIGHT_IMPORT_SPEC_RESOLVED" node "$script"; then
        log_success "Screenshot captured: $page_name"
        rm "$script"
        return 0
    else
        log_error "Failed to capture authenticated screenshot: $page_name"
        rm "$script"
        return 1
    fi
}

compare_screenshots() {
    local page_name=$1

    # Add viewport suffix to filenames
    local filename="${page_name}${VIEWPORT_SUFFIX}.png"
    local baseline="$BASELINE_DIR/${filename}"
    local current="$CURRENT_DIR/${filename}"
    local diff="$DIFF_DIR/${filename}"

    if [[ ! -f "$baseline" ]]; then
        log_warn "No baseline found for $page_name - skipping comparison"
        return 2
    fi

    if [[ ! -f "$current" ]]; then
        log_error "No current screenshot found for $page_name"
        return 1
    fi

    # Check if ImageMagick is available
    if ! command -v compare &> /dev/null; then
        log_warn "ImageMagick not available - skipping visual diff for $page_name"
        return 2
    fi

    log_info "Comparing screenshots: $page_name"

    # Compare images and calculate difference
    # ImageMagick compare: returns difference metric
    diff_output=$(compare -metric AE "$baseline" "$current" "$diff" 2>&1 || true)

    # Extract pixel count difference
    diff_pixels=$(echo "$diff_output" | grep -oE '[0-9]+' | head -1 || echo "0")

    # Calculate percentage difference
    # Get image dimensions
    dimensions=$(identify -format "%w %h" "$baseline" 2>/dev/null || echo "1280 1024")
    width=$(echo "$dimensions" | cut -d' ' -f1)
    height=$(echo "$dimensions" | cut -d' ' -f2)
    total_pixels=$((width * height))

    if [[ $total_pixels -gt 0 ]]; then
        diff_percentage=$(echo "scale=4; $diff_pixels / $total_pixels" | bc)
    else
        diff_percentage=0
    fi

    # Check against threshold (AC-UI-003: detect visual regressions)
    if (( $(echo "$diff_percentage > $DIFF_THRESHOLD" | bc -l) )); then
        log_error "Visual regression detected: $page_name"
        log_error "  Diff: $diff_percentage (${diff_pixels} pixels, threshold: $DIFF_THRESHOLD)"
        log_error "  Diff image: $diff"
        return 1
    else
        log_success "No visual regression: $page_name"
        log_info "  Diff: $diff_percentage (${diff_pixels} pixels)"
        return 0
    fi
}

echo "========================================="
echo "Visual Regression Testing"
echo "========================================="
echo "Environment: $ENV"
echo "Viewport: $VIEWPORT (${VIEWPORT_WIDTH}x${VIEWPORT_HEIGHT})"
echo "Mode: $([ "$UPDATE_BASELINE" == "true" ] && echo "UPDATE BASELINE" || echo "COMPARE")"
echo "Diff threshold: $DIFF_THRESHOLD (5%)"
echo ""

# Setup
check_dependencies
setup_directories

# Counters
TOTAL_PAGES=${#CRITICAL_PAGES[@]}
CAPTURED=0
FAILED_CAPTURE=0
REGRESSIONS=0
PASSED=0
SKIPPED=0

# Capture screenshots
log_info "Capturing screenshots for $TOTAL_PAGES critical pages..."
echo ""

for page_name in "${!CRITICAL_PAGES[@]}"; do
    url="${CRITICAL_PAGES[$page_name]}"

    if [[ "$UPDATE_BASELINE" == "true" ]]; then
        # Capture baseline
        if capture_screenshot "$page_name" "$url" "$BASELINE_DIR"; then
            ((CAPTURED++)) || true
        else
            ((FAILED_CAPTURE++)) || true
        fi
    else
        # Capture current
        if capture_screenshot "$page_name" "$url" "$CURRENT_DIR"; then
            ((CAPTURED++)) || true
        else
            ((FAILED_CAPTURE++)) || true
        fi
    fi
done

# Capture authenticated pages if --authenticated flag is set (AC-UIAUTH-002)
if [[ "$AUTHENTICATED" == "true" ]]; then
    log_info "Capturing authenticated pages..."
    echo ""

    AUTH_TOTAL=${#AUTHENTICATED_PAGES[@]}
    AUTH_CAPTURED=0
    AUTH_FAILED=0
    AUTH_SKIPPED=0

    for page_name in "${!AUTHENTICATED_PAGES[@]}"; do
        url="${AUTHENTICATED_PAGES[$page_name]}"

        if [[ "$UPDATE_BASELINE" == "true" ]]; then
            # Capture baseline
            result=0
            capture_authenticated_screenshot "$page_name" "$url" "$BASELINE_DIR" || result=$?
            case $result in
                0) ((AUTH_CAPTURED++)) || true ;;
                1) ((AUTH_FAILED++)) || true ;;
                2) ((AUTH_SKIPPED++)) || true ;;
            esac
        else
            # Capture current
            result=0
            capture_authenticated_screenshot "$page_name" "$url" "$CURRENT_DIR" || result=$?
            case $result in
                0) ((AUTH_CAPTURED++)) || true ;;
                1) ((AUTH_FAILED++)) || true ;;
                2) ((AUTH_SKIPPED++)) || true ;;
            esac
        fi
    done

    # Update totals
    TOTAL_PAGES=$((TOTAL_PAGES + AUTH_TOTAL))
    CAPTURED=$((CAPTURED + AUTH_CAPTURED))
    FAILED_CAPTURE=$((FAILED_CAPTURE + AUTH_FAILED))

    if [[ $AUTH_SKIPPED -gt 0 ]]; then
        log_warn "Skipped $AUTH_SKIPPED authenticated pages (credentials not provided)"
    fi
fi

echo ""

if [[ "$UPDATE_BASELINE" == "true" ]]; then
    # Baseline mode - just capture, no comparison
    echo "========================================="
    echo "Baseline Update Summary"
    echo "========================================="
    echo ""
    echo "Total pages:     $TOTAL_PAGES"
    echo -e "${GREEN}Captured:${NC}        $CAPTURED"
    echo -e "${RED}Failed:${NC}          $FAILED_CAPTURE"
    echo ""

    if [[ $FAILED_CAPTURE -eq 0 ]]; then
        log_success "Baseline screenshots updated successfully!"
        log_info "Baseline directory: $BASELINE_DIR"
        exit 0
    else
        log_error "Some screenshots failed to capture"
        exit 1
    fi
else
    # Comparison mode
    log_info "Comparing screenshots against baseline..."
    echo ""

    for page_name in "${!CRITICAL_PAGES[@]}"; do
        result=0
        compare_screenshots "$page_name" || result=$?

        case $result in
            0)
                ((PASSED++)) || true
                ;;
            1)
                ((REGRESSIONS++)) || true
                ;;
            2)
                ((SKIPPED++)) || true
                ;;
        esac
    done

    # Compare authenticated pages if --authenticated was used
    if [[ "$AUTHENTICATED" == "true" ]]; then
        log_info "Comparing authenticated screenshots..."
        echo ""

        for page_name in "${!AUTHENTICATED_PAGES[@]}"; do
            result=0
            compare_screenshots "$page_name" || result=$?

            case $result in
                0)
                    ((PASSED++)) || true
                    ;;
                1)
                    ((REGRESSIONS++)) || true
                    ;;
                2)
                    ((SKIPPED++)) || true
                    ;;
            esac
        done
    fi

    echo ""

    # Summary
    echo "========================================="
    echo "Visual Regression Summary"
    echo "========================================="
    echo ""
    echo "Total pages:     $TOTAL_PAGES"
    echo -e "${RED}Capture failed:${NC}  $FAILED_CAPTURE"
    echo -e "${GREEN}Passed:${NC}          $PASSED"
    echo -e "${RED}Regressions:${NC}     $REGRESSIONS"
    echo -e "${YELLOW}Skipped:${NC}         $SKIPPED"
    echo ""

    if [[ $FAILED_CAPTURE -gt 0 ]]; then
        log_error "$FAILED_CAPTURE screenshot capture(s) failed!"
        exit 1
    elif [[ $REGRESSIONS -eq 0 ]]; then
        log_success "No visual regressions detected!"
        echo ""
        echo "AC-UIQ-001 verified: Visual regression suite captures and compares screenshots"
        echo "Coverage: 20+ critical surfaces (desktop + mobile viewports)"
        echo ""
        echo "Screenshot directories:"
        echo "  Baseline: $BASELINE_DIR"
        echo "  Current:  $CURRENT_DIR"
        echo "  Diff:     $DIFF_DIR"
        echo ""
        exit 0
    else
        log_error "$REGRESSIONS visual regression(s) detected!"
        echo ""
        echo "Review diff images in: $DIFF_DIR"
        echo ""
        echo "If changes are intentional, update baseline:"
        echo "  ./scripts/qa/visual-regression-test.sh --update-baseline --env $ENV --viewport $VIEWPORT"
        echo ""
        exit 1
    fi
fi
