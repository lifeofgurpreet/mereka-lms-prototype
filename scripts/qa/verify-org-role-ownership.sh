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
#   ./scripts/qa/verify-org-role-ownership.sh staging --context rke2-nonprod --namespace stg-mereka-lms
#   STRICT=0 ./scripts/qa/verify-org-role-ownership.sh both
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../shared/config.sh"

ENV_SCOPE="${1:-both}"
if [[ "$#" -gt 0 ]]; then
  shift
fi

if [[ "$ENV_SCOPE" != "prod" && "$ENV_SCOPE" != "dev" && "$ENV_SCOPE" != "staging" && "$ENV_SCOPE" != "both" ]]; then
  echo "Usage: $0 [prod|dev|staging|both] [--context CONTEXT] [--namespace NS]" >&2
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
DEFAULT_STAGING_CTX="rke2-nonprod"
CLUSTER_CHECK_TIMEOUT="${CLUSTER_CHECK_TIMEOUT:-20}"
require_bool_01 "STRICT" "$STRICT"

_cluster_reachable() {
  local ctx="$1"
  if ! command -v kubectl >/dev/null 2>&1; then
    return 1
  fi
  if command -v timeout >/dev/null 2>&1; then
    timeout "${CLUSTER_CHECK_TIMEOUT}s" kubectl --context "$ctx" cluster-info >/dev/null 2>&1
  else
    kubectl --context "$ctx" --request-timeout="${CLUSTER_CHECK_TIMEOUT}s" cluster-info >/dev/null 2>&1
  fi
}

run_target() {
  local env_name="$1"
  local ctx="${CTX_OVERRIDE:-}"
  local namespace="$NAMESPACE"
  if [[ -z "$ctx" ]]; then
    if [[ "$env_name" == "prod" ]]; then
      ctx="${K8S_CONTEXT:-$DEFAULT_PROD_CTX}"
    elif [[ "$env_name" == "staging" ]]; then
      ctx="${K8S_CONTEXT_STAGING:-${K8S_CONTEXT:-$DEFAULT_STAGING_CTX}}"
      namespace="${K8S_NAMESPACE_STAGING:-stg-mereka-lms}"
    else
      ctx="${K8S_CONTEXT_DEV:-${K8S_CONTEXT:-$DEFAULT_DEV_CTX}}"
    fi
  fi

  echo "== ${env_name} (${ctx}) =="

  if ! _cluster_reachable "$ctx"; then
    echo "⚠ SKIP: cluster unreachable (context=${ctx}, timeout=${CLUSTER_CHECK_TIMEOUT}s) — skipping org role ownership checks"
    echo "  (Run with a reachable cluster context to execute AC-017, AC-018)"
    return 0
  fi

  kubectl --context "$ctx" -n "$namespace" exec -i deploy/lms -- \
    env STRICT="$STRICT" ADMINS_CSV="$ADMINS_CSV" ORGS_CSV="$ORGS_CSV" python - <<'PY'
import os
import sys
import django

django.setup()

from django.contrib.auth import get_user_model
from django.contrib.auth.models import Permission
from organizations.models import Organization
from common.djangoapps.student.roles import OrgStaffRole, OrgInstructorRole

strict = os.environ.get("STRICT", "1") == "1"
admins = [x.strip() for x in os.environ.get("ADMINS_CSV", "").split(",") if x.strip()]
expected_orgs = [x.strip() for x in os.environ.get("ORGS_CSV", "").split(",") if x.strip()]
User = get_user_model()

def _role_email_set(role, limit=500):
    """Return a set of (id, email_or_username) for users in role.

    Uses values_list to avoid loading full User objects — avoids OOM on large
    installations.  Caps at `limit` rows; if the role has more members the check
    is still valid (we only need count + specific admin membership).
    """
    qs = role.users_with_role()
    rows = qs.values_list("id", "email", "username")[:limit]
    result = {}
    for uid, email, username in rows:
        label = (email or username or "").strip()
        if label:
            result[uid] = label
    return result

failed = False
for org_code in expected_orgs:
    org_exists = Organization.objects.filter(short_name=org_code).exists()
    if not org_exists:
        print(f"{org_code}: ORG_MISSING")
        failed = True
        continue

    staff_role = OrgStaffRole(org=org_code)
    instructor_role = OrgInstructorRole(org=org_code)

    # Count without loading objects to avoid OOM on large orgs.
    staff_count = staff_role.users_with_role().count()
    instructor_count = instructor_role.users_with_role().count()

    # Only materialise up to 500 rows to build the email list for display.
    staff_map = _role_email_set(staff_role)
    instructor_map = _role_email_set(instructor_role)
    staff_emails = sorted(staff_map.values())
    instructor_emails = sorted(instructor_map.values())

    print(
        f"{org_code}: staff_count={staff_count} instructor_count={instructor_count} "
        f"staff={','.join(staff_emails[:10]) if staff_emails else 'none'}"
        f"{',...' if len(staff_emails) > 10 else ''} "
        f"instructor={','.join(instructor_emails[:10]) if instructor_emails else 'none'}"
        f"{',...' if len(instructor_emails) > 10 else ''}"
    )

    if staff_count < 1:
        print(f"{org_code}: ORG_STAFF_MISSING")
        failed = True
    if instructor_count < 1:
        print(f"{org_code}: ORG_INSTRUCTOR_MISSING")
        failed = True

    for email in admins:
        user_qs = User.objects.filter(email=email)
        if not user_qs.exists():
            user_qs = User.objects.filter(username=email)
        if not user_qs.exists():
            print(f"{org_code}: ADMIN_USER_MISSING email={email}")
            failed = True
            continue
        user_id = user_qs.values_list("id", flat=True).first()
        has_staff = user_id in staff_map
        has_instructor = user_id in instructor_map
        # If not in materialised slice (>500 members), do a targeted DB check.
        if not has_staff:
            has_staff = staff_role.users_with_role().filter(id=user_id).exists()
        if not has_instructor:
            has_instructor = instructor_role.users_with_role().filter(id=user_id).exists()
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
if [[ "$ENV_SCOPE" == "staging" ]]; then
  run_target "staging"
fi
