#!/usr/bin/env bash
# Apply multisite configuration to production/dev LMS database.
# This script runs the multisite_bootstrap.py script from within an LMS pod
# to configure Django site entries and SiteConfiguration for all domains.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
NAMESPACE="${NAMESPACE:-mereka-lms}"
DRY_RUN="${DRY_RUN:-true}"
ENVIRONMENT="${ENVIRONMENT:-prod}"
DEFINITIONS_PATH=""

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
  -e, --env ENV               Which definition set to apply (prod|dev). Default: prod
  --definitions PATH          Path to multisite definitions YAML (overrides --env)
  --dry-run                   Preview operations without applying changes (default)
  --apply                     Apply changes to database
  -h, --help                  Show this help message

EXAMPLES:
  # Preview changes (dry run - default)
  $0 --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster --env prod --dry-run

  # Apply changes to production/dev
  $0 --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster --env prod --apply
  $0 --context kind-dev --env dev --apply

  # Apply to different namespace
  $0 --namespace production --apply

REQUIREMENTS:
  - kubectl configured with access to target cluster
  - PyMySQL installed in LMS pod (already included in Open edX)
  - Database credentials in lms.env.yml
EOF
  exit 1
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

if [[ -z "$DEFINITIONS_PATH" ]]; then
  if [[ "$ENVIRONMENT" == "prod" ]]; then
    DEFINITIONS_PATH="$REPO_ROOT/infrastructure/tutor/multisite-sites.yml"
  elif [[ "$ENVIRONMENT" == "dev" ]]; then
    DEFINITIONS_PATH="$REPO_ROOT/infrastructure/tutor/multisite-sites.dev.yml"
  else
    log_error "Unknown --env value: $ENVIRONMENT (expected prod|dev)"
    exit 1
  fi
fi

if [[ ! -f "$DEFINITIONS_PATH" ]]; then
  log_error "Definitions YAML not found: $DEFINITIONS_PATH"
  exit 1
fi

# Find LMS pod
log_info "Finding LMS pod in context=$K8S_CONTEXT namespace=$NAMESPACE"
LMS_POD=$(
  kubectl --context "$K8S_CONTEXT" get pods -n "$NAMESPACE" \
    -l app.kubernetes.io/name=lms \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo ""
)

if [[ -z "$LMS_POD" ]]; then
  log_error "No LMS pod found in namespace $NAMESPACE"
  log_error "Check that the namespace exists and pods are running:"
  log_error "  kubectl --context $K8S_CONTEXT get pods -n $NAMESPACE"
  exit 1
fi

log_info "Using LMS pod: $LMS_POD"

# Copy the multisite bootstrap script to the pod
log_info "Copying multisite_bootstrap_django.py to LMS pod..."
kubectl --context "$K8S_CONTEXT" cp "$REPO_ROOT/scripts/shared/multisite_bootstrap_django.py" \
  "$NAMESPACE/$LMS_POD:/tmp/multisite_bootstrap.py"

# Copy the multisite definition YAML (single source of truth)
log_info "Copying multisite definitions to LMS pod: $DEFINITIONS_PATH"
kubectl --context "$K8S_CONTEXT" cp "$DEFINITIONS_PATH" \
  "$NAMESPACE/$LMS_POD:/tmp/multisite-sites.yml"

# Run the script
if [[ "$DRY_RUN" == "true" ]]; then
  log_info "Running in DRY RUN mode (no changes will be made)"
  kubectl --context "$K8S_CONTEXT" exec -n "$NAMESPACE" "$LMS_POD" -- \
    env MULTISITE_DEFINITIONS_PATH=/tmp/multisite-sites.yml \
    python /tmp/multisite_bootstrap.py \
    --dry-run
else
  log_info "Applying multisite configuration to database (context=$K8S_CONTEXT namespace=$NAMESPACE)..."
  kubectl --context "$K8S_CONTEXT" exec -n "$NAMESPACE" "$LMS_POD" -- \
    env MULTISITE_DEFINITIONS_PATH=/tmp/multisite-sites.yml \
    python /tmp/multisite_bootstrap.py \
    $APPLY_FLAG
fi

# Cleanup
log_info "Cleaning up temporary files..."
kubectl --context "$K8S_CONTEXT" exec -n "$NAMESPACE" "$LMS_POD" -- rm -f /tmp/multisite_bootstrap.py /tmp/multisite-sites.yml

log_info "Done!"

if [[ "$DRY_RUN" == "true" ]]; then
  log_info ""
  log_info "This was a dry run. To apply changes, run:"
  log_info "  $0 --context $K8S_CONTEXT --namespace $NAMESPACE --env $ENVIRONMENT --apply"
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
