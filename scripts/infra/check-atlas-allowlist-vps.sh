#!/usr/bin/env bash
# @covers AC-007
# @spec: mongodb-atlas-integration_spec.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

LOG_DIR="${LOG_DIR:-${REPO_ROOT}/var}"
ATLAS_PROJECT_ID="${ATLAS_PROJECT_ID:-690e7c787757f4238efc94d1}"
ATLAS_PROFILE="${ATLAS_PROFILE:-mereka-lms}"
REFRESH_ATLAS_PROFILE="${REFRESH_ATLAS_PROFILE:-1}"

mkdir -p "$LOG_DIR"

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

VPS_IP=$(curl -s -4 https://ifconfig.me || true)
if [[ -z "$VPS_IP" ]]; then
  VPS_IP=$(curl -s https://api.ipify.org || true)
fi
if [[ -z "$VPS_IP" ]]; then
  echo "Unable to determine VPS egress IP." >&2
  exit 1
fi

log "Checking Atlas allowlist for VPS IP: ${VPS_IP}"
EGRESS_IPS="$VPS_IP" \
ATLAS_PROJECT_ID="$ATLAS_PROJECT_ID" \
ATLAS_PROFILE="$ATLAS_PROFILE" \
REFRESH_ATLAS_PROFILE="$REFRESH_ATLAS_PROFILE" \
  "${SCRIPT_DIR}/check-atlas-allowlist.sh"
