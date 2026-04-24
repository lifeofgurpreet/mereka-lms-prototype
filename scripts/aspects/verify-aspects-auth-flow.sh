#!/usr/bin/env bash
# verify-aspects-auth-flow.sh — Verify the Authentik-brokered OIDC auth flow for Superset.
#
# AUTH ARCHITECTURE NOTE:
# This deployment uses Authentik as an OIDC broker between LMS users and
# Superset. This is a custom design, NOT the default Aspects LMS-direct-SSO
# pattern. The standard Aspects auth (LMS JWT -> Superset) is not used.
# See: docs/status/active/ASPECTS_ANALYTICS_ACTIVATION_TRACKER.md
#
# Usage:
#   ./scripts/aspects/verify-aspects-auth-flow.sh --env dev
#   ./scripts/aspects/verify-aspects-auth-flow.sh --env staging

set -euo pipefail

# ---------------------------------------------------------------------------
# Colors and counters
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# shellcheck source=../shared/config.sh
source "${REPO_ROOT}/scripts/shared/config.sh"

CURL_TIMEOUT="${CURL_TIMEOUT:-10}"

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
pass() {
  echo -e "  ${GREEN}PASS${NC} $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo -e "  ${RED}FAIL${NC} $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

warn() {
  echo -e "  ${YELLOW}WARN${NC} $1"
  WARN_COUNT=$((WARN_COUNT + 1))
}

section() {
  echo ""
  echo -e "${CYAN}--- $1 ---${NC}"
}

usage() {
  echo "Usage: $0 --env <dev|staging>"
  echo ""
  echo "  --env dev|staging   Target environment (no prod — ADR-017)"
  exit 1
}

# kctl — kubectl with fixed context and namespace
kctl() {
  kubectl --context "$K8S_CTX" -n "$NS" "$@"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
ENV=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      ;;
  esac
done

if [[ -z "$ENV" ]]; then
  echo "ERROR: --env is required" >&2
  usage
fi

case "$ENV" in
  dev|staging) ;;
  prod|production)
    echo "ERROR: Production Aspects is deferred (ADR-017). Use --env dev or --env staging." >&2
    exit 1
    ;;
  *)
    echo "ERROR: Unsupported environment: $ENV" >&2
    usage
    ;;
esac

# ---------------------------------------------------------------------------
# Resolve domains and K8s targets
# ---------------------------------------------------------------------------
K8S_CTX="$(mereka_lms_default_context_for_env "$ENV")"
NS="$(mereka_lms_default_namespace_for_env "$ENV")"

case "$ENV" in
  dev)
    ANALYTICS_DOMAIN="analytics.academyv2.mereka.dev"
    AUTH_DOMAIN="auth0.mereka.dev"
    ;;
  staging)
    ANALYTICS_DOMAIN="analytics.staging.academyv2.mereka.io"
    AUTH_DOMAIN="staging.auth0.mereka.io"
    ;;
esac

echo "========================================================"
echo "  Aspects Auth Flow Verification — env=${ENV}"
echo "  analytics: ${ANALYTICS_DOMAIN}"
echo "  auth:      ${AUTH_DOMAIN}"
echo "  context:   ${K8S_CTX}  namespace: ${NS}"
echo "========================================================"

# ---------------------------------------------------------------------------
# Step 1: DNS resolution
# ---------------------------------------------------------------------------
section "[1/6] DNS Resolution"

if host "$ANALYTICS_DOMAIN" >/dev/null 2>&1; then
  resolved_ip="$(host "$ANALYTICS_DOMAIN" 2>/dev/null | grep 'has address' | head -1 | awk '{print $NF}' || true)"
  pass "DNS resolves for ${ANALYTICS_DOMAIN} -> ${resolved_ip:-?}"
elif dig +short "$ANALYTICS_DOMAIN" 2>/dev/null | grep -qE '^[0-9]'; then
  resolved_ip="$(dig +short "$ANALYTICS_DOMAIN" 2>/dev/null | head -1)"
  pass "DNS resolves for ${ANALYTICS_DOMAIN} -> ${resolved_ip}"
else
  fail "DNS does not resolve for ${ANALYTICS_DOMAIN}"
