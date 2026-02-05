#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

INFISICAL_DOMAIN="${INFISICAL_DOMAIN:-https://secrets.mereka.io/api}"
INFISICAL_ENV="${INFISICAL_ENV:-prod}"
CANONICAL_PATH="${CANONICAL_PATH:-/k8s/mereka-lms}"
INFISICAL_DIR="${INFISICAL_DIR:-}"

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

if [[ -z "${INFISICAL_DIR:-}" || ! -f "${INFISICAL_DIR}/.infisical.json" ]]; then
  echo "Infisical config not found. Set INFISICAL_DIR to a repo with .infisical.json" >&2
  exit 1
fi

if ! command -v infisical >/dev/null 2>&1; then
  echo "infisical CLI not found" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found. Install jq to continue." >&2
  exit 1
fi

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

fetch_keys() {
  local path=$1
  (cd "$INFISICAL_DIR" && infisical secrets \
    --domain "$INFISICAL_DOMAIN" \
    --env "$INFISICAL_ENV" \
    --path "$path" \
    --output json --silent 2>/dev/null | jq -r '.[].secretKey' | sort -u)
}

log "Loading canonical secrets from ${CANONICAL_PATH} (env=${INFISICAL_ENV})..."
canonical_keys=$(fetch_keys "$CANONICAL_PATH")

if [[ -z "${canonical_keys}" ]]; then
  echo "No secrets found under ${CANONICAL_PATH}. Abort." >&2
  exit 1
fi

log "Checking duplicate keys in legacy paths..."
legacy_paths=(
  "/shared"
  "/mereka-lms"
)

for legacy in "${legacy_paths[@]}"; do
  legacy_keys=$(fetch_keys "$legacy" || true)
  if [[ -z "${legacy_keys}" ]]; then
    printf "  - %s: none\n" "$legacy"
    continue
  fi
  duplicates=$(comm -12 <(printf "%s\n" "$canonical_keys") <(printf "%s\n" "$legacy_keys") || true)
  if [[ -n "${duplicates}" ]]; then
    printf "  - %s duplicates:\n" "$legacy"
    printf "%s\n" "$duplicates"
  else
    printf "  - %s: no duplicates\n" "$legacy"
  fi
done

log "Audit complete. Move duplicates into ${CANONICAL_PATH} and delete legacy copies in the Infisical UI."
