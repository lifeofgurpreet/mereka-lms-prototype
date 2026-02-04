#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

INFISICAL_DOMAIN="${INFISICAL_DOMAIN:-https://secrets.mereka.io/api}"
INFISICAL_ENV="${INFISICAL_ENV:-prod}"
INFISICAL_PATH="${INFISICAL_PATH:-/k8s/mereka-lms}"
INFISICAL_DIR="${INFISICAL_DIR:-/home/gurpreet/projects/k8s/reka-slackbot}"
EXTERNAL_SECRETS_FILE="${EXTERNAL_SECRETS_FILE:-${REPO_ROOT}/deploy/k8s/base/secrets/external-secrets.yaml}"

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

if ! command -v infisical >/dev/null 2>&1; then
  echo "infisical CLI not found. Install and authenticate first." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found. Install jq to continue." >&2
  exit 1
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "rg (ripgrep) not found. Install rg to continue." >&2
  exit 1
fi

if [[ ! -f "$EXTERNAL_SECRETS_FILE" ]]; then
  echo "Missing external secrets file: $EXTERNAL_SECRETS_FILE" >&2
  exit 1
fi

if [[ ! -d "$INFISICAL_DIR" ]]; then
  echo "Infisical config dir not found: $INFISICAL_DIR" >&2
  exit 1
fi

log "Collecting expected secret keys from external-secrets.yaml..."
expected_keys=$(rg -o "MEREKA_LMS_[A-Z0-9_]+" "$EXTERNAL_SECRETS_FILE" | sort -u)

log "Collecting actual secret keys from Infisical (${INFISICAL_PATH})..."
actual_keys=$(cd "$INFISICAL_DIR" && infisical secrets \
  --domain "$INFISICAL_DOMAIN" \
  --env "$INFISICAL_ENV" \
  --path "$INFISICAL_PATH" \
  --output json 2>/dev/null | jq -r '.[].secretKey' | sort -u)

missing=$(comm -23 <(printf "%s\n" "$expected_keys") <(printf "%s\n" "$actual_keys") || true)
extra=$(comm -13 <(printf "%s\n" "$expected_keys") <(printf "%s\n" "$actual_keys") || true)

if [[ -n "$missing" ]]; then
  echo "Missing Infisical secrets:" >&2
  echo "$missing" >&2
  exit 1
fi

log "All expected secrets exist in Infisical."
if [[ -n "$extra" ]]; then
  log "Additional secrets present in Infisical (review if needed):"
  echo "$extra"
fi
