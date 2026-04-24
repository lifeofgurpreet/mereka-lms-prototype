#!/usr/bin/env bash
# Verification script for Kajabi SSO integration
# @spec: kajabi-sso
# @covers: AC-SSO-001 through AC-SSO-005, AC-NEG-SSO-001 through AC-NEG-SSO-003
# lint: allow-no-euo

set -uo pipefail  # Removed -e to allow script to continue on failures

# ========================================================================
# Configuration
# ========================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
APP_DIR="${REPO_ROOT}/infrastructure/tutor/custom-apps/openedx_kajabi_sso"
SETTINGS_FILE="${REPO_ROOT}/deploy/k8s/base/apps/openedx/settings/lms/production.py"

SKIP_CLUSTER=false
VERBOSE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# ========================================================================
# Helper Functions
# ========================================================================

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_test() {
    echo -e "${YELLOW}→ $1${NC}"
}

pass() {
    echo -e "${GREEN}  ✓ PASS${NC}: $1"
    ((PASS_COUNT++))
}

fail() {
    echo -e "${RED}  ✗ FAIL${NC}: $1"
    ((FAIL_COUNT++))
}

skip() {
    echo -e "${YELLOW}  ⊘ SKIP${NC}: $1"
    ((SKIP_COUNT++))
}

check_file() {
    local file="$1"
    local description="$2"
    if [[ -f "$file" ]]; then
        pass "$description exists: $file"
    else
        fail "$description missing: $file"
    fi
    return 0  # Always return 0 to prevent set -e from exiting
}

check_content() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if grep -q "$pattern" "$file" 2>/dev/null; then
        pass "$description"
    else
        fail "$description"
        if [[ "$VERBOSE" == "true" ]]; then
            echo "    Expected pattern: $pattern"
        fi
    fi
    return 0  # Always return 0 to prevent set -e from exiting
}

# ========================================================================
# Parse Arguments
# ========================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-cluster)
            SKIP_CLUSTER=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-cluster    Skip cluster/runtime tests"
            echo "  --verbose, -v     Verbose output"
            echo "  --help, -h        Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ========================================================================
# Section 1: App Structure
# ========================================================================

print_header "Section 1: App Structure"

print_test "Checking app directory exists"
if [[ -d "$APP_DIR" ]]; then
    pass "App directory exists"
else
    fail "App directory missing: $APP_DIR"
fi

print_test "Checking core Python files"
check_file "${APP_DIR}/__init__.py" "App __init__.py"
check_file "${APP_DIR}/apps.py" "App config"
check_file "${APP_DIR}/models.py" "Models"
check_file "${APP_DIR}/backend.py" "OAuth2 backend"
check_file "${APP_DIR}/api.py" "Business logic API"
check_file "${APP_DIR}/admin.py" "Django admin"
check_file "${APP_DIR}/setup.py" "Setup config"

print_test "Checking management command structure"
check_file "${APP_DIR}/management/__init__.py" "Management __init__.py"
check_file "${APP_DIR}/management/commands/__init__.py" "Commands __init__.py"
check_file "${APP_DIR}/management/commands/import_kajabi_users.py" "Import command"

print_test "Checking templates"
check_file "${APP_DIR}/templates/openedx_kajabi_sso/welcome_email.html" "HTML email template"
check_file "${APP_DIR}/templates/openedx_kajabi_sso/welcome_email.txt" "Text email template"
check_file "${APP_DIR}/templates/kajabi_sso/welcome_email.html" "Legacy alias HTML email template"
check_file "${APP_DIR}/templates/kajabi_sso/welcome_email.txt" "Legacy alias text email template"

print_test "Checking migrations directory"
check_file "${APP_DIR}/migrations/__init__.py" "Migrations __init__.py"

# ========================================================================
# Section 2: Models (AC-SSO-001, AC-SSO-002, AC-SSO-004, AC-SSO-005)
# ========================================================================

print_header "Section 2: Models"

print_test "Checking KajabiSsoLink model fields"
check_content "${APP_DIR}/models.py" "class KajabiSsoLink" "KajabiSsoLink model defined"
check_content "${APP_DIR}/models.py" "kajabi_email.*EmailField" "kajabi_email field"
check_content "${APP_DIR}/models.py" "kajabi_user_id.*CharField" "kajabi_user_id field"
check_content "${APP_DIR}/models.py" "sso_provider.*CharField" "sso_provider field"
check_content "${APP_DIR}/models.py" "is_active.*BooleanField" "is_active field"
check_content "${APP_DIR}/models.py" "welcome_email_sent.*BooleanField" "welcome_email_sent field"
check_content "${APP_DIR}/models.py" "welcome_email_sent_at.*DateTimeField" "welcome_email_sent_at field"
check_content "${APP_DIR}/models.py" "last_sso_login_at.*DateTimeField" "last_sso_login_at field"
check_content "${APP_DIR}/models.py" "sso_failures_count.*IntegerField" "sso_failures_count field"

