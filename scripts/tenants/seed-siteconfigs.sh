#!/usr/bin/env bash
set -euo pipefail

# seed-siteconfigs.sh — Create/update Site + SiteConfiguration rows from tenant registry.
#
# Reads deploy/k8s/tenancy/tenant-registry.yaml and ensures each tenant has:
#   - A Site row (domain matching site_domain)
#   - A SiteConfiguration row with correct LMS/CMS/MFE URLs, org filter, theme
#   - Preserved ENTERPRISE_CUSTOMER_UUID when the site is already linked to an
#     EnterpriseCustomer
#
# This is a repeatable provisioning path. Running it twice is safe (idempotent).
#
# Usage:
#   scripts/tenants/seed-siteconfigs.sh --namespace NS --environment ENV [--registry PATH] [--dry-run]
#
# The --environment flag selects which domain entries to use from the registry.
# If no matching domains exist for a tenant+environment, falls back to
# site_domain with conventional studio./apps. prefixes.
#
# Requires: kubectl, yq, python3

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

NAMESPACE=""
ENVIRONMENT=""
REGISTRY="deploy/k8s/tenancy/tenant-registry.yaml"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace)    NAMESPACE="${2:?--namespace requires a value}"; shift 2 ;;
    --environment)  ENVIRONMENT="${2:?--environment requires a value}"; shift 2 ;;
    --registry)     REGISTRY="${2:?--registry requires a value}";  shift 2 ;;
    --dry-run)      DRY_RUN=true; shift ;;
    -h|--help)      echo "Usage: $0 --namespace NS --environment ENV [--registry PATH] [--dry-run]" >&2; exit 0 ;;
    *)              echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$NAMESPACE" ]] && { echo "ERROR: --namespace is required" >&2; exit 1; }
[[ -z "$ENVIRONMENT" ]] && { echo "ERROR: --environment is required" >&2; exit 1; }
[[ -f "$REPO_ROOT/$REGISTRY" ]] || { echo "ERROR: registry not found: $REGISTRY" >&2; exit 1; }
command -v yq &>/dev/null || { echo "ERROR: yq required" >&2; exit 1; }
command -v kubectl &>/dev/null || { echo "ERROR: kubectl required" >&2; exit 1; }

cd "$REPO_ROOT"

# Find a ready LMS pod (not just any pod — some may have kubelet issues)
_POD_LIST=$(kubectl get pods -n "$NAMESPACE" \
  -l app.kubernetes.io/name=lms \
  --field-selector=status.phase=Running \
  -o jsonpath='{range .items[*]}{.metadata.name} {.status.containerStatuses[0].ready}{"\n"}{end}' 2>/dev/null || true)
LMS_POD=$(echo "$_POD_LIST" | awk '$2 == "true" { print $1; exit }')
[[ -z "$LMS_POD" ]] && { echo "ERROR: no ready LMS pod in namespace $NAMESPACE" >&2; exit 1; }

echo "=== seed-siteconfigs: namespace=$NAMESPACE environment=$ENVIRONMENT lms=$LMS_POD ===" >&2

# Read tenants from registry
mapfile -t SLUGS < <(yq '.tenants[].slug' "$REGISTRY")

PASS=0; FAIL=0

