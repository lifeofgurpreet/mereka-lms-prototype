#!/usr/bin/env bash
# @covers AC-043, AC-005, AC-004
# @spec: auth-sso-enterprise_spec.md
#
# verify-enterprise-sso-readiness.sh — Enterprise SSO Phase 0 readiness audit.
#
# This script is the AC-043 verification entry point for auth-sso-enterprise_spec.md.
# It does NOT overlap with verify-enterprise-sso.sh (which covers
# enterprise-microservices_spec.md Phase 4: integrated channels).
#
# Checks:
#   Repo-level (no kubectl required):
#     1. ExternalSecret definition contains all four enterprise-sso-secrets keys
#     2. ENABLE_ENTERPRISE_INTEGRATION flag is set in mereka_lms.py
#     3. SAML keypair generation script exists and is executable
#     4. configure-tenant-idp.sh exists and is implemented
#     5. OIDC cookie middleware order guard passes (OIDC session prerequisite)
#     6. DISABLE_ENTERPRISE_LOGIN present in lms/production.py MFE_CONFIG
#     7. auth-sso-enterprise_spec.md exists
#     8. verify-auth-surfaces.sh exists (AC-042 dependency)
#
#   Live cluster (requires kubectl):
#     9.  enterprise-sso-secrets K8s Secret exists (GCP secrets populated)
#    10.  Each of the four expected keys present in the K8s Secret
#    11.  ExternalSecret enterprise-sso-secrets is in Ready/Synced state
#    12.  LMS pod is running
#    13.  openedx-enterprise package is installed in LMS pod
#    14.  SAML auth backend (social_core) is importable in LMS pod
#    15.  ENABLE_ENTERPRISE_INTEGRATION is True at LMS runtime
#    16.  SAML SP metadata endpoint responds (AC-005)
#    17.  Authentik OIDC baseline still works (AC-004 — non-enterprise users)
#
#   Per-tenant (requires --tenant and kubectl):
#    18.  Enterprise login URL responds (redirects to IdP or landing page)
#    19.  EnterpriseCustomer record exists for the tenant slug
#    20.  Enterprise IdP linkage is configured (link table or legacy field)
#
# Usage:
#   # Repo-only checks (no cluster needed — fastest):
#   ./scripts/qa/verify-enterprise-sso-readiness.sh --mode repo
#
#   # Full check against dev cluster:
#   ./scripts/qa/verify-enterprise-sso-readiness.sh --env dev
#
#   # Full check against prod cluster:
#   ./scripts/qa/verify-enterprise-sso-readiness.sh --env prod
#
#   # Per-tenant check:
#   ./scripts/qa/verify-enterprise-sso-readiness.sh --env prod --tenant acme-corp
#
# Exit codes:
#   0 — all checks passed (or all failures are SKIP)
#   1 — one or more FAIL
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
TENANT=""
ENV="prod"
MODE="all"       # repo | cluster | all
NAMESPACE="${NAMESPACE:-${K8S_NAMESPACE:-mereka-lms}}"
NAMESPACE_PROD="${NAMESPACE_PROD:-${K8S_NAMESPACE_PROD:-$NAMESPACE}}"
NAMESPACE_DEV="${NAMESPACE_DEV:-${K8S_NAMESPACE_DEV:-$NAMESPACE}}"
CONTEXT_PROD="${CONTEXT_PROD:-${K8S_CONTEXT_PROD:-${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}}}"
CONTEXT_DEV="${CONTEXT_DEV:-${K8S_CONTEXT_DEV:-${K8S_CONTEXT:-kind-dev}}}"
NAMESPACE_OVERRIDE=""

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Verify Enterprise SSO Phase 0 readiness (auth-sso-enterprise_spec.md AC-043).

OPTIONS:
  --env {prod|dev}          Target environment (default: prod)
  --tenant SLUG             Tenant slug for per-tenant checks (optional)
  --mode {repo|cluster|all} Scope of checks (default: all)
  -n, --namespace NS        Kubernetes namespace (default: $NAMESPACE)
  -h, --help                Show this help

