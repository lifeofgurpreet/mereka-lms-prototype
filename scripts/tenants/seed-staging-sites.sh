#!/usr/bin/env bash
# seed-staging-sites.sh — Idempotent seed/repair for Django Site + SiteConfiguration
#                         rows across all staging tenants.
#
# Creates or updates Site and SiteConfiguration for each staging tenant.
# Safe to re-run: uses get_or_create / update_or_create throughout.
#
# Usage:
#   scripts/tenants/seed-staging-sites.sh [--namespace NS] [--dry-run]
#
# Requires: kubectl, python3
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

NAMESPACE="stg-mereka-lms"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) NAMESPACE="${2:?--namespace requires a value}"; shift 2 ;;
    --dry-run)   DRY_RUN=true; shift ;;
    -h|--help)   echo "Usage: $0 [--namespace NS] [--dry-run]"; exit 0 ;;
    *)           echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

command -v kubectl &>/dev/null || { echo "ERROR: kubectl required" >&2; exit 1; }

# ── Discover LMS pod ─────────────────────────────────────────────────────────
_POD_LIST=$(kubectl get pods -n "$NAMESPACE" \
  -l app.kubernetes.io/name=lms \
  --field-selector=status.phase=Running \
  -o jsonpath='{range .items[*]}{.metadata.name} {.status.containerStatuses[0].ready}{"\n"}{end}' 2>/dev/null || true)
LMS_POD=$(echo "$_POD_LIST" | awk '$2 == "true" { print $1; exit }')
[[ -z "$LMS_POD" ]] && { echo "ERROR: no ready LMS pod in namespace $NAMESPACE" >&2; exit 1; }

echo "=== seed-staging-sites: namespace=$NAMESPACE lms=$LMS_POD ==="
[[ "$DRY_RUN" == "true" ]] && echo "=== DRY RUN — no writes will be made ==="
echo ""

# ── Tenant definitions ────────────────────────────────────────────────────────
# Format: SLUG|DOMAIN|NAME|LMS_ROOT_URL|MFE_BASE_URL|COURSE_ORG_FILTER_JSON|THEME_NAME
declare -a TENANT_DEFS=(
  'mereka|staging.academyv2.mereka.io|Mereka Academy Staging|https://staging.academyv2.mereka.io|https://staging.apps.academyv2.mereka.io|["BBI","Mereka"]|mereka'
  'biji-biji|staging.academy.biji-biji.com|Biji-Biji Academy Staging|https://staging.academy.biji-biji.com|https://apps.staging.academy.biji-biji.com|["BijiBiji"]|'
  'skillourfuture|staging.skillourfuture.academy.mereka.io|Skill Our Future Staging|https://staging.skillourfuture.academy.mereka.io|https://apps.staging.skillourfuture.academy.mereka.io|["SoF"]|'
)

PASS=0
FAIL=0

for TENANT_LINE in "${TENANT_DEFS[@]}"; do
  IFS='|' read -r SLUG DOMAIN NAME LMS_ROOT_URL MFE_BASE_URL COURSE_ORG_FILTER_JSON THEME_NAME <<< "$TENANT_LINE"
  CMS_ROOT_URL="${LMS_ROOT_URL/staging./staging.studio.}"
  # Derive studio URL by inserting studio. after the staging. prefix
  # e.g. https://staging.academyv2.mereka.io → https://staging.studio.academyv2.mereka.io
  # For biji-biji: https://staging.academy.biji-biji.com → https://studio.staging.academy.biji-biji.com
  case "$SLUG" in
    mereka)        CMS_ROOT_URL="https://staging.studio.academyv2.mereka.io" ;;
    biji-biji)     CMS_ROOT_URL="https://studio.staging.academy.biji-biji.com" ;;
    skillourfuture) CMS_ROOT_URL="https://studio.staging.skillourfuture.academy.mereka.io" ;;
  esac

  AUTHN_MFE_URL="${MFE_BASE_URL}/authn"

  echo "--- tenant: $SLUG ---"
  echo "  domain         : $DOMAIN"
  echo "  LMS_ROOT_URL   : $LMS_ROOT_URL"
  echo "  CMS_ROOT_URL   : $CMS_ROOT_URL"
  echo "  MFE_BASE_URL   : $MFE_BASE_URL"
  echo "  AUTHN_MFE_URL  : $AUTHN_MFE_URL"
  echo "  course_org_filter: $COURSE_ORG_FILTER_JSON"
  echo "  THEME_NAME     : ${THEME_NAME:-(empty)}"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [DRY RUN] would create/update Site + SiteConfiguration"
    echo ""
    PASS=$((PASS + 1))
    continue
  fi

  # Write Python script to a tempfile to avoid shell quoting hazards
  PY_SCRIPT=$(mktemp /tmp/seed_staging_XXXXXX.py)
  cat > "$PY_SCRIPT" <<PYEOF
