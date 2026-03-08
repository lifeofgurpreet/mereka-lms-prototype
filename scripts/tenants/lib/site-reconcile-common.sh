# site-reconcile-common.sh — Shared Site + SiteConfiguration seed/reconcile functions
#
# Sourced by seed-staging-sites.sh and seed-dev-sites.sh.
# Callers must source an env file first (scripts/tenants/env/<env>.env) and
# declare the following variables before sourcing this file:
#
#   Required (from env file):
#     NAMESPACE        — K8s namespace to query
#     TENANT_DEFS      — array of "SLUG|DOMAIN|NAME|LMS_ROOT_URL|MFE_BASE_URL|COURSE_ORG_FILTER_JSON|THEME_NAME"
#   Required (from env file, function):
#     _cms_url_for_slug — function returning CMS URL for a given slug
#
#   Required (from caller preamble):
#     DRY_RUN          — "true" or "false"
#     LMS_POD          — already-resolved pod name
#
# After sourcing, call run_seed to execute all tenant upserts.
#
# This file does NOT call set -euo pipefail; the caller owns that.

# ─────────────────────────────────────────────────────────────────────────────
# run_seed — iterate TENANT_DEFS and upsert Site + SiteConfiguration
# ─────────────────────────────────────────────────────────────────────────────
run_seed() {
  local PASS=0
  local FAIL=0

  for TENANT_LINE in "${TENANT_DEFS[@]}"; do
    IFS='|' read -r SLUG DOMAIN NAME LMS_ROOT_URL MFE_BASE_URL COURSE_ORG_FILTER_JSON THEME_NAME <<< "$TENANT_LINE"

    local CMS_ROOT_URL
    CMS_ROOT_URL="$(_cms_url_for_slug "$SLUG")"
    if [[ -z "$CMS_ROOT_URL" ]]; then
      echo "WARNING: no CMS URL defined for slug '$SLUG' — skipping" >&2
      FAIL=$((FAIL + 1))
      continue
    fi

    local AUTHN_MFE_URL="${MFE_BASE_URL}/authn"

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
    local PY_SCRIPT
    PY_SCRIPT=$(mktemp /tmp/seed_site_XXXXXX.py)
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

    local PY_CONTENT
    PY_CONTENT=$(cat "$PY_SCRIPT")
    rm -f "$PY_SCRIPT"

    local RESULT
    RESULT=$(kubectl exec -n "$NAMESPACE" "$LMS_POD" -- \
      python manage.py lms shell -c "$PY_CONTENT" 2>/dev/null \
      | grep '^{' | tail -1 \
      || echo "{\"tenant\":\"${SLUG}\",\"status\":\"FAIL\",\"error\":\"exec_failed\"}")

    echo "  result: $RESULT"
    echo ""

    if printf '%s' "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if d.get('status')=='OK' else 1)" 2>/dev/null; then
      PASS=$((PASS + 1))
    else
      FAIL=$((FAIL + 1))
      echo "  ERROR: seed failed for tenant $SLUG" >&2
    fi
  done

  echo "=== seed complete: ${#TENANT_DEFS[@]} tenants, $PASS OK, $FAIL FAIL ==="
  [[ $FAIL -eq 0 ]]
}
