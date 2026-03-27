#!/usr/bin/env bash
# @covers AC-001
# @spec: multi-site-domains_spec.md
# Apply multisite configuration to production/dev/staging LMS database.
# This script runs the canonical Django multisite bootstrap helper inside an
# LMS or CMS pod to reconcile django_site and SiteConfiguration rows from the
# repo-owned multisite definitions.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
NAMESPACE="${NAMESPACE:-mereka-lms}"
DRY_RUN="${DRY_RUN:-true}"
ENVIRONMENT="${ENVIRONMENT:-prod}"
DEFINITIONS_PATH=""
ALLOWLIST_PATH="$REPO_ROOT/infrastructure/tutor/multisite-shared-host-allowlist.txt"
SERVICE_TARGET="${SERVICE_TARGET:-lms}"
ALLOW_PROD_APPLY="${ALLOW_PROD_APPLY:-0}"
CREATE_PREOP_BACKUP="${CREATE_PREOP_BACKUP:-1}"
CONFIRM_APPLY_MULTISITE_CONFIG="${CONFIRM_APPLY_MULTISITE_CONFIG:-}"
CONFIRM_TOKEN="APPLY_MULTISITE_CONFIG"

log_info() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] INFO: $*"
}

log_error() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ERROR: $*" >&2
}

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Apply multisite configuration to LMS database via kubectl exec.

OPTIONS:
  -c, --context CONTEXT       Kubernetes context (default: $K8S_CONTEXT)
  -n, --namespace NAMESPACE   K8s namespace (default: mereka-lms)
  -e, --env ENV               Which definition set to apply (prod|dev|staging). Default: prod
  -s, --service TARGET        Which service to run against (lms|cms|both). Default: lms
  --definitions PATH          Path to multisite definitions YAML (overrides --env)
  --dry-run                   Preview operations without applying changes (default)
  --apply                     Apply changes to database
  -h, --help                  Show this help message

Safety controls for --apply:
  CONFIRM_APPLY_MULTISITE_CONFIG=APPLY_MULTISITE_CONFIG
  ALLOW_PROD_APPLY=1          Required for prod-like contexts
  CREATE_PREOP_BACKUP=1       Default for prod-like contexts (Velero pre-op backup)

EXAMPLES:
  # Preview changes (dry run - default)
  $0 --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster --env prod --dry-run

  # Apply changes to production/dev/staging
  $0 --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster --env prod --apply
  $0 --context kind-dev --env dev --apply
  $0 --context rke2-nonprod --namespace stg-mereka-lms --env staging --apply

  # Apply to different namespace
  $0 --namespace production --apply

REQUIREMENTS:
  - kubectl configured with access to target cluster
  - LMS or CMS pod running in the target namespace
  - Django runtime in the target pod (already included in Open edX)
EOF
  exit 1
}

require_bool_01() {
  local var_name="$1"
  local value="$2"
  case "$value" in
    0|1) ;;
    *)
      log_error "Invalid ${var_name}='${value}' (expected 0 or 1)"
      exit 1
      ;;
  esac
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || {
    log_error "Missing command: $cmd"
    exit 1
  }
}

is_prod_like_context() {
  local ctx="$1"
  [[ "$ctx" == *"gke_bbi-k8"* ]] || [[ "$ctx" == "prod" ]] || [[ "$ctx" == "production" ]] || [[ "$ctx" == "gke-prod" ]]
}

# Parse arguments
APPLY_FLAG=""
while [[ $# -gt 0 ]]; do
  case $1 in
    -c|--context)
      K8S_CONTEXT="$2"
      shift 2
      ;;
    -n|--namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    -e|--env)
      ENVIRONMENT="$2"
      shift 2
      ;;
    -s|--service)
      SERVICE_TARGET="$2"
      shift 2
      ;;
    --definitions)
      DEFINITIONS_PATH="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    --apply)
      APPLY_FLAG="--apply"
      DRY_RUN="false"
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

require_bool_01 "ALLOW_PROD_APPLY" "$ALLOW_PROD_APPLY"
require_bool_01 "CREATE_PREOP_BACKUP" "$CREATE_PREOP_BACKUP"
require_cmd kubectl

if [[ -z "$DEFINITIONS_PATH" ]]; then
  if [[ "$ENVIRONMENT" == "prod" ]]; then
    DEFINITIONS_PATH="$REPO_ROOT/infrastructure/tutor/multisite-sites.yml"
  elif [[ "$ENVIRONMENT" == "dev" ]]; then
    DEFINITIONS_PATH="$REPO_ROOT/infrastructure/tutor/multisite-sites.dev.yml"
  elif [[ "$ENVIRONMENT" == "staging" ]]; then
    DEFINITIONS_PATH="$REPO_ROOT/infrastructure/tutor/multisite-sites.staging.yml"
  else
    log_error "Unknown --env value: $ENVIRONMENT (expected prod|dev|staging)"
    exit 1
  fi
fi

if [[ ! -f "$DEFINITIONS_PATH" ]]; then
  log_error "Definitions YAML not found: $DEFINITIONS_PATH"
  exit 1
fi

if [[ "$SERVICE_TARGET" != "lms" && "$SERVICE_TARGET" != "cms" && "$SERVICE_TARGET" != "both" ]]; then
  log_error "Invalid --service value: $SERVICE_TARGET (expected lms|cms|both)"
  exit 1
fi

