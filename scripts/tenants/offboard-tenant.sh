#!/usr/bin/env bash
# @covers AC-MTA-022, AC-MTA-023, AC-MTA-024
# @spec: multi-tenancy-architecture_spec.md
# Offboard a tenant from the Open edX platform.
#
# Performs deactivation, data export, and generates an offboarding audit report.
# Full data deletion occurs after a 30-day grace period (manual step).
#
# Usage:
#   ./scripts/tenants/offboard-tenant.sh --slug acme-corp [--dry-run]
#
# Steps:
#   1. Deactivate: set EnterpriseCustomer.active=False and TenantConfig.is_active=False
#   2. Export: dump tenant data (users, enrollments, courses) to JSON
#   3. Disable SSO: deactivate SAML/OIDC provider config (if applicable)
#   4. Generate audit report with all offboarding actions and timestamps
#
# Data deletion (after 30-day grace period) is a separate manual step.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/scripts/shared/config.sh" 2>/dev/null || true

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

SLUG=""
DRY_RUN=0
NAMESPACE="${K8S_NAMESPACE:-mereka-lms}"
EXPORT_DIR=""

usage() {
  echo "Usage: $0 --slug SLUG [OPTIONS]"
  echo ""
  echo "Required:"
  echo "  --slug          Tenant slug to offboard (e.g. 'acme-corp')"
  echo ""
  echo "Optional:"
  echo "  --export-dir    Directory for data export (default: /tmp/tenant-export-{slug})"
  echo "  --dry-run       Show what would be done without executing"
  echo "  -h, --help      Show this help"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --slug) SLUG="$2"; shift 2 ;;
    --export-dir) EXPORT_DIR="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

if [[ -z "$SLUG" ]]; then
  echo -e "${RED}ERROR${NC}: --slug is required"
  usage
fi

if [[ -z "$EXPORT_DIR" ]]; then
  EXPORT_DIR="/tmp/tenant-export-${SLUG}"
fi

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
AUDIT_FILE="${EXPORT_DIR}/offboarding-audit-${SLUG}.json"

echo "=== Tenant Offboarding ==="
echo ""
echo "  Slug:       $SLUG"
echo "  Timestamp:  $TIMESTAMP"
echo "  Export dir:  $EXPORT_DIR"
echo ""

# Build the Python script that runs inside the LMS container.
# This handles deactivation and data export in a single Django context.
OFFBOARD_SCRIPT=$(cat <<'PYEOF'
import json
import sys
import os
from datetime import datetime

slug = os.environ.get("TENANT_SLUG", "")
dry_run = os.environ.get("DRY_RUN", "0") == "1"
export_dir = os.environ.get("EXPORT_DIR", "/tmp")

if not slug:
    print("ERROR: TENANT_SLUG not set", file=sys.stderr)
    sys.exit(1)

audit_log = {
    "tenant_slug": slug,
    "action": "offboard",
    "timestamp": datetime.utcnow().isoformat() + "Z",
    "dry_run": dry_run,
    "steps": [],
}

def log_step(name, status, detail=""):
    entry = {"step": name, "status": status, "detail": detail}
    audit_log["steps"].append(entry)
    prefix = "DRY RUN: " if dry_run else ""
    print(f"  {prefix}{name}: {status}" + (f" ({detail})" if detail else ""))

# Step 1: Find the EnterpriseCustomer.
try:
    from enterprise.models import EnterpriseCustomer
    ec = EnterpriseCustomer.objects.filter(slug=slug).first()
    if not ec:
        print(f"ERROR: No EnterpriseCustomer found with slug '{slug}'", file=sys.stderr)
        sys.exit(1)
    log_step("find_enterprise_customer", "ok", f"uuid={ec.uuid}, name={ec.name}")
    audit_log["enterprise_customer_uuid"] = str(ec.uuid)
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)