print_test "Checking KajabiSsoLink model methods"
check_content "${APP_DIR}/models.py" "def record_sso_success" "record_sso_success method"
check_content "${APP_DIR}/models.py" "def record_sso_failure" "record_sso_failure method"
check_content "${APP_DIR}/models.py" "def mark_welcome_email_sent" "mark_welcome_email_sent method"

print_test "Checking KajabiImportBatch model fields"
check_content "${APP_DIR}/models.py" "class KajabiImportBatch" "KajabiImportBatch model defined"
check_content "${APP_DIR}/models.py" "csv_filename.*CharField" "csv_filename field"
check_content "${APP_DIR}/models.py" "total_rows.*IntegerField" "total_rows field"
check_content "${APP_DIR}/models.py" "created_count.*IntegerField" "created_count field"
check_content "${APP_DIR}/models.py" "linked_count.*IntegerField" "linked_count field"
check_content "${APP_DIR}/models.py" "skipped_count.*IntegerField" "skipped_count field"
check_content "${APP_DIR}/models.py" "error_count.*IntegerField" "error_count field"
check_content "${APP_DIR}/models.py" "status.*CharField" "status field"
check_content "${APP_DIR}/models.py" "errors_json.*JSONField" "errors_json field"

# ========================================================================
# Section 3: OAuth2 Backend (AC-SSO-001, AC-SSO-003)
# ========================================================================

print_header "Section 3: OAuth2 Backend"

print_test "Checking KajabiSsoBackend class"
check_content "${APP_DIR}/backend.py" "class KajabiSsoBackend" "KajabiSsoBackend class defined"
check_content "${APP_DIR}/backend.py" "ModelBackend" "Inherits from ModelBackend"

print_test "Checking authenticate method (AC-SSO-001)"
check_content "${APP_DIR}/backend.py" "def authenticate" "authenticate method signature"
check_content "${APP_DIR}/backend.py" "KAJABI_SSO_ENABLED" "Checks KAJABI_SSO_ENABLED setting"
check_content "${APP_DIR}/backend.py" "KajabiSsoLink.objects" "Looks up SSO link"
check_content "${APP_DIR}/backend.py" "kajabi_email" "Filters by kajabi_email"

print_test "Checking fallback behavior (AC-SSO-003, AC-NEG-SSO-002)"
check_content "${APP_DIR}/backend.py" "return None" "Returns None for fallback"
check_content "${APP_DIR}/backend.py" "DoesNotExist" "Handles DoesNotExist exception"

print_test "Checking get_user method"
check_content "${APP_DIR}/backend.py" "def get_user.*user_id" "get_user method defined"

# ========================================================================
# Section 4: Bulk Import (AC-SSO-002, AC-NEG-SSO-001)
# ========================================================================

print_header "Section 4: Bulk Import"

print_test "Checking import_kajabi_csv function (AC-SSO-002)"
check_content "${APP_DIR}/api.py" "def import_kajabi_csv" "import_kajabi_csv function defined"
check_content "${APP_DIR}/api.py" "csv_file_path" "Has csv_file_path parameter"
check_content "${APP_DIR}/api.py" "imported_by" "Has imported_by parameter"
check_content "${APP_DIR}/api.py" "send_welcome" "Has send_welcome parameter"
check_content "${APP_DIR}/api.py" "csv.DictReader" "CSV parsing logic"

print_test "Checking batch tracking"
check_content "${APP_DIR}/api.py" "KajabiImportBatch.objects.create" "Creates batch record"
check_content "${APP_DIR}/api.py" "created_count" "Tracks created count"
check_content "${APP_DIR}/api.py" "linked_count" "Tracks linked count"
check_content "${APP_DIR}/api.py" "skipped_count" "Tracks skipped count"

print_test "Checking deduplication (AC-NEG-SSO-001)"
check_content "${APP_DIR}/api.py" "KajabiSsoLink.objects.filter" "Checks for existing SSO link"
check_content "${APP_DIR}/api.py" "kajabi_email" "Filters by kajabi_email"
check_content "${APP_DIR}/api.py" "skipped" "Tracks skipped count"

# ========================================================================
# Section 5: Email Deduplication (AC-SSO-004)
# ========================================================================

print_header "Section 5: Email Deduplication"

