#!/usr/bin/env bash
# Ensure platform admins exist and have full permissions across the Open edX ecosystem.
#
# What this enforces (idempotent):
# - LMS user: is_active, is_staff, is_superuser
# - LMS org-level roles: OrgStaff + OrgInstructor for every active org
# - CMS Studio course creation: CourseCreator(state=granted, all_organizations=True)
# - Discovery / Credentials / Ecommerce: is_active, is_staff, is_superuser
#
# Notes:
# - This does NOT set or reset passwords. For services like Discovery/Credentials/Ecommerce,
#   access admin by logging in via their SSO endpoint first: /login/ -> /login/edx-oauth2/,
#   then visit /admin/.
# - Authentik controls authentication; Open edX controls authorization. These flags do not
#   "sync" from Authentik by default.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

NAMESPACE="${NAMESPACE:-${K8S_NAMESPACE:-mereka-lms}}"

# Default: enforce on both production (GKE) and dev (kind).
DEFAULT_CONTEXTS=(
  "gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster"
  "kind-dev"
)

ADMINS_CSV_DEFAULT="gurpreet@biji-biji.com,malasari@mereka.my"
ADMINS_CSV="${ADMINS_CSV:-$ADMINS_CSV_DEFAULT}"

CONTEXTS=()
MODE="apply" # apply | verify

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Ensures Gurpreet + Malasari have full permissions across:
  - LMS/CMS (Open edX)
  - LMS org-level ownership roles (OrgStaff + OrgInstructor)
  - Discovery
  - Credentials
  - Ecommerce

OPTIONS:
  -n, --namespace NAMESPACE   K8s namespace (default: $NAMESPACE)
  -c, --context CONTEXT       Kube context to target (repeatable). If omitted, uses:
                              ${DEFAULT_CONTEXTS[*]}
  --admins CSV                Comma-separated admin emails (default: $ADMINS_CSV_DEFAULT)
  --verify                     Verification only (no writes)
  -h, --help                   Show this help

EXAMPLES:
  # Apply on both prod + dev (default)
  $0

  # Verify only on prod
  $0 --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster --verify

  # Apply for a custom admin list on dev only
  ADMINS_CSV="a@example.com,b@example.com" $0 --context kind-dev
EOF
  exit 1
}

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    -c|--context)
      CONTEXTS+=("$2")
      shift 2
      ;;
    --admins)
      ADMINS_CSV="$2"
      shift 2
      ;;
    --verify)
      MODE="verify"
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      ;;
  esac
done

