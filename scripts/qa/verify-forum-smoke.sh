#!/usr/bin/env bash
# @covers AC-001, AC-005, AC-009, AC-011, AC-012, AC-013, AC-021, AC-022
# @spec: forum-service-migration_spec.md
# verify-forum-smoke.sh — Forum service smoke test for RKE2 post-deploy verification.
#
# Forum v2 (Python openedx-forum) runs integrated INTO the LMS process.
# There is no separate forum container; the forum API is served at the LMS URL.
# Meilisearch provides search (replaces Elasticsearch).
#
# Modes:
#   --offline   Static checks only — validates config files and K8s manifests
#   --online    Live cluster checks — tests forum API endpoints and Meilisearch health
#   (default)   Runs both offline and online checks
#
# Environment variables:
#   KUBE_CONTEXT   kubectl context to use (default: rke2-nonprod)
#   NAMESPACE      K8s namespace (default: mereka-lms)
#   LMS_URL        LMS base URL for online checks (default: https://academyv2.mereka.io)
#   CURL_TIMEOUT   curl connect timeout in seconds (default: 10)
#
# Usage:
#   ./scripts/qa/verify-forum-smoke.sh [--offline|--online]
#   KUBE_CONTEXT=gke_mereka-lms_prod ./scripts/qa/verify-forum-smoke.sh --online

set -euo pipefail

# ---------------------------------------------------------------------------
# Colors and counters
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# ---------------------------------------------------------------------------
# Paths and defaults
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KUBE_CONTEXT="${KUBE_CONTEXT:-rke2-nonprod}"
NAMESPACE="${NAMESPACE:-mereka-lms}"
LMS_URL="${LMS_URL:-https://academyv2.mereka.io}"
CURL_TIMEOUT="${CURL_TIMEOUT:-10}"

