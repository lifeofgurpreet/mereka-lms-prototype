#!/usr/bin/env bash
# verify-enterprise-frontend-live-contract.sh
# Runtime-only verification for live enterprise frontend contract parity.
#
# Verifies against a live cluster:
# - learner/admin runtime env contract inputs
# - learner and main-caddy route ownership
# - learner live bundle patch markers
# - admin live bundle absence of learner-only patch markers
#
# Exit codes:
#   0 = PASS
#   1 = FAIL
#   2 = INDETERMINATE (cluster/pod access unavailable)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

NAMESPACE="${NAMESPACE:-${K8S_NAMESPACE_DEV:-mereka-lms-dev}}"
KUBE_CONTEXT="${KUBE_CONTEXT:-}"

PASS=0
FAIL=0
INDET=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}  $1"; PASS=$((PASS + 1)); return 0; }
fail() { echo -e "${RED}FAIL${NC}  $1"; FAIL=$((FAIL + 1)); return 0; }
indet() { echo -e "${YELLOW}SKIP${NC}  $1"; INDET=$((INDET + 1)); return 0; }

kube() {
  if [[ -n "$KUBE_CONTEXT" ]]; then
    kubectl --context "$KUBE_CONTEXT" "$@"
  else
    kubectl "$@"
  fi
}

usage() {
  cat <<'EOF'
Usage: verify-enterprise-frontend-live-contract.sh [--namespace NS] [--context CTX]

Checks live enterprise learner/admin frontend parity against the merged route,
config, and patch contracts.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace)
      NAMESPACE="${2:-}"
      shift 2
      ;;
    --context)
      KUBE_CONTEXT="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if ! command -v kubectl >/dev/null 2>&1; then
  indet "kubectl not available"
  exit 2
fi

if ! kube get ns "$NAMESPACE" >/dev/null 2>&1; then
  indet "namespace not accessible: $NAMESPACE"
  exit 2
fi

pod_for_app() {
  local app_name="$1"
  kube get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=${app_name}" \
    --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

LEARNER_POD="$(pod_for_app enterprise-learner-portal)"
ADMIN_POD="$(pod_for_app enterprise-admin-portal)"
CADDY_POD="$(pod_for_app caddy)"

if [[ -z "$LEARNER_POD" || -z "$ADMIN_POD" || -z "$CADDY_POD" ]]; then
  indet "required live pods not all available in namespace ${NAMESPACE}"
  exit 2
fi

live_file_contains() {
  local pod="$1" file="$2" pattern="$3"
  kube exec -n "$NAMESPACE" "$pod" -- sh -lc "grep -F -q -- '$pattern' '$file'"
}

live_bundle_contains() {
  local pod="$1" pattern="$2"
  [[ "$(kube exec -n "$NAMESPACE" "$pod" -- sh -lc "if grep -R -F -q -- '$pattern' /openedx/dist/*.js; then printf yes; else printf no; fi")" == "yes" ]]
}

live_bundle_not_contains() {
  local pod="$1" pattern="$2"
  [[ "$(kube exec -n "$NAMESPACE" "$pod" -- sh -lc "if grep -R -F -q -- '$pattern' /openedx/dist/*.js; then printf yes; else printf no; fi")" == "no" ]]
}

echo "=== Enterprise Frontend Live Contract Verification ==="
echo "namespace=${NAMESPACE}"
[[ -n "$KUBE_CONTEXT" ]] && echo "context=${KUBE_CONTEXT}"
echo "learner_pod=${LEARNER_POD}"
echo "admin_pod=${ADMIN_POD}"
echo "caddy_pod=${CADDY_POD}"

# Runtime env contract
for pattern in \
  "INTEGRATION_WARNING_DISMISSED_COOKIE_NAME" \
  "integration-warning-dismissed" \
  "ENTERPRISE_ACCESS_BASE_URL: ''" \
  "ENTERPRISE_CATALOG_API_BASE_URL: ''" \
  "window.PARAGON_THEME" \
  "mereka-brand.min.css"; do
  if live_file_contains "$LEARNER_POD" /openedx/dist/env.config.js "$pattern"; then
    pass "learner env contains: $pattern"
  else
    fail "learner env missing: $pattern"
  fi
done

for pattern in \
  "INTEGRATION_WARNING_DISMISSED_COOKIE_NAME" \
  "integration-warning-dismissed" \
  "window.PARAGON_THEME" \
  "mereka-brand.min.css"; do
  if live_file_contains "$ADMIN_POD" /openedx/dist/env.config.js "$pattern"; then
    pass "admin env contains: $pattern"
  else
    fail "admin env missing: $pattern"
  fi
done

# Learner pod-local route ownership
for pattern in \
  "handle /api/v1/academies* {" \
  "handle /api/v1/enterprise-curations* {" \
  "handle /api/v1/highlight-sets* {" \
  "reverse_proxy enterprise-catalog:8160 {" \
  "handle /api/v1/* {" \
  "reverse_proxy enterprise-access:18270 {" \
  "handle /enterprise/* {" \
  "handle /csrf/* {" \
  "handle /oauth2/* {" \
  "handle /login {" \
  "handle /consent/* {"; do
  if live_file_contains "$LEARNER_POD" /etc/caddy/Caddyfile "$pattern"; then
    pass "learner caddy contains: $pattern"
  else
    fail "learner caddy missing: $pattern"
  fi
done

# Main caddy admin-host route split
for pattern in \
  "http://{\$ENTERPRISE_ADMIN_HOST} {" \
  "handle /api/enterprise-catalog/* {" \
  "reverse_proxy enterprise-catalog:8160 {" \
  "handle /api/enterprise-access/* {" \
  "reverse_proxy enterprise-access:18270 {"; do
  if live_file_contains "$CADDY_POD" /etc/caddy/Caddyfile "$pattern"; then
    pass "main caddy contains: $pattern"
  else
    fail "main caddy missing: $pattern"
  fi
done

# Learner live bundle patch markers
for pattern in \
  "integration-warning-dismissed" \
  "/api/v1/academies?" \
  "/api/v1/enterprise-curations/?" \
  "/api/v1/highlight-sets/?" \
  "/api/v1/customer-configurations/" \
  "couponCodeRedemptionCount:0" \
  "t&&t.validUntil&&await"; do
  if live_bundle_contains "$LEARNER_POD" "$pattern"; then
    pass "learner bundle contains: $pattern"
  else
    fail "learner bundle missing: $pattern"
  fi
done

# Admin should not carry learner-only bundle hardening markers
for pattern in \
  "couponCodeRedemptionCount:0" \
  "t&&t.validUntil&&await" \
  "/api/v1/academies?" \
  "/api/v1/customer-configurations/"; do
  if live_bundle_not_contains "$ADMIN_POD" "$pattern"; then
    pass "admin bundle omits learner-only marker: $pattern"
  else
    fail "admin bundle unexpectedly contains learner-only marker: $pattern"
  fi
done

echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} ${PASS}"
echo -e "${YELLOW}SKIP:${NC} ${INDET}"
echo -e "${RED}FAIL:${NC} ${FAIL}"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

if [[ "$INDET" -gt 0 ]]; then
  exit 2
fi

echo "ENTERPRISE_FRONTEND_LIVE_CONTRACT_OK"
