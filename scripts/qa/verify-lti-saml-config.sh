#!/usr/bin/env bash
# @spec: cross-cutting-requirements_spec.md
# @covers AC-TCR-001, AC-TCR-002
# verify-lti-saml-config.sh — Verify LTI XBlock and SAML SP configuration alignment.
#
# Checks that:
#   - LTI consumer XBlock is available in the installed platform
#   - SAML SP ExternalSecret exists in K8s manifests with required keys
#   - third_party_auth is configured in production settings
#   - SAML SP entity ID configuration is present
#   - SAML metadata endpoint configuration is declared
#   - LTI passport / configuration exists in settings or documentation
#
# Usage:
#   ./scripts/qa/verify-lti-saml-config.sh [--offline|--online]
#
#   --offline  (default) Check repo file layout and manifest declarations only.
#              Safe to run without cluster access.
#   --online   Also probe live endpoints (requires kubectl + public HTTPS access).
#
# Exit codes:
#   0 — All checks PASS (SKIPs are acceptable)
#   1 — One or more FAIL
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"

# ── Mode ─────────────────────────────────────────────────────────────────────
MODE="offline"
for arg in "$@"; do
  case "$arg" in
    --offline) MODE="offline" ;;
    --online)  MODE="online" ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

# ── Colors ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ── Counters ─────────────────────────────────────────────────────────────────
PASS=0
FAIL=0
SKIP=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }
section() { echo ""; echo "=== $1 ==="; }

# ── File paths ───────────────────────────────────────────────────────────────
EXTERNAL_SECRETS="${REPO_ROOT}/deploy/k8s/base/secrets/external-secrets.yaml"
PROD_SETTINGS="${REPO_ROOT}/deploy/k8s/base/apps/openedx/settings/lms/production.py"
APPLY_PATCHES="${REPO_ROOT}/infrastructure/tutor/apply-patches.sh"
LTI_DOC="${REPO_ROOT}/docs/integrations/LTI.md"

NAMESPACE="mereka-lms"
LMS_DOMAIN="academyv2.mereka.io"

echo "========================================================"
echo "LTI + SAML Configuration Verification"
echo "Mode: ${MODE}"
echo "Repo: ${REPO_ROOT}"
echo "========================================================"

# ═════════════════════════════════════════════════════════════════════════════
# OFFLINE CHECKS
# ═════════════════════════════════════════════════════════════════════════════

# ── Check 1: SAML ExternalSecret exists ──────────────────────────────────────
section "SAML SP ExternalSecret (K8s manifest)"

if [[ ! -f "${EXTERNAL_SECRETS}" ]]; then
  fail "ExternalSecrets manifest not found: ${EXTERNAL_SECRETS}"
else
  # enterprise-sso-secrets ExternalSecret must exist
  if grep -q "enterprise-sso-secrets" "${EXTERNAL_SECRETS}"; then
    pass "enterprise-sso-secrets ExternalSecret declared in manifest"
  else
    fail "enterprise-sso-secrets ExternalSecret NOT found in ${EXTERNAL_SECRETS}"
  fi

  # SAML SP cert key mapping
  if grep -q "SAML_SP_PUBLIC_CERT" "${EXTERNAL_SECRETS}"; then
    pass "SAML_SP_PUBLIC_CERT mapped in ExternalSecret"
  else
    fail "SAML_SP_PUBLIC_CERT not found in ExternalSecrets manifest"
  fi

  # SAML SP private key mapping
  if grep -q "SAML_SP_PRIVATE_KEY" "${EXTERNAL_SECRETS}"; then
    pass "SAML_SP_PRIVATE_KEY mapped in ExternalSecret"
  else
    fail "SAML_SP_PRIVATE_KEY not found in ExternalSecrets manifest"
  fi

  # Infisical source keys
  if grep -q "MEREKA_LMS_SAML_SP_PUBLIC_CERT" "${EXTERNAL_SECRETS}"; then
    pass "Infisical source key MEREKA_LMS_SAML_SP_PUBLIC_CERT declared"
  else
    fail "Infisical source key MEREKA_LMS_SAML_SP_PUBLIC_CERT not declared"
  fi

  if grep -q "MEREKA_LMS_SAML_SP_PRIVATE_KEY" "${EXTERNAL_SECRETS}"; then
    pass "Infisical source key MEREKA_LMS_SAML_SP_PRIVATE_KEY declared"
  else
    fail "Infisical source key MEREKA_LMS_SAML_SP_PRIVATE_KEY not declared"
  fi
