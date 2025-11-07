#!/usr/bin/env bash
# Stream the in-cluster MongoDB data into Atlas.
set -euo pipefail

ATLAS_URI=${ATLAS_URI:?"Set ATLAS_URI to your Atlas connection string"}
NAMESPACE=${NAMESPACE:-mereka-lms}
POD=${POD:-mongodb-0}
DATABASE=${DATABASE:-cs_comments_service}
MONGO_IMAGE=${MONGO_IMAGE:-mongo:5.0}

kubectl get pod "$POD" -n "$NAMESPACE" >/dev/null

echo "Dumping $DATABASE from $POD/$NAMESPACE and restoring to Atlas..."
kubectl exec -n "$NAMESPACE" "$POD" -- mongodump --db "$DATABASE" --archive --gzip \
  | docker run --rm -i "$MONGO_IMAGE" mongorestore --uri "$ATLAS_URI" --archive --gzip --drop

echo "MongoDB data restored to Atlas."