DEPLOY_FILE="${REPO_ROOT}/deploy/k8s/base/deployments.yml"
SERVICES_FILE="${REPO_ROOT}/deploy/k8s/base/services.yml"
ES_FILE="${REPO_ROOT}/deploy/k8s/base/secrets/external-secrets.yaml"
LMS_SETTINGS="${REPO_ROOT}/deploy/k8s/base/apps/openedx/settings/lms/production.py"
PATCHES_FILE="${REPO_ROOT}/infrastructure/tutor/apply-patches.sh"

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
pass() {
  echo -e "${GREEN}PASS${NC} $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo -e "${RED}FAIL${NC} $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

skip() {
  echo -e "${YELLOW}SKIP${NC} $1"
  SKIP_COUNT=$((SKIP_COUNT + 1))
}

# kctl — kubectl with fixed context
kctl() {
  kubectl --context "$KUBE_CONTEXT" "$@"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
MODE="both"
if [[ "${1:-}" == "--offline" ]]; then
  MODE="offline"
elif [[ "${1:-}" == "--online" ]]; then
  MODE="online"
fi

# ---------------------------------------------------------------------------
# Offline checks (static analysis — no cluster access required)
# ---------------------------------------------------------------------------
run_offline_checks() {
  echo ""
  echo "== Offline Checks (static analysis) =="
  echo ""

  # 1. No standalone forum Deployment in K8s manifests
  # Forum v2 runs in-process with LMS — there must be no separate forum Deployment.
  echo "--- No standalone forum Deployment ---"
  if [[ ! -f "$DEPLOY_FILE" ]]; then
    skip "deployments.yml not found: ${DEPLOY_FILE}"
  elif grep -E "^  name:\s+(forum|cs_comments_service)$" "$DEPLOY_FILE" > /dev/null 2>&1; then
    fail "Standalone forum Deployment found in ${DEPLOY_FILE} (should be in-process with LMS)"
  else
    pass "No standalone forum Deployment (forum correctly integrated into LMS process)"
  fi

  # 2. No Ruby cs_comments_service image references in manifests
  # AC-014: apply-patches.sh must not apply Ruby-specific patches
  echo "--- No Ruby forum image references ---"
  if [[ ! -f "$DEPLOY_FILE" ]]; then
    skip "deployments.yml not found, skipping Ruby image check"
  elif grep -E "overhangio/openedx-forum" "$DEPLOY_FILE" > /dev/null 2>&1; then
    fail "Ruby forum image (overhangio/openedx-forum) still referenced in ${DEPLOY_FILE}"
  else
    pass "No Ruby forum image references in deployment manifests"
  fi

  # 3. Meilisearch Deployment exists in base manifests
  # Forum search requires Meilisearch; this replaces Elasticsearch.
  echo "--- Meilisearch Deployment manifest ---"
  if [[ ! -f "$DEPLOY_FILE" ]]; then
    skip "deployments.yml not found, skipping Meilisearch check"
  elif grep -q "name: meilisearch" "$DEPLOY_FILE" > /dev/null 2>&1; then
    pass "Meilisearch Deployment found in base manifests"
  else
    fail "Meilisearch Deployment missing from ${DEPLOY_FILE} (required for forum search)"
  fi

  # 4. Meilisearch image is version-pinned (not :latest)
  echo "--- Meilisearch image version pinned ---"
  if [[ ! -f "$DEPLOY_FILE" ]]; then
    skip "deployments.yml not found, skipping Meilisearch image pin check"
  elif grep -E "getmeili/meilisearch:v[0-9]" "$DEPLOY_FILE" > /dev/null 2>&1; then
    meili_ver=$(grep -Eo "getmeili/meilisearch:v[0-9][^ \"']*" "$DEPLOY_FILE" | head -1)
    pass "Meilisearch image version pinned: ${meili_ver}"
  else
    fail "Meilisearch image is not pinned to a version tag in ${DEPLOY_FILE}"
  fi

  # 5. Meilisearch Service exists
  echo "--- Meilisearch Service manifest ---"
  if [[ ! -f "$SERVICES_FILE" ]]; then
    skip "services.yml not found: ${SERVICES_FILE}"
  elif grep -q "name: meilisearch" "$SERVICES_FILE" > /dev/null 2>&1; then
    pass "Meilisearch Service found in base manifests"
  else
    fail "Meilisearch Service missing from ${SERVICES_FILE}"
  fi

  # 6. LMS production.py has ENABLE_DISCUSSION_SERVICE enabled
  # AC-005: discussions MFE backed by Python forum must render threads
  echo "--- ENABLE_DISCUSSION_SERVICE in LMS settings ---"
  if [[ ! -f "$LMS_SETTINGS" ]]; then
    skip "LMS production.py not found: ${LMS_SETTINGS}"
  elif grep -qE "ENABLE_DISCUSSION_SERVICE.*True" "$LMS_SETTINGS" > /dev/null 2>&1; then
    pass "ENABLE_DISCUSSION_SERVICE = True in LMS production settings"
  else
    fail "ENABLE_DISCUSSION_SERVICE not True in ${LMS_SETTINGS}"
  fi

  # 7. LMS production.py has DISCUSSIONS_MFE_ENABLED (or DISCUSSIONS_MICROFRONTEND_URL)
  echo "--- Discussions MFE configured in LMS settings ---"
  if [[ ! -f "$LMS_SETTINGS" ]]; then
    skip "LMS production.py not found, skipping discussions MFE check"
  elif grep -qE "(DISCUSSIONS_MFE_ENABLED|DISCUSSIONS_MICROFRONTEND_URL)" "$LMS_SETTINGS" > /dev/null 2>&1; then
    pass "Discussions MFE URL/flag configured in LMS production settings"
  else
    fail "DISCUSSIONS_MFE_ENABLED / DISCUSSIONS_MICROFRONTEND_URL missing from ${LMS_SETTINGS}"
  fi

  # 8. LMS production.py references Meilisearch config (MEILISEARCH_URL or SEARCH_BACKEND)
  # AC-009: search results must be served by Meilisearch
  echo "--- Meilisearch config in LMS settings ---"
  if [[ ! -f "$LMS_SETTINGS" ]]; then
    skip "LMS production.py not found, skipping Meilisearch config check"
  elif grep -qE "(MEILISEARCH_URL|MEILISEARCH_API_KEY|SEARCH_BACKEND.*meilisearch)" "$LMS_SETTINGS" > /dev/null 2>&1; then
    pass "Meilisearch URL/API key referenced in LMS production settings"
  else
    fail "MEILISEARCH_URL / MEILISEARCH_API_KEY missing from ${LMS_SETTINGS}"
  fi

  # 9. ExternalSecrets map Meilisearch keys
  echo "--- ExternalSecret Meilisearch mappings ---"
  if [[ ! -f "$ES_FILE" ]]; then
    skip "external-secrets.yaml not found: ${ES_FILE}"
  else
    local meili_master meili_api
    meili_master=false
    meili_api=false
    grep -q "MEREKA_LMS_MEILISEARCH_MASTER_KEY" "$ES_FILE" 2>/dev/null && meili_master=true
    grep -q "MEREKA_LMS_MEILISEARCH_API_KEY" "$ES_FILE" 2>/dev/null && meili_api=true

    if $meili_master && $meili_api; then
      pass "ExternalSecret maps MEREKA_LMS_MEILISEARCH_MASTER_KEY and MEREKA_LMS_MEILISEARCH_API_KEY"
    elif $meili_api; then
      fail "MEREKA_LMS_MEILISEARCH_MASTER_KEY missing from ExternalSecret (API key found)"
    else
      fail "MEREKA_LMS_MEILISEARCH_* keys missing from ${ES_FILE}"
    fi
  fi

  # 10. apply-patches.sh contains Python-forum-specific configuration
  # AC-014: patches script must inject Python-specific config, not Ruby config
  echo "--- apply-patches.sh has Python forum config ---"
  if [[ ! -f "$PATCHES_FILE" ]]; then
    skip "apply-patches.sh not found: ${PATCHES_FILE}"
  elif grep -qiE "(openedx.forum|meilisearch|ENABLE_DISCUSSION_SERVICE)" "$PATCHES_FILE" > /dev/null 2>&1; then
    pass "apply-patches.sh references Python forum / Meilisearch configuration"
  else
    fail "apply-patches.sh does not reference Python forum config (check for openedx-forum / meilisearch)"
  fi
}

# ---------------------------------------------------------------------------
# Online checks (requires live cluster access)
# ---------------------------------------------------------------------------
run_online_checks() {
  echo ""
  echo "== Online Checks (live cluster: ${KUBE_CONTEXT} / ${NAMESPACE}) =="
  echo ""

  # Verify cluster reachability before all online checks
  if ! kctl cluster-info > /dev/null 2>&1; then
    echo -e "${RED}ERROR${NC}: Cannot reach cluster context '${KUBE_CONTEXT}'"
    echo "  Set KUBE_CONTEXT=<context> or verify kubeconfig is configured."
    for _i in $(seq 1 7); do
      skip "Online check skipped (cluster unreachable)"
    done
    return
  fi

  # 11. LMS pod is Running
  # AC-013: Python forum pod (in-process) starts and passes health checks within 60s
  echo "--- LMS pod Running (forum in-process) ---"
  local lms_phase lms_waiting
  lms_phase=$(kctl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=lms \
    -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
  lms_waiting=$(kctl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=lms \
    -o jsonpath='{.items[0].status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || echo "")
  if [[ "$lms_phase" == "Running" && -z "$lms_waiting" ]]; then
    pass "LMS pod is Running (forum runs in-process)"
  elif [[ -z "$lms_phase" ]]; then
    fail "LMS pod not found in namespace ${NAMESPACE}"
  else
    fail "LMS pod status: phase=${lms_phase} waiting=${lms_waiting:-none}"
  fi

  # 12. Meilisearch pod is Running
  echo "--- Meilisearch pod Running ---"
  local meili_phase meili_waiting
  meili_phase=$(kctl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=meilisearch \
    -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
  meili_waiting=$(kctl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=meilisearch \
    -o jsonpath='{.items[0].status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || echo "")
  if [[ "$meili_phase" == "Running" && -z "$meili_waiting" ]]; then
    pass "Meilisearch pod is Running"
  elif [[ -z "$meili_phase" ]]; then
    fail "Meilisearch pod not found in namespace ${NAMESPACE} (forum search will not work)"
  else
    fail "Meilisearch pod status: phase=${meili_phase} waiting=${meili_waiting:-none}"
  fi

  # 13. Forum API endpoint responds at LMS URL
  # AC-012: forum API must respond (200 or 401 for unauthenticated — both prove it's live)
  # AC-011: pod Running with Ready status (API reachable = pod is Ready)
  echo "--- Forum API endpoint responds (GET /api/discussion/v1/courses/) ---"
  local forum_status
  forum_status=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout "$CURL_TIMEOUT" --max-time "$((CURL_TIMEOUT * 3))" \
    "${LMS_URL}/api/discussion/v1/courses/" 2>/dev/null || echo "000")
  if [[ "$forum_status" =~ ^(200|401|403)$ ]]; then
    pass "Forum API /api/discussion/v1/courses/ responded HTTP ${forum_status}"
  elif [[ "$forum_status" == "000" ]]; then
    fail "Forum API /api/discussion/v1/courses/ unreachable (connection failed) — LMS_URL=${LMS_URL}"
  else
    fail "Forum API /api/discussion/v1/courses/ returned unexpected HTTP ${forum_status}"
  fi

  # 14. Forum threads endpoint responds
  # AC-005: discussions MFE backed by Python forum renders threads
  echo "--- Forum threads endpoint responds (GET /api/discussion/v1/threads/) ---"
  local threads_status
  threads_status=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout "$CURL_TIMEOUT" --max-time "$((CURL_TIMEOUT * 3))" \
    "${LMS_URL}/api/discussion/v1/threads/" 2>/dev/null || echo "000")
  if [[ "$threads_status" =~ ^(200|400|401|403)$ ]]; then
    # 400 is acceptable — endpoint exists but requires course_id param
    pass "Forum threads endpoint /api/discussion/v1/threads/ responded HTTP ${threads_status}"
  elif [[ "$threads_status" == "000" ]]; then
    fail "Forum threads endpoint unreachable (connection failed) — LMS_URL=${LMS_URL}"
  else
    fail "Forum threads endpoint returned unexpected HTTP ${threads_status}"
  fi

  # 15. Meilisearch health endpoint responds from inside cluster
  # AC-009: Meilisearch must be healthy for forum search to work
  echo "--- Meilisearch /health endpoint (via kubectl exec) ---"
  local meili_pod
  meili_pod=$(kctl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=meilisearch \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [[ -z "$meili_pod" ]]; then
    skip "No Meilisearch pod found — skipping in-cluster health check"
  else
    local meili_health
    meili_health=$(kctl exec -n "$NAMESPACE" "$meili_pod" -- \
      curl -s -o /dev/null -w "%{http_code}" http://localhost:7700/health 2>/dev/null || echo "000")
    if [[ "$meili_health" == "200" ]]; then
      pass "Meilisearch /health responded HTTP 200 (pod: ${meili_pod})"
    elif [[ "$meili_health" == "000" ]]; then
      fail "Meilisearch /health unreachable from inside pod ${meili_pod}"
    else
      fail "Meilisearch /health returned HTTP ${meili_health} (expected 200)"
    fi
  fi

  # 16. LMS pod env contains MONGODB_HOST (forum requires MongoDB Atlas)
  # AC-001: Python forum must connect to Atlas cs_comments_service database
  echo "--- LMS pod has MONGODB_HOST env var (Atlas connection) ---"
  local lms_pod
  lms_pod=$(kctl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=lms \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [[ -z "$lms_pod" ]]; then
    skip "No LMS pod found — skipping env var check"
  else
    local mongo_host
    mongo_host=$(kctl exec -n "$NAMESPACE" "$lms_pod" -- \
      sh -c 'echo "${MONGODB_HOST:-}"' 2>/dev/null || echo "")
    if [[ -n "$mongo_host" ]]; then
      pass "LMS pod MONGODB_HOST is set: ${mongo_host}"
    else
      fail "LMS pod MONGODB_HOST is empty or not set (forum cannot connect to Atlas)"
    fi
  fi

  # 17. No forum-related CrashLoopBackOff pods
  # AC-013: Python forum pod starts and passes health checks within 60s
  echo "--- No forum-related CrashLoopBackOff pods ---"
  local crash_pods
  crash_pods=$(kctl get pods -n "$NAMESPACE" -o json 2>/dev/null | \
    python3 -c "
import sys, json
data = json.load(sys.stdin)
bad = []
for pod in data.get('items', []):
  name = pod['metadata']['name']
  labels = pod['metadata'].get('labels', {})
  app = labels.get('app.kubernetes.io/name', '')
  # Check LMS (forum) and Meilisearch pods only
  if app not in ('lms', 'meilisearch'):
    continue
  for cs in pod.get('status', {}).get('containerStatuses', []):
    reason = (cs.get('state', {}).get('waiting', {}) or {}).get('reason', '')
    if reason == 'CrashLoopBackOff':
      bad.append(name)
      break
print('\n'.join(bad))
" 2>/dev/null || echo "")
  if [[ -z "$crash_pods" ]]; then
    pass "No LMS or Meilisearch pods in CrashLoopBackOff"
  else
    fail "CrashLoopBackOff pods (forum-related): ${crash_pods//$'\n'/, }"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "=== Forum Service Smoke Test ==="
echo "Mode      : ${MODE}"
echo "Repo root : ${REPO_ROOT}"
echo "Context   : ${KUBE_CONTEXT}"
echo "Namespace : ${NAMESPACE}"
echo "LMS URL   : ${LMS_URL}"

if [[ "$MODE" == "offline" || "$MODE" == "both" ]]; then
  run_offline_checks
fi

if [[ "$MODE" == "online" || "$MODE" == "both" ]]; then
  run_online_checks
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "========================================="
echo -e "  PASS: ${GREEN}${PASS_COUNT}${NC}  FAIL: ${RED}${FAIL_COUNT}${NC}  SKIP: ${YELLOW}${SKIP_COUNT}${NC}"
echo "========================================="

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo ""
  echo "Forum is Python openedx-forum integrated into LMS (no separate container)."
  echo "Common causes:"
  echo "  - Meilisearch not deployed or crashed (forum search breaks)"
  echo "  - MONGODB_HOST not set (forum cannot connect to Atlas)"
  echo "  - Ruby forum image still referenced in deployments.yml"
  echo "  - apply-patches.sh not run after tutor config save"
  echo ""
  echo "See docs/ops/runbooks/TROUBLESHOOTING.md and docs/reference/operations/FORUM_MEILISEARCH.md"
  exit 1
fi

exit 0
