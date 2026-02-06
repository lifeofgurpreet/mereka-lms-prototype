#!/usr/bin/env bash
# Sync Infisical secrets -> GCP Secret Manager for ExternalSecrets.
#
# Why this exists:
# - K8s ExternalSecrets reads from GCP Secret Manager (ClusterSecretStore projectID=bbi-k8).
# - Infisical is the source of truth, but without an automated bridge, secrets can drift/miss.
# - This script restores/creates the required Secret Manager entries based on
#   deploy/k8s/base/secrets/external-secrets.yaml.
#
# Safety:
# - Does not print secret values.
# - Writes new *versions* for existing secrets.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

GCP_PROJECT_ID="${GCP_PROJECT_ID:-bbi-k8}"
INFISICAL_DOMAIN="${INFISICAL_DOMAIN:-https://secrets.mereka.io/api}"
INFISICAL_PATH="${INFISICAL_PATH:-/k8s/mereka-lms}"
INFISICAL_DIR="${INFISICAL_DIR:-}"
INFISICAL_PROJECT_ID="${INFISICAL_PROJECT_ID:-}"
EXTERNAL_SECRETS_FILE="${EXTERNAL_SECRETS_FILE:-${REPO_ROOT}/deploy/k8s/base/secrets/external-secrets.yaml}"

# Safety: by default, only Stripe keys are allowed to overwrite existing GCP SM
# secrets. Everything else is "create-if-missing" to avoid clobbering live DB
# passwords or auth credentials.
OVERWRITE_ALLOWED_REGEX="${OVERWRITE_ALLOWED_REGEX:-^MEREKA_LMS_STRIPE_(SECRET_KEY|PUBLISHABLE_KEY|WEBHOOK_SECRET)(_DEV)?$|^MEREKA_LMS_MYSQL_(ROOT_PASSWORD|PASSWORD|DISCOVERY_PASSWORD|ECOMMERCE_PASSWORD|NOTES_PASSWORD|XQUEUE_PASSWORD|CREDENTIALS_PASSWORD)_DEV$}"

# Opt-in: allow overwriting MongoDB Atlas connection secrets.
# This is intentionally off by default because it affects forum + modulestore.
if [[ "${ALLOW_OVERWRITE_MONGODB_KEYS:-0}" == "1" ]]; then
  OVERWRITE_ALLOWED_REGEX="${OVERWRITE_ALLOWED_REGEX}|^MEREKA_LMS_(FORUM_MONGODB_SRV|MONGODB_USERNAME|MONGODB_PASSWORD)$"
fi

# Infisical CLI prints a trailing newline by default. If we pipe that directly
# into Secret Manager, K8s env vars may include a newline and break auth (e.g.,
# MySQL passwords). We normalize by stripping trailing CR/LF bytes only.
normalize_value_file() {
  local src="$1"
  local dst="$2"
  python3 - "$src" "$dst" <<'PY'
import pathlib
import sys

src = pathlib.Path(sys.argv[1])
dst = pathlib.Path(sys.argv[2])
data = src.read_bytes()
data = data.rstrip(b"\r\n")
dst.write_bytes(data)
PY
}

# Some secrets must differ between prod and dev (notably Stripe).
# The production ExternalSecret references MEREKA_LMS_* keys.
# The dev(kind) overlay should reference *_DEV keys, populated from Infisical dev env.
DEV_SUFFIX_KEYS=(
  "MEREKA_LMS_STRIPE_SECRET_KEY"
  "MEREKA_LMS_STRIPE_PUBLISHABLE_KEY"
  "MEREKA_LMS_STRIPE_WEBHOOK_SECRET"
  # MySQL credentials drift frequently in kind dev because MySQL persists passwords
  # in its PVC. We keep prod stable and use *_DEV keys for kind.
  "MEREKA_LMS_MYSQL_ROOT_PASSWORD"
  "MEREKA_LMS_MYSQL_PASSWORD"
  "MEREKA_LMS_MYSQL_DISCOVERY_PASSWORD"
  "MEREKA_LMS_MYSQL_ECOMMERCE_PASSWORD"
  "MEREKA_LMS_MYSQL_NOTES_PASSWORD"
  "MEREKA_LMS_MYSQL_XQUEUE_PASSWORD"
  "MEREKA_LMS_MYSQL_CREDENTIALS_PASSWORD"
)

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

die() { echo "$*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

resolve_infisical_dir() {
  if [[ -n "${INFISICAL_DIR:-}" ]]; then
    return
  fi
  local candidates=(
    "/home/gurpreet/projects/secrets-management"
    "${REPO_ROOT}"
  )
  for candidate in "${candidates[@]}"; do
    if [[ -f "${candidate}/.infisical.json" ]]; then
      INFISICAL_DIR="$candidate"
      return
    fi
  done

  # Infisical CLI can run without a repo-local .infisical.json when the user has
  # already authenticated globally (e.g., on a VPS). Fall back to repo root.
  INFISICAL_DIR="${REPO_ROOT}"
}

infer_infisical_project_id_from_backup() {
  local backup_dir="${INFISICAL_BACKUP_DIR:-$HOME/.infisical/secrets-backup}"
  local candidate=""
  if [[ -d "$backup_dir" ]]; then
    candidate=$(ls "$backup_dir"/project_secrets_* 2>/dev/null | head -n 1 || true)
  fi
  if [[ -n "$candidate" ]]; then
    basename "$candidate" | sed -E 's/^project_secrets_([^_]+)_.*/\1/'
  fi
}

resolve_infisical_project_id() {
  if [[ -n "${INFISICAL_PROJECT_ID:-}" ]]; then
    return
  fi

  # If a local .infisical.json exists, we can often run without --projectId,
  # but explicitly setting it makes the script work even when that file isn't present.
  if [[ -r "${INFISICAL_DIR}/.infisical.json" ]]; then
    INFISICAL_PROJECT_ID="$(python3 - "${INFISICAL_DIR}/.infisical.json" <<'PY'
import json
import sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        obj = json.load(f)
    print(obj.get("workspaceId") or "")
except Exception:
    print("")
PY
)"
  fi

  if [[ -z "${INFISICAL_PROJECT_ID:-}" ]]; then
    INFISICAL_PROJECT_ID="$(infer_infisical_project_id_from_backup || true)"
  fi
}

