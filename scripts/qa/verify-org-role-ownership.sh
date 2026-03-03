#!/usr/bin/env bash
# @covers AC-017, AC-018
# @spec: multi-tenancy-architecture_spec.md
# Verify org-level role ownership for multisite governance.
#
# Checks per org:
# - org exists
# - at least one OrgStaffRole user
# - at least one OrgInstructorRole user
# - required platform admins have both roles
#
# Usage:
#   ./scripts/qa/verify-org-role-ownership.sh
#   ./scripts/qa/verify-org-role-ownership.sh prod
#   ./scripts/qa/verify-org-role-ownership.sh dev --context kind-dev
#   STRICT=0 ./scripts/qa/verify-org-role-ownership.sh both
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../shared/config.sh"

ENV_SCOPE="${1:-both}"
if [[ "$#" -gt 0 ]]; then
  shift
fi

if [[ "$ENV_SCOPE" != "prod" && "$ENV_SCOPE" != "dev" && "$ENV_SCOPE" != "both" ]]; then
  echo "Usage: $0 [prod|dev|both] [--context CONTEXT] [--namespace NS]" >&2
  exit 1
fi

NAMESPACE="${K8S_NAMESPACE:-mereka-lms}"
STRICT="${STRICT:-1}"
CTX_OVERRIDE=""

require_bool_01() {
  local var_name="$1"
  local value="$2"
  case "$value" in
    0|1) ;;
    *)
      echo "Invalid $var_name='$value' (expected 0 or 1)" >&2
      exit 1
      ;;
  esac
}

ADMINS_CSV_DEFAULT="gurpreet@biji-biji.com,malasari@mereka.my"
ADMINS_CSV="${ADMINS_CSV:-$ADMINS_CSV_DEFAULT}"
ORGS_CSV="${ORGS_CSV:-MEREKA,BIJIBIJI,SKILLOURFUTURE}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context)
      CTX_OVERRIDE="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

DEFAULT_PROD_CTX="gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster"
DEFAULT_DEV_CTX="kind-dev"
require_bool_01 "STRICT" "$STRICT"

run_target() {
  local env_name="$1"
  local ctx="${CTX_OVERRIDE:-}"
  if [[ -z "$ctx" ]]; then
    if [[ "$env_name" == "prod" ]]; then
      ctx="${K8S_CONTEXT:-$DEFAULT_PROD_CTX}"
    else
      ctx="${K8S_CONTEXT_DEV:-${K8S_CONTEXT:-$DEFAULT_DEV_CTX}}"
    fi
  fi

  echo "== ${env_name} (${ctx}) =="
  kubectl --context "$ctx" -n "$NAMESPACE" exec -i deploy/lms -- \
    env STRICT="$STRICT" ADMINS_CSV="$ADMINS_CSV" ORGS_CSV="$ORGS_CSV" python - <<'PY'
import os
import sys
import django

django.setup()

from django.contrib.auth import get_user_model
from organizations.models import Organization
from common.djangoapps.student.roles import OrgStaffRole, OrgInstructorRole

strict = os.environ.get("STRICT", "1") == "1"
admins = [x.strip() for x in os.environ.get("ADMINS_CSV", "").split(",") if x.strip()]
expected_orgs = [x.strip() for x in os.environ.get("ORGS_CSV", "").split(",") if x.strip()]
User = get_user_model()

failed = False
for org_code in expected_orgs:
    org_exists = Organization.objects.filter(short_name=org_code).exists()
    if not org_exists:
        print(f"{org_code}: ORG_MISSING")
        failed = True
        continue

    staff_role = OrgStaffRole(org=org_code)
    instructor_role = OrgInstructorRole(org=org_code)
    staff_users = list(staff_role.users_with_role())
    instructor_users = list(instructor_role.users_with_role())
    staff_emails = sorted({(u.email or u.username or "").strip() for u in staff_users if (u.email or u.username)})
    instructor_emails = sorted({(u.email or u.username or "").strip() for u in instructor_users if (u.email or u.username)})

    print(
        f"{org_code}: staff_count={len(staff_users)} instructor_count={len(instructor_users)} "
        f"staff={','.join(staff_emails) if staff_emails else 'none'} "
        f"instructor={','.join(instructor_emails) if instructor_emails else 'none'}"
    )

    if len(staff_users) < 1:
        print(f"{org_code}: ORG_STAFF_MISSING")
        failed = True
    if len(instructor_users) < 1:
        print(f"{org_code}: ORG_INSTRUCTOR_MISSING")
        failed = True

    for email in admins:
        user = User.objects.filter(email=email).first() or User.objects.filter(username=email).first()
        if not user:
            print(f"{org_code}: ADMIN_USER_MISSING email={email}")
            failed = True
            continue
        has_staff = any(u.id == user.id for u in staff_users)
        has_instructor = any(u.id == user.id for u in instructor_users)
        print(f"{org_code}: admin={email} staff={has_staff} instructor={has_instructor}")
        if not has_staff or not has_instructor:
            failed = True

if strict and failed:
    sys.exit(1)
PY
}

if [[ "$ENV_SCOPE" == "prod" || "$ENV_SCOPE" == "both" ]]; then
  run_target "prod"
fi
if [[ "$ENV_SCOPE" == "dev" || "$ENV_SCOPE" == "both" ]]; then
  run_target "dev"
fi
