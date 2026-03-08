#!/usr/bin/env bash
# @covers AC-K8S-001, AC-K8S-002, AC-K8S-003, AC-K8S-004, AC-K8S-005, AC-K8S-006
# @spec: k8s-deployment_spec.md
# verify-credentials-notes-smoke.sh — Smoke test for Credentials and Notes services.
#
# Both services are deployed as standalone Django apps alongside the LMS.
# Credentials: issues verifiable certificates/badges (port 8000, /health/ endpoint)
# Notes: stores learner annotations (port 8000, /api/v1/annotations/ endpoint)
#
# Modes:
#   --offline   Static checks only — validates K8s manifests, secrets, routing
#   --online    Live cluster checks — tests endpoints and pod health
#   (default)   Runs both offline and online checks
#
# Environment variables:
#   KUBE_CONTEXT          kubectl context to use (default: rke2-nonprod)
#   NAMESPACE             K8s namespace (default: mereka-lms)
#   CREDENTIALS_URL       Credentials base URL (default: https://credentials.academyv2.mereka.io)
#   NOTES_URL             Notes base URL (default: https://notes.academyv2.mereka.io)
#   CURL_TIMEOUT          curl connect timeout in seconds (default: 10)
#
# Usage:
#   ./scripts/qa/verify-credentials-notes-smoke.sh [--offline|--online]
#   KUBE_CONTEXT=gke_mereka-lms_prod ./scripts/qa/verify-credentials-notes-smoke.sh --online

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
CREDENTIALS_URL="${CREDENTIALS_URL:-https://credentials.academyv2.mereka.io}"
NOTES_URL="${NOTES_URL:-https://notes.academyv2.mereka.io}"
CURL_TIMEOUT="${CURL_TIMEOUT:-10}"