if [[ ${#CONTEXTS[@]} -eq 0 ]]; then
  CONTEXTS=("${DEFAULT_CONTEXTS[@]}")
fi

require_deploy() {
  local ctx="$1"
  local deploy="$2"
  kubectl --context "$ctx" get deploy -n "$NAMESPACE" "$deploy" >/dev/null
}

exec_py() {
  local ctx="$1"
  local deploy="$2"
  local workdir="$3"
  # stdin is the python program
  kubectl --context "$ctx" exec -i -n "$NAMESPACE" "deploy/$deploy" -- bash -lc \
    "cd \"$workdir\" && ADMINS_CSV=\"$ADMINS_CSV\" MODE=\"$MODE\" python -"
}

ensure_lms_admins() {
  local ctx="$1"
  log "[$ctx] Ensuring LMS admins ($MODE)"
  exec_py "$ctx" "lms" "/openedx/edx-platform" <<'PY'
import os
mode = os.environ.get("MODE", "apply")
admins = [a.strip() for a in os.environ["ADMINS_CSV"].split(",") if a.strip()]

import django
django.setup()
from django.contrib.auth import get_user_model

User = get_user_model()
for email in admins:
    u = User.objects.filter(email=email).first() or User.objects.filter(username=email).first()
    if not u:
        if mode == "verify":
            print(email, "MISSING")
            continue
        u = User.objects.create_user(username=email, email=email)
        if hasattr(u, "set_unusable_password"):
            u.set_unusable_password()
        created = True
    else:
        created = False

    if mode != "verify":
        u.is_active = True
        u.is_staff = True
        u.is_superuser = True
        u.save()

    print(email, "CREATED" if created else "OK", f"active={u.is_active}", f"staff={u.is_staff}", f"superuser={u.is_superuser}")
PY
}

ensure_lms_org_roles() {
  local ctx="$1"
  log "[$ctx] Ensuring LMS org roles (staff + instructor) for platform admins ($MODE)"
  exec_py "$ctx" "lms" "/openedx/edx-platform" <<'PY'
import os
import sys
mode = os.environ.get("MODE", "apply")
admins = [a.strip() for a in os.environ["ADMINS_CSV"].split(",") if a.strip()]

import django
django.setup()
from django.contrib.auth import get_user_model
from organizations.models import Organization
from common.djangoapps.student.roles import OrgStaffRole, OrgInstructorRole

User = get_user_model()
orgs = list(Organization.objects.filter(active=True).values_list("short_name", flat=True))
if not orgs:
    print("NO_ACTIVE_ORGS")
    sys.exit(1 if mode == "verify" else 0)

failed = False
for email in admins:
    u = User.objects.filter(email=email).first() or User.objects.filter(username=email).first()
    if not u:
        print(email, "USER_MISSING")
        if mode == "verify":
            failed = True
        continue

    for org in orgs:
        staff_role = OrgStaffRole(org=org)
        instructor_role = OrgInstructorRole(org=org)
        has_staff = staff_role.users_with_role().filter(id=u.id).exists()
        has_instructor = instructor_role.users_with_role().filter(id=u.id).exists()

        if mode != "verify":
            if not has_staff:
                staff_role.add_users(u)
            if not has_instructor:
                instructor_role.add_users(u)
            has_staff = staff_role.users_with_role().filter(id=u.id).exists()
            has_instructor = instructor_role.users_with_role().filter(id=u.id).exists()

        print(email, org, f"staff={has_staff}", f"instructor={has_instructor}")
        if mode == "verify" and (not has_staff or not has_instructor):
            failed = True

if mode == "verify" and failed:
    sys.exit(1)
PY
}

ensure_cms_coursecreator() {
  local ctx="$1"
  log "[$ctx] Ensuring CMS CourseCreator grants ($MODE)"
  exec_py "$ctx" "cms" "/openedx/edx-platform" <<'PY'
import os
mode = os.environ.get("MODE", "apply")
admins = [a.strip() for a in os.environ["ADMINS_CSV"].split(",") if a.strip()]

import django
django.setup()
from django.contrib.auth import get_user_model
from cms.djangoapps.course_creators.models import CourseCreator

User = get_user_model()
for email in admins:
    u = User.objects.filter(email=email).first() or User.objects.filter(username=email).first()
    if not u:
        print(email, "USER_MISSING")
        continue

    cc = CourseCreator.objects.filter(user=u).first()
    if mode == "verify":
        print(email, "CourseCreator", "MISSING" if not cc else f"state={cc.state}", "all_orgs=" + str(getattr(cc, "all_organizations", None)))
        continue

    if cc:
        cc.state = CourseCreator.GRANTED
        cc.all_organizations = True
        cc.save()
        print(email, "CourseCreator", "UPDATED")
    else:
        CourseCreator.objects.create(user=u, state=CourseCreator.GRANTED, all_organizations=True)
        print(email, "CourseCreator", "CREATED")
PY
}

ensure_generic_service_admins() {
  local ctx="$1"
  local deploy="$2"
  local workdir="$3"
  log "[$ctx] Ensuring ${deploy} admins ($MODE)"
  exec_py "$ctx" "$deploy" "$workdir" <<'PY'
import os
mode = os.environ.get("MODE", "apply")
admins = [a.strip() for a in os.environ["ADMINS_CSV"].split(",") if a.strip()]

import django
django.setup()
from django.contrib.auth import get_user_model

User = get_user_model()
for email in admins:
    u = User.objects.filter(email=email).first() or User.objects.filter(username=email).first()
    if not u:
        if mode == "verify":
            print(email, "MISSING")
            continue
        u = User.objects.create_user(username=email, email=email)
        if hasattr(u, "set_unusable_password"):
            u.set_unusable_password()
        created = True
    else:
        created = False

    if mode != "verify":
        u.is_active = True
        u.is_staff = True
        u.is_superuser = True
        u.save()

    print(email, "CREATED" if created else "OK", f"active={u.is_active}", f"staff={u.is_staff}", f"superuser={u.is_superuser}")
PY
}

for ctx in "${CONTEXTS[@]}"; do
  log "Target context: $ctx (namespace=$NAMESPACE, admins=$ADMINS_CSV, mode=$MODE)"

  for d in lms cms discovery credentials ecommerce; do
    require_deploy "$ctx" "$d"
  done

  ensure_lms_admins "$ctx"
  ensure_lms_org_roles "$ctx"
  ensure_cms_coursecreator "$ctx"

  # These services use Open edX OAuth (edx-oauth2) for normal login. To access /admin,
  # first log in via /login/ then visit /admin/.
  ensure_generic_service_admins "$ctx" "discovery" "/openedx/discovery"
  ensure_generic_service_admins "$ctx" "credentials" "/openedx/credentials"
  ensure_generic_service_admins "$ctx" "ecommerce" "/openedx/ecommerce"
done

log "Done."
