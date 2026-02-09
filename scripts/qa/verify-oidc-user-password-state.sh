#!/usr/bin/env bash
# Verify OIDC-linked active users are not blocked by unusable LMS passwords.
#
# Open edX third-party-auth pipeline returns "Your account is disabled" when an
# authenticated OIDC user has no usable LMS password. This script audits that
# state and can optionally remediate it by setting strong random passwords.
#
# Usage:
#   ./scripts/qa/verify-oidc-user-password-state.sh --env prod
#   ./scripts/qa/verify-oidc-user-password-state.sh --env both
#   ./scripts/qa/verify-oidc-user-password-state.sh --env prod --fix
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

ENV_SCOPE="prod" # prod|dev|both
NAMESPACE="${NAMESPACE:-${K8S_NAMESPACE:-mereka-lms}}"
CONTEXT_PROD="${CONTEXT_PROD:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
CONTEXT_DEV="${CONTEXT_DEV:-kind-dev}"
APPLY_FIX=0

usage() {
  cat <<'EOF' >&2
Usage: ./scripts/qa/verify-oidc-user-password-state.sh [--env prod|dev|both] [--fix]

Options:
  --env ENV      Target environment scope (prod|dev|both). Default: prod
  --fix          Remediate affected users by setting strong random passwords

Env overrides:
  NAMESPACE      Kubernetes namespace (default: mereka-lms)
  CONTEXT_PROD   Kubernetes context for prod
  CONTEXT_DEV    Kubernetes context for dev
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_SCOPE="${2:-}"; shift 2 ;;
    --fix)
      APPLY_FIX=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ "$ENV_SCOPE" != "prod" && "$ENV_SCOPE" != "dev" && "$ENV_SCOPE" != "both" ]]; then
  echo "Invalid --env: $ENV_SCOPE" >&2
  usage
  exit 1
fi

run_env() {
  local env_name="$1"
  local context="$2"

  if ! kubectl --context "$context" get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "[$env_name] FAIL namespace '$NAMESPACE' not found in context '$context'" >&2
    return 2
  fi
  if ! kubectl --context "$context" -n "$NAMESPACE" get deploy lms >/dev/null 2>&1; then
    echo "[$env_name] FAIL deployment/lms not found in namespace '$NAMESPACE'" >&2
    return 2
  fi

  local output rc summary
  set +e
  output="$(
    kubectl --context "$context" -n "$NAMESPACE" exec -i deploy/lms -- bash -lc "cd /openedx/edx-platform && OIDC_PASSWORD_FIX=${APPLY_FIX} ./manage.py lms shell" <<'PY'
import json
import os
from django.contrib.auth import get_user_model
from django.utils.crypto import get_random_string

U = get_user_model()
apply_fix = os.environ.get("OIDC_PASSWORD_FIX", "0") == "1"

qs = U.objects.filter(social_auth__provider="oidc", is_active=True).distinct()
affected = []
for user in qs:
    if not user.has_usable_password():
        affected.append(
            {
                "id": user.id,
                "username": user.username,
                "email": user.email,
            }
        )
        if apply_fix:
            user.set_password(get_random_string(40))
            user.save(update_fields=["password"])

result = {
    "active_oidc_users": qs.count(),
    "affected_count": len(affected),
    "fixed_count": len(affected) if apply_fix else 0,
    "affected": affected,
}
print("OIDC_PASSWORD_AUDIT_JSON=" + json.dumps(result, sort_keys=True))
raise SystemExit(12 if (len(affected) > 0 and not apply_fix) else 0)
PY
  )"
  rc=$?
  set -e

  summary="$(printf "%s\n" "$output" | grep '^OIDC_PASSWORD_AUDIT_JSON=' | tail -n 1 | sed 's/^OIDC_PASSWORD_AUDIT_JSON=//')"
  if [[ -z "$summary" ]]; then
    echo "[$env_name] FAIL could not parse OIDC password audit output" >&2
    printf "%s\n" "$output" | tail -n 40 | sed 's/^/  /' >&2
    return 2
  fi

  if [[ "$rc" -eq 0 ]]; then
    if [[ "$APPLY_FIX" -eq 1 ]]; then
      echo "[$env_name] OK (remediated) $summary"
    else
      echo "[$env_name] OK $summary"
    fi
    return 0
  fi

  if [[ "$rc" -eq 12 ]]; then
    echo "[$env_name] FAIL active OIDC users with unusable passwords detected: $summary" >&2
    return 12
  fi

  echo "[$env_name] FAIL unexpected error (exit=$rc)" >&2
  printf "%s\n" "$output" | tail -n 40 | sed 's/^/  /' >&2
  return "$rc"
}

rc=0
if [[ "$ENV_SCOPE" == "prod" || "$ENV_SCOPE" == "both" ]]; then
  run_env "prod" "$CONTEXT_PROD" || rc=1
fi
if [[ "$ENV_SCOPE" == "dev" || "$ENV_SCOPE" == "both" ]]; then
  run_env "dev" "$CONTEXT_DEV" || rc=1
fi

exit "$rc"
