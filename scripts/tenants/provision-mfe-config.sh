#!/usr/bin/env bash
# @covers AC-MTA-015, AC-MTA-016, AC-MTA-017
# @spec: multi-tenancy-architecture_spec.md
# Provision per-tenant MFE configuration via Open edX SiteConfiguration.
#
# The LMS mfe_config_api view (/api/mfe_config/v1) reads from SiteConfiguration.site_values
# and merges the MFE_CONFIG dict with per-site overrides.  This script sets the
# keys that the enterprise MFEs expect: LMS_BASE_URL, LOGO_URL, FAVICON_URL,
# SITE_NAME, and PARAGON_THEME_URLS for branded CSS delivery.
#
# Usage:
#   ./scripts/tenants/provision-mfe-config.sh --tenant mereka
#   ./scripts/tenants/provision-mfe-config.sh --tenant biji-biji
#   ./scripts/tenants/provision-mfe-config.sh --tenant skillourfuture
#   ./scripts/tenants/provision-mfe-config.sh --tenant mereka --dry-run
#   ./scripts/tenants/provision-mfe-config.sh --tenant mereka --context gke_...
#
# Reference env.config.js files (per-tenant MFE values used as input):
#   deploy/k8s/base/apps/enterprise/mfe/enterprise-mfe-env.js     (mereka)
#   deploy/k8s/base/apps/enterprise/mfe/biji-biji-mfe-env.js      (biji-biji)
#   deploy/k8s/base/apps/enterprise/mfe/skillourfuture-mfe-env.js (skillourfuture)
#
# How it works:
#   - Calls Django management command `provision_mfe_config` to set SiteConfiguration
#     site_values with MFE_CONFIG keys on the Site that matches the tenant domain.
#   - Idempotent: running twice is safe (uses update_or_create pattern).
#   - Live-cluster only: SiteConfiguration is runtime DB state, not K8s config.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/scripts/shared/config.sh" 2>/dev/null || true

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

TENANT=""
DRY_RUN=0
NAMESPACE="${K8S_NAMESPACE:-mereka-lms}"
CONTEXT_OVERRIDE=""

# Per-tenant configuration table.
# Values match the env.config.js files in deploy/k8s/base/apps/enterprise/mfe/.
declare -A TENANT_LMS_URL=(
  [mereka]="https://academyv2.mereka.io"
  [biji-biji]="https://academy.biji-biji.com"
  [skillourfuture]="https://skillourfuture.academy.mereka.io"
)

declare -A TENANT_STUDIO_URL=(
  [mereka]="https://studio.academyv2.mereka.io"
  [biji-biji]="https://studio.academy.biji-biji.com"
  [skillourfuture]="https://studio.skillourfuture.academy.mereka.io"
)

declare -A TENANT_MFE_URL=(
  [mereka]="https://apps.academyv2.mereka.io"
  [biji-biji]="https://apps.academy.biji-biji.com"
  [skillourfuture]="https://apps.skillourfuture.academy.mereka.io"
)

declare -A TENANT_SITE_NAME=(
  [mereka]="Mereka Academy"
  [biji-biji]="Biji-Biji Academy"
  [skillourfuture]="SkillOurFuture Academy"
)

# Paragon brand CSS filenames (served from /theme/ in the enterprise MFE container)
declare -A TENANT_BRAND_CORE_CSS=(
  [mereka]="mereka-brand.min.css"
  [biji-biji]="biji-biji-brand.min.css"
  [skillourfuture]="sof-brand.min.css"
)

declare -A TENANT_BRAND_LIGHT_CSS=(
  [mereka]="mereka-brand-light.min.css"
  [biji-biji]="biji-biji-brand-light.min.css"
  [skillourfuture]="sof-brand-light.min.css"
)

usage() {
  cat <<EOF
Usage: $0 --tenant TENANT [OPTIONS]

Required:
  --tenant TENANT     Tenant name: mereka | biji-biji | skillourfuture

Optional:
  --context NAME      kubectl context override
  --dry-run           Show what would be set without executing
  -h, --help          Show this help
EOF
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant) TENANT="$2"; shift 2 ;;
    --context) CONTEXT_OVERRIDE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# Validate tenant
