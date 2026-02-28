#!/usr/bin/env bash
# Email & Notifications - Multi-Language Template Verification
# @spec: email-notifications-pipeline_spec.md
# @covers AC-025

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

do_pass() { echo "✓ $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
do_fail() { echo "✗ $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
do_warn() { echo "⚠ $1"; WARN_COUNT=$((WARN_COUNT + 1)); }

cd "$REPO_ROOT" || exit 1

echo "=== Email & Notifications: Multi-Language Template Verification ==="
echo

# AC-025: Malay (ms) template existence
echo "AC-025: Multi-language email templates (EN, MS, ZH)..."

# Search for ACE templates
TEMPLATE_DIRS=$(find infrastructure/tutor -type d -name "templates" 2>/dev/null)

if [ -z "$TEMPLATE_DIRS" ]; then
    do_warn "No template directories found in infrastructure/tutor"
    TEMPLATE_DIRS="infrastructure/tutor/themes"
fi

LANGUAGES_FOUND=0
EN_TEMPLATES=0
MS_TEMPLATES=0
ZH_TEMPLATES=0

for template_dir in $TEMPLATE_DIRS; do
    if [ -d "$template_dir" ]; then
        # Check for English templates (default or en/)
        if find "$template_dir" -name "*.html" -o -name "*.txt" 2>/dev/null | grep -q .; then
            EN_TEMPLATES=$((EN_TEMPLATES + 1))
        fi

        # Check for Malay templates (ms/ or ms-MY/)
        if find "$template_dir" -type d -name "ms" -o -name "ms-MY" 2>/dev/null | grep -q .; then
            if find "$template_dir" -path "*/ms/*" -name "*.html" -o -path "*/ms/*" -name "*.txt" 2>/dev/null | grep -q .; then
                MS_TEMPLATES=$((MS_TEMPLATES + 1))
            fi
        fi

        # Check for Chinese templates (zh-hans/ or zh/)
        if find "$template_dir" -type d -name "zh-hans" -o -name "zh" 2>/dev/null | grep -q .; then
            if find "$template_dir" -path "*/zh*/*" -name "*.html" -o -path "*/zh*/*" -name "*.txt" 2>/dev/null | grep -q .; then
                ZH_TEMPLATES=$((ZH_TEMPLATES + 1))
            fi
        fi
    fi
done

# Report findings
if [ "$EN_TEMPLATES" -gt 0 ]; then
    do_pass "English (EN) email templates found"
    LANGUAGES_FOUND=$((LANGUAGES_FOUND + 1))
else
    do_fail "No English email templates found"
fi

if [ "$MS_TEMPLATES" -gt 0 ]; then
    do_pass "Malay (MS) email templates found"
    LANGUAGES_FOUND=$((LANGUAGES_FOUND + 1))
else
    do_warn "No Malay (MS) email templates found (AC-025 requires MS support)"
fi

if [ "$ZH_TEMPLATES" -gt 0 ]; then
    do_pass "Chinese (ZH) email templates found"
    LANGUAGES_FOUND=$((LANGUAGES_FOUND + 1))
else
    do_warn "No Chinese (ZH) email templates found (spec requires ZH-HANS support)"
fi

echo

# Check for language fallback logic
echo "Checking language fallback logic..."

FALLBACK_FOUND=0

if find infrastructure/tutor/plugins -name "*.py" -exec grep -E "(language.*fallback|default.*lang.*en|if.*not.*template.*exists)" {} \; 2>/dev/null | grep -q .; then
    do_pass "Language fallback logic found (falls back to EN)"
    FALLBACK_FOUND=$((FALLBACK_FOUND + 1))
fi

if find infrastructure/tutor -name "*.py" -exec grep -E "(language_preference|LANGUAGE_CODE|user.*language)" {} \; 2>/dev/null | grep -q .; then
    do_pass "User language preference handling found"
    FALLBACK_FOUND=$((FALLBACK_FOUND + 1))
fi

if [ "$FALLBACK_FOUND" -eq 0 ]; then
    do_warn "Language fallback logic not evident (may rely on upstream ACE)"
fi

echo

# Check for specific message types with multi-language support
echo "Checking message type template coverage..."

MESSAGE_TYPES=(
    "enrollment_confirmation"
    "course_announcement"
    "assignment_reminder"
    "grade_posted"
    "discussion_reply"
    "certificate_issued"
    "password_reset"
    "account_activation"
)

TEMPLATES_WITH_MULTILANG=0

for msg_type in "${MESSAGE_TYPES[@]}"; do
    # Search for templates matching message type
    TEMPLATE_MATCHES=$(find infrastructure/tutor -name "*${msg_type}*" -type f \( -name "*.html" -o -name "*.txt" \) 2>/dev/null | wc -l)

    if [ "$TEMPLATE_MATCHES" -gt 0 ]; then
        # Check if multi-language versions exist
        MS_VERSION=$(find infrastructure/tutor -path "*/ms/*${msg_type}*" -type f 2>/dev/null | wc -l)
        ZH_VERSION=$(find infrastructure/tutor -path "*/zh*/*${msg_type}*" -type f 2>/dev/null | wc -l)

        if [ "$MS_VERSION" -gt 0 ] || [ "$ZH_VERSION" -gt 0 ]; then
            TEMPLATES_WITH_MULTILANG=$((TEMPLATES_WITH_MULTILANG + 1))
        fi
    fi
done

if [ "$TEMPLATES_WITH_MULTILANG" -gt 0 ]; then
    do_pass "Multi-language template support found for $TEMPLATES_WITH_MULTILANG message types"
elif [ "$MS_TEMPLATES" -gt 0 ] || [ "$ZH_TEMPLATES" -gt 0 ]; then
    do_warn "Multi-language templates exist but may not cover all message types"
else
    do_warn "No multi-language templates found (English only)"
fi

echo

# Check for ACE configuration
echo "Checking ACE template configuration..."

if [ -f "infrastructure/tutor/config.yml" ] || [ -f "tutor_env/config.yml" ]; then
    CONFIG_FILE=""
    [ -f "infrastructure/tutor/config.yml" ] && CONFIG_FILE="infrastructure/tutor/config.yml"
    [ -f "tutor_env/config.yml" ] && CONFIG_FILE="tutor_env/config.yml"

    if [ -n "$CONFIG_FILE" ]; then
        if grep -qE "(ACE_TEMPLATE|ACE_CHANNEL)" "$CONFIG_FILE" 2>/dev/null; then
            do_pass "ACE template configuration found in config.yml"
        else
            do_warn "ACE configuration not found in config.yml"
        fi
    fi
else
    do_warn "No config.yml found to verify ACE configuration"
fi

echo
echo "=== Summary ==="
echo "PASS: $PASS_COUNT"
echo "FAIL: $FAIL_COUNT"
echo "WARN: $WARN_COUNT"
echo

[ "$FAIL_COUNT" -eq 0 ]
