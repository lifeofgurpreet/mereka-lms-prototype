#!/usr/bin/env bash
# Read-only course data sanity checks for an environment.
#
# This script reports:
# - Where modulestore is pointing (in-cluster Mongo vs Atlas)
# - CourseOverview count (MySQL)
# - Modulestore course count (MongoDB)
#
# It is intentionally not "STRICT" by default because some environments may
# legitimately be empty during migrations. Use STRICT=1 to fail on 0 counts.
#
# Usage:
#   ./scripts/qa/course-data-sanity.sh --env prod
#   ./scripts/qa/course-data-sanity.sh --env dev
#   ./scripts/qa/course-data-sanity.sh --env staging
#   STRICT=1 ./scripts/qa/course-data-sanity.sh --env all
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

ENV_SCOPE="both" # prod|dev|staging|both|all
NAMESPACE="${NAMESPACE:-${K8S_NAMESPACE:-mereka-lms}}"
NAMESPACE_PROD="${NAMESPACE_PROD:-${K8S_NAMESPACE_PROD:-$NAMESPACE}}"
NAMESPACE_DEV="${NAMESPACE_DEV:-${K8S_NAMESPACE_DEV:-$NAMESPACE}}"
NAMESPACE_STAGING="${NAMESPACE_STAGING:-${K8S_NAMESPACE_STAGING:-stg-mereka-lms}}"
CONTEXT_PROD="${CONTEXT_PROD:-${K8S_CONTEXT_PROD:-${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}}}"
CONTEXT_DEV="${CONTEXT_DEV:-${K8S_CONTEXT_DEV:-${K8S_CONTEXT:-kind-dev}}}"
CONTEXT_STAGING="${CONTEXT_STAGING:-${K8S_CONTEXT_STAGING:-rke2-nonprod}}"
STRICT="${STRICT:-0}"

usage() {
  cat <<'EOF' >&2
Usage: ./scripts/qa/course-data-sanity.sh [--env prod|dev|staging|both|all] [--namespace NAMESPACE]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_SCOPE="${2:-}"; shift 2 ;;
    --namespace) NAMESPACE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ "$ENV_SCOPE" != "prod" && "$ENV_SCOPE" != "dev" && "$ENV_SCOPE" != "staging" && "$ENV_SCOPE" != "both" && "$ENV_SCOPE" != "all" ]]; then
  echo "Invalid --env: $ENV_SCOPE" >&2
  usage
  exit 1
fi

case "$STRICT" in
  0|1) ;;
  *)
    echo "Invalid STRICT='$STRICT' (expected 0 or 1)" >&2
    exit 1
    ;;
esac

check_context() {
  local ctx="$1"
  local ns="$2"
  echo "Context: $ctx"
  echo "Namespace: $ns"
  echo "Strict: $STRICT"

  local out
  out="$(
    kubectl --context "$ctx" exec -n "$ns" deploy/lms -- bash -lc \
      "python /openedx/edx-platform/manage.py lms shell -c \"\
from django.conf import settings; \
from openedx.core.djangoapps.content.course_overviews.models import CourseOverview; \
from xmodule.modulestore.django import modulestore; \
cfg=settings.CONTENTSTORE.get('DOC_STORE_CONFIG', {}); \
host=str(cfg.get('host') or ''); \
parts=host.split('://', 1); \
host=((parts[0] + '://***@' + parts[1].split('@', 1)[1]) if (len(parts)==2 and '@' in parts[1]) else host); \
print('DOC_STORE_HOST', host); \
print('DOC_STORE_DB', cfg.get('db')); \
print('CourseOverview', CourseOverview.objects.count()); \
store=modulestore(); \
print('modulestore_courses', sum(1 for _ in store.get_courses()));\""
  )"

  echo "$out" | sed 's/\r$//'

  local co ms
  co="$(echo "$out" | awk '$1=="CourseOverview"{print $2}' | tail -n 1)"
  ms="$(echo "$out" | awk '$1=="modulestore_courses"{print $2}' | tail -n 1)"

  if [[ "$STRICT" == "1" ]]; then
    if [[ "${co:-}" == "0" ]]; then
      echo "FAILED: CourseOverview is 0" >&2
      return 1
    fi
    if [[ "${ms:-}" == "0" ]]; then
      echo "FAILED: modulestore_courses is 0" >&2
      return 1
    fi
  fi

  echo "OK"
  return 0
}

rc=0
if [[ "$ENV_SCOPE" == "prod" || "$ENV_SCOPE" == "both" || "$ENV_SCOPE" == "all" ]]; then
  check_context "$CONTEXT_PROD" "$NAMESPACE_PROD" || rc=1
fi
if [[ "$ENV_SCOPE" == "dev" || "$ENV_SCOPE" == "both" || "$ENV_SCOPE" == "all" ]]; then
  check_context "$CONTEXT_DEV" "$NAMESPACE_DEV" || rc=1
fi
if [[ "$ENV_SCOPE" == "staging" || "$ENV_SCOPE" == "all" ]]; then
  check_context "$CONTEXT_STAGING" "$NAMESPACE_STAGING" || rc=1
fi

exit "$rc"
