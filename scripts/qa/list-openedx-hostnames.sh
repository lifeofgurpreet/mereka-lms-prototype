#!/usr/bin/env bash
# List the Open edX ecosystem hostnames (expected vs deployed).
#
# This is an operator tool to keep docs/specs honest when hostnames change.
# It requires kubectl access but does not use secrets.
#
# Usage:
#   ./scripts/qa/list-openedx-hostnames.sh
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

CONTEXT_PROD="${CONTEXT_PROD:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
CONTEXT_DEV="${CONTEXT_DEV:-kind-dev}"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }

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

  echo "Unknown env: $env" >&2
  return 2
}

diff_sets() {
  local expected="$1"
  local deployed="$2"
  local label="$3"

  local missing extra
  missing="$(comm -23 <(printf "%s\n" "$expected") <(printf "%s\n" "$deployed") || true)"
  extra="$(comm -13 <(printf "%s\n" "$expected") <(printf "%s\n" "$deployed") || true)"

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
  if [[ -n "$extra" ]]; then
    echo "Extra in deployed (not in expected list):"
    printf "%s\n" "$extra" | sed 's/^/  - /'
  fi

  if [[ "$STRICT" == "1" && ( -n "$missing" || -n "$extra" ) ]]; then
    return 1
  fi
  return 0
}

rc=0

log "Collecting Open edX hostnames from cluster ingresses"

expected_prod="$(print_expected prod)"
deployed_prod="$(
  collect_ingress_hosts "$CONTEXT_PROD" \
    | tr -d '\r' \
    | sed 's/[[:space:]]*$//' \
    | grep -E '(mereka\.io|biji-biji\.com)$' \
    || true
)"
diff_sets "$expected_prod" "$deployed_prod" "prod ($CONTEXT_PROD)" || rc=1

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

if [[ "$rc" -ne 0 ]]; then
  echo ""
  echo "FAILED: Deployed hostnames differ from expected list." >&2
  exit 1
fi

echo ""
echo "OK"
