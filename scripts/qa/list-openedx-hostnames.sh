#!/usr/bin/env bash
# @covers AC-001
# @spec: multi-site-domains_spec.md
# List the Open edX ecosystem hostnames (expected vs deployed).
#
# This is an operator tool to keep docs/specs honest when hostnames change.
# It requires kubectl access but does not use secrets.
#
# Usage:
#   ./scripts/qa/list-openedx-hostnames.sh
#   ./scripts/qa/list-openedx-hostnames.sh --env prod
#
# Optional:
#   STRICT=1  # exit non-zero if deployed hosts differ from expected
#   NAMESPACE=mereka-lms
#   CONTEXT_PROD=gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster
#   CONTEXT_DEV=kind-dev
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

STRICT="${STRICT:-0}"
NAMESPACE="${NAMESPACE:-${K8S_NAMESPACE:-mereka-lms}}"
ENV_SCOPE="both" # prod|dev|staging|both|all

CONTEXT_PROD="${CONTEXT_PROD:-${K8S_CONTEXT_PROD:-${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}}}"
CONTEXT_DEV="${CONTEXT_DEV:-${K8S_CONTEXT_DEV:-${K8S_CONTEXT:-kind-dev}}}"
CONTEXT_STAGING="${CONTEXT_STAGING:-${K8S_CONTEXT_STAGING:-rke2-nonprod}}"
NAMESPACE_STAGING="${NAMESPACE_STAGING:-${K8S_NAMESPACE_STAGING:-stg-mereka-lms}}"

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

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }

usage() {
  cat <<EOF >&2
Usage: $0 [--env prod|dev|staging|both|all]

Env:
  STRICT=1  Fail when deployed hosts differ from expected set
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_SCOPE="${2:-}"; shift 2 ;;
    -h|--help)
      usage
      exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ "$ENV_SCOPE" != "prod" && "$ENV_SCOPE" != "dev" && "$ENV_SCOPE" != "staging" && "$ENV_SCOPE" != "both" && "$ENV_SCOPE" != "all" ]]; then
  echo "Invalid --env: $ENV_SCOPE" >&2
  usage
  exit 1
fi
require_bool_01 "STRICT" "$STRICT"

collect_ingress_hosts() {
  local ctx="$1"
  kubectl --context "$ctx" get ingress -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .spec.rules[*]}{.host}{" "}{end}{"\n"}{end}' \
    | awk -F'\t' '
      NF < 2 {next}
      {
        # Emit only hosts (one per line)
        n=split($2, arr, " ")
        for (i=1; i<=n; i++) if (length(arr[i])>0) print arr[i]
      }
    ' \
    | sort -u
}

print_expected() {
  local env="$1"
  if [[ "$env" == "prod" ]]; then
    printf "%s\n" \
      "$LMS_DOMAIN" \
      "$PREVIEW_DOMAIN" \
      "$STUDIO_DOMAIN" \
      "$MFE_DOMAIN" \
      "$DISCOVERY_DOMAIN" \
      "$ECOMMERCE_DOMAIN" \
      "$CREDENTIALS_DOMAIN" \
      "$NOTES_DOMAIN" \
      "$FORUM_DOMAIN" \
      "$ENTERPRISE_ADMIN_DOMAIN" \
      "$ENTERPRISE_PORTAL_DOMAIN" \
      "$BIJI_DOMAIN" \
      "$BIJI_STUDIO_DOMAIN" \
      "$BIJI_MFE_DOMAIN" \
      "$SKILLOURFUTURE_DOMAIN" \
      | awk 'NF{print}' | sort -u
    return
  fi

  if [[ "$env" == "dev" ]]; then
    printf "%s\n" \
      "$DEV_LMS_DOMAIN" \
      "$DEV_PREVIEW_DOMAIN" \
      "$DEV_STUDIO_DOMAIN" \
      "$DEV_MFE_DOMAIN" \
      "$DEV_DISCOVERY_DOMAIN" \
      "$DEV_ECOMMERCE_DOMAIN" \
      "$DEV_CREDENTIALS_DOMAIN" \
      "$DEV_NOTES_DOMAIN" \
      "$DEV_FORUM_DOMAIN" \
      | awk 'NF{print}' | sort -u
    return
  fi

  if [[ "$env" == "staging" ]]; then
    # Keep this aligned with the active staging entries in tenant-registry.yaml.
    printf "%s\n" \
      "$STAGING_LMS_DOMAIN" \
      "$STAGING_PREVIEW_DOMAIN" \
      "$STAGING_STUDIO_DOMAIN" \
      "$STAGING_MFE_DOMAIN" \
      "$STAGING_DISCOVERY_DOMAIN" \
      "$STAGING_NOTES_DOMAIN" \
      "$STAGING_CREDENTIALS_DOMAIN" \
      "$STAGING_ENTERPRISE_ADMIN_DOMAIN" \
      "$STAGING_ENTERPRISE_PORTAL_DOMAIN" \
      "staging.academy.biji-biji.com" \
      "studio.staging.academy.biji-biji.com" \
      "apps.staging.academy.biji-biji.com" \
      "staging.skillourfuture.academy.mereka.io" \
      "studio.staging.skillourfuture.academy.mereka.io" \
      "apps.staging.skillourfuture.academy.mereka.io" \
      | awk 'NF{print}' | sort -u
    return
  fi

  echo "Unknown env: $env" >&2
  return 2
}

