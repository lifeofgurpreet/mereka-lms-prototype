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

base_lms="$LMS_DOMAIN"
base_studio="$STUDIO_DOMAIN"
base_mfe="$MFE_DOMAIN"
base_ecommerce="$ECOMMERCE_DOMAIN"
base_credentials="$CREDENTIALS_DOMAIN"
biji="$BIJI_DOMAIN"
sof="$SKILLOURFUTURE_DOMAIN"

if [[ "$ENVIRONMENT" == "dev" ]]; then
  base_lms="$DEV_LMS_DOMAIN"
  base_studio="$DEV_STUDIO_DOMAIN"
  base_mfe="$DEV_MFE_DOMAIN"
  base_ecommerce="$DEV_ECOMMERCE_DOMAIN"
  base_credentials="$DEV_CREDENTIALS_DOMAIN"
  biji="" # dev does not serve biji/sof microsites
  sof=""
fi

declare -a URLS=(
  "lms-home|https://${base_lms}/"
  "studio-home|https://${base_studio}/"
  "mfe-authn-login|https://${base_mfe}/authn/login"
  "ecommerce-dashboard|https://${base_ecommerce}/dashboard/"
  "credentials-admin-login|https://${base_credentials}/admin/login/"
)

if [[ -n "$biji" ]]; then
  URLS+=("biji-home|https://${biji}/")
fi
if [[ -n "$sof" ]]; then
  URLS+=("skillourfuture-home|https://${sof}/")
fi

sanitize() {
  echo "$1" | tr ' /:' '___' | tr -cd 'a-zA-Z0-9_.-'
}

echo "Capturing screenshots to: $OUT_DIR"
agent-browser set viewport 1440 900 >/dev/null

for entry in "${URLS[@]}"; do
  label="${entry%%|*}"
  url="${entry#*|}"
  file="$OUT_DIR/$(sanitize "$label").png"

  echo "- $label: $url"
  agent-browser open "$url" >/dev/null
  agent-browser wait --load networkidle >/dev/null || true
  agent-browser screenshot --full "$file" >/dev/null
done

agent-browser close >/dev/null || true

echo "OK"

