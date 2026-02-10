#!/usr/bin/env bash
# Run the credentialed Authentik SSO canary using Infisical as the source of truth.
#
# Why:
# - The Playwright canary validates what public redirect checks cannot: a real OIDC login
#   completes and results in a logged-in session for LMS (and optionally Studio).
# - Canary credentials live in Infisical; this helper injects them as env vars without
#   printing secret values.
#
# Usage:
#   ./scripts/infra/run-authenticated-sso-canary-from-infisical.sh --env prod
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

INFISICAL_DOMAIN="${INFISICAL_DOMAIN:-https://secrets.mereka.io/api}"
INFISICAL_ENV="${INFISICAL_ENV:-prod}"
INFISICAL_PATH="${INFISICAL_PATH:-/shared/oauth}"
INFISICAL_DIR="${INFISICAL_DIR:-}"
INFISICAL_PROJECT_ID="${INFISICAL_PROJECT_ID:-}"
INFISICAL_TOKEN="${INFISICAL_TOKEN:-}"

ENV_SCOPE="prod" # prod|dev|both
REQUIRE_STUDIO_CANARY="${REQUIRE_STUDIO_CANARY:-0}"
REQUIRE_SECRETS="${REQUIRE_SECRETS:-1}"

usage() {
  cat <<'EOF' >&2
Usage: ./scripts/infra/run-authenticated-sso-canary-from-infisical.sh [--env prod|dev|both]

Env:
  INFISICAL_DOMAIN=https://secrets.mereka.io/api
  INFISICAL_ENV=prod
  INFISICAL_PATH=/shared/oauth
  INFISICAL_PROJECT_ID=...         (auto-inferred when possible)
  INFISICAL_TOKEN=...              (optional)
  REQUIRE_SECRETS=1                Fail if canary secrets are missing (default: 1)
  REQUIRE_STUDIO_CANARY=0          Also require Studio canary access creds (default: 0)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_SCOPE="${2:-}"; shift 2 ;;
    -h|--help)
      usage
      exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ "$ENV_SCOPE" != "prod" && "$ENV_SCOPE" != "dev" && "$ENV_SCOPE" != "both" ]]; then
  echo "Invalid --env: $ENV_SCOPE" >&2
  usage
  exit 1
fi

need_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || { echo "Missing required command: $cmd" >&2; exit 1; }
}

need_cmd infisical
need_cmd jq

resolve_infisical_dir() {
  if [[ -n "${INFISICAL_DIR:-}" ]]; then
    return
  fi
  local candidates=(
    "/home/gurpreet/projects/secrets-management"
    "$REPO_ROOT"
  )
  for candidate in "${candidates[@]}"; do
    if [[ -f "${candidate}/.infisical.json" ]]; then
      INFISICAL_DIR="$candidate"
      return
    fi
  done
  INFISICAL_DIR="$REPO_ROOT"
}

infer_project_id_from_backup() {
  local backup_dir="${INFISICAL_BACKUP_DIR:-$HOME/.infisical/secrets-backup}"
  local candidate=""
  if [[ -d "$backup_dir" ]]; then
    candidate=$(ls "$backup_dir"/project_secrets_* 2>/dev/null | head -n 1 || true)
  fi
  if [[ -n "$candidate" ]]; then
    basename "$candidate" | sed -E 's/^project_secrets_([^_]+)_.*/\1/'
  fi
}

resolve_infisical_dir
if [[ -z "${INFISICAL_PROJECT_ID:-}" ]]; then
  if [[ -r "${INFISICAL_DIR}/.infisical.json" ]]; then
    INFISICAL_PROJECT_ID="$(jq -r '.workspaceId // empty' "${INFISICAL_DIR}/.infisical.json" || true)"
  fi
fi
if [[ -z "${INFISICAL_PROJECT_ID:-}" ]]; then
  INFISICAL_PROJECT_ID="$(infer_project_id_from_backup || true)"
fi
if [[ -z "${INFISICAL_PROJECT_ID:-}" ]]; then
  echo "Unable to determine Infisical projectId. Set INFISICAL_PROJECT_ID and retry." >&2
  exit 1
fi

infisical_token_args=()
if [[ -n "${INFISICAL_TOKEN:-}" ]]; then
  infisical_token_args=(--token "${INFISICAL_TOKEN}")
fi

fetch_plain() {
  local key="$1"
  (cd "$INFISICAL_DIR" && infisical secrets get "$key" \
    --domain "$INFISICAL_DOMAIN" \
    --env "$INFISICAL_ENV" \
    --path "$INFISICAL_PATH" \
    --projectId "$INFISICAL_PROJECT_ID" \
    "${infisical_token_args[@]}" \
    --plain --silent)
}

fetch_plain_optional() {
  local key="$1"
  fetch_plain "$key" 2>/dev/null || true
}

# Use the shared admin test creds as the canary identity. Do not print.
SSO_CANARY_EMAIL_PROD="$(fetch_plain GOOGLE_IMPERSONATE_EMAIL)"
SSO_CANARY_PASSWORD_PROD="$(fetch_plain GOOGLE_IMPERSONATE_PASSWORD)"

# Studio canary creds MUST be explicit and should belong to a Studio-access (staff) account.
# Do NOT default to the primary canary identity, because a non-staff user can get stuck in
# a /home -> /login -> oauth2 loop (and this would produce noisy false-negative failures).
SSO_CANARY_STUDIO_EMAIL_PROD="${SSO_CANARY_STUDIO_EMAIL_PROD:-$(fetch_plain_optional SSO_CANARY_STUDIO_EMAIL_PROD)}"
SSO_CANARY_STUDIO_PASSWORD_PROD="${SSO_CANARY_STUDIO_PASSWORD_PROD:-$(fetch_plain_optional SSO_CANARY_STUDIO_PASSWORD_PROD)}"

exec env \
  REQUIRE_SECRETS="$REQUIRE_SECRETS" \
  REQUIRE_STUDIO_CANARY="$REQUIRE_STUDIO_CANARY" \
  SSO_CANARY_EMAIL_PROD="$SSO_CANARY_EMAIL_PROD" \
  SSO_CANARY_PASSWORD_PROD="$SSO_CANARY_PASSWORD_PROD" \
  SSO_CANARY_STUDIO_EMAIL_PROD="$SSO_CANARY_STUDIO_EMAIL_PROD" \
  SSO_CANARY_STUDIO_PASSWORD_PROD="$SSO_CANARY_STUDIO_PASSWORD_PROD" \
  "$REPO_ROOT/scripts/qa/verify-authenticated-sso-canary.sh" --env "$ENV_SCOPE"
