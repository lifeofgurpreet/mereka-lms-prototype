#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

INFISICAL_DOMAIN="${INFISICAL_DOMAIN:-https://secrets.mereka.io/api}"
INFISICAL_ENV="${INFISICAL_ENV:-prod}"
INFISICAL_PATH="${INFISICAL_PATH:-/k8s/mereka-lms}"
INFISICAL_DIR="${INFISICAL_DIR:-}"
INFISICAL_PROJECT_ID="${INFISICAL_PROJECT_ID:-}"
INFISICAL_CONFIG_FILE="${INFISICAL_CONFIG_FILE:-}"
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

resolve_infisical_dir() {
  if [[ -n "${INFISICAL_DIR:-}" ]]; then
    return
  fi
  local candidates=(
    "$REPO_ROOT"
    "/home/gurpreet/projects/secrets-management"
    "/home/gurpreet/projects/k8s/reka-slackbot"
    "/home/gurpreet/projects/standalone/spoken"
  )
  for candidate in "${candidates[@]}"; do
    if [[ -f "${candidate}/.infisical.json" ]]; then
      INFISICAL_DIR="$candidate"
      break
    fi
  done
}

resolve_infisical_dir

if [[ -z "${INFISICAL_DIR:-}" || ! -d "$INFISICAL_DIR" ]]; then
  echo "Infisical config dir not found. Set INFISICAL_DIR to a repo with .infisical.json" >&2
  exit 1
fi

INFISICAL_CONFIG_FILE="${INFISICAL_CONFIG_FILE:-${INFISICAL_DIR}/.infisical.json}"

if [[ ! -f "$INFISICAL_CONFIG_FILE" ]]; then
  echo "Missing .infisical.json at ${INFISICAL_CONFIG_FILE}" >&2
  exit 1
fi

if [[ -z "$INFISICAL_PROJECT_ID" ]]; then
  if [[ -f "$INFISICAL_CONFIG_FILE" ]]; then
    INFISICAL_PROJECT_ID=$(jq -r '.workspaceId // empty' "$INFISICAL_CONFIG_FILE")
  fi
fi

if [[ -z "$INFISICAL_PROJECT_ID" ]]; then
  echo "INFISICAL_PROJECT_ID not set and workspaceId missing from $INFISICAL_CONFIG_FILE" >&2
  exit 1
fi

log "Collecting expected secret keys from external-secrets.yaml..."
expected_keys=$(rg -o "MEREKA_LMS_[A-Z0-9_]+" "$EXTERNAL_SECRETS_FILE" | sort -u)

log "Collecting actual secret keys from Infisical (${INFISICAL_PATH})..."
tmpfile=$(mktemp)
tmpvalues=$(mktemp)
trap 'rm -f "$tmpfile" "$tmpvalues"' EXIT
(
  cd "$INFISICAL_DIR"
  infisical secrets generate-example-env \
    --domain "$INFISICAL_DOMAIN" \
    --env "$INFISICAL_ENV" \
    --path "$INFISICAL_PATH" \
    --projectId "$INFISICAL_PROJECT_ID" \
    > "$tmpfile"
)
actual_keys=$(cut -d= -f1 "$tmpfile" | sed '/^$/d' | sort -u)

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

log "Checking for empty or placeholder values in Infisical..."
(
  cd "$INFISICAL_DIR"
  infisical secrets --domain "$INFISICAL_DOMAIN" --env "$INFISICAL_ENV" --path "$INFISICAL_PATH" --output json > "$tmpvalues"
)
empty_values=$(jq -r '.[] | select((.secretValue == null) or (.secretValue == "") or (.secretValue|tostring|test("\\*not found\\*"; "i"))) | .secretKey' "$tmpvalues")
if [[ -n "$empty_values" ]]; then
  echo "Infisical secrets with empty values:" >&2
  echo "$empty_values" >&2
  exit 1
fi
