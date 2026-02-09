#!/usr/bin/env bash
# Build a runtime hostname routing matrix for the Open edX ecosystem.
#
# Purpose:
# - Show where each hostname is deployed (prod GKE vs dev kind).
# - Make "two Open edX" confusion explicit on shared VPS hosts.
#
# Usage:
#   ./scripts/qa/map-openedx-host-routing.sh
#   ./scripts/qa/map-openedx-host-routing.sh --env both
#   ./scripts/qa/map-openedx-host-routing.sh --format json
#
# Env overrides:
#   NAMESPACE=mereka-lms
#   CONTEXT_PROD=gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster
#   CONTEXT_DEV=kind-dev
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

NAMESPACE="${NAMESPACE:-${K8S_NAMESPACE:-mereka-lms}}"
CONTEXT_PROD="${CONTEXT_PROD:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
CONTEXT_DEV="${CONTEXT_DEV:-kind-dev}"
ENV_SCOPE="both"   # prod|dev|both
FORMAT="table"     # table|json

usage() {
  cat <<EOF >&2
Usage: $0 [--env prod|dev|both] [--format table|json]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_SCOPE="${2:-}"; shift 2 ;;
    --format)
      FORMAT="${2:-}"; shift 2 ;;
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
if [[ "$FORMAT" != "table" && "$FORMAT" != "json" ]]; then
  echo "Invalid --format: $FORMAT" >&2
  usage
  exit 1
fi

declare -A expected_env
declare -A prod_present
declare -A dev_present
declare -A prod_ingresses
declare -A dev_ingresses
declare -A host_union

set_expected() {
  local host="$1"
  local env_label="$2"
  if [[ -z "${expected_env[$host]+x}" ]]; then
    expected_env[$host]="$env_label"
  elif [[ "${expected_env[$host]}" != "$env_label" ]]; then
    expected_env[$host]="${expected_env[$host]}+$env_label"
  fi
  host_union[$host]=1
}

collect_context_hosts() {
  local ctx="$1"
  kubectl --context "$ctx" get ingress -n "$NAMESPACE" -o json \
    | jq -r '
      .items[]
      | .metadata.name as $ing
      | (.spec.rules // [])[]?
      | select(.host != null and .host != "")
      | "\($ing)\t\(.host)"
    ' \
    | sort -u
}

append_ingress() {
  local current="$1"
  local ingress="$2"
  if [[ -z "$current" ]]; then
    echo "$ingress"
    return
  fi
  if grep -q "(^|,)$ingress(,|$)" <<<"$current"; then
    echo "$current"
    return
  fi
  echo "$current,$ingress"
}

for h in \
  "$LMS_DOMAIN" "$PREVIEW_DOMAIN" "$STUDIO_DOMAIN" "$MFE_DOMAIN" \
  "$DISCOVERY_DOMAIN" "$ECOMMERCE_DOMAIN" "$CREDENTIALS_DOMAIN" \
  "$NOTES_DOMAIN" "$FORUM_DOMAIN" "$BIJI_DOMAIN" "$BIJI_STUDIO_DOMAIN" \
  "$BIJI_MFE_DOMAIN" "$SKILLOURFUTURE_DOMAIN"; do
  [[ -n "$h" ]] && set_expected "$h" "prod"
done

for h in \
  "$DEV_LMS_DOMAIN" "$DEV_PREVIEW_DOMAIN" "$DEV_STUDIO_DOMAIN" "$DEV_MFE_DOMAIN" \
  "$DEV_DISCOVERY_DOMAIN" "$DEV_ECOMMERCE_DOMAIN" "$DEV_CREDENTIALS_DOMAIN" \
  "$DEV_NOTES_DOMAIN" "$DEV_FORUM_DOMAIN"; do
  [[ -n "$h" ]] && set_expected "$h" "dev"
done

for h in apps.lms.lvh.me lms.lvh.me preview.lms.lvh.me studio.lms.lvh.me; do
  set_expected "$h" "dev-local"
done

if [[ "$ENV_SCOPE" == "prod" || "$ENV_SCOPE" == "both" ]]; then
  while IFS=$'\t' read -r ingress host; do
    [[ -z "$host" ]] && continue
    host_union[$host]=1
    prod_present[$host]=1
    prod_ingresses[$host]="$(append_ingress "${prod_ingresses[$host]:-}" "$ingress")"
  done < <(collect_context_hosts "$CONTEXT_PROD")
fi

if [[ "$ENV_SCOPE" == "dev" || "$ENV_SCOPE" == "both" ]]; then
  while IFS=$'\t' read -r ingress host; do
    [[ -z "$host" ]] && continue
    host_union[$host]=1
    dev_present[$host]=1
    dev_ingresses[$host]="$(append_ingress "${dev_ingresses[$host]:-}" "$ingress")"
  done < <(collect_context_hosts "$CONTEXT_DEV")
fi

classification_for() {
  local host="$1"
  local in_prod="${prod_present[$host]:-0}"
  local in_dev="${dev_present[$host]:-0}"
  if [[ "$in_prod" == "1" && "$in_dev" == "1" ]]; then
    echo "both"
    return
  fi
  if [[ "$in_prod" == "1" ]]; then
    echo "prod-only"
    return
  fi
  if [[ "$in_dev" == "1" ]]; then
    echo "dev-only"
    return
  fi
  echo "not-deployed"
}

if [[ "$FORMAT" == "json" ]]; then
  echo "["
  first=1
  while IFS= read -r host; do
    [[ -z "$host" ]] && continue
    [[ "$first" -eq 1 ]] || echo ","
    first=0
    printf '  {"host":"%s","expected_env":"%s","prod_present":%s,"dev_present":%s,"prod_ingresses":"%s","dev_ingresses":"%s","classification":"%s"}' \
      "$host" \
      "${expected_env[$host]:-unlisted}" \
      "${prod_present[$host]:-0}" \
      "${dev_present[$host]:-0}" \
      "${prod_ingresses[$host]:-}" \
      "${dev_ingresses[$host]:-}" \
      "$(classification_for "$host")"
  done < <(printf '%s\n' "${!host_union[@]}" | sort)
  echo
  echo "]"
  exit 0
fi

printf '%-44s %-12s %-5s %-5s %-22s %-22s %-12s\n' \
  "HOST" "EXPECTED" "PROD" "DEV" "PROD_INGRESS" "DEV_INGRESS" "CLASS"
printf '%s\n' "----------------------------------------------------------------------------------------------------------------------------------------"
while IFS= read -r host; do
  [[ -z "$host" ]] && continue
  printf '%-44s %-12s %-5s %-5s %-22s %-22s %-12s\n' \
    "$host" \
    "${expected_env[$host]:-unlisted}" \
    "${prod_present[$host]:-0}" \
    "${dev_present[$host]:-0}" \
    "${prod_ingresses[$host]:--}" \
    "${dev_ingresses[$host]:--}" \
    "$(classification_for "$host")"
done < <(printf '%s\n' "${!host_union[@]}" | sort)
