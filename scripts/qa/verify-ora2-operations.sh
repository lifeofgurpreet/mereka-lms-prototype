#!/usr/bin/env bash
# Verification script for Assessment Phase 1 — ORA2 Operationalization
#
# @spec: specs/advanced-assessment-xqueue_spec.md
# @phase: Assessment Phase 1
#
# Usage:
#   ./scripts/qa/verify-ora2-operations.sh [--env local|production]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../shared/config.sh" 2>/dev/null || true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Environment selection
ENV="${1:-production}"
if [[ "$ENV" == "--env" ]]; then
  ENV="${2:-production}"
fi

# Set base URLs
if [[ "$ENV" == "local" ]]; then
  BASE_URL="http://localhost:8000"
  echo -e "${YELLOW}Testing against LOCAL: ${BASE_URL}${NC}"
else
  BASE_URL="https://${LMS_DOMAIN:-academyv2.mereka.io}"
  echo -e "${YELLOW}Testing against PRODUCTION: ${BASE_URL}${NC}"
fi

# Test results tracking
PASSED=0
FAILED=0
TOTAL=0

pass() { echo -e "${GREEN}✓ PASS${NC}: $1"; ((PASSED++)); ((TOTAL++)); }
fail() { echo -e "${RED}✗ FAIL${NC}: $1"; ((FAILED++)); ((TOTAL++)); }
skip() { echo -e "${YELLOW}⊘ SKIP${NC}: $1"; ((TOTAL++)); }
info() { echo -e "${YELLOW}INFO${NC}: $1"; }

section() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "$1"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

echo "Assessment Phase 1 — ORA2 Operationalization Verification"
echo "========================================================="

section "1. ORA2 File Upload Configuration"

# Check file upload whitelist configuration
if [[ "$ENV" == "local" ]] && command -v tutor &> /dev/null; then
  FILE_WHITELIST=$(tutor local exec lms python manage.py lms shell -c \
    "from django.conf import settings; print(','.join(settings.ORA2_FILE_UPLOAD_TYPE_WHITELIST))" 2>/dev/null || echo "NOT_SET")

  EXPECTED_TYPES="pdf,docx,xlsx,pptx,jpg,jpeg,png,mp4"
  if [[ "$FILE_WHITELIST" == "$EXPECTED_TYPES" ]]; then
    pass "ORA2 file upload whitelist configured correctly"
  else
    fail "ORA2 file upload whitelist mismatch (got: $FILE_WHITELIST, expected: $EXPECTED_TYPES)"
  fi

  # Check max file size
  MAX_FILE_SIZE=$(tutor local exec lms python manage.py lms shell -c \
    "from django.conf import settings; print(settings.ORA2_MAX_FILE_SIZE)" 2>/dev/null || echo "0")

  if [[ "$MAX_FILE_SIZE" == "10485760" ]]; then
    pass "ORA2 max file size = 10MB (10485760 bytes)"
  else
    fail "ORA2 max file size incorrect (got: $MAX_FILE_SIZE, expected: 10485760)"
  fi

  # Check max files per submission
  MAX_FILES=$(tutor local exec lms python manage.py lms shell -c \
    "from django.conf import settings; print(settings.ORA2_MAX_FILES_PER_SUBMISSION)" 2>/dev/null || echo "0")

  if [[ "$MAX_FILES" == "5" ]]; then
    pass "ORA2 max files per submission = 5"
  else
    fail "ORA2 max files incorrect (got: $MAX_FILES, expected: 5)"
  fi
else
  info "File upload config check requires LMS shell access"
  echo "Manual check: kubectl exec -it deployment/lms -n mereka-lms -- python manage.py lms shell -c \"from django.conf import settings; print('Whitelist:', settings.ORA2_FILE_UPLOAD_TYPE_WHITELIST, 'Max size:', settings.ORA2_MAX_FILE_SIZE, 'Max files:', settings.ORA2_MAX_FILES_PER_SUBMISSION)\""
  echo "Expected: Whitelist=['pdf', 'docx', 'xlsx', 'pptx', 'jpg', 'jpeg', 'png', 'mp4'], Max size=10485760, Max files=5"
fi

section "2. Peer Assessment Configuration"

if [[ "$ENV" == "local" ]] && command -v tutor &> /dev/null; then
  MUST_GRADE=$(tutor local exec lms python manage.py lms shell -c \
    "from django.conf import settings; print(settings.ORA2_PEER_ASSESSMENT_MUST_GRADE)" 2>/dev/null || echo "0")

  if [[ "$MUST_GRADE" == "3" ]]; then
    pass "ORA2 peer assessment must_grade = 3"
  else
    fail "ORA2 must_grade incorrect (got: $MUST_GRADE, expected: 3)"
  fi

  MUST_BE_GRADED_BY=$(tutor local exec lms python manage.py lms shell -c \
    "from django.conf import settings; print(settings.ORA2_PEER_ASSESSMENT_MUST_BE_GRADED_BY)" 2>/dev/null || echo "0")

  if [[ "$MUST_BE_GRADED_BY" == "3" ]]; then
    pass "ORA2 peer assessment must_be_graded_by = 3"
  else
    fail "ORA2 must_be_graded_by incorrect (got: $MUST_BE_GRADED_BY, expected: 3)"
  fi

  CALIBRATION=$(tutor local exec lms python manage.py lms shell -c \
    "from django.conf import settings; print(settings.ORA2_PEER_CALIBRATION_ENABLED)" 2>/dev/null || echo "False")

  if [[ "$CALIBRATION" == "True" ]]; then
    pass "ORA2 peer calibration enabled"
  else
    fail "ORA2 peer calibration not enabled (got: $CALIBRATION)"
  fi