for SLUG in "${SLUGS[@]}"; do
  # site_domain defaults to tenant's canonical (prod) domain;
  # overridden by the primary domain entry for the target environment if one exists.
  SITE_DOMAIN=$(yq ".tenants[] | select(.slug == \"$SLUG\") | .site_domain" "$REGISTRY")
  ENV_PRIMARY=$(yq ".domains[] | select(.tenant==\"$SLUG\" and .role==\"primary\" and .environment==\"$ENVIRONMENT\" and .status==\"active\") | .domain" "$REGISTRY" | head -1)
  [[ -n "$ENV_PRIMARY" ]] && SITE_DOMAIN="$ENV_PRIMARY"
  TENANT_NAME=$(yq ".tenants[] | select(.slug == \"$SLUG\") | .name" "$REGISTRY")
  THEME=$(yq ".tenants[] | select(.slug == \"$SLUG\") | .theme" "$REGISTRY")
  ORG_JSON=$(yq -o=json -I=0 ".tenants[] | select(.slug == \"$SLUG\") | .org_filter" "$REGISTRY")

  # Get domains for this tenant from registry, filtered by --environment.
  # Falls back to site_domain with conventional prefixes if no entries exist.
  PRIMARY=$(yq ".domains[] | select(.tenant==\"$SLUG\" and .role==\"primary\" and .environment==\"$ENVIRONMENT\" and .status==\"active\") | .domain" "$REGISTRY" | head -1)
  STUDIO=$(yq ".domains[] | select(.tenant==\"$SLUG\" and .role==\"studio\" and .environment==\"$ENVIRONMENT\" and .status==\"active\") | .domain" "$REGISTRY" | head -1)
  MFE=$(yq ".domains[] | select(.tenant==\"$SLUG\" and .role==\"mfe\" and .environment==\"$ENVIRONMENT\" and .status==\"active\") | .domain" "$REGISTRY" | head -1)

  [[ -z "$PRIMARY" ]] && PRIMARY="$SITE_DOMAIN"
  [[ -z "$STUDIO" ]] && STUDIO="studio.${PRIMARY}"
  [[ -z "$MFE" ]] && MFE="apps.${PRIMARY}"

  SCHEME=$(yq ".environments.${ENVIRONMENT}.scheme" "$REGISTRY")
  [[ -z "$SCHEME" || "$SCHEME" == "null" ]] && SCHEME="https"

  LMS_URL="${SCHEME}://${PRIMARY}"
  CMS_URL="${SCHEME}://${STUDIO}"
  MFE_URL="${SCHEME}://${MFE}"

  echo "" >&2
  echo "--- tenant: $SLUG ---" >&2
  echo "  site_domain: $SITE_DOMAIN" >&2
  echo "  LMS_ROOT_URL: $LMS_URL" >&2
  echo "  CMS_ROOT_URL: $CMS_URL" >&2
  echo "  MFE_BASE_URL: $MFE_URL" >&2
  echo "  org_filter: $ORG_JSON" >&2
  echo "  theme: $THEME" >&2

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [DRY RUN] would create/update Site + SiteConfiguration" >&2
    PASS=$((PASS + 1))
    continue
  fi

  # Build the Python script as a tempfile to avoid shell quoting issues
  PY_SCRIPT=$(mktemp /tmp/seed_sc_XXXXXX.py)
  cat > "$PY_SCRIPT" <<PYEOF
import json
from django.contrib.sites.models import Site
from openedx.core.djangoapps.site_configuration.models import SiteConfiguration
from urllib.parse import urlparse

try:
    from enterprise.models import EnterpriseCustomer
except Exception:  # pragma: no cover - enterprise app should exist in real lanes
    EnterpriseCustomer = None

domain = "${SITE_DOMAIN}"
name = "${TENANT_NAME}"
lms_url = "${LMS_URL}"
cms_url = "${CMS_URL}"
mfe_url = "${MFE_URL}"
theme = "${THEME}"
slug = "${SLUG}"
org_filter = json.loads('${ORG_JSON}')

# Derive tenant brand asset subpath from slug.
_TENANT_BRAND_SUBPATHS = {"biji-biji": "biji-biji/", "skillourfuture": "skillourfuture/"}
brand_subpath = _TENANT_BRAND_SUBPATHS.get(slug, "")

site, created = Site.objects.get_or_create(
    domain=domain,
    defaults={"name": name}
)
if not created:
    site.name = name
    site.save()

existing_site_config = SiteConfiguration.objects.filter(site=site).first()
existing_values = dict(existing_site_config.site_values or {}) if existing_site_config else {}
enterprise_customer_uuid = str(existing_values.get("ENTERPRISE_CUSTOMER_UUID", "")).strip()
if not enterprise_customer_uuid and EnterpriseCustomer is not None:
    enterprise_customer = EnterpriseCustomer.objects.filter(site=site).first()
    if enterprise_customer is not None:
        enterprise_customer_uuid = str(enterprise_customer.uuid)

