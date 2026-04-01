#!/usr/bin/env bash
# site-reconcile-common.sh — Shared Site + SiteConfiguration seed/reconcile functions
#
# Sourced by seed-staging-sites.sh and seed-dev-sites.sh.
# Callers must source an env file first (scripts/tenants/env/<env>.env) and
# declare the following variables before sourcing this file:
#
#   Required (from env file):
#     NAMESPACE        — K8s namespace to query
#     TENANT_DEFS      — array of
#                        "SLUG|DOMAIN|NAME|LMS_ROOT_URL|MFE_BASE_URL|COURSE_ORG_FILTER_JSON|THEME_NAME|PRIMARY_COLOR|SECONDARY_COLOR|ACCENT_COLOR"
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
# seed_waffle_flags — create global waffle flags required for MFE redirects
# ─────────────────────────────────────────────────────────────────────────────
seed_waffle_flags() {
  echo "--- seeding waffle flags ---"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [DRY RUN] would create/update waffle flags"
    echo ""
    return 0
  fi

  local PY_WAFFLE
  PY_WAFFLE=$(cat <<'PYEOF'
from waffle.models import Flag
import json

flags = [
    # Dashboard MFE redirect — learner_home_mfe_enabled() checks this flag.
    # Without it, /dashboard stays on the legacy Django page even when
    # LEARNER_HOME_MFE_REDIRECT_PERCENTAGE = 100 is set.
    ("learner_home.redirect_to_microfrontend", True),
]

results = []
for flag_name, everyone_val in flags:
    obj, created = Flag.objects.update_or_create(
        name=flag_name,
        defaults={"everyone": everyone_val},
    )
    results.append({
        "flag": flag_name,
        "action": "CREATED" if created else "UPDATED",
        "everyone": obj.everyone,
    })
print(json.dumps(results))
PYEOF
)

  local RESULT
  RESULT=$(kubectl exec -n "$NAMESPACE" "$LMS_POD" -- \
    python manage.py lms shell -c "$PY_WAFFLE" 2>/dev/null \
    | grep '^\[' | tail -1 \
    || echo "[]")

  echo "  result: $RESULT"
  echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# run_seed — iterate TENANT_DEFS and upsert Site + SiteConfiguration
# ─────────────────────────────────────────────────────────────────────────────
run_seed() {
  # Seed global waffle flags before tenant-specific config.
  seed_waffle_flags

  local PASS=0
  local FAIL=0

  for TENANT_LINE in "${TENANT_DEFS[@]}"; do
    IFS='|' read -r SLUG DOMAIN NAME LMS_ROOT_URL MFE_BASE_URL COURSE_ORG_FILTER_JSON THEME_NAME PRIMARY_COLOR SECONDARY_COLOR ACCENT_COLOR <<< "$TENANT_LINE"

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
    echo "  PRIMARY_COLOR  : ${PRIMARY_COLOR:-(empty)}"
    echo "  SECONDARY_COLOR: ${SECONDARY_COLOR:-(empty)}"
    echo "  ACCENT_COLOR   : ${ACCENT_COLOR:-(empty)}"

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
primary_color   = "${PRIMARY_COLOR}"
secondary_color = "${SECONDARY_COLOR}"
accent_color    = "${ACCENT_COLOR}"

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
logo_img = f"{lms_url}/static/{theme_name}/images/logo-horizontal.svg" if theme_name else ""
favicon  = f"{theme_name}/images/favicon.ico" if theme_name else ""

# Derive tenant brand asset subpath from slug.
# Known tenants with their own brand asset subdirectories under /theme/:
_TENANT_BRAND_SUBPATHS = {"biji-biji": "biji-biji/", "skillourfuture": "skillourfuture/"}
brand_subpath = _TENANT_BRAND_SUBPATHS.get(slug, "")

# Derive canonical brand colors from the brand token CSS files.
# The brand CSS (e.g. sof-brand.min.css) is the canonical source of
# tenant colors. The env-file palette values are fallbacks only.
import re as _re, pathlib as _pathlib
_BRAND_CSS_MAP = {"biji-biji": "biji-biji-brand.min.css", "skillourfuture": "sof-brand.min.css"}
_brand_css_name = _BRAND_CSS_MAP.get(slug)
if _brand_css_name:
    _brand_css_candidates = [
        _pathlib.Path("/openedx/themes/mereka/mfe/theme") / _brand_css_name,
        _pathlib.Path("/openedx/dist/theme") / _brand_css_name,
    ]
    for _bcp in _brand_css_candidates:
        if _bcp.is_file():
            _css_text = _bcp.read_text()
            _m = _re.search(r"--mereka-color-magenta:\s*(#[0-9a-fA-F]{3,8})", _css_text)
            if _m: primary_color = _m.group(1)
            _m = _re.search(r"--mereka-color-teal:\s*(#[0-9a-fA-F]{3,8})", _css_text)
            if _m: secondary_color = _m.group(1)
            _m = _re.search(r"--mereka-color-blue:\s*(#[0-9a-fA-F]{3,8})", _css_text)
            if _m: accent_color = _m.group(1)
            break

mfe_origin = mfe_url.replace("https://", "").replace("http://", "")

site_values = {
    "domain": domain,
    "site_name": name,
    "platform_name": name,
    "PRIMARY_COLOR": primary_color,
    "SECONDARY_COLOR": secondary_color,
    "ACCENT_COLOR": accent_color,
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
        "DISABLE_ENTERPRISE_LOGIN": True,
        "ACCESS_TOKEN_COOKIE_NAME": "edx-jwt-cookie-header-payload",
        "USER_INFO_COOKIE_NAME": "user-info",
        "SESSION_COOKIE_SAMESITE": "None",
        "CSRF_COOKIE_SAMESITE": "None",
        "SITE_NAME": name,
        "FAVICON_URL": f"https://{mfe_origin}/theme/favicon.ico" if theme_name else "",
        "LOGO_URL": f"https://{mfe_origin}/theme/{brand_subpath}logo-horizontal.svg" if theme_name else "",
        "LOGO_WHITE_URL": f"https://{mfe_origin}/theme/{brand_subpath}logo-horizontal-white.svg" if theme_name else "",
        "LOGO_TRADEMARK_URL": f"https://{mfe_origin}/theme/{brand_subpath}logo.svg" if theme_name else "",
        "STUDIO_BASE_URL": cms_url,
        "BASE_URL": mfe_url.replace("https://", "").replace("http://", ""),
        "AUTHN_MICROFRONTEND_URL": authn_mfe_url,
        "AUTHN_MICROFRONTEND_DOMAIN": mfe_url.replace("https://", "").replace("http://", ""),
        "ACCOUNT_MICROFRONTEND_URL": f"{mfe_url}/account/",
        "ACCOUNT_PROFILE_URL": f"{mfe_url}/profile",
        "COMMUNICATIONS_MICROFRONTEND_URL": f"{mfe_url}/communications",
        "COURSE_AUTHORING_MICROFRONTEND_URL": f"{mfe_url}/authoring",
        "COURSE_HOME_URL": f"{mfe_url}/learning/",
        "DISCUSSIONS_MICROFRONTEND_URL": f"{mfe_url}/discussions",
        "LEARNER_DASHBOARD_URL": f"{mfe_url}/learner-dashboard/",
        "LEARNER_HOME_MICROFRONTEND_URL": f"{mfe_url}/learner-dashboard/",
        "LEARNING_BASE_URL": f"{mfe_url}/learning",
        "PRIMARY_COLOR": primary_color,
        "SECONDARY_COLOR": secondary_color,
        "ACCENT_COLOR": accent_color,
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
