#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

TARGET_ENVS="${TARGET_ENVS:-prod dev}"
VISUAL_THRESHOLD="${VISUAL_THRESHOLD:-0.06}"
# Keep cron regression focused on stable, public unauthenticated surfaces.
# Dynamic/authenticated pages (dashboards, account, webhook endpoints) produce noisy diffs.
VISUAL_EXCLUDE_REGEX="${VISUAL_EXCLUDE_REGEX:-(lms-courses|mfe-account|mfe-account-settings|mfe-learner-dashboard|ecommerce-dashboard|ecommerce-stripe-webhook|forum-home|notes-root|biji-mfe-account)}"
VISUAL_STRICT="${VISUAL_STRICT:-0}"
AUDIT_STRICT="${AUDIT_STRICT:-1}"
STRICT_MFE_BRANDING_REV="${STRICT_MFE_BRANDING_REV:-1}"

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

log "Visual regression threshold=${VISUAL_THRESHOLD} exclude_regex='${VISUAL_EXCLUDE_REGEX}'"

run_for_env() {
  local env="$1"
  local certs_flag=0

  if [[ "$env" == "prod" ]]; then
    certs_flag=1
  fi

  log "Running branding gate with screenshot capture + visual regression (${env})"
  RUN_SOURCE_GATE=0 \
  RUN_SCREENSHOTS=1 \
  RUN_VISUAL_REGRESSION=1 \
  VISUAL_ALLOW_BOOTSTRAP=1 \
  VISUAL_THRESHOLD="${VISUAL_THRESHOLD}" \
  VISUAL_EXCLUDE_REGEX="${VISUAL_EXCLUDE_REGEX}" \
  VISUAL_STRICT="${VISUAL_STRICT}" \
  AUDIT_STRICT="${AUDIT_STRICT}" \
  STRICT_MFE_BRANDING_REV="${STRICT_MFE_BRANDING_REV}" \
  CHECK_CERTS="${certs_flag}" \
    "$REPO_ROOT/scripts/branding/run-branding-gates.sh" "$env"
}

for env in $TARGET_ENVS; do
  if [[ "$env" != "prod" && "$env" != "dev" ]]; then
    log "Skipping invalid env in TARGET_ENVS: $env"
    continue
  fi
  run_for_env "$env"
done

log "Branding visual regression cron run complete."