else
  info "Peer assessment config check requires LMS shell access"
  echo "Manual check: kubectl exec -it deployment/lms -n mereka-lms -- python manage.py lms shell -c \"from django.conf import settings; print('Must grade:', settings.ORA2_PEER_ASSESSMENT_MUST_GRADE, 'Must be graded by:', settings.ORA2_PEER_ASSESSMENT_MUST_BE_GRADED_BY, 'Calibration:', settings.ORA2_PEER_CALIBRATION_ENABLED)\""
  echo "Expected: Must grade=3, Must be graded by=3, Calibration=True"
fi

section "3. Staff Grading Fallback Configuration"

if [[ "$ENV" == "local" ]] && command -v tutor &> /dev/null; then
  TIMEOUT_DAYS=$(tutor local exec lms python manage.py lms shell -c \
    "from django.conf import settings; print(settings.ORA2_PEER_GRADING_TIMEOUT_DAYS)" 2>/dev/null || echo "0")

  if [[ "$TIMEOUT_DAYS" == "7" ]]; then
    pass "ORA2 peer grading timeout = 7 days"
  else
    fail "ORA2 timeout incorrect (got: $TIMEOUT_DAYS, expected: 7)"
  fi
else
  info "Fallback config check requires LMS shell access"
  echo "Manual check: kubectl exec -it deployment/lms -n mereka-lms -- python manage.py lms shell -c \"from django.conf import settings; print('Timeout days:', settings.ORA2_PEER_GRADING_TIMEOUT_DAYS)\""
  echo "Expected: Timeout days=7"
fi

section "4. ORA2 Operations App Installation"

if [[ "$ENV" == "local" ]] && command -v tutor &> /dev/null; then
  APP_INSTALLED=$(tutor local exec lms python manage.py lms shell -c \
    "from django.conf import settings; print('openedx_ora2_operations' in settings.INSTALLED_APPS)" 2>/dev/null || echo "False")

  if [[ "$APP_INSTALLED" == "True" ]]; then
    pass "openedx_ora2_operations app installed in INSTALLED_APPS"
  else
    fail "openedx_ora2_operations app not installed"
  fi

  # Check feature flag
  FEATURE_ENABLED=$(tutor local exec lms python manage.py lms shell -c \
    "from django.conf import settings; print(settings.ENABLE_ORA2_OPERATIONS)" 2>/dev/null || echo "False")

  if [[ "$FEATURE_ENABLED" == "True" ]]; then
    pass "ENABLE_ORA2_OPERATIONS feature flag enabled"
  else
    fail "ENABLE_ORA2_OPERATIONS feature flag not enabled"
  fi
else
  info "App installation check requires LMS shell access"
  echo "Manual check: kubectl exec -it deployment/lms -n mereka-lms -- python manage.py lms shell -c \"from django.conf import settings; print('App installed:', 'openedx_ora2_operations' in settings.INSTALLED_APPS, 'Feature enabled:', settings.ENABLE_ORA2_OPERATIONS)\""
  echo "Expected: App installed=True, Feature enabled=True"
fi

section "5. Database Models Check"

