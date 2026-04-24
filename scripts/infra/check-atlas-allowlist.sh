#!/usr/bin/env bash
# @covers AC-007
# @spec: mongodb-atlas-integration_spec.md
# Validate Atlas IP allowlist matches current cluster egress IPs.
# Requires: atlas CLI auth + kubectl access to cluster.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../shared/config.sh"

ATLAS_PROJECT_NAME=${ATLAS_PROJECT_NAME:-mereka-lms}
ATLAS_PROJECT_ID=${ATLAS_PROJECT_ID:-}
EGRESS_IPS=${EGRESS_IPS:-}
ATLAS_PROFILE=${ATLAS_PROFILE:-mereka-lms}
REFRESH_ATLAS_PROFILE=${REFRESH_ATLAS_PROFILE:-0}
APP_NS=${APP_NS:-${K8S_NAMESPACE:-mereka-lms}}

log() { printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

atlas_cmd() {
  if [[ -n "$ATLAS_PROFILE" ]]; then
    atlas "$@" -P "$ATLAS_PROFILE"
  else
    atlas "$@"
  fi
}

if ! command -v atlas >/dev/null 2>&1; then
  echo "atlas CLI not found. Install and authenticate first." >&2
  exit 1
fi

if [[ "$REFRESH_ATLAS_PROFILE" == "1" ]]; then
  "${SCRIPT_DIR}/atlas-config-from-infisical.sh"
  if [[ -z "$ATLAS_PROFILE" ]]; then
    ATLAS_PROFILE="mereka-lms"
  fi
fi

if ! atlas_cmd auth whoami >/dev/null 2>&1; then
  echo "atlas CLI not authenticated for profile '${ATLAS_PROFILE:-default}'. Configure API-key profile or run: atlas auth login" >&2
  exit 1
fi

if [[ -z "$ATLAS_PROJECT_ID" ]]; then
  # Prefer explicit project_id configured in the selected Atlas profile.
  if [[ -n "$ATLAS_PROFILE" ]]; then
    ATLAS_PROJECT_ID="$(
      atlas config describe "$ATLAS_PROFILE" -o json 2>/dev/null | \
        jq -r '.project_id // empty' | head -1
    )"
  fi
fi

if [[ -z "$ATLAS_PROJECT_ID" ]]; then
  log "Resolving Atlas project ID for ${ATLAS_PROJECT_NAME}..."
  ATLAS_PROJECT_ID=$(atlas_cmd projects list --output json | \
    jq -r --arg name "$ATLAS_PROJECT_NAME" '.results[]? | select(.name == $name) | .id' | head -1)
fi

if [[ -z "$ATLAS_PROJECT_ID" ]]; then
  echo "Unable to resolve Atlas project ID. Set ATLAS_PROJECT_ID manually." >&2
  exit 1
fi

if [[ -z "$EGRESS_IPS" ]]; then
  log "Fetching current egress IP from cluster (using deploy/lms)..."
  EGRESS_IPS="$(kubectl --context "${K8S_CONTEXT}" -n "$APP_NS" exec deploy/lms -- sh -c 'curl -s https://ifconfig.me' 2>/dev/null || true)"
fi

if [[ -z "$EGRESS_IPS" ]]; then
  log "Fallback: fetching current egress IP via transient pod..."
  EGRESS_IPS="$(kubectl --context "${K8S_CONTEXT}" run egress-check --rm --restart=Never --image=curlimages/curl --command -- sh -c 'curl -s https://ifconfig.me' 2>/dev/null || true)"
fi

if [[ -z "$EGRESS_IPS" ]]; then
  echo "Unable to determine egress IPs. Set EGRESS_IPS manually." >&2
  exit 1
fi

# Keep only comma-separated IPv4 tokens to avoid kubectl status noise.
EGRESS_IPS="$(echo "$EGRESS_IPS" | tr '\n' ',' | tr -cd '0-9.,' | sed 's/,,*/,/g; s/^,//; s/,$//')"

log "Checking Atlas access list..."
ALLOWLIST_RAW=$(atlas_cmd accessLists list --projectId "$ATLAS_PROJECT_ID" --output json)
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