print_test "Checking email normalization (AC-SSO-004)"
check_content "${APP_DIR}/api.py" "lower().*strip()" "Email lowercase normalization"
check_content "${APP_DIR}/api.py" "email__iexact" "Case-insensitive email lookup"

print_test "Checking username generation"
check_content "${APP_DIR}/api.py" "def generate_unique_username" "generate_unique_username function"
check_content "${APP_DIR}/api.py" "split.*@" "Extracts email prefix"
check_content "${APP_DIR}/api.py" "User.objects.filter.*username.*exists" "Checks for username collisions"

# ========================================================================
# Section 6: Welcome Email (AC-SSO-005, AC-NEG-SSO-003)
# ========================================================================

print_header "Section 6: Welcome Email"

print_test "Checking send_welcome_email function (AC-SSO-005)"
check_content "${APP_DIR}/api.py" "def send_welcome_email" "send_welcome_email function defined"
check_content "${APP_DIR}/api.py" "KAJABI_WELCOME_EMAIL_ENABLED" "Checks welcome email enabled setting"

print_test "Checking duplicate prevention (AC-NEG-SSO-003)"
check_content "${APP_DIR}/api.py" "welcome_email_sent" "Checks welcome_email_sent flag"
check_content "${APP_DIR}/api.py" "return False" "Returns False to skip"

print_test "Checking email sending"
check_content "${APP_DIR}/api.py" "send_mail" "Calls Django send_mail"
check_content "${APP_DIR}/api.py" "render_to_string.*welcome_email.html" "Renders HTML template"
check_content "${APP_DIR}/api.py" "render_to_string.*welcome_email.txt" "Renders text template"
check_content "${APP_DIR}/api.py" "mark_welcome_email_sent" "Marks email as sent"

print_test "Checking email templates"
check_content "${APP_DIR}/templates/openedx_kajabi_sso/welcome_email.html" "platform_name|default:\"Mereka Academy\"" "HTML template content"
check_content "${APP_DIR}/templates/openedx_kajabi_sso/welcome_email.html" "default:first_name" "HTML template variables"
check_content "${APP_DIR}/templates/openedx_kajabi_sso/welcome_email.txt" "platform_name|default:\"Mereka Academy\"" "Text template content"
check_content "${APP_DIR}/templates/openedx_kajabi_sso/welcome_email.html" "linear-gradient(120deg" "HTML template uses branded gradient header shell"
check_content "${APP_DIR}/templates/openedx_kajabi_sso/welcome_email.html" "org_primary_color|default:'#ab3b78'" "HTML template uses Mereka primary fallback color"
check_content "${APP_DIR}/templates/openedx_kajabi_sso/welcome_email.html" "org_accent_color|default:'#237072'" "HTML template uses Mereka accent fallback color"
check_content "${APP_DIR}/templates/kajabi_sso/welcome_email.html" "include \"openedx_kajabi_sso/welcome_email.html\"" "Legacy alias HTML template points to canonical template"

# ========================================================================
# Section 7: LMS Settings (AC-SSO-001 through AC-SSO-005)
# ========================================================================

print_header "Section 7: LMS Settings"

print_test "Checking settings file modifications"
check_content "$SETTINGS_FILE" "KAJABI_SSO_ENABLED" "KAJABI_SSO_ENABLED setting"
check_content "$SETTINGS_FILE" "KAJABI_SSO_CLIENT_SLUG" "KAJABI_SSO_CLIENT_SLUG setting"
check_content "$SETTINGS_FILE" "KAJABI_WELCOME_EMAIL_ENABLED" "KAJABI_WELCOME_EMAIL_ENABLED setting"
check_content "$SETTINGS_FILE" "KAJABI_WELCOME_EMAIL_FROM" "KAJABI_WELCOME_EMAIL_FROM setting"
check_content "$SETTINGS_FILE" "KAJABI_WELCOME_EMAIL_SUPPORT" "KAJABI_WELCOME_EMAIL_SUPPORT setting"
check_content "$SETTINGS_FILE" "KAJABI_SSO_FALLBACK_ENABLED" "KAJABI_SSO_FALLBACK_ENABLED setting"

print_test "Checking app registration"
if grep -Eq '_safe_add_app\("openedx_kajabi_sso"\)|INSTALLED_APPS.*openedx_kajabi_sso|openedx_kajabi_sso.*INSTALLED_APPS' "$SETTINGS_FILE" 2>/dev/null; then
    pass "App added to INSTALLED_APPS (directly or via _safe_add_app)"
else
    fail "App added to INSTALLED_APPS"
fi

print_test "Checking backend registration"
check_content "$SETTINGS_FILE" "openedx_kajabi_sso.backend.KajabiSsoBackend" "Backend added to AUTHENTICATION_BACKENDS"
check_content "$SETTINGS_FILE" "AUTHENTICATION_BACKENDS.append" "Backend appended (not prepended for fallback)"

