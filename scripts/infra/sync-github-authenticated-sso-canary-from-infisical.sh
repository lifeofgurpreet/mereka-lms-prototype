#!/usr/bin/env bash
# Sync authenticated SSO canary credentials from Infisical -> GitHub secrets.
#
# Goal: Infisical remains the single source of truth; GitHub Actions reads canary
# creds via repo secrets for the credentialed browser canary gate.
#
# This script never prints secret values.
#
# Usage:
#   ./scripts/infra/sync-github-authenticated-sso-canary-from-infisical.sh --enable-runtime-gate
#
# Env (optional):
#   INFISICAL_DOMAIN=https://secrets.mereka.io/api
#   INFISICAL_ENV=prod
#   INFISICAL_PATH=/shared/oauth
#   INFISICAL_PROJECT_ID=...              (auto-inferred when possible)
#   INFISICAL_TOKEN=...                   (optional; service token/machine token)
#   REPO_SLUG=Biji-Biji-Initiative/mereka-lms
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$REPO_ROOT/../.." && pwd)}"

INFISICAL_DOMAIN="${INFISICAL_DOMAIN:-https://secrets.mereka.io/api}"
INFISICAL_ENV="${INFISICAL_ENV:-prod}"
INFISICAL_PATH="${INFISICAL_PATH:-/shared/oauth}"
INFISICAL_DIR="${INFISICAL_DIR:-}"
INFISICAL_PROJECT_ID="${INFISICAL_PROJECT_ID:-}"
INFISICAL_TOKEN="${INFISICAL_TOKEN:-}"

REPO_SLUG="${REPO_SLUG:-Biji-Biji-Initiative/mereka-lms}"
REQUIRE_DEV="${REQUIRE_DEV:-0}"
REQUIRE_STUDIO="${REQUIRE_STUDIO:-0}"
ENABLE_RUNTIME_GATE=0

usage() {
  cat <<EOF_USAGE
Usage: $0 [--repo owner/repo] [--require-dev] [--require-studio] [--enable-runtime-gate]

This syncs Infisical /shared/oauth into GitHub secrets:
  GOOGLE_IMPERSONATE_EMAIL     -> SSO_CANARY_EMAIL_PROD
  GOOGLE_IMPERSONATE_PASSWORD  -> SSO_CANARY_PASSWORD_PROD

Options:
  --repo owner/repo      GitHub repo slug (default: $REPO_SLUG)
  --require-dev          Require dev canary secrets too (default: $REQUIRE_DEV)
  --require-studio       Require Studio canary secrets too (default: $REQUIRE_STUDIO)
  --enable-runtime-gate  Set repo variable RUN_AUTHENTICATED_SSO_CANARY=true
  -h, --help             Show help

Env (Infisical):
  INFISICAL_DOMAIN, INFISICAL_ENV, INFISICAL_PATH, INFISICAL_PROJECT_ID, INFISICAL_TOKEN
EOF_USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO_SLUG="${2:-}"; shift 2 ;;
    --require-dev)
      REQUIRE_DEV=1; shift ;;
    --require-studio)
      REQUIRE_STUDIO=1; shift ;;
    --enable-runtime-gate)
      ENABLE_RUNTIME_GATE=1; shift ;;
    -h|--help)
      usage
      exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1 ;;
  esac
done

need_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || { echo "Missing required command: $cmd" >&2; exit 1; }
}

need_cmd infisical
need_cmd jq
need_cmd gh

resolve_infisical_dir() {
  if [[ -n "${INFISICAL_DIR:-}" ]]; then
    return
  fi
  local candidates=(
    "${WORKSPACE_ROOT}/secrets-management"
    "${HOME}/projects/secrets-management"
    "$REPO_ROOT"
  )
  for candidate in "${candidates[@]}"; do
    if [[ -f "${candidate}/.infisical.json" ]]; then
      INFISICAL_DIR="$candidate"
      return
    fi
  done
}

infer_project_id_from_backup() {
  local backup_dir="${INFISICAL_BACKUP_DIR:-$HOME/.infisical/secrets-backup}"
  local candidate=""
  if [[ -d "$backup_dir" ]]; then
    candidate=$(ls "$backup_dir"/project_secrets_* 2>/dev/null | head -n 1 || true)
  fi
  if [[ -n "$candidate" ]]; then
    # Example filename: project_secrets_<workspaceId>_<timestamp>.json
    basename "$candidate" | sed -E 's/^project_secrets_([^_]+)_.*/\1/'
  fi
}

resolve_infisical_dir
if [[ -z "${INFISICAL_DIR:-}" || ! -d "$INFISICAL_DIR" ]]; then
  # Infisical CLI can operate with global auth even without a repo-local .infisical.json.
  INFISICAL_DIR="$REPO_ROOT"
fi

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

# Source-of-truth shared creds used for Authentik + LMS admin verification.
export SSO_CANARY_EMAIL_PROD
export SSO_CANARY_PASSWORD_PROD
SSO_CANARY_EMAIL_PROD="$(fetch_plain GOOGLE_IMPERSONATE_EMAIL)"
SSO_CANARY_PASSWORD_PROD="$(fetch_plain GOOGLE_IMPERSONATE_PASSWORD)"

# Studio canary creds MUST be explicit and should belong to a Studio-access (staff) account.
# Do NOT default to the primary canary identity, otherwise non-staff users can get stuck
# in a /home -> /login -> oauth2 loop and the gate becomes noisy.
export SSO_CANARY_STUDIO_EMAIL_PROD="${SSO_CANARY_STUDIO_EMAIL_PROD:-$(fetch_plain_optional SSO_CANARY_STUDIO_EMAIL_PROD)}"
export SSO_CANARY_STUDIO_PASSWORD_PROD="${SSO_CANARY_STUDIO_PASSWORD_PROD:-$(fetch_plain_optional SSO_CANARY_STUDIO_PASSWORD_PROD)}"

# Delegate GitHub secret creation to the existing helper.
exec env \
  REPO_SLUG="$REPO_SLUG" \
  REQUIRE_DEV="$REQUIRE_DEV" \
  REQUIRE_STUDIO="$REQUIRE_STUDIO" \
  "$REPO_ROOT/scripts/infra/configure-github-authenticated-sso-canary.sh" \
  --repo "$REPO_SLUG" \
  $([[ "$ENABLE_RUNTIME_GATE" == "1" ]] && echo "--enable-runtime-gate")
