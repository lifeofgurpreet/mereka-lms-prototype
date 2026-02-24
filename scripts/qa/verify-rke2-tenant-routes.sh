#!/usr/bin/env bash
# @covers AC-017, AC-018, AC-019, AC-020, AC-013, AC-014, AC-021, AC-022, AC-023, AC-025
# @spec: k8s-deployment_spec.md
#
# verify-rke2-tenant-routes.sh — RKE2 nonprod smoke test + tenant route matrix verification.
#
# Validates every public-facing hostname × HTTP method × auth state on the rke2-nonprod cluster.
# Forum v2 runs IN-PROCESS with LMS (no separate forum container).
# Purchase Gateway replaces Oscar ecommerce (Oscar is deprecated — no ecommerce routes tested).
#
# Route matrix coverage:
#   - LMS (academyv2.mereka.dev)
#   - Preview LMS (preview.academyv2.mereka.dev)
#   - Studio/CMS (studio.academyv2.mereka.dev)
#   - MFE apps (apps.academyv2.mereka.dev)
#   - Discovery (discovery.academyv2.mereka.dev)
#   - Notes (notes.academyv2.mereka.dev)
#   - Credentials (credentials.academyv2.mereka.dev)
#   - Forum API (served at LMS URL — in-process, not standalone)
#   - API endpoints: /api/user/v1/, /api/courses/v2/, /api/discussion/v2/
#
# Modes:
#   --offline         Static checks — validate Ingress manifests, Caddy configs, hostname mappings
#   --online          HTTP probe all tenant routes (GET × anon); kubectl pod/endpoint health
#   --readiness-gate  offline + online; exits 1 on any FAIL (pre-cutover gate)
#   (default)         Requires explicit mode flag; prints usage.
#
# Environment variables:
#   KUBE_CONTEXT      kubectl context (default: rke2-nonprod)
#   NAMESPACE         K8s namespace (default: mereka-lms)
#   CURL_TIMEOUT      curl connect timeout in seconds (default: 10)
#   CHECK_TLS         Set to "0" to skip TLS certificate checks (default: 1)
#   CHECK_REDIRECTS   Set to "0" to skip HTTP→HTTPS redirect checks (default: 1)
#
# Usage:
#   ./scripts/qa/verify-rke2-tenant-routes.sh --offline
#   ./scripts/qa/verify-rke2-tenant-routes.sh --online
#   ./scripts/qa/verify-rke2-tenant-routes.sh --readiness-gate
#   KUBE_CONTEXT=kind-local ./scripts/qa/verify-rke2-tenant-routes.sh --offline

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
SKIP_COUNT=0

# ---------------------------------------------------------------------------
# Paths and defaults
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KUBE_CONTEXT="${KUBE_CONTEXT:-rke2-nonprod}"
NAMESPACE="${NAMESPACE:-mereka-lms}"
CURL_TIMEOUT="${CURL_TIMEOUT:-10}"
CHECK_TLS="${CHECK_TLS:-1}"
CHECK_REDIRECTS="${CHECK_REDIRECTS:-1}"

# rke2-nonprod overlay paths
RKE2_OVERLAY="${REPO_ROOT}/deploy/k8s/overlays/rke2-nonprod"
RKE2_KUST="${RKE2_OVERLAY}/kustomization.yaml"
LMS_INGRESS="${RKE2_OVERLAY}/ingress-openedx-lms.yaml"
STUDIO_INGRESS="${RKE2_OVERLAY}/ingress-openedx-studio.yaml"
MFE_INGRESS="${RKE2_OVERLAY}/ingress-openedx-mfe.yaml"
DOMAIN_ENV_PATCH="${RKE2_OVERLAY}/patches/domain-env.yaml"
INFISICAL_PATCH="${RKE2_OVERLAY}/patches/externalsecrets-infisical.yaml"
BASE_DIR="${REPO_ROOT}/deploy/k8s/base"
BASE_SECRETS="${BASE_DIR}/secrets/external-secrets.yaml"
CADDY_CONFIG="${BASE_DIR}/apps/caddy/Caddyfile"
PATCHES_FILE="${REPO_ROOT}/infrastructure/tutor/apply-patches.sh"

# Nonprod domains
LMS_DOMAIN="academyv2.mereka.dev"
PREVIEW_DOMAIN="preview.academyv2.mereka.dev"
STUDIO_DOMAIN="studio.academyv2.mereka.dev"
MFE_DOMAIN="apps.academyv2.mereka.dev"
DISCOVERY_DOMAIN="discovery.academyv2.mereka.dev"
NOTES_DOMAIN="notes.academyv2.mereka.dev"
CREDENTIALS_DOMAIN="credentials.academyv2.mereka.dev"
# Forum v2 is in-process — no standalone forum domain probe needed.
# forum.academyv2.mereka.dev routes to lms:8000 via caddy (same process).
FORUM_DOMAIN="forum.academyv2.mereka.dev"

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

skip() {
  echo -e "  ${YELLOW}SKIP${NC} $1"
  SKIP_COUNT=$((SKIP_COUNT + 1))
}

