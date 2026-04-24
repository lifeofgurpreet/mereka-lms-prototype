#!/usr/bin/env bash
# @covers AC-MTA-001, AC-MTA-002, AC-MTA-021
# @spec: multi-tenancy-architecture_spec.md
# Provision a new tenant in the Open edX platform.
#
# Wraps the Django management command with validation, DNS hints,
# and post-provisioning verification.
#
# Usage:
#   ./scripts/tenants/provision-tenant.sh \
#     --slug acme-corp \
#     --name "Acme Corp" \
#     --domain acme.academyv2.mereka.io \
#     [--contact-email admin@acme.com] \
#     [--country MY] \
#     [--dry-run]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/scripts/shared/config.sh" 2>/dev/null || true

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Defaults
SLUG=""
NAME=""
DOMAIN=""
CONTACT_EMAIL=""
COUNTRY=""
ENTERPRISE_UUID=""
BRANDING_FILE=""
DRY_RUN=0
NAMESPACE="${K8S_NAMESPACE:-mereka-lms}"
CONTEXT_OVERRIDE=""
CONFIRM_PROVISION_TENANT="${CONFIRM_PROVISION_TENANT:-}"
CONFIRM_TOKEN="PROVISION_TENANT"

usage() {
  echo "Usage: $0 --slug SLUG --name NAME --domain DOMAIN [OPTIONS]"
  echo ""
  echo "Required:"
  echo "  --slug          URL-safe tenant slug (e.g. 'acme-corp')"
  echo "  --name          Human-readable tenant name (e.g. 'Acme Corp')"
  echo "  --domain        Primary domain (e.g. 'acme.academyv2.mereka.io')"
  echo ""
  echo "Optional:"
  echo "  --contact-email     Primary contact email"
  echo "  --country           ISO 3166-1 alpha-2 country code (e.g. 'MY')"
  echo "  --enterprise-uuid   Existing EnterpriseCustomer UUID (auto-generated if empty)"
  echo "  --branding-file     Canonical branding payload to apply during provisioning"
  echo "  --from-env          Load configuration from .env file (e.g. scripts/tenants/mereka-tenant.env)"
  echo "  --context NAME      kubectl context override (optional)"
  echo "  --dry-run           Show what would be done without executing"
  echo "  -h, --help          Show this help"
  echo ""
  echo "Safety controls (required when not using --dry-run):"
  echo "  CONFIRM_PROVISION_TENANT=PROVISION_TENANT"
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --slug) SLUG="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --domain) DOMAIN="$2"; shift 2 ;;
    --contact-email) CONTACT_EMAIL="$2"; shift 2 ;;
    --country) COUNTRY="$2"; shift 2 ;;
    --enterprise-uuid) ENTERPRISE_UUID="$2"; shift 2 ;;
    --branding-file) BRANDING_FILE="$2"; shift 2 ;;
    --context) CONTEXT_OVERRIDE="$2"; shift 2 ;;
    --from-env)
      # Load from .env file
      if [[ ! -f "$2" ]]; then
        echo -e "${RED}ERROR${NC}: Environment file not found: $2"
        exit 1
      fi
      # shellcheck source=/dev/null
      source "$2"
      SLUG="${TENANT_SLUG:-$SLUG}"
      NAME="${TENANT_NAME:-$NAME}"
      DOMAIN="${TENANT_DOMAIN:-$DOMAIN}"
      CONTACT_EMAIL="${TENANT_CONTACT_EMAIL:-$CONTACT_EMAIL}"
      COUNTRY="${TENANT_COUNTRY:-$COUNTRY}"
      ENTERPRISE_UUID="${TENANT_ENTERPRISE_UUID:-$ENTERPRISE_UUID}"
      shift 2
      ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# Validate required args
if [[ -z "$SLUG" || -z "$NAME" || -z "$DOMAIN" ]]; then
  echo -e "${RED}ERROR${NC}: --slug, --name, and --domain are required"
  usage
fi

# Validate slug format
if ! echo "$SLUG" | grep -qE '^[a-z0-9][a-z0-9_-]*$'; then
  echo -e "${RED}ERROR${NC}: Slug must be lowercase alphanumeric with hyphens/underscores"
  exit 1
fi

CANONICAL_BRANDING_FILE="$REPO_ROOT/scripts/tenants/${SLUG}-branding.json"
if [[ -z "$BRANDING_FILE" && -f "$CANONICAL_BRANDING_FILE" ]]; then
  BRANDING_FILE="$CANONICAL_BRANDING_FILE"
fi

echo "=== Tenant Provisioning ==="
echo ""
echo "  Slug:             $SLUG"
echo "  Name:             $NAME"
echo "  Domain:           $DOMAIN"
echo "  Contact:          ${CONTACT_EMAIL:-<none>}"
echo "  Country:          ${COUNTRY:-<none>}"
echo "  Enterprise UUID:  ${ENTERPRISE_UUID:-<auto-generate>}"
echo "  Branding file:    ${BRANDING_FILE:-<none>}"
echo ""

if [[ $DRY_RUN -eq 1 ]]; then
  echo -e "${YELLOW}DRY RUN${NC}: Would execute the following Django management command:"
  echo ""
  echo "  manage.py lms provision_tenant \\"
  echo "    --slug '$SLUG' \\"
  echo "    --name '$NAME' \\"
  echo "    --domain '$DOMAIN' \\"
  [[ -n "$CONTACT_EMAIL" ]] && echo "    --contact-email '$CONTACT_EMAIL' \\"
  [[ -n "$COUNTRY" ]] && echo "    --country '$COUNTRY' \\"
  [[ -n "$ENTERPRISE_UUID" ]] && echo "    --enterprise-uuid '$ENTERPRISE_UUID' \\"
  [[ -n "$BRANDING_FILE" ]] && echo "    --branding-file '$BRANDING_FILE' \\"
  echo ""
  echo "Post-provisioning steps:"
  echo "  1. Add DNS record: $DOMAIN → LMS load balancer"
  echo "  2. Add $DOMAIN to ALLOWED_HOSTS and CSRF_TRUSTED_ORIGINS"
  echo "  3. Configure SSO/SAML IdP (if applicable)"
  echo "  4. Upload branding assets to themes/mereka/tenants/$SLUG/"
  echo "  5. Create enterprise catalog and subscription plans"
  echo "  6. Run: scripts/qa/verify-tenant-isolation-patterns.sh"
  exit 0
