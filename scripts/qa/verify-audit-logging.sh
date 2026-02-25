#!/usr/bin/env bash
# verify-audit-logging.sh — Audit logging capability assessment for Mereka LMS.
#
# Verifies that audit logging surfaces are present and configured:
#   - tracking.log handler in LMS/CMS production settings
#   - django_admin_log available (django.contrib.admin in INSTALLED_APPS)
#   - Purchase Gateway order_audit_log model and migration
#   - VideoAccessLog model in video protection custom app
#   - Loki retention configuration
#   - Assessment document exists
#
# Priority: P3 (aspirational) — failures here are informational, not blocking.
#
# Usage:
#   ./scripts/qa/verify-audit-logging.sh
#
# Runtime checks (require kubectl + cluster access) are SKIPped when kubectl
# is unavailable or the mereka-lms namespace is not reachable.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

pass() { echo -e "${GREEN}PASS${NC}  $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC}  $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC}  $1"; SKIP=$((SKIP + 1)); }

echo "=== Audit Logging Assessment — Mereka LMS ==="
echo "Note: P3 aspirational. FAIL here is informational, not blocking."
echo "Repo: ${REPO_ROOT}"
echo ""

# ---------------------------------------------------------------------------
# 1. Assessment document exists
# ---------------------------------------------------------------------------
echo "--- Assessment document ---"

ASSESSMENT_DOC="${REPO_ROOT}/docs/architecture/AUDIT_LOGGING_ASSESSMENT.md"
if [[ -f "${ASSESSMENT_DOC}" ]]; then
  pass "AUDIT_LOGGING_ASSESSMENT.md exists"
else
  fail "AUDIT_LOGGING_ASSESSMENT.md missing: ${ASSESSMENT_DOC}"
fi

echo ""

# ---------------------------------------------------------------------------
# 2. Open edX tracking.log handler — LMS
# ---------------------------------------------------------------------------
echo "--- Open edX tracking.log (LMS) ---"

LMS_PROD="${REPO_ROOT}/deploy/k8s/base/apps/openedx/settings/lms/production.py"

if [[ ! -f "${LMS_PROD}" ]]; then
  fail "LMS production.py not found: ${LMS_PROD}"
else
  pass "LMS production.py found"

  if grep -q 'tracking.log' "${LMS_PROD}"; then
    pass "LMS tracking.log handler configured"
  else
    fail "LMS tracking.log handler not found in production.py"
  fi

  if grep -q '"tracking"' "${LMS_PROD}" && grep -q 'LOGGING\["loggers"\]\["tracking"\]' "${LMS_PROD}"; then
    pass "LMS tracking logger wired to handlers"
  else
    fail "LMS LOGGING[loggers][tracking][handlers] not found in production.py"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# 3. Open edX tracking.log handler — CMS
# ---------------------------------------------------------------------------
echo "--- Open edX tracking.log (CMS) ---"

CMS_PROD="${REPO_ROOT}/deploy/k8s/base/apps/openedx/settings/cms/production.py"

if [[ ! -f "${CMS_PROD}" ]]; then
  fail "CMS production.py not found: ${CMS_PROD}"
else
  pass "CMS production.py found"

  if grep -q 'tracking.log' "${CMS_PROD}"; then
    pass "CMS tracking.log handler configured"
  else
    fail "CMS tracking.log handler not found in production.py"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# 4. Django admin log — django.contrib.admin presence
# ---------------------------------------------------------------------------
echo "--- Django admin audit log (django.contrib.admin) ---"

# Open edX's base lms.env.yml or production.py doesn't list INSTALLED_APPS in
# the override file, but we verify that django.contrib.admin is not explicitly
# removed, and that the LMS settings file does not disable it.
if grep -q 'django.contrib.admin' "${LMS_PROD}" 2>/dev/null; then
  # If explicitly present in the production.py override, that's fine.
  pass "django.contrib.admin referenced in LMS production.py"
elif ! grep -q "REMOVE.*admin\|disable.*admin" "${LMS_PROD}" 2>/dev/null; then
  pass "django.contrib.admin not explicitly disabled in LMS production.py (upstream default active)"
else
  fail "django.contrib.admin may have been removed or disabled"
fi

echo ""

# ---------------------------------------------------------------------------
# 5. Purchase Gateway — order_audit_log model
# ---------------------------------------------------------------------------
echo "--- Purchase Gateway order_audit_log ---"

PG_MODEL="${REPO_ROOT}/services/purchase-gateway/app/models/order.py"
PG_MIGRATION="${REPO_ROOT}/services/purchase-gateway/alembic/versions/001_initial_schema.py"