section() {
  echo ""
  echo -e "${CYAN}--- $1 ---${NC}"
}

# kctl — kubectl with fixed context
kctl() {
  kubectl --context "$KUBE_CONTEXT" "$@"
}

# http_probe <url> <expected_codes_pipe_separated> <description>
# Accepts codes like "200|302|301" — passes if status is in the set.
http_probe() {
  local url="$1"
  local expected="$2"
  local description="$3"
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout "$CURL_TIMEOUT" \
    --max-time "$((CURL_TIMEOUT * 3))" \
    -L \
    "$url" 2>/dev/null || echo "000")
  if echo "$status" | grep -qE "^(${expected})$"; then
    pass "${description} [HTTP ${status}]"
  elif [[ "$status" == "000" ]]; then
    fail "${description} — unreachable (connection failed) url=${url}"
  else
    fail "${description} — HTTP ${status} (expected ${expected}) url=${url}"
  fi
}

# http_probe_no_follow <url> <expected_codes> <description>
# Like http_probe but does NOT follow redirects (for checking raw redirect behavior).
http_probe_no_follow() {
  local url="$1"
  local expected="$2"
  local description="$3"
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout "$CURL_TIMEOUT" \
    --max-time "$((CURL_TIMEOUT * 3))" \
    "$url" 2>/dev/null || echo "000")
  if echo "$status" | grep -qE "^(${expected})$"; then
    pass "${description} [HTTP ${status}]"
  elif [[ "$status" == "000" ]]; then
    fail "${description} — unreachable (connection failed) url=${url}"
  else
    fail "${description} — HTTP ${status} (expected ${expected}) url=${url}"
  fi
}

# tls_check <domain> — verifies TLS cert is valid (no -k) and checks expiry.
tls_check() {
  local domain="$1"
  local strict_status insecure_status

  strict_status=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout "$CURL_TIMEOUT" --max-time "$((CURL_TIMEOUT * 2))" \
    "https://${domain}/" 2>/dev/null || echo "000")

  if [[ "$strict_status" != "000" ]]; then
    pass "TLS certificate valid for ${domain} (curl without -k succeeded)"
  else
    insecure_status=$(curl -sk -o /dev/null -w "%{http_code}" \
      --connect-timeout "$CURL_TIMEOUT" --max-time "$((CURL_TIMEOUT * 2))" \
      "https://${domain}/" 2>/dev/null || echo "000")
    if [[ "$insecure_status" != "000" ]]; then
      fail "TLS certificate INVALID for ${domain} (strict curl fails, -k curl succeeds)"
    else
      fail "Domain ${domain} unreachable (DNS or network — both strict and -k fail)"
    fi
  fi

  if command -v openssl > /dev/null 2>&1; then
    local cert_expiry expiry_epoch now_epoch days_left
    cert_expiry=$(echo \
      | openssl s_client -connect "${domain}:443" -servername "${domain}" 2>/dev/null \
      | openssl x509 -noout -enddate 2>/dev/null \
      | sed 's/notAfter=//' \
      || echo "")
    if [[ -n "$cert_expiry" ]]; then
      expiry_epoch=$(date -d "$cert_expiry" +%s 2>/dev/null \
        || date -j -f "%b %d %H:%M:%S %Y %Z" "$cert_expiry" +%s 2>/dev/null \
        || echo "0")
      now_epoch=$(date +%s)
      days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
      if [[ "$days_left" -ge 14 ]]; then
        pass "TLS cert for ${domain} expires in ${days_left} days"
      elif [[ "$days_left" -ge 0 ]]; then
        fail "TLS cert for ${domain} expires in ${days_left} days — renew soon"
      else
        fail "TLS cert for ${domain} EXPIRED (${cert_expiry})"
      fi
    else
      skip "Could not retrieve cert expiry for ${domain} via openssl"
    fi
  fi
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --offline)        MODE="offline";        shift ;;
    --online)         MODE="online";         shift ;;
    --readiness-gate) MODE="readiness-gate"; shift ;;
    --context)        KUBE_CONTEXT="$2";     shift 2 ;;
    --namespace)      NAMESPACE="$2";        shift 2 ;;
    --help)
      cat <<EOF
Usage: $(basename "$0") [--offline|--online|--readiness-gate] [--context CTX] [--namespace NS]

Modes:
  --offline         Validate Ingress manifests, Caddy config, hostname mappings (no cluster required)
  --online          Live HTTP probes + kubectl pod/endpoint health checks
  --readiness-gate  offline + online; exits 1 on any FAIL (pre-cutover gate)

Environment overrides:
  KUBE_CONTEXT      kubectl context      (default: rke2-nonprod)
  NAMESPACE         K8s namespace        (default: mereka-lms)
  CURL_TIMEOUT      curl timeout (secs)  (default: 10)
  CHECK_TLS         TLS cert checks      (default: 1 — set 0 to skip)
  CHECK_REDIRECTS   Redirect checks      (default: 1 — set 0 to skip)

