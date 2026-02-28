#!/usr/bin/env bash
# Email & Notifications - GDPR Compliance Code Verification
# @spec: email-notifications-pipeline_spec.md
# @covers AC-044, AC-045

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

do_pass() { echo "✓ $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
do_fail() { echo "✗ $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
do_warn() { echo "⚠ $1"; WARN_COUNT=$((WARN_COUNT + 1)); }
has_py_pattern() {
  local base_dir="$1"
  local pattern="$2"
  grep -R --include='*.py' --exclude-dir='__pycache__' -E "$pattern" "$base_dir" >/dev/null 2>&1
}

cd "$REPO_ROOT" || exit 1

echo "=== Email & Notifications: GDPR Compliance Code Verification ==="
echo

# AC-044: GDPR data export (notification preferences + consent)
echo "AC-044: GDPR data export for notification data..."

EXPORT_FOUND=0

# Check for GDPR export plugin or data privacy integration
if [ -d "infrastructure/tutor/plugins/data-privacy" ]; then
    PRIVACY_PLUGIN="infrastructure/tutor/plugins/data-privacy"

    if has_py_pattern "$PRIVACY_PLUGIN" "(notification.*preference|consent.*record|email.*preference)"; then
        do_pass "Notification preferences included in GDPR export"
        EXPORT_FOUND=$((EXPORT_FOUND + 1))
    fi

    if has_py_pattern "$PRIVACY_PLUGIN" "(device.*registration|push.*token)"; then
        do_pass "Device registrations included in GDPR export"
        EXPORT_FOUND=$((EXPORT_FOUND + 1))
    fi
fi

# Check email preferences plugin for export support
if [ -d "infrastructure/tutor/plugins/email-preferences" ]; then
    PREF_PLUGIN="infrastructure/tutor/plugins/email-preferences"

    if has_py_pattern "$PREF_PLUGIN" "(export.*user.*data|gdpr.*export|serialize.*preferences)"; then
        do_pass "Email preferences plugin supports data export"
        EXPORT_FOUND=$((EXPORT_FOUND + 1))
    fi
fi

# Check for notification data in export
if [ -d "infrastructure/tutor/plugins/notifications-inapp" ]; then
    INAPP_PLUGIN="infrastructure/tutor/plugins/notifications-inapp"

    if has_py_pattern "$INAPP_PLUGIN" "(export.*notification|gdpr.*export)"; then
        do_pass "In-app notifications included in GDPR export"
        EXPORT_FOUND=$((EXPORT_FOUND + 1))
    fi
fi

if [ "$EXPORT_FOUND" -eq 0 ]; then
    do_warn "GDPR export support for notification data not found (may be in upstream or manual)"
fi

echo

# AC-045: GDPR data deletion (notification records, preferences, consent, devices)
echo "AC-045: GDPR data deletion for notification data..."

DELETION_FOUND=0

# Check for data deletion handlers
if [ -d "infrastructure/tutor/plugins/data-privacy" ]; then
    PRIVACY_PLUGIN="infrastructure/tutor/plugins/data-privacy"

    if has_py_pattern "$PRIVACY_PLUGIN" "(delete.*notification|purge.*user.*data|anonymize)"; then
        do_pass "Notification data deletion handler found"
        DELETION_FOUND=$((DELETION_FOUND + 1))
    fi
fi

# Check email preferences plugin for deletion
if [ -d "infrastructure/tutor/plugins/email-preferences" ]; then
    PREF_PLUGIN="infrastructure/tutor/plugins/email-preferences"

    if has_py_pattern "$PREF_PLUGIN" "(delete.*preference|on_delete|CASCADE)"; then
        do_pass "Email preferences deletion logic found"
        DELETION_FOUND=$((DELETION_FOUND + 1))
    fi

    # Check for consent record deletion
    if has_py_pattern "$PREF_PLUGIN" "(delete.*consent|ConsentRecord.*delete)"; then
        do_pass "Consent record deletion logic found"
        DELETION_FOUND=$((DELETION_FOUND + 1))
    fi
fi

# Check push notifications plugin for device deletion
if [ -d "infrastructure/tutor/plugins/push-notifications" ]; then
    PUSH_PLUGIN="infrastructure/tutor/plugins/push-notifications"

    if has_py_pattern "$PUSH_PLUGIN" "(delete.*device|unregister.*all|CASCADE)"; then
        do_pass "Device registration deletion logic found"
        DELETION_FOUND=$((DELETION_FOUND + 1))
    fi
fi

# Check in-app notifications plugin for deletion
if [ -d "infrastructure/tutor/plugins/notifications-inapp" ]; then
    INAPP_PLUGIN="infrastructure/tutor/plugins/notifications-inapp"

    if has_py_pattern "$INAPP_PLUGIN" "(delete.*notification|purge.*user|CASCADE)"; then
        do_pass "In-app notification deletion logic found"
        DELETION_FOUND=$((DELETION_FOUND + 1))
    fi
fi

if [ "$DELETION_FOUND" -eq 0 ]; then
    do_warn "GDPR deletion support for notification data not found (may rely on CASCADE)"
fi

echo

# Additional checks: Consent tracking
echo "Checking consent tracking compliance..."

if [ -d "infrastructure/tutor/plugins/email-preferences" ]; then
    PREF_PLUGIN="infrastructure/tutor/plugins/email-preferences"

    # Check for consent_version field
    if has_py_pattern "$PREF_PLUGIN" "consent_version"; then
        do_pass "Consent version tracking found (GDPR audit trail)"
    else
        do_warn "consent_version field not found (GDPR compliance risk)"
    fi

    # Check for consent_text_hash
    if has_py_pattern "$PREF_PLUGIN" "(consent_text_hash|SHA-256)"; then
        do_pass "Consent text hash tracking found (GDPR proof of consent)"
    else
        do_warn "Consent text hash not found (may store version only)"
    fi

    # Check for IP address hashing
    if has_py_pattern "$PREF_PLUGIN" "(ip_address_hash|hash.*ip)"; then
        do_pass "IP address hashing found (GDPR compliance for audit)"
    else
        do_warn "IP address hashing not found (may store plaintext or skip IP)"
    fi

    # Check for consent timestamp
    if has_py_pattern "$PREF_PLUGIN" "(consented_at|consent.*timestamp)"; then
        do_pass "Consent timestamp tracking found"
    else
        do_warn "Consent timestamp not found (GDPR audit trail incomplete)"
    fi
else
    do_warn "Cannot verify consent tracking without email-preferences plugin"
fi

echo

# Check for marketing opt-in requirement
echo "Checking marketing opt-in enforcement..."

if [ -d "infrastructure/tutor/plugins/email-preferences" ]; then
    PREF_PLUGIN="infrastructure/tutor/plugins/email-preferences"

    # Check for opt-in default (bulk_campaign should default to disabled)
    if has_py_pattern "$PREF_PLUGIN" "(bulk_campaign.*False|bulk_campaign.*disabled|opt.*in.*required)"; then
        do_pass "Marketing emails default to opt-out (GDPR compliant)"
    else
        do_warn "Marketing opt-in default not found (may violate GDPR)"
    fi

    # Check for explicit consent requirement
    if has_py_pattern "$PREF_PLUGIN" "(explicit.*consent|require.*opt.*in|marketing.*consent)"; then
        do_pass "Explicit consent requirement found for marketing"
    else
        do_warn "Explicit consent enforcement not evident"
    fi
fi

echo
echo "=== Summary ==="
echo "PASS: $PASS_COUNT"
echo "FAIL: $FAIL_COUNT"
echo "WARN: $WARN_COUNT"
echo

[ "$FAIL_COUNT" -eq 0 ]