EXAMPLES:
  $0 --mode repo              # Static checks only, no kubectl
  $0 --env dev                # Full check against dev (rke2-nonprod)
  $0 --env prod --tenant acme-corp
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV="$2"; shift 2 ;;
    --tenant) TENANT="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    -n|--namespace)
      NAMESPACE="$2"
      NAMESPACE_OVERRIDE="$NAMESPACE"
      shift 2
      ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

if [[ "$ENV" != "prod" && "$ENV" != "dev" ]]; then
  echo "Invalid --env: $ENV (expected prod|dev)" >&2
  exit 1
fi

if [[ "$MODE" != "repo" && "$MODE" != "cluster" && "$MODE" != "all" ]]; then
  echo "Invalid --mode: $MODE (expected repo|cluster|all)" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# K8s context and URL selection
# ---------------------------------------------------------------------------
if [[ "$ENV" == "prod" ]]; then
  KUBE_CTX="$CONTEXT_PROD"
  if [[ -z "$NAMESPACE_OVERRIDE" ]]; then
    NAMESPACE="$NAMESPACE_PROD"
  fi
  LMS_URL="https://${LMS_DOMAIN:-academyv2.mereka.io}"
else
  KUBE_CTX="$CONTEXT_DEV"
  if [[ -z "$NAMESPACE_OVERRIDE" ]]; then
    NAMESPACE="$NAMESPACE_DEV"
  fi
  LMS_URL="https://${DEV_LMS_DOMAIN:-academyv2.mereka.dev}"
fi

# ---------------------------------------------------------------------------
# Counters and helpers
# ---------------------------------------------------------------------------
PASS=0
FAIL=0
SKIP=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}  $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC}  $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC}  $1"; SKIP=$((SKIP + 1)); }
header() { echo ""; echo "--- $1 ---"; }

# kubectl with context baked in
kube() { kubectl --context "$KUBE_CTX" "$@"; }

# Probe whether the kube context resolves
cluster_available() {
  command -v kubectl &>/dev/null || return 1
  kubectl --context "$KUBE_CTX" cluster-info &>/dev/null 2>&1
}

# ---------------------------------------------------------------------------
echo "=== Enterprise SSO Phase 0 Readiness Verification ==="
echo "    spec: auth-sso-enterprise_spec.md"
echo "    env=$ENV  mode=$MODE  namespace=$NAMESPACE  lms=$LMS_URL"
[[ -n "$TENANT" ]] && echo "    tenant=$TENANT"
echo ""