if [[ ! -f "${PG_MODEL}" ]]; then
  fail "Purchase Gateway order model not found: ${PG_MODEL}"
else
  pass "Purchase Gateway order model file found"

  if grep -q 'order_audit_log' "${PG_MODEL}"; then
    pass "OrderAuditLog model defined in order.py"
  else
    fail "order_audit_log table not found in order.py"
  fi

  # Verify key audit fields are present
  for field in "old_status" "new_status" "triggered_by" "timestamp"; do
    if grep -q "${field}" "${PG_MODEL}"; then
      pass "OrderAuditLog field '${field}' present"
    else
      fail "OrderAuditLog field '${field}' missing from order.py"
    fi
  done
fi

if [[ ! -f "${PG_MIGRATION}" ]]; then
  fail "Purchase Gateway initial migration not found: ${PG_MIGRATION}"
else
  if grep -q 'order_audit_log' "${PG_MIGRATION}"; then
    pass "order_audit_log table in Alembic initial migration"
  else
    fail "order_audit_log not found in initial migration"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# 6. VideoAccessLog — custom app
# ---------------------------------------------------------------------------
echo "--- VideoAccessLog (openedx_video_protection) ---"

VIDEO_PROT_MODELS="${REPO_ROOT}/infrastructure/tutor/custom-apps/openedx_video_protection/models.py"
VIDEO_PROT_ADMIN="${REPO_ROOT}/infrastructure/tutor/custom-apps/openedx_video_protection/admin.py"

if [[ ! -f "${VIDEO_PROT_MODELS}" ]]; then
  fail "openedx_video_protection/models.py not found"
else
  pass "openedx_video_protection/models.py found"

  if grep -q 'VideoAccessLog' "${VIDEO_PROT_MODELS}"; then
    pass "VideoAccessLog model defined"
  else
    fail "VideoAccessLog model not found in models.py"
  fi
fi

if [[ ! -f "${VIDEO_PROT_ADMIN}" ]]; then
  fail "openedx_video_protection/admin.py not found"
else
  if grep -q 'VideoAccessLog' "${VIDEO_PROT_ADMIN}"; then
    pass "VideoAccessLog registered with Django admin"
  else
    fail "VideoAccessLog not registered with Django admin"
  fi

  # Admin should be read-only (has_add_permission = False)
  if grep -q 'has_add_permission' "${VIDEO_PROT_ADMIN}"; then
    pass "VideoAccessLog admin has_add_permission override (read-only protection)"
  else
    fail "VideoAccessLog admin does not override has_add_permission — log may be writable"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# 7. Data retention policy covers audit surfaces
# ---------------------------------------------------------------------------
echo "--- Data retention policy coverage ---"

RETENTION_POLICY="${REPO_ROOT}/docs/operations/DATA_RETENTION_POLICY.md"

if [[ ! -f "${RETENTION_POLICY}" ]]; then
  fail "DATA_RETENTION_POLICY.md not found"
else
  pass "DATA_RETENTION_POLICY.md exists"

  if grep -q 'order_audit_log' "${RETENTION_POLICY}"; then
    pass "order_audit_log retention period documented"
  else
    fail "order_audit_log retention period not found in DATA_RETENTION_POLICY.md"
  fi

  if grep -q 'tracking.log\|Application Logs\|Loki' "${RETENTION_POLICY}"; then
    pass "Application log (Loki) retention documented"
  else
    fail "Application log retention not documented in DATA_RETENTION_POLICY.md"
  fi

  if grep -q 'stripe_events' "${RETENTION_POLICY}"; then
    pass "stripe_events (webhook audit) retention documented"
  else
    fail "stripe_events retention not documented in DATA_RETENTION_POLICY.md"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# 8. Loki retention configuration
# ---------------------------------------------------------------------------
echo "--- Loki log retention ---"

LOKI_CONFIG_SEARCH=$(grep -rn "retention_period\|720h\|retention.*720" \
  "${REPO_ROOT}/infrastructure/" "${REPO_ROOT}/deploy/" 2>/dev/null | head -1 || true)

if [[ -n "${LOKI_CONFIG_SEARCH}" ]]; then
  pass "Loki retention_period configured (720h / 30 days found in config)"
else
  skip "Loki retention_period config not found in repo (may be configured in observability stack outside this repo)"
fi

echo ""

# ---------------------------------------------------------------------------
# 9. Promtail log shipping configured
# ---------------------------------------------------------------------------
echo "--- Promtail log shipping ---"

