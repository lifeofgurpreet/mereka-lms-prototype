#!/usr/bin/env bash
# @covers AC-006
# @spec: secrets-management_spec.md
set -euo pipefail

ENVIRONMENT="${1:-prod}"
SRC_PATH="${SRC_PATH:-/}"
DEST_PATH="${DEST_PATH:-/k8s/mereka-lms}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$REPO_ROOT/../.." && pwd)}"
INFISICAL_DIR="${INFISICAL_DIR:-}"
INFISICAL_DOMAIN="${INFISICAL_DOMAIN:-https://secrets.mereka.io/api}"
INFISICAL_PROJECT_ID="${INFISICAL_PROJECT_ID:-}"
EXTERNAL_SECRETS_FILE="${EXTERNAL_SECRETS_FILE:-${REPO_ROOT}/deploy/k8s/base/secrets/external-secrets.yaml}"

if [[ ! -f "$EXTERNAL_SECRETS_FILE" ]]; then
  echo "Missing external-secrets file: $EXTERNAL_SECRETS_FILE" >&2
  exit 1
fi

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
      break
    fi
  done
}

resolve_infisical_dir

if [[ -z "${INFISICAL_DIR:-}" || ! -d "$INFISICAL_DIR" ]]; then
  # Infisical CLI can operate with global auth (no repo-local .infisical.json).
  INFISICAL_DIR="$REPO_ROOT"
fi

if ! command -v infisical >/dev/null 2>&1; then
  echo "infisical CLI not found" >&2
  exit 1
fi

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

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

if [[ -z "$INFISICAL_PROJECT_ID" ]]; then
  INFISICAL_PROJECT_ID=$(infer_project_id_from_backup || true)
fi
if [[ -z "$INFISICAL_PROJECT_ID" ]]; then
  echo "Unable to determine Infisical projectId. Set INFISICAL_PROJECT_ID and retry." >&2
  exit 1
fi

if [[ -f "${INFISICAL_DIR}/.infisical.json" ]]; then
  log "Infisical config: ${INFISICAL_DIR}/.infisical.json"
else
  log "Infisical config: (global auth; no .infisical.json found)"
fi
log "Syncing MEREKA_LMS secrets from ${SRC_PATH} -> ${DEST_PATH} (env=${ENVIRONMENT})"

mapfile -t keys < <(rg -o "MEREKA_LMS_[A-Z0-9_]+" "$EXTERNAL_SECRETS_FILE" | sort -u)

missing=0
synced=0

for key in "${keys[@]}"; do
  tmpfile=$(mktemp)
  if (cd "$INFISICAL_DIR" && infisical secrets get "$key" \
      --domain "$INFISICAL_DOMAIN" \
      --env "$ENVIRONMENT" \
      --path "$SRC_PATH" \
      --projectId "$INFISICAL_PROJECT_ID" \
      --recursive \
      --plain 2>/dev/null > "$tmpfile"); then
    if [[ -s "$tmpfile" ]]; then
      (cd "$INFISICAL_DIR" && infisical secrets set "${key}=@${tmpfile}" \
        --domain "$INFISICAL_DOMAIN" \
        --env "$ENVIRONMENT" \
        --path "$DEST_PATH" \
        --projectId "$INFISICAL_PROJECT_ID" \
        --silent >/dev/null)
      printf "  ✓ %s\n" "$key"
      synced=$((synced + 1))
    else
      printf "  ✗ %s (empty)\n" "$key" >&2
      missing=$((missing + 1))
    fi
  else
    printf "  ✗ %s (missing in %s)\n" "$key" "$SRC_PATH" >&2
    missing=$((missing + 1))
  fi
  rm -f "$tmpfile"
done

log "Synced ${synced} secrets. Missing/empty: ${missing}."
if [[ $missing -gt 0 ]]; then
  exit 1
fi
