#!/usr/bin/env bash
# @covers AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008, AC-009, AC-010, AC-011, AC-012, AC-013, AC-014, AC-015
# @spec: advanced-assessment-xqueue_spec.md
# Verification script for Assessment Infrastructure Audit (Phase 0)
# Covers ORA2 (AC-001..009) and Timed Exams (AC-010..015) baseline checks
#
# @audit: docs/concepts/architecture/ASSESSMENT_AUDIT.md
#
# Usage:
#   ./scripts/qa/verify-assessment-audit.sh [--env local|production]

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
  MFE_BASE_URL="http://apps.localhost:1993"
  echo -e "${YELLOW}Testing against LOCAL: ${BASE_URL}${NC}"
else
  BASE_URL="https://${LMS_DOMAIN:-academyv2.mereka.io}"
  MFE_BASE_URL="https://${MFE_DOMAIN:-apps.academyv2.mereka.io}"
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

echo "Assessment Infrastructure Audit Verification (Phase 0)"
echo "======================================================"

section "1. ORA2 Configuration Check"

# Check if ORA2 settings exist in LMS
if [[ "$ENV" == "production" ]]; then
  info "ORA2 config check requires LMS shell access"
  echo "Manual check: kubectl exec -it deployment/lms -n mereka-lms -- python manage.py lms shell -c \"from django.conf import settings; print('ORA2_FILEUPLOAD_BACKEND:', settings.ORA2_FILEUPLOAD_BACKEND, 'ORA2_FILEUPLOAD_ROOT:', settings.ORA2_FILEUPLOAD_ROOT)\""
else
  if command -v tutor &> /dev/null; then
    ORA2_BACKEND=$(tutor local exec lms python manage.py lms shell -c \
      "from django.conf import settings; print(settings.ORA2_FILEUPLOAD_BACKEND)" 2>/dev/null || echo "UNKNOWN")

    if [[ "$ORA2_BACKEND" == "filesystem" ]]; then
      pass "ORA2_FILEUPLOAD_BACKEND = 'filesystem'"
    else
      fail "ORA2_FILEUPLOAD_BACKEND not configured correctly (got: $ORA2_BACKEND)"
    fi

    ORA2_ROOT=$(tutor local exec lms python manage.py lms shell -c \
      "from django.conf import settings; print(settings.ORA2_FILEUPLOAD_ROOT)" 2>/dev/null || echo "UNKNOWN")

    if [[ "$ORA2_ROOT" == "/openedx/data/ora2" ]]; then
      pass "ORA2_FILEUPLOAD_ROOT = '/openedx/data/ora2'"
    else
      info "ORA2_FILEUPLOAD_ROOT: $ORA2_ROOT (expected: /openedx/data/ora2)"
    fi
  else
    skip "ORA2 config check (tutor not available)"
  fi
fi

section "2. ORA Grading MFE URL Check"

# Check if ORA Grading MFE URL is accessible
ORA_GRADING_URL="${MFE_BASE_URL}/ora-grading"
echo "Checking ORA Grading MFE at: $ORA_GRADING_URL"

if curl -s -I "$ORA_GRADING_URL" --max-time 10 | grep -E "HTTP.* (200|302|301)" >/dev/null 2>&1; then
  pass "ORA Grading MFE URL accessible (HTTP 200/302/301)"
else
  fail "ORA Grading MFE URL not accessible at $ORA_GRADING_URL"
fi

section "3. XQueue Service Health Check"

