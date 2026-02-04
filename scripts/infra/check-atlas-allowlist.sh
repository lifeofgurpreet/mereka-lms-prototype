#!/usr/bin/env bash
# Validate Atlas IP allowlist matches current cluster egress IPs.
# Requires: atlas CLI auth + kubectl access to cluster.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../shared/config.sh"

ATLAS_PROJECT_NAME=${ATLAS_PROJECT_NAME:-mereka-lms}
ATLAS_PROJECT_ID=${ATLAS_PROJECT_ID:-}
EGRESS_IPS=${EGRESS_IPS:-}

log() { printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

if ! command -v atlas >/dev/null 2>&1; then
  echo "atlas CLI not found. Install and authenticate first." >&2
  exit 1
fi

if ! atlas auth whoami >/dev/null 2>&1; then
  echo "atlas CLI not authenticated. Run: atlas auth login" >&2
  exit 1
fi

if [[ -z "$ATLAS_PROJECT_ID" ]]; then
  log "Resolving Atlas project ID for ${ATLAS_PROJECT_NAME}..."
  ATLAS_PROJECT_ID=$(atlas projects list --output json | \
    jq -r --arg name "$ATLAS_PROJECT_NAME" '.results[]? | select(.name == $name) | .id' | head -1)
fi

if [[ -z "$ATLAS_PROJECT_ID" ]]; then
  echo "Unable to resolve Atlas project ID. Set ATLAS_PROJECT_ID manually." >&2
  exit 1
fi

if [[ -z "$EGRESS_IPS" ]]; then
  log "Fetching current egress IP from cluster..."
  EGRESS_IPS=$(kubectl run egress-check --rm -i --image=curlimages/curl --restart=Never -- \
    curl -s https://ifconfig.me | tr '\n' ',' | sed 's/,$//')
fi

if [[ -z "$EGRESS_IPS" ]]; then
  echo "Unable to determine egress IPs. Set EGRESS_IPS manually." >&2
  exit 1
fi

log "Checking Atlas access list..."
ALLOWLIST_RAW=$(atlas accessLists list --projectId "$ATLAS_PROJECT_ID" --output json)
ALLOWLIST=$(echo "$ALLOWLIST_RAW" | jq -r '.results[]? | (.ipAddress // .cidrBlock // empty)' | sort -u)

IFS=',' read -ra IPS <<< "$EGRESS_IPS"
missing=()
for ip in "${IPS[@]}"; do
  ip=$(echo "$ip" | xargs)
  [[ -z "$ip" ]] && continue
  if ! echo "$ALLOWLIST" | rg -q "^${ip}(/32)?$"; then
    missing+=("$ip")
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Missing Atlas allowlist entries: ${missing[*]}" >&2
  echo "Add them in Atlas: atlas accessLists create <ip> --projectId $ATLAS_PROJECT_ID" >&2
  exit 1
fi

log "Atlas allowlist matches cluster egress."
