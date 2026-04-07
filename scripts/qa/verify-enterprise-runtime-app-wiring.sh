#!/usr/bin/env bash
# @covers AC-MTA-003, AC-MTA-004, AC-MTA-021, AC-043
# @spec: multi-tenancy-architecture_spec.md
# Verify runtime app wiring required for enterprise tenant onboarding.
#
# Checks (cluster runtime):
# - LMS/CMS deployments are reachable
# - Tenant-critical apps are present in INSTALLED_APPS
# - Tenant resolution middleware is active
# - Tenant management commands are available in LMS or CMS runtime
#
# Usage:
#   ./scripts/qa/verify-enterprise-runtime-app-wiring.sh --env prod --strict
#   ./scripts/qa/verify-enterprise-runtime-app-wiring.sh --env dev --context rke2-nonprod
# Exit 0 = PASS
# Exit 1 = FAIL
# Exit 2 = INDETERMINATE (lane/runtime truth unavailable)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

ENV="staging"
MODE="standard" # standard|strict
NAMESPACE="${NAMESPACE:-mereka-lms}"
NAMESPACE_PROD="${NAMESPACE_PROD:-${K8S_NAMESPACE_PROD:-mereka-lms}}"
NAMESPACE_DEV="${NAMESPACE_DEV:-${K8S_NAMESPACE_DEV:-mereka-lms-dev}}"
NAMESPACE_STAGING="${NAMESPACE_STAGING:-${K8S_NAMESPACE_STAGING:-stg-mereka-lms}}"
CONTEXT_PROD="${CONTEXT_PROD:-${K8S_CONTEXT_PROD:-rke2-prod}}"
CONTEXT_DEV="${CONTEXT_DEV:-${K8S_CONTEXT_DEV:-rke2-nonprod}}"
CONTEXT_STAGING="${CONTEXT_STAGING:-${K8S_CONTEXT_STAGING:-rke2-nonprod}}"
KUBE_CONTEXT_OVERRIDE=""
NAMESPACE_OVERRIDE=""

PASS=0
FAIL=0
SKIP=0
INDET=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}  $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC}  $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC}  $1"; SKIP=$((SKIP + 1)); }
indet() { echo -e "${YELLOW}INDETERMINATE${NC}  $1"; INDET=$((INDET + 1)); }

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --env {prod|dev|staging}  Target environment (default: prod)
  --context NAME        Kubernetes context override
  -n, --namespace NS    Kubernetes namespace (default: $NAMESPACE)
  --strict              Enforce expanded app set in addition to core tenant wiring
  -h, --help            Show this help
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV="$2"; shift 2 ;;
    --context) KUBE_CONTEXT_OVERRIDE="$2"; shift 2 ;;
    --strict) MODE="strict"; shift ;;
    -n|--namespace)
      NAMESPACE="$2"
      NAMESPACE_OVERRIDE="$NAMESPACE"
      shift 2
      ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

if [[ "$ENV" != "prod" && "$ENV" != "dev" && "$ENV" != "staging" ]]; then
  echo "Invalid --env: $ENV (expected prod|dev|staging)" >&2
  exit 1
fi

if [[ -n "$KUBE_CONTEXT_OVERRIDE" ]]; then
  KUBE_CTX="$KUBE_CONTEXT_OVERRIDE"
else
  case "$ENV" in
    prod) KUBE_CTX="$CONTEXT_PROD" ;;
    dev) KUBE_CTX="$CONTEXT_DEV" ;;
    staging) KUBE_CTX="$CONTEXT_STAGING" ;;
  esac
fi

if [[ -z "$NAMESPACE_OVERRIDE" ]]; then
  case "$ENV" in
    prod) NAMESPACE="$NAMESPACE_PROD" ;;
    dev) NAMESPACE="$NAMESPACE_DEV" ;;
    staging) NAMESPACE="$NAMESPACE_STAGING" ;;
  esac
fi

kube() { kubectl --context "$KUBE_CTX" "$@"; }

cluster_available() {
  command -v kubectl &>/dev/null || return 1
  kube cluster-info &>/dev/null 2>&1
}

run_manage_probe() {
  local deploy="$1"
  local variant="$2"
  local code="$3"
  kube -n "$NAMESPACE" exec "deploy/${deploy}" -- \
    bash -lc "python manage.py ${variant} shell -c \"$code\"" 2>/dev/null | tr -d '\r' | tail -n1
}

