#!/usr/bin/env bash
# Apply multisite configuration to production/dev LMS database.
# This script runs the multisite_bootstrap.py script from within an LMS pod
# to configure Django site entries and SiteConfiguration for all domains.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

NAMESPACE="${NAMESPACE:-mereka-lms}"
DRY_RUN="${DRY_RUN:-false}"

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Apply multisite configuration to LMS database via kubectl exec.

OPTIONS:
  -n, --namespace NAMESPACE   K8s namespace (default: mereka-lms)
  --dry-run                   Preview operations without applying changes
  --apply                     Apply changes to database (required to make changes)
  -h, --help                  Show this help message

EXAMPLES:
  # Preview changes (dry run - default)
  $0 --dry-run

  # Apply changes to production/dev
  $0 --apply

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
    -n|--namespace)
      NAMESPACE="$2"
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

log_info() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] INFO: $*"
}

log_error() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ERROR: $*" >&2
}

# Find LMS pod
log_info "Finding LMS pod in namespace: $NAMESPACE"
LMS_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -z "$LMS_POD" ]]; then
  log_error "No LMS pod found in namespace $NAMESPACE"
  log_error "Check that the namespace exists and pods are running:"
  log_error "  kubectl get pods -n $NAMESPACE"
  exit 1
fi

log_info "Using LMS pod: $LMS_POD"

# Copy the multisite bootstrap script to the pod
log_info "Copying multisite_bootstrap_django.py to LMS pod..."
kubectl cp "$REPO_ROOT/scripts/shared/multisite_bootstrap_django.py" \
  "$NAMESPACE/$LMS_POD:/tmp/multisite_bootstrap.py"

# Run the script
if [[ "$DRY_RUN" == "true" ]]; then
  log_info "Running in DRY RUN mode (no changes will be made)"
  kubectl exec -n "$NAMESPACE" "$LMS_POD" -- \
    python /tmp/multisite_bootstrap.py \
    --dry-run
else
  log_info "Applying multisite configuration to database..."
  kubectl exec -n "$NAMESPACE" "$LMS_POD" -- \
    python /tmp/multisite_bootstrap.py \
    $APPLY_FLAG
fi

# Cleanup
log_info "Cleaning up temporary files..."
kubectl exec -n "$NAMESPACE" "$LMS_POD" -- rm -f /tmp/multisite_bootstrap.py

log_info "Done!"

if [[ "$DRY_RUN" == "true" ]]; then
  log_info ""
  log_info "This was a dry run. To apply changes, run:"
  log_info "  $0 --apply"
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
