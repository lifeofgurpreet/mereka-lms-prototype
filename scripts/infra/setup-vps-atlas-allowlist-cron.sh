#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOG_DIR="${LOG_DIR:-${REPO_ROOT}/var}"
CRON_SCHEDULE="${CRON_SCHEDULE:-*/30 * * * *}"
CRON_LOG="${CRON_LOG:-${LOG_DIR}/atlas-allowlist.log}"
CRON_CMD="cd ${REPO_ROOT} && ./scripts/infra/monitor-atlas-allowlist-vps.sh >> ${CRON_LOG} 2>&1"
CRON_LINE="${CRON_SCHEDULE} ${CRON_CMD}"

mkdir -p "${LOG_DIR}"

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

existing=$(crontab -l 2>/dev/null | sed '/^#/d' || true)

# Remove legacy allowlist cron entries and replace with monitoring wrapper.
existing=$(echo "${existing}" | rg -v "check-atlas-allowlist-vps.sh|ensure-atlas-allowlist-vps.sh|monitor-atlas-allowlist-vps.sh|atlas-allowlist.log" || true)

log "Installing VPS cron for Atlas allowlist updates..."
{
  echo "${existing}"
  echo "${CRON_LINE}"
} | crontab -

log "Cron installed: ${CRON_LINE}"
log "Logs will write to: ${CRON_LOG}"