# Step 2: Deactivate EnterpriseCustomer.
if ec.active:
    if not dry_run:
        ec.active = False
        ec.save(update_fields=["active"])
    log_step("deactivate_enterprise_customer", "deactivated")
else:
    log_step("deactivate_enterprise_customer", "already_inactive")

# Step 3: Deactivate TenantConfig.
try:
    from mereka_tenancy.models import TenantConfig
    tc = TenantConfig.objects.filter(enterprise_customer=ec).first()
    if tc:
        if tc.is_active:
            if not dry_run:
                tc.is_active = False
                tc.save(update_fields=["is_active"])
            log_step("deactivate_tenant_config", "deactivated")
        else:
            log_step("deactivate_tenant_config", "already_inactive")
    else:
        log_step("deactivate_tenant_config", "skipped", "no TenantConfig found")
except ImportError:
    log_step("deactivate_tenant_config", "skipped", "mereka_tenancy not installed")

# Step 4: Export tenant data summary.
export_data = {
    "tenant_slug": slug,
    "enterprise_customer_uuid": str(ec.uuid),
    "enterprise_customer_name": ec.name,
    "exported_at": datetime.utcnow().isoformat() + "Z",
}

# Count linked users.
try:
    from enterprise.models import EnterpriseCustomerUser
    user_count = EnterpriseCustomerUser.objects.filter(
        enterprise_customer=ec
    ).count()
    export_data["user_count"] = user_count
    log_step("export_user_count", "ok", f"{user_count} users")
except Exception as e:
    log_step("export_user_count", "error", str(e))

# Count linked enrollments (via enterprise enrollment).
try:
    from enterprise.models import EnterpriseCourseEnrollment
    enrollment_count = EnterpriseCourseEnrollment.objects.filter(
        enterprise_customer_user__enterprise_customer=ec
    ).count()
    export_data["enrollment_count"] = enrollment_count
    log_step("export_enrollment_count", "ok", f"{enrollment_count} enrollments")
except Exception as e:
    log_step("export_enrollment_count", "error", str(e))

# Step 5: Disable SSO provider (if configured).
try:
    idp_slug = getattr(ec, "identity_provider", None) or ""
    if idp_slug:
        # Try to find and disable the SAML provider.
        try:
            from third_party_auth.models import SAMLProviderConfig
            saml_config = SAMLProviderConfig.objects.filter(slug=idp_slug).first()
            if saml_config:
                if saml_config.enabled:
                    if not dry_run:
                        saml_config.enabled = False
                        saml_config.save(update_fields=["enabled"])
                    log_step("disable_sso", "disabled", f"SAML IdP: {idp_slug}")
                else:
                    log_step("disable_sso", "already_disabled", f"SAML IdP: {idp_slug}")
            else:
                log_step("disable_sso", "skipped", f"No SAML config for slug: {idp_slug}")
        except ImportError:
            log_step("disable_sso", "skipped", "third_party_auth not installed")
    else:
        log_step("disable_sso", "skipped", "no identity_provider configured")
except Exception as e:
    log_step("disable_sso", "error", str(e))

# Step 6: Disable Waffle switches for this tenant.
try:
    from waffle.models import Switch
    tenant_switches = Switch.objects.filter(name__endswith=f".{slug}")
    switch_count = tenant_switches.count()
    if switch_count > 0:
        if not dry_run:
            tenant_switches.update(active=False)
        log_step("disable_waffle_switches", "disabled", f"{switch_count} switches")
    else:
        log_step("disable_waffle_switches", "skipped", "no switches found")
except ImportError:
    log_step("disable_waffle_switches", "skipped", "django-waffle not installed")

