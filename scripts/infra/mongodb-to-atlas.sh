#!/usr/bin/env bash
# Stream the in-cluster MongoDB data into Atlas.
set -euo pipefail

ATLAS_URI=${ATLAS_URI:?"Set ATLAS_URI to your Atlas connection string"}
NAMESPACE=${NAMESPACE:-mereka-lms}
POD=${POD:-mongodb-0}
DATABASE=${DATABASE:-cs_comments_service}
MONGO_IMAGE=${MONGO_IMAGE:-mongo:5.0}
TEMP_POD=${TEMP_POD:-mongodb-migration-$(date +%s)}

kubectl get pod "$POD" -n "$NAMESPACE" >/dev/null

echo "Dumping $DATABASE from $POD/$NAMESPACE and restoring to Atlas..."

# Dump from source MongoDB pod
echo "Step 1: Dumping data from source MongoDB..."
DUMP_FILE="/tmp/mongodb-dump-$(date +%s).gz"
kubectl exec -n "$NAMESPACE" "$POD" -- mongodump --db "$DATABASE" --archive --gzip > "$DUMP_FILE"

# Restore to Atlas from a pod in the cluster (so GKE IPs are allowed)
echo "Step 2: Restoring to Atlas from cluster pod..."
kubectl run "$TEMP_POD" -n "$NAMESPACE" \
  --image="$MONGO_IMAGE" \
  --rm -i --restart=Never \
  -- sh -c "cat - | mongorestore --uri '$ATLAS_URI' --archive --gzip --drop" < "$DUMP_FILE"

# Cleanup
rm -f "$DUMP_FILE"

echo "MongoDB data restored to Atlas."
