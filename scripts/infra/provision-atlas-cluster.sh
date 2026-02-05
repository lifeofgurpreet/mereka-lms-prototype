#!/usr/bin/env bash
# Provision MongoDB Atlas cluster via CLI for Mereka Academy.
# This script automates cluster creation, user setup, and network access configuration.
# We intentionally use public IP allowlists (no private connectivity).
set -euo pipefail

CLUSTER_NAME=${CLUSTER_NAME:-cluster-mereka-lms}
PROJECT_NAME=${PROJECT_NAME:-mereka-lms}
PROVIDER=${PROVIDER:-AWS}
REGION=${REGION:-AP_SOUTHEAST_1}
TIER=${TIER:-M10}
DB_USERNAME=${DB_USERNAME:-cs_comments_user}
DATABASE=${DATABASE:-cs_comments_service}
OPENEDX_DATABASE=${OPENEDX_DATABASE:-openedx}
GKE_EGRESS_IPS=${GKE_EGRESS_IPS:-"35.247.164.211,34.142.147.42"}

log() { printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
error() { printf '\n[ERROR] %s\n' "$*" >&2; exit 1; }

# Check authentication
log "Checking Atlas authentication..."
if ! atlas auth whoami >/dev/null 2>&1; then
  log "Not authenticated. Please log in..."
  log "Opening browser for authentication..."
  atlas auth login
  if ! atlas auth whoami >/dev/null 2>&1; then
    error "Authentication failed. Please try again."
  fi
fi

log "Authenticated as: $(atlas auth whoami | head -1)"

# Get or create project
log "Checking for project: $PROJECT_NAME"
PROJECT_ID=$(atlas projects list --output json 2>/dev/null | \
  jq -r --arg name "$PROJECT_NAME" '.results[]? | select(.name == $name) | .id' | head -1)

if [[ -z "$PROJECT_ID" ]]; then
  log "Project not found. Creating project: $PROJECT_NAME"
  PROJECT_ID=$(atlas projects create "$PROJECT_NAME" --output json | jq -r '.id')
  log "Created project with ID: $PROJECT_ID"
else
  log "Using existing project ID: $PROJECT_ID"
fi

# Check if cluster already exists
log "Checking for existing cluster: $CLUSTER_NAME"
if atlas clusters describe "$CLUSTER_NAME" --projectId "$PROJECT_ID" >/dev/null 2>&1; then
  log "Cluster $CLUSTER_NAME already exists!"
  atlas clusters describe "$CLUSTER_NAME" --projectId "$PROJECT_ID" --output json | \
    jq -r '.connectionStrings.standardSrv // empty'
  log "To recreate, delete it first: atlas clusters delete $CLUSTER_NAME --projectId $PROJECT_ID"
  exit 0
fi

# Create cluster
log "Creating M10 cluster: $CLUSTER_NAME in $REGION..."
atlas clusters create "$CLUSTER_NAME" \
  --projectId "$PROJECT_ID" \
  --provider "$PROVIDER" \
  --region "$REGION" \
  --tier "$TIER" \
  --members 3 \
  --diskSizeGB 10 \
  --mdbVersion 7.0 \
  --output json > /tmp/atlas-cluster.json

CLUSTER_STATUS=$(jq -r '.stateName' /tmp/atlas-cluster.json)
log "Cluster creation initiated. Status: $CLUSTER_STATUS"

if [[ "$CLUSTER_STATUS" != "CREATING" && "$CLUSTER_STATUS" != "IDLE" ]]; then
  error "Cluster creation failed. Status: $CLUSTER_STATUS"
fi

log "Waiting for cluster to be ready (this may take 5-10 minutes)..."
atlas clusters watch "$CLUSTER_NAME" --projectId "$PROJECT_ID"

# Get connection string
log "Fetching connection string..."
CONNECTION_STRING=$(atlas clusters connectionStrings describe "$CLUSTER_NAME" \
  --projectId "$PROJECT_ID" \
  --output json | jq -r '.standardSrv')

if [[ -z "$CONNECTION_STRING" || "$CONNECTION_STRING" == "null" ]]; then
  error "Failed to retrieve connection string"
fi

log "Connection string: ${CONNECTION_STRING//\/\/.*@/\/\/***@}"

# Create database user
log "Creating database user: $DB_USERNAME"
if atlas dbusers describe "$DB_USERNAME" --projectId "$PROJECT_ID" >/dev/null 2>&1; then
  log "Database user $DB_USERNAME already exists. Skipping creation."
  log "Note: If you need to reset the password, delete and recreate the user."
else
  if [[ -z "${DB_PASSWORD:-}" ]]; then
    log "Please enter a password for the database user (min 8 chars, alphanumeric + special chars):"
    read -s DB_PASSWORD
    echo ""
  fi
  
  if [[ ${#DB_PASSWORD} -lt 8 ]]; then
    error "Password must be at least 8 characters"
  fi
  
  atlas dbusers create \
    --username "$DB_USERNAME" \
    --password "$DB_PASSWORD" \
    --projectId "$PROJECT_ID" \
    --role "readWrite@$DATABASE" \
    --role "readWrite@$OPENEDX_DATABASE" \
    --output json > /tmp/atlas-user.json
  
  log "Database user created successfully"
fi

# Configure network access
log "Configuring network access for GKE egress IPs (public allowlist)..."
IFS=',' read -ra IPS <<< "$GKE_EGRESS_IPS"
for ip in "${IPS[@]}"; do
  ip=$(echo "$ip" | xargs) # trim whitespace
  if [[ -n "$ip" ]]; then
    log "Adding IP to allowlist: $ip"
    atlas accesslists create "$ip" \
      --projectId "$PROJECT_ID" \
      --comment "GKE egress IP for mereka-lms" \
      --output json >/dev/null 2>&1 || \
      log "IP $ip may already be in allowlist (continuing...)"
  fi
done

# Build final connection URI
log "Building connection URI..."
if [[ -z "${DB_PASSWORD:-}" ]]; then
  log "Database user already exists. Please enter the password to build connection URI:"
  read -s DB_PASSWORD
  echo ""
fi

if [[ "$CONNECTION_STRING" =~ mongodb\+srv://(.+) ]]; then
  HOST_PART="${BASH_REMATCH[1]}"
  ATLAS_URI="mongodb+srv://${DB_USERNAME}:${DB_PASSWORD}@${HOST_PART}/${DATABASE}?retryWrites=true&w=majority"
else
  error "Unexpected connection string format"
fi

log ""
log "=========================================="
log "Atlas cluster provisioned successfully!"
log "=========================================="
log ""
log "Cluster Name: $CLUSTER_NAME"
log "Project ID: $PROJECT_ID"
log "Region: $REGION"
log "Tier: $TIER"
log ""
log "Connection URI (save this securely):"
log "$ATLAS_URI"
log ""
log "Next steps:"
log "1. Verify cluster is accessible:"
log "   mongosh '$ATLAS_URI'"
log ""
log "2. Run the migration:"
log "   ATLAS_URI='$ATLAS_URI' ./scripts/infra/mongodb-atlas-cutover.sh"
log ""
log "3. After verification, clean up the StatefulSet:"
log "   CLEANUP_STATEFULSET=true ATLAS_URI='$ATLAS_URI' ./scripts/infra/mongodb-atlas-cutover.sh"
log ""

# Save URI to a temporary file (user can move to Secret Manager)
echo "$ATLAS_URI" > /tmp/atlas-uri.txt
log "Connection URI saved to /tmp/atlas-uri.txt"
log "To store in Secret Manager:"
log "  printf '%s' '$ATLAS_URI' | gcloud secrets create mongodb-atlas-uri --data-file=-"

