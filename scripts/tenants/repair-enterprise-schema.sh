#!/usr/bin/env bash
# @covers AC-029
# @spec: enterprise-microservices_spec.md
# Repair enterprise schema drift by running enterprise app migrations and verifying columns.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/scripts/shared/config.sh" 2>/dev/null || true

ENVIRONMENT="prod"
NAMESPACE="${K8S_NAMESPACE:-mereka-lms}"
CONTEXT_OVERRIDE=""
APPLY=0
ALLOW_PROD_APPLY="${ALLOW_PROD_APPLY:-0}"
CREATE_PREOP_BACKUP="${CREATE_PREOP_BACKUP:-1}"
CONFIRM_REPAIR_ENTERPRISE_SCHEMA="${CONFIRM_REPAIR_ENTERPRISE_SCHEMA:-}"
CONFIRM_TOKEN="REPAIR_ENTERPRISE_SCHEMA"

usage() {
  cat <<'USAGE'
Usage: repair-enterprise-schema.sh [--env prod|dev] [--apply] [--namespace NS] [--context CTX]

Default mode is read-only validation. Use --apply to run migrations.

Safety controls for --apply:
  - CONFIRM_REPAIR_ENTERPRISE_SCHEMA=REPAIR_ENTERPRISE_SCHEMA (required)
  - ALLOW_PROD_APPLY=1 (required for --env prod)
  - CREATE_PREOP_BACKUP=1 (default for prod apply; runs Velero pre-op backup)
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENVIRONMENT="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --context) CONTEXT_OVERRIDE="$2"; shift 2 ;;
    --apply) APPLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ "$ENVIRONMENT" != "prod" && "$ENVIRONMENT" != "dev" ]]; then
  echo "Invalid --env '$ENVIRONMENT'" >&2
  exit 1
fi

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

require_bool_01 "ALLOW_PROD_APPLY" "$ALLOW_PROD_APPLY"
require_bool_01 "CREATE_PREOP_BACKUP" "$CREATE_PREOP_BACKUP"
require_cmd kubectl

DEFAULT_PROD_CTX="gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster"
DEFAULT_DEV_CTX="kind-dev"
K8S_CONTEXT_EFFECTIVE="${CONTEXT_OVERRIDE}"
if [[ -z "$K8S_CONTEXT_EFFECTIVE" ]]; then
  if [[ "$ENVIRONMENT" == "prod" ]]; then
    K8S_CONTEXT_EFFECTIVE="${K8S_CONTEXT:-$DEFAULT_PROD_CTX}"
  else
    K8S_CONTEXT_EFFECTIVE="$DEFAULT_DEV_CTX"
  fi
fi

context_args=()
if [[ -n "$K8S_CONTEXT_EFFECTIVE" ]]; then
  context_args+=(--context "$K8S_CONTEXT_EFFECTIVE")
fi

check_schema() {
  kubectl "${context_args[@]}" exec -i -n "$NAMESPACE" deploy/lms -- python - <<'PY'
import json
import django

django.setup()

from django.db import connection
from enterprise.models import EnterpriseCustomer

with connection.cursor() as cursor:
    db_columns = {c.name for c in connection.introspection.get_table_description(cursor, "enterprise_enterprisecustomer")}
    table_names = set(connection.introspection.table_names(cursor))

# Runtime contract:
# - keep concrete modeled fields in DB (currently only career-engagement flag)
# - accept either legacy identity_provider column OR linkage table model
required_candidates = ["enable_career_engagement_network_on_learner_portal"]
model_fields = {f.name for f in EnterpriseCustomer._meta.get_fields()}
required_modeled = [field for field in required_candidates if field in model_fields]
db_missing = [field for field in required_modeled if field not in db_columns]

concrete_fields = {f.name for f in EnterpriseCustomer._meta.get_fields() if getattr(f, "concrete", False)}
has_legacy_identity_provider_field = "identity_provider" in concrete_fields
has_linkage_table = "enterprise_enterprisecustomeridentityprovider" in table_names

linkage_errors = []
if has_legacy_identity_provider_field and "identity_provider" not in db_columns:
    linkage_errors.append("enterprise_enterprisecustomer.identity_provider")
if not has_legacy_identity_provider_field and not has_linkage_table:
    linkage_errors.append("enterprise idp linkage model/table")

print(json.dumps({
    "required_modeled": required_modeled,
    "has_legacy_identity_provider_field": has_legacy_identity_provider_field,
    "has_linkage_table": has_linkage_table,
    "linkage_errors": linkage_errors,
    "db_missing": db_missing,
}, sort_keys=True))

if db_missing or linkage_errors:
    raise SystemExit(2)
PY
}

echo "=== Enterprise Schema Repair ==="
echo "env=${ENVIRONMENT} context=${K8S_CONTEXT_EFFECTIVE} namespace=${NAMESPACE} apply=${APPLY}"

if [[ "$APPLY" -eq 1 ]]; then
  if [[ "$CONFIRM_REPAIR_ENTERPRISE_SCHEMA" != "$CONFIRM_TOKEN" ]]; then
    echo "Refusing --apply: set CONFIRM_REPAIR_ENTERPRISE_SCHEMA=${CONFIRM_TOKEN}" >&2
    exit 1
  fi

  if [[ "$ENVIRONMENT" == "prod" && "$ALLOW_PROD_APPLY" != "1" ]]; then
    echo "Refusing production --apply without ALLOW_PROD_APPLY=1" >&2
    exit 1
  fi

  if [[ "$ENVIRONMENT" == "prod" && "$CREATE_PREOP_BACKUP" == "1" ]]; then
    require_cmd velero
    backup_name="pre-op-${NAMESPACE}-enterprise-schema-repair-$(date -u +%Y%m%d-%H%M)"
    echo "Creating Velero pre-op backup: $backup_name"
    velero backup create "$backup_name" --include-namespaces "$NAMESPACE" --wait
  elif [[ "$ENVIRONMENT" == "prod" ]]; then
    echo "WARNING: CREATE_PREOP_BACKUP=0 for production apply (operator override)" >&2
  fi

  echo "Running enterprise migrations in LMS pod..."
  kubectl "${context_args[@]}" exec -n "$NAMESPACE" deploy/lms -- python manage.py lms migrate enterprise --noinput
fi

echo "Checking enterprise schema integrity..."
if output=$(check_schema 2>&1); then
  echo "PASS: enterprise schema/linkage integrity is aligned with runtime contract"
  echo "$output"
else
  status=$?
  echo "FAIL: enterprise schema drift remains"
  echo "$output"
  if [[ $status -eq 2 ]]; then
    echo "Required runtime contract: modeled required fields in DB + valid identity-provider linkage path"
  fi
  exit 1
fi