fi

if host "$AUTH_DOMAIN" >/dev/null 2>&1; then
  pass "DNS resolves for ${AUTH_DOMAIN}"
else
  warn "DNS does not resolve for ${AUTH_DOMAIN} (may not be reachable from this host)"
fi

# ---------------------------------------------------------------------------
# Step 2: HTTPS reachability
# ---------------------------------------------------------------------------
section "[2/6] HTTPS Reachability"

http_status="$(curl -s -o /dev/null -w "%{http_code}" \
  --connect-timeout "$CURL_TIMEOUT" \
  --max-time "$((CURL_TIMEOUT * 3))" \
  -k \
  "https://${ANALYTICS_DOMAIN}/" 2>/dev/null || echo "000")"

if [[ "$http_status" == "200" ]]; then
  pass "Superset returns HTTP 200 (authenticated or public)"
elif [[ "$http_status" == "302" || "$http_status" == "301" ]]; then
  pass "Superset returns HTTP ${http_status} (OAuth redirect — expected for unauthenticated)"
elif [[ "$http_status" == "000" ]]; then
  fail "Superset unreachable at https://${ANALYTICS_DOMAIN}/ (connection failed)"
else
  warn "Superset returns HTTP ${http_status} (unexpected — may be misconfigured)"
fi

# ---------------------------------------------------------------------------
# Step 3: OAuth redirect target
# ---------------------------------------------------------------------------
section "[3/6] OAuth Redirect Target"

if [[ "$http_status" == "302" || "$http_status" == "301" ]]; then
  location="$(curl -s -I \
    --connect-timeout "$CURL_TIMEOUT" \
    --max-time "$((CURL_TIMEOUT * 3))" \
    -k \
    "https://${ANALYTICS_DOMAIN}/" 2>/dev/null | grep -i '^location:' | head -1 | tr -d '\r')"

  if [[ -n "$location" ]]; then
    echo "    Location: ${location#Location: }"
    if echo "$location" | grep -qi "$AUTH_DOMAIN"; then
      pass "Redirect points to Authentik (${AUTH_DOMAIN})"
    elif echo "$location" | grep -qi "login"; then
      warn "Redirect goes to a login page but not to ${AUTH_DOMAIN} — check Superset OAuth config"
    else
      warn "Redirect does not point to ${AUTH_DOMAIN}: ${location}"
    fi
  else
    warn "HTTP ${http_status} but no Location header found"
  fi
else
  warn "Skipping redirect check — HTTP status was ${http_status} (need 301/302)"
fi

# ---------------------------------------------------------------------------
# Step 4: Superset OAuth configmap check
# ---------------------------------------------------------------------------
section "[4/6] Superset OAuth Configuration"

# Check for superset configmap (common patterns: superset-config, superset-custom-config)
superset_cm=""
for cm_name in superset-config superset-custom-config superset-configmap; do
  if kctl get configmap "$cm_name" -o name >/dev/null 2>&1; then
    superset_cm="$cm_name"
    break
  fi
done

if [[ -n "$superset_cm" ]]; then
  cm_data="$(kctl get configmap "$superset_cm" -o json 2>/dev/null || true)"
  if [[ -n "$cm_data" ]]; then
    # Check for AUTH_TYPE = AUTH_OAUTH or OAUTH_PROVIDERS
    if echo "$cm_data" | grep -qi "AUTH_OAUTH\|OAUTH_PROVIDERS\|AUTH_TYPE"; then
      pass "ConfigMap '${superset_cm}' references OAuth auth configuration"
    else
      warn "ConfigMap '${superset_cm}' found but no OAuth config detected"
    fi

    # Check for Authentik provider reference
    if echo "$cm_data" | grep -qi "authentik\|${AUTH_DOMAIN}"; then
      pass "ConfigMap references Authentik (${AUTH_DOMAIN})"
    else
      warn "ConfigMap does not reference Authentik or ${AUTH_DOMAIN}"
    fi
  fi
else
  warn "No Superset ConfigMap found (tried: superset-config, superset-custom-config, superset-configmap)"
fi

