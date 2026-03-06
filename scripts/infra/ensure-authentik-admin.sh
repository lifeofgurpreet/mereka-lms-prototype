#!/usr/bin/env bash
# @covers AC-016
# @spec: auth-sso-enterprise_spec.md
# Ensure Authentik admin permissions are correct.
#
# Policy:
# - Gurpreet is the Authentik admin (is_superuser=True)
# - Malasari is NOT an Authentik admin (is_superuser=False)
#
# This is separate from Open edX "platform admin" permissions.
#
# Usage:
#   ./scripts/infra/ensure-authentik-admin.sh --verify
#   ./scripts/infra/ensure-authentik-admin.sh --apply

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
NAMESPACE="${NAMESPACE:-authentik}"
ALLOW_PROD_APPLY="${ALLOW_PROD_APPLY:-0}"
CREATE_PREOP_BACKUP="${CREATE_PREOP_BACKUP:-1}"
CONFIRM_ENSURE_AUTHENTIK_ADMIN="${CONFIRM_ENSURE_AUTHENTIK_ADMIN:-}"
CONFIRM_TOKEN="ENSURE_AUTHENTIK_ADMIN"

ADMIN_EMAIL="${ADMIN_EMAIL:-gurpreet@biji-biji.com}"
NON_ADMIN_EMAILS_CSV="${NON_ADMIN_EMAILS_CSV:-malasari@mereka.my}"

MODE="verify" # verify | apply

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

OPTIONS:
  --verify                  Verify only (default)
  --apply                   Apply changes (set superuser flags)
  --context K8S_CONTEXT     Kube context (default: $K8S_CONTEXT)
  --namespace NAMESPACE     Namespace (default: $NAMESPACE)
  --admin-email EMAIL       Authentik admin email (default: $ADMIN_EMAIL)
  --non-admin-emails CSV    Comma-separated emails that must NOT be superuser (default: $NON_ADMIN_EMAILS_CSV)
  -h, --help                Show help

Safety controls for --apply:
  CONFIRM_ENSURE_AUTHENTIK_ADMIN=ENSURE_AUTHENTIK_ADMIN
  ALLOW_PROD_APPLY=1        Required for prod-like contexts
  CREATE_PREOP_BACKUP=1     Default for prod-like contexts (Velero pre-op backup)
EOF
  exit 1
}

require_bool_01() {
  local var_name="$1"
  local value="$2"
  case "$value" in
    0|1) ;;
    *)
      echo "Invalid ${var_name}='${value}' (expected 0 or 1)" >&2
      exit 1
      ;;
  esac
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing command: $cmd" >&2
    exit 1
  }
}

is_prod_like_context() {
  local ctx="$1"
  [[ "$ctx" == *"gke_bbi-k8"* ]] || [[ "$ctx" == "prod" ]] || [[ "$ctx" == "production" ]] || [[ "$ctx" == "gke-prod" ]]
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verify) MODE="verify"; shift ;;
    --apply) MODE="apply"; shift ;;
    --context) K8S_CONTEXT="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --admin-email) ADMIN_EMAIL="$2"; shift 2 ;;
    --non-admin-emails) NON_ADMIN_EMAILS_CSV="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

require_bool_01 "ALLOW_PROD_APPLY" "$ALLOW_PROD_APPLY"
require_bool_01 "CREATE_PREOP_BACKUP" "$CREATE_PREOP_BACKUP"
require_cmd kubectl

if [[ "$MODE" == "apply" ]]; then
  if [[ "$CONFIRM_ENSURE_AUTHENTIK_ADMIN" != "$CONFIRM_TOKEN" ]]; then
    echo "Refusing --apply without explicit confirmation token. Set CONFIRM_ENSURE_AUTHENTIK_ADMIN=${CONFIRM_TOKEN}" >&2
    exit 1
  fi

  if is_prod_like_context "$K8S_CONTEXT" && [[ "$ALLOW_PROD_APPLY" != "1" ]]; then
    echo "Refusing --apply on prod-like context '$K8S_CONTEXT' without ALLOW_PROD_APPLY=1" >&2
    exit 1
  fi

  if is_prod_like_context "$K8S_CONTEXT"; then
    if [[ "$CREATE_PREOP_BACKUP" == "1" ]]; then
      require_cmd velero
      backup_name="pre-op-${NAMESPACE}-ensure-authentik-admin-$(date -u +%Y%m%d-%H%M)"
      echo "Creating Velero pre-op backup: $backup_name"
      velero backup create "$backup_name" --include-namespaces "$NAMESPACE" --wait
    else
      echo "WARNING: CREATE_PREOP_BACKUP=0 on prod-like context '$K8S_CONTEXT' (operator override)"
    fi
  fi
fi

echo "Mode: $MODE"
echo "Context: $K8S_CONTEXT"
echo "Namespace: $NAMESPACE"
echo "Admin: $ADMIN_EMAIL"
echo "Non-admins: $NON_ADMIN_EMAILS_CSV"
echo ""

kubectl --context "$K8S_CONTEXT" exec -n "$NAMESPACE" deploy/authentik-server -- \
  env MODE="$MODE" ADMIN_EMAIL="$ADMIN_EMAIL" NON_ADMIN_EMAILS_CSV="$NON_ADMIN_EMAILS_CSV" \
  ak shell -c '
from authentik.core.models import Group, User
import os

mode = os.environ.get("MODE", "verify")
admin_email = os.environ["ADMIN_EMAIL"].strip().lower()
non_admins = [e.strip().lower() for e in os.environ.get("NON_ADMIN_EMAILS_CSV", "").split(",") if e.strip()]

admin_group = Group.objects.filter(name="authentik Admins").first()
if not admin_group:
    raise SystemExit("Authentik admin group not found: authentik Admins")

def ensure(email: str, should_be_admin: bool):
    u = User.objects.filter(email=email).first()
    if not u:
        print(email, "MISSING")
        return

    current = admin_group in u.ak_groups.all()
    desired = should_be_admin
    if mode == "verify":
        print(email, "authentik_admin=" + str(current), "OK" if current == desired else "MISMATCH")
        return

    if current != desired:
        if desired:
            u.ak_groups.add(admin_group)
        else:
            u.ak_groups.remove(admin_group)
        print(email, "UPDATED", "authentik_admin=" + str(desired))
    else:
        print(email, "OK", "authentik_admin=" + str(current))

ensure(admin_email, True)
for e in non_admins:
    ensure(e, False)
'