# ===========================================================================
# SECTION 1: Repo-level checks (no kubectl required)
# ===========================================================================
if [[ "$MODE" == "repo" || "$MODE" == "all" ]]; then
  header "Repo-level checks"

  # --- ExternalSecret definition ---
  ES_FILE="$REPO_ROOT/deploy/k8s/base/secrets/external-secrets.yaml"
  if [[ -f "$ES_FILE" ]]; then
    if grep -q "enterprise-sso-secrets" "$ES_FILE"; then
      pass "ExternalSecret 'enterprise-sso-secrets' is defined in external-secrets.yaml"
    else
      fail "ExternalSecret 'enterprise-sso-secrets' NOT found in external-secrets.yaml"
    fi
    for key in SAML_SP_PUBLIC_CERT SAML_SP_PRIVATE_KEY OIDC_ENTERPRISE_CLIENT_SECRET SCIM_BEARER_TOKEN; do
      if grep -q "secretKey: $key" "$ES_FILE"; then
        pass "ExternalSecret defines key '$key'"
      else
        fail "ExternalSecret is missing key '$key'"
      fi
    done
  else
    fail "external-secrets.yaml not found at $ES_FILE"
    for key in SAML_SP_PUBLIC_CERT SAML_SP_PRIVATE_KEY OIDC_ENTERPRISE_CLIENT_SECRET SCIM_BEARER_TOKEN; do
      skip "ExternalSecret key '$key' (file missing)"
    done
  fi

  # --- ENABLE_ENTERPRISE_INTEGRATION in plugin contract sources ---
  if mereka_plugin_has_any "$REPO_ROOT"; then
    if mereka_plugin_has_regex "$REPO_ROOT" 'ENABLE_ENTERPRISE_INTEGRATION.*=.*True'; then
      pass "ENABLE_ENTERPRISE_INTEGRATION = True found in plugin contract sources"
    else
      fail "ENABLE_ENTERPRISE_INTEGRATION = True NOT found in plugin contract sources"
    fi
  else
    fail "No plugin contract sources found (mereka_lms*.py)"
  fi

  # DISABLE_ENTERPRISE_LOGIN lives in LMS settings (MFE_CONFIG), not the Tutor plugin
  LMS_SETTINGS_FILE="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"
  if [[ -f "$LMS_SETTINGS_FILE" ]]; then
    if grep -q "DISABLE_ENTERPRISE_LOGIN" "$LMS_SETTINGS_FILE"; then
      pass "DISABLE_ENTERPRISE_LOGIN present in lms/production.py (MFE_CONFIG)"
    else
      fail "DISABLE_ENTERPRISE_LOGIN NOT found in lms/production.py (MFE_CONFIG gate missing)"
    fi
  else
    fail "lms/production.py not found at $LMS_SETTINGS_FILE"
  fi

  # --- SAML keypair generation script ---
  KEYPAIR_SCRIPT="$REPO_ROOT/scripts/tenants/generate-saml-keypair.sh"
  if [[ -f "$KEYPAIR_SCRIPT" ]]; then
    pass "generate-saml-keypair.sh exists"
    if [[ -x "$KEYPAIR_SCRIPT" ]]; then
      pass "generate-saml-keypair.sh is executable"
    else
      fail "generate-saml-keypair.sh is not executable (chmod +x $KEYPAIR_SCRIPT)"
    fi
  else
    fail "generate-saml-keypair.sh not found at $KEYPAIR_SCRIPT"
    skip "generate-saml-keypair.sh executable check (file missing)"
  fi

  # --- configure-tenant-idp.sh exists and is implemented ---
  IDP_SCRIPT="$REPO_ROOT/scripts/tenants/configure-tenant-idp.sh"
  if [[ -f "$IDP_SCRIPT" ]]; then
    if grep -q "TODO: implement verification" "$IDP_SCRIPT"; then
      fail "configure-tenant-idp.sh exists but is still a TODO stub"
    else
      pass "configure-tenant-idp.sh exists and is implemented"
    fi
  else
    fail "configure-tenant-idp.sh not found at $IDP_SCRIPT"
  fi

  # --- Cookie middleware order guard ---
  COOKIE_GUARD="$REPO_ROOT/scripts/qa/verify-oidc-cookie-middleware-order.sh"
  if [[ -f "$COOKIE_GUARD" ]]; then
    if bash "$COOKIE_GUARD" &>/dev/null; then
      pass "OIDC cookie middleware order guard passes"
    else
      fail "OIDC cookie middleware order guard FAILED (run verify-oidc-cookie-middleware-order.sh for details)"
    fi
  else
    skip "verify-oidc-cookie-middleware-order.sh not found — skipping middleware guard"
  fi

  # --- Spec file exists ---
  SPEC_FILE="$REPO_ROOT/specs/auth-sso-enterprise_spec.md"
  if [[ -f "$SPEC_FILE" ]]; then
    pass "auth-sso-enterprise_spec.md exists"
  else
    fail "auth-sso-enterprise_spec.md not found at $SPEC_FILE"
  fi

  # --- verify-auth-surfaces.sh exists (AC-042 dependency) ---
  AUTH_SURFACES="$REPO_ROOT/scripts/qa/verify-auth-surfaces.sh"
  if [[ -f "$AUTH_SURFACES" ]]; then
    pass "verify-auth-surfaces.sh exists (AC-042 dependency)"
  else
    fail "verify-auth-surfaces.sh not found — AC-042 cannot be satisfied"
  fi
fi

