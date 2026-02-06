#!/usr/bin/env bash
set -euo pipefail

# Repairs kind-dev MySQL auth drift by aligning MySQL users to the current
# values in `secret/database-secrets`.
#
# Why needed:
# - MySQL persists credentials inside its PVC; changing K8s secrets does not
#   automatically rotate MySQL user passwords.
# - If GCP SM/ExternalSecrets values drift, LMS/CMS/ecommerce/etc can start
#   failing with MySQL 1045.
#
# This script is non-destructive (no DB drops). It only runs ALTER USER.

K8S_CONTEXT="${K8S_CONTEXT:-kind-dev}"
K8S_NAMESPACE="${K8S_NAMESPACE:-mereka-lms}"
GCP_PROJECT_ID="${GCP_PROJECT_ID:-bbi-k8}"

MYSQL_DEPLOYMENT="${MYSQL_DEPLOYMENT:-mysql}"
K8S_SECRET_NAME="${K8S_SECRET_NAME:-database-secrets}"

ROOT_SECRET_CANDIDATES=(
  "MEREKA_LMS_MYSQL_ROOT_PASSWORD_DEV"
  "MEREKA_LMS_MYSQL_ROOT_PASSWORD"
)

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}

get_k8s_secret_raw() {
  local key="$1"
  kubectl get secret "${K8S_SECRET_NAME}" \
    -n "${K8S_NAMESPACE}" \
    --context "${K8S_CONTEXT}" \
    -o jsonpath="{.data.${key}}" | base64 -d
}

strip_trailing_crlf() {
  python3 - <<'PY'
import sys
data = sys.stdin.buffer.read()
sys.stdout.buffer.write(data.rstrip(b"\r\n"))
PY
}

# Escape for single-quoted MySQL string literal.
escape_mysql_literal() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\'/\'\'}
  printf "%s" "$s"
}

mysql_exec_root() {
  local root_pw="$1"
  local sql="$2"
  kubectl exec -n "${K8S_NAMESPACE}" --context "${K8S_CONTEXT}" "deploy/${MYSQL_DEPLOYMENT}" -- \
    env MYSQL_PWD="${root_pw}" mysql -uroot -e "${sql}" >/dev/null
}

mysql_root_ok() {
  local root_pw="$1"
  kubectl exec -n "${K8S_NAMESPACE}" --context "${K8S_CONTEXT}" "deploy/${MYSQL_DEPLOYMENT}" -- \
    env MYSQL_PWD="${root_pw}" mysql -uroot -e "SELECT 1;" >/dev/null 2>&1
}

gcp_enabled_versions() {
  local secret="$1"
  gcloud secrets versions list "${secret}" \
    --project "${GCP_PROJECT_ID}" \
    --format="value(name,state)" 2>/dev/null \
    | awk '$2=="enabled"{print $1}' \
    | sort -nr
}

find_working_root_password() {
  local desired_root_pw="$1"

  # 1) Fast path: if DB already matches the current K8s secret, use it.
  if mysql_root_ok "${desired_root_pw}"; then
    echo "${desired_root_pw}"
    return 0
  fi

  # 2) Try known GCP SM secrets (enabled versions, latest-first).
  local secret v pw
  for secret in "${ROOT_SECRET_CANDIDATES[@]}"; do
    while read -r v; do
      [[ -n "${v}" ]] || continue
      pw="$(gcloud secrets versions access "${v}" --secret "${secret}" --project "${GCP_PROJECT_ID}" 2>/dev/null | strip_trailing_crlf)"
      if [[ -n "${pw}" ]] && mysql_root_ok "${pw}"; then
        echo "${pw}"
        return 0
      fi
    done < <(gcp_enabled_versions "${secret}" || true)
  done

  return 1
}

main() {
  need_cmd kubectl
  need_cmd gcloud
  need_cmd python3
  need_cmd base64

  log "Context=${K8S_CONTEXT} namespace=${K8S_NAMESPACE}"

  local desired_root_pw
  desired_root_pw="$(get_k8s_secret_raw MYSQL_ROOT_PASSWORD | strip_trailing_crlf)"
  [[ -n "${desired_root_pw}" ]] || { echo "database-secrets.MYSQL_ROOT_PASSWORD is empty" >&2; exit 1; }

  local root_pw
  if ! root_pw="$(find_working_root_password "${desired_root_pw}")"; then
    echo "Unable to authenticate as MySQL root (checked K8s secret and GCP SM candidates)." >&2
    exit 1
  fi

  # Align root to desired value (keeps drift low).
  if [[ "${root_pw}" != "${desired_root_pw}" ]]; then
    local desired_root_esc
    desired_root_esc="$(escape_mysql_literal "${desired_root_pw}")"
    mysql_exec_root "${root_pw}" "ALTER USER 'root'@'%' IDENTIFIED BY '${desired_root_esc}'; ALTER USER 'root'@'localhost' IDENTIFIED BY '${desired_root_esc}'; FLUSH PRIVILEGES;"
    root_pw="${desired_root_pw}"
  fi

  # Align service DB users.
  local openedx_pw discovery_pw ecommerce_pw notes_pw xqueue_pw credentials_pw
  openedx_pw="$(get_k8s_secret_raw OPENEDX_MYSQL_PASSWORD | strip_trailing_crlf)"
  discovery_pw="$(get_k8s_secret_raw MYSQL_DISCOVERY_PASSWORD | strip_trailing_crlf)"
  ecommerce_pw="$(get_k8s_secret_raw MYSQL_ECOMMERCE_PASSWORD | strip_trailing_crlf)"
  notes_pw="$(get_k8s_secret_raw MYSQL_NOTES_PASSWORD | strip_trailing_crlf)"
  xqueue_pw="$(get_k8s_secret_raw MYSQL_XQUEUE_PASSWORD | strip_trailing_crlf)"
  credentials_pw="$(get_k8s_secret_raw MYSQL_CREDENTIALS_PASSWORD | strip_trailing_crlf)"

  mysql_exec_root "${root_pw}" "ALTER USER 'openedx'@'%' IDENTIFIED BY '$(escape_mysql_literal "${openedx_pw}")';"
  mysql_exec_root "${root_pw}" "ALTER USER 'discovery'@'%' IDENTIFIED BY '$(escape_mysql_literal "${discovery_pw}")';"
  mysql_exec_root "${root_pw}" "ALTER USER 'ecommerce'@'%' IDENTIFIED BY '$(escape_mysql_literal "${ecommerce_pw}")';"
  mysql_exec_root "${root_pw}" "ALTER USER 'notes'@'%' IDENTIFIED BY '$(escape_mysql_literal "${notes_pw}")';"
  mysql_exec_root "${root_pw}" "ALTER USER 'xqueue'@'%' IDENTIFIED BY '$(escape_mysql_literal "${xqueue_pw}")';"
  mysql_exec_root "${root_pw}" "ALTER USER 'credentials'@'%' IDENTIFIED BY '$(escape_mysql_literal "${credentials_pw}")';"
  mysql_exec_root "${root_pw}" "FLUSH PRIVILEGES;"

  log "OK: MySQL users updated to match ${K8S_SECRET_NAME}"
}

main "$@"

