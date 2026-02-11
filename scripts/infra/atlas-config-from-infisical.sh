#!/usr/bin/env bash
# @covers AC-007
# @spec: mongodb-atlas-integration_spec.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

INFISICAL_DOMAIN="${INFISICAL_DOMAIN:-https://secrets.mereka.io/api}"
INFISICAL_ENV="${INFISICAL_ENV:-prod}"
INFISICAL_PATH="${INFISICAL_PATH:-/k8s/mereka-lms/atlas}"
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

if ! command -v atlas >/dev/null 2>&1; then
  echo "atlas CLI not found" >&2
  exit 1
fi

get_secret() {
  local key=$1
  (cd "$INFISICAL_DIR" && infisical secrets get "$key" \
    --domain "$INFISICAL_DOMAIN" \
    --env "$INFISICAL_ENV" \
    --path "$INFISICAL_PATH" \
    --plain 2>/dev/null || true)
}

ATLAS_PUBLIC_KEY=$(get_secret ATLAS_PUBLIC_KEY)
ATLAS_PRIVATE_KEY=$(get_secret ATLAS_PRIVATE_KEY)
ATLAS_ORG_ID=$(get_secret ATLAS_ORG_ID)
ATLAS_PROJECT_ID=$(get_secret ATLAS_PROJECT_ID)
ATLAS_PROFILE=$(get_secret ATLAS_PROFILE)

if [[ -z "${ATLAS_PROFILE}" || "${ATLAS_PROFILE}" == "REPLACE_ME" ]]; then
  ATLAS_PROFILE="mereka-lms"
fi

for var in ATLAS_PUBLIC_KEY ATLAS_PRIVATE_KEY ATLAS_ORG_ID; do
  value="${!var}"
  if [[ -z "$value" || "$value" == "REPLACE_ME" ]]; then
    echo "Missing ${var} in Infisical (${INFISICAL_PATH}, env=${INFISICAL_ENV})" >&2
    exit 1
  fi
done

echo "Configuring atlas profile '${ATLAS_PROFILE}' from Infisical (${INFISICAL_ENV}:${INFISICAL_PATH})..."

atlas config set public_api_key "$ATLAS_PUBLIC_KEY" -P "$ATLAS_PROFILE"
atlas config set private_api_key "$ATLAS_PRIVATE_KEY" -P "$ATLAS_PROFILE"
atlas config set org_id "$ATLAS_ORG_ID" -P "$ATLAS_PROFILE"
if [[ -n "${ATLAS_PROJECT_ID}" && "${ATLAS_PROJECT_ID}" != "REPLACE_ME" ]]; then
  atlas config set project_id "$ATLAS_PROJECT_ID" -P "$ATLAS_PROFILE"
fi
atlas config set output plaintext -P "$ATLAS_PROFILE"

atlas config describe "$ATLAS_PROFILE"