diff_sets() {
  local expected="$1"
  local deployed="$2"
  local label="$3"
  local allowed_extra="${4:-}"

  local missing extra filtered_extra compatibility_extra
  missing="$(comm -23 <(printf "%s\n" "$expected") <(printf "%s\n" "$deployed") || true)"
  extra="$(comm -13 <(printf "%s\n" "$expected") <(printf "%s\n" "$deployed") || true)"
  if [[ -n "$allowed_extra" ]]; then
    filtered_extra="$(comm -23 <(printf "%s\n" "$extra") <(printf "%s\n" "$allowed_extra") || true)"
    compatibility_extra="$(comm -12 <(printf "%s\n" "$extra") <(printf "%s\n" "$allowed_extra") || true)"
  else
    filtered_extra="$extra"
    compatibility_extra=""
  fi

  echo ""
  echo "== $label =="
  echo "Expected:"
  printf "%s\n" "$expected" | sed 's/^/  - /'
  echo "Deployed (Ingress hosts in $NAMESPACE):"
  printf "%s\n" "$deployed" | sed 's/^/  - /'

  if [[ -n "$missing" ]]; then
    echo "Missing from deployed:"
    printf "%s\n" "$missing" | sed 's/^/  - /'
  fi
  if [[ -n "$filtered_extra" ]]; then
    echo "Extra in deployed (not in expected list):"
    printf "%s\n" "$filtered_extra" | sed 's/^/  - /'
  fi
  if [[ -n "$compatibility_extra" ]]; then
    echo "Compatibility extras currently allowed during staging migration window:"
    printf "%s\n" "$compatibility_extra" | sed 's/^/  - /'
  fi

  if [[ "$STRICT" == "1" && ( -n "$missing" || -n "$filtered_extra" ) ]]; then
    return 1
  fi
  return 0
}

allowed_extra_hosts() {
  local env="$1"
  if [[ "$env" == "staging" ]]; then
    printf "%s\n" \
      "admin.staging.academyv2.mereka.io" \
      "credentials.staging.academyv2.mereka.io" \
      "discovery.staging.academyv2.mereka.io" \
      "learner.staging.academyv2.mereka.io" \
      "notes.staging.academyv2.mereka.io" \
      "staging.credentials.mereka.io" \
      "staging.discovery.mereka.io" \
      "staging.ecommerce.mereka.io" \
      "staging.notes.mereka.io" \
      | awk 'NF{print}' | sort -u
    return
  fi

  printf ""
}

rc=0

log "Collecting Open edX hostnames from cluster ingresses (env=$ENV_SCOPE)"

if [[ "$ENV_SCOPE" == "prod" || "$ENV_SCOPE" == "both" || "$ENV_SCOPE" == "all" ]]; then
  expected_prod="$(print_expected prod)"
  deployed_prod="$(
    collect_ingress_hosts "$CONTEXT_PROD" \
      | tr -d '\r' \
      | sed 's/[[:space:]]*$//' \
      | grep -E '(mereka\.io|biji-biji\.com)$' \
      || true
  )"
  diff_sets "$expected_prod" "$deployed_prod" "prod ($CONTEXT_PROD)" || rc=1
fi

if [[ "$ENV_SCOPE" == "dev" || "$ENV_SCOPE" == "both" || "$ENV_SCOPE" == "all" ]]; then
  expected_dev="$(print_expected dev)"
  deployed_dev_public="$(
    collect_ingress_hosts "$CONTEXT_DEV" \
      | tr -d '\r' \
      | sed 's/[[:space:]]*$//' \
      | grep -E 'mereka\.dev$' \
      || true
  )"
  deployed_dev_local="$(
    collect_ingress_hosts "$CONTEXT_DEV" \
      | tr -d '\r' \
      | sed 's/[[:space:]]*$//' \
      | grep -E 'lvh\.me$' \
      || true
  )"
  diff_sets "$expected_dev" "$deployed_dev_public" "dev (public) ($CONTEXT_DEV)" || rc=1

  if [[ -n "${deployed_dev_local:-}" ]]; then
    echo ""
    echo "== dev (kind-local hostnames) ($CONTEXT_DEV) =="
    printf "%s\n" "$deployed_dev_local" | sed 's/^/  - /'
  fi
fi

if [[ "$ENV_SCOPE" == "staging" || "$ENV_SCOPE" == "all" ]]; then
  NAMESPACE="$NAMESPACE_STAGING"
  expected_staging="$(print_expected staging)"
  allowed_extra_staging="$(allowed_extra_hosts staging)"
  deployed_staging="$(
    collect_ingress_hosts "$CONTEXT_STAGING" \
      | tr -d '\r' \
      | sed 's/[[:space:]]*$//' \
      || true
  )"
  diff_sets "$expected_staging" "$deployed_staging" "staging ($CONTEXT_STAGING)" "$allowed_extra_staging" || rc=1
fi

if [[ "$rc" -ne 0 ]]; then
  echo ""
  echo "FAILED: Deployed hostnames differ from expected list." >&2
  exit 1
fi

echo ""
echo "OK"
