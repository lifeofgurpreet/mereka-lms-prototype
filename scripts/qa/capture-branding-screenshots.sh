#!/usr/bin/env bash
# Capture screenshots of the public branding surfaces for prod/dev.
#
# This is an operator tool: it writes screenshots under var/ (gitignored).
# It uses `agent-browser`, so it is intended to be run by humans/agents with
# access to a browser-capable environment.
#
# Usage:
#   ./scripts/qa/capture-branding-screenshots.sh prod
#   ./scripts/qa/capture-branding-screenshots.sh dev
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

ENVIRONMENT="${1:-}"
if [[ "$ENVIRONMENT" != "prod" && "$ENVIRONMENT" != "dev" ]]; then
  echo "Usage: $0 {prod|dev}" >&2
  exit 2
fi

if ! command -v agent-browser >/dev/null 2>&1; then
  echo "agent-browser is required (Codex skill: agent-browser)." >&2
  exit 2
fi

ts="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="$REPO_ROOT/var/screenshots/${ENVIRONMENT}/${ts}"
mkdir -p "$OUT_DIR"
AB_TIMEOUT_SECONDS="${AGENT_BROWSER_TIMEOUT_SECONDS:-45}"

ab_run() {
  timeout --foreground "${AB_TIMEOUT_SECONDS}s" agent-browser "$@" 2>&1
}

ab() {
  local out status uid session cmd
  cmd="$*"
  if out="$(ab_run "$@")"; then
    [[ -n "$out" ]] && echo "$out"
    return 0
  fi
  status=$?
  if [[ "$status" -eq 124 ]]; then
    echo "agent-browser timed out after ${AB_TIMEOUT_SECONDS}s: ${cmd}" >&2
    return 124
  fi
  if grep -q "Daemon failed to start" <<<"$out"; then
    uid="$(id -u)"
    session="${AGENT_BROWSER_SESSION:-default}"
    rm -f \
      "/run/user/${uid}/agent-browser/${session}.sock" \
      "/tmp/agent-browser-runtime-${uid}/agent-browser/${session}.sock" \
      2>/dev/null || true
    sleep 1
    if out="$(ab_run "$@")"; then
      [[ -n "$out" ]] && echo "$out"
      return 0
    fi
    status=$?
    if [[ "$status" -eq 124 ]]; then
      echo "agent-browser timed out after ${AB_TIMEOUT_SECONDS}s (retry): ${cmd}" >&2
      return 124
    fi
  fi
  echo "$out" >&2
  return "$status"
}

base_lms="$LMS_DOMAIN"
base_studio="$STUDIO_DOMAIN"
base_mfe="$MFE_DOMAIN"
base_ecommerce="$ECOMMERCE_DOMAIN"
base_credentials="$CREDENTIALS_DOMAIN"
biji="$BIJI_DOMAIN"
sof="$SKILLOURFUTURE_DOMAIN"
biji_studio="$BIJI_STUDIO_DOMAIN"
biji_mfe="$BIJI_MFE_DOMAIN"

if [[ "$ENVIRONMENT" == "dev" ]]; then
  base_lms="$DEV_LMS_DOMAIN"
  base_studio="$DEV_STUDIO_DOMAIN"
  base_mfe="$DEV_MFE_DOMAIN"
  base_ecommerce="$DEV_ECOMMERCE_DOMAIN"
  base_credentials="$DEV_CREDENTIALS_DOMAIN"
  biji="" # dev does not serve biji/sof microsites
  sof=""
  biji_studio=""
  biji_mfe=""
fi

declare -a URLS=(
  "lms-home|https://${base_lms}/"
  "lms-courses|https://${base_lms}/courses"
  "studio-home|https://${base_studio}/"
  "mfe-authn-login|https://${base_mfe}/authn/login"
  "mfe-learning|https://${base_mfe}/learning/"
  "mfe-account|https://${base_mfe}/account/"
  "mfe-account-settings|https://${base_mfe}/account/settings"
  "mfe-learner-dashboard|https://${base_mfe}/learner-dashboard/"
  "ecommerce-root|https://${base_ecommerce}/"
  "ecommerce-dashboard|https://${base_ecommerce}/dashboard/"
  "ecommerce-basket|https://${base_ecommerce}/basket/"
  "ecommerce-checkout|https://${base_ecommerce}/checkout/"
  "ecommerce-stripe-webhook|https://${base_ecommerce}/api/v2/webhooks/stripe/"
  "credentials-admin-login|https://${base_credentials}/admin/login/"
  "forum-home|https://forum.${base_lms}/"
  "forum-heartbeat|https://forum.${base_lms}/heartbeat"
  "notes-root|https://notes.${base_lms}/"
)

if [[ -n "$biji" ]]; then
  URLS+=("biji-home|https://${biji}/")
fi
if [[ -n "$biji_studio" ]]; then
  URLS+=("biji-studio-home|https://${biji_studio}/")
fi
if [[ -n "$biji_mfe" ]]; then
  URLS+=("biji-mfe-authn-login|https://${biji_mfe}/authn/login")
  URLS+=("biji-mfe-account|https://${biji_mfe}/account/")
fi
if [[ -n "$sof" ]]; then
  URLS+=("skillourfuture-home|https://${sof}/")
fi

sanitize() {
  echo "$1" | tr ' /:' '___' | tr -cd 'a-zA-Z0-9_.-'
}

echo "Capturing screenshots to: $OUT_DIR"
ab set viewport 1440 900 >/dev/null

for entry in "${URLS[@]}"; do
  label="${entry%%|*}"
  url="${entry#*|}"
  file="$OUT_DIR/$(sanitize "$label").png"

  echo "- $label: $url"
  ab open "$url" >/dev/null
  ab wait --load networkidle >/dev/null || true
  ab screenshot --full "$file" >/dev/null
done

ab close >/dev/null || true

echo "OK"