fi

if [[ "$CONFIRM_PROVISION_TENANT" != "$CONFIRM_TOKEN" ]]; then
  echo -e "${RED}ERROR${NC}: Refusing live provisioning without explicit confirmation token."
  echo "Set CONFIRM_PROVISION_TENANT=${CONFIRM_TOKEN} to execute."
  exit 1
fi

context_args=()
if [[ -n "$CONTEXT_OVERRIDE" ]]; then
  context_args+=(--context "$CONTEXT_OVERRIDE")
elif [[ -n "${K8S_CONTEXT:-}" ]]; then
  context_args+=(--context "$K8S_CONTEXT")
fi

# Detect execution context (K8s vs local Tutor)
if command -v kubectl &>/dev/null && kubectl "${context_args[@]}" get namespace "$NAMESPACE" &>/dev/null 2>&1; then
  echo "Detected Kubernetes environment (namespace: $NAMESPACE)"
  echo ""

  # Determine whether provision_tenant is available in LMS or CMS runtime.
  TARGET_DEPLOY="lms"
  MGMT_VARIANT="lms"
  if ! kubectl "${context_args[@]}" exec -n "$NAMESPACE" deploy/lms -- \
      bash -lc "python manage.py lms help | grep -qE '^\\s*provision_tenant$'" >/dev/null 2>&1; then
    if kubectl "${context_args[@]}" exec -n "$NAMESPACE" deploy/cms -- \
      bash -lc "python manage.py cms help | grep -qE '^\\s*provision_tenant$'" >/dev/null 2>&1; then
      TARGET_DEPLOY="cms"
      MGMT_VARIANT="cms"
    else
      echo -e "${RED}ERROR${NC}: provision_tenant command not found in LMS or CMS runtime"
      exit 1
    fi
  fi

  TARGET_POD=$(kubectl "${context_args[@]}" get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=${TARGET_DEPLOY}" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [[ -z "$TARGET_POD" ]]; then
    echo -e "${RED}ERROR${NC}: No running ${TARGET_DEPLOY} pod found in namespace $NAMESPACE"
    exit 1
  fi
  echo "Using ${TARGET_DEPLOY^^} pod: $TARGET_POD"
  echo "Command variant: manage.py ${MGMT_VARIANT} provision_tenant"

  # Build command args
  CMD_ARGS="--slug '$SLUG' --name '$NAME' --domain '$DOMAIN'"
  [[ -n "$CONTACT_EMAIL" ]] && CMD_ARGS="$CMD_ARGS --contact-email '$CONTACT_EMAIL'"
  [[ -n "$COUNTRY" ]] && CMD_ARGS="$CMD_ARGS --country '$COUNTRY'"
  [[ -n "$ENTERPRISE_UUID" ]] && CMD_ARGS="$CMD_ARGS --enterprise-uuid '$ENTERPRISE_UUID'"
  [[ -n "$BRANDING_FILE" ]] && CMD_ARGS="$CMD_ARGS --branding-file '$BRANDING_FILE'"

  # Run the management command
  kubectl "${context_args[@]}" exec -n "$NAMESPACE" "$TARGET_POD" -- \
    bash -c "python manage.py ${MGMT_VARIANT} provision_tenant $CMD_ARGS"

elif command -v tutor &>/dev/null; then
  echo "Detected Tutor environment"
  echo ""

  # Build command args
  CMD_ARGS="--slug $SLUG --name \"$NAME\" --domain $DOMAIN"
  [[ -n "$CONTACT_EMAIL" ]] && CMD_ARGS="$CMD_ARGS --contact-email $CONTACT_EMAIL"
  [[ -n "$COUNTRY" ]] && CMD_ARGS="$CMD_ARGS --country $COUNTRY"
  [[ -n "$ENTERPRISE_UUID" ]] && CMD_ARGS="$CMD_ARGS --enterprise-uuid $ENTERPRISE_UUID"
  [[ -n "$BRANDING_FILE" ]] && CMD_ARGS="$CMD_ARGS --branding-file \"$BRANDING_FILE\""

  tutor local run lms bash -c "python manage.py lms provision_tenant $CMD_ARGS"

else
  echo -e "${RED}ERROR${NC}: Neither kubectl nor tutor found. Cannot provision tenant."
  exit 1
fi

echo ""
echo -e "${GREEN}=== Provisioning Complete ===${NC}"
echo ""
echo "Next steps:"
echo "  1. Add DNS: $DOMAIN → LMS load balancer IP"
echo "  2. Update ALLOWED_HOSTS and CSRF_TRUSTED_ORIGINS in LMS settings"
echo "  3. Configure tenant SSO (if applicable)"
if [[ -n "$BRANDING_FILE" ]]; then
  echo "  4. Canonical branding applied from: $BRANDING_FILE"
else
  echo "  4. Add canonical branding payload: scripts/tenants/${SLUG}-branding.json"
fi
echo "  5. Create enterprise catalog and subscription plans"
echo "  6. Verify isolation: ./scripts/qa/verify-tenant-isolation-patterns.sh"
