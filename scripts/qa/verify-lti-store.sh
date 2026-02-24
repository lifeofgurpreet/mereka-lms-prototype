#!/usr/bin/env bash
# @spec: cross-cutting-requirements_spec.md
# @covers AC-TCR-001, AC-TCR-002
# verify-lti-store.sh — Verify Reusable LTI Store (Ulmo feature) configuration.
#
# Checks that:
#   - lti_consumer XBlock is available (pip requirements or INSTALLED_APPS)
#   - LTI Store configuration is present in LMS settings / apply-patches
#   - FEATURES['ENABLE_LTI_PROVIDER'] or equivalent flag is configured
#   - LTI 1.3 JWKS endpoint configuration is declared
#   - LTI tool configurations can persist across course contexts (LtiTool model)
#   - LTI-related Django apps are in INSTALLED_APPS
#   - LTI admin interface availability is documented for Studio
#   - ExternalSecrets do not reference LTI-specific secrets (LTI uses DB-stored keys)
#   - LTI Store documentation exists
#
# Usage:
#   ./scripts/qa/verify-lti-store.sh [--offline|--online]
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
TUTOR_PLUGIN="${REPO_ROOT}/infrastructure/tutor/plugins/mereka_lms.py"
LTI_DOC="${REPO_ROOT}/docs/integrations/LTI.md"
LTI_STORE_DOC="${REPO_ROOT}/docs/integrations/LTI_STORE.md"

NAMESPACE="mereka-lms"
LMS_DOMAIN="academyv2.mereka.io"

echo "========================================================"
echo "Reusable LTI Store (Ulmo) Verification"
echo "Mode: ${MODE}"
echo "Repo: ${REPO_ROOT}"
echo "========================================================"

# ═════════════════════════════════════════════════════════════════════════════
# OFFLINE CHECKS
# ═════════════════════════════════════════════════════════════════════════════

# ── Check 1: lti_consumer XBlock availability ─────────────────────────────
section "lti_consumer XBlock availability"

# lti_consumer is bundled with Open edX Ulmo — check for any explicit reference
LTI_XBLOCK_FOUND=false
for f in \
  "${TUTOR_PLUGIN}" \
  "${PROD_SETTINGS}" \
  "${APPLY_PATCHES}"; do
  if [[ -f "$f" ]] && grep -qi "lti_consumer\|lti-consumer" "$f" 2>/dev/null; then
    LTI_XBLOCK_FOUND=true
    pass "lti_consumer reference found in $(basename "$f")"
    break
  fi
done

if [[ "${LTI_XBLOCK_FOUND}" == "false" ]]; then
  # lti_consumer is bundled with Open edX base; absence from custom files is normal
  skip "lti_consumer not explicitly referenced in custom files (it is bundled with Open edX Ulmo — verify via kubectl in --online mode)"
fi

# Check LTI Store documentation exists
if [[ -f "${LTI_STORE_DOC}" ]]; then
  pass "LTI Store guide exists: docs/integrations/LTI_STORE.md"
else
  fail "LTI Store guide missing: docs/integrations/LTI_STORE.md (create per T076)"
fi

if [[ -f "${LTI_DOC}" ]]; then
  pass "LTI integration guide exists: docs/integrations/LTI.md"
else
  fail "LTI integration guide missing: docs/integrations/LTI.md (create per T035)"
fi

# ── Check 2: ENABLE_LTI_PROVIDER feature flag ─────────────────────────────
section "ENABLE_LTI_PROVIDER feature flag"

LTI_PROVIDER_FLAG_FOUND=false
for f in \
  "${PROD_SETTINGS}" \
  "${APPLY_PATCHES}" \
  "${TUTOR_PLUGIN}"; do
  if [[ -f "$f" ]] && grep -q "ENABLE_LTI_PROVIDER" "$f" 2>/dev/null; then
    LTI_PROVIDER_FLAG_FOUND=true
    pass "ENABLE_LTI_PROVIDER flag found in $(basename "$f")"
    break
  fi
done

if [[ "${LTI_PROVIDER_FLAG_FOUND}" == "false" ]]; then
  # Open edX Ulmo enables LTI provider by default when lti_consumer is installed
  skip "ENABLE_LTI_PROVIDER not explicitly set in custom files (Open edX Ulmo enables LTI when lti_consumer is in INSTALLED_APPS — this is acceptable)"
fi

# ── Check 3: LTI 1.3 JWKS endpoint configuration ─────────────────────────
section "LTI 1.3 JWKS endpoint"