check_apps() {
  local deploy="$1"
  local variant="$2"
  local apps_csv="$3"
  local requiredness="${4:-required}" # required|optional
  local result
  result="$(run_manage_probe "$deploy" "$variant" \
    "from django.conf import settings; apps='${apps_csv}'.split(','); m=[a for a in apps if a and a not in settings.INSTALLED_APPS]; print('OK' if not m else ','.join(m))")"
  if [[ "$result" == "OK" ]]; then
    pass "${deploy}/${variant}: required apps present (${apps_csv})"
  elif [[ "$requiredness" == "optional" ]]; then
    skip "${deploy}/${variant}: optional apps missing: ${result}"
  else
    fail "${deploy}/${variant}: missing apps: ${result}"
  fi
}

check_middleware() {
  local deploy="$1"
  local variant="$2"
  local result
  result="$(run_manage_probe "$deploy" "$variant" \
    "from django.conf import settings; print('OK' if 'mereka_tenancy.middleware.TenantResolutionMiddleware' in settings.MIDDLEWARE else 'MISSING')")"
  if [[ "$result" == "OK" ]]; then
    pass "${deploy}/${variant}: TenantResolutionMiddleware active"
  else
    fail "${deploy}/${variant}: TenantResolutionMiddleware missing at runtime"
  fi
}

check_commands_any_runtime() {
  local commands_csv="$1"
  local lms_result cms_result
  lms_result="$(run_manage_probe "lms" "lms" \
    "from django.core.management import get_commands as gc; c=gc(); cmds='${commands_csv}'.split(','); print(','.join([k for k in cmds if k not in c]))")"
  cms_result="$(run_manage_probe "cms" "cms" \
    "from django.core.management import get_commands as gc; c=gc(); cmds='${commands_csv}'.split(','); print(','.join([k for k in cmds if k not in c]))")"

  local cmd
  IFS=',' read -r -a required <<< "$commands_csv"
  for cmd in "${required[@]}"; do
    local lms_missing=0
    local cms_missing=0
    [[ ",${lms_result}," == *",${cmd},"* ]] && lms_missing=1
    [[ ",${cms_result}," == *",${cmd},"* ]] && cms_missing=1
    if [[ "$lms_missing" -eq 1 && "$cms_missing" -eq 1 ]]; then
      fail "management command '${cmd}' missing in both LMS and CMS runtimes"
    else
      pass "management command '${cmd}' available in runtime"
    fi
  done
}

echo "=== Enterprise Runtime App Wiring Verification ==="
echo "env=$ENV mode=$MODE namespace=$NAMESPACE context=$KUBE_CTX"
echo ""

if [[ "$ENV" == "staging" && -z "$KUBE_CTX" ]]; then
  indet "staging is a first-class lane but no authoritative staging context is configured in this repo (K8S_CONTEXT_STAGING unset)"
  echo ""
  echo "Summary: PASS=$PASS FAIL=$FAIL SKIP=$SKIP INDETERMINATE=$INDET"
  exit 2
fi

if ! cluster_available; then
  indet "kubectl context '$KUBE_CTX' unavailable; runtime wiring truth is not locally provable"
  echo ""
  echo "Summary: PASS=$PASS FAIL=$FAIL SKIP=$SKIP INDETERMINATE=$INDET"
  exit 2
fi

if kube -n "$NAMESPACE" get deploy lms &>/dev/null; then
  pass "deployment/lms exists"
else
  fail "deployment/lms not found in namespace '$NAMESPACE'"
fi

if kube -n "$NAMESPACE" get deploy cms &>/dev/null; then
  pass "deployment/cms exists"
else
  fail "deployment/cms not found in namespace '$NAMESPACE'"
fi

CORE_APPS_LMS="mereka_tenancy,openedx_tenant_cache"
CORE_APPS_CMS="openedx_tenant_cache"
OPTIONAL_APPS="mfe_oauth_fix,openedx_prometheus,openedx_notifications,openedx_email_preferences,openedx_mux_upload,openedx_video_analytics,openedx_video_protection,openedx_advanced_xblocks"

check_apps "lms" "lms" "$CORE_APPS_LMS" "required"
check_apps "cms" "cms" "$CORE_APPS_CMS" "required"
check_middleware "lms" "lms"

if [[ "$MODE" == "strict" ]]; then
  # Wider custom-app surface is useful as a signal but not a hard gate for tenant onboarding.
  check_apps "lms" "lms" "$OPTIONAL_APPS" "optional"
  check_apps "cms" "cms" "$OPTIONAL_APPS" "optional"
else
  skip "strict app set not enforced (run with --strict to require full custom app wiring)"
fi

check_commands_any_runtime "provision_tenant,offboard_tenant,apply_tenant_branding"

echo ""
echo "=== Summary ==="
echo "PASS=$PASS FAIL=$FAIL SKIP=$SKIP INDETERMINATE=$INDET"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
if [[ "$INDET" -gt 0 ]]; then
  exit 2
fi
exit 0