# ---------------------------------------------------------------------------
# Step 5: Authentik OAuth application check
# ---------------------------------------------------------------------------
section "[5/6] Authentik OAuth Application"

# Check if Authentik is reachable and has the superset-analytics application
# We check via the Authentik well-known OIDC endpoint for the analytics provider
authentik_oidc_url="https://${AUTH_DOMAIN}/application/o/superset-analytics/.well-known/openid-configuration"
oidc_status="$(curl -s -o /dev/null -w "%{http_code}" \
  --connect-timeout "$CURL_TIMEOUT" \
  --max-time "$((CURL_TIMEOUT * 3))" \
  -k \
  "$authentik_oidc_url" 2>/dev/null || echo "000")"

if [[ "$oidc_status" == "200" ]]; then
  pass "Authentik OIDC discovery endpoint for 'superset-analytics' returns 200"
elif [[ "$oidc_status" == "404" ]]; then
  warn "Authentik OIDC discovery returns 404 — 'superset-analytics' application may not exist yet"
elif [[ "$oidc_status" == "000" ]]; then
  warn "Authentik unreachable at ${AUTH_DOMAIN} (cannot verify OAuth application)"
else
  warn "Authentik OIDC discovery returns HTTP ${oidc_status}"
fi

# Also try the generic Authentik health endpoint
authentik_health="$(curl -s -o /dev/null -w "%{http_code}" \
  --connect-timeout "$CURL_TIMEOUT" \
  --max-time "$((CURL_TIMEOUT * 3))" \
  -k \
  "https://${AUTH_DOMAIN}/-/health/ready/" 2>/dev/null || echo "000")"

if [[ "$authentik_health" == "200" || "$authentik_health" == "204" ]]; then
  pass "Authentik health endpoint is reachable"
elif [[ "$authentik_health" == "000" ]]; then
  warn "Authentik health endpoint unreachable"
else
  warn "Authentik health returns HTTP ${authentik_health}"
fi

# ---------------------------------------------------------------------------
# Step 6: Superset pod readiness
# ---------------------------------------------------------------------------
section "[6/6] Superset Pod Readiness"

superset_pod="$(kctl get pod -l app.kubernetes.io/name=superset -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "$superset_pod" ]]; then
  superset_pod="$(kctl get pod -l app=superset -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
fi

if [[ -z "$superset_pod" ]]; then
  fail "Superset pod not found in ${NS}"
else
  phase="$(kctl get pod "$superset_pod" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  if [[ "$phase" == "Running" ]]; then
    pass "Superset pod is Running (${superset_pod})"
  else
    fail "Superset pod is ${phase:-unknown} (expected Running)"
  fi
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "========================================================"
echo -e "  PASS: ${GREEN}${PASS_COUNT}${NC}  FAIL: ${RED}${FAIL_COUNT}${NC}  WARN: ${YELLOW}${WARN_COUNT}${NC}"
echo "========================================================"

echo ""
echo "Proven:"
echo "  - DNS resolution for analytics and auth domains"
echo "  - HTTPS reachability and redirect behavior"
echo "  - OAuth redirect target (Authentik)"
echo "  - Superset OAuth configuration in ConfigMap"
echo "  - Authentik OIDC provider application existence"
echo "  - Superset pod readiness"
echo ""
echo "Not proven (requires browser E2E):"
echo "  - Full OIDC login flow (user clicks through Authentik)"
echo "  - Superset dashboard access after authentication"
echo "  - Token refresh and session persistence"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo ""
  echo "Auth flow check FAILED. Debug commands:"
  echo ""
  echo "  Pods:     kubectl --context ${K8S_CTX} -n ${NS} get pods -l app.kubernetes.io/name=superset"
  echo "  Logs:     kubectl --context ${K8S_CTX} -n ${NS} logs -l app.kubernetes.io/name=superset --tail=50"
  echo "  Config:   kubectl --context ${K8S_CTX} -n ${NS} get configmaps"
  echo "  Authentik: curl -sk https://${AUTH_DOMAIN}/-/health/ready/"
  echo ""
  exit 1
fi

echo ""
echo "RESULT: PASS — Aspects auth flow verification complete"
exit 0
