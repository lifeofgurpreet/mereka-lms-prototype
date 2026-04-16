#!/usr/bin/env bash
# Quick health check for the buildx builder estate on the fastlane VPS runner.
#
# Checks:
#   1. Docker daemon responsiveness (timeout 5s)
#   2. Docker socket permissions (warns if not 660 or 666)
#   3. Buildx builder container count (warn >5, alert >10)
#
# Exit codes:
#   0  healthy — all checks passed
#   1  degraded — at least one warning (non-critical)
#   2  critical — docker unavailable or builder count above alert threshold
#
# Usage:
#   buildx-monitor.sh
#
# Cron example (alert via syslog on failure):
#   */5 * * * * /opt/runner/buildx-monitor.sh \
#     || echo "CRITICAL: buildx unhealthy on $(hostname)" | logger -t buildx-monitor
#
# See docs/ops/ci-cd/RUNNER_HYGIENE.md for full installation instructions.

set -euo pipefail

readonly SCRIPT_NAME="buildx-monitor"
readonly WARN_THRESHOLD=5
readonly ALERT_THRESHOLD=10
readonly DOCKER_TIMEOUT=5

# ── Helpers ──────────────────────────────────────────────────────────────────
log() {
  printf "[%s] [%s] %s\n" "$(date '+%Y-%m-%dT%H:%M:%SZ')" "${SCRIPT_NAME}" "$*"
}

# ── State tracking ────────────────────────────────────────────────────────────
STATUS="healthy"   # healthy | degraded | critical
MESSAGES=()

mark_degraded() {
  if [[ "${STATUS}" == "healthy" ]]; then
    STATUS="degraded"
  fi
  MESSAGES+=("WARN: $1")
}

mark_critical() {
  STATUS="critical"
  MESSAGES+=("CRIT: $1")
}

# ── Check 1: Docker daemon responsiveness ────────────────────────────────────
check_docker_daemon() {
  local result
  if result="$(timeout "${DOCKER_TIMEOUT}" docker info 2>&1 | head -1)"; then
    log "docker daemon: OK (${result})"
  else
    mark_critical "docker daemon did not respond within ${DOCKER_TIMEOUT}s"
  fi
}

# ── Check 2: Docker socket permissions ───────────────────────────────────────
check_socket_permissions() {
  local sock="/var/run/docker.sock"
  if [[ ! -e "${sock}" ]]; then
    mark_critical "docker socket not found at ${sock}"
    return
  fi
  local perms
  perms="$(stat -c '%a' "${sock}" 2>/dev/null || echo "")"
  if [[ -z "${perms}" ]]; then
    mark_degraded "could not stat ${sock}"
    return
  fi
  case "${perms}" in
    660|666)
      log "docker socket permissions: ${perms} (OK)"
      ;;
    *)
      mark_degraded "docker socket permissions are ${perms} (expected 660 or 666) — runner may fail on docker commands"
      ;;
  esac
}

# ── Check 3: Buildx builder container count ──────────────────────────────────
check_buildx_count() {
  # Count containers whose names start with buildx_buildkit_.
  local count
  count="$(docker ps -a \
    --filter "name=buildx_buildkit" \
    --format '{{.Names}}' 2>/dev/null \
    | grep -c '.' || true)"

  log "buildx_buildkit containers: ${count}"

  if [[ "${count}" -gt "${ALERT_THRESHOLD}" ]]; then
    mark_critical "buildx container count ${count} exceeds alert threshold (${ALERT_THRESHOLD}) — run buildx-cleanup.sh immediately"
  elif [[ "${count}" -gt "${WARN_THRESHOLD}" ]]; then
    mark_degraded "buildx container count ${count} exceeds warn threshold (${WARN_THRESHOLD}) — consider running buildx-cleanup.sh"
  fi
}

# ── Run checks ───────────────────────────────────────────────────────────────
check_docker_daemon

# Only continue with further checks if docker is reachable.
if [[ "${STATUS}" != "critical" ]]; then
  check_socket_permissions
  check_buildx_count
fi

# ── Summary ───────────────────────────────────────────────────────────────────
for msg in "${MESSAGES[@]:-}"; do
  log "${msg}"
done

case "${STATUS}" in
  healthy)
    log "STATUS=healthy"
    exit 0
    ;;
  degraded)
    log "STATUS=degraded"
    exit 1
    ;;
  critical)
    log "STATUS=critical"
    exit 2
    ;;
esac