# ===========================================================================
# SECTION 2: Live cluster checks (requires kubectl)
# ===========================================================================
if [[ "$MODE" == "cluster" || "$MODE" == "all" ]]; then
  header "Live cluster checks (env=$ENV context=$KUBE_CTX)"

  if ! cluster_available; then
    skip "kubectl context '$KUBE_CTX' unavailable — skipping all cluster checks"
    for i in $(seq 1 10); do
      skip "cluster check $i (context unavailable)"
    done
  else
    # --- enterprise-sso-secrets K8s Secret ---
    if kube get secret enterprise-sso-secrets -n "$NAMESPACE" &>/dev/null; then
      pass "K8s Secret 'enterprise-sso-secrets' exists in $NAMESPACE"

      # Inspect keys present in the secret
      SECRET_KEYS=$(kube get secret enterprise-sso-secrets -n "$NAMESPACE" \
        -o jsonpath='{.data}' 2>/dev/null \
        | python3 -c "import sys,json; print(' '.join(json.load(sys.stdin).keys()))" \
        2>/dev/null || echo "")
      for key in SAML_SP_PUBLIC_CERT SAML_SP_PRIVATE_KEY OIDC_ENTERPRISE_CLIENT_SECRET SCIM_BEARER_TOKEN; do
        if echo "$SECRET_KEYS" | grep -qw "$key"; then
          pass "Secret key '$key' present in enterprise-sso-secrets"
        else
          fail "Secret key '$key' MISSING from enterprise-sso-secrets (populate GCP secret MEREKA_LMS_$key)"
        fi
      done
    else
      fail "K8s Secret 'enterprise-sso-secrets' does NOT exist in $NAMESPACE"
      echo "     -> GCP secrets not yet populated, or ExternalSecret not synced."
      echo "     -> Run: ./scripts/tenants/generate-saml-keypair.sh then store in GCP SM."
      for key in SAML_SP_PUBLIC_CERT SAML_SP_PRIVATE_KEY OIDC_ENTERPRISE_CLIENT_SECRET SCIM_BEARER_TOKEN; do
        skip "secret key '$key' (secret does not exist)"
      done
    fi

    # --- ExternalSecret sync status ---
    ES_READY=$(kube get externalsecret enterprise-sso-secrets -n "$NAMESPACE" \
      -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null \
      || echo "NotFound")
    if [[ "$ES_READY" == "True" ]]; then
      pass "ExternalSecret 'enterprise-sso-secrets' Ready=True"
    elif [[ "$ES_READY" == "NotFound" ]]; then
      fail "ExternalSecret 'enterprise-sso-secrets' not found in cluster"
    else
      fail "ExternalSecret 'enterprise-sso-secrets' NOT ready (status=$ES_READY)"
    fi

    # --- LMS pod ---
    LMS_POD=$(kube get pods -n "$NAMESPACE" \
      -l app.kubernetes.io/name=lms \
      --field-selector=status.phase=Running \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [[ -z "$LMS_POD" ]]; then
      fail "No running LMS pod found in $NAMESPACE"
      skip "openedx-enterprise package check (no pod)"
      skip "SAML backend check (no pod)"
      skip "ENABLE_ENTERPRISE_INTEGRATION runtime check (no pod)"
    else
      pass "LMS pod found: $LMS_POD"

      # openedx-enterprise package
      ENT_CHECK=$(kube exec -n "$NAMESPACE" "$LMS_POD" -- \
        python3 -c "import enterprise; print('ok')" 2>/dev/null || echo "missing")
      if [[ "$ENT_CHECK" == "ok" ]]; then
        pass "openedx-enterprise package installed in LMS"
      else
        fail "openedx-enterprise package NOT found in LMS pod"
      fi

      # SAML auth backend
      SAML_CHECK=$(kube exec -n "$NAMESPACE" "$LMS_POD" -- \
        python3 -c "
from social_core.backends.saml import SAMLAuth
print('ok')
" 2>/dev/null || echo "missing")
      if [[ "$SAML_CHECK" == "ok" ]]; then
        pass "SAML auth backend (social_core.backends.saml.SAMLAuth) importable"
      else
        fail "SAML auth backend NOT importable ($SAML_CHECK)"
      fi

      # ENABLE_ENTERPRISE_INTEGRATION at runtime
      RUNTIME_FLAG=$(kube exec -n "$NAMESPACE" "$LMS_POD" -- \
        python3 -c "
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'lms.envs.production')
os.environ.setdefault('SERVICE_VARIANT', 'lms')
import django; django.setup()
from django.conf import settings
f = getattr(settings, 'FEATURES', {})
print('ok' if f.get('ENABLE_ENTERPRISE_INTEGRATION') else 'disabled')
" 2>/dev/null || echo "error")
      if [[ "$RUNTIME_FLAG" == "ok" ]]; then
        pass "ENABLE_ENTERPRISE_INTEGRATION=True at LMS runtime"
      elif [[ "$RUNTIME_FLAG" == "disabled" ]]; then
        fail "ENABLE_ENTERPRISE_INTEGRATION is False at LMS runtime"
      else
        fail "Could not verify ENABLE_ENTERPRISE_INTEGRATION ($RUNTIME_FLAG)"
      fi

      # Enterprise schema + linkage integrity (runtime model/storage compatibility)
      SCHEMA_CHECK=$(kube exec -n "$NAMESPACE" "$LMS_POD" -- \
        python3 -c "
import os, json
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'lms.envs.production')
os.environ.setdefault('SERVICE_VARIANT', 'lms')
import django; django.setup()
from django.db import connection
from enterprise.models import EnterpriseCustomer

with connection.cursor() as cursor:
    cols = {c.name for c in connection.introspection.get_table_description(cursor, 'enterprise_enterprisecustomer')}

# 1) Column compatibility for currently-modeled concrete fields.
required_candidates = ['enable_career_engagement_network_on_learner_portal']
model_fields = {f.name for f in EnterpriseCustomer._meta.get_fields()}
required = [c for c in required_candidates if c in model_fields]
missing = [c for c in required if c not in cols]

# 2) IdP linkage compatibility:
#    - legacy concrete column enterprise_enterprisecustomer.identity_provider, OR
#    - relationship model/table enterprise_enterprisecustomeridentityprovider
concrete_fields = {f.name for f in EnterpriseCustomer._meta.get_fields() if getattr(f, 'concrete', False)}
has_legacy_field = 'identity_provider' in concrete_fields
has_link_table = False
with connection.cursor() as cursor:
    table_names = set(connection.introspection.table_names(cursor))
if 'enterprise_enterprisecustomeridentityprovider' in table_names:
    has_link_table = True

if has_legacy_field and 'identity_provider' not in cols:
    missing.append('enterprise_enterprisecustomer.identity_provider')
if not has_legacy_field and not has_link_table:
    missing.append('enterprise idp linkage model/table')

if missing:
    print('missing:' + ','.join(missing))
else:
    print('ok:' + ','.join(required + ['idp_linkage']))
" 2>/dev/null || echo \"error\")
      if [[ "$SCHEMA_CHECK" == ok:* ]]; then
        pass "enterprise schema/linkage integrity check passed (${SCHEMA_CHECK#ok:})"
      elif [[ "$SCHEMA_CHECK" == missing:* ]]; then
        fail "enterprise schema/linkage integrity check failed (${SCHEMA_CHECK#missing:})"
      else
        fail "Could not verify enterprise schema integrity ($SCHEMA_CHECK)"
      fi

      # Tenant-domain mapping integrity: SiteConfiguration ENTERPRISE_CUSTOMER_UUID must
      # be present and match EnterpriseCustomer.uuid for site-bound enterprise customers.
      SITE_MAP_CHECK=$(kube exec -n "$NAMESPACE" "$LMS_POD" -- \
        python3 -c "
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'lms.envs.production')
os.environ.setdefault('SERVICE_VARIANT', 'lms')
import django; django.setup()
from enterprise.models import EnterpriseCustomer
from openedx.core.djangoapps.site_configuration.models import SiteConfiguration

issues = []
customers = EnterpriseCustomer.objects.filter(site__isnull=False).only('uuid', 'slug', 'site')
for ec in customers:
    cfg = SiteConfiguration.objects.filter(site=ec.site).order_by('-id').first()
    if not cfg:
        issues.append(f'{ec.slug}:missing_siteconfig')
        continue
    values = cfg.site_values or {}
    mapped = str(values.get('ENTERPRISE_CUSTOMER_UUID', '')).strip()
    expected = str(ec.uuid)
    if not mapped:
        issues.append(f'{ec.slug}:missing_enterprise_uuid')
    elif mapped != expected:
        issues.append(f'{ec.slug}:uuid_mismatch:{mapped}->{expected}')

if issues:
    print('missing:' + ';'.join(issues))
else:
    print('ok:' + str(customers.count()))
" 2>/dev/null || echo \"error\")
      if [[ "$SITE_MAP_CHECK" == ok:* ]]; then
        pass "SiteConfiguration ENTERPRISE_CUSTOMER_UUID mapping is aligned for ${SITE_MAP_CHECK#ok:} enterprise site(s)"
      elif [[ "$SITE_MAP_CHECK" == missing:* ]]; then
        fail "SiteConfiguration ENTERPRISE_CUSTOMER_UUID mapping drift detected (${SITE_MAP_CHECK#missing:})"
      else
        fail "Could not verify SiteConfiguration ENTERPRISE_CUSTOMER_UUID mapping ($SITE_MAP_CHECK)"
      fi
    fi

    # --- SAML SP metadata endpoint (AC-005) ---
    SAML_META_URL="${LMS_URL}/auth/saml/metadata.xml"
    SAML_META_HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
      --max-time 15 "$SAML_META_URL" 2>/dev/null || echo "000")
    if [[ "$SAML_META_HTTP" == "200" ]]; then
      pass "SAML SP metadata endpoint HTTP 200 ($SAML_META_URL) [AC-005]"
    elif [[ "$SAML_META_HTTP" == "404" ]]; then
      fail "SAML SP metadata endpoint HTTP 404 — SAMLConfiguration may be missing/disabled for this site [AC-005]"
    elif [[ "$SAML_META_HTTP" == "000" ]]; then
      fail "SAML SP metadata endpoint unreachable (timeout/DNS) [AC-005]"
    else
      fail "SAML SP metadata endpoint returned HTTP $SAML_META_HTTP [AC-005]"
    fi

    # --- Authentik OIDC baseline (AC-004) ---
    OIDC_LOGIN_URL="${LMS_URL}/auth/login/oidc/"
    OIDC_HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
      --max-time 15 -L "$OIDC_LOGIN_URL" 2>/dev/null || echo "000")
    if [[ "$OIDC_HTTP" == "200" || "$OIDC_HTTP" == "302" || "$OIDC_HTTP" == "301" ]]; then
      pass "Authentik OIDC login endpoint responds (HTTP $OIDC_HTTP) — non-enterprise baseline intact [AC-004]"
    elif [[ "$OIDC_HTTP" == "000" ]]; then
      fail "Authentik OIDC login endpoint unreachable — non-enterprise SSO may be broken [AC-004]"
    else
      fail "Authentik OIDC login endpoint returned HTTP $OIDC_HTTP (expected 200/301/302) [AC-004]"
    fi
  fi
