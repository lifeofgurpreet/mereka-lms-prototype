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
CONTEXT_OVERRIDE=""
CONFIRM_OFFBOARD_TENANT="${CONFIRM_OFFBOARD_TENANT:-}"
CONFIRM_FORCE_DELETE_TENANT="${CONFIRM_FORCE_DELETE_TENANT:-}"
OFFBOARD_CONFIRM_TOKEN="OFFBOARD_TENANT"
FORCE_DELETE_CONFIRM_TOKEN="FORCE_DELETE_TENANT"
ALLOW_PROD_OFFBOARD="${ALLOW_PROD_OFFBOARD:-0}"
CREATE_PREOP_BACKUP="${CREATE_PREOP_BACKUP:-1}"

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
  echo "  --context NAME  kubectl context override (optional)"
  echo "  --dry-run       Show what would be done without executing"
  echo "  -h, --help      Show this help"
  echo ""
  echo "Safety controls (required when not using --dry-run):"
  echo "  CONFIRM_OFFBOARD_TENANT=OFFBOARD_TENANT"
  echo ""
  echo "Additional controls for --force-delete:"
  echo "  CONFIRM_FORCE_DELETE_TENANT=FORCE_DELETE_TENANT"
  echo "  ALLOW_PROD_OFFBOARD=1 (required for prod-like kube contexts)"
  echo "  CREATE_PREOP_BACKUP=1 (default for prod-like kube contexts)"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --slug) SLUG="$2"; shift 2 ;;
    --export-dir) EXPORT_DIR="$2"; shift 2 ;;
    --force-delete) FORCE_DELETE=1; shift ;;
    --grace-days) GRACE_DAYS="$2"; shift 2 ;;
    --actor) ACTOR="$2"; shift 2 ;;
    --context) CONTEXT_OVERRIDE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

require_bool_01() {
  local var_name="$1"
  local value="$2"
  case "$value" in
    0|1) ;;
    *)
      echo -e "${RED}ERROR${NC}: Invalid ${var_name}='${value}' (expected 0 or 1)" >&2
      exit 1
      ;;
  esac
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || {
    echo -e "${RED}ERROR${NC}: Missing command: $cmd" >&2
    exit 1
  }
}

is_prod_like_context() {
  local ctx="$1"
  [[ "$ctx" == *"gke_bbi-k8"* ]] || [[ "$ctx" == "prod" ]] || [[ "$ctx" == "production" ]] || [[ "$ctx" == "gke-prod" ]]
}

require_bool_01 "ALLOW_PROD_OFFBOARD" "$ALLOW_PROD_OFFBOARD"
require_bool_01 "CREATE_PREOP_BACKUP" "$CREATE_PREOP_BACKUP"

if [[ -z "$SLUG" ]]; then
  echo -e "${RED}ERROR${NC}: --slug is required"
  usage
fi

if [[ -z "$EXPORT_DIR" ]]; then
  EXPORT_DIR="/tmp/tenant-export-${SLUG}"
fi

if [[ "$DRY_RUN" -eq 0 ]]; then
  if [[ "$CONFIRM_OFFBOARD_TENANT" != "$OFFBOARD_CONFIRM_TOKEN" ]]; then
    echo -e "${RED}ERROR${NC}: Refusing offboarding without explicit confirmation token."
    echo "Set CONFIRM_OFFBOARD_TENANT=${OFFBOARD_CONFIRM_TOKEN} to execute."
    exit 1
  fi
fi

if [[ "$FORCE_DELETE" -eq 1 ]]; then
  if [[ "$CONFIRM_FORCE_DELETE_TENANT" != "$FORCE_DELETE_CONFIRM_TOKEN" ]]; then
    echo -e "${RED}ERROR${NC}: Refusing force-delete without explicit confirmation token."
    echo "Set CONFIRM_FORCE_DELETE_TENANT=${FORCE_DELETE_CONFIRM_TOKEN} to execute force-delete."
    exit 1
  fi
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