from django.contrib.sites.models import Site
from openedx.core.djangoapps.site_configuration.models import SiteConfiguration
import json, sys

slug            = "${SLUG}"
domain          = "${DOMAIN}"
name            = "${NAME}"
lms_url         = "${LMS_ROOT_URL}"
cms_url         = "${CMS_ROOT_URL}"
mfe_url         = "${MFE_BASE_URL}"
authn_mfe_url   = "${AUTHN_MFE_URL}"
course_org_filter = json.loads('${COURSE_ORG_FILTER_JSON}')
theme_name      = "${THEME_NAME}"

# ── Site row ──────────────────────────────────────────────────────────────────
site, site_created = Site.objects.get_or_create(
    domain=domain,
    defaults={"name": name},
)
if not site_created and site.name != name:
    site.name = name
    site.save()
    site_action = "UPDATED"
elif site_created:
    site_action = "CREATED"
else:
    site_action = "UNCHANGED"

# ── SiteConfiguration row ─────────────────────────────────────────────────────
logo_img = f"{lms_url}/static/{theme_name}/images/logo-horizontal.png" if theme_name else ""
favicon  = f"{theme_name}/images/favicon.ico" if theme_name else ""

site_values = {
    "domain": domain,
    "site_name": name,
    "platform_name": name,
    "LMS_ROOT_URL": lms_url,
    "CMS_ROOT_URL": cms_url,
    "MFE_BASE_URL": mfe_url,
    "AUTHN_MICROFRONTEND_URL": authn_mfe_url,
    "THEME_NAME": theme_name,
    "ENABLE_COMPREHENSIVE_THEMING": True,
    "course_org_filter": course_org_filter,
    "logo_image": logo_img,
    "logo_url": "/",
    "favicon_path": favicon,
    "MFE_CONFIG": {
        "LMS_BASE_URL": lms_url,
        "LOGIN_URL": f"{lms_url}/login",
        "LOGOUT_URL": f"{lms_url}/logout",
        "MARKETING_SITE_BASE_URL": lms_url,
        "REFRESH_ACCESS_TOKEN_ENDPOINT": "/login_refresh",
        "FAVICON_URL": f"{lms_url}/theming/asset/{theme_name}/images/favicon.ico" if theme_name else "",
        "LOGO_URL": logo_img,
        "LOGO_WHITE_URL": f"{lms_url}/theming/asset/{theme_name}/images/logo-horizontal-white.png" if theme_name else "",
        "LOGO_TRADEMARK_URL": f"{lms_url}/theming/asset/{theme_name}/images/logo.png" if theme_name else "",
        "STUDIO_BASE_URL": cms_url,
        "BASE_URL": mfe_url.replace("https://", "").replace("http://", ""),
        "AUTHN_MICROFRONTEND_URL": authn_mfe_url,
        "AUTHN_MICROFRONTEND_DOMAIN": mfe_url.replace("https://", "").replace("http://", ""),
    },
}

sc, sc_created = SiteConfiguration.objects.update_or_create(
    site=site,
    defaults={
        "enabled": True,
        "site_values": site_values,
    },
)
sc_action = "CREATED" if sc_created else "UPDATED"

# Detect truly unchanged (heuristic: LMS_ROOT_URL matches)
if not sc_created and sc.site_values.get("LMS_ROOT_URL") == lms_url and site_action == "UNCHANGED":
    sc_action = "UNCHANGED"

result = {
    "tenant": slug,
    "domain": domain,
    "site_id": site.id,
    "site_action": site_action,
    "sc_action": sc_action,
    "status": "OK",
}
print(json.dumps(result))
PYEOF

  PY_CONTENT=$(cat "$PY_SCRIPT")
  rm -f "$PY_SCRIPT"

  RESULT=$(kubectl exec -n "$NAMESPACE" "$LMS_POD" -- \
    python manage.py lms shell -c "$PY_CONTENT" 2>/dev/null \
    | grep '^{' | tail -1 \
    || echo "{\"tenant\":\"${SLUG}\",\"status\":\"FAIL\",\"error\":\"exec_failed\"}")

  echo "  result: $RESULT"
  echo ""

  if python3 -c "import json,sys; d=json.loads('${RESULT}'); exit(0 if d.get('status')=='OK' else 1)" 2>/dev/null; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "  ERROR: seed failed for tenant $SLUG" >&2
  fi
done

echo "=== seed-staging-sites: ${#TENANT_DEFS[@]} tenants, $PASS OK, $FAIL FAIL ==="
[[ $FAIL -eq 0 ]]