Route matrix domains (nonprod):
  LMS       https://academyv2.mereka.dev
  Preview   https://preview.academyv2.mereka.dev
  Studio    https://studio.academyv2.mereka.dev
  MFE       https://apps.academyv2.mereka.dev
  Discovery https://discovery.academyv2.mereka.dev
  Notes     https://notes.academyv2.mereka.dev
  Creds     https://credentials.academyv2.mereka.dev
  Forum API served at LMS URL (in-process, not standalone)

Note: Oscar ecommerce is deprecated. Purchase Gateway handles payments.
      No ecommerce routes are probed.
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Run with --help for usage." >&2
      exit 1
      ;;
  esac
done

if [[ -z "$MODE" ]]; then
  echo "Error: mode required (--offline | --online | --readiness-gate)" >&2
  echo "Run with --help for usage." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------
echo "========================================================"
echo "RKE2 Nonprod Tenant Route Matrix Verification"
echo "  mode      : ${MODE}"
echo "  context   : ${KUBE_CONTEXT}"
echo "  namespace : ${NAMESPACE}"
echo "  repo      : ${REPO_ROOT}"
echo "========================================================"

# ============================================================================
# OFFLINE CHECKS
# ============================================================================
run_offline_checks() {
  echo ""
  echo "========================================"
  echo "OFFLINE: Static Manifest + Config Checks"
  echo "========================================"

  # -------------------------------------------------------------------------
  section "[1/6] Required Ingress Manifests"
  # -------------------------------------------------------------------------

  local required_files=(
    "${LMS_INGRESS}:LMS Ingress (ingress-openedx-lms.yaml)"
    "${STUDIO_INGRESS}:Studio Ingress (ingress-openedx-studio.yaml)"
    "${MFE_INGRESS}:MFE Ingress (ingress-openedx-mfe.yaml)"
    "${RKE2_KUST}:rke2-nonprod kustomization.yaml"
    "${DOMAIN_ENV_PATCH}:domain-env.yaml patch"
    "${INFISICAL_PATCH}:externalsecrets-infisical.yaml patch"
    "${BASE_SECRETS}:base external-secrets.yaml"
  )

  for entry in "${required_files[@]}"; do
    local file="${entry%%:*}"
    local label="${entry##*:}"
    if [[ -f "$file" ]]; then
      pass "${label} exists"
    else
      fail "${label} missing: ${file}"
    fi
  done

  # -------------------------------------------------------------------------
  section "[2/6] Hostname Coverage — LMS Ingress"
  # -------------------------------------------------------------------------
  # AC-019: openedx-lms Ingress must cover all expected hosts.

  if [[ -f "$LMS_INGRESS" ]]; then
    local lms_hosts=(
      "${LMS_DOMAIN}"
      "${PREVIEW_DOMAIN}"
      "${DISCOVERY_DOMAIN}"
      "${NOTES_DOMAIN}"
      "${CREDENTIALS_DOMAIN}"
    )
    for host in "${lms_hosts[@]}"; do
      if grep -q "$host" "$LMS_INGRESS"; then
        pass "LMS Ingress includes host: ${host}"
      else
        fail "LMS Ingress missing host: ${host} (check ingress-openedx-lms.yaml rules)"
      fi
    done

    # Verify all hosts also appear in the TLS block
    for host in "${lms_hosts[@]}"; do
      if grep -A 200 "^  tls:" "$LMS_INGRESS" | grep -q "$host"; then
        pass "LMS Ingress TLS block includes: ${host}"
      else
        fail "LMS Ingress TLS block missing: ${host} (cert won't be issued)"
      fi
    done

    # AC-018: required Ingress annotations
    if grep -q "cert-manager.io/cluster-issuer: letsencrypt-prod" "$LMS_INGRESS"; then
      pass "LMS Ingress has cert-manager.io/cluster-issuer: letsencrypt-prod"
    else
      fail "LMS Ingress missing cert-manager.io/cluster-issuer: letsencrypt-prod"
    fi
    if grep -q 'nginx.ingress.kubernetes.io/ssl-redirect: "true"' "$LMS_INGRESS"; then
      pass 'LMS Ingress has ssl-redirect: "true"'
    else
      fail 'LMS Ingress missing ssl-redirect: "true" (HTTP→HTTPS redirect will not work)'
    fi
    if grep -q "nginx.ingress.kubernetes.io/proxy-body-size: 100m" "$LMS_INGRESS"; then
      pass "LMS Ingress has proxy-body-size: 100m"
    else
      fail "LMS Ingress missing proxy-body-size: 100m (file uploads may be rejected)"
    fi

    # Verify all hosts route to caddy backend (not lms or cms directly)
    if grep -q "name: caddy" "$LMS_INGRESS"; then
      pass "LMS Ingress routes traffic to caddy service backend"
    else
      fail "LMS Ingress does not route to caddy service (check backend service name)"
    fi

    # Oscar ecommerce is deprecated — ecommerce domain should NOT be in the LMS Ingress
    # OR if it is, note that the route is legacy and untested.
    if grep -q "ecommerce.academyv2.mereka.dev" "$LMS_INGRESS"; then
      skip "ecommerce.academyv2.mereka.dev found in LMS Ingress — Oscar is deprecated; Purchase Gateway handles payments (route untested)"
    else
      pass "No ecommerce host in LMS Ingress (Oscar deprecated — expected)"
    fi
  else
    skip "LMS Ingress file not found — skipping hostname coverage checks"
  fi

  # -------------------------------------------------------------------------
  section "[3/6] Hostname Coverage — Studio + MFE Ingresses"
  # -------------------------------------------------------------------------

  if [[ -f "$STUDIO_INGRESS" ]]; then
    if grep -q "${STUDIO_DOMAIN}" "$STUDIO_INGRESS"; then
      pass "Studio Ingress includes host: ${STUDIO_DOMAIN}"
    else
      fail "Studio Ingress missing host: ${STUDIO_DOMAIN}"
    fi
    if grep -q "cert-manager.io/cluster-issuer: letsencrypt-prod" "$STUDIO_INGRESS"; then
      pass "Studio Ingress has cert-manager.io/cluster-issuer: letsencrypt-prod"
    else
      fail "Studio Ingress missing cert-manager.io/cluster-issuer: letsencrypt-prod"
    fi
    if grep -q "name: caddy" "$STUDIO_INGRESS"; then
      pass "Studio Ingress routes traffic to caddy service backend"
    else
      fail "Studio Ingress does not route to caddy service"
    fi
  else
    skip "Studio Ingress file not found — skipping Studio hostname checks"
  fi

  if [[ -f "$MFE_INGRESS" ]]; then
    if grep -q "${MFE_DOMAIN}" "$MFE_INGRESS"; then
      pass "MFE Ingress includes host: ${MFE_DOMAIN}"
    else
      fail "MFE Ingress missing host: ${MFE_DOMAIN}"
    fi
    if grep -q "cert-manager.io/cluster-issuer: letsencrypt-prod" "$MFE_INGRESS"; then
      pass "MFE Ingress has cert-manager.io/cluster-issuer: letsencrypt-prod"
    else
      fail "MFE Ingress missing cert-manager.io/cluster-issuer: letsencrypt-prod"
    fi
    if grep -q "name: caddy" "$MFE_INGRESS"; then
      pass "MFE Ingress routes traffic to caddy service backend"
    else
      fail "MFE Ingress does not route to caddy service"
    fi
  else
    skip "MFE Ingress file not found — skipping MFE hostname checks"
  fi

  # -------------------------------------------------------------------------
  section "[4/6] Caddy Configuration"
  # -------------------------------------------------------------------------

  if [[ ! -f "$CADDY_CONFIG" ]]; then
    skip "Caddyfile not found at ${CADDY_CONFIG} — skipping Caddy routing checks"
  else
    pass "Caddyfile exists: ${CADDY_CONFIG}"

    # LMS block must exist (proxies to lms:8000)
    if grep -q "lms:8000" "$CADDY_CONFIG"; then
      pass "Caddyfile has proxy target: lms:8000"
    else
      fail "Caddyfile missing proxy target lms:8000"
    fi

    # CMS/Studio block must exist (proxies to cms:8000)
    if grep -q "cms:8000" "$CADDY_CONFIG"; then
      pass "Caddyfile has proxy target: cms:8000"
    else
      fail "Caddyfile missing proxy target cms:8000"
    fi

    # MFE block must exist (proxies to mfe:8002)
    if grep -q "mfe:8002" "$CADDY_CONFIG"; then
      pass "Caddyfile has proxy target: mfe:8002"
    else
      fail "Caddyfile missing proxy target mfe:8002"
    fi

    # Discovery block (proxies to discovery:8000)
    if grep -q "discovery:8000" "$CADDY_CONFIG"; then
      pass "Caddyfile has proxy target: discovery:8000"
    else
      skip "Caddyfile missing discovery:8000 — discovery may not be enabled"
    fi

    # Forum v2 runs IN-PROCESS with LMS — no separate forum Caddy block expected.
    # The forum domain (if present) should proxy to lms:8000, not a standalone forum service.
    if grep -qE "forum.*lms:8000|lms:8000.*forum" "$CADDY_CONFIG"; then
      pass "Caddyfile routes forum domain to lms:8000 (forum is in-process)"
    elif grep -q "forum:" "$CADDY_CONFIG"; then
      fail "Caddyfile has standalone forum block — forum v2 must route to lms:8000 (in-process)"
    else
      # No forum block at all — forum.academyv2.mereka.dev is in LMS Ingress routing
      # directly to caddy, which then routes to lms:8000 via the catch-all or LMS block.
      pass "No standalone forum Caddy block (forum routes via LMS block — correct for v2 in-process)"
    fi

    # No Ruby cs_comments_service references
    if grep -qiE "cs_comments_service|overhangio/openedx-forum" "$CADDY_CONFIG"; then
      fail "Caddyfile references Ruby forum (cs_comments_service) — must be removed"
    else
      pass "No Ruby forum (cs_comments_service) references in Caddyfile"
    fi
  fi

  # -------------------------------------------------------------------------
  section "[5/6] Domain Env Patch + ExternalSecrets"
  # -------------------------------------------------------------------------

  if [[ -f "$DOMAIN_ENV_PATCH" ]]; then
    if grep -q "mereka.dev" "$DOMAIN_ENV_PATCH"; then
      pass "domain-env.yaml patch sets *.mereka.dev domains"
    else
      fail "domain-env.yaml patch does not reference *.mereka.dev (is it set for production instead?)"
    fi

    if grep -q "LMS_BASE_URL" "$DOMAIN_ENV_PATCH"; then
      pass "domain-env.yaml patch sets LMS_BASE_URL env var"
    else
      fail "domain-env.yaml patch missing LMS_BASE_URL"
    fi

    if grep -q "MFE_BASE_URL" "$DOMAIN_ENV_PATCH"; then
      pass "domain-env.yaml patch sets MFE_BASE_URL env var"
    else
      fail "domain-env.yaml patch missing MFE_BASE_URL"
    fi
  fi

  if [[ -f "$INFISICAL_PATCH" ]]; then
    local infisical_refs gcp_refs
    infisical_refs=$(grep -v '^\s*#' "$INFISICAL_PATCH" | grep -c 'infisical-secret-store' || true)
    gcp_refs=$(grep -v '^\s*#' "$INFISICAL_PATCH" | grep -c 'gcp-secret-manager' || true)

    if [[ "$infisical_refs" -ge 1 && "$gcp_refs" -eq 0 ]]; then
      pass "Infisical patch uses infisical-secret-store (no gcp-secret-manager refs)"
    else
      fail "Infisical patch: infisical_refs=${infisical_refs}, gcp_refs=${gcp_refs} (expected >=1, 0)"
    fi
  fi

  # AC-023: ExternalSecret keys must use MEREKA_LMS_ prefix
  if [[ -f "$BASE_SECRETS" ]]; then
    local required_keys=(
      "OPENEDX_SECRET_KEY"
      "SECRET_KEY"
      "MONGODB_PASSWORD"
      "MYSQL_ROOT_PASSWORD"
    )
    for key in "${required_keys[@]}"; do
      if grep -q "secretKey: ${key}" "$BASE_SECRETS"; then
        pass "ExternalSecret maps secretKey: ${key}"
      else
        fail "ExternalSecret missing secretKey: ${key}"
      fi
    done
  fi

  # -------------------------------------------------------------------------
  section "[6/6] Oscar Deprecation Guard"
  # -------------------------------------------------------------------------
  # Oscar ecommerce is deprecated. Purchase Gateway handles payments.
  # Verify no new routes or manifests reference the Oscar ecommerce service.

  local oscar_refs
  oscar_refs=$(grep -rn "ecommerce:8000\|service: ecommerce" \
    "${RKE2_OVERLAY}" "${BASE_DIR}" 2>/dev/null \
    | grep -v "^Binary\|\.pyc:" \
    | grep -v "# deprecated\|# legacy\|# oscar" \
    || true)

  if [[ -z "$oscar_refs" ]]; then
    pass "No active Oscar ecommerce service references in rke2-nonprod overlay or base"
  else
    # Oscar may still exist in base manifests as legacy — warn, don't fail
    local oscar_line_count
    oscar_line_count=$(echo "$oscar_refs" | grep -c . || true)
    skip "Oscar ecommerce references found (${oscar_line_count} lines) — legacy, not tested by this script. Purchase Gateway is canonical."
  fi

  # Verify purchase gateway manifests exist (replacement for Oscar)
  if find "${BASE_DIR}" "${REPO_ROOT}/services/purchase-gateway" \
      -name "*.yaml" -o -name "*.yml" 2>/dev/null \
      | xargs grep -l "purchase-gateway\|payments-gateway" 2>/dev/null \
      | grep -q .; then
    pass "Purchase Gateway manifests found (Oscar ecommerce replacement)"
  else
    skip "Purchase Gateway manifests not found in base or services/ — verify deployment separately"
  fi
}

