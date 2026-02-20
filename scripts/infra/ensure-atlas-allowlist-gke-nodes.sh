#!/usr/bin/env bash
# ensure-atlas-allowlist-gke-nodes.sh
#
# Ensures all GKE node external IPs are in the MongoDB Atlas allowlist.
# Run after any GKE node rotation, scale-out, or cluster upgrade.
#
# Root cause addressed: When GKE adds/replaces nodes, new external IPs
# are not automatically added to Atlas. Atlas responds to non-allowlisted
# IPs with TLSV1_ALERT_INTERNAL_ERROR (not a clear 'connection refused'),
# causing forum heartbeat 503 and courseware failures.
#
# Usage:
#   ./scripts/infra/ensure-atlas-allowlist-gke-nodes.sh [--dry-run]
#
# Dependencies:
#   - atlas CLI authenticated with mereka-lms profile
#   - kubectl access to GKE cluster (gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster)
#
# Cron (add to crontab for automated drift prevention):
#   0 * * * * cd /home/gurpreet/projects/k8s/mereka-lms && \
#     ./scripts/infra/ensure-atlas-allowlist-gke-nodes.sh >> \
#     var/atlas-gke-allowlist.log 2>&1
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ATLAS_PROJECT_ID="${ATLAS_PROJECT_ID:-690e7c787757f4238efc94d1}"
ATLAS_PROFILE="${ATLAS_PROFILE:-mereka-lms}"
GKE_CONTEXT="${GKE_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
DRY_RUN="${DRY_RUN:-0}"

[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

atlas_cmd() { atlas "$@" -P "$ATLAS_PROFILE" 2>/dev/null; }

if ! atlas_cmd auth whoami >/dev/null 2>&1; then
  log "Atlas CLI not authenticated for profile '${ATLAS_PROFILE}'. Run: atlas auth login" >&2
  exit 1
fi

if ! kubectl --context "$GKE_CONTEXT" get nodes >/dev/null 2>&1; then
  log "Cannot reach GKE context '${GKE_CONTEXT}'" >&2
  exit 1
fi

# Get all GKE node external IPs
log "Fetching GKE node external IPs from context: ${GKE_CONTEXT}"
node_ips=$(kubectl --context "$GKE_CONTEXT" get nodes \
  -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null)

if [[ -z "$node_ips" ]]; then
  log "ERROR: No external IPs found for GKE nodes" >&2
  exit 1
fi

log "GKE node IPs: $node_ips"

# Get current Atlas allowlist as space-separated list
allowed_ips=$(atlas_cmd accessLists list --projectId "$ATLAS_PROJECT_ID" \
  --output json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
for entry in data.get('results', []):
    ip = entry.get('ipAddress', entry.get('cidrBlock', ''))
    print(ip.split('/')[0])  # strip /32 CIDR
" 2>/dev/null)

added=0
already_present=0

for ip in $node_ips; do
  if echo "$allowed_ips" | grep -qF "$ip"; then
    log "  SKIP (already allowed): $ip"
    already_present=$((already_present + 1))
  else
    if [[ "$DRY_RUN" == "1" ]]; then
      log "  DRY-RUN would add: $ip"
    else
      log "  ADDING: $ip"
      atlas_cmd accessLists create "$ip" \
        --projectId "$ATLAS_PROJECT_ID" \
        --type ipAddress \
        --comment "GKE node (auto-added $(date +%Y-%m-%d))" >/dev/null
      log "  ADDED: $ip"
      added=$((added + 1))
    fi
  fi
done

log "Done. added=${added} already_present=${already_present} dry_run=${DRY_RUN}"