KNOWN_TENANTS="mereka biji-biji skillourfuture"
if [[ -z "$TENANT" ]]; then
  echo -e "${RED}ERROR${NC}: --tenant is required (one of: $KNOWN_TENANTS)"
  usage
fi

if [[ -z "${TENANT_LMS_URL[$TENANT]:-}" ]]; then
  echo -e "${RED}ERROR${NC}: Unknown tenant '$TENANT'. Known tenants: $KNOWN_TENANTS"
  exit 1
fi

LMS_URL="${TENANT_LMS_URL[$TENANT]}"
STUDIO_URL="${TENANT_STUDIO_URL[$TENANT]}"
MFE_URL="${TENANT_MFE_URL[$TENANT]}"
SITE_NAME="${TENANT_SITE_NAME[$TENANT]}"
BRAND_CORE_CSS="${TENANT_BRAND_CORE_CSS[$TENANT]}"
BRAND_LIGHT_CSS="${TENANT_BRAND_LIGHT_CSS[$TENANT]}"

# The MFE_CONFIG_API_TENANT_DOMAIN is the LMS domain (strips https://)
LMS_DOMAIN="${LMS_URL#https://}"

echo "=== MFE Config API Provisioning ==="
echo ""
echo "  Tenant:         $TENANT"
echo "  LMS URL:        $LMS_URL"
echo "  Studio URL:     $STUDIO_URL"
echo "  MFE URL:        $MFE_URL"
echo "  Site Name:      $SITE_NAME"
echo "  LMS Domain:     $LMS_DOMAIN"
echo "  Brand Core CSS: $BRAND_CORE_CSS"
echo "  Brand Light CSS: $BRAND_LIGHT_CSS"
echo ""

# The Python snippet that sets SiteConfiguration.site_values MFE_CONFIG keys.
# This is the body of the management command call that will run inside the LMS pod.
# We inline it here so the script is self-contained and the command is auditable.
PYTHON_SNIPPET=$(cat <<PYEOF
import json, sys

try:
    from django.contrib.sites.models import Site
    from openedx.core.djangoapps.site_configuration.models import SiteConfiguration
except ImportError as e:
    print(f"ERROR: Import failed: {e}", file=sys.stderr)
    sys.exit(1)

lms_domain = "${LMS_DOMAIN}"
lms_url = "${LMS_URL}"
studio_url = "${STUDIO_URL}"
mfe_url = "${MFE_URL}"
site_name = "${SITE_NAME}"
brand_core_css = "${BRAND_CORE_CSS}"
brand_light_css = "${BRAND_LIGHT_CSS}"

# Locate the Site for this tenant domain.
site = Site.objects.filter(domain=lms_domain).first()
if not site:
    print(f"ERROR: No Django Site found for domain '{lms_domain}'.")
    print("       Run provision-tenant.sh first to create the Site.")
    sys.exit(1)

site_config, created = SiteConfiguration.objects.get_or_create(
    site=site,
    defaults={"site_values": {}, "enabled": True},
)

values = dict(site_config.site_values or {})

# MFE_CONFIG overlay: keys returned by /api/mfe_config/v1 for this site.
# These override the global MFE_CONFIG set in LMS production settings.
mfe_overlay = {
    "LMS_BASE_URL": lms_url,
    "STUDIO_BASE_URL": studio_url,
    "SITE_NAME": site_name,
    "PLATFORM_NAME": site_name,
    "FAVICON_URL": f"{mfe_url}/favicon.ico",
    "LOGO_URL": f"{mfe_url}/logo.svg",
    "LOGO_WHITE_URL": f"{mfe_url}/logo-white.svg",
    "LOGO_TRADEMARK_URL": f"{mfe_url}/logo-trademark.svg",
    "PARAGON_THEME_URLS": {
        "core": {
            "urls": {
                "default": f"{mfe_url}/theme/core.min.css",
                "brandOverride": f"{mfe_url}/theme/{brand_core_css}",
            }
        },
        "variants": {
            "light": {
                "urls": {
                    "default": f"{mfe_url}/theme/light.min.css",
                    "brandOverride": f"{mfe_url}/theme/{brand_light_css}",
                }
            }
        },
    },
}

# Merge: MFE_CONFIG sub-key in site_values is the per-site override dict.
values.setdefault("MFE_CONFIG", {})
values["MFE_CONFIG"].update(mfe_overlay)
site_config.site_values = values
site_config.enabled = True
site_config.save()

action = "Created" if created else "Updated"
print(f"{action} SiteConfiguration MFE_CONFIG for site '{lms_domain}' (site_id={site.id})")
print(f"  Keys set: {list(mfe_overlay.keys())}")
PYEOF
)