site_values = {
    "domain": domain,
    "site_name": name,
    "platform_name": name,
    "LMS_ROOT_URL": lms_url,
    "CMS_ROOT_URL": cms_url,
    "MFE_BASE_URL": mfe_url,
    "AUTHN_MICROFRONTEND_URL": f"{mfe_url}/authn",
    "THEME_NAME": theme,
    "ENABLE_LEARNER_HOME_MFE": True,
    "ENABLE_COMPREHENSIVE_THEMING": True,
    "course_org_filter": org_filter,
    "logo_image": f"{lms_url}/static/{theme}/images/logo-horizontal.svg",
    "logo_url": "/",
    "favicon_path": f"{theme}/images/favicon.ico",
    "MFE_CONFIG": {
        "LMS_BASE_URL": lms_url,
        "LOGIN_URL": f"{lms_url}/login",
        "LOGOUT_URL": f"{lms_url}/logout",
        "MARKETING_SITE_BASE_URL": lms_url,
        "REFRESH_ACCESS_TOKEN_ENDPOINT": "/login_refresh",
        "DISABLE_ENTERPRISE_LOGIN": True,
        "ACCESS_TOKEN_COOKIE_NAME": "edx-jwt-cookie-header-payload",
        "USER_INFO_COOKIE_NAME": "user-info",
        "SESSION_COOKIE_SAMESITE": "None",
        "CSRF_COOKIE_SAMESITE": "None",
        "FAVICON_URL": f"{mfe_url}/theme/favicon.ico",
        "LOGO_URL": f"{mfe_url}/theme/{brand_subpath}logo-horizontal.svg",
        "LOGO_WHITE_URL": f"{mfe_url}/theme/{brand_subpath}logo-horizontal-white.svg",
        "LOGO_TRADEMARK_URL": f"{mfe_url}/theme/{brand_subpath}logo.svg",
        "STUDIO_BASE_URL": cms_url,
        "BASE_URL": mfe_url.replace("https://", "").replace("http://", ""),
        "AUTHN_MICROFRONTEND_URL": f"{mfe_url}/authn",
        "AUTHN_MICROFRONTEND_DOMAIN": mfe_url.replace("https://", "").replace("http://", ""),
    },
}
if enterprise_customer_uuid:
    site_values["ENTERPRISE_CUSTOMER_UUID"] = enterprise_customer_uuid

sc, sc_created = SiteConfiguration.objects.update_or_create(
    site=site,
    defaults={
        "enabled": True,
        "site_values": site_values,
    }
)

mfe_site_action = "SKIPPED"
mfe_sc_action = "SKIPPED"
mfe_host = urlparse(mfe_url).netloc or ""
if mfe_host and mfe_host != domain:
    mfe_site, mfe_site_created = Site.objects.update_or_create(
        domain=mfe_host,
        defaults={"name": f"{name} Apps"},
    )
    mfe_site_action = "CREATED" if mfe_site_created else "UPDATED"

    mfe_site_values = dict(site_values)
    mfe_site_values["domain"] = mfe_host
    mfe_site_values["MFE_CONFIG"] = dict(site_values.get("MFE_CONFIG", {}))

    _, mfe_sc_created = SiteConfiguration.objects.update_or_create(
        site=mfe_site,
        defaults={
            "enabled": True,
            "site_values": mfe_site_values,
        }
    )
    mfe_sc_action = "CREATED" if mfe_sc_created else "UPDATED"

action = "CREATED" if sc_created else "UPDATED"
print(json.dumps({
    "tenant": "${SLUG}",
    "site_id": site.id,
    "action": action,
    "mfe_site_action": mfe_site_action,
    "mfe_sc_action": mfe_sc_action,
    "status": "OK",
}))
PYEOF

  PY_CONTENT=$(cat "$PY_SCRIPT")
  rm -f "$PY_SCRIPT"

  RESULT=$(kubectl exec -n "$NAMESPACE" "$LMS_POD" -- python manage.py lms shell -c "$PY_CONTENT" 2>/dev/null | tail -1 || echo '{"tenant":"'"$SLUG"'","status":"FAIL","error":"exec_failed"}')

  echo "  result: $RESULT" >&2

  if echo "$RESULT" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); exit(0 if d.get('status')=='OK' else 1)" 2>/dev/null; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
  fi
done

echo "" >&2
echo "=== seed-siteconfigs: ${#SLUGS[@]} tenants, $PASS OK, $FAIL FAIL ===" >&2
[[ $FAIL -eq 0 ]]
