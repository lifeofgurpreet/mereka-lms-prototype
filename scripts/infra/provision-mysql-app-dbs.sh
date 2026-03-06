#!/usr/bin/env bash
set -euo pipefail

# Provision missing MySQL databases/users for optional Open edX services.
#
# Why:
# - Notes and XQueue run as standalone Django services and expect their own
#   databases/users (`notes`, `xqueue`).
# - In-cluster MySQL initialization can miss these, leaving the services "up"
#   but failing once they actually hit the DB.
# - Secrets from ExternalSecrets often contain a trailing newline; we strip CR/LF
#   when reading them, and we always set MySQL users to the stripped value.
#
# Safety:
# - Non-destructive: no DROP/TRUNCATE/DELETE.
# - Idempotent: CREATE DATABASE/USER IF NOT EXISTS; ALTER USER sets password.
# - Live execution requires explicit confirmation token.
# - Prod-like contexts require explicit ALLOW_PROD_APPLY=1 and default to Velero pre-op backup.

K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
K8S_NAMESPACE="${K8S_NAMESPACE:-mereka-lms}"
MYSQL_DEPLOYMENT="${MYSQL_DEPLOYMENT:-mysql}"
K8S_SECRET_NAME="${K8S_SECRET_NAME:-database-secrets}"
ALLOW_PROD_APPLY="${ALLOW_PROD_APPLY:-0}"
CREATE_PREOP_BACKUP="${CREATE_PREOP_BACKUP:-1}"
CONFIRM_PROVISION_MYSQL_APP_DBS="${CONFIRM_PROVISION_MYSQL_APP_DBS:-}"
CONFIRM_TOKEN="PROVISION_MYSQL_APP_DBS"

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
die() { echo "$*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

require_bool_01() {
  local var_name="$1"
  local value="$2"
  case "$value" in
    0|1) ;;
    *) die "Invalid ${var_name}='${value}' (expected 0 or 1)" ;;
  esac
}

is_prod_like_context() {
  local ctx="$1"
  [[ "$ctx" == *"gke_bbi-k8"* ]] || [[ "$ctx" == "prod" ]] || [[ "$ctx" == "production" ]] || [[ "$ctx" == "gke-prod" ]]
}

strip_trailing_crlf() {
  python3 -c 'import sys; data=sys.stdin.buffer.read(); sys.stdout.buffer.write(data.rstrip(b"\r\n"))'
}

get_k8s_secret_raw() {
  local key="$1"
  kubectl get secret "${K8S_SECRET_NAME}" \
    -n "${K8S_NAMESPACE}" \
    --context "${K8S_CONTEXT}" \
    -o jsonpath="{.data.${key}}" | base64 -d
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

# Escape for single-quoted MySQL string literal.
escape_mysql_literal() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\'/\'\'}
  printf "%s" "$s"
}

main() {
  need_cmd kubectl
  need_cmd python3
  need_cmd base64
  require_bool_01 "ALLOW_PROD_APPLY" "$ALLOW_PROD_APPLY"
  require_bool_01 "CREATE_PREOP_BACKUP" "$CREATE_PREOP_BACKUP"

  if [[ "$CONFIRM_PROVISION_MYSQL_APP_DBS" != "$CONFIRM_TOKEN" ]]; then
    die "Refusing live mutation without explicit confirmation token. Set CONFIRM_PROVISION_MYSQL_APP_DBS=${CONFIRM_TOKEN}"
  fi

  if is_prod_like_context "$K8S_CONTEXT" && [[ "$ALLOW_PROD_APPLY" != "1" ]]; then
    die "Refusing live mutation on prod-like context '$K8S_CONTEXT' without ALLOW_PROD_APPLY=1"
  fi

  if is_prod_like_context "$K8S_CONTEXT"; then
    if [[ "$CREATE_PREOP_BACKUP" == "1" ]]; then
      need_cmd velero
      backup_name="pre-op-${K8S_NAMESPACE}-provision-mysql-app-dbs-$(date -u +%Y%m%d-%H%M)"
      log "Creating Velero pre-op backup: $backup_name"
      velero backup create "$backup_name" --include-namespaces "$K8S_NAMESPACE" --wait
    else
      log "WARNING: CREATE_PREOP_BACKUP=0 on prod-like context '$K8S_CONTEXT' (operator override)"
    fi
  fi

  log "Context=${K8S_CONTEXT} namespace=${K8S_NAMESPACE}"

  local root_pw
  root_pw="$(get_k8s_secret_raw MYSQL_ROOT_PASSWORD | strip_trailing_crlf)"
  [[ -n "${root_pw}" ]] || die "${K8S_SECRET_NAME}.MYSQL_ROOT_PASSWORD is empty"

  if ! mysql_root_ok "${root_pw}"; then
    die "Unable to authenticate as MySQL root using ${K8S_SECRET_NAME}.MYSQL_ROOT_PASSWORD (after CR/LF stripping)."
  fi

  local notes_pw xqueue_pw
  notes_pw="$(get_k8s_secret_raw MYSQL_NOTES_PASSWORD | strip_trailing_crlf || true)"
  xqueue_pw="$(get_k8s_secret_raw MYSQL_XQUEUE_PASSWORD | strip_trailing_crlf || true)"
  [[ -n "${notes_pw}" ]] || die "${K8S_SECRET_NAME}.MYSQL_NOTES_PASSWORD is empty"
  [[ -n "${xqueue_pw}" ]] || die "${K8S_SECRET_NAME}.MYSQL_XQUEUE_PASSWORD is empty"

  # Databases
  log "Ensuring databases exist..."
  mysql_exec_root "${root_pw}" "CREATE DATABASE IF NOT EXISTS notes CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  mysql_exec_root "${root_pw}" "CREATE DATABASE IF NOT EXISTS xqueue CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

  # Users + grants (idempotent)
  log "Ensuring users exist + have correct passwords..."
  mysql_exec_root "${root_pw}" "CREATE USER IF NOT EXISTS 'notes'@'%' IDENTIFIED BY '$(escape_mysql_literal "${notes_pw}")';"
  mysql_exec_root "${root_pw}" "ALTER USER 'notes'@'%' IDENTIFIED BY '$(escape_mysql_literal "${notes_pw}")';"
  mysql_exec_root "${root_pw}" "GRANT ALL PRIVILEGES ON notes.* TO 'notes'@'%';"

  mysql_exec_root "${root_pw}" "CREATE USER IF NOT EXISTS 'xqueue'@'%' IDENTIFIED BY '$(escape_mysql_literal "${xqueue_pw}")';"
  mysql_exec_root "${root_pw}" "ALTER USER 'xqueue'@'%' IDENTIFIED BY '$(escape_mysql_literal "${xqueue_pw}")';"
  mysql_exec_root "${root_pw}" "GRANT ALL PRIVILEGES ON xqueue.* TO 'xqueue'@'%';"

  mysql_exec_root "${root_pw}" "FLUSH PRIVILEGES;"

  log "OK: notes/xqueue databases + users are provisioned."
}

main "$@"