if [[ $DRY_RUN -eq 1 ]]; then
  echo -e "${YELLOW}DRY RUN${NC}: Would set the following SiteConfiguration MFE_CONFIG keys"
  echo "  for Django Site domain '${LMS_DOMAIN}':"
  echo ""
  echo "  MFE_CONFIG = {"
  echo "    LMS_BASE_URL:          ${LMS_URL}"
  echo "    STUDIO_BASE_URL:       ${STUDIO_URL}"
  echo "    SITE_NAME:             ${SITE_NAME}"
  echo "    PLATFORM_NAME:         ${SITE_NAME}"
  echo "    FAVICON_URL:           ${MFE_URL}/favicon.ico"
  echo "    LOGO_URL:              ${MFE_URL}/logo.svg"
  echo "    LOGO_WHITE_URL:        ${MFE_URL}/logo-white.svg"
  echo "    LOGO_TRADEMARK_URL:    ${MFE_URL}/logo-trademark.svg"
  echo "    PARAGON_THEME_URLS:    {core, variants.light} -> ${MFE_URL}/theme/"
  echo "  }"
  echo ""
  echo "Prerequisite: Site for '${LMS_DOMAIN}' must exist"
  echo "  (created by provision-tenant.sh --domain ${LMS_DOMAIN})"
  echo ""
  echo "After provisioning:"
  echo "  1. Verify: curl https://${LMS_DOMAIN}/api/mfe_config/v1 | python3 -m json.tool"
  echo "  2. Check SITE_NAME and LMS_BASE_URL in response match expected values"
  echo "  3. Run: ./scripts/qa/verify-mfe-config-api.sh"
  exit 0
fi

context_args=()
if [[ -n "$CONTEXT_OVERRIDE" ]]; then
  context_args+=(--context "$CONTEXT_OVERRIDE")
elif [[ -n "${K8S_CONTEXT:-}" ]]; then
  context_args+=(--context "$K8S_CONTEXT")
fi

# Detect execution context: K8s or local Tutor
if command -v kubectl &>/dev/null && kubectl "${context_args[@]}" get namespace "$NAMESPACE" &>/dev/null 2>&1; then
  echo "Detected Kubernetes environment (namespace: $NAMESPACE)"
  echo ""

  TARGET_POD=$(kubectl "${context_args[@]}" get pods -n "$NAMESPACE" \
    -l "app.kubernetes.io/name=lms" \
    --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -z "$TARGET_POD" ]]; then
    echo -e "${RED}ERROR${NC}: No running lms pod found in namespace $NAMESPACE"
    exit 1
  fi

  echo "Using LMS pod: $TARGET_POD"

  kubectl "${context_args[@]}" exec -n "$NAMESPACE" "$TARGET_POD" -- \
    bash -c "python manage.py lms shell -c $(printf '%q' "$PYTHON_SNIPPET")"

elif command -v tutor &>/dev/null; then
  echo "Detected Tutor environment"
  echo ""

  tutor local run lms bash -c "python manage.py lms shell -c $(printf '%q' "$PYTHON_SNIPPET")"

else
  echo -e "${RED}ERROR${NC}: Neither kubectl nor tutor found. Cannot provision MFE config."
  exit 1
fi

echo ""
echo -e "${GREEN}=== MFE Config Provisioning Complete ===${NC}"
echo ""
echo "Next steps:"
echo "  1. Verify: curl https://${LMS_DOMAIN}/api/mfe_config/v1 | python3 -m json.tool"
echo "  2. Check SITE_NAME=${SITE_NAME} and LMS_BASE_URL=${LMS_URL} in response"
echo "  3. Run: ./scripts/qa/verify-mfe-config-api.sh"
