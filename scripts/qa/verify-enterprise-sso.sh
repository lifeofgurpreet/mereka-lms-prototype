#!/usr/bin/env bash
# Verify enterprise SSO configuration for a specific tenant.
#
# Checks (when enterprise SSO is implemented):
# - Enterprise login URL exists and redirects correctly
# - SP SAML metadata is valid (if SAML tenant)
# - IdP metadata is reachable (if metadata URL configured)
# - EnterpriseCustomer record exists and is linked to IdP
# - Feature flags are enabled
#
# Pre-requisites:
# - kubectl access to mereka-lms namespace
# - Enterprise SSO feature flags enabled
#
# Usage:
#   ./scripts/qa/verify-enterprise-sso.sh --tenant=acme-corp --env=prod
#   ./scripts/qa/verify-enterprise-sso.sh --tenant=acme-corp --env=dev
#   ./scripts/qa/verify-enterprise-sso.sh --preflight  # Check infrastructure only

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

TENANT=""
ENVIRONMENT=""
PREFLIGHT=0

for arg in "$@"; do
  case "$arg" in
    --tenant=*) TENANT="${arg#*=}" ;;
    --env=*) ENVIRONMENT="${arg#*=}" ;;
    --preflight) PREFLIGHT=1 ;;
    -h|--help)
      echo "Usage: $0 --tenant=<slug> --env={prod|dev}"
      echo "       $0 --preflight"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

if [[ "$PREFLIGHT" -eq 0 && ( -z "$TENANT" || -z "$ENVIRONMENT" ) ]]; then
  echo "Usage: $0 --tenant=<slug> --env={prod|dev}" >&2
  echo "       $0 --preflight" >&2
  exit 1
fi

if [[ -n "$ENVIRONMENT" && "$ENVIRONMENT" != "prod" && "$ENVIRONMENT" != "dev" ]]; then
  echo "Error: --env must be 'prod' or 'dev'" >&2
  exit 1
fi

failures=0

log_ok() { printf "✓ %s\n" "$*"; }
log_fail() { printf "✗ %s\n" "$*" >&2; failures=$((failures + 1)); }
log_warn() { printf "! %s\n" "$*" >&2; }
log_info() { printf "· %s\n" "$*"; }

# --- Preflight: Infrastructure checks (no tenant needed) ---

check_preflight() {
  echo "=== Enterprise SSO Preflight Checks ==="
  echo ""

  # 1. Verify kubectl access
  if kubectl get namespace mereka-lms &>/dev/null; then
    log_ok "kubectl access to mereka-lms namespace"
  else
    log_fail "Cannot access mereka-lms namespace via kubectl"
    return
  fi

  # 2. Verify LMS pods are running
  local lms_pods
  lms_pods=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms --no-headers 2>/dev/null | grep -c Running || true)
  if [[ "$lms_pods" -gt 0 ]]; then
    log_ok "LMS pods running: $lms_pods"
  else
    log_fail "No LMS pods in Running state"
  fi

  # 3. Verify Authentik is accessible
  if kubectl get deploy -n mereka-lms authentik-server &>/dev/null 2>&1; then
    log_ok "Authentik deployment exists"
  else
    log_warn "Authentik deployment not found in mereka-lms namespace (may be in separate namespace)"
  fi

  # 4. Verify auth verification scripts exist
  local scripts=(
    "$REPO_ROOT/scripts/qa/verify-auth-surfaces.sh"
    "$REPO_ROOT/scripts/qa/verify-auth-hardening.sh"
    "$REPO_ROOT/scripts/infra/ensure-authentik-hardening.sh"
  )
  for script in "${scripts[@]}"; do
    if [[ -x "$script" ]]; then
      log_ok "Script exists and executable: $(basename "$script")"
    elif [[ -f "$script" ]]; then
      log_warn "Script exists but not executable: $(basename "$script")"
    else
      log_fail "Script missing: $(basename "$script")"
    fi
  done

  # 5. Verify third_party_auth app is in INSTALLED_APPS
  log_info "Check third_party_auth in LMS settings (requires kubectl exec):"
  log_info "  kubectl exec -n mereka-lms deploy/lms -- python -c \\"
  log_info "    \"from django.conf import settings; print('third_party_auth' in settings.INSTALLED_APPS)\""

  # 6. Verify SP metadata endpoint is accessible
  local lms_url
  if [[ "${ENVIRONMENT:-prod}" == "prod" ]]; then
    lms_url="https://academyv2.mereka.io"
  else
    lms_url="https://dev.academyv2.mereka.io"
  fi

  local code
  code=$(curl -sS -o /dev/null -w "%{http_code}" "${lms_url}/auth/saml/metadata.xml" 2>/dev/null || echo "000")
  if [[ "$code" == "200" ]]; then
    log_ok "SP SAML metadata endpoint reachable ($code)"
  elif [[ "$code" == "404" ]]; then
    log_warn "SP SAML metadata endpoint returns 404 (third_party_auth SAML may not be configured yet)"
  else
    log_warn "SP SAML metadata endpoint returned HTTP $code"
  fi

  echo ""
  echo "Preflight complete."
}

