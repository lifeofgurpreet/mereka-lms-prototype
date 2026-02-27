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

usage() {
  cat <<'USAGE'
Usage: repair-enterprise-schema.sh [--env prod|dev] [--apply] [--namespace NS] [--context CTX]

Default mode is read-only validation. Use --apply to run migrations.
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

required_candidates = [
    "identity_provider",
    "enable_career_engagement_network_on_learner_portal",
]
model_fields = {f.name for f in EnterpriseCustomer._meta.get_fields()}
required = [c for c in required_candidates if c in model_fields]
with connection.cursor() as cursor:
    cols = {c.name for c in connection.introspection.get_table_description(cursor, "enterprise_enterprisecustomer")}
missing = [c for c in required if c not in cols]
print(json.dumps({"required": required, "missing": missing}, sort_keys=True))
if missing:
    raise SystemExit(2)
PY
}

echo "=== Enterprise Schema Repair ==="
echo "env=${ENVIRONMENT} context=${K8S_CONTEXT_EFFECTIVE} namespace=${NAMESPACE} apply=${APPLY}"

if [[ "$APPLY" -eq 1 ]]; then
  echo "Running enterprise migrations in LMS pod..."
  kubectl "${context_args[@]}" exec -n "$NAMESPACE" deploy/lms -- python manage.py lms migrate enterprise --noinput
fi

echo "Checking enterprise schema integrity..."
if check_schema; then
  echo "PASS: enterprise schema is aligned with required model fields"
else
  echo "FAIL: enterprise schema drift remains"
  exit 1
fi
