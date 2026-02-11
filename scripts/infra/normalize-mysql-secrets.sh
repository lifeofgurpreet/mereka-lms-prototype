#!/usr/bin/env bash
# @covers AC-006
# @spec: secrets-management_spec.md
set -euo pipefail

# Normalize trailing CR/LF for MySQL password secrets across:
# - Infisical (source of truth)
# - GCP Secret Manager (ESO reads from here)
# - K8s Secret (ESO target)
#
# IMPORTANT:
# - This script never prints secret values.
# - It only strips trailing \r/\n bytes; it does NOT otherwise mutate secrets.
# - Existing pods will NOT pick up secret changes until they restart. This is
#   intended to make future restarts safe and remove drift.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

APPLY="${APPLY:-0}"

K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
K8S_NAMESPACE="${K8S_NAMESPACE:-mereka-lms}"
K8S_SECRET_NAME="${K8S_SECRET_NAME:-database-secrets}"
K8S_EXTERNALSECRET_NAME="${K8S_EXTERNALSECRET_NAME:-database-secrets}"

GCP_PROJECT_ID="${GCP_PROJECT_ID:-bbi-k8}"

INFISICAL_DOMAIN="${INFISICAL_DOMAIN:-https://secrets.mereka.io/api}"
INFISICAL_ENV="${INFISICAL_ENV:-prod}"
INFISICAL_PATH="${INFISICAL_PATH:-/k8s/mereka-lms}"
INFISICAL_DIR="${INFISICAL_DIR:-}"
INFISICAL_PROJECT_ID="${INFISICAL_PROJECT_ID:-}"

