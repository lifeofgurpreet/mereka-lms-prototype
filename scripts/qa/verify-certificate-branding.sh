#!/usr/bin/env bash
# Verify certificate-related branding surfaces across theme CSS, MFE slot wiring,
# and transactional certificate email templates.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"

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
  if grep -Fq -- "$needle" "$file"; then
    pass "$label"
  else
    fail "$label (missing '$needle' in ${file#$REPO_ROOT/})"
  fi
}

assert_not_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"
  if grep -Fq -- "$needle" "$file"; then
    fail "$label (unexpected '$needle' in ${file#$REPO_ROOT/})"
  else
    pass "$label"
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

MFE_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss"
THEME_README="$REPO_ROOT/infrastructure/tutor/themes/mereka/README.md"
SHARED_THEME_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/scss/theme.scss"
PROFILE_CERT_CARD_COMPONENT="$REPO_ROOT/tutor_env/dev/frontend-app-profile/src/profile/CertificateCard.jsx"
PLUGIN_FILE="$REPO_ROOT/infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js"

if mereka_plugin_has_any "$REPO_ROOT"; then
  if mereka_plugin_has_fixed "$REPO_ROOT" "org.openedx.frontend.learning.progress_certificate_status.v1"; then
    pass "Learning progress certificate slot is wired in Tutor plugin contract sources"
  else
    fail "Learning progress certificate slot wiring missing in Tutor plugin contract sources"
  fi

  if mereka_plugin_has_fixed "$REPO_ROOT" "mereka_progress_certificate_status"; then
    pass "Certificate slot widget id is declared in Tutor plugin contract sources"
  else
    fail "Certificate slot widget id missing in Tutor plugin contract sources"
  fi
else
  fail "Tutor plugin contract sources missing"
fi

if [[ -f "$MFE_SCSS" ]]; then
  assert_contains "$MFE_SCSS" ".mereka-progress-certificate-status" "MFE certificate slot class styling exists"
  assert_contains "$MFE_SCSS" ".mereka-progress-certificate-status__header" "MFE certificate slot includes a structured readiness header"
  assert_contains "$MFE_SCSS" ".mereka-certificate-readiness__steps" "MFE certificate slot includes a canonical readiness checklist"
  assert_contains "$MFE_SCSS" ".mereka-progress-certificate-status__hint" "MFE progress certificate helper hint styling exists"
  assert_contains "$MFE_SCSS" ".mereka-account-id-verification-hint__title" "Account verification hint has an explicit title style"
  assert_contains "$MFE_SCSS" ".mereka-additional-profile-fields__item" "Additional profile fields render as structured readiness items"
  assert_contains "$MFE_SCSS" ".profile-page .certificate" "Profile certificate cards use Mereka tokenized card styling"
  assert_contains "$MFE_SCSS" ".profile-page .certificate-type-illustration" "Profile certificate illustration shell is themed"
else
  fail "MFE stylesheet missing: infrastructure/tutor/themes/mereka/mfe/mereka.scss"
fi

if [[ -f "$PLUGIN_FILE" ]]; then
  assert_contains "$PLUGIN_FILE" "const MerekaCertificateContextShell = ({" "Certificate surfaces share one canonical context shell"
  assert_contains "$PLUGIN_FILE" "const MerekaCertificateContextMetaItem = ({ label, value }) => (" "Certificate surfaces share a canonical readiness meta row"
  assert_contains "$PLUGIN_FILE" "className=\"mereka-progress-certificate-status mereka-shell-panel my-3\"" "Progress certificate status uses the canonical context shell"
  assert_contains "$PLUGIN_FILE" "className=\"mereka-account-id-verification-hint mereka-shell-panel mb-3\"" "Account verification uses the canonical certificate context shell"
  assert_contains "$PLUGIN_FILE" "className=\"mereka-additional-profile-fields mereka-shell-panel mb-3\"" "Additional profile fields use the canonical certificate context shell"
else
  fail "MFE runtime definitions missing: infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js"
fi

if [[ -f "$SHARED_THEME_SCSS" ]]; then
  assert_contains "$SHARED_THEME_SCSS" ".view-certificates .content-primary .no-content .button" "Shared theme keeps only the Studio certificates CTA"
  assert_not_contains "$SHARED_THEME_SCSS" "body.certificate" "Shared theme does not own printable LMS certificate presentation"
  assert_not_contains "$SHARED_THEME_SCSS" ".profile-page .certificate" "Shared theme does not own MFE certificate card presentation"
else
  fail "Shared theme stylesheet missing: infrastructure/tutor/themes/mereka/scss/theme.scss"
fi

if [[ -f "$PROFILE_CERT_CARD_COMPONENT" ]]; then
  assert_contains "$PROFILE_CERT_CARD_COMPONENT" "className=\"col certificate" "Profile MFE certificate card class remains present upstream"
  assert_contains "$PROFILE_CERT_CARD_COMPONENT" "certificate-type-illustration" "Profile MFE certificate illustration class remains present upstream"
else
  warn "Profile MFE source checkout missing: tutor_env/dev/frontend-app-profile/src/profile/CertificateCard.jsx"
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

THEMED_CERT_BASE="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates/certificates/accomplishment-base.html"
if [[ -f "$THEMED_CERT_BASE" ]]; then
  pass "Themed LMS certificate base template override exists"
  assert_contains "$THEMED_CERT_BASE" "canonical owner for printable LMS certificate presentation" "Certificate template states printable ownership explicitly"
  assert_contains "$THEMED_CERT_BASE" "--mereka-cert-primary" "Certificate template defines Mereka certificate design tokens"
  assert_contains "$THEMED_CERT_BASE" "--mereka-cert-shadow" "Certificate template defines elevated certificate shell styling"
else
  fail "Missing themed LMS certificate base template override: ${THEMED_CERT_BASE#$REPO_ROOT/}"
fi

if [[ -f "$THEME_README" ]]; then
  assert_contains "$THEME_README" "Certificate ownership is split by runtime surface" "Theme README documents certificate ownership split"
  assert_contains "$THEME_README" "lms/templates/certificates/accomplishment-base.html" "Theme README names the printable LMS certificate owner"
  assert_contains "$THEME_README" "only owns the Studio \`.view-certificates\` empty-state CTA" "Theme README keeps shared theme certificate scope narrow"
else
  fail "Theme README missing: infrastructure/tutor/themes/mereka/README.md"
fi

echo ""
echo "=== Summary: PASS=$PASS WARN=$WARN FAIL=$FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