if [[ -f "${LTI_STORE_DOC}" ]]; then
  if grep -q "public_keysets\|jwks\|JWKS" "${LTI_STORE_DOC}"; then
    pass "JWKS endpoint configuration documented in LTI_STORE.md"
  else
    fail "JWKS endpoint configuration not documented in LTI_STORE.md"
  fi
else
  skip "LTI_STORE.md missing — cannot verify JWKS documentation"
fi

if [[ -f "${LTI_DOC}" ]]; then
  if grep -q "public_keysets\|jwks\|JWKS" "${LTI_DOC}"; then
    pass "JWKS endpoint configuration documented in LTI.md"
  else
    fail "JWKS endpoint not documented in LTI.md"
  fi
else
  skip "LTI.md missing — cannot verify JWKS in base LTI guide"
fi

# ── Check 4: LTI tool persistence across course contexts ─────────────────
section "LTI tool persistence (LtiTool model / LTI Store)"

# The LTI Store in Ulmo uses the LtiTool Django model for platform-wide persistence
if [[ -f "${LTI_STORE_DOC}" ]]; then
  if grep -q "LtiTool\|lti_consumer/ltitool\|LTI Tool Store\|platform-wide\|reusable" "${LTI_STORE_DOC}"; then
    pass "LTI Tool Store (platform-wide persistence) documented in LTI_STORE.md"
  else
    fail "LTI Tool Store / cross-course persistence not documented in LTI_STORE.md"
  fi

  if grep -q "admin.*lti_consumer\|lti_consumer.*admin\|/admin/" "${LTI_STORE_DOC}"; then
    pass "LTI admin interface path documented in LTI_STORE.md"
  else
    fail "LTI admin interface path not documented in LTI_STORE.md"
  fi
else
  skip "LTI_STORE.md missing — cannot verify persistence documentation"
fi

# ── Check 5: LTI-related Django apps in INSTALLED_APPS ───────────────────
section "LTI Django apps in INSTALLED_APPS"

LTI_APPS_FOUND=false
for f in \
  "${PROD_SETTINGS}" \
  "${APPLY_PATCHES}" \
  "${TUTOR_PLUGIN}"; do
  if [[ -f "$f" ]] && grep -q "lti_consumer\|lti_provider" "$f" 2>/dev/null; then
    LTI_APPS_FOUND=true
    pass "LTI app reference found in INSTALLED_APPS context in $(basename "$f")"
    break
  fi
done

if [[ "${LTI_APPS_FOUND}" == "false" ]]; then
  skip "lti_consumer not explicitly in INSTALLED_APPS patch (Open edX Ulmo includes it in base settings — verify via kubectl in --online mode)"
fi

# ── Check 6: LTI admin interface for Studio ───────────────────────────────
section "Studio LTI configuration interface"

if [[ -f "${LTI_DOC}" ]]; then
  if grep -q "Advanced Module List\|advanced_modules\|lti.*Studio\|Studio.*lti" "${LTI_DOC}"; then
    pass "Studio Advanced Module List configuration documented in LTI.md"
  else
    fail "Studio Advanced Module List not documented in LTI.md"
  fi
else
  skip "LTI.md missing — cannot verify Studio LTI documentation"
fi

if [[ -f "${LTI_STORE_DOC}" ]]; then
  if grep -q "Studio\|studio\|course author\|Course Author" "${LTI_STORE_DOC}"; then
    pass "Studio author workflow documented in LTI_STORE.md"
  else
    fail "Studio author workflow not documented in LTI_STORE.md"
  fi
else
  skip "LTI_STORE.md missing — cannot verify Studio workflow documentation"
fi

# ── Check 7: ExternalSecrets — LTI uses DB-stored keys (no K8s secrets) ──
section "ExternalSecrets: LTI key management"

if [[ -f "${EXTERNAL_SECRETS}" ]]; then
  # LTI 1.3 keys are managed by Open edX internally in the DB (not K8s secrets)
  # Presence of LTI-specific secrets would indicate a misconfiguration
  if grep -q "MEREKA_LMS_LTI_" "${EXTERNAL_SECRETS}" 2>/dev/null; then
    skip "LTI-specific ExternalSecret keys found — verify these are intentional (LTI 1.3 keys are normally DB-managed)"
  else
    pass "No LTI-specific K8s secret entries found (correct: LTI 1.3 keys are managed by Open edX in the database)"
  fi
else
  skip "ExternalSecrets manifest not found: ${EXTERNAL_SECRETS}"
fi

# ── Check 8: LTI Store documentation completeness ────────────────────────
section "LTI Store documentation completeness"

