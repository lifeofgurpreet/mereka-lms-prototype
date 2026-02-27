#!/usr/bin/env bash
# @spec: auth-sso-enterprise_spec.md
# @covers: AC-005, AC-042, AC-043
# Configure an enterprise tenant IdP (SAML or OIDC) and link it to EnterpriseCustomer.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/scripts/shared/config.sh" 2>/dev/null || true

ENVIRONMENT="prod"
NAMESPACE="${K8S_NAMESPACE:-mereka-lms}"
CONTEXT_OVERRIDE=""
TENANT_SLUG=""
IDP_TYPE=""
IDP_SLUG=""
DISPLAY_NAME=""
DRY_RUN=1
SKIP_ENTERPRISE_LINK=0

# SAML inputs
SAML_METADATA_URL=""
SAML_ENTITY_ID=""

# OIDC inputs
OIDC_CLIENT_ID=""
OIDC_CLIENT_SECRET=""
OIDC_DISCOVERY_URL=""
OIDC_AUTH_URL=""
OIDC_TOKEN_URL=""
OIDC_USERINFO_URL=""

usage() {
  cat <<'USAGE'
Usage: configure-tenant-idp.sh --tenant-slug <slug> --idp-type saml|oidc [options]

Common options:
  --env prod|dev
  --namespace <ns>
  --context <ctx>
  --tenant-slug <slug>
  --idp-type saml|oidc
  --idp-slug <slug>                 Optional provider slug override
  --display-name <name>             Optional provider display name
  --skip-enterprise-link            Do not update EnterpriseCustomer IdP linkage
  --apply                           Apply changes (default is dry-run)
  --dry-run                         Preview changes only (default)

SAML options:
  --metadata-url <url>              Required for --idp-type saml
  --entity-id <idp-entity-id>       Recommended for --idp-type saml

OIDC options:
  --client-id <id>
  --client-secret <secret>
  --discovery-url <url>
  --auth-url <url>
  --token-url <url>
  --user-info-url <url>

Examples:
  ./scripts/tenants/configure-tenant-idp.sh \
    --tenant-slug acme-corp --idp-type saml \
    --metadata-url https://idp.acme.com/metadata --entity-id https://idp.acme.com/entity \
    --apply

  ./scripts/tenants/configure-tenant-idp.sh \
    --tenant-slug acme-corp --idp-type oidc \
    --client-id abc --client-secret xyz \
    --discovery-url https://idp.acme.com/.well-known/openid-configuration \
    --apply
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENVIRONMENT="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --context) CONTEXT_OVERRIDE="$2"; shift 2 ;;
    --tenant-slug) TENANT_SLUG="$2"; shift 2 ;;
    --idp-type) IDP_TYPE="$2"; shift 2 ;;
    --idp-slug) IDP_SLUG="$2"; shift 2 ;;
    --display-name) DISPLAY_NAME="$2"; shift 2 ;;
    --skip-enterprise-link) SKIP_ENTERPRISE_LINK=1; shift ;;
    --metadata-url) SAML_METADATA_URL="$2"; shift 2 ;;
    --entity-id) SAML_ENTITY_ID="$2"; shift 2 ;;
    --client-id) OIDC_CLIENT_ID="$2"; shift 2 ;;
    --client-secret) OIDC_CLIENT_SECRET="$2"; shift 2 ;;
    --discovery-url) OIDC_DISCOVERY_URL="$2"; shift 2 ;;
    --auth-url) OIDC_AUTH_URL="$2"; shift 2 ;;
    --token-url) OIDC_TOKEN_URL="$2"; shift 2 ;;
    --user-info-url) OIDC_USERINFO_URL="$2"; shift 2 ;;
    --apply) DRY_RUN=0; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ "$ENVIRONMENT" != "prod" && "$ENVIRONMENT" != "dev" ]]; then
  echo "Invalid --env '$ENVIRONMENT' (expected prod|dev)" >&2
  exit 1
fi

if [[ -z "$TENANT_SLUG" || -z "$IDP_TYPE" ]]; then
  echo "--tenant-slug and --idp-type are required" >&2
  usage
  exit 1
fi