fetch_infisical_plain() {
  local env="$1"
  local key="$2"
  local args=()
  if [[ -n "${INFISICAL_PROJECT_ID:-}" ]]; then
    args+=(--projectId "${INFISICAL_PROJECT_ID}")
  fi
  (cd "${INFISICAL_DIR}" && infisical secrets get "${key}" \
    --domain "${INFISICAL_DOMAIN}" \
    --env "${env}" \
    --path "${INFISICAL_PATH}" \
    "${args[@]}" \
    --plain 2>/dev/null) || return 1
}

ensure_gcp_secret_version() {
  local secret_name="$1"
  local value_file="$2"
  local normalized

  normalized="$(mktemp)"
  normalize_value_file "${value_file}" "${normalized}"

  if gcloud secrets describe "${secret_name}" --project "${GCP_PROJECT_ID}" >/dev/null 2>&1; then
    if [[ "${secret_name}" =~ ${OVERWRITE_ALLOWED_REGEX} ]]; then
      gcloud secrets versions add "${secret_name}" \
        --project "${GCP_PROJECT_ID}" \
        --data-file="${normalized}" \
        --quiet >/dev/null
      echo "  ✓ ${secret_name} (updated)"
    else
      echo "  - ${secret_name} (exists; skipped)"
    fi
    rm -f "${normalized}"
    return
  fi

  gcloud secrets create "${secret_name}" \
    --project "${GCP_PROJECT_ID}" \
    --replication-policy="automatic" \
    --data-file="${normalized}" \
    --quiet >/dev/null
  echo "  ✓ ${secret_name} (created)"
  rm -f "${normalized}"
}

main() {
  need_cmd rg
  need_cmd gcloud
  need_cmd infisical

  if [[ ! -f "${EXTERNAL_SECRETS_FILE}" ]]; then
    die "Missing ${EXTERNAL_SECRETS_FILE}"
  fi

  resolve_infisical_dir
  [[ -n "${INFISICAL_DIR:-}" ]] || die "INFISICAL_DIR resolution failed"
  resolve_infisical_project_id

  log "GCP project: ${GCP_PROJECT_ID}"
  if [[ -f "${INFISICAL_DIR}/.infisical.json" ]]; then
    log "Infisical config: ${INFISICAL_DIR}/.infisical.json"
  else
    log "Infisical config: (global auth; no .infisical.json found)"
  fi
  if [[ -n "${INFISICAL_PROJECT_ID:-}" ]]; then
    log "Infisical projectId: ${INFISICAL_PROJECT_ID}"
  fi
  log "Infisical path: ${INFISICAL_PATH}"

  mapfile -t keys < <(rg -o "key:\\s*(MEREKA_LMS_[A-Z0-9_]+)" "${EXTERNAL_SECRETS_FILE}" | awk '{print $2}' | sort -u)
  if [[ "${#keys[@]}" -eq 0 ]]; then
    die "No keys found in ${EXTERNAL_SECRETS_FILE}"
  fi

  log "Syncing ${#keys[@]} secrets from Infisical prod -> GCP Secret Manager..."

  # NOTE: keep this variable global so the EXIT trap can always see it.
  tmp="$(mktemp)"
  trap 'rm -f "${tmp:-}"' EXIT

  local missing=0
  for key in "${keys[@]}"; do
    if ! fetch_infisical_plain prod "${key}" >"${tmp}"; then
      echo "  ✗ ${key} missing in Infisical prod (${INFISICAL_PATH})" >&2
      missing=$((missing + 1))
      continue
    fi
    if [[ ! -s "${tmp}" ]]; then
      echo "  ✗ ${key} empty in Infisical prod" >&2
      missing=$((missing + 1))
      continue
    fi
    ensure_gcp_secret_version "${key}" "${tmp}"
  done

  log "Syncing dev-only overrides (Stripe) from Infisical dev -> GCP Secret Manager..."
  for key in "${DEV_SUFFIX_KEYS[@]}"; do
    local dev_key="${key}_DEV"
    if ! fetch_infisical_plain dev "${key}" >"${tmp}"; then
      echo "  ✗ ${key} missing in Infisical dev (${INFISICAL_PATH})" >&2
      missing=$((missing + 1))
      continue
    fi
    if [[ ! -s "${tmp}" ]]; then
      echo "  ✗ ${key} empty in Infisical dev" >&2
      missing=$((missing + 1))
      continue
    fi
    ensure_gcp_secret_version "${dev_key}" "${tmp}"
  done

  if [[ $missing -gt 0 ]]; then
    die "Sync incomplete: ${missing} missing/empty secrets"
  fi

  log "Done. You can now force ExternalSecret sync with:"
  log "  kubectl annotate externalsecret openedx-secrets -n mereka-lms force-sync=\"$(date +%s)\" --overwrite"
}

main "$@"