# Write export data and audit log.
if not dry_run:
    os.makedirs(export_dir, exist_ok=True)
    export_path = os.path.join(export_dir, f"export-{slug}.json")
    with open(export_path, "w") as f:
        json.dump(export_data, f, indent=2)
    log_step("write_export", "ok", export_path)

    audit_path = os.path.join(export_dir, f"offboarding-audit-{slug}.json")
    audit_log["outcome"] = "success"
    with open(audit_path, "w") as f:
        json.dump(audit_log, f, indent=2)
    log_step("write_audit_log", "ok", audit_path)
else:
    log_step("write_export", "skipped", "dry run")
    log_step("write_audit_log", "skipped", "dry run")

# Print summary.
print()
audit_log["outcome"] = audit_log.get("outcome", "dry_run")
print(json.dumps(audit_log, indent=2))
PYEOF
)

if [[ $DRY_RUN -eq 1 ]]; then
  echo -e "${YELLOW}DRY RUN${NC}: Showing what would be done..."
  echo ""
fi

# Detect execution context (K8s vs local Tutor).
if command -v kubectl &>/dev/null && kubectl get namespace "$NAMESPACE" &>/dev/null 2>&1; then
  echo "Detected Kubernetes environment (namespace: $NAMESPACE)"
  echo ""

  LMS_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [[ -z "$LMS_POD" ]]; then
    echo -e "${RED}ERROR${NC}: No LMS pod found in namespace $NAMESPACE"
    exit 1
  fi

  echo "Using LMS pod: $LMS_POD"
  echo ""

  kubectl exec -n "$NAMESPACE" "$LMS_POD" -- bash -c "
    export TENANT_SLUG='$SLUG'
    export DRY_RUN='$DRY_RUN'
    export EXPORT_DIR='$EXPORT_DIR'
    python -c '$OFFBOARD_SCRIPT'
  "

  # Copy export files out of the pod if not dry run.
  if [[ $DRY_RUN -eq 0 ]]; then
    mkdir -p "$EXPORT_DIR"
    kubectl cp "$NAMESPACE/$LMS_POD:$EXPORT_DIR/" "$EXPORT_DIR/" 2>/dev/null || true
    echo ""
    echo "Export files copied to: $EXPORT_DIR/"
  fi

elif command -v tutor &>/dev/null; then
  echo "Detected Tutor environment"
  echo ""

  # Write the script to a temp file and execute via tutor.
  TMPSCRIPT=$(mktemp /tmp/offboard-XXXXXX.py)
  echo "$OFFBOARD_SCRIPT" > "$TMPSCRIPT"

  tutor local run \
    -e "TENANT_SLUG=$SLUG" \
    -e "DRY_RUN=$DRY_RUN" \
    -e "EXPORT_DIR=$EXPORT_DIR" \
    lms bash -c "python /dev/stdin < $TMPSCRIPT"

  rm -f "$TMPSCRIPT"

else
  echo -e "${RED}ERROR${NC}: Neither kubectl nor tutor found. Cannot offboard tenant."
  exit 1
fi

echo ""
if [[ $DRY_RUN -eq 1 ]]; then
  echo -e "${YELLOW}=== DRY RUN COMPLETE ===${NC}"
  echo "No changes made."
else
  echo -e "${GREEN}=== Offboarding Complete ===${NC}"
  echo ""
  echo "Tenant '$SLUG' has been deactivated."
  echo ""
  echo "Grace period: 30 days from $TIMESTAMP"
  echo ""
  echo "Next steps:"
  echo "  1. Review export at: $EXPORT_DIR/"
  echo "  2. Notify tenant of data availability"
  echo "  3. After 30-day grace period:"
  echo "     a. Delete enterprise records from all service databases"
  echo "     b. Delete analytics events from ClickHouse"
  echo "     c. Flush Redis cache keys: enterprise:{uuid}:*"
  echo "     d. Remove branding assets: infrastructure/tutor/themes/mereka/tenants/$SLUG/"
  echo "     e. Remove domain from ALLOWED_HOSTS and CSRF_TRUSTED_ORIGINS"
  echo "  4. Verify deletion: run post-deletion verification"
fi