if [[ "$IDP_TYPE" != "saml" && "$IDP_TYPE" != "oidc" ]]; then
  echo "Invalid --idp-type '$IDP_TYPE' (expected saml|oidc)" >&2
  exit 1
fi

if [[ -z "$DISPLAY_NAME" ]]; then
  DISPLAY_NAME="${TENANT_SLUG} enterprise ${IDP_TYPE}"
fi
if [[ -z "$IDP_SLUG" ]]; then
  if [[ "$IDP_TYPE" == "saml" ]]; then
    IDP_SLUG="tpa-saml-${TENANT_SLUG}"
  else
    IDP_SLUG="oidc-${TENANT_SLUG}"
  fi
fi

if [[ "$IDP_TYPE" == "saml" ]]; then
  if [[ -z "$SAML_METADATA_URL" ]]; then
    echo "--metadata-url is required for --idp-type saml" >&2
    exit 1
  fi
fi

if [[ "$IDP_TYPE" == "oidc" ]]; then
  if [[ -z "$OIDC_CLIENT_ID" || -z "$OIDC_CLIENT_SECRET" ]]; then
    echo "--client-id and --client-secret are required for --idp-type oidc" >&2
    exit 1
  fi
  if [[ -z "$OIDC_DISCOVERY_URL" && ( -z "$OIDC_AUTH_URL" || -z "$OIDC_TOKEN_URL" || -z "$OIDC_USERINFO_URL" ) ]]; then
    echo "For OIDC, provide --discovery-url OR all of --auth-url --token-url --user-info-url" >&2
    exit 1
  fi
fi

DEFAULT_PROD_CTX="gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster"
DEFAULT_DEV_CTX="kind-dev"
K8S_CONTEXT_EFFECTIVE="${CONTEXT_OVERRIDE}"
if [[ -z "$K8S_CONTEXT_EFFECTIVE" ]]; then
  if [[ "$ENVIRONMENT" == "prod" ]]; then
    K8S_CONTEXT_EFFECTIVE="${K8S_CONTEXT:-$DEFAULT_PROD_CTX}"
  else
    K8S_CONTEXT_EFFECTIVE="$DEFAULT_DEV_CTX"
  fi
fi

context_args=()
if [[ -n "$K8S_CONTEXT_EFFECTIVE" ]]; then
  context_args+=(--context "$K8S_CONTEXT_EFFECTIVE")
fi

if [[ "$ENVIRONMENT" == "prod" ]]; then
  LMS_BASE_URL="https://${LMS_DOMAIN:-academyv2.mereka.io}"
else
  LMS_BASE_URL="https://${DEV_LMS_DOMAIN:-academyv2.mereka.dev}"
fi

echo "=== Configure Tenant IdP ==="
echo "env=${ENVIRONMENT} context=${K8S_CONTEXT_EFFECTIVE} namespace=${NAMESPACE}"
echo "tenant_slug=${TENANT_SLUG} idp_type=${IDP_TYPE} idp_slug=${IDP_SLUG} dry_run=${DRY_RUN}"
echo ""

if ! kubectl "${context_args[@]}" get deploy lms -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "LMS deployment not found in namespace '${NAMESPACE}' (context: ${K8S_CONTEXT_EFFECTIVE})" >&2
  exit 1
fi

kubectl "${context_args[@]}" exec -i -n "$NAMESPACE" deploy/lms -- \
  env TENANT_SLUG="$TENANT_SLUG" \
      IDP_TYPE="$IDP_TYPE" \
      IDP_SLUG="$IDP_SLUG" \
      DISPLAY_NAME="$DISPLAY_NAME" \
      DRY_RUN="$DRY_RUN" \
      SKIP_ENTERPRISE_LINK="$SKIP_ENTERPRISE_LINK" \
      SAML_METADATA_URL="$SAML_METADATA_URL" \
      SAML_ENTITY_ID="$SAML_ENTITY_ID" \
      OIDC_CLIENT_ID="$OIDC_CLIENT_ID" \
      OIDC_CLIENT_SECRET="$OIDC_CLIENT_SECRET" \
      OIDC_DISCOVERY_URL="$OIDC_DISCOVERY_URL" \
      OIDC_AUTH_URL="$OIDC_AUTH_URL" \
      OIDC_TOKEN_URL="$OIDC_TOKEN_URL" \
      OIDC_USERINFO_URL="$OIDC_USERINFO_URL" \
      python - <<'PY'