if [[ "$DRY_RUN" == "false" ]]; then
  if [[ "$CONFIRM_APPLY_MULTISITE_CONFIG" != "$CONFIRM_TOKEN" ]]; then
    log_error "Refusing --apply without explicit confirmation token. Set CONFIRM_APPLY_MULTISITE_CONFIG=${CONFIRM_TOKEN}"
    exit 1
  fi

  if is_prod_like_context "$K8S_CONTEXT" && [[ "$ALLOW_PROD_APPLY" != "1" ]]; then
    log_error "Refusing --apply on prod-like context '$K8S_CONTEXT' without ALLOW_PROD_APPLY=1"
    exit 1
  fi

  if is_prod_like_context "$K8S_CONTEXT"; then
    if [[ "$CREATE_PREOP_BACKUP" == "1" ]]; then
      require_cmd velero
      backup_name="pre-op-${NAMESPACE}-multisite-apply-$(date -u +%Y%m%d-%H%M)"
      log_info "Creating Velero pre-op backup: $backup_name"
      velero backup create "$backup_name" --include-namespaces "$NAMESPACE" --wait
    else
      log_info "WARNING: CREATE_PREOP_BACKUP=0 on prod-like context '$K8S_CONTEXT' (operator override)"
    fi
  fi
fi

SERVICES=(lms)
if [[ "$SERVICE_TARGET" == "cms" ]]; then
  SERVICES=(cms)
elif [[ "$SERVICE_TARGET" == "both" ]]; then
  SERVICES=(lms cms)
fi

for service in "${SERVICES[@]}"; do
  log_info "Finding ${service} pod in context=$K8S_CONTEXT namespace=$NAMESPACE"
  SERVICE_POD=$(
    kubectl --context "$K8S_CONTEXT" get pods -n "$NAMESPACE" \
      -l app.kubernetes.io/name="$service" \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo ""
  )

  if [[ -z "$SERVICE_POD" ]]; then
    log_error "No $service pod found in namespace $NAMESPACE"
    log_error "Check that the namespace exists and pods are running:"
    log_error "  kubectl --context $K8S_CONTEXT get pods -n $NAMESPACE"
    exit 1
  fi

  settings_module="lms.envs.tutor.production"
  scope_arg=""
  if [[ "$service" == "cms" ]]; then
    settings_module="cms.envs.tutor.production"
    # CMS needs django_site/SiteConfiguration parity, but organization + OIDC rows
    # are LMS-owned and should be reconciled from LMS settings.
    scope_arg="--scope sites"
  fi

  log_info "Using $service pod: $SERVICE_POD"
  log_info "Copying multisite_bootstrap_django.py to $service pod..."
  kubectl --context "$K8S_CONTEXT" cp "$REPO_ROOT/scripts/shared/multisite_bootstrap_django.py" \
    "$NAMESPACE/$SERVICE_POD:/tmp/multisite_bootstrap.py"

  log_info "Copying multisite definitions to $service pod: $DEFINITIONS_PATH"
  kubectl --context "$K8S_CONTEXT" cp "$DEFINITIONS_PATH" \
    "$NAMESPACE/$SERVICE_POD:/tmp/multisite-sites.yml"
  if [[ -f "$ALLOWLIST_PATH" ]]; then
    log_info "Copying multisite host allowlist to $service pod: $ALLOWLIST_PATH"
    kubectl --context "$K8S_CONTEXT" cp "$ALLOWLIST_PATH" \
      "$NAMESPACE/$SERVICE_POD:/tmp/multisite-shared-host-allowlist.txt"
  else
    log_info "No multisite host allowlist file found at $ALLOWLIST_PATH (continuing without it)"
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "Running in DRY RUN mode for $service (no changes will be made)"
    kubectl --context "$K8S_CONTEXT" exec -n "$NAMESPACE" "$SERVICE_POD" -- \
      env DJANGO_SETTINGS_MODULE="$settings_module" \
      MULTISITE_DEFINITIONS_PATH=/tmp/multisite-sites.yml \
      MULTISITE_SHARED_HOST_ALLOWLIST_FILE=/tmp/multisite-shared-host-allowlist.txt \
      python /tmp/multisite_bootstrap.py \
      --dry-run $scope_arg
  else
    log_info "Applying multisite configuration for $service (context=$K8S_CONTEXT namespace=$NAMESPACE)..."
    kubectl --context "$K8S_CONTEXT" exec -n "$NAMESPACE" "$SERVICE_POD" -- \
      env DJANGO_SETTINGS_MODULE="$settings_module" \
      MULTISITE_DEFINITIONS_PATH=/tmp/multisite-sites.yml \
      MULTISITE_SHARED_HOST_ALLOWLIST_FILE=/tmp/multisite-shared-host-allowlist.txt \
      python /tmp/multisite_bootstrap.py \
      $APPLY_FLAG $scope_arg
  fi

  log_info "Cleaning up temporary files for $service..."
  kubectl --context "$K8S_CONTEXT" exec -n "$NAMESPACE" "$SERVICE_POD" -- \
    rm -f /tmp/multisite_bootstrap.py /tmp/multisite-sites.yml /tmp/multisite-shared-host-allowlist.txt
done

log_info "Done!"

if [[ "$DRY_RUN" == "true" ]]; then
  log_info ""
  log_info "This was a dry run. To apply changes, run:"
  log_info "  $0 --context $K8S_CONTEXT --namespace $NAMESPACE --env $ENVIRONMENT --service $SERVICE_TARGET --apply"
else
  log_info ""
  log_info "Multisite configuration applied successfully!"
  log_info ""
  log_info "Verify the changes:"
  log_info "  1. Visit https://academyv2.mereka.io - should show Mereka Academy branding"
  log_info "  2. Visit https://academy.biji-biji.com - should show Mereka Academy branding"
  log_info "  3. Visit https://skillourfuture.academy.mereka.io - should show Skill Our Future branding"
  log_info ""
  log_info "If changes don't appear immediately, restart the LMS pods:"
  log_info "  kubectl rollout restart deployment/lms -n $NAMESPACE"
fi