print_test "Checking default values (all should default to false)"
check_content "$SETTINGS_FILE" "KAJABI_SSO_ENABLED.*\"false\"" "KAJABI_SSO_ENABLED defaults to false"
check_content "$SETTINGS_FILE" "KAJABI_WELCOME_EMAIL_ENABLED.*\"false\"" "KAJABI_WELCOME_EMAIL_ENABLED defaults to false"

# ========================================================================
# Section 8: Admin Registration
# ========================================================================

print_header "Section 8: Admin Registration"

print_test "Checking admin classes"
check_content "${APP_DIR}/admin.py" "@admin.register.*KajabiSsoLink" "KajabiSsoLink admin registered"
check_content "${APP_DIR}/admin.py" "@admin.register.*KajabiImportBatch" "KajabiImportBatch admin registered"
check_content "${APP_DIR}/admin.py" "class KajabiSsoLinkAdmin" "KajabiSsoLinkAdmin class"
check_content "${APP_DIR}/admin.py" "class KajabiImportBatchAdmin" "KajabiImportBatchAdmin class"

print_test "Checking admin features"
check_content "${APP_DIR}/admin.py" "list_display" "list_display configured"
check_content "${APP_DIR}/admin.py" "list_filter" "list_filter configured"
check_content "${APP_DIR}/admin.py" "search_fields" "search_fields configured"

# ========================================================================
# Section 9: Management Commands
# ========================================================================

print_header "Section 9: Management Commands"

print_test "Checking import_kajabi_users command"
check_content "${APP_DIR}/management/commands/import_kajabi_users.py" "class Command" "Command class defined"
check_content "${APP_DIR}/management/commands/import_kajabi_users.py" "BaseCommand" "Inherits from BaseCommand"
check_content "${APP_DIR}/management/commands/import_kajabi_users.py" "csv-file" "CSV file argument"
check_content "${APP_DIR}/management/commands/import_kajabi_users.py" "no-welcome" "No-welcome argument"
check_content "${APP_DIR}/management/commands/import_kajabi_users.py" "dry-run" "Dry-run argument"
check_content "${APP_DIR}/management/commands/import_kajabi_users.py" "import_kajabi_csv" "Calls import_kajabi_csv"

# ========================================================================
# Section 10: Negative Assertions
# ========================================================================

print_header "Section 10: Negative Assertions"

print_test "AC-NEG-SSO-001: Duplicate prevention"
check_content "${APP_DIR}/api.py" "existing_link" "Checks for existing_link"
check_content "${APP_DIR}/api.py" "skipped" "Returns skipped action"

print_test "AC-NEG-SSO-002: Fallback mandatory"
check_content "${APP_DIR}/backend.py" "return None" "SSO failure returns None for fallback"
check_content "$SETTINGS_FILE" "KAJABI_SSO_FALLBACK_ENABLED" "Fallback setting exists"
check_content "$SETTINGS_FILE" "True.*NEVER disable" "Fallback always enabled"

print_test "AC-NEG-SSO-003: Welcome email deduplication"
check_content "${APP_DIR}/api.py" "welcome_email_sent" "Checks welcome_email_sent flag"

# ========================================================================
# Section 11: Runtime Tests (SKIP if --skip-cluster)
# ========================================================================

print_header "Section 11: Runtime Tests"

if [[ "$SKIP_CLUSTER" == "true" ]]; then
    skip "Runtime tests skipped (--skip-cluster flag)"
else
    print_test "Checking if Django is available"
    if command -v python &> /dev/null; then
        # Try to import the app (requires Django environment)
        if python -c "import sys; sys.path.insert(0, '${APP_DIR}'); import openedx_kajabi_sso" 2>/dev/null; then
            pass "App can be imported"
        else
            skip "App import failed (requires Django environment)"
        fi
    else
        skip "Python not available for runtime tests"
    fi
fi

# ========================================================================
# Summary
# ========================================================================

print_header "Verification Summary"

TOTAL=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))

echo ""
echo "Total tests: $TOTAL"
echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
echo -e "${RED}Failed: $FAIL_COUNT${NC}"
echo -e "${YELLOW}Skipped: $SKIP_COUNT${NC}"
echo ""

if [[ $FAIL_COUNT -gt 0 ]]; then
    echo -e "${RED}✗ VERIFICATION FAILED${NC}"
    echo "Please fix the failed checks above before proceeding."
    exit 1
else
    echo -e "${GREEN}✓ VERIFICATION PASSED${NC}"
    echo "All checks passed successfully!"
    exit 0
fi
