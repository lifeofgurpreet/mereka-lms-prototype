#!/usr/bin/env bash
# @covers AC-001 AC-002 AC-021
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
DRY_RUN=0
NAMESPACE="${K8S_NAMESPACE:-mereka-lms}"

usage() {
  echo "Usage: $0 --slug SLUG --name NAME --domain DOMAIN [OPTIONS]"
  echo ""
  echo "Required:"
  echo "  --slug          URL-safe tenant slug (e.g. 'acme-corp')"
  echo "  --name          Human-readable tenant name (e.g. 'Acme Corp')"
  echo "  --domain        Primary domain (e.g. 'acme.academyv2.mereka.io')"
  echo ""
  echo "Optional:"
  echo "  --contact-email Primary contact email"
  echo "  --country       ISO 3166-1 alpha-2 country code (e.g. 'MY')"
  echo "  --dry-run       Show what would be done without executing"
  echo "  -h, --help      Show this help"
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

echo "=== Tenant Provisioning ==="
echo ""
echo "  Slug:     $SLUG"
echo "  Name:     $NAME"
echo "  Domain:   $DOMAIN"
echo "  Contact:  ${CONTACT_EMAIL:-<none>}"
echo "  Country:  ${COUNTRY:-<none>}"
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

# Detect execution context (K8s vs local Tutor)
if command -v kubectl &>/dev/null && kubectl get namespace "$NAMESPACE" &>/dev/null 2>&1; then
  echo "Detected Kubernetes environment (namespace: $NAMESPACE)"
  echo ""

  # Find an LMS pod
  LMS_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [[ -z "$LMS_POD" ]]; then
    echo -e "${RED}ERROR${NC}: No LMS pod found in namespace $NAMESPACE"
    exit 1
  fi

  echo "Using LMS pod: $LMS_POD"

  # Build command args
  CMD_ARGS="--slug '$SLUG' --name '$NAME' --domain '$DOMAIN'"
  [[ -n "$CONTACT_EMAIL" ]] && CMD_ARGS="$CMD_ARGS --contact-email '$CONTACT_EMAIL'"
  [[ -n "$COUNTRY" ]] && CMD_ARGS="$CMD_ARGS --country '$COUNTRY'"

  # Run the management command
  kubectl exec -n "$NAMESPACE" "$LMS_POD" -- \
    bash -c "python manage.py lms provision_tenant $CMD_ARGS"

elif command -v tutor &>/dev/null; then
  echo "Detected Tutor environment"
  echo ""

  # Build command args
  CMD_ARGS="--slug $SLUG --name \"$NAME\" --domain $DOMAIN"
  [[ -n "$CONTACT_EMAIL" ]] && CMD_ARGS="$CMD_ARGS --contact-email $CONTACT_EMAIL"
  [[ -n "$COUNTRY" ]] && CMD_ARGS="$CMD_ARGS --country $COUNTRY"

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
echo "  4. Deploy branding assets to themes/mereka/tenants/$SLUG/"
echo "  5. Create enterprise catalog and subscription plans"
echo "  6. Verify isolation: ./scripts/qa/verify-tenant-isolation-patterns.sh"