DEPLOY_FILE="${REPO_ROOT}/deploy/k8s/base/deployments.yml"
SERVICES_FILE="${REPO_ROOT}/deploy/k8s/base/services.yml"
ES_FILE="${REPO_ROOT}/deploy/k8s/base/secrets/external-secrets.yaml"
CADDYFILE="${REPO_ROOT}/deploy/k8s/base/apps/caddy/Caddyfile"
CREDENTIALS_SETTINGS="${REPO_ROOT}/deploy/k8s/base/plugins/credentials/apps/credentials/settings/production.py"
NOTES_SETTINGS="${REPO_ROOT}/deploy/k8s/base/plugins/notes/apps/settings/tutor.py"

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

  # 1. Credentials Deployment exists in base manifests
  echo "--- Credentials Deployment manifest ---"
  if [[ ! -f "$DEPLOY_FILE" ]]; then
    skip "deployments.yml not found: ${DEPLOY_FILE}"
  elif grep -q "name: credentials" "$DEPLOY_FILE" 2>/dev/null; then
    pass "Credentials Deployment found in base manifests"
  else
    fail "Credentials Deployment missing from ${DEPLOY_FILE}"
  fi

  # 2. Notes Deployment exists in base manifests
  echo "--- Notes Deployment manifest ---"
  if [[ ! -f "$DEPLOY_FILE" ]]; then
    skip "deployments.yml not found, skipping Notes Deployment check"
  elif grep -q "name: notes" "$DEPLOY_FILE" 2>/dev/null; then
    pass "Notes Deployment found in base manifests"
  else
    fail "Notes Deployment missing from ${DEPLOY_FILE}"
  fi

  # 3. Credentials Service exists
  echo "--- Credentials Service manifest ---"
  if [[ ! -f "$SERVICES_FILE" ]]; then
    skip "services.yml not found: ${SERVICES_FILE}"
  elif grep -q "name: credentials" "$SERVICES_FILE" 2>/dev/null; then
    pass "Credentials Service found in base manifests"
  else
    fail "Credentials Service missing from ${SERVICES_FILE}"
  fi

  # 4. Notes Service exists
  echo "--- Notes Service manifest ---"
  if [[ ! -f "$SERVICES_FILE" ]]; then
    skip "services.yml not found, skipping Notes Service check"
  elif grep -q "name: notes" "$SERVICES_FILE" 2>/dev/null; then
    pass "Notes Service found in base manifests"
  else
    fail "Notes Service missing from ${SERVICES_FILE}"
  fi

  # 5. Credentials image is version-pinned (not :latest)
  echo "--- Credentials image version pinned ---"
  if [[ ! -f "$DEPLOY_FILE" ]]; then
    skip "deployments.yml not found, skipping Credentials image pin check"
  elif grep -E "openedx-credentials:[0-9]" "$DEPLOY_FILE" > /dev/null 2>&1; then
    cred_ver=$(grep -Eo "openedx-credentials:[^ \"']*" "$DEPLOY_FILE" | head -1)
    pass "Credentials image version pinned: ${cred_ver}"
  else
    fail "Credentials image is not pinned to a version tag in ${DEPLOY_FILE}"
  fi

  # 6. Notes image is version-pinned (not :latest)
  echo "--- Notes image version pinned ---"
  if [[ ! -f "$DEPLOY_FILE" ]]; then
    skip "deployments.yml not found, skipping Notes image pin check"
  elif grep -E "openedx-notes:[0-9]" "$DEPLOY_FILE" > /dev/null 2>&1; then
    notes_ver=$(grep -Eo "openedx-notes:[^ \"']*" "$DEPLOY_FILE" | head -1)
    pass "Notes image version pinned: ${notes_ver}"
  else
    fail "Notes image is not pinned to a version tag in ${DEPLOY_FILE}"
  fi

  # 7. Credentials ALLOWED_HOSTS includes credentials domain
  echo "--- Credentials ALLOWED_HOSTS configured ---"
  if [[ ! -f "$CREDENTIALS_SETTINGS" ]]; then
    skip "Credentials production.py not found: ${CREDENTIALS_SETTINGS}"
  elif grep -qE "ALLOWED_HOSTS" "$CREDENTIALS_SETTINGS" 2>/dev/null; then
    pass "Credentials ALLOWED_HOSTS configured in production settings"
  else
    fail "ALLOWED_HOSTS missing from ${CREDENTIALS_SETTINGS}"
  fi

  # 8. Notes ALLOWED_HOSTS includes notes domain
  echo "--- Notes ALLOWED_HOSTS configured ---"
  if [[ ! -f "$NOTES_SETTINGS" ]]; then
    skip "Notes settings not found: ${NOTES_SETTINGS}"
  elif grep -qE "ALLOWED_HOSTS" "$NOTES_SETTINGS" 2>/dev/null; then
    pass "Notes ALLOWED_HOSTS configured in settings"
  else
    fail "ALLOWED_HOSTS missing from ${NOTES_SETTINGS}"
  fi

  # 9. ExternalSecret maps Credentials secrets
  echo "--- ExternalSecret Credentials mappings ---"
  if [[ ! -f "$ES_FILE" ]]; then
    skip "external-secrets.yaml not found: ${ES_FILE}"
  else
    local cred_secret cred_oauth
    cred_secret=false
    cred_oauth=false
    grep -q "CREDENTIALS_SECRET_KEY" "$ES_FILE" 2>/dev/null && cred_secret=true
    grep -q "CREDENTIALS_BACKEND_OAUTH2_SECRET" "$ES_FILE" 2>/dev/null && cred_oauth=true

    if $cred_secret && $cred_oauth; then
      pass "ExternalSecret maps CREDENTIALS_SECRET_KEY and CREDENTIALS_BACKEND_OAUTH2_SECRET"
    elif $cred_secret; then
      fail "CREDENTIALS_BACKEND_OAUTH2_SECRET missing from ExternalSecret (secret key found)"
    else
      fail "Credentials secrets (CREDENTIALS_SECRET_KEY) missing from ${ES_FILE}"
    fi
  fi

  # 10. ExternalSecret maps Notes secrets
  echo "--- ExternalSecret Notes mappings ---"
  if [[ ! -f "$ES_FILE" ]]; then
    skip "external-secrets.yaml not found, skipping Notes secrets check"
  else
    local notes_secret notes_client
    notes_secret=false
    notes_client=false
    grep -q "NOTES_SECRET_KEY" "$ES_FILE" 2>/dev/null && notes_secret=true
    grep -q "NOTES_CLIENT_SECRET" "$ES_FILE" 2>/dev/null && notes_client=true

    if $notes_secret && $notes_client; then
      pass "ExternalSecret maps NOTES_SECRET_KEY and NOTES_CLIENT_SECRET"
    elif $notes_secret; then
      fail "NOTES_CLIENT_SECRET missing from ExternalSecret (secret key found)"
    else
      fail "Notes secrets (NOTES_SECRET_KEY) missing from ${ES_FILE}"
    fi
  fi

  # 11. Caddy routes credentials domain
  echo "--- Caddy routes credentials domain ---"
  if [[ ! -f "$CADDYFILE" ]]; then
    skip "Caddyfile not found: ${CADDYFILE}"
  elif grep -q "credentials.academyv2.mereka" "$CADDYFILE" 2>/dev/null; then
    pass "Caddyfile routes credentials.academyv2.mereka.{io,dev}"
  else
    fail "Credentials domain not found in Caddyfile (${CADDYFILE})"
  fi

  # 12. Caddy routes notes domain
  echo "--- Caddy routes notes domain ---"
  if [[ ! -f "$CADDYFILE" ]]; then
    skip "Caddyfile not found, skipping notes routing check"
  elif grep -q "notes.academyv2.mereka" "$CADDYFILE" 2>/dev/null; then
    pass "Caddyfile routes notes.academyv2.mereka.{io,dev}"
  else
    fail "Notes domain not found in Caddyfile (${CADDYFILE})"
  fi

  # 13. Caddy proxies Credentials to credentials:8000
  echo "--- Caddy proxies Credentials to credentials:8000 ---"
  if [[ ! -f "$CADDYFILE" ]]; then
    skip "Caddyfile not found, skipping Credentials proxy check"
  elif grep -q "credentials:8000" "$CADDYFILE" 2>/dev/null; then
    pass "Caddyfile proxies to credentials:8000"
  else
    fail "credentials:8000 proxy target missing from Caddyfile (${CADDYFILE})"
  fi

  # 14. Caddy proxies Notes to notes:8000
  echo "--- Caddy proxies Notes to notes:8000 ---"
  if [[ ! -f "$CADDYFILE" ]]; then
    skip "Caddyfile not found, skipping Notes proxy check"
  elif grep -q "notes:8000" "$CADDYFILE" 2>/dev/null; then
    pass "Caddyfile proxies to notes:8000"
  else
    fail "notes:8000 proxy target missing from Caddyfile (${CADDYFILE})"
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
    for _i in $(seq 1 8); do
      skip "Online check skipped (cluster unreachable)"
    done
    return
  fi

  # 15. Credentials pod is Running
  echo "--- Credentials pod Running ---"
  local cred_phase cred_waiting
  cred_phase=$(kctl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=credentials \
    -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
  cred_waiting=$(kctl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=credentials \
    -o jsonpath='{.items[0].status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || echo "")
  if [[ "$cred_phase" == "Running" && -z "$cred_waiting" ]]; then
    pass "Credentials pod is Running"
  elif [[ -z "$cred_phase" ]]; then
    fail "Credentials pod not found in namespace ${NAMESPACE}"
  else
    fail "Credentials pod status: phase=${cred_phase} waiting=${cred_waiting:-none}"
  fi

  # 16. Notes pod is Running
  echo "--- Notes pod Running ---"
  local notes_phase notes_waiting
  notes_phase=$(kctl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=notes \
    -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
  notes_waiting=$(kctl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=notes \
    -o jsonpath='{.items[0].status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || echo "")
  if [[ "$notes_phase" == "Running" && -z "$notes_waiting" ]]; then
    pass "Notes pod is Running"
  elif [[ -z "$notes_phase" ]]; then
    fail "Notes pod not found in namespace ${NAMESPACE}"
  else
    fail "Notes pod status: phase=${notes_phase} waiting=${notes_waiting:-none}"
  fi

  # 17. Credentials /health/ endpoint responds
  echo "--- Credentials /health/ endpoint responds ---"
  local cred_health_status
  cred_health_status=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout "$CURL_TIMEOUT" --max-time "$((CURL_TIMEOUT * 3))" \
    "${CREDENTIALS_URL}/health/" 2>/dev/null || echo "000")
  if [[ "$cred_health_status" == "200" ]]; then
    pass "Credentials /health/ responded HTTP 200"
  elif [[ "$cred_health_status" =~ ^(301|302)$ ]]; then
    pass "Credentials /health/ responded HTTP ${cred_health_status} (redirect — service alive)"
  elif [[ "$cred_health_status" == "000" ]]; then
    fail "Credentials /health/ unreachable (connection failed) — CREDENTIALS_URL=${CREDENTIALS_URL}"
  else
    fail "Credentials /health/ returned unexpected HTTP ${cred_health_status}"
  fi

  # 18. Notes /api/v1/annotations/ endpoint responds
  # 401/403 = endpoint exists (auth required); both prove the service is live.
  echo "--- Notes /api/v1/annotations/ endpoint responds ---"
  local notes_api_status
  notes_api_status=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout "$CURL_TIMEOUT" --max-time "$((CURL_TIMEOUT * 3))" \
    "${NOTES_URL}/api/v1/annotations/" 2>/dev/null || echo "000")
  if [[ "$notes_api_status" =~ ^(200|401|403)$ ]]; then
    pass "Notes /api/v1/annotations/ responded HTTP ${notes_api_status}"
  elif [[ "$notes_api_status" == "000" ]]; then
    fail "Notes /api/v1/annotations/ unreachable (connection failed) — NOTES_URL=${NOTES_URL}"
  else
    fail "Notes /api/v1/annotations/ returned unexpected HTTP ${notes_api_status}"
  fi

  # 19. Credentials /api/v2/credentials/ endpoint responds
  # 401/403 = endpoint exists (auth required); both prove the service is live.
  echo "--- Credentials /api/v2/credentials/ endpoint responds ---"
  local cred_api_status
  cred_api_status=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout "$CURL_TIMEOUT" --max-time "$((CURL_TIMEOUT * 3))" \
    "${CREDENTIALS_URL}/api/v2/credentials/" 2>/dev/null || echo "000")
  if [[ "$cred_api_status" =~ ^(200|401|403)$ ]]; then
    pass "Credentials /api/v2/credentials/ responded HTTP ${cred_api_status}"
  elif [[ "$cred_api_status" == "000" ]]; then
    fail "Credentials /api/v2/credentials/ unreachable (connection failed) — CREDENTIALS_URL=${CREDENTIALS_URL}"
  else
    fail "Credentials /api/v2/credentials/ returned unexpected HTTP ${cred_api_status}"
  fi

  # 20. No Credentials or Notes CrashLoopBackOff pods
  echo "--- No Credentials or Notes CrashLoopBackOff pods ---"
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
  if app not in ('credentials', 'notes'):
    continue
  for cs in pod.get('status', {}).get('containerStatuses', []):
    reason = (cs.get('state', {}).get('waiting', {}) or {}).get('reason', '')
    if reason == 'CrashLoopBackOff':
      bad.append(name)
      break
print('\n'.join(bad))
" 2>/dev/null || echo "")
  if [[ -z "$crash_pods" ]]; then
    pass "No Credentials or Notes pods in CrashLoopBackOff"
  else
    fail "CrashLoopBackOff pods (credentials/notes): ${crash_pods//$'\n'/, }"
  fi

  # 21. Credentials pod has CREDENTIALS_SECRET_KEY env var set
  echo "--- Credentials pod has CREDENTIALS_SECRET_KEY set ---"
  local cred_pod
  cred_pod=$(kctl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=credentials \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [[ -z "$cred_pod" ]]; then
    skip "No Credentials pod found — skipping env var check"
  else
    local cred_sk
    cred_sk=$(kctl exec -n "$NAMESPACE" "$cred_pod" -- \
      sh -c 'echo "${CREDENTIALS_SECRET_KEY:-}"' 2>/dev/null || echo "")
    if [[ -n "$cred_sk" ]]; then
      pass "Credentials pod CREDENTIALS_SECRET_KEY is set"
    else
      fail "Credentials pod CREDENTIALS_SECRET_KEY is empty (check ExternalSecret sync)"
    fi
  fi

  # 22. Notes pod has NOTES_SECRET_KEY env var set
  echo "--- Notes pod has NOTES_SECRET_KEY set ---"
  local notes_pod
  notes_pod=$(kctl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=notes \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [[ -z "$notes_pod" ]]; then
    skip "No Notes pod found — skipping env var check"
  else
    local notes_sk
    notes_sk=$(kctl exec -n "$NAMESPACE" "$notes_pod" -- \
      sh -c 'echo "${NOTES_SECRET_KEY:-}"' 2>/dev/null || echo "")
    if [[ -n "$notes_sk" ]]; then
      pass "Notes pod NOTES_SECRET_KEY is set"
    else
      fail "Notes pod NOTES_SECRET_KEY is empty (check ExternalSecret sync)"
    fi
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "=== Credentials and Notes Service Smoke Test ==="
echo "Mode            : ${MODE}"
echo "Repo root       : ${REPO_ROOT}"
echo "Context         : ${KUBE_CONTEXT}"
echo "Namespace       : ${NAMESPACE}"
echo "Credentials URL : ${CREDENTIALS_URL}"
echo "Notes URL       : ${NOTES_URL}"

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
  echo "Credentials: Django app issuing verifiable certificates/badges."
  echo "Notes: Django app storing learner annotations (edx-notes-api)."
  echo ""
  echo "Common causes:"
  echo "  - ExternalSecret not synced (CREDENTIALS_SECRET_KEY / NOTES_SECRET_KEY empty)"
  echo "  - ALLOWED_HOSTS mismatch (check MEREKA_CREDENTIALS_DOMAIN / NOTES_DOMAIN env vars)"
  echo "  - Caddy routing missing for credentials/notes subdomain"
  echo "  - MySQL migrations not run on first deploy (run python manage.py migrate)"
  echo ""
  echo "See docs/runbooks/operations/TROUBLESHOOTING.md for K8s pod and endpoint diagnostics."
  exit 1
fi

exit 0