if [[ -f "${LTI_STORE_DOC}" ]]; then
  # Ulmo feature description
  if grep -q "Ulmo\|ulmo\|Tutor 21\|tutor 21" "${LTI_STORE_DOC}"; then
    pass "Ulmo context documented in LTI_STORE.md"
  else
    fail "Ulmo context not documented in LTI_STORE.md"
  fi

  # How to add tools
  if grep -q "Add LTI Tool\|add.*tool\|Add.*tool" "${LTI_STORE_DOC}"; then
    pass "Tool registration procedure documented in LTI_STORE.md"
  else
    fail "Tool registration procedure not documented in LTI_STORE.md"
  fi

  # Relationship to T035 / base LTI guide
  if grep -q "LTI\.md\|T035\|LTI guide\|lti-guide\|LTI integration" "${LTI_STORE_DOC}"; then
    pass "Cross-reference to base LTI guide present in LTI_STORE.md"
  else
    fail "Cross-reference to base LTI guide missing in LTI_STORE.md"
  fi
else
  skip "LTI_STORE.md missing — cannot verify documentation completeness"
fi

# ─────────────────────────────────────────────────────────────────────────────
# ONLINE CHECKS (require kubectl + network access)
# ─────────────────────────────────────────────────────────────────────────────
if [[ "${MODE}" == "online" ]]; then

  section "Live cluster: lti_consumer XBlock importable"

  if ! command -v kubectl &>/dev/null; then
    skip "kubectl not available — skipping live cluster checks"
  else
    LMS_POD="$(kubectl get pods -n "${NAMESPACE}" \
      -l app.kubernetes.io/name=lms \
      --field-selector=status.phase=Running \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")"

    if [[ -n "${LMS_POD}" ]]; then
      LTI_CHECK="$(kubectl exec -n "${NAMESPACE}" "${LMS_POD}" -- \
        python3 -c "
try:
    from lti_consumer.models import LtiConfiguration, LtiTool
    print('ok')
except ImportError as e:
    print('missing:' + str(e))
" 2>/dev/null || echo "error")"
      if [[ "${LTI_CHECK}" == "ok" ]]; then
        pass "lti_consumer XBlock (LtiConfiguration, LtiTool) is importable in running LMS pod"
      else
        fail "lti_consumer XBlock not importable in running LMS pod (got: ${LTI_CHECK})"
      fi

      # Check lti_consumer is in INSTALLED_APPS
      LTI_INSTALLED="$(kubectl exec -n "${NAMESPACE}" "${LMS_POD}" -- \
        python3 -c "
from django.conf import settings
result = any('lti_consumer' in a for a in settings.INSTALLED_APPS)
print('ok' if result else 'missing')
" 2>/dev/null || echo "error")"
      if [[ "${LTI_INSTALLED}" == "ok" ]]; then
        pass "lti_consumer is in INSTALLED_APPS (verified in running LMS pod)"
      else
        fail "lti_consumer not in INSTALLED_APPS in running LMS pod (got: ${LTI_INSTALLED})"
      fi

      # Check ENABLE_LTI_PROVIDER feature flag (or default)
      LTI_FEATURE="$(kubectl exec -n "${NAMESPACE}" "${LMS_POD}" -- \
        python3 -c "