fi

# ── Check 2: third_party_auth in production settings ─────────────────────────
section "third_party_auth in LMS settings"

if [[ ! -f "${PROD_SETTINGS}" ]]; then
  skip "production.py not found at ${PROD_SETTINGS} (expected if using bbi-infrastructure overlay)"
else
  if grep -q "third_party_auth" "${PROD_SETTINGS}"; then
    pass "third_party_auth referenced in production.py"
  else
    fail "third_party_auth not referenced in production.py"
  fi

  if grep -q "ENABLE_THIRD_PARTY_AUTH" "${PROD_SETTINGS}"; then
    pass "ENABLE_THIRD_PARTY_AUTH flag present in production.py"
  else
    skip "ENABLE_THIRD_PARTY_AUTH not explicitly set in production.py (may rely on base Open edX default)"
  fi
fi

# ── Check 3: SAML SP entity ID configuration ─────────────────────────────────
section "SAML SP entity ID"

if [[ -f "${PROD_SETTINGS}" ]]; then
  if grep -q "SOCIAL_AUTH_SAML_SP_ENTITY_ID\|SAML_SP_ENTITY_ID" "${PROD_SETTINGS}"; then
    pass "SAML SP entity ID configured in production.py"
  else
    fail "SAML SP entity ID (SOCIAL_AUTH_SAML_SP_ENTITY_ID) not configured"
  fi

  # SAML cert/key injection pattern
  if grep -q "SOCIAL_AUTH_SAML_SP_PUBLIC_CERT\|SOCIAL_AUTH_SAML_SP_PRIVATE_KEY" "${PROD_SETTINGS}"; then
    pass "SAML cert/key injection configured in production.py"
  else
    fail "SAML cert/key injection not found in production.py"
  fi
else
  skip "Skipping entity ID check — production.py not present locally"
fi

# ── Check 4: SAML metadata endpoint documentation ────────────────────────────
section "SAML metadata endpoint"

if [[ -f "${LTI_DOC}" ]]; then
  if grep -q "saml/metadata.xml" "${LTI_DOC}"; then
    pass "SAML metadata endpoint documented in docs/integrations/LTI.md"
  else
    fail "SAML metadata endpoint not referenced in LTI.md"
  fi
else
  fail "LTI integration guide not found: ${LTI_DOC}"
fi

# Verify metadata path is also in production settings (or apply-patches)
METADATA_FOUND=false
if [[ -f "${PROD_SETTINGS}" ]] && grep -q "saml/metadata\|auth/saml" "${PROD_SETTINGS}" 2>/dev/null; then
  METADATA_FOUND=true
fi
if [[ -f "${APPLY_PATCHES}" ]] && grep -q "saml/metadata\|auth/saml" "${APPLY_PATCHES}" 2>/dev/null; then
  METADATA_FOUND=true
fi

if [[ "${METADATA_FOUND}" == "true" ]]; then
  pass "SAML metadata path referenced in platform settings or patches"
else
  skip "SAML metadata path not explicitly in settings (Open edX provides /auth/saml/metadata.xml by default)"
fi

# ── Check 5: LTI XBlock available (repo-level check) ─────────────────────────
section "LTI XBlock availability"

# Check if lti_consumer is referenced in pip requirements or settings
LTI_FOUND=false
for f in \
  "${PLUGIN_MAIN}" \
  "${PROD_SETTINGS}" \
  "${APPLY_PATCHES}"; do
  if [[ -f "$f" ]] && grep -qi "lti_consumer\|lti-consumer" "$f" 2>/dev/null; then
    LTI_FOUND=true
    pass "lti_consumer reference found in $(basename "$f")"
    break
  fi
done

