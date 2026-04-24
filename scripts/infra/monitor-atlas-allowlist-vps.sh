#!/usr/bin/env bash
set -euo pipefail

# Monitor Atlas allowlist drift for VPS egress and emit alerts.
#
# Behavior:
# - Runs check-atlas-allowlist-vps.sh
# - Writes a machine-readable status file under var/
# - Sends webhook notification on failure (if ATLAS_ALLOWLIST_WEBHOOK_URL is set)
#
# Intended cadence: every 30 minutes (drift notification <= 1h)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

LOG_DIR="${LOG_DIR:-${REPO_ROOT}/var}"
STATUS_FILE="${STATUS_FILE:-${LOG_DIR}/atlas-allowlist-status.json}"
ATLAS_ALLOWLIST_WEBHOOK_URL="${ATLAS_ALLOWLIST_WEBHOOK_URL:-}"
ATLAS_ALLOWLIST_WEBHOOK_URL_FILE="${ATLAS_ALLOWLIST_WEBHOOK_URL_FILE:-${LOG_DIR}/atlas-allowlist-monitor.env}"
ALERT_COOLDOWN_MINUTES="${ALERT_COOLDOWN_MINUTES:-60}"
FORCE_ALERT="${FORCE_ALERT:-0}"

mkdir -p "$LOG_DIR"

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

resolve_webhook_url() {
  if [[ -n "${ATLAS_ALLOWLIST_WEBHOOK_URL:-}" ]]; then
    return 0
  fi
  if [[ -n "${ATLAS_ALLOWLIST_WEBHOOK_URL_FILE:-}" && -f "${ATLAS_ALLOWLIST_WEBHOOK_URL_FILE}" ]]; then
    ATLAS_ALLOWLIST_WEBHOOK_URL="$(tr -d '\r\n' <"${ATLAS_ALLOWLIST_WEBHOOK_URL_FILE}")"
  fi
}

write_status() {
  local status="$1"
  local message="$2"
  local webhook_configured="false"
  if [[ -n "${ATLAS_ALLOWLIST_WEBHOOK_URL:-}" ]]; then
    webhook_configured="true"
  fi
  cat >"$STATUS_FILE" <<EOF
{
  "status": "${status}",
  "message": "$(printf '%s' "$message" | sed 's/"/\\"/g')",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "webhook_configured": ${webhook_configured}
}
EOF
}

should_alert_now() {
  if [[ "$FORCE_ALERT" == "1" ]]; then
    return 0
  fi
  local stamp_file="${LOG_DIR}/atlas-allowlist-last-alert.ts"
  if [[ ! -f "$stamp_file" ]]; then
    return 0
  fi
  local now epoch_last delta limit
  now="$(date +%s)"
  epoch_last="$(cat "$stamp_file" 2>/dev/null || echo 0)"
  limit=$((ALERT_COOLDOWN_MINUTES * 60))
  delta=$((now - epoch_last))
  [[ "$delta" -ge "$limit" ]]
}

send_webhook_alert() {
  local body="$1"
  [[ -n "$ATLAS_ALLOWLIST_WEBHOOK_URL" ]] || return 0
  if ! should_alert_now; then
    log "Skipping webhook alert (cooldown active)"
    return 0
  fi
  curl -fsS -X POST "$ATLAS_ALLOWLIST_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$body" >/dev/null || log "WARN: failed to send webhook alert"
  date +%s >"${LOG_DIR}/atlas-allowlist-last-alert.ts"
}

resolve_webhook_url

tmp_log="$(mktemp -t atlas-allowlist-vps.XXXXXX)"
trap 'rm -f "$tmp_log"' EXIT

if "${SCRIPT_DIR}/check-atlas-allowlist-vps.sh" >"$tmp_log" 2>&1; then
  output="$(cat "$tmp_log")"
  log "$output"
  write_status "ok" "Atlas allowlist matches VPS egress."
  exit 0
fi

output="$(cat "$tmp_log")"
log "ATLAS_ALLOWLIST_DRIFT detected"
log "$output"

write_status "drift" "$output"

payload=$(cat <<EOF
{
  "severity": "error",
  "source": "atlas-allowlist-monitor",
  "message": "ATLAS_ALLOWLIST_DRIFT detected for VPS egress. Run ./scripts/infra/ensure-atlas-allowlist-vps.sh and re-check.",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)
send_webhook_alert "$payload"

exit 1