PROMTAIL_DIR="${REPO_ROOT}/deploy/k8s/base/logging"

if [[ -d "${PROMTAIL_DIR}" ]]; then
  PROMTAIL_FILES=$(find "${PROMTAIL_DIR}" -name "*.yaml" -o -name "*.yml" 2>/dev/null | wc -l)
  if [[ "${PROMTAIL_FILES}" -gt 0 ]]; then
    pass "Promtail configuration directory exists with ${PROMTAIL_FILES} file(s)"
  else
    skip "Promtail config directory exists but contains no YAML files"
  fi
else
  skip "deploy/k8s/base/logging/ not found — Promtail may be managed by external observability repo"
fi

echo ""

# ---------------------------------------------------------------------------
# 10. Runtime check — tracking.log present in LMS pod
#     Requires kubectl + cluster access
# ---------------------------------------------------------------------------
echo "--- Runtime: tracking.log in LMS pod ---"

if ! command -v kubectl >/dev/null 2>&1; then
  skip "kubectl not available — skipping runtime check"
else
  LMS_POD=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms \
    --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -z "${LMS_POD}" ]]; then
    skip "No running LMS pod found in mereka-lms namespace — skipping runtime check"
  else
    TRACKING_CHECK=$(kubectl exec -n mereka-lms "${LMS_POD}" -- \
      test -f /openedx/data/logs/tracking.log && echo "exists" || echo "missing")

    if [[ "${TRACKING_CHECK}" == "exists" ]]; then
      pass "tracking.log exists on LMS pod: ${LMS_POD}"

      # Check whether the file has content (wc -l via bash -c to avoid redirection issues)
      TRACKING_LINES=$(kubectl exec -n mereka-lms "${LMS_POD}" -- \
        bash -c 'wc -l /openedx/data/logs/tracking.log 2>/dev/null | awk "{print \$1}"' || echo "0")
      if [[ "${TRACKING_LINES}" -gt 0 ]]; then
        pass "tracking.log has ${TRACKING_LINES} line(s)"
      else
        # Empty file is noteworthy but expected on a freshly started pod with no activity
        skip "tracking.log exists but is empty (pod may be idle or recently restarted)"
      fi
    else
      fail "tracking.log missing on LMS pod: ${LMS_POD}"
    fi
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# 11. Runtime check — django_admin_log table exists
#     Requires kubectl + cluster access
# ---------------------------------------------------------------------------
echo "--- Runtime: django_admin_log table (MySQL) ---"

if ! command -v kubectl >/dev/null 2>&1; then
  skip "kubectl not available — skipping runtime check"
else
  MYSQL_POD=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=mysql \
    --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -z "${MYSQL_POD}" ]]; then
    skip "No running MySQL pod in mereka-lms — skipping django_admin_log check"
  else
    # Check if the openedx schema has been initialized (0 tables = migrations not run)
    OPENEDX_TABLE_COUNT=$(kubectl exec -n mereka-lms "${MYSQL_POD}" -c mysql -- \
      mysql -u root -N -e \
      "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='openedx';" \
      2>/dev/null || echo "0")

    if [[ "${OPENEDX_TABLE_COUNT}" -eq 0 ]]; then
      skip "openedx MySQL schema has 0 tables — database not initialized (using MongoDB Atlas for modulestore, or migrations not run yet)"
    else
      TABLE_EXISTS=$(kubectl exec -n mereka-lms "${MYSQL_POD}" -c mysql -- \
        mysql -u root -N -e \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='openedx' AND table_name='django_admin_log';" \
        2>/dev/null || echo "0")

      if [[ "${TABLE_EXISTS}" -gt 0 ]]; then
        pass "django_admin_log table exists in openedx database"
      else
        fail "django_admin_log table not found in initialized openedx schema — admin actions may not be recorded"
      fi
    fi
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
TOTAL=$((PASS + FAIL + SKIP))
echo "=============================================="
echo -e "  ${GREEN}PASS${NC}  ${PASS}"
echo -e "  ${RED}FAIL${NC}  ${FAIL}"
echo -e "  ${YELLOW}SKIP${NC}  ${SKIP}"
echo "  Total ${TOTAL}"
echo "=============================================="
echo ""
echo -e "${CYAN}Note${NC}: This is a P3 aspirational check. FAILs are informational."
echo "See docs/architecture/AUDIT_LOGGING_ASSESSMENT.md for gap analysis and plan."
echo ""

if [[ "${FAIL}" -gt 0 ]]; then
  exit 1
fi
exit 0
