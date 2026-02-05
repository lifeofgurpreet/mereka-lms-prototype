#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOG_DIR="${LOG_DIR:-${REPO_ROOT}/var}"
CRON_SCHEDULE="${CRON_SCHEDULE:-*/30 * * * *}"
CRON_LOG="${CRON_LOG:-${LOG_DIR}/cron-public-health-check.log}"
CRON_CMD="cd ${REPO_ROOT} && ./scripts/infra/cron-public-health-check.sh >> ${CRON_LOG} 2>&1"
CRON_LINE="${CRON_SCHEDULE} ${CRON_CMD}"

mkdir -p "${LOG_DIR}"

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

existing=$(crontab -l 2>/dev/null | sed '/^#/d' || true)
if echo "${existing}" | rg -q "cron-public-health-check.sh"; then
  log "Cron entry already present. Skipping."
  exit 0
fi

log "Installing VPS cron for public health checks..."
{
  echo "${existing}"
  echo "${CRON_LINE}"
} | crontab -

log "Cron installed: ${CRON_LINE}"
log "Logs will write to: ${CRON_LOG}"
