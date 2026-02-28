#!/usr/bin/env bash
# Verify certificate-related branding surfaces across theme CSS, MFE slot wiring,
# and transactional certificate email templates.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

PASS=0
WARN=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $*"; }
warn() { WARN=$((WARN + 1)); echo "WARN: $*"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }

assert_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"
  if grep -Fq "$needle" "$file"; then
    pass "$label"
  else
    fail "$label (missing '$needle' in ${file#$REPO_ROOT/})"
  fi
}

echo "=== Certificate Branding Verification ==="

CSS_FILES=(
  "$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css"
  "$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css"
  "$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/css/mereka-overrides.css"
)

for css_file in "${CSS_FILES[@]}"; do
  if [[ -f "$css_file" ]]; then
    pass "Theme override CSS present: ${css_file#$REPO_ROOT/}"
  else
    fail "Theme override CSS missing: ${css_file#$REPO_ROOT/}"
    continue
  fi

  assert_contains "$css_file" ".dashboard .certificates h2" "Dashboard certificate heading selector present (${css_file##*/})"
  assert_contains "$css_file" ".view-certificates .content-primary .no-content .button" "Certificates CTA selector present (${css_file##*/})"
done

if cmp -s "${CSS_FILES[0]}" "${CSS_FILES[1]}" && cmp -s "${CSS_FILES[0]}" "${CSS_FILES[2]}"; then
  pass "Certificate-related override CSS is in sync across common/lms/cms copies"
else
  warn "Certificate-related override CSS differs across common/lms/cms copies"
fi

PLUGIN_FILE="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
MFE_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss"

if [[ -f "$PLUGIN_FILE" ]]; then
  assert_contains "$PLUGIN_FILE" "org.openedx.frontend.learning.progress_certificate_status.v1" "Learning progress certificate slot is wired in Tutor plugin"
  assert_contains "$PLUGIN_FILE" "mereka_progress_certificate_status" "Certificate slot widget id is declared in Tutor plugin"
else
  fail "Tutor plugin file missing: infrastructure/tutor/plugins/mereka_lms.py"
fi

if [[ -f "$MFE_SCSS" ]]; then
  assert_contains "$MFE_SCSS" ".mereka-progress-certificate-status" "MFE certificate slot class styling exists"
else
  fail "MFE stylesheet missing: infrastructure/tutor/themes/mereka/mfe/mereka.scss"
fi

EMAIL_CERT_TEMPLATE="$REPO_ROOT/infrastructure/tutor/custom-apps/openedx_email_templates/templates/email/certificate.html"
EMAIL_CERT_TEMPLATE_MS="$REPO_ROOT/infrastructure/tutor/custom-apps/openedx_email_templates/templates/email/ms/certificate.html"
EMAIL_CERT_TEMPLATE_ZH="$REPO_ROOT/infrastructure/tutor/custom-apps/openedx_email_templates/templates/email/zh-hans/certificate.html"

if [[ -f "$EMAIL_CERT_TEMPLATE" ]]; then
  assert_contains "$EMAIL_CERT_TEMPLATE" "linear-gradient(120deg, {{ org_primary_color|default:'#ab3b78' }}" "Certificate email uses branded gradient header"
  assert_contains "$EMAIL_CERT_TEMPLATE" "{{ org_display_name|default:\"Mereka Academy\" }}" "Certificate email supports tenant/org display name fallback"
  assert_contains "$EMAIL_CERT_TEMPLATE" "{% trans \"View Certificate\" %}" "Certificate email CTA label is present"
else
  fail "Certificate email template missing: ${EMAIL_CERT_TEMPLATE#$REPO_ROOT/}"
fi

if [[ -f "$EMAIL_CERT_TEMPLATE_MS" ]] && [[ -f "$EMAIL_CERT_TEMPLATE_ZH" ]]; then
  assert_contains "$EMAIL_CERT_TEMPLATE_MS" "{% include \"email/certificate.html\" %}" "Malay certificate email wrapper includes branded base template"
  assert_contains "$EMAIL_CERT_TEMPLATE_ZH" "{% include \"email/certificate.html\" %}" "Chinese certificate email wrapper includes branded base template"
else
  warn "Localized certificate email wrappers missing (ms/zh-hans)"
fi

mapfile -t THEMED_CERT_TEMPLATES < <(
  find "$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates" -type f 2>/dev/null \
    | grep -E '/(certificate|certificates)' || true
)
if [[ "${#THEMED_CERT_TEMPLATES[@]}" -gt 0 ]]; then
  pass "Themed LMS certificate template override(s) found (${#THEMED_CERT_TEMPLATES[@]})"
else
  warn "No LMS certificate template overrides found under themes/mereka/lms/templates (PDF certificate branding may be upstream/default-managed)"
fi

echo ""
echo "=== Summary: PASS=$PASS WARN=$WARN FAIL=$FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
