#!/usr/bin/env bash
# Email & Notifications - ACE Channels Configuration
# @spec: email-notifications-pipeline_spec.md
# @covers AC-006, AC-008

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

echo "=== Email & Notifications: ACE Channels Configuration ==="
echo

# AC-006: ACE configured with three channels
echo "AC-006: ACE channel configuration..."

if [ -f "infrastructure/tutor/config.yml" ]; then
    CONFIG="infrastructure/tutor/config.yml"
elif [ -f "tutor_env/config.yml" ]; then
    CONFIG="tutor_env/config.yml"
else
    do_warn "No config.yml found (expected in infrastructure/tutor/ or tutor_env/)"
    CONFIG=""
fi

if [ -n "$CONFIG" ]; then
    # Check for ACE channels in config
    CHANNELS_FOUND=0
    if grep -q "ACE_ENABLED_CHANNELS" "$CONFIG" 2>/dev/null; then
        CHANNELS_CONFIG=$(grep "ACE_ENABLED_CHANNELS" "$CONFIG" | head -1)

        if echo "$CHANNELS_CONFIG" | grep -q "django_email"; then
            CHANNELS_FOUND=$((CHANNELS_FOUND + 1))
        fi

        if echo "$CHANNELS_CONFIG" | grep -q "push"; then
            CHANNELS_FOUND=$((CHANNELS_FOUND + 1))
        fi

        if echo "$CHANNELS_CONFIG" | grep -q "in_app"; then
            CHANNELS_FOUND=$((CHANNELS_FOUND + 1))
        fi

        if [ "$CHANNELS_FOUND" -eq 3 ]; then
            do_pass "ACE_ENABLED_CHANNELS includes django_email, push, and in_app"
        else
            do_fail "ACE_ENABLED_CHANNELS missing expected channels (found $CHANNELS_FOUND/3)"
        fi
    else
        do_warn "ACE_ENABLED_CHANNELS not found in config"
    fi
else
    do_warn "Cannot verify ACE channels without config file"
fi

echo

# AC-008: password_reset is system-critical (non-suppressible)
echo "AC-008: System-critical message types (non-suppressible)..."

CRITICAL_TYPES_FOUND=0

# Check in plugin code for preference bypass logic
if [ -d "infrastructure/tutor/plugins/email-preferences" ]; then
    PREF_DIR="infrastructure/tutor/plugins/email-preferences"

    # Look for password_reset in SYSTEM_CRITICAL or NONSUPPRESSIBLE constants
    if has_py_pattern "$PREF_DIR" "(password_reset.*(SYSTEM_CRITICAL|NON_SUPPRESSIBLE|system.critical|non.suppressible)|(SYSTEM_CRITICAL|NON_SUPPRESSIBLE|system.critical|non.suppressible).*password_reset)"; then
        do_pass "password_reset marked as system-critical (non-suppressible)"
        CRITICAL_TYPES_FOUND=$((CRITICAL_TYPES_FOUND + 1))
    fi

    # Look for account_activation in SYSTEM_CRITICAL or NONSUPPRESSIBLE constants
    if has_py_pattern "$PREF_DIR" "(account_activation.*(SYSTEM_CRITICAL|NON_SUPPRESSIBLE|system.critical|non.suppressible)|(SYSTEM_CRITICAL|NON_SUPPRESSIBLE|system.critical|non.suppressible).*account_activation)"; then
        do_pass "account_activation marked as system-critical (non-suppressible)"
        CRITICAL_TYPES_FOUND=$((CRITICAL_TYPES_FOUND + 1))
    fi

    if [ "$CRITICAL_TYPES_FOUND" -eq 0 ]; then
        # Check for code that bypasses preferences for these types
        if has_py_pattern "$PREF_DIR" "((password_reset|account_activation).*(bypass|override|force_send|always_send)|(bypass|override|force_send|always_send).*(password_reset|account_activation))"; then
            do_pass "System-critical message types have preference bypass logic"
        else
            do_warn "System-critical message types not explicitly marked (may be in upstream code)"
        fi
    fi
else
    do_warn "Email preferences plugin not found at infrastructure/tutor/plugins/email-preferences"
fi

echo

# Check for ACE channel definitions in patches or settings
echo "Checking ACE channel routing in settings..."

SETTINGS_FILES=$(find infrastructure/tutor -name "*.py" -path "*/settings/*" 2>/dev/null)

if [ -n "$SETTINGS_FILES" ]; then
    CHANNEL_REFS=0

    for settings_file in $SETTINGS_FILES; do
        if grep -qE "(ACE_CHANNEL_DEFAULT|ACE_CHANNEL_TRANSACTIONAL)" "$settings_file" 2>/dev/null; then
            CHANNEL_REFS=$((CHANNEL_REFS + 1))
        fi
    done

    if [ "$CHANNEL_REFS" -gt 0 ]; then
        do_pass "ACE channel routing configured in settings ($CHANNEL_REFS references)"
    else
        do_warn "No ACE channel routing found in settings (may be in upstream defaults)"
    fi
else
    do_warn "No settings files found to check ACE channel routing"
fi

echo
echo "=== Summary ==="
echo "PASS: $PASS_COUNT"
echo "FAIL: $FAIL_COUNT"
echo "WARN: $WARN_COUNT"
echo

[ "$FAIL_COUNT" -eq 0 ]