context_args=()
if [[ -n "$CONTEXT_OVERRIDE" ]]; then
  context_args+=(--context "$CONTEXT_OVERRIDE")
elif [[ -n "${K8S_CONTEXT:-}" ]]; then
  context_args+=(--context "$K8S_CONTEXT")
fi

K8S_CONTEXT_EFFECTIVE="${CONTEXT_OVERRIDE:-${K8S_CONTEXT:-}}"
if [[ -z "$K8S_CONTEXT_EFFECTIVE" ]] && command -v kubectl &>/dev/null; then
  K8S_CONTEXT_EFFECTIVE="$(kubectl config current-context 2>/dev/null || true)"
fi

# Detect execution context (K8s vs local Tutor).
if command -v kubectl &>/dev/null && kubectl "${context_args[@]}" get namespace "$NAMESPACE" &>/dev/null 2>&1; then
  if [[ "$DRY_RUN" -eq 0 ]] && is_prod_like_context "$K8S_CONTEXT_EFFECTIVE" && [[ "$ALLOW_PROD_OFFBOARD" != "1" ]]; then
    echo -e "${RED}ERROR${NC}: Refusing non-dry-run offboarding on prod-like context '$K8S_CONTEXT_EFFECTIVE' without ALLOW_PROD_OFFBOARD=1"
    exit 1
  fi

  if [[ "$DRY_RUN" -eq 0 ]] && is_prod_like_context "$K8S_CONTEXT_EFFECTIVE"; then
    if [[ "$CREATE_PREOP_BACKUP" == "1" ]]; then
      require_cmd velero
      backup_name="pre-op-${NAMESPACE}-offboard-${SLUG}-$(date -u +%Y%m%d-%H%M)"
      echo "Creating Velero pre-op backup: $backup_name"
      velero backup create "$backup_name" --include-namespaces "$NAMESPACE" --wait
    else
      echo -e "${YELLOW}WARNING${NC}: CREATE_PREOP_BACKUP=0 on prod-like context '$K8S_CONTEXT_EFFECTIVE' (operator override)"
    fi
  fi

  echo "Detected Kubernetes environment (namespace: $NAMESPACE)"
  echo ""

  TARGET_DEPLOY="lms"
  MGMT_VARIANT="lms"
  if ! kubectl "${context_args[@]}" exec -n "$NAMESPACE" deploy/lms -- \
      bash -lc "python manage.py lms help | grep -qE '^\\s*offboard_tenant$'" >/dev/null 2>&1; then
    if kubectl "${context_args[@]}" exec -n "$NAMESPACE" deploy/cms -- \
      bash -lc "python manage.py cms help | grep -qE '^\\s*offboard_tenant$'" >/dev/null 2>&1; then
      TARGET_DEPLOY="cms"
      MGMT_VARIANT="cms"
    else
      echo -e "${RED}ERROR${NC}: offboard_tenant command not found in LMS or CMS runtime"
      exit 1
    fi
  fi

  TARGET_POD=$(kubectl "${context_args[@]}" get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=${TARGET_DEPLOY}" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [[ -z "$TARGET_POD" ]]; then
    echo -e "${RED}ERROR${NC}: No running ${TARGET_DEPLOY} pod found in namespace $NAMESPACE"
    exit 1
  fi
  echo "Using ${TARGET_DEPLOY^^} pod: $TARGET_POD"
  echo "Command variant: manage.py ${MGMT_VARIANT} offboard_tenant"
  echo ""

  kubectl "${context_args[@]}" exec -n "$NAMESPACE" "$TARGET_POD" -- \
    python manage.py "${MGMT_VARIANT}" offboard_tenant $CMD_ARGS

  # Copy export files out of the pod if not dry run.
  if [[ $DRY_RUN -eq 0 ]]; then
    mkdir -p "$EXPORT_DIR"
    kubectl "${context_args[@]}" cp "$NAMESPACE/$TARGET_POD:$EXPORT_DIR/" "$EXPORT_DIR/" 2>/dev/null || true
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