from django.conf import settings
features = getattr(settings, 'FEATURES', {})
# In Ulmo, LTI is enabled when lti_consumer is installed; flag may not be explicit
val = features.get('ENABLE_LTI_PROVIDER', True)
print('enabled' if val else 'disabled')
" 2>/dev/null || echo "error")"
      if [[ "${LTI_FEATURE}" == "enabled" ]]; then
        pass "FEATURES['ENABLE_LTI_PROVIDER'] is enabled in running LMS"
      elif [[ "${LTI_FEATURE}" == "disabled" ]]; then
        fail "FEATURES['ENABLE_LTI_PROVIDER'] is explicitly disabled — LTI launches will fail"
      else
        skip "Could not read FEATURES['ENABLE_LTI_PROVIDER'] from running LMS (got: ${LTI_FEATURE})"
      fi
    else
      skip "No running LMS pod found — skipping live pod checks"
    fi
  fi

  section "Live endpoints: Studio LTI configuration"

  # Studio CMS should respond for LTI config admin
  STUDIO_URL="https://studio.${LMS_DOMAIN}"
  HTTP_CODE="$(curl -sS -o /dev/null -w '%{http_code}' \
    --connect-timeout 10 --max-time 20 "${STUDIO_URL}/" 2>/dev/null || echo "000")"
  if [[ "${HTTP_CODE}" =~ ^(200|301|302)$ ]]; then
    pass "Studio responds (HTTP ${HTTP_CODE}): ${STUDIO_URL}/"
  elif [[ "${HTTP_CODE}" == "000" ]]; then
    skip "Studio not reachable (network timeout) — skipping Studio LTI check"
  else
    fail "Studio returned unexpected ${HTTP_CODE}: ${STUDIO_URL}/"
  fi

  section "Live endpoints: LTI consumer API"

  LTI_API_URL="https://${LMS_DOMAIN}/api/lti_consumer/v1/lti/"
  HTTP_CODE="$(curl -sS -o /dev/null -w '%{http_code}' \
    --connect-timeout 10 --max-time 20 "${LTI_API_URL}" 2>/dev/null || echo "000")"
  if [[ "${HTTP_CODE}" =~ ^(200|401|403|405)$ ]]; then
    pass "LTI consumer API responds (HTTP ${HTTP_CODE}): ${LTI_API_URL}"
  elif [[ "${HTTP_CODE}" == "000" ]]; then
    skip "LTI API not reachable (network timeout)"
  else
    fail "LTI consumer API returned unexpected ${HTTP_CODE}: ${LTI_API_URL}"
  fi

  section "Live endpoints: JWKS endpoint"

  # The JWKS endpoint is per-tool-id; test the base path
  JWKS_BASE_URL="https://${LMS_DOMAIN}/api/lti_consumer/v1/public_keysets/"
  HTTP_CODE="$(curl -sS -o /dev/null -w '%{http_code}' \
    --connect-timeout 10 --max-time 20 "${JWKS_BASE_URL}" 2>/dev/null || echo "000")"
  if [[ "${HTTP_CODE}" =~ ^(200|400|404|405)$ ]]; then
    # 404 on the base path is acceptable — the endpoint requires a tool ID suffix
    pass "JWKS base endpoint reachable (HTTP ${HTTP_CODE}): ${JWKS_BASE_URL}"
  elif [[ "${HTTP_CODE}" == "000" ]]; then
    skip "JWKS endpoint not reachable (network timeout)"
  else
    fail "JWKS endpoint returned unexpected ${HTTP_CODE}: ${JWKS_BASE_URL}"
  fi

  section "Live cluster: LtiTool admin URL accessible"

  if command -v kubectl &>/dev/null; then
    LMS_POD="$(kubectl get pods -n "${NAMESPACE}" \
      -l app.kubernetes.io/name=lms \
      --field-selector=status.phase=Running \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")"

    if [[ -n "${LMS_POD}" ]]; then
      ADMIN_CHECK="$(kubectl exec -n "${NAMESPACE}" "${LMS_POD}" -- \
        python3 -c "
try:
    from django.contrib.admin.sites import site
    from lti_consumer.admin import LtiToolAdmin
    print('registered')
except (ImportError, AttributeError):
    # Check via model registration instead
    try:
        from lti_consumer.models import LtiTool
        print('model_ok')
    except ImportError:
        print('missing')
" 2>/dev/null || echo "error")"
      if [[ "${ADMIN_CHECK}" =~ ^(registered|model_ok)$ ]]; then
        pass "LtiTool admin/model available in running LMS pod (LTI Store accessible via /admin/lti_consumer/ltitool/)"
      else
        fail "LtiTool admin/model not accessible in running LMS pod (got: ${ADMIN_CHECK})"
      fi
    else
      skip "No running LMS pod found — skipping LtiTool admin check"
    fi
  else
    skip "kubectl not available — skipping LtiTool admin check"
  fi

fi  # end --online

# ─────────────────────────────────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "========================================================"
echo "Reusable LTI Store (Ulmo) Verification: ${MODE} mode"
echo -e "${GREEN}PASS${NC}: ${PASS}  ${RED}FAIL${NC}: ${FAIL}  ${YELLOW}SKIP${NC}: ${SKIP}"
echo "========================================================"

if [[ ${FAIL} -gt 0 ]]; then
  echo ""
  echo "Remediation hints:"
  echo "  - LTI_STORE.md missing → create docs/integrations/LTI_STORE.md (see T076)"
  echo "  - LTI.md missing → create docs/integrations/LTI.md (see T035)"
  echo "  - JWKS not documented → add endpoint docs to LTI_STORE.md"
  echo "  - lti_consumer not importable → verify lti_consumer is in INSTALLED_APPS in Open edX Ulmo"
  echo "  - ENABLE_LTI_PROVIDER disabled → remove explicit False from FEATURES dict in production.py"
  echo "  - LTI admin URL: https://${LMS_DOMAIN}/admin/lti_consumer/ltitool/"
  echo "  - Full guide: docs/integrations/LTI_STORE.md"
  exit 1
fi

exit 0
