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
FORCE_DELETE=0
GRACE_DAYS=30
ACTOR="${USER:-unknown}"

usage() {
  echo "Usage: $0 --slug SLUG [OPTIONS]"
  echo ""
  echo "Required:"
  echo "  --slug          Tenant slug to offboard (e.g. 'acme-corp')"
  echo ""
  echo "Optional:"
  echo "  --export-dir    Directory for data export (default: /tmp/tenant-export-{slug})"
  echo "  --force-delete  Execute data deletion (only after grace period)"
  echo "  --grace-days N  Grace period in days (default: 30)"
  echo "  --actor ACTOR   Who initiated offboarding (default: \$USER)"
  echo "  --dry-run       Show what would be done without executing"
  echo "  -h, --help      Show this help"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --slug) SLUG="$2"; shift 2 ;;
    --export-dir) EXPORT_DIR="$2"; shift 2 ;;
    --force-delete) FORCE_DELETE=1; shift ;;
    --grace-days) GRACE_DAYS="$2"; shift 2 ;;
    --actor) ACTOR="$2"; shift 2 ;;
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
echo "  Slug:        $SLUG"
echo "  Timestamp:   $TIMESTAMP"
echo "  Export dir:  $EXPORT_DIR"
echo "  Actor:       $ACTOR"
echo "  Mode:        $([ $FORCE_DELETE -eq 1 ] && echo 'DELETE' || echo 'DEACTIVATE')"
echo "  Grace days:  $GRACE_DAYS"
echo ""

# Build the Django management command arguments
CMD_ARGS="--slug $SLUG --export-dir $EXPORT_DIR --grace-days $GRACE_DAYS --actor $ACTOR"
if [[ $DRY_RUN -eq 1 ]]; then
  CMD_ARGS="$CMD_ARGS --dry-run"
fi
if [[ $FORCE_DELETE -eq 1 ]]; then
  CMD_ARGS="$CMD_ARGS --force-delete"
fi

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

  kubectl exec -n "$NAMESPACE" "$LMS_POD" -- \
    python manage.py lms offboard_tenant $CMD_ARGS

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

  tutor local run lms python manage.py lms offboard_tenant $CMD_ARGS

else
  echo -e "${RED}ERROR${NC}: Neither kubectl nor tutor found. Cannot offboard tenant."
  exit 1
fi

echo ""
if [[ $DRY_RUN -eq 1 ]]; then
  echo -e "${YELLOW}=== DRY RUN COMPLETE ===${NC}"
  echo "No changes made."
elif [[ $FORCE_DELETE -eq 1 ]]; then
  echo -e "${GREEN}=== Full Deletion Complete ===${NC}"
  echo ""
  echo "Tenant '$SLUG' has been fully deleted."
  echo "Audit log: $EXPORT_DIR/"
else
  echo -e "${GREEN}=== Offboarding Complete ===${NC}"
  echo ""
  echo "Tenant '$SLUG' has been deactivated."
  echo ""
  echo "Grace period: $GRACE_DAYS days from $TIMESTAMP"
  echo "Actor: $ACTOR"
  echo ""
  echo "Next steps:"
  echo "  1. Review export at: $EXPORT_DIR/"
  echo "  2. Notify tenant of data availability"
  echo "  3. After ${GRACE_DAYS}-day grace period:"
  echo "     ./scripts/tenants/offboard-tenant.sh --slug $SLUG --force-delete"
fi