import json
import os
import sys
import django

django.setup()

from django.conf import settings
from django.contrib.sites.models import Site
from openedx.core.djangoapps.site_configuration.models import SiteConfiguration
from enterprise.models import EnterpriseCustomer

TENANT_SLUG = os.environ["TENANT_SLUG"]
IDP_TYPE = os.environ["IDP_TYPE"]
IDP_SLUG = os.environ["IDP_SLUG"]
DISPLAY_NAME = os.environ["DISPLAY_NAME"]
DRY_RUN = os.environ.get("DRY_RUN", "1") == "1"
SKIP_ENTERPRISE_LINK = os.environ.get("SKIP_ENTERPRISE_LINK", "0") == "1"


def model_field_names(model_obj):
    return {f.name for f in model_obj._meta.get_fields()}


def set_if_field(obj, field_names, name, value):
    if value is None:
        return
    if name in field_names:
        setattr(obj, name, value)


ec_qs = EnterpriseCustomer.objects.filter(slug=TENANT_SLUG)
if hasattr(EnterpriseCustomer, "created"):
    ec = ec_qs.order_by("-created").first()
elif hasattr(EnterpriseCustomer, "modified"):
    ec = ec_qs.order_by("-modified").first()
else:
    ec = ec_qs.first()
if ec is None:
    if DRY_RUN:
        print(
            f"DRY-RUN: EnterpriseCustomer slug='{TENANT_SLUG}' not found yet; "
            "would configure IdP after tenant provisioning is applied"
        )
        sys.exit(0)
    print(f"ERROR: EnterpriseCustomer slug='{TENANT_SLUG}' not found")
    sys.exit(2)
if ec.site_id is None:
    print(f"ERROR: EnterpriseCustomer slug='{TENANT_SLUG}' has no site mapping")
    sys.exit(3)

site = Site.objects.filter(id=ec.site_id).first()
if site is None:
    print(f"ERROR: Site id={ec.site_id} not found for tenant '{TENANT_SLUG}'")
    sys.exit(4)

print(f"Tenant '{TENANT_SLUG}' resolved to site domain={site.domain} site_id={site.id}")

# Keep SiteConfiguration in sync with tenant-resolution middleware expectations.
cfg, _ = SiteConfiguration.objects.get_or_create(
    site=site,
    defaults={"enabled": True, "site_values": {}},
)
site_values = cfg.site_values or {}
changed_cfg = False
if str(site_values.get("ENTERPRISE_CUSTOMER_UUID", "")).strip() != str(ec.uuid):
    site_values["ENTERPRISE_CUSTOMER_UUID"] = str(ec.uuid)
    changed_cfg = True
if site_values.get("ENABLE_ENTERPRISE_INTEGRATION") is not True:
    site_values["ENABLE_ENTERPRISE_INTEGRATION"] = True
    changed_cfg = True
if not cfg.enabled:
    cfg.enabled = True
    changed_cfg = True

if changed_cfg:
    if DRY_RUN:
        print("DRY-RUN: would update SiteConfiguration ENTERPRISE_CUSTOMER_UUID + ENABLE_ENTERPRISE_INTEGRATION")
    else:
        cfg.site_values = site_values
        cfg.save(update_fields=["site_values", "enabled"])
        print("Updated SiteConfiguration with tenant enterprise mapping")
else:
    print("SiteConfiguration already aligned for tenant mapping")

created = False
provider_kind = None