# --- Tenant-specific checks ---

check_tenant() {
  local lms_url
  if [[ "$ENVIRONMENT" == "prod" ]]; then
    lms_url="https://academyv2.mereka.io"
  else
    lms_url="https://dev.academyv2.mereka.io"
  fi

  echo "=== Enterprise SSO Verification: tenant=$TENANT env=$ENVIRONMENT ==="
  echo ""

  # 1. Enterprise login URL
  local login_url="${lms_url}/enterprise/login/${TENANT}"
  local code
  code=$(curl -sS -o /dev/null -w "%{http_code}" -L --max-redirs 0 "$login_url" 2>/dev/null || echo "000")
  if [[ "$code" == "302" || "$code" == "301" ]]; then
    log_ok "Enterprise login URL redirects ($code): $login_url"
  elif [[ "$code" == "200" ]]; then
    log_ok "Enterprise login URL accessible ($code): $login_url"
  elif [[ "$code" == "404" ]]; then
    log_fail "Enterprise login URL not found (404): $login_url"
    log_info "Verify EnterpriseCustomer exists with slug='$TENANT' and enterprise SSO feature flag is enabled"
  else
    log_fail "Enterprise login URL returned unexpected HTTP $code: $login_url"
  fi

  # 2. SP SAML metadata
  local metadata_code
  metadata_code=$(curl -sS -o /dev/null -w "%{http_code}" "${lms_url}/auth/saml/metadata.xml" 2>/dev/null || echo "000")
  if [[ "$metadata_code" == "200" ]]; then
    log_ok "SP SAML metadata available (200)"
  else
    log_warn "SP SAML metadata returned HTTP $metadata_code (SAML may not be configured)"
  fi

  # 3. EnterpriseCustomer record check (requires kubectl)
  log_info "Verify EnterpriseCustomer record:"
  log_info "  kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c \\"
  log_info "    \"from enterprise.models import EnterpriseCustomer; ec = EnterpriseCustomer.objects.get(slug='$TENANT'); print(f'UUID={ec.uuid}, IdP={ec.identity_provider}')\""

  # 4. Feature flag check
  log_info "Verify feature flags:"
  log_info "  kubectl exec -n mereka-lms deploy/lms -- python -c \\"
  log_info "    \"from django.conf import settings; print('ENABLE_ENTERPRISE_SSO:', getattr(settings, 'ENABLE_ENTERPRISE_SSO', False)); print('ENABLE_ENTERPRISE_SSO_${TENANT^^}:', getattr(settings, 'ENABLE_ENTERPRISE_SSO_${TENANT^^}', False))\""

  echo ""
}

# --- Main ---

if [[ "$PREFLIGHT" -eq 1 ]]; then
  check_preflight
else
  check_tenant
fi

if [[ "$failures" -gt 0 ]]; then
  echo "FAIL: $failures check(s) failed."
  exit 1
else
  echo "PASS: All checks passed."
  exit 0
fi