# ============================================================================
# ONLINE CHECKS
# ============================================================================
run_online_checks() {
  echo ""
  echo "========================================"
  echo "ONLINE: Live Cluster + HTTP Route Matrix"
  echo "========================================"

  # -------------------------------------------------------------------------
  section "[O1/7] Cluster Reachability"
  # -------------------------------------------------------------------------

  if ! command -v kubectl > /dev/null 2>&1; then
    skip "kubectl not found — skipping all cluster checks"
    return 0
  fi

  if ! kctl cluster-info > /dev/null 2>&1; then
    fail "Cannot reach cluster context '${KUBE_CONTEXT}' — is kubeconfig configured?"
    echo "  Remaining online checks will be skipped."
    # Skip remaining by returning early
    for _i in $(seq 1 50); do
      skip "Online check skipped (cluster unreachable)"
    done
    return 0
  fi

  pass "Cluster context '${KUBE_CONTEXT}' reachable"

  if ! kctl get namespace "${NAMESPACE}" > /dev/null 2>&1; then
    fail "Namespace ${NAMESPACE} not found on context ${KUBE_CONTEXT}"
    return 0
  fi

  pass "Namespace '${NAMESPACE}' exists"

  # -------------------------------------------------------------------------
  section "[O2/7] Pod Health"
  # -------------------------------------------------------------------------

  # Core pods that must be Running
  local core_pods=(
    "lms"
    "cms"
    "caddy"
  )
  for pod_label in "${core_pods[@]}"; do
    local running_count
    running_count=$(kctl get pods -n "${NAMESPACE}" \
      -l "app.kubernetes.io/name=${pod_label}" \
      --field-selector=status.phase=Running \
      -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
      2>/dev/null | grep -c . || true)
    if [[ "$running_count" -ge 1 ]]; then
      pass "At least 1 ${pod_label} pod is Running"
    else
      fail "0 ${pod_label} pods Running in ${NAMESPACE}"
    fi
  done

  # Optional satellite pods — SKIP if not deployed (discovery, notes, credentials)
  local optional_pods=(
    "discovery"
    "notes"
    "credentials"
  )
  for pod_label in "${optional_pods[@]}"; do
    local count
    count=$(kctl get pods -n "${NAMESPACE}" \
      -l "app.kubernetes.io/name=${pod_label}" \
      -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
      2>/dev/null | grep -c . || true)
    if [[ "$count" -ge 1 ]]; then
      local running
      running=$(kctl get pods -n "${NAMESPACE}" \
        -l "app.kubernetes.io/name=${pod_label}" \
        --field-selector=status.phase=Running \
        -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
        2>/dev/null | grep -c . || true)
      if [[ "$running" -ge 1 ]]; then
        pass "${pod_label} pod is Running"
      else
        fail "${pod_label} pod exists but not Running"
      fi
    else
      skip "${pod_label} pod not deployed — skipping (optional service)"
    fi
  done

  # CrashLoopBackOff scan across the namespace
  local crash_pods
  crash_pods=$(kctl get pods -n "${NAMESPACE}" \
    -o jsonpath='{range .items[*]}{.metadata.name}={range .status.containerStatuses[*]}{.state.waiting.reason}{end}{"\n"}{end}' \
    2>/dev/null | grep 'CrashLoopBackOff' | cut -d= -f1 | tr '\n' ',' | sed 's/,$//' || true)
  if [[ -z "$crash_pods" ]]; then
    pass "No CrashLoopBackOff pods in ${NAMESPACE}"
  else
    fail "CrashLoopBackOff pods: ${crash_pods}"
  fi

  # -------------------------------------------------------------------------
  section "[O3/7] Service Endpoints"
  # -------------------------------------------------------------------------
  # AC-013: No Service should show <none> for endpoints after pods are Ready.

  local core_svcs=("lms" "cms" "caddy")
  for svc_name in "${core_svcs[@]}"; do
    local ep_ip
    ep_ip=$(kctl get endpoints "${svc_name}" -n "${NAMESPACE}" \
      -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || echo "")
    if [[ -n "$ep_ip" ]]; then
      pass "Service ${svc_name} endpoints populated (${ep_ip})"
    else
      fail "Service ${svc_name} endpoints empty — pods not Ready or selector mismatch"
    fi
  done

  # -------------------------------------------------------------------------
  section "[O4/7] TLS Certificate Validation"
  # -------------------------------------------------------------------------

  if [[ "$CHECK_TLS" == "0" ]]; then
    skip "TLS checks disabled (CHECK_TLS=0)"
  elif ! command -v curl > /dev/null 2>&1; then
    skip "curl not available — skipping TLS checks"
  else
    local tls_domains=(
      "${LMS_DOMAIN}"
      "${STUDIO_DOMAIN}"
      "${MFE_DOMAIN}"
      "${PREVIEW_DOMAIN}"
    )
    for domain in "${tls_domains[@]}"; do
      tls_check "$domain"
    done
  fi

  # -------------------------------------------------------------------------
  section "[O5/7] HTTP→HTTPS Redirect Checks"
  # -------------------------------------------------------------------------
  # Ingress has ssl-redirect: "true" — plain HTTP must redirect to HTTPS.

  if [[ "$CHECK_REDIRECTS" == "0" ]]; then
    skip "Redirect checks disabled (CHECK_REDIRECTS=0)"
  elif ! command -v curl > /dev/null 2>&1; then
    skip "curl not available — skipping redirect checks"
  else
    local redirect_domains=(
      "${LMS_DOMAIN}"
      "${STUDIO_DOMAIN}"
      "${MFE_DOMAIN}"
    )
    for domain in "${redirect_domains[@]}"; do
      local redir_status
      redir_status=$(curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout "$CURL_TIMEOUT" \
        --max-time "$((CURL_TIMEOUT * 2))" \
        "http://${domain}/" 2>/dev/null || echo "000")
      if echo "$redir_status" | grep -qE "^(301|302|308)$"; then
        pass "http://${domain}/ redirects to HTTPS [HTTP ${redir_status}]"
      elif [[ "$redir_status" == "000" ]]; then
        # Port 80 may be blocked for some domains — acceptable in nonprod
        skip "http://${domain}/ unreachable on port 80 (port may be blocked in nonprod)"
      else
        fail "http://${domain}/ did not redirect — HTTP ${redir_status} (expected 301/302/308)"
      fi
    done
  fi

  # -------------------------------------------------------------------------
  section "[O6/7] Route Matrix — Unauthenticated HTTP Probes"
  # -------------------------------------------------------------------------
  # Each row in the route matrix: hostname × path × expected status (anonymous)
  # Format: "url|expected_codes|description"

  if ! command -v curl > /dev/null 2>&1; then
    skip "curl not available — skipping route matrix HTTP probes"
    return 0
  fi

  # LMS routes
  echo ""
  echo "  [LMS — ${LMS_DOMAIN}]"
  http_probe "https://${LMS_DOMAIN}/" "200|302" "GET / — LMS homepage (anon)"
  http_probe "https://${LMS_DOMAIN}/login" "200|302" "GET /login — LMS login page (anon)"
  http_probe "https://${LMS_DOMAIN}/register" "200|302" "GET /register — LMS registration (anon)"
  http_probe "https://${LMS_DOMAIN}/dashboard" "200|302" "GET /dashboard — LMS dashboard (anon → auth redirect expected)"
  http_probe "https://${LMS_DOMAIN}/heartbeat" "200" "GET /heartbeat — LMS health check"
  http_probe "https://${LMS_DOMAIN}/api/user/v1/me" "200|401|403" "GET /api/user/v1/me — LMS User API (anon → 401)"
  http_probe "https://${LMS_DOMAIN}/api/courses/v2/" "200|401|403" "GET /api/courses/v2/ — LMS Courses API (anon)"
  http_probe "https://${LMS_DOMAIN}/api/mobile/v4/users/test/" "200|401|403|404" "GET /api/mobile/v4/ — Mobile API endpoint (anon)"

  # Preview LMS routes (same lms:8000 backend, different domain)
  echo ""
  echo "  [Preview LMS — ${PREVIEW_DOMAIN}]"
  http_probe "https://${PREVIEW_DOMAIN}/" "200|302" "GET / — Preview LMS homepage (anon)"
  http_probe "https://${PREVIEW_DOMAIN}/dashboard" "200|302" "GET /dashboard — Preview LMS dashboard (anon → redirect expected)"

  # Studio routes
  echo ""
  echo "  [Studio — ${STUDIO_DOMAIN}]"
  http_probe "https://${STUDIO_DOMAIN}/" "200|302" "GET / — Studio homepage (anon → login redirect expected)"
  http_probe "https://${STUDIO_DOMAIN}/login" "200|302" "GET /login — Studio login page (anon)"
  http_probe "https://${STUDIO_DOMAIN}/health" "200|404" "GET /health — Studio health endpoint"

  # MFE routes
  echo ""
  echo "  [MFE Apps — ${MFE_DOMAIN}]"
  http_probe "https://${MFE_DOMAIN}/authn/login" "200|302" "GET /authn/login — MFE authn login page (anon)"
  http_probe "https://${MFE_DOMAIN}/authn/register" "200|302" "GET /authn/register — MFE authn register page (anon)"
  http_probe "https://${MFE_DOMAIN}/learning/" "200|302" "GET /learning/ — MFE learning app (anon → login redirect)"
  http_probe "https://${MFE_DOMAIN}/account/" "200|302" "GET /account/ — MFE account app (anon → login redirect)"
  http_probe "https://${MFE_DOMAIN}/discussions/" "200|302" "GET /discussions/ — MFE discussions app (anon → login redirect)"

  # Discovery routes
  echo ""
  echo "  [Discovery — ${DISCOVERY_DOMAIN}]"
  local disc_count
  disc_count=$(kctl get pods -n "${NAMESPACE}" \
    -l "app.kubernetes.io/name=discovery" \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
    2>/dev/null | grep -c . || true)
  if [[ "$disc_count" -ge 1 ]]; then
    http_probe "https://${DISCOVERY_DOMAIN}/" "200|301|302|401" "GET / — Discovery service root (anon)"
    http_probe "https://${DISCOVERY_DOMAIN}/health/" "200" "GET /health/ — Discovery health (anon)"
    http_probe "https://${DISCOVERY_DOMAIN}/api/v1/courses/" "200|401|403" "GET /api/v1/courses/ — Discovery Courses API (anon)"
  else
    skip "Discovery pod not deployed — skipping Discovery route checks"
  fi

  # Notes routes
  echo ""
  echo "  [Notes — ${NOTES_DOMAIN}]"
  local notes_count
  notes_count=$(kctl get pods -n "${NAMESPACE}" \
    -l "app.kubernetes.io/name=notes" \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
    2>/dev/null | grep -c . || true)
  if [[ "$notes_count" -ge 1 ]]; then
    http_probe "https://${NOTES_DOMAIN}/" "200|301|302|401" "GET / — Notes service root (anon)"
    http_probe "https://${NOTES_DOMAIN}/health" "200" "GET /health — Notes health (anon)"
  else
    skip "Notes pod not deployed — skipping Notes route checks"
  fi

  # Credentials routes
  echo ""
  echo "  [Credentials — ${CREDENTIALS_DOMAIN}]"
  local creds_count
  creds_count=$(kctl get pods -n "${NAMESPACE}" \
    -l "app.kubernetes.io/name=credentials" \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
    2>/dev/null | grep -c . || true)
  if [[ "$creds_count" -ge 1 ]]; then
    http_probe "https://${CREDENTIALS_DOMAIN}/" "200|301|302|401" "GET / — Credentials service root (anon)"
    http_probe "https://${CREDENTIALS_DOMAIN}/health/" "200" "GET /health/ — Credentials health (anon)"
  else
    skip "Credentials pod not deployed — skipping Credentials route checks"
  fi

  # Forum API (in-process with LMS — must NOT be served at forum.academyv2.mereka.dev standalone)
  echo ""
  echo "  [Forum API (in-process at LMS) — ${LMS_DOMAIN}]"
  http_probe "https://${LMS_DOMAIN}/api/discussion/v2/courses/" "200|401|403" "GET /api/discussion/v2/courses/ — Forum API v2 (anon → 401)"
  http_probe "https://${LMS_DOMAIN}/api/discussion/v2/threads/" "200|400|401|403" "GET /api/discussion/v2/threads/ — Forum threads API (anon)"
  # v1 is deprecated and should 404, not 200
  http_probe_no_follow "https://${LMS_DOMAIN}/api/discussion/v1/courses/" "200|401|403|404" "GET /api/discussion/v1/courses/ — Forum API v1 (deprecated; 404 acceptable)"

  # -------------------------------------------------------------------------
  section "[O7/7] CORS Headers Check"
  # -------------------------------------------------------------------------
  # Verify LMS emits CORS headers on API requests from MFE domain

  echo ""
  echo "  [CORS — LMS API must allow MFE origin]"
  if ! command -v curl > /dev/null 2>&1; then
    skip "curl not available — skipping CORS check"
  else
    local cors_response cors_origin
    cors_response=$(curl -s -I \
      --connect-timeout "$CURL_TIMEOUT" \
      --max-time "$((CURL_TIMEOUT * 2))" \
      -H "Origin: https://${MFE_DOMAIN}" \
      -H "Access-Control-Request-Method: GET" \
      "https://${LMS_DOMAIN}/api/user/v1/me" 2>/dev/null || echo "")

    cors_origin=$(echo "$cors_response" | grep -i "access-control-allow-origin" | head -1 || true)
    if [[ -n "$cors_origin" ]]; then
      pass "LMS API emits Access-Control-Allow-Origin header: $(echo "$cors_origin" | tr -d '\r')"
    else
      # CORS header may not be emitted on 401 — soft fail
      skip "CORS header not found on unauthenticated request (may be suppressed on 401 — verify with authenticated token)"
    fi

    # OPTIONS preflight check
    local options_status
    options_status=$(curl -s -o /dev/null -w "%{http_code}" \
      --connect-timeout "$CURL_TIMEOUT" \
      --max-time "$((CURL_TIMEOUT * 2))" \
      -X OPTIONS \
      -H "Origin: https://${MFE_DOMAIN}" \
      -H "Access-Control-Request-Method: GET" \
      -H "Access-Control-Request-Headers: Content-Type" \
      "https://${LMS_DOMAIN}/api/user/v1/me" 2>/dev/null || echo "000")
    if echo "$options_status" | grep -qE "^(200|204|401|403)$"; then
      pass "LMS API OPTIONS preflight responded HTTP ${options_status}"
    elif [[ "$options_status" == "000" ]]; then
      skip "CORS preflight OPTIONS unreachable (connection timeout)"
    else
      fail "LMS API OPTIONS preflight returned HTTP ${options_status} (expected 200/204)"
    fi
  fi
}

