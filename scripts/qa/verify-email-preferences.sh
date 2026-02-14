#!/usr/bin/env bash
# @spec: email-notifications-pipeline_spec.md
# @covers AC-020, AC-021, AC-022, AC-023, AC-024, AC-043
#
# Verify Email Preferences Service (Phase 2)
#
# AC-020: Default preferences API (GET returns defaults, all enabled except bulk_campaign email)
# AC-021: User preference update (PUT preferences, per-channel toggles)
# AC-022: One-click unsubscribe (HMAC token, disables bulk_campaign + course_announcement)
# AC-023: Audit log for preference changes (user_id, old/new value, consent, IP hash, timestamp)
# AC-024: List-Unsubscribe headers in bulk_campaign emails
# AC-043: GDPR compliance (default preferences disabled for bulk_campaign)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PLUGIN_DIR="${PROJECT_ROOT}/infrastructure/tutor/plugins/email-preferences"
SECRETS_FILE="${PROJECT_ROOT}/deploy/k8s/base/secrets/external-secrets.yaml"

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# Helper functions
pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

skip() {
    echo -e "${YELLOW}⊘ SKIP${NC}: $1"
    SKIP_COUNT=$((SKIP_COUNT + 1))
}

echo "========================================="
echo "Email Preferences Service Verification"
echo "========================================="
echo ""

