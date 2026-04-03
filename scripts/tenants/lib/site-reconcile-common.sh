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
#            plus openedx_tenant_cache tenant rows
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
from django.conf import settings
from urllib.parse import urlparse
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
default_footer  = (getattr(settings, "MFE_CONFIG", {}) or {}).get("MEREKA_PUBLIC_FOOTER") or {}

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

# ── SiteConfiguration / tenant-cache row ─────────────────────────────────────
# Derive tenant brand asset subpath from slug.
# Known tenants with their own brand asset subdirectories under /theme/ and /static/images/:
_TENANT_BRAND_SUBPATHS = {"biji-biji": "biji-biji/", "skillourfuture": "skillourfuture/"}
_logo_subpath = _TENANT_BRAND_SUBPATHS.get(slug, "")
logo_img = f"{lms_url}/static/{theme_name}/images/{_logo_subpath}logo-horizontal.svg" if theme_name else ""
favicon  = f"{theme_name}/images/favicon.ico" if theme_name else ""
brand_subpath = _TENANT_BRAND_SUBPATHS.get(slug, "")

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
    "ENABLE_LEARNER_HOME_MFE": True,
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
        "MEREKA_PUBLIC_FOOTER": default_footer,
        "BRAND_PRIMARY": primary_color,
        "BRAND_SECONDARY": secondary_color,
        "BRAND_ACCENT": accent_color,
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
        },
    )
    mfe_sc_action = "CREATED" if mfe_sc_created else "UPDATED"

tenant_mapping_action = "SKIPPED"
tenant_config_action = "SKIPPED"
enterprise_uuid = ""

try:
    from enterprise.models import EnterpriseCustomer
    enterprise_customer = (
        EnterpriseCustomer.objects.filter(site=site).order_by("created").first()
        or EnterpriseCustomer.objects.filter(slug=slug).order_by("created").first()
    )
except Exception:
    enterprise_customer = None

if enterprise_customer is not None:
    enterprise_uuid = str(enterprise_customer.uuid)
    from openedx_tenant_cache.models import TenantSiteConfiguration, TenantSiteMapping

    branding_config = {
        "logo_url": site_values.get("logo_image", ""),
        "favicon_url": favicon,
        "primary_color": primary_color,
        "secondary_color": secondary_color,
        "accent_color": accent_color,
        "footer_text": default_footer.get("support", {}).get("contactSupportLabel", ""),
        "sender_alias": name,
    }
    tenant_values = {
        "PLATFORM_NAME": name,
        "SITE_NAME": name,
        "logo_url": site_values.get("logo_image", ""),
        "favicon_url": favicon,
        "primary_color": primary_color,
        "secondary_color": secondary_color,
        "accent_color": accent_color,
        "text_on_primary_color": "#ffffff",
        "footer_text": default_footer.get("support", {}).get("contactSupportLabel", ""),
        "sender_alias": name,
    }
    tenant_mfe_config = {
        "SITE_NAME": name,
        "LOGO_URL": f"https://{mfe_origin}/theme/{brand_subpath}logo-horizontal.svg" if theme_name else "",
        "LOGO_TRADEMARK_URL": f"https://{mfe_origin}/theme/{brand_subpath}logo.svg" if theme_name else "",
        "LOGO_WHITE_URL": f"https://{mfe_origin}/theme/{brand_subpath}logo-horizontal-white.svg" if theme_name else "",
        "FAVICON_URL": f"https://{mfe_origin}/theme/favicon.ico" if theme_name else "",
        "PRIMARY_COLOR": primary_color,
        "SECONDARY_COLOR": secondary_color,
        "ACCENT_COLOR": accent_color,
        "TEXT_ON_PRIMARY": "#ffffff",
        "BRAND_PRIMARY": primary_color,
        "BRAND_SECONDARY": secondary_color,
        "BRAND_ACCENT": accent_color,
        "MEREKA_PUBLIC_FOOTER": default_footer,
    }

    mapping = TenantSiteMapping.objects.filter(slug=slug).first()
    if mapping is None:
        mapping = TenantSiteMapping.objects.filter(
            enterprise_customer_uuid=enterprise_customer.uuid
        ).first()

    if mapping is None:
        mapping = TenantSiteMapping.objects.create(
            enterprise_customer_uuid=enterprise_customer.uuid,
            site=site,
            slug=slug,
            name=name,
            is_active=True,
            branding_config=branding_config,
        )
        tenant_mapping_action = "CREATED"
    else:
        mapping_action_changed = False
        if mapping.enterprise_customer_uuid != enterprise_customer.uuid:
            mapping.enterprise_customer_uuid = enterprise_customer.uuid
            mapping_action_changed = True
        if mapping.site_id != site.id:
            mapping.site = site
            mapping_action_changed = True
        if mapping.slug != slug:
            mapping.slug = slug
            mapping_action_changed = True
        if mapping.name != name:
            mapping.name = name
            mapping_action_changed = True
        if not mapping.is_active:
            mapping.is_active = True
            mapping_action_changed = True
        if mapping.branding_config != branding_config:
            mapping.branding_config = branding_config
            mapping_action_changed = True
        if mapping_action_changed:
            mapping.save()
            tenant_mapping_action = "UPDATED"
        else:
            tenant_mapping_action = "UNCHANGED"

    tenant_config, tenant_config_created = TenantSiteConfiguration.objects.get_or_create(
        tenant=mapping,
        defaults={
            "values": tenant_values,
            "mfe_config": tenant_mfe_config,
            "is_active": True,
        },
    )
    if tenant_config_created:
        tenant_config_action = "CREATED"
    else:
        merged_values = dict(tenant_config.values or {})
        merged_values.update(tenant_values)
        merged_mfe = dict(tenant_config.mfe_config or {})
        merged_mfe.update(tenant_mfe_config)
        tenant_config_changed = (
            merged_values != (tenant_config.values or {})
            or merged_mfe != (tenant_config.mfe_config or {})
            or not tenant_config.is_active
        )
        if tenant_config_changed:
            tenant_config.values = merged_values
            tenant_config.mfe_config = merged_mfe
            tenant_config.is_active = True
            tenant_config.save()
            tenant_config_action = "UPDATED"
        else:
            tenant_config_action = "UNCHANGED"

result = {
    "tenant": slug,
    "domain": domain,
    "site_id": site.id,
    "enterprise_uuid": enterprise_uuid,
    "site_action": site_action,
    "sc_action": sc_action,
    "mfe_site_action": mfe_site_action,
    "mfe_sc_action": mfe_sc_action,
    "tenant_mapping_action": tenant_mapping_action,
    "tenant_config_action": tenant_config_action,
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
