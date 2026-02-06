#!/usr/bin/env bash
# Apply the dev(kind) overlay end-to-end (load image, apply manifests, verify health).
#
# Usage:
#   ./scripts/infra/apply-kind-overlay.sh
#
# Optional:
#   KUBE_CONTEXT=kind-dev
#   CLUSTER=dev
#   NAMESPACE=mereka-lms
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

KUBE_CONTEXT="${KUBE_CONTEXT:-kind-dev}"
CLUSTER="${CLUSTER:-dev}"
NAMESPACE="${NAMESPACE:-mereka-lms}"

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

log "Loading Open edX image into kind nodes (cluster=${CLUSTER})..."
CLUSTER="${CLUSTER}" "$REPO_ROOT/scripts/infra/kind-load-openedx-image.sh"

log "Applying kustomize overlay to ${KUBE_CONTEXT} (${NAMESPACE})..."
kubectl --context "${KUBE_CONTEXT}" apply -k "$REPO_ROOT/deploy/k8s/overlays/local"

log "Waiting for rollouts..."
kubectl --context "${KUBE_CONTEXT}" -n "${NAMESPACE}" rollout status deployment/lms --timeout=300s
kubectl --context "${KUBE_CONTEXT}" -n "${NAMESPACE}" rollout status deployment/cms --timeout=300s
kubectl --context "${KUBE_CONTEXT}" -n "${NAMESPACE}" rollout status deployment/lms-worker --timeout=300s
kubectl --context "${KUBE_CONTEXT}" -n "${NAMESPACE}" rollout status deployment/cms-worker --timeout=300s

log "Running public health checks (dev)..."
"$REPO_ROOT/scripts/qa/public-health-check.sh" dev

log "Running branding checks (dev)..."
"$REPO_ROOT/scripts/qa/verify-public-branding.sh" dev

log "OK"

