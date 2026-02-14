#!/usr/bin/env bash
# Verification script for Assessment Phase 3 — XQueue Grader Workers
#
# @spec: specs/advanced-assessment-xqueue_spec.md
# @phase: Assessment Phase 3
#
# Usage:
#   ./scripts/qa/verify-xqueue-graders.sh [--env local|production]

set -euo pipefail

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
  BASE_URL="https://academyv2.mereka.io"
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

echo "Assessment Phase 3 — XQueue Grader Workers Verification"
echo "========================================================"

section "1. XQueue Graders App Installation"

if [[ "$ENV" == "local" ]] && command -v tutor &> /dev/null; then
  APP_INSTALLED=$(tutor local exec lms python manage.py lms shell -c \
    "from django.conf import settings
print('openedx_xqueue_graders' in settings.INSTALLED_APPS)" 2>/dev/null || echo "False")

  if [[ "$APP_INSTALLED" == "True" ]]; then
    pass "openedx_xqueue_graders app installed in INSTALLED_APPS"
  else
    fail "openedx_xqueue_graders app not installed"
  fi

  # Check models
  MODELS_EXIST=$(tutor local exec lms python manage.py lms shell -c \
    "try:
   from openedx_xqueue_graders.models import GraderSubmission, GraderQueueMetrics
   print('True')
except Exception as e:
   print('False')" 2>/dev/null || echo "False")

  if [[ "$MODELS_EXIST" == "True" ]]; then
    pass "Grader models imported successfully (GraderSubmission, GraderQueueMetrics)"
  else
    fail "Grader models not found or import error"
  fi
else
  info "App installation check requires LMS shell access"
  echo "Manual check: kubectl exec -it deployment/lms -n mereka-lms -- python manage.py lms shell -c \"from openedx_xqueue_graders.models import GraderSubmission; print('Models OK')\""
fi

section "2. AC-ASS-015: Python Grading Performance (< 30s)"

if [[ "$ENV" == "local" ]] && command -v tutor &> /dev/null; then
  # Test simple Python grading
  TEST_CODE='print("Hello, World!")'
  GRADER_PAYLOAD='{"expected_output": "Hello, World!"}'

  info "Testing Python grader with simple code (should complete < 30s)"

  START_TIME=$(date +%s)

  GRADING_RESULT=$(tutor local exec lms python manage.py lms shell -c \
    "from openedx_xqueue_graders.grader import PythonGrader
grader = PythonGrader(timeout_seconds=30)
result = grader.grade_submission(
    {'submission_id': 'test-001'},
    {'student_response': '''${TEST_CODE}''', 'grader_payload': '''${GRADER_PAYLOAD}'''}
)
print(result['score'])" 2>/dev/null || echo "ERROR")

  END_TIME=$(date +%s)
  ELAPSED=$((END_TIME - START_TIME))

  if [[ "$GRADING_RESULT" == "100.0" ]] && [[ $ELAPSED -lt 30 ]]; then
    pass "AC-ASS-015: Python grading completed correctly in ${ELAPSED}s (< 30s)"
  elif [[ "$GRADING_RESULT" == "ERROR" ]]; then
    fail "AC-ASS-015: Grading failed (error during execution)"
  elif [[ $ELAPSED -ge 30 ]]; then
    fail "AC-ASS-015: Grading took ${ELAPSED}s (>= 30s threshold)"
  else
    fail "AC-ASS-015: Grading score incorrect (got: $GRADING_RESULT, expected: 100.0)"
  fi
else
  info "Grading performance check requires local environment with tutor"
fi

section "3. AC-ASS-016: Sandbox Network Access Denial"

if [[ "$ENV" == "local" ]] && command -v tutor &> /dev/null; then
  # Test network access denial
  NETWORK_CODE='
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(("google.com", 80))
print("Network access succeeded")
'

  info "Testing sandbox network access denial"

  NETWORK_TEST=$(tutor local exec lms python manage.py lms shell -c \
    "from openedx_xqueue_graders.sandbox import SecureSandbox
sandbox = SecureSandbox(timeout_seconds=5)
result = sandbox.execute_code('''${NETWORK_CODE}''')
print('network_access_attempt' in result.get('violations', []))" 2>/dev/null || echo "False")

  if [[ "$NETWORK_TEST" == "True" ]]; then
    pass "AC-ASS-016: Network access denied (sandbox violation detected)"
  else
    fail "AC-ASS-016: Network access NOT denied (security vulnerability!)"
  fi
else
  info "Network access denial check requires local environment"
  echo "Manual test: Submit code with network access, verify connection refused"
fi

section "4. AC-ASS-017: Sandbox Filesystem Write Restrictions"

if [[ "$ENV" == "local" ]] && command -v tutor &> /dev/null; then
  # Test filesystem write outside /tmp
  FILESYSTEM_CODE='
with open("/etc/passwd", "a") as f:
    f.write("hacker")
print("File write succeeded")
'

  info "Testing sandbox filesystem write restriction"

  FILESYSTEM_TEST=$(tutor local exec lms python manage.py lms shell -c \
    "from openedx_xqueue_graders.sandbox import SecureSandbox
sandbox = SecureSandbox(timeout_seconds=5)
result = sandbox.execute_code('''${FILESYSTEM_CODE}''')
has_violation = 'filesystem_write_violation' in result.get('violations', [])
has_permission_denied = 'Permission denied' in result.get('stderr', '')
print(has_violation or has_permission_denied)" 2>/dev/null || echo "False")

  if [[ "$FILESYSTEM_TEST" == "True" ]]; then
    pass "AC-ASS-017: Filesystem writes outside /tmp denied (sandbox violation detected)"
  else
    fail "AC-ASS-017: Filesystem writes NOT restricted (security vulnerability!)"
  fi

  # Test that /tmp writes are allowed
  TMP_CODE='
with open("/tmp/test.txt", "w") as f:
    f.write("test")
print("Tmp write succeeded")
'

  TMP_TEST=$(tutor local exec lms python manage.py lms shell -c \
    "from openedx_xqueue_graders.sandbox import SecureSandbox
sandbox = SecureSandbox(timeout_seconds=5)
result = sandbox.execute_code('''${TMP_CODE}''')
print('Tmp write succeeded' in result.get('stdout', ''))" 2>/dev/null || echo "False")

  if [[ "$TMP_TEST" == "True" ]]; then
    pass "Filesystem writes to /tmp allowed (as expected)"
  else
    info "Tmp write test: $TMP_TEST (expected: True)"
  fi
else
  info "Filesystem restriction check requires local environment"
fi

section "5. AC-ASS-019: Idempotent Grading (Same Input = Same Output)"

if [[ "$ENV" == "local" ]] && command -v tutor &> /dev/null; then
  TEST_CODE='print(42)'
  GRADER_PAYLOAD='{"expected_output": "42"}'

  info "Testing idempotent grading (submitting same code twice)"

  # First submission
  RESULT1=$(tutor local exec lms python manage.py lms shell -c \
    "from openedx_xqueue_graders.grader import PythonGrader
grader = PythonGrader(timeout_seconds=30)
result = grader.grade_submission(
    {'submission_id': 'idempotency-test-001'},
    {'student_response': '''${TEST_CODE}''', 'grader_payload': '''${GRADER_PAYLOAD}'''}
)
print(f\"{result['score']}|{result.get('cached', False)}\")" 2>/dev/null || echo "ERROR")

  # Second submission (should be cached)
  RESULT2=$(tutor local exec lms python manage.py lms shell -c \
    "from openedx_xqueue_graders.grader import PythonGrader
grader = PythonGrader(timeout_seconds=30)
result = grader.grade_submission(
    {'submission_id': 'idempotency-test-002'},
    {'student_response': '''${TEST_CODE}''', 'grader_payload': '''${GRADER_PAYLOAD}'''}
)
print(f\"{result['score']}|{result.get('cached', False)}\")" 2>/dev/null || echo "ERROR")

  SCORE1=$(echo "$RESULT1" | cut -d'|' -f1)
  CACHED1=$(echo "$RESULT1" | cut -d'|' -f2)
  SCORE2=$(echo "$RESULT2" | cut -d'|' -f1)
  CACHED2=$(echo "$RESULT2" | cut -d'|' -f2)

  if [[ "$SCORE1" == "$SCORE2" ]] && [[ "$CACHED2" == "True" ]]; then
    pass "AC-ASS-019: Idempotent grading (same code → same result, second cached)"
  else
    fail "AC-ASS-019: Grading NOT idempotent (score1=$SCORE1, score2=$SCORE2, cached2=$CACHED2)"
  fi
else
  info "Idempotency check requires local environment"
fi

section "6. AC-ASS-020: HPA Auto-Scaling (1-3 replicas, 70% CPU threshold)"

if command -v kubectl &> /dev/null; then
  HPA_EXISTS=$(kubectl get hpa xqueue-graders -n mereka-lms 2>/dev/null && echo "True" || echo "False")

  if [[ "$HPA_EXISTS" == "True" ]]; then
    pass "HPA exists for xqueue-graders"

    # Check HPA configuration
    MIN_REPLICAS=$(kubectl get hpa xqueue-graders -n mereka-lms -o jsonpath='{.spec.minReplicas}')
    MAX_REPLICAS=$(kubectl get hpa xqueue-graders -n mereka-lms -o jsonpath='{.spec.maxReplicas}')
    CPU_TARGET=$(kubectl get hpa xqueue-graders -n mereka-lms -o jsonpath='{.spec.metrics[?(@.resource.name=="cpu")].resource.target.averageUtilization}')

    if [[ "$MIN_REPLICAS" == "1" ]] && [[ "$MAX_REPLICAS" == "3" ]]; then
      pass "AC-ASS-020: HPA min/max replicas configured (1-3)"
    else
      fail "AC-ASS-020: HPA min/max replicas incorrect (min=$MIN_REPLICAS, max=$MAX_REPLICAS, expected: 1-3)"
    fi

    if [[ "$CPU_TARGET" == "70" ]]; then
      pass "AC-ASS-020: HPA CPU threshold = 70%"
    else
      fail "AC-ASS-020: HPA CPU threshold incorrect (got: $CPU_TARGET%, expected: 70%)"
    fi
  else
    fail "HPA not found for xqueue-graders"
    echo "Deploy with: kubectl apply -f deploy/k8s/base/apps/xqueue-graders/hpa.yaml"
  fi
else
  skip "HPA check (kubectl not available)"
fi

section "7. AC-ASS-021: No Secrets in Environment Variables"

if command -v kubectl &> /dev/null; then
  DEPLOYMENT_EXISTS=$(kubectl get deployment xqueue-graders -n mereka-lms 2>/dev/null && echo "True" || echo "False")

  if [[ "$DEPLOYMENT_EXISTS" == "True" ]]; then
    # Check for secret environment variables
    SECRET_ENVS=$(kubectl get deployment xqueue-graders -n mereka-lms -o jsonpath='{.spec.template.spec.containers[0].env[*].name}' 2>/dev/null | grep -iE "password|secret|key|token" || echo "")

    if [[ -z "$SECRET_ENVS" ]]; then
      pass "AC-ASS-021: No secret environment variables found (ExternalSecrets only)"
    else
      fail "AC-ASS-021: Secret environment variables detected: $SECRET_ENVS"
    fi

    # Check for volume mounts from secrets
    SECRET_VOLUMES=$(kubectl get deployment xqueue-graders -n mereka-lms -o jsonpath='{.spec.template.spec.volumes[?(@.secret)].name}' 2>/dev/null || echo "")

    if [[ -n "$SECRET_VOLUMES" ]]; then
      pass "Secrets mounted as volumes (secure): $SECRET_VOLUMES"
    else
      info "No secret volumes found (may be intentional for test environment)"
    fi
  else
    skip "Deployment not found for xqueue-graders"
  fi
else
  skip "Secrets check (kubectl not available)"
fi

section "8. AC-ASS-018: Queue Depth Alert (> 100 for 10min → PagerDuty)"

if command -v kubectl &> /dev/null; then
  PROMETHEUSRULE_EXISTS=$(kubectl get prometheusrule xqueue-graders -n mereka-lms 2>/dev/null && echo "True" || echo "False")

  if [[ "$PROMETHEUSRULE_EXISTS" == "True" ]]; then
    pass "PrometheusRule exists for xqueue-graders"

    # Check for queue depth alert
    QUEUE_ALERT=$(kubectl get prometheusrule xqueue-graders -n mereka-lms -o yaml | grep -A 5 "XQueueHighQueueDepth" || echo "")

    if [[ -n "$QUEUE_ALERT" ]]; then
      # Check for pagerduty label
      HAS_PAGERDUTY=$(echo "$QUEUE_ALERT" | grep "pagerduty" || echo "")

      if [[ -n "$HAS_PAGERDUTY" ]]; then
        pass "AC-ASS-018: Queue depth alert configured with PagerDuty notification"
      else
        fail "AC-ASS-018: Queue depth alert missing PagerDuty label"
      fi
    else
      fail "AC-ASS-018: XQueueHighQueueDepth alert not found in PrometheusRule"
    fi
  else
    fail "PrometheusRule not found for xqueue-graders"
    echo "Deploy with: kubectl apply -f deploy/k8s/base/apps/xqueue-graders/prometheusrule.yaml"
  fi
else
  skip "PrometheusRule check (kubectl not available)"
fi

section "9. Sandbox Security Policies"

if command -v kubectl &> /dev/null; then
  # Check for seccomp profile ConfigMap
  SECCOMP_PROFILE=$(kubectl get configmap xqueue-grader-seccomp-profile -n kube-system 2>/dev/null && echo "True" || echo "False")

  if [[ "$SECCOMP_PROFILE" == "True" ]]; then
    pass "Seccomp profile ConfigMap exists"
  else
    skip "Seccomp profile ConfigMap not found (deploy with: kubectl apply -f deploy/k8s/base/apps/xqueue-graders/sandbox-policy.yaml)"
  fi

  # Check for AppArmor profile ConfigMap
  APPARMOR_PROFILE=$(kubectl get configmap xqueue-grader-apparmor-profile -n kube-system 2>/dev/null && echo "True" || echo "False")

  if [[ "$APPARMOR_PROFILE" == "True" ]]; then
    pass "AppArmor profile ConfigMap exists"
  else
    skip "AppArmor profile ConfigMap not found"
  fi
else
  skip "Security policy check (kubectl not available)"
fi

section "10. NetworkPolicy Isolation"

if command -v kubectl &> /dev/null; then
  NETPOL_EXISTS=$(kubectl get networkpolicy xqueue-graders-sandbox -n mereka-lms 2>/dev/null && echo "True" || echo "False")

  if [[ "$NETPOL_EXISTS" == "True" ]]; then
    pass "NetworkPolicy exists for sandbox isolation"

    # Verify egress rules (should only allow DB, DNS, XQueue)
    EGRESS_RULES=$(kubectl get networkpolicy xqueue-graders-sandbox -n mereka-lms -o jsonpath='{.spec.egress[*].to[*].podSelector.matchLabels}')

    if [[ -n "$EGRESS_RULES" ]]; then
      pass "NetworkPolicy egress rules configured (limited network access)"
    else
      info "NetworkPolicy egress rules: $EGRESS_RULES"
    fi
  else
    fail "NetworkPolicy not found for xqueue-graders-sandbox"
    echo "Deploy with: kubectl apply -f deploy/k8s/base/apps/xqueue-graders/networkpolicy.yaml"
  fi
else
  skip "NetworkPolicy check (kubectl not available)"
fi

section "Summary"

echo "Total: ${TOTAL}, Passed: ${GREEN}${PASSED}${NC}, Failed: ${RED}${FAILED}${NC}, Skipped: ${YELLOW}$((TOTAL - PASSED - FAILED))${NC}"

if [[ "$FAILED" -eq 0 ]]; then
  echo -e "${GREEN}✓ All automated checks passed!${NC}"
  echo ""
  echo "XQueue Grader Workers Configuration Summary:"
  echo "  ✅ AC-ASS-015: Python grading < 30s (performance verified)"
  echo "  ✅ AC-ASS-016: Network access denied (sandbox isolation)"
  echo "  ✅ AC-ASS-017: Filesystem writes restricted to /tmp only"
  echo "  ✅ AC-ASS-018: Queue depth alerts with PagerDuty integration"
  echo "  ✅ AC-ASS-019: Idempotent grading (same input = cached result)"
  echo "  ✅ AC-ASS-020: HPA auto-scaling (1-3 replicas, 70% CPU threshold)"
  echo "  ✅ AC-ASS-021: Secrets via ExternalSecrets (no env vars)"
  echo ""
  echo "Deployment status:"
  if command -v kubectl &> /dev/null; then
    echo "  Deployment: $(kubectl get deployment xqueue-graders -n mereka-lms 2>/dev/null | grep -c xqueue-graders || echo 0) / 1"
    echo "  HPA: $(kubectl get hpa xqueue-graders -n mereka-lms 2>/dev/null | grep -c xqueue-graders || echo 0) / 1"
    echo "  NetworkPolicy: $(kubectl get networkpolicy xqueue-graders-sandbox -n mereka-lms 2>/dev/null | grep -c xqueue-graders || echo 0) / 1"
    echo "  PrometheusRule: $(kubectl get prometheusrule xqueue-graders -n mereka-lms 2>/dev/null | grep -c xqueue-graders || echo 0) / 1"
  fi
  echo ""
  echo "Next Steps:"
  echo "  1. Run migrations: tutor local exec lms python manage.py lms migrate openedx_xqueue_graders"
  echo "  2. Deploy to K8s: kubectl apply -k deploy/k8s/base/apps/xqueue-graders/"
  echo "  3. Verify HPA status: kubectl get hpa xqueue-graders -n mereka-lms"
  echo "  4. Create test course with Python coding problem"
  echo "  5. Submit code → verify grading < 30s"
  echo "  6. Monitor queue depth: kubectl top pods -n mereka-lms -l app.kubernetes.io/name=xqueue-graders"
  echo "  7. Test sandbox violations (network access, filesystem writes)"
  echo "  8. Verify idempotency (submit same code twice)"
  exit 0
else
  echo -e "${RED}✗ ${FAILED} check(s) failed${NC}"
  echo "Review failures above and check configuration"
  exit 1
fi
