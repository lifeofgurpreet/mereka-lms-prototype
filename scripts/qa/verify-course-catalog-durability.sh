#!/usr/bin/env bash
# verify-course-catalog-durability.sh — Verify course catalog index durability
# Checks that the course-reindex CronJob exists and verifies the backend selected
# by runtime SEARCH_ENGINE.
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

# 4. CronJob has backend-aware post-reindex verification
if grep -q "SEARCH_ENGINE" deploy/k8s/base/monitoring/cronjob-course-reindex.yaml 2>/dev/null \
  && grep -q "Unsupported SEARCH_ENGINE" deploy/k8s/base/monitoring/cronjob-course-reindex.yaml 2>/dev/null; then
  pass "CronJob verifies backend by effective SEARCH_ENGINE"
else
  fail "CronJob is missing backend-aware verification"
fi

# 5. CronJob is non-interactive (pipes explicit confirmation to reindex_course)
if grep -Eq "printf 'y\\\\n'|echo y \|" deploy/k8s/base/monitoring/cronjob-course-reindex.yaml 2>/dev/null; then
  pass "CronJob is non-interactive via explicit stdin confirmation"
else
  fail "CronJob missing explicit non-interactive confirmation"
fi

# 6. Live cluster checks (optional — skip if no kubectl access)
if command -v kubectl &>/dev/null && kubectl get ns mereka-lms-dev &>/dev/null 2>&1; then
  ENGINE=$(kubectl exec -n mereka-lms-dev deployment/cms -- \
    python manage.py cms shell -c "from django.conf import settings; print(settings.SEARCH_ENGINE)" 2>/dev/null \
    | tail -1 | tr -d '\r' || echo "")
  case "${ENGINE}" in
    search.elastic.ElasticSearchEngine)
      COUNT=$(kubectl exec -n mereka-lms-dev deployment/lms -- \
        curl -sf http://elasticsearch:9200/course_info/_count 2>/dev/null \
        | python3 -c "import sys,json; print(json.load(sys.stdin).get('count',0))" 2>/dev/null \
        || echo "0")
      if [ "${COUNT:-0}" -gt 0 ]; then
        pass "Elasticsearch course_info has ${COUNT} docs"
      else
        fail "Elasticsearch course_info is empty (${COUNT} docs)"
      fi
      ;;
    search.meilisearch.MeilisearchEngine)
      COUNT=$(kubectl exec -n mereka-lms-dev deployment/cms -- /bin/sh -lc \
        "curl -sf -H \"Authorization: Bearer \${MEILISEARCH_API_KEY:-}\" http://meilisearch:7700/indexes/tutor_course_info/stats 2>/dev/null \
        | python3 -c \"import sys,json; print(json.load(sys.stdin).get('numberOfDocuments',0))\"" \
        2>/dev/null || echo "0")
      if [ "${COUNT:-0}" -gt 0 ]; then
        pass "Meilisearch tutor_course_info has ${COUNT} docs"
      else
        fail "Meilisearch tutor_course_info is empty (${COUNT} docs)"
      fi
      ;;
    "")
      skip "Could not determine dev SEARCH_ENGINE"
      ;;
    *)
      fail "Unsupported dev SEARCH_ENGINE=${ENGINE}"
      ;;
  esac
else
  skip "No kubectl access — cannot verify live catalog backend state"
fi

echo ""
echo "=== Results: ${PASS} PASS / ${FAIL} FAIL / ${SKIP} SKIP ==="
[ "${FAIL}" -eq 0 ]