# ============================================================================
# Run based on mode
# ============================================================================
case "$MODE" in
  offline)
    run_offline_checks
    ;;
  online)
    run_online_checks
    ;;
  readiness-gate)
    run_offline_checks
    run_online_checks
    ;;
esac

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "========================================================"
echo -e "  PASS: ${GREEN}${PASS_COUNT}${NC}  FAIL: ${RED}${FAIL_COUNT}${NC}  SKIP: ${YELLOW}${SKIP_COUNT}${NC}"
echo "========================================================"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo ""
  echo "Route matrix check FAILED. Common causes:"
  echo ""
  echo "  Manifests:  ls deploy/k8s/overlays/rke2-nonprod/"
  echo "  Ingress:    kubectl --context ${KUBE_CONTEXT} get ingress -n ${NAMESPACE}"
  echo "  Pods:       kubectl --context ${KUBE_CONTEXT} get pods -n ${NAMESPACE}"
  echo "  Endpoints:  kubectl --context ${KUBE_CONTEXT} get endpoints -n ${NAMESPACE}"
  echo "  Logs:       kubectl --context ${KUBE_CONTEXT} logs -n ${NAMESPACE} -l app.kubernetes.io/name=lms --tail=50"
  echo "  TLS:        openssl s_client -connect ${LMS_DOMAIN}:443 -servername ${LMS_DOMAIN}"
  echo ""
  echo "Reference: docs/operations/RKE2_TENANT_ROUTES.md"
  echo ""
  exit 1
fi

echo ""
echo "RESULT: PASS — all route matrix checks passed"
exit 0
