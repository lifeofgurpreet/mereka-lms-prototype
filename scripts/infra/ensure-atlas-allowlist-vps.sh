#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

LOG_DIR="${LOG_DIR:-${REPO_ROOT}/var}"
ATLAS_PROJECT_NAME="${ATLAS_PROJECT_NAME:-mereka-lms}"
ATLAS_PROJECT_ID="${ATLAS_PROJECT_ID:-690e7c787757f4238efc94d1}"
ATLAS_PROFILE="${ATLAS_PROFILE:-}"

mkdir -p "$LOG_DIR"

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

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

if ! atlas_cmd auth whoami >/dev/null 2>&1; then
  echo "atlas CLI not authenticated. Run: atlas auth login" >&2
  exit 1
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

VPS_IP=$(curl -s -4 https://ifconfig.me || true)
if [[ -z "$VPS_IP" ]]; then
  VPS_IP=$(curl -s https://api.ipify.org || true)
fi
if [[ -z "$VPS_IP" ]]; then
  echo "Unable to determine VPS egress IP." >&2
  exit 1
fi

log "Ensuring Atlas allowlist contains VPS IP: ${VPS_IP}"
ALLOWLIST_RAW=$(atlas_cmd accessLists list --projectId "$ATLAS_PROJECT_ID" --output json)
ALLOWLIST=$(echo "$ALLOWLIST_RAW" | jq -r '.results[]? | (.ipAddress // .cidrBlock // empty)' | sort -u)

if echo "$ALLOWLIST" | rg -q "^${VPS_IP}(/32)?$"; then
  log "Atlas allowlist already contains ${VPS_IP}."
  exit 0
fi

log "Adding ${VPS_IP} to Atlas allowlist..."
atlas_cmd accessLists create "$VPS_IP" --projectId "$ATLAS_PROJECT_ID" >/dev/null
log "Added ${VPS_IP} to Atlas allowlist."
