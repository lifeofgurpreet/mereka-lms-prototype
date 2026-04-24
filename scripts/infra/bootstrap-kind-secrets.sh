#!/usr/bin/env bash
# @covers AC-003
# @spec: k8s-deployment_spec.md
# Bootstrap ExternalSecrets access for the kind dev cluster.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

KUBE_CONTEXT="${KUBE_CONTEXT:-kind-dev}"
SECRET_NAMESPACE="${SECRET_NAMESPACE:-external-secrets}"
SECRET_NAME="${SECRET_NAME:-gcp-secret-manager}"
PROJECT_ID="${PROJECT_ID:-bbi-k8}"
SA_EMAIL="${SA_EMAIL:-external-secrets-gcp@bbi-k8.iam.gserviceaccount.com}"
KEY_FILE="${GCP_SA_KEY_FILE:-}"

log() { printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud CLI is required for generating service account keys." >&2
  exit 1
fi

if kubectl --context "$KUBE_CONTEXT" get secret "$SECRET_NAME" -n "$SECRET_NAMESPACE" >/dev/null 2>&1; then
  log "Secret ${SECRET_NAME} already exists in ${SECRET_NAMESPACE}. Skipping key creation."
else
  if [[ -z "$KEY_FILE" ]]; then
    log "Creating new service account key for ${SA_EMAIL}..."
    KEY_FILE="$(mktemp)"
    trap 'rm -f "$KEY_FILE"' EXIT
    gcloud iam service-accounts keys create "$KEY_FILE" \
      --iam-account "$SA_EMAIL" \
      --project "$PROJECT_ID"
  fi

  log "Creating ${SECRET_NAME} in ${SECRET_NAMESPACE}..."
  kubectl --context "$KUBE_CONTEXT" create secret generic "$SECRET_NAME" \
    -n "$SECRET_NAMESPACE" \
    --from-file=key.json="$KEY_FILE" \
    --dry-run=client -o yaml | kubectl --context "$KUBE_CONTEXT" apply -f -
fi

log "Applying ClusterSecretStore configuration..."
kubectl --context "$KUBE_CONTEXT" apply -f "$REPO_ROOT/deploy/k8s/overlays/local/patches/clustersecretstore-gcp.yaml"

log "Forcing ExternalSecret sync..."
kubectl --context "$KUBE_CONTEXT" annotate externalsecret openedx-secrets -n mereka-lms force-sync="$(date +%s)" --overwrite
kubectl --context "$KUBE_CONTEXT" annotate externalsecret database-secrets -n mereka-lms force-sync="$(date +%s)" --overwrite

log "Bootstrap complete."