MYSQL_SECRET_KEYS=(
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
  INFISICAL_DIR="${REPO_ROOT}"
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

resolve_infisical_project_id() {
  if [[ -n "${INFISICAL_PROJECT_ID:-}" ]]; then
    return
  fi

  local cfg="${INFISICAL_DIR}/.infisical.json"
  if [[ -f "$cfg" ]]; then
    INFISICAL_PROJECT_ID="$(jq -r '.workspaceId // empty' "$cfg" || true)"
  fi
  if [[ -z "${INFISICAL_PROJECT_ID:-}" ]]; then
    INFISICAL_PROJECT_ID="$(infer_project_id_from_backup || true)"
  fi
  [[ -n "${INFISICAL_PROJECT_ID:-}" ]] || die "Unable to infer INFISICAL_PROJECT_ID (set INFISICAL_PROJECT_ID=... and retry)"
}

strip_trailing_crlf_file() {
  local src="$1"
  local dst="$2"
  python3 - "$src" "$dst" <<'PY'
import pathlib
import sys

src = pathlib.Path(sys.argv[1])
dst = pathlib.Path(sys.argv[2])
data = src.read_bytes()
dst.write_bytes(data.rstrip(b"\r\n"))
PY
}

file_has_trailing_crlf() {
  local path="$1"
  python3 - "$path" <<'PY'
import pathlib
import sys

p = pathlib.Path(sys.argv[1])
data = p.read_bytes() if p.exists() else b""
sys.stdout.write("1" if (data.endswith(b"\n") or data.endswith(b"\r")) else "0")
PY
}

fetch_infisical_to_file() {
  local key="$1"
  local out="$2"
  (cd "${INFISICAL_DIR}" && infisical secrets get "${key}" \
    --domain "${INFISICAL_DOMAIN}" \
    --env "${INFISICAL_ENV}" \
    --path "${INFISICAL_PATH}" \
    --projectId "${INFISICAL_PROJECT_ID}" \
    --plain --silent > "${out}" 2>/dev/null) || return 1
}

set_infisical_from_file() {
  local key="$1"
  local file="$2"
  (cd "${INFISICAL_DIR}" && infisical secrets set "${key}=@${file}" \
    --domain "${INFISICAL_DOMAIN}" \
    --env "${INFISICAL_ENV}" \
    --path "${INFISICAL_PATH}" \
    --projectId "${INFISICAL_PROJECT_ID}" \
    --silent >/dev/null 2>&1) || return 1
}

fetch_gcp_to_file() {
  local key="$1"
  local out="$2"
  gcloud secrets versions access latest \
    --secret "${key}" \
    --project "${GCP_PROJECT_ID}" > "${out}"
}

add_gcp_version_from_file() {
  local key="$1"
  local file="$2"
  gcloud secrets versions add "${key}" \
    --project "${GCP_PROJECT_ID}" \
    --data-file="${file}" \
    --quiet >/dev/null
}

force_es_sync() {
  local anno="force-sync=$(date +%s)"
  kubectl --context "${K8S_CONTEXT}" -n "${K8S_NAMESPACE}" annotate externalsecret "${K8S_EXTERNALSECRET_NAME}" "${anno}" --overwrite >/dev/null
}

check_k8s_secret_trailing() {
  local key="$1"
  # Print 1 if decoded secret ends with CR/LF.
  kubectl --context "${K8S_CONTEXT}" -n "${K8S_NAMESPACE}" get secret "${K8S_SECRET_NAME}" -o "jsonpath={.data.${key}}" \
    | base64 -d \
    | python3 -c 'import sys; data=sys.stdin.buffer.read(); sys.stdout.write("1" if (data.endswith(b"\n") or data.endswith(b"\r")) else "0")'
}

main() {
  need_cmd infisical
  need_cmd gcloud
  need_cmd kubectl
  need_cmd jq
  need_cmd python3
  need_cmd base64

  resolve_infisical_dir
  resolve_infisical_project_id

  log "Mode: $( [[ \"$APPLY\" == \"1\" ]] && echo apply || echo plan )"
  log "Infisical: env=${INFISICAL_ENV} path=${INFISICAL_PATH}"
  log "GCP SM: project=${GCP_PROJECT_ID}"
  log "K8s: context=${K8S_CONTEXT} ns=${K8S_NAMESPACE} secret=${K8S_SECRET_NAME}"

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir:-}"' EXIT

  local changed=0

  for gcp_key in "${MYSQL_SECRET_KEYS[@]}"; do
    local k8s_key="${gcp_key#MEREKA_LMS_}"
    # Map to ExternalSecret target keys:
    # MEREKA_LMS_MYSQL_PASSWORD -> OPENEDX_MYSQL_PASSWORD, others are 1:1 sans prefix.
    if [[ "$gcp_key" == "MEREKA_LMS_MYSQL_PASSWORD" ]]; then
      k8s_key="OPENEDX_MYSQL_PASSWORD"
    fi

    log "Checking ${gcp_key}..."

    local inf_raw="${tmpdir}/${gcp_key}.inf.raw"
    local inf_norm="${tmpdir}/${gcp_key}.inf.norm"
    local gcp_raw="${tmpdir}/${gcp_key}.gcp.raw"
    local gcp_norm="${tmpdir}/${gcp_key}.gcp.norm"

    if ! fetch_infisical_to_file "${gcp_key}" "${inf_raw}"; then
      echo "  - Infisical: missing (skip)" >&2
      continue
    fi
    strip_trailing_crlf_file "${inf_raw}" "${inf_norm}"

    local inf_has
    inf_has="$(file_has_trailing_crlf "${inf_raw}")"
    if [[ "$inf_has" == "1" ]]; then
      echo "  - Infisical: trailing CR/LF present"
      if [[ "$APPLY" == "1" ]]; then
        set_infisical_from_file "${gcp_key}" "${inf_norm}"
        echo "    -> Infisical updated (CR/LF stripped)"
        changed=1
      fi
    else
      echo "  - Infisical: OK"
    fi

    fetch_gcp_to_file "${gcp_key}" "${gcp_raw}"
    strip_trailing_crlf_file "${gcp_raw}" "${gcp_norm}"

    local gcp_has
    gcp_has="$(file_has_trailing_crlf "${gcp_raw}")"
    if [[ "$gcp_has" == "1" ]]; then
      echo "  - GCP SM: trailing CR/LF present"
      if [[ "$APPLY" == "1" ]]; then
        add_gcp_version_from_file "${gcp_key}" "${gcp_norm}"
        echo "    -> GCP SM new version added (CR/LF stripped)"
        changed=1
      fi
    else
      echo "  - GCP SM: OK"
    fi

    local k8s_has="0"
    if kubectl --context "${K8S_CONTEXT}" -n "${K8S_NAMESPACE}" get secret "${K8S_SECRET_NAME}" >/dev/null 2>&1; then
      k8s_has="$(check_k8s_secret_trailing "${k8s_key}" || echo 0)"
    fi
    if [[ "$k8s_has" == "1" ]]; then
      echo "  - K8s: trailing CR/LF present (${K8S_SECRET_NAME}.${k8s_key})"
    else
      echo "  - K8s: OK (${K8S_SECRET_NAME}.${k8s_key})"
    fi
  done

  if [[ "$APPLY" == "1" && "$changed" == "1" ]]; then
    log "Forcing ExternalSecret refresh (${K8S_EXTERNALSECRET_NAME})..."
    force_es_sync
    log "Done. Note: running pods keep old env vars until restart."
  fi
}

main "$@"
