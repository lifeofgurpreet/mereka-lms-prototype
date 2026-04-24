#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOG_DIR="${LOG_DIR:-${REPO_ROOT}/var}"
CRON_SCHEDULE="${CRON_SCHEDULE:-15 */6 * * *}"
CRON_LOG="${CRON_LOG:-${LOG_DIR}/cron-branding-visual-regression.log}"
CRON_ENV_FILE="${CRON_ENV_FILE:-${REPO_ROOT}/var/branding-visual-regression.env}"
CRON_CMD="cd ${REPO_ROOT} && [ -f ${CRON_ENV_FILE} ] && . ${CRON_ENV_FILE}; ./scripts/infra/cron-branding-visual-regression.sh >> ${CRON_LOG} 2>&1"
CRON_LINE="${CRON_SCHEDULE} ${CRON_CMD}"

mkdir -p "${LOG_DIR}"

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

existing=$(crontab -l 2>/dev/null | sed '/^#/d' || true)
existing=$(echo "${existing}" | rg -v "cron-branding-visual-regression.sh|cron-branding-visual-regression.log" || true)

log "Installing VPS cron for branding visual regression checks..."
{
  echo "${existing}"
  echo "${CRON_LINE}"
} | crontab -

log "Cron installed: ${CRON_LINE}"
log "Logs will write to: ${CRON_LOG}"
log "Optional env file: ${CRON_ENV_FILE}"
