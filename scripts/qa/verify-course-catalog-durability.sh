#!/usr/bin/env bash
# verify-course-catalog-durability.sh — Verify course catalog index durability
# Checks that the course-reindex CronJob exists and course_info ES index is populated.
# @covers AC-CAT-001
set -euo pipefail

PASS=0; FAIL=0; SKIP=0
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "SKIP: $1"; SKIP=$((SKIP + 1)); }

echo "=== Course Catalog Durability Verification ==="
echo ""

# 1. CronJob manifest exists
if [ -f "deploy/k8s/base/monitoring/cronjob-course-reindex.yaml" ]; then
  pass "cronjob-course-reindex.yaml exists"
else
  fail "cronjob-course-reindex.yaml missing"
fi

# 2. CronJob registered in kustomization
if grep -q "cronjob-course-reindex.yaml" deploy/k8s/base/monitoring/kustomization.yaml 2>/dev/null; then
  pass "cronjob-course-reindex.yaml registered in kustomization"
else
  fail "cronjob-course-reindex.yaml not in kustomization"
fi

# 3. CronJob uses CMS (reindex_course is CMS-only)
if grep -q "cms reindex_course" deploy/k8s/base/monitoring/cronjob-course-reindex.yaml 2>/dev/null; then
  pass "CronJob runs reindex_course via CMS"
else
  fail "CronJob does not run reindex_course via CMS"
fi

# 4. CronJob has post-reindex verification
if grep -q "course_info" deploy/k8s/base/monitoring/cronjob-course-reindex.yaml 2>/dev/null; then
  pass "CronJob verifies course_info after reindex"
else
  fail "CronJob has no post-reindex verification"
fi

# 5. CronJob is idempotent (uses --setup flag for non-interactive)
if grep -q "\-\-setup" deploy/k8s/base/monitoring/cronjob-course-reindex.yaml 2>/dev/null; then
  pass "CronJob uses --setup (non-interactive, idempotent)"
else
  fail "CronJob missing --setup flag"
fi

# 6. Live cluster checks (optional — skip if no kubectl access)
if command -v kubectl &>/dev/null && kubectl get ns mereka-lms-dev &>/dev/null 2>&1; then
  # Check course_info doc count via ES REST API directly (avoids Django shell noise)
  COUNT=$(kubectl exec -n mereka-lms-dev deployment/lms -- \
    curl -sf http://elasticsearch:9200/course_info/_count 2>/dev/null \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('count',0))" 2>/dev/null \
    || echo "0")
  if [ "${COUNT:-0}" -gt 0 ]; then
    pass "ES course_info has ${COUNT} docs"
  else
    fail "ES course_info is empty (${COUNT} docs)"
  fi
else
  skip "No kubectl access — cannot verify live ES state"
fi

echo ""
echo "=== Results: ${PASS} PASS / ${FAIL} FAIL / ${SKIP} SKIP ==="
[ "${FAIL}" -eq 0 ]
