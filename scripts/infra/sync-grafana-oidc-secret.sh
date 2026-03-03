#!/usr/bin/env bash
# Sync Grafana OIDC client secret from GCP Secret Manager to Kubernetes.
# Non-destructive: creates/updates monitoring/grafana-oidc-client-secret only.
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-bbi-k8}"
K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
NAMESPACE="${NAMESPACE:-monitoring}"
K8S_SECRET_NAME="${K8S_SECRET_NAME:-grafana-oidc-client-secret}"
K8S_SECRET_KEY="${K8S_SECRET_KEY:-GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET}"
# Default source key uses the dedicated OIDC secret in bbi-k8.
# Override when your monitoring stack is wired to a different secret source.
GCP_SECRET_NAME="${GCP_SECRET_NAME:-mereka-lms-oidc-client-secret}"

if ! command -v gcloud >/dev/null 2>&1; then
  echo "ERROR: gcloud is required" >&2
  exit 1
fi
if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: kubectl is required" >&2
  exit 1
fi

if ! gcloud secrets describe "$GCP_SECRET_NAME" --project "$PROJECT_ID" >/dev/null 2>&1; then
  echo "ERROR: GCP secret not found: ${GCP_SECRET_NAME} (project ${PROJECT_ID})" >&2
  exit 1
fi

secret_value="$(gcloud secrets versions access latest --secret "$GCP_SECRET_NAME" --project "$PROJECT_ID")"
if [[ -z "$secret_value" ]]; then
  echo "ERROR: Retrieved empty secret payload for ${GCP_SECRET_NAME}" >&2
  exit 1
fi

kubectl --context "$K8S_CONTEXT" -n "$NAMESPACE" create secret generic "$K8S_SECRET_NAME" \
  --from-literal="${K8S_SECRET_KEY}=${secret_value}" \
  --dry-run=client -o yaml | kubectl --context "$K8S_CONTEXT" apply -f -

# Restart deployment to pick up env secret changes if needed.
kubectl --context "$K8S_CONTEXT" -n "$NAMESPACE" rollout restart deployment/monitoring-grafana >/dev/null 2>&1 || true

echo "Synced Secret/${K8S_SECRET_NAME} in namespace ${NAMESPACE} from GCP secret ${GCP_SECRET_NAME}."
