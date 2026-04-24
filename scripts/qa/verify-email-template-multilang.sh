#!/usr/bin/env bash
# Email & Notifications - Multi-Language Template Verification
# @spec: email-notifications-pipeline_spec.md
# @covers AC-025

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$REPO_ROOT/.." && pwd)}"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

do_pass() { echo "✓ $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
do_fail() { echo "✗ $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
do_warn() { echo "⚠ $1"; WARN_COUNT=$((WARN_COUNT + 1)); }

cd "$REPO_ROOT" || exit 1

resolve_ace_settings_source() {
    local candidates=()
    if [[ -n "${EMAIL_TEMPLATE_SETTINGS_SOURCE:-}" ]]; then
        candidates+=("${EMAIL_TEMPLATE_SETTINGS_SOURCE}")
    fi
    candidates+=(
        "../infrastructure/apps/mereka-lms/overlays/prod/patches/production-prod.py"
        "../bbi-infrastructure/apps/mereka-lms/overlays/prod/patches/production-prod.py"
        "${WORKSPACE_ROOT}/infrastructure/apps/mereka-lms/overlays/prod/patches/production-prod.py"
        "${WORKSPACE_ROOT}/bbi-infrastructure/apps/mereka-lms/overlays/prod/patches/production-prod.py"
        "${HOME}/projects/k8s/infrastructure/apps/mereka-lms/overlays/prod/patches/production-prod.py"
        "${HOME}/projects/k8s/bbi-infrastructure/apps/mereka-lms/overlays/prod/patches/production-prod.py"
        "infrastructure/tutor/config.yml"
        "tutor_env/config.yml"
    )

    local candidate
    for candidate in "${candidates[@]}"; do
        if [[ -n "$candidate" && -f "$candidate" ]]; then
            printf "%s" "$candidate"
            return 0
        fi
    done
    return 1
}

ACE_SETTINGS_SOURCE="$(resolve_ace_settings_source || true)"

echo "=== Email & Notifications: Multi-Language Template Verification ==="
echo "ACE settings source: ${ACE_SETTINGS_SOURCE:-not found}"
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
        if find "$template_dir" -type d \( -name "ms" -o -name "ms-MY" \) 2>/dev/null | grep -q .; then
            if find "$template_dir" \( -path "*/ms/*" -o -path "*/ms-MY/*" \) \( -name "*.html" -o -name "*.txt" \) 2>/dev/null | grep -q .; then
                MS_TEMPLATES=$((MS_TEMPLATES + 1))
            fi
        fi

        # Check for Chinese templates (zh-hans/ or zh/)
        if find "$template_dir" -type d \( -name "zh-hans" -o -name "zh" \) 2>/dev/null | grep -q .; then
            if find "$template_dir" \( -path "*/zh-hans/*" -o -path "*/zh/*" \) \( -name "*.html" -o -name "*.txt" \) 2>/dev/null | grep -q .; then
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

if find infrastructure/tutor/plugins -name "*.py" -exec grep -E "(language.*fallback|default.*lang.*en|if.*not.*template.*exists|if language != 'en')" {} \; 2>/dev/null | grep -q .; then
    do_pass "Language fallback logic found (falls back to EN)"
    FALLBACK_FOUND=$((FALLBACK_FOUND + 1))
fi

if find infrastructure/tutor -name "*.py" -exec grep -E "(language_preference|LANGUAGE_CODE|user.*language|LANGUAGE_CHOICES)" {} \; 2>/dev/null | grep -q .; then
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
    "welcome"
    "enrollment"
    "grade"
    "certificate"
    "deadline"
    "forum"
    "password_reset"
    "account_activation"
    "course_announcement"
    "survey"
    "marketing_promo"
    "re_engagement"
    "feedback"
    "maintenance_notice"
    "campaign"
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

# AC-025 (branding hardening): key templates must keep Mereka branded shell
echo "Checking key email template branding markers..."

EMAIL_TEMPLATE_ROOT="infrastructure/tutor/custom-apps/openedx_email_templates/templates/email"

assert_template_has_marker() {
    local file="$1"
    local marker="$2"
    local label="$3"
    if [ ! -f "$file" ]; then
        do_fail "$label — file missing: $file"
        return
    fi
    if grep -qF "$marker" "$file"; then
        do_pass "$label"
    else
        do_fail "$label (missing marker: $marker)"
    fi
}

# Transactional templates
assert_template_has_marker \
  "$EMAIL_TEMPLATE_ROOT/password_reset.html" \
  "linear-gradient(120deg" \
  "Password reset template has branded gradient header shell"
assert_template_has_marker \
  "$EMAIL_TEMPLATE_ROOT/password_reset.html" \
  "org_primary_color|default:'#ab3b78'" \
  "Password reset template uses Mereka primary fallback color"
assert_template_has_marker \
  "$EMAIL_TEMPLATE_ROOT/enrollment.html" \
  "org_accent_color|default:'#237072'" \
  "Enrollment template uses Mereka accent fallback color"
assert_template_has_marker \
  "$EMAIL_TEMPLATE_ROOT/welcome.html" \
  "org_support_email" \
  "Welcome template footer retains support contact link"
assert_template_has_marker \
  "$EMAIL_TEMPLATE_ROOT/password_reset.txt" \
  "Support: {{ org_support_email }}" \
  "Password reset text template retains support contact footer"
assert_template_has_marker \
  "$EMAIL_TEMPLATE_ROOT/enrollment.txt" \
  "Support: {{ org_support_email }}" \
  "Enrollment text template retains support contact footer"
assert_template_has_marker \
  "$EMAIL_TEMPLATE_ROOT/welcome.txt" \
  "Support: {{ org_support_email }}" \
  "Welcome text template retains support contact footer"
assert_template_has_marker \
  "$EMAIL_TEMPLATE_ROOT/account_activation.txt" \
  "Support: {{ org_support_email }}" \
  "Account activation text template retains support contact footer"
assert_template_has_marker \
  "$EMAIL_TEMPLATE_ROOT/account_activation.html" \
  "linear-gradient(120deg" \
  "Account activation template has branded gradient header shell"
assert_template_has_marker \
  "$EMAIL_TEMPLATE_ROOT/account_activation.html" \
  "org_primary_color|default:'#ab3b78'" \
  "Account activation template uses Mereka primary fallback color"
assert_template_has_marker \
  "$EMAIL_TEMPLATE_ROOT/course_announcement.html" \
  "org_accent_color|default:'#237072'" \
  "Course announcement template uses Mereka accent fallback color"
assert_template_has_marker \
  "$EMAIL_TEMPLATE_ROOT/deadline.html" \
  "border-radius: 9999px" \
  "Deadline template CTA keeps pill-radius branding"
assert_template_has_marker \
  "$EMAIL_TEMPLATE_ROOT/certificate.html" \
  "linear-gradient(120deg" \
  "Certificate template has branded gradient header shell"
assert_template_has_marker \
  "$EMAIL_TEMPLATE_ROOT/certificate.html" \
  "org_primary_color|default:'#ab3b78'" \
  "Certificate template uses Mereka primary fallback color"
assert_template_has_marker \
  "$EMAIL_TEMPLATE_ROOT/certificate.html" \
  "org_accent_color|default:'#237072'" \
  "Certificate template uses Mereka accent fallback color"
assert_template_has_marker \
  "$EMAIL_TEMPLATE_ROOT/certificate.html" \
  "border-radius: 9999px" \
  "Certificate template CTA keeps pill-radius branding"
assert_template_has_marker \
  "$EMAIL_TEMPLATE_ROOT/feedback.html" \
  "linear-gradient(120deg" \
  "Feedback template has branded gradient header shell"
assert_template_has_marker \
  "$EMAIL_TEMPLATE_ROOT/forum.html" \
  "org_accent_color|default:'#237072'" \
  "Forum template uses Mereka accent fallback color"
assert_template_has_marker \
  "$EMAIL_TEMPLATE_ROOT/grade.html" \
  "org_primary_color|default:'#ab3b78'" \
  "Grade template uses Mereka primary fallback color"
assert_template_has_marker \
  "$EMAIL_TEMPLATE_ROOT/maintenance_notice.html" \
  "org_accent_color|default:'#237072'" \
  "Maintenance template uses Mereka accent fallback color"
assert_template_has_marker \
  "$EMAIL_TEMPLATE_ROOT/re_engagement.html" \
  "unsubscribe_url" \
  "Re-engagement template retains unsubscribe link"
assert_template_has_marker \
  "$EMAIL_TEMPLATE_ROOT/survey.html" \
  "border-radius: 9999px" \
  "Survey template CTA keeps pill-radius branding"

# Marketing templates
assert_template_has_marker \
  "$EMAIL_TEMPLATE_ROOT/campaign.html" \
  "Unsubscribe" \
  "Campaign template retains unsubscribe footer"
assert_template_has_marker \
  "$EMAIL_TEMPLATE_ROOT/marketing_promo.html" \
  "border-radius: 9999px" \
  "Marketing promo template CTA keeps pill-radius branding"

# Kajabi SSO migration welcome templates (transactional edge path)
KAJABI_TEMPLATE_ROOT="infrastructure/tutor/custom-apps/openedx_kajabi_sso/templates"
assert_template_has_marker \
  "$KAJABI_TEMPLATE_ROOT/openedx_kajabi_sso/welcome_email.html" \
  "linear-gradient(120deg" \
  "Kajabi welcome HTML template has branded gradient header shell"
assert_template_has_marker \
  "$KAJABI_TEMPLATE_ROOT/openedx_kajabi_sso/welcome_email.html" \
  "org_primary_color|default:'#ab3b78'" \
  "Kajabi welcome HTML template uses Mereka primary fallback color"
assert_template_has_marker \
  "$KAJABI_TEMPLATE_ROOT/openedx_kajabi_sso/welcome_email.html" \
  "org_accent_color|default:'#237072'" \
  "Kajabi welcome HTML template uses Mereka accent fallback color"
assert_template_has_marker \
  "$KAJABI_TEMPLATE_ROOT/openedx_kajabi_sso/welcome_email.html" \
  "platform_name|default:\"Mereka Academy\"" \
  "Kajabi welcome HTML template supports platform fallback naming"
assert_template_has_marker \
  "$KAJABI_TEMPLATE_ROOT/openedx_kajabi_sso/welcome_email.txt" \
  "platform_name|default:\"Mereka Academy\"" \
  "Kajabi welcome text template supports platform fallback naming"
assert_template_has_marker \
  "$KAJABI_TEMPLATE_ROOT/kajabi_sso/welcome_email.html" \
  "include \"openedx_kajabi_sso/welcome_email.html\"" \
  "Kajabi alias HTML template includes canonical branded template"
assert_template_has_marker \
  "$KAJABI_TEMPLATE_ROOT/kajabi_sso/welcome_email.txt" \
  "include \"openedx_kajabi_sso/welcome_email.txt\"" \
  "Kajabi alias text template includes canonical branded template"

# Full-shell regression checks across all branded HTML templates.
for template_file in "$EMAIL_TEMPLATE_ROOT"/*.html; do
    template_name="$(basename "$template_file")"
    assert_template_has_marker \
      "$template_file" \
      "linear-gradient(120deg" \
      "${template_name} includes branded gradient header shell"
    assert_template_has_marker \
      "$template_file" \
      "org_primary_color|default:'#ab3b78'" \
      "${template_name} includes Mereka primary fallback token"
    assert_template_has_marker \
      "$template_file" \
      "org_accent_color|default:'#237072'" \
      "${template_name} includes Mereka accent fallback token"
done

echo

# Check for ACE configuration in runtime overlay settings or local Tutor config.
echo "Checking ACE template configuration..."

ACE_CONFIG_FOUND=0
if [ -n "$ACE_SETTINGS_SOURCE" ] && [ -f "$ACE_SETTINGS_SOURCE" ]; then
    if grep -qE "(ACE_TEMPLATE|ACE_CHANNEL|ACE_ENABLED_CHANNELS|ACE_CHANNEL_DEFAULT_EMAIL|BULK_EMAIL_SEND_USING_EDX_ACE)" "$ACE_SETTINGS_SOURCE" 2>/dev/null; then
        do_pass "ACE template configuration found in ${ACE_SETTINGS_SOURCE}"
        ACE_CONFIG_FOUND=1
    fi
fi

if [ "$ACE_CONFIG_FOUND" -eq 0 ]; then
    do_warn "ACE configuration not found in expected settings/config files"
fi

echo
echo "=== Summary ==="
echo "PASS: $PASS_COUNT"
echo "FAIL: $FAIL_COUNT"
echo "WARN: $WARN_COUNT"
echo

[ "$FAIL_COUNT" -eq 0 ]