if [[ "${LTI_FOUND}" == "false" ]]; then
  # lti_consumer is bundled with Open edX base; absence from custom files is normal
  skip "lti_consumer not explicitly added in custom files (it is bundled with Open edX base — verify via kubectl if needed)"
fi

# LTI documentation exists
if [[ -f "${LTI_DOC}" ]]; then
  pass "LTI integration guide exists: docs/integrations/LTI.md"
else
  fail "LTI integration guide missing: docs/integrations/LTI.md"
fi

# ── Check 6: LTI passport / configuration pattern documented ─────────────────
section "LTI passport and LTI 1.3 configuration pattern"

if [[ -f "${LTI_DOC}" ]]; then
  if grep -q "LTI Passport\|lti_passport\|LTI_PASSPORTS" "${LTI_DOC}"; then
    pass "LTI 1.1 passport configuration documented"
  else
    fail "LTI 1.1 passport configuration not found in LTI.md"
  fi

  if grep -q "LTI 1.3\|lti_consumer.*v1\|LtiConfiguration" "${LTI_DOC}"; then
    pass "LTI 1.3 configuration documented"
  else
    fail "LTI 1.3 configuration not documented in LTI.md"
  fi

  if grep -q "grade\|passback\|AGS\|Basic Outcomes" "${LTI_DOC}"; then
    pass "Grade passback configuration documented"
  else
    fail "Grade passback not documented in LTI.md"
  fi

  if grep -q "security\|key rotation\|TLS\|HTTPS" "${LTI_DOC}"; then
    pass "Security considerations documented in LTI.md"
  else
    fail "Security considerations not documented in LTI.md"
  fi
else
  skip "LTI.md missing — cannot verify documentation coverage"
fi

# ── Check 7: SAML keypair generation script ───────────────────────────────────
section "SAML keypair tooling"

SAML_KEYGEN="${REPO_ROOT}/scripts/tenants/generate-saml-keypair.sh"
if [[ -f "${SAML_KEYGEN}" ]]; then
  pass "SAML keypair generation script exists: scripts/tenants/generate-saml-keypair.sh"
  if [[ -x "${SAML_KEYGEN}" ]]; then
    pass "generate-saml-keypair.sh is executable"
  else
    fail "generate-saml-keypair.sh is not executable (run: chmod +x ${SAML_KEYGEN})"
  fi
else
  skip "SAML keypair script not found (scripts/tenants/generate-saml-keypair.sh) — may not be required yet"
fi

