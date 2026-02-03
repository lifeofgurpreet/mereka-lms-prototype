#!/usr/bin/env bash
# Downgrade MongoDB Atlas from M10 to M0 (FREE tier) to save costs.
# M10 costs ~$87/month, M0 is FREE (with limitations).
set -euo pipefail

PROJECT_ID=${PROJECT_ID:-690e7c787757f4238efc94d1}
CLUSTER_NAME=${CLUSTER_NAME:-cluster-mereka-lms}
TARGET_CLUSTER=${TARGET_CLUSTER:-cluster-mereka-lms}  # Existing M0 cluster

log() { printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
error() { printf '\n[ERROR] %s\n' "$*" >&2; exit 1; }

log "MongoDB Atlas Cost Optimization"
log "================================"
log ""
log "Current: M10 cluster ($CLUSTER_NAME) - ~\$87/month"
log "Target: M0 cluster ($TARGET_CLUSTER) - FREE"
log ""
log "M0 Limitations:"
log "  • 512MB storage (vs 10GB on M10)"
log "  • Shared CPU/RAM (vs dedicated)"
log "  • No backups (vs automatic backups)"
log "  • Cost-optimized for dev only; do NOT use for production"
log ""
read -p "Continue with migration to M0? (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
  log "Cancelled."
  exit 0
fi

# Check if target M0 cluster exists
log "Checking for M0 cluster: $TARGET_CLUSTER"
if ! atlas clusters describe "$TARGET_CLUSTER" --projectId "$PROJECT_ID" >/dev/null 2>&1; then
  error "M0 cluster $TARGET_CLUSTER not found. Create it first or use a different cluster name."
fi

# Get connection strings
log "Getting connection strings..."
M10_URI=$(atlas clusters connectionStrings describe "$CLUSTER_NAME" --projectId "$PROJECT_ID" --output json | jq -r '.standardSrv')
M0_URI=$(atlas clusters connectionStrings describe "$TARGET_CLUSTER" --projectId "$PROJECT_ID" --output json | jq -r '.standardSrv')

if [[ -z "$M10_URI" || -z "$M0_URI" ]]; then
  error "Failed to get connection strings"
fi

log "M10 URI: ${M10_URI//\/\/.*@/\/\/***@}"
log "M0 URI: ${M0_URI//\/\/.*@/\/\/***@}"

# Check if database user exists on M0
log "Checking database user on M0 cluster..."
DB_USERNAME=${DB_USERNAME:-cs_comments_user}
if ! atlas dbusers describe "$DB_USERNAME" --projectId "$PROJECT_ID" >/dev/null 2>&1; then
  log "Database user $DB_USERNAME not found on M0 cluster."
  log "Please enter password to create user:"
  read -s DB_PASSWORD
  echo ""
  
  atlas dbusers create \
    --username "$DB_USERNAME" \
    --password "$DB_PASSWORD" \
    --projectId "$PROJECT_ID" \
    --role "readWrite@cs_comments_service" \
    --output json > /tmp/m0-user.json
  
  log "Database user created on M0 cluster."
else
  log "Database user already exists on M0 cluster."
  log "Please enter password to build connection URI:"
  read -s DB_PASSWORD
  echo ""
fi

# Build M0 connection URI
if [[ "$M0_URI" =~ mongodb\+srv://(.+) ]]; then
  HOST_PART="${BASH_REMATCH[1]}"
  M0_FULL_URI="mongodb+srv://${DB_USERNAME}:${DB_PASSWORD}@${HOST_PART}/cs_comments_service?retryWrites=true&w=majority"
else
  error "Unexpected M0 connection string format"
fi

# Migrate data from M10 to M0
log "Migrating data from M10 to M0..."
log "This will dump from M10 and restore to M0..."

# Use mongosh to dump and restore
kubectl run mongodb-migration-m0 --rm -i --image=mongo:5.0 --restart=Never -n mereka-lms -- \
  sh -c "
    echo 'Dumping from M10...'
    mongodump --uri '$M10_URI' --archive --gzip > /tmp/dump.gz
    echo 'Restoring to M0...'
    mongorestore --uri '$M0_FULL_URI' --archive --gzip --drop /tmp/dump.gz
    echo 'Migration complete!'
  "

# Update forum deployment
log "Updating forum deployment to use M0..."
kubectl set env deployment/forum -n mereka-lms \
  MONGODB_URI="$M0_FULL_URI" \
  MONGODB_HOST="" \
  MONGODB_PORT="" \
  MONGODB_AUTH=""

# Update Secret Manager
log "Updating Secret Manager..."
GCP_PROJECT=${GCP_PROJECT:-mereka-lms}
printf '%s' "$M0_FULL_URI" | gcloud secrets versions add mongodb-atlas-uri --project "$GCP_PROJECT" --data-file=-

# Update Tutor config
log "Updating Tutor config..."
source infrastructure/tutor/tutor-env.sh
tutor config save --set RUN_MONGODB=false --set MONGODB_URI="$M0_FULL_URI"

# Restart forum
log "Restarting forum deployment..."
kubectl rollout restart deployment/forum -n mereka-lms
kubectl rollout status deployment/forum -n mereka-lms --timeout=300s

log ""
log "=========================================="
log "Migration to M0 complete!"
log "=========================================="
log ""
log "Next steps:"
log "1. Verify forum is working: kubectl logs -n mereka-lms -l app.kubernetes.io/name=forum"
log "2. Delete M10 cluster to stop charges:"
log "   atlas clusters delete $CLUSTER_NAME --projectId $PROJECT_ID"
log ""
log "M0 connection URI saved to Secret Manager and Tutor config."


