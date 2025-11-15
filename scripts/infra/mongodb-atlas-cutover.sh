#!/usr/bin/env bash
# Dump the in-cluster MongoDB to Atlas, update Tutor config, and optionally clean up the StatefulSet.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ATLAS_URI=${ATLAS_URI:?"Set ATLAS_URI to your Atlas connection string"}
NAMESPACE=${NAMESPACE:-mereka-lms}
STATEFULSET=${STATEFULSET:-mongodb}
PVC_NAME=${PVC_NAME:-data-mongodb-0}
PROJECT_ID=${GCP_PROJECT:-mereka-lms}
RUN_MIGRATION=${RUN_MIGRATION:-true}
UPDATE_SECRET=${UPDATE_SECRET:-true}
CLEANUP_STATEFULSET=${CLEANUP_STATEFULSET:-false}
TUTOR_CMD=${TUTOR_CMD:-tutor}

log() { printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

if [[ "$RUN_MIGRATION" == "true" ]]; then
  log "Streaming cs_comments_service data into Atlas..."
  ATLAS_URI="$ATLAS_URI" "$REPO_ROOT/scripts/infra/mongodb-to-atlas.sh"
else
  log "Skipping data transfer (RUN_MIGRATION=false)."
fi

if [[ "$UPDATE_SECRET" == "true" ]]; then
  log "Persisting Atlas URI to Secret Manager (project: $PROJECT_ID)..."
  if gcloud secrets describe mongodb-atlas-uri --project "$PROJECT_ID" >/dev/null 2>&1; then
    printf '%s' "$ATLAS_URI" | gcloud secrets versions add mongodb-atlas-uri --project "$PROJECT_ID" --data-file=- >/dev/null
  else
    printf '%s' "$ATLAS_URI" | gcloud secrets create mongodb-atlas-uri --project "$PROJECT_ID" --data-file=- >/dev/null
  fi
else
  log "Skipping Secret Manager update (UPDATE_SECRET=false)."
fi

log "Updating Tutor configuration to use Atlas..."
pushd "$REPO_ROOT" >/dev/null
source infrastructure/tutor/tutor-env.sh
$TUTOR_CMD config save --set RUN_MONGODB=false \
  --set MONGODB_URI="$ATLAS_URI" \
  --set MONGODB_HOST="" --set MONGODB_PORT="" --set MONGODB_AUTH=""
$TUTOR_CMD k8s start
popd >/dev/null

log "Waiting for forum deployment to pick up the new settings..."
kubectl rollout status deployment/forum -n "$NAMESPACE" --timeout=300s

if [[ "$CLEANUP_STATEFULSET" == "true" ]]; then
  log "Deleting legacy MongoDB StatefulSet + PVC..."
  kubectl delete statefulset "$STATEFULSET" -n "$NAMESPACE" --ignore-not-found
  kubectl delete pvc "$PVC_NAME" -n "$NAMESPACE" --ignore-not-found
else
  log "Leaving StatefulSet in place (CLEANUP_STATEFULSET=false). Delete it manually once Atlas is verified."
fi

log "MongoDB Atlas cutover complete."