# AC-020: Models exist
echo "Checking models..."
if [[ -f "${PLUGIN_DIR}/mereka_email_preferences/models.py" ]]; then
    if grep -q "class NotificationPreference" "${PLUGIN_DIR}/mereka_email_preferences/models.py"; then
        pass "AC-020: NotificationPreference model exists"
    else
        fail "AC-020: NotificationPreference model not found"
    fi

    if grep -q "class PreferenceAuditLog" "${PLUGIN_DIR}/mereka_email_preferences/models.py"; then
        pass "AC-023: PreferenceAuditLog model exists"
    else
        fail "AC-023: PreferenceAuditLog model not found"
    fi

    # Check 15 message types
    message_types=(
        "password_reset"
        "account_activation"
        "enrollment_confirmation"
        "course_announcement"
        "assignment_reminder"
        "grade_posted"
        "discussion_reply"
        "discussion_mention"
        "certificate_issued"
        "course_start_reminder"
        "course_completion"
        "license_expiry_warning"
        "enterprise_welcome"
        "bulk_campaign"
        "forum_digest"
    )

    missing_types=()
    for msg_type in "${message_types[@]}"; do
        if grep -q "'${msg_type}'" "${PLUGIN_DIR}/mereka_email_preferences/models.py"; then
            :  # Found
        else
            missing_types+=("$msg_type")
        fi
    done

    if [[ ${#missing_types[@]} -eq 0 ]]; then
        pass "AC-020: All 15 message types defined"
    else
        fail "AC-020: Missing message types: ${missing_types[*]}"
    fi

    # Check channels
    if grep -q "'email'" "${PLUGIN_DIR}/mereka_email_preferences/models.py" && \
       grep -q "'push'" "${PLUGIN_DIR}/mereka_email_preferences/models.py" && \
       grep -q "'in_app'" "${PLUGIN_DIR}/mereka_email_preferences/models.py"; then
        pass "AC-020: All 3 channels defined (email, push, in_app)"
    else
        fail "AC-020: Missing channel definitions"
    fi

    # Check audit log fields (AC-023)
    audit_fields=(
        "user_id"
        "message_type"
        "channel"
        "old_value"
        "new_value"
        "consent_version"
        "ip_address_hash"
        "timestamp"
        "change_source"
    )

    missing_fields=()
    for field in "${audit_fields[@]}"; do
        if grep -q "${field}" "${PLUGIN_DIR}/mereka_email_preferences/models.py"; then
            :  # Found
        else
            missing_fields+=("$field")
        fi
    done

    if [[ ${#missing_fields[@]} -eq 0 ]]; then
        pass "AC-023: All audit log fields present"
    else
        fail "AC-023: Missing audit log fields: ${missing_fields[*]}"
    fi
else
    fail "AC-020: models.py not found"
fi

# AC-020: Check default preferences logic
echo ""
echo "Checking default preferences..."
if [[ -f "${PLUGIN_DIR}/mereka_email_preferences/utils.py" ]]; then
    # AC-043: GDPR - bulk_campaign email disabled by default
    if grep -q "'bulk_campaign'.*'email'.*False" "${PLUGIN_DIR}/mereka_email_preferences/utils.py"; then
        pass "AC-043: GDPR - bulk_campaign email disabled by default"
    else
        fail "AC-043: GDPR - bulk_campaign email not disabled by default"
    fi

    # Check system-critical types
    if grep -q "password_reset.*account_activation" "${PLUGIN_DIR}/mereka_email_preferences/utils.py" || \
       grep -q "SYSTEM_CRITICAL_TYPES" "${PLUGIN_DIR}/mereka_email_preferences/utils.py"; then
        pass "AC-020: System-critical types defined (password_reset, account_activation)"
    else
        fail "AC-020: System-critical types not defined"
    fi
else
    fail "AC-020: utils.py not found"
fi

# AC-022: HMAC token utilities
echo ""
echo "Checking HMAC token utilities..."
if [[ -f "${PLUGIN_DIR}/mereka_email_preferences/utils.py" ]]; then
    if grep -q "def generate_unsubscribe_token" "${PLUGIN_DIR}/mereka_email_preferences/utils.py"; then
        pass "AC-022: HMAC token generation function exists"
    else
        fail "AC-022: HMAC token generation function not found"
    fi

    if grep -q "def validate_unsubscribe_token" "${PLUGIN_DIR}/mereka_email_preferences/utils.py"; then
        pass "AC-022: HMAC token validation function exists"
    else
        fail "AC-022: HMAC token validation function not found"
    fi

    # Check HMAC uses SHA256
    if grep -q "hashlib.sha256" "${PLUGIN_DIR}/mereka_email_preferences/utils.py"; then
        pass "AC-022: HMAC uses SHA256"
    else
        fail "AC-022: HMAC does not use SHA256"
    fi

    # Check 90-day expiry
    if grep -q "90" "${PLUGIN_DIR}/mereka_email_preferences/utils.py"; then
        pass "AC-022: 90-day token expiry configured"
    else
        fail "AC-022: 90-day token expiry not found"
    fi

    # Check IP address hashing (AC-023)
    if grep -q "def hash_ip_address" "${PLUGIN_DIR}/mereka_email_preferences/utils.py"; then
        pass "AC-023: IP address hashing function exists"
    else
        fail "AC-023: IP address hashing function not found"
    fi
else
    fail "AC-022: utils.py not found"
fi

# AC-020: DRF views exist
echo ""
echo "Checking DRF views..."
if [[ -f "${PLUGIN_DIR}/mereka_email_preferences/views.py" ]]; then
    if grep -q "class PreferencesListView" "${PLUGIN_DIR}/mereka_email_preferences/views.py"; then
        pass "AC-020: PreferencesListView exists (GET /api/notifications/v1/preferences/)"
    else
        fail "AC-020: PreferencesListView not found"
    fi

    if grep -q "class PreferencesUpdateView" "${PLUGIN_DIR}/mereka_email_preferences/views.py"; then
        pass "AC-021: PreferencesUpdateView exists (PUT /api/notifications/v1/preferences/)"
    else
        fail "AC-021: PreferencesUpdateView not found"
    fi

    if grep -q "class UnsubscribeView" "${PLUGIN_DIR}/mereka_email_preferences/views.py"; then
        pass "AC-022: UnsubscribeView exists (GET /api/notifications/v1/unsubscribe/)"
    else
        fail "AC-022: UnsubscribeView not found"
    fi

    # Check audit logging in views
    if grep -q "PreferenceAuditLog.objects.create" "${PLUGIN_DIR}/mereka_email_preferences/views.py"; then
        pass "AC-023: Audit logging in views"
    else
        fail "AC-023: Audit logging not found in views"
    fi
else
    fail "AC-020: views.py not found"
fi

# Check URL patterns
echo ""
echo "Checking URL patterns..."
if [[ -f "${PLUGIN_DIR}/mereka_email_preferences/urls.py" ]]; then
    if grep -q "PreferencesListView" "${PLUGIN_DIR}/mereka_email_preferences/urls.py"; then
        pass "AC-020: URL pattern for preferences list"
    else
        fail "AC-020: URL pattern for preferences list not found"
    fi

    if grep -q "PreferencesUpdateView" "${PLUGIN_DIR}/mereka_email_preferences/urls.py"; then
        pass "AC-021: URL pattern for preferences update"
    else
        fail "AC-021: URL pattern for preferences update not found"
    fi

    if grep -q "UnsubscribeView" "${PLUGIN_DIR}/mereka_email_preferences/urls.py"; then
        pass "AC-022: URL pattern for unsubscribe"
    else
        fail "AC-022: URL pattern for unsubscribe not found"
    fi
else
    fail "AC-020: urls.py not found"
fi

# AC-024: List-Unsubscribe middleware
echo ""
echo "Checking List-Unsubscribe middleware..."
if [[ -f "${PLUGIN_DIR}/mereka_email_preferences/middleware.py" ]]; then
    if grep -q "class ListUnsubscribeMiddleware" "${PLUGIN_DIR}/mereka_email_preferences/middleware.py"; then
        pass "AC-024: ListUnsubscribeMiddleware exists"
    else
        fail "AC-024: ListUnsubscribeMiddleware not found"
    fi

    if grep -q "List-Unsubscribe" "${PLUGIN_DIR}/mereka_email_preferences/middleware.py"; then
        pass "AC-024: List-Unsubscribe header handling"
    else
        fail "AC-024: List-Unsubscribe header not found"
    fi
else
    fail "AC-024: middleware.py not found"
fi

# Check Django migration
echo ""
echo "Checking Django migration..."
if [[ -f "${PLUGIN_DIR}/mereka_email_preferences/migrations/0001_initial.py" ]]; then
    if grep -q "name='NotificationPreference'" "${PLUGIN_DIR}/mereka_email_preferences/migrations/0001_initial.py"; then
        pass "AC-020: Migration creates NotificationPreference model"
    else
        fail "AC-020: Migration does not create NotificationPreference model"
    fi

    if grep -q "name='PreferenceAuditLog'" "${PLUGIN_DIR}/mereka_email_preferences/migrations/0001_initial.py"; then
        pass "AC-023: Migration creates PreferenceAuditLog model"
    else
        fail "AC-023: Migration does not create PreferenceAuditLog model"
    fi
else
    fail "AC-020: 0001_initial.py migration not found"
fi

# Check Django admin
echo ""
echo "Checking Django admin..."
if [[ -f "${PLUGIN_DIR}/mereka_email_preferences/admin.py" ]]; then
    if grep -q "@admin.register(NotificationPreference)" "${PLUGIN_DIR}/mereka_email_preferences/admin.py"; then
        pass "AC-020: NotificationPreference admin registered"
    else
        fail "AC-020: NotificationPreference admin not registered"
    fi

    if grep -q "@admin.register(PreferenceAuditLog)" "${PLUGIN_DIR}/mereka_email_preferences/admin.py"; then
        pass "AC-023: PreferenceAuditLog admin registered"
    else
        fail "AC-023: PreferenceAuditLog admin not registered"
    fi

    # Check audit log is read-only
    if grep -q "def has_add_permission" "${PLUGIN_DIR}/mereka_email_preferences/admin.py" && \
       grep -q "return False" "${PLUGIN_DIR}/mereka_email_preferences/admin.py"; then
        pass "AC-023: Audit log admin is read-only"
    else
        fail "AC-023: Audit log admin is not read-only"
    fi
else
    fail "AC-020: admin.py not found"
fi

# Check DRF serializers
echo ""
echo "Checking DRF serializers..."
if [[ -f "${PLUGIN_DIR}/mereka_email_preferences/serializers.py" ]]; then
    if grep -q "class NotificationPreferenceSerializer" "${PLUGIN_DIR}/mereka_email_preferences/serializers.py"; then
        pass "AC-020: NotificationPreferenceSerializer exists"
    else
        fail "AC-020: NotificationPreferenceSerializer not found"
    fi

    if grep -q "class PreferencesUpdateSerializer" "${PLUGIN_DIR}/mereka_email_preferences/serializers.py"; then
        pass "AC-021: PreferencesUpdateSerializer exists"
    else
        fail "AC-021: PreferencesUpdateSerializer not found"
    fi

    # Check system-critical validation
    if grep -q "SYSTEM_CRITICAL_TYPES" "${PLUGIN_DIR}/mereka_email_preferences/serializers.py"; then
        pass "AC-020: System-critical types validation in serializer"
    else
        fail "AC-020: System-critical types validation not found"
    fi
else
    fail "AC-020: serializers.py not found"
fi

# Check setup.py
echo ""
echo "Checking plugin setup..."
if [[ -f "${PLUGIN_DIR}/setup.py" ]]; then
    if grep -q "name='mereka_email_preferences'" "${PLUGIN_DIR}/setup.py"; then
        pass "Plugin setup.py exists with correct name"
    else
        fail "Plugin setup.py has incorrect name"
    fi
else
    fail "Plugin setup.py not found"
fi

# Check apps.py
if [[ -f "${PLUGIN_DIR}/mereka_email_preferences/apps.py" ]]; then
    if grep -q "class MerekaEmailPreferencesConfig" "${PLUGIN_DIR}/mereka_email_preferences/apps.py"; then
        pass "Plugin apps.py exists with correct config"
    else
        fail "Plugin apps.py has incorrect config"
    fi
else
    fail "Plugin apps.py not found"
fi

# Check ExternalSecret for HMAC key
echo ""
echo "Checking ExternalSecret configuration..."
if [[ -f "${SECRETS_FILE}" ]]; then
    if grep -q "UNSUBSCRIBE_HMAC_SECRET" "${SECRETS_FILE}"; then
        pass "AC-022: UNSUBSCRIBE_HMAC_SECRET in ExternalSecret"
    else
        fail "AC-022: UNSUBSCRIBE_HMAC_SECRET not in ExternalSecret"
    fi

    if grep -q "MEREKA_LMS_UNSUBSCRIBE_HMAC_SECRET" "${SECRETS_FILE}"; then
        pass "AC-022: MEREKA_LMS_UNSUBSCRIBE_HMAC_SECRET remoteRef in ExternalSecret"
    else
        fail "AC-022: MEREKA_LMS_UNSUBSCRIBE_HMAC_SECRET remoteRef not in ExternalSecret"
    fi
else
    fail "AC-022: ExternalSecret file not found"
fi

# Summary
echo ""
echo "========================================="
echo "Summary"
echo "========================================="
echo -e "${GREEN}PASS${NC}: ${PASS_COUNT}"
echo -e "${RED}FAIL${NC}: ${FAIL_COUNT}"
echo -e "${YELLOW}SKIP${NC}: ${SKIP_COUNT}"
echo ""

if [[ ${FAIL_COUNT} -eq 0 ]]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some checks failed.${NC}"
    exit 1
fi