if IDP_TYPE == "oidc":
    try:
        from common.djangoapps.third_party_auth.models import OAuth2ProviderConfig
    except Exception:
        from third_party_auth.models import OAuth2ProviderConfig

    qs = OAuth2ProviderConfig.objects.filter(site=site, backend_name="oidc").order_by("-change_date", "-id")
    obj = qs.filter(slug=IDP_SLUG).first()
    if obj is None:
        obj = OAuth2ProviderConfig(site=site, backend_name="oidc")
        created = True

    fields = model_field_names(obj)
    set_if_field(obj, fields, "enabled", True)
    set_if_field(obj, fields, "visible", True)
    set_if_field(obj, fields, "name", DISPLAY_NAME)
    set_if_field(obj, fields, "slug", IDP_SLUG)
    set_if_field(obj, fields, "secondary", False)
    set_if_field(obj, fields, "key", os.environ.get("OIDC_CLIENT_ID"))
    set_if_field(obj, fields, "secret", os.environ.get("OIDC_CLIENT_SECRET"))

    oidc_settings = {
        "DISCOVERY_URL": os.environ.get("OIDC_DISCOVERY_URL", ""),
        "AUTHORIZATION_URL": os.environ.get("OIDC_AUTH_URL", ""),
        "ACCESS_TOKEN_URL": os.environ.get("OIDC_TOKEN_URL", ""),
        "USER_INFO_URL": os.environ.get("OIDC_USERINFO_URL", ""),
    }
    oidc_settings = {k: v for k, v in oidc_settings.items() if v}

    if "other_settings" in fields and oidc_settings:
        set_if_field(obj, fields, "other_settings", json.dumps(oidc_settings, sort_keys=True))

    provider_kind = "OAuth2ProviderConfig"

elif IDP_TYPE == "saml":
    try:
        from common.djangoapps.third_party_auth.models import SAMLConfiguration, SAMLProviderConfig
    except Exception:
        from third_party_auth.models import SAMLConfiguration, SAMLProviderConfig

    qs = SAMLProviderConfig.objects.filter(site=site).order_by("-change_date", "-id")
    obj = qs.filter(slug=IDP_SLUG).first()
    if obj is None:
        obj = SAMLProviderConfig(site=site)
        created = True

    fields = model_field_names(obj)
    set_if_field(obj, fields, "backend_name", "tpa-saml")
    set_if_field(obj, fields, "enabled", True)
    set_if_field(obj, fields, "visible", True)
    set_if_field(obj, fields, "name", DISPLAY_NAME)
    set_if_field(obj, fields, "slug", IDP_SLUG)
    set_if_field(obj, fields, "secondary", False)
    set_if_field(obj, fields, "entity_id", os.environ.get("SAML_ENTITY_ID"))

    metadata_url = os.environ.get("SAML_METADATA_URL", "")
    if metadata_url:
        for metadata_field in ("metadata_source", "metadata_url", "metadata"):
            if metadata_field in fields:
                set_if_field(obj, fields, metadata_field, metadata_url)
                break

    # Common default claim mappings; only applied if the model supports the fields.
    set_if_field(obj, fields, "attr_email", "email")
    set_if_field(obj, fields, "attr_first_name", "first_name")
    set_if_field(obj, fields, "attr_last_name", "last_name")
    set_if_field(obj, fields, "attr_full_name", "name")

    # Ensure SAMLConfiguration exists/enabled for this site.
    # Without this, /auth/saml/metadata.xml returns 404 even when SAMLProviderConfig exists.
    saml_cfg_slug = "default"
    cfg = SAMLConfiguration.objects.filter(site=site, slug=saml_cfg_slug).order_by("-change_date").first()
    cfg_created = False
    if cfg is None:
        cfg = SAMLConfiguration(site=site, slug=saml_cfg_slug)
        cfg_created = True

    cfg_fields = model_field_names(cfg)
    set_if_field(cfg, cfg_fields, "enabled", True)
    set_if_field(
        cfg,
        cfg_fields,
        "entity_id",
        os.environ.get("SAML_SP_ENTITY_ID")
        or getattr(settings, "SOCIAL_AUTH_SAML_SP_ENTITY_ID", "")
        or f"https://{site.domain}",
    )
    set_if_field(
        cfg,
        cfg_fields,
        "public_key",
        os.environ.get("SAML_SP_PUBLIC_CERT") or getattr(settings, "SOCIAL_AUTH_SAML_SP_PUBLIC_CERT", ""),
    )
    set_if_field(
        cfg,
        cfg_fields,
        "private_key",
        os.environ.get("SAML_SP_PRIVATE_KEY") or getattr(settings, "SOCIAL_AUTH_SAML_SP_PRIVATE_KEY", ""),
    )
    set_if_field(
        cfg,
        cfg_fields,
        "org_info_str",
        json.dumps(getattr(settings, "SOCIAL_AUTH_SAML_ORG_INFO", {}), sort_keys=True),
    )
    set_if_field(
        cfg,
        cfg_fields,
        "other_config_str",
        json.dumps(getattr(settings, "SOCIAL_AUTH_SAML_SECURITY_CONFIG", {}), sort_keys=True),
    )

    if "saml_configuration" in fields:
        obj.saml_configuration = cfg

    if DRY_RUN:
        cfg_action = "create" if cfg_created else "update"
        print(f"DRY-RUN: would {cfg_action} SAMLConfiguration slug={saml_cfg_slug} for site={site.domain}")
    else:
        cfg.save()
        cfg_action = "Created" if cfg_created else "Updated"
        print(f"{cfg_action} SAMLConfiguration: id={cfg.id} slug={cfg.slug} site={site.domain} enabled={cfg.enabled}")

    provider_kind = "SAMLProviderConfig"