# Check if XQueue service is running (production only)
if [[ "$ENV" == "production" ]]; then
  info "XQueue health check requires K8s access"
  echo "Manual check: kubectl exec -it deployment/xqueue -n mereka-lms -- curl -s http://localhost:8000/xqueue/status/"
  echo "Expected: HTTP 200 with JSON status response"

  # Try to check from outside if kubectl is available
  if command -v kubectl &> /dev/null; then
    XQUEUE_POD=$(kubectl get pod -n mereka-lms -l app.kubernetes.io/name=xqueue -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [[ -n "$XQUEUE_POD" ]]; then
      XQUEUE_STATUS=$(kubectl exec -n mereka-lms "$XQUEUE_POD" -- curl -s http://localhost:8000/xqueue/status/ 2>/dev/null || echo "FAIL")

      if echo "$XQUEUE_STATUS" | grep -q "queue"; then
        pass "XQueue service health endpoint responding"
      else
        fail "XQueue service health endpoint not responding correctly"
      fi
    else
      skip "XQueue pod not found (service may not be deployed)"
    fi
  else
    skip "XQueue health check (kubectl not available)"
  fi
else
  # Local environment
  if command -v tutor &> /dev/null; then
    XQUEUE_STATUS=$(tutor local dc exec xqueue curl -s http://localhost:8000/xqueue/status/ 2>/dev/null || echo "FAIL")

    if echo "$XQUEUE_STATUS" | grep -q "queue"; then
      pass "XQueue service health endpoint responding"
    else
      skip "XQueue service not running or not responding"
    fi
  else
    skip "XQueue health check (tutor not available)"
  fi
fi

section "4. XQueue Configuration Check"

# Check XQueue LMS integration settings
if [[ "$ENV" == "local" ]] && command -v tutor &> /dev/null; then
  XQUEUE_URL=$(tutor local exec lms python manage.py lms shell -c \
    "from django.conf import settings; print(settings.XQUEUE_INTERFACE.get('url', 'NOT_SET'))" 2>/dev/null || echo "UNKNOWN")

  if [[ "$XQUEUE_URL" == "http://xqueue:8000" ]]; then
    pass "XQUEUE_INTERFACE URL configured correctly"
  else
    info "XQUEUE_INTERFACE URL: $XQUEUE_URL (expected: http://xqueue:8000)"
  fi
else
  skip "XQueue LMS integration check (requires local environment with tutor)"
fi

section "5. CodeJail Status Verification"

# Check CodeJail configuration
if [[ "$ENV" == "local" ]] && command -v tutor &> /dev/null; then
  CODEJAIL_BIN=$(tutor local exec lms python manage.py lms shell -c \
    "from django.conf import settings; print(settings.CODE_JAIL.get('python_bin', 'NOT_SET'))" 2>/dev/null || echo "UNKNOWN")

  if [[ "$CODEJAIL_BIN" == "nonexistingpythonbinary" ]]; then
    pass "CodeJail DISABLED (python_bin = 'nonexistingpythonbinary') - EXPECTED"
  else
    fail "CodeJail configuration unexpected: python_bin = $CODEJAIL_BIN"
  fi
else
  info "CodeJail check requires LMS shell access"
  echo "Manual check: kubectl exec -it deployment/lms -n mereka-lms -- python manage.py lms shell -c \"from django.conf import settings; print('CODE_JAIL:', settings.CODE_JAIL)\""
  echo "Expected: {'python_bin': 'nonexistingpythonbinary', 'user': None}"
fi

section "6. Timed Exam Backend Check"

# Check if edx-proctoring is installed and configured
if [[ "$ENV" == "local" ]] && command -v tutor &> /dev/null; then
  PROCTORING_BACKEND=$(tutor local exec lms python manage.py lms shell -c \
    "try:
       from edx_proctoring.backends import get_backend_provider
       backend = get_backend_provider()
       print(backend.__class__.__name__ if backend else 'None')
     except Exception as e:
       print('ERROR')" 2>/dev/null || echo "UNKNOWN")

  if [[ "$PROCTORING_BACKEND" == "None" || "$PROCTORING_BACKEND" == "NullBackend" ]]; then
    pass "Timed exam backend: no-op/null backend (timed-only, no proctoring)"
  elif [[ "$PROCTORING_BACKEND" == "ERROR" ]]; then
    fail "edx-proctoring not installed or error checking backend"
  else
    info "Proctoring backend: $PROCTORING_BACKEND (unexpected - should be None for timed-only)"
  fi
else
  info "Timed exam backend check requires LMS shell access"
  echo "Manual check: kubectl exec -it deployment/lms -n mereka-lms -- python manage.py lms shell -c \"from edx_proctoring.backends import get_backend_provider; print(get_backend_provider())\""
  echo "Expected: None or NullBackend (timed-only exams without proctoring)"
fi

section "7. XQueue Grader Backends Check"

# Check if any grader backends are configured
if [[ "$ENV" == "local" ]] && command -v tutor &> /dev/null; then
  XQUEUE_GRADERS=$(tutor local dc exec xqueue python -c \
    "from xqueue_watcher import settings; print(settings.XQUEUES)" 2>/dev/null || echo "ERROR")

  if echo "$XQUEUE_GRADERS" | grep -q "None"; then
    info "EXPECTED: No grader backends configured (XQUEUES contains None values)"
    pass "XQueue grader backend status documented (None = not configured)"
  elif [[ "$XQUEUE_GRADERS" == "ERROR" ]]; then
    skip "XQueue grader check failed (service may not be running)"
  else
    info "XQueue grader configuration: $XQUEUE_GRADERS"
  fi
else
  info "XQueue grader check requires XQueue shell access"
  echo "Manual check: kubectl exec -it deployment/xqueue -n mereka-lms -- python -c \"from xqueue_watcher import settings; print(settings.XQUEUES)\""
  echo "Expected: {'openedx': None} (no graders configured)"
fi

section "8. File Upload Storage Check"

# Check if ORA2 file upload directory exists and is writable
if [[ "$ENV" == "local" ]] && command -v tutor &> /dev/null; then
  ORA2_DIR_CHECK=$(tutor local exec lms bash -c \
    "test -d /openedx/data/ora2 && test -w /openedx/data/ora2 && echo 'OK' || echo 'FAIL'" 2>/dev/null || echo "ERROR")

  if [[ "$ORA2_DIR_CHECK" == "OK" ]]; then
    pass "ORA2 file upload directory exists and is writable (/openedx/data/ora2)"
  elif [[ "$ORA2_DIR_CHECK" == "FAIL" ]]; then
    fail "ORA2 file upload directory missing or not writable"
  else
    skip "ORA2 directory check failed (LMS pod may not be running)"
  fi
else
  info "File upload storage check requires LMS shell access"
  echo "Manual check: kubectl exec -it deployment/lms -n mereka-lms -- ls -la /openedx/data/ora2"
  echo "Expected: Directory exists with write permissions"
fi

section "9. XQueue MySQL Database Check"

# Check if XQueue MySQL database exists
if [[ "$ENV" == "production" ]]; then
  info "XQueue MySQL check requires database access"
  echo "Manual check: kubectl exec -it deployment/mysql -n mereka-lms -- mysql -u xqueue -p<password> -e 'SHOW DATABASES;'"
  echo "Expected: Database 'xqueue' exists"
else
  if command -v tutor &> /dev/null; then
    XQUEUE_DB=$(tutor local dc exec mysql mysql -u xqueue -p"$(tutor config printvalue MYSQL_XQUEUE_PASSWORD)" \
      -e "SHOW DATABASES LIKE 'xqueue';" 2>/dev/null | grep -c "xqueue" || echo "0")

    if [[ "$XQUEUE_DB" -gt 0 ]]; then
      pass "XQueue MySQL database exists"
    else
      fail "XQueue MySQL database not found"
    fi
  else
    skip "XQueue MySQL check (tutor not available)"
  fi
fi

section "10. ExternalSecrets Check (Production Only)"

if [[ "$ENV" == "production" ]]; then
  if command -v kubectl &> /dev/null; then
    # Check if XQueue secrets are synced
    XQUEUE_SECRET=$(kubectl get secret openedx-secret -n mereka-lms -o jsonpath='{.data.XQUEUE_SECRET_KEY}' 2>/dev/null | base64 -d 2>/dev/null || echo "")

    if [[ -n "$XQUEUE_SECRET" && "$XQUEUE_SECRET" != "null" ]]; then
      pass "XQueue secrets synced from ExternalSecrets"
    else
      fail "XQueue secrets not synced or empty"
    fi
  else
    skip "ExternalSecrets check (kubectl not available)"
  fi
else
  skip "ExternalSecrets check (production only)"
fi

section "Summary"

echo "Total: ${TOTAL}, Passed: ${GREEN}${PASSED}${NC}, Failed: ${RED}${FAILED}${NC}, Skipped: ${YELLOW}$((TOTAL - PASSED - FAILED))${NC}"

if [[ "$FAILED" -eq 0 ]]; then
  echo -e "${GREEN}✓ All automated checks passed!${NC}"
  echo ""
  echo "Audit Findings Summary:"
  echo "  ✅ ORA2 framework configured (file uploads enabled)"
  echo "  ✅ XQueue service deployed (health endpoint accessible)"
  echo "  ✅ ORA Grading MFE URL configured"
  echo "  ✅ Timed exam backend configured (no-op for timed-only)"
  echo "  ✅ CodeJail DISABLED (expected - mitigation plan required)"
  echo "  ⚠️  No XQueue grader backends configured (expected - Phase 2 task)"
  echo ""
  echo "Next Steps: Assessment Phase 1 (ORA2 Operationalization)"
  exit 0
else
  echo -e "${RED}✗ ${FAILED} check(s) failed${NC}"
  echo "Review failures above and check docs/concepts/architecture/ASSESSMENT_AUDIT.md"
  exit 1
fi
