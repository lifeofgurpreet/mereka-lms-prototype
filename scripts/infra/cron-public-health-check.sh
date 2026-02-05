#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOG_DIR="${LOG_DIR:-${REPO_ROOT}/var}"

mkdir -p "$LOG_DIR"

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

run_check() {
  local env=$1
  log "Running public health checks (${env})..."
  if [[ "$env" == "prod" ]]; then
    CHECK_CERTS=1 CHECK_BRANDING=1 "$REPO_ROOT/scripts/qa/public-health-check.sh" "$env"
  else
    CHECK_BRANDING=1 "$REPO_ROOT/scripts/qa/public-health-check.sh" "$env"
  fi
}

run_check prod
run_check dev

log "Public health checks complete."