else:
    print(f"ERROR: unsupported IDP_TYPE={IDP_TYPE}")
    sys.exit(5)

if DRY_RUN:
    action = "create" if created else "update"
    print(f"DRY-RUN: would {action} {provider_kind} slug={IDP_SLUG} for site={site.domain}")
else:
    obj.save()
    action = "Created" if created else "Updated"
    print(f"{action} {provider_kind}: id={obj.id} slug={IDP_SLUG} site={site.domain}")

if SKIP_ENTERPRISE_LINK:
    print("Skipping EnterpriseCustomer IdP linkage by request")
else:
    # Newer enterprise versions use EnterpriseCustomerIdentityProvider mapping.
    linked = False
    try:
        from enterprise.models import EnterpriseCustomerIdentityProvider
    except Exception:
        EnterpriseCustomerIdentityProvider = None

    if EnterpriseCustomerIdentityProvider is not None:
        qs = EnterpriseCustomerIdentityProvider.objects.filter(enterprise_customer=ec)
        existing = qs.filter(provider_id=IDP_SLUG).first()
        if existing is None:
            is_first = not qs.exists()
            if DRY_RUN:
                print(
                    "DRY-RUN: would create EnterpriseCustomerIdentityProvider "
                    f"enterprise={ec.slug} provider_id={IDP_SLUG} default_provider={is_first}"
                )
            else:
                EnterpriseCustomerIdentityProvider.objects.create(
                    enterprise_customer=ec,
                    provider_id=IDP_SLUG,
                    default_provider=is_first,
                )
                print(
                    "Linked EnterpriseCustomer via EnterpriseCustomerIdentityProvider "
                    f"provider_id={IDP_SLUG}"
                )
            linked = True
        else:
            print(
                "EnterpriseCustomerIdentityProvider already linked "
                f"provider_id={IDP_SLUG} default_provider={existing.default_provider}"
            )
            linked = True

    ec_fields = model_field_names(ec)
    if not linked and "identity_provider" in ec_fields:
        current = str(getattr(ec, "identity_provider") or "")
        if current != IDP_SLUG:
            if DRY_RUN:
                print(f"DRY-RUN: would set EnterpriseCustomer.identity_provider {current or 'unset'} -> {IDP_SLUG}")
            else:
                ec.identity_provider = IDP_SLUG
                ec.save(update_fields=["identity_provider"])
                print(f"Linked EnterpriseCustomer.identity_provider -> {IDP_SLUG}")
        else:
            print(f"EnterpriseCustomer.identity_provider already set to {IDP_SLUG}")
    elif not linked:
        print("WARN: EnterpriseCustomer identity-provider linkage model unavailable on this build")
PY

if [[ "$IDP_TYPE" == "saml" && "$DRY_RUN" -eq 0 ]]; then
  if command -v curl >/dev/null 2>&1; then
    metadata_http=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 "${LMS_BASE_URL}/auth/saml/metadata.xml" || echo "000")
    if [[ "$metadata_http" == "200" ]]; then
      echo "PASS: SAML SP metadata endpoint reachable (${LMS_BASE_URL}/auth/saml/metadata.xml)"
    else
      echo "FAIL: SAML SP metadata endpoint returned HTTP ${metadata_http} (${LMS_BASE_URL}/auth/saml/metadata.xml)" >&2
      exit 1
    fi
  else
    echo "WARN: curl not available; skipped metadata endpoint verification"
  fi
fi

echo "Done."