fi

# ===========================================================================
# SECTION 3: Per-tenant checks (requires --tenant and kubectl)
# ===========================================================================
if [[ -n "$TENANT" ]]; then
  header "Per-tenant checks (tenant=$TENANT) [AC-043]"

  if ! cluster_available; then
    skip "kubectl context '$KUBE_CTX' unavailable — skipping per-tenant checks"
    skip "per-tenant checks (context unavailable)"
    skip "per-tenant checks (context unavailable)"
  else
    # Enterprise login URL
    ENTERPRISE_LOGIN_URL="${LMS_URL}/enterprise/login/${TENANT}"
    ENT_HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
      --max-time 15 "$ENTERPRISE_LOGIN_URL" 2>/dev/null || echo "000")
    if [[ "$ENT_HTTP" == "302" || "$ENT_HTTP" == "301" ]]; then
      pass "Enterprise login URL redirects (HTTP $ENT_HTTP): $ENTERPRISE_LOGIN_URL"
    elif [[ "$ENT_HTTP" == "200" ]]; then
      pass "Enterprise login URL responds HTTP 200: $ENTERPRISE_LOGIN_URL"
    elif [[ "$ENT_HTTP" == "404" ]]; then
      fail "Enterprise login URL HTTP 404 for tenant '$TENANT' — EnterpriseCustomer may not exist"
    elif [[ "$ENT_HTTP" == "000" ]]; then
      fail "Enterprise login URL unreachable for tenant '$TENANT'"
    else
      fail "Enterprise login URL returned HTTP $ENT_HTTP for tenant '$TENANT'"
    fi

    # EnterpriseCustomer record + IdP linkage
    LMS_POD=$(kube get pods -n "$NAMESPACE" \
      -l app.kubernetes.io/name=lms \
      --field-selector=status.phase=Running \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [[ -z "$LMS_POD" ]]; then
      skip "No running LMS pod — skipping EnterpriseCustomer checks"
      skip "enterprise IdP linkage check (no pod)"
    else
      EC_CHECK=$(kube exec -n "$NAMESPACE" "$LMS_POD" -- \
        python3 -c "
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'lms.envs.production')
os.environ.setdefault('SERVICE_VARIANT', 'lms')
import django; django.setup()
try:
    from enterprise.models import EnterpriseCustomer
    ec = EnterpriseCustomer.objects.filter(slug='${TENANT}').first()
    if not ec:
        print('not_found')
    else:
        provider = ''
        linkage_model = 'none'

        # Preferred linkage in newer enterprise versions.
        try:
            from enterprise.models import EnterpriseCustomerIdentityProvider
            links = EnterpriseCustomerIdentityProvider.objects.filter(enterprise_customer=ec)
            link = links.order_by('-default_provider', '-created').first()
            if link and getattr(link, 'provider_id', ''):
                provider = str(link.provider_id)
                linkage_model = 'enterprise_customer_identity_providers'
        except Exception:
            pass

        # Legacy fallback when identity_provider is a concrete DB field.
        if not provider:
            concrete_fields = {f.name for f in EnterpriseCustomer._meta.get_fields() if getattr(f, 'concrete', False)}
            if 'identity_provider' in concrete_fields:
                candidate = str(getattr(ec, 'identity_provider') or '')
                if candidate:
                    provider = candidate
                    linkage_model = 'identity_provider_field'

        # Property fallback for backwards compatibility.
        if not provider:
            candidate = str(getattr(ec, 'identity_provider', '') or '')
            if candidate:
                provider = candidate
                linkage_model = 'identity_provider_property'

        if provider:
            print('ok:' + provider + ':' + linkage_model)
        else:
            print('no_idp')
except Exception as e:
    print('error:' + str(e))
" 2>/dev/null || echo "error:exec_failed")

      if [[ "$EC_CHECK" == "not_found" ]]; then
        fail "EnterpriseCustomer slug='$TENANT' NOT found — run provision-tenant.sh first"
      elif [[ "$EC_CHECK" == "no_idp" ]]; then
        fail "EnterpriseCustomer '$TENANT' exists but no IdP linkage is configured (configure tenant IdP mapping)"
      elif [[ "$EC_CHECK" == ok:* ]]; then
        LINK_DETAIL="${EC_CHECK#ok:}"
        IDP_SLUG="$(cut -d: -f1 <<<"$LINK_DETAIL")"
        LINK_MODEL="$(cut -d: -f2 <<<"$LINK_DETAIL")"
        pass "EnterpriseCustomer '$TENANT' exists, idp='$IDP_SLUG' (linkage=$LINK_MODEL)"
      else
        fail "EnterpriseCustomer check failed: $EC_CHECK"
      fi
    fi
  fi
fi

# ===========================================================================
# Summary
# ===========================================================================
echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS${NC}  $PASS"
echo -e "${RED}FAIL${NC}  $FAIL"
echo -e "${YELLOW}SKIP${NC}  $SKIP"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo "Some checks FAILED. See above for details."
  echo "Refer to docs/ops/runbooks/ENTERPRISE_SSO_GUIDE.md for remediation steps."
  exit 1
fi

if [[ $PASS -eq 0 && $FAIL -eq 0 ]]; then
  echo "No checks ran — check --mode and --env."
  exit 1
fi

echo "All checks passed (SKIP=$SKIP checks were not applicable in this environment)."
exit 0