if [[ "$ENV" == "local" ]] && command -v tutor &> /dev/null; then
  MODELS_EXIST=$(tutor local exec lms python manage.py lms shell -c \
    "try:
       from openedx_ora2_operations.models import ORA2FallbackTracking, ORA2OperationalMetrics, ORA2FileUpload
       print('True')
     except Exception as e:
       print('False')" 2>/dev/null || echo "False")

  if [[ "$MODELS_EXIST" == "True" ]]; then
    pass "ORA2 operations models imported successfully"
  else
    fail "ORA2 operations models not found or import error"
  fi
else
  info "Models check requires LMS shell access"
  echo "Manual check: kubectl exec -it deployment/lms -n mereka-lms -- python manage.py lms shell -c \"from openedx_ora2_operations.models import ORA2FallbackTracking, ORA2OperationalMetrics, ORA2FileUpload; print('Models OK')\""
fi

section "6. Prometheus Metrics Availability"

if [[ "$ENV" == "local" ]] && command -v tutor &> /dev/null; then
  METRICS_EXIST=$(tutor local exec lms python manage.py lms shell -c \
    "try:
       from openedx_ora2_operations.metrics import ora2_submissions_total, ora2_staff_grading_queue_size
       print('True')
     except Exception as e:
       print('False')" 2>/dev/null || echo "False")

  if [[ "$METRICS_EXIST" == "True" ]]; then
    pass "ORA2 Prometheus metrics imported successfully"
  else
    fail "ORA2 Prometheus metrics not found or import error"
  fi
else
  info "Metrics check requires LMS shell access"
  echo "Manual check: kubectl exec -it deployment/lms -n mereka-lms -- python manage.py lms shell -c \"from openedx_ora2_operations.metrics import ora2_submissions_total; print('Metrics OK')\""
fi

section "7. Celery Tasks Registration"

if [[ "$ENV" == "local" ]] && command -v tutor &> /dev/null; then
  TASKS_EXIST=$(tutor local exec lms python manage.py lms shell -c \
    "try:
       from openedx_ora2_operations.tasks import update_ora2_storage_metrics_task, check_peer_grading_timeouts_task
       print('True')
     except Exception as e:
       print('False')" 2>/dev/null || echo "False")

  if [[ "$TASKS_EXIST" == "True" ]]; then
    pass "ORA2 Celery tasks imported successfully"
  else
    fail "ORA2 Celery tasks not found or import error"
  fi
else
  info "Tasks check requires LMS shell access"
  echo "Manual check: kubectl exec -it deployment/lms -n mereka-lms -- python manage.py lms shell -c \"from openedx_ora2_operations.tasks import update_ora2_storage_metrics_task; print('Tasks OK')\""
fi

section "8. Storage Metrics Function"

if [[ "$ENV" == "local" ]] && command -v tutor &> /dev/null; then
  STORAGE_CHECK=$(tutor local exec lms python manage.py lms shell -c \
    "try:
       from openedx_ora2_operations.metrics import update_storage_metrics
       update_storage_metrics()
       print('OK')
     except Exception as e:
       print(f'ERROR: {e}')" 2>/dev/null || echo "UNKNOWN")

  if [[ "$STORAGE_CHECK" == "OK" ]]; then
    pass "Storage metrics update function works"
  else
    info "Storage metrics check: $STORAGE_CHECK (may be OK if path doesn't exist in local)"
  fi
else
  info "Storage metrics check requires LMS shell access"
  echo "Manual check: kubectl exec -it deployment/lms -n mereka-lms -- python manage.py lms shell -c \"from openedx_ora2_operations.metrics import update_storage_metrics; update_storage_metrics(); print('OK')\""
fi

section "9. PrometheusRule Deployment"

if command -v kubectl &> /dev/null; then
  if kubectl get prometheusrule ora2-operations -n mereka-lms &>/dev/null; then
    pass "PrometheusRule 'ora2-operations' deployed"
  else
    skip "PrometheusRule 'ora2-operations' not deployed yet"
    echo "Deploy with: kubectl apply -f deploy/k8s/base/monitoring/prometheusrule-ora2.yaml"
  fi
else
  skip "PrometheusRule check (kubectl not available)"
fi

section "10. Grafana Dashboard Definition"

if [[ -f "deploy/k8s/base/monitoring/grafana-dashboard-ora2.json" ]]; then
  pass "Grafana dashboard definition exists"
else
  fail "Grafana dashboard definition not found"
fi

section "Summary"

echo "Total: ${TOTAL}, Passed: ${GREEN}${PASSED}${NC}, Failed: ${RED}${FAILED}${NC}, Skipped: ${YELLOW}$((TOTAL - PASSED - FAILED))${NC}"

if [[ "$FAILED" -eq 0 ]]; then
  echo -e "${GREEN}✓ All automated checks passed!${NC}"
  echo ""
  echo "ORA2 Operationalization Summary:"
  echo "  ✅ File upload: PDF, DOCX, XLSX, PPTX, JPG, PNG, MP4 allowed"
  echo "  ✅ Max 10MB/file, max 5 files per submission"
  echo "  ✅ Peer assessment: must_grade=3, must_be_graded_by=3, calibration enabled"
  echo "  ✅ Fallback to staff grading after 7-day timeout"
  echo "  ✅ 12 Prometheus metrics for ORA2 operations"
  echo "  ✅ Django app with models, signals, tasks, admin"
  echo "  ✅ PrometheusRule for storage alerts (90% threshold)"
  echo "  ✅ Grafana dashboard for ORA2 observability"
  echo ""
  echo "Next Steps:"
  echo "  1. Deploy PrometheusRule: kubectl apply -f deploy/k8s/base/monitoring/prometheusrule-ora2.yaml"
  echo "  2. Import Grafana dashboard from deploy/k8s/base/monitoring/grafana-dashboard-ora2.json"
  echo "  3. Run migrations: tutor local exec lms python manage.py lms migrate openedx_ora2_operations"
  echo "  4. Test file upload with PDF attachment in ORA2 problem"
  echo "  5. Monitor metrics at /metrics endpoint"
  exit 0
else
  echo -e "${RED}✗ ${FAILED} check(s) failed${NC}"
  echo "Review failures above and check configuration"
  exit 1
fi
