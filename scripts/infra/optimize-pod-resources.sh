#!/usr/bin/env bash
# Optimize pod resource requests to reduce GKE node count and costs
# This reduces memory requests from 2Gi to 512Mi for most services
set -euo pipefail

NAMESPACE=${NAMESPACE:-mereka-lms}
MEMORY_REQUEST=${MEMORY_REQUEST:-512Mi}

log() { printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

log "Optimizing pod resource requests for dev environment"
log "Namespace: $NAMESPACE"
log "Target memory request: $MEMORY_REQUEST"
log ""

# List of deployments to optimize (exclude small services)
DEPLOYMENTS=(
  "cms"
  "cms-worker"
  "lms"
  "lms-worker"
  "mfe"
)

for deployment in "${DEPLOYMENTS[@]}"; do
  log "Patching deployment: $deployment"

  # Check if deployment exists
  if ! kubectl get deployment "$deployment" -n "$NAMESPACE" &>/dev/null; then
    log "  ⚠ Deployment $deployment not found, skipping"
    continue
  fi

  # Patch the deployment to reduce memory request
  kubectl patch deployment "$deployment" -n "$NAMESPACE" --type='json' -p="[
    {
      \"op\": \"add\",
      \"path\": \"/spec/template/spec/containers/0/resources\",
      \"value\": {
        \"requests\": {
          \"memory\": \"$MEMORY_REQUEST\"
        }
      }
    }
  ]" && log "  ✓ Patched $deployment" || log "  ⚠ Failed to patch $deployment"
done

log ""
log "Resource optimization complete!"
log ""
log "Checking pod status..."
kubectl get pods -n "$NAMESPACE" -o wide

log ""
log "Expected impact:"
log "  • Reduced memory requests from 2Gi to $MEMORY_REQUEST per pod"
log "  • GKE Autopilot will scale down nodes based on new requests"
log "  • Estimated savings: \$150-250/month (6 nodes → 2-3 nodes)"
log ""
log "Monitor node count with: kubectl get nodes"
log "Monitor pod status with: kubectl get pods -n $NAMESPACE"
