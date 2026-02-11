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
EOF
  exit 1
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