# ─────────────────────────────────────────────────────────────────────────────
# ONLINE CHECKS (require kubectl + network access)
# ─────────────────────────────────────────────────────────────────────────────
if [[ "${MODE}" == "online" ]]; then

  section "Live cluster: SAML SP secrets"

  if ! command -v kubectl &>/dev/null; then
    skip "kubectl not available — skipping live cluster checks"
  else
    if kubectl get secret enterprise-sso-secrets -n "${NAMESPACE}" &>/dev/null; then
      pass "enterprise-sso-secrets K8s secret exists in namespace ${NAMESPACE}"

      CERT_VAL="$(kubectl get secret enterprise-sso-secrets -n "${NAMESPACE}" \
        -o jsonpath='{.data.SAML_SP_PUBLIC_CERT}' 2>/dev/null | base64 -d || true)"
      if [[ -n "${CERT_VAL}" ]]; then
        pass "SAML_SP_PUBLIC_CERT has a non-empty value in the live secret"
      else
        fail "SAML_SP_PUBLIC_CERT is empty in enterprise-sso-secrets — ExternalSecret sync may have failed"
      fi

      KEY_VAL="$(kubectl get secret enterprise-sso-secrets -n "${NAMESPACE}" \
        -o jsonpath='{.data.SAML_SP_PRIVATE_KEY}' 2>/dev/null | base64 -d || true)"
      if [[ -n "${KEY_VAL}" ]]; then
        pass "SAML_SP_PRIVATE_KEY has a non-empty value in the live secret"
      else
        fail "SAML_SP_PRIVATE_KEY is empty in enterprise-sso-secrets — ExternalSecret sync may have failed"
      fi
    else
      fail "enterprise-sso-secrets not found in namespace ${NAMESPACE} (ExternalSecret may not have synced)"
    fi
  fi

  section "Live endpoints: SAML metadata"

  METADATA_URL="https://${LMS_DOMAIN}/auth/saml/metadata.xml"
  HTTP_CODE="$(curl -sS -o /dev/null -w '%{http_code}' \
    --connect-timeout 10 --max-time 20 "${METADATA_URL}" 2>/dev/null || echo "000")"
  if [[ "${HTTP_CODE}" == "200" ]]; then
    pass "SAML metadata endpoint returns 200: ${METADATA_URL}"
  elif [[ "${HTTP_CODE}" == "403" || "${HTTP_CODE}" == "404" ]]; then
    fail "SAML metadata endpoint returned ${HTTP_CODE}: ${METADATA_URL} — third_party_auth may not be enabled"
  else
    fail "SAML metadata endpoint returned unexpected ${HTTP_CODE}: ${METADATA_URL}"
  fi

  section "Live endpoints: LTI provider listing"

  LTI_API_URL="https://${LMS_DOMAIN}/api/lti_consumer/v1/lti/"
  HTTP_CODE="$(curl -sS -o /dev/null -w '%{http_code}' \
    --connect-timeout 10 --max-time 20 "${LTI_API_URL}" 2>/dev/null || echo "000")"
  if [[ "${HTTP_CODE}" =~ ^(200|401|403)$ ]]; then
    pass "LTI consumer API responds (HTTP ${HTTP_CODE}): ${LTI_API_URL}"
  else
    fail "LTI consumer API returned unexpected ${HTTP_CODE}: ${LTI_API_URL}"
  fi

  section "Live cluster: third_party_auth in LMS INSTALLED_APPS"

  if command -v kubectl &>/dev/null; then
    LMS_POD="$(kubectl get pods -n "${NAMESPACE}" \
      -l app.kubernetes.io/name=lms \
      --field-selector=status.phase=Running \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")"

    if [[ -n "${LMS_POD}" ]]; then
      TPA_CHECK="$(kubectl exec -n "${NAMESPACE}" "${LMS_POD}" -- \
        python3 -c "
from django.conf import settings
result = any('third_party_auth' in a for a in settings.INSTALLED_APPS)
print('ok' if result else 'missing')
" 2>/dev/null || echo "error")"
      if [[ "${TPA_CHECK}" == "ok" ]]; then
        pass "third_party_auth is in INSTALLED_APPS (verified in running LMS pod)"
      else
        fail "third_party_auth not in INSTALLED_APPS in running LMS pod (got: ${TPA_CHECK})"
      fi

      LTI_CHECK="$(kubectl exec -n "${NAMESPACE}" "${LMS_POD}" -- \
        python3 -c "
try:
    from lti_consumer.models import LtiConfiguration
    print('ok')
except ImportError:
    print('missing')
" 2>/dev/null || echo "error")"
      if [[ "${LTI_CHECK}" == "ok" ]]; then
        pass "lti_consumer XBlock is importable in running LMS pod"
      else
        fail "lti_consumer XBlock not importable in running LMS pod (got: ${LTI_CHECK})"
      fi
    else
      skip "No running LMS pod found — skipping live pod checks"
    fi
  else
    skip "kubectl not available — skipping live pod checks"
  fi

fi  # end --online

# ─────────────────────────────────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "========================================================"
echo "LTI + SAML Config Verification: ${MODE} mode"
echo -e "${GREEN}PASS${NC}: ${PASS}  ${RED}FAIL${NC}: ${FAIL}  ${YELLOW}SKIP${NC}: ${SKIP}"
echo "========================================================"

if [[ ${FAIL} -gt 0 ]]; then
  echo ""
  echo "Remediation hints:"
  echo "  - SAML ExternalSecret missing → check deploy/k8s/base/secrets/external-secrets.yaml"
  echo "  - SAML secrets empty on cluster → ArgoCD sync may be pending; check ESO status"
  echo "  - third_party_auth missing → verify production.py INSTALLED_APPS patch"
  echo "  - LTI doc missing → run: touch docs/integrations/LTI.md (see T035)"
  echo "  - Full guide: docs/integrations/LTI.md"
  exit 1
fi

exit 0
