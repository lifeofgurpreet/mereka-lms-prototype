#!/usr/bin/env bash
# @covers AC-016
# @spec: auth-sso-enterprise_spec.md
# Ensure Authentik OIDC provider has redirect URIs for every LMS hostname we serve.
#
# This is intentionally additive and idempotent.
#
# Why:
# - Missing redirect URIs cause OIDC login to fail on new microsites/aliases.
#
# Usage:
#   ./scripts/infra/ensure-authentik-oidc-redirect-uris.sh --verify
#   ./scripts/infra/ensure-authentik-oidc-redirect-uris.sh --apply
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

K8S_CONTEXT="${K8S_CONTEXT:-rke2-prod}"
NAMESPACE="${NAMESPACE:-authentik}"
AUTHENTIK_DEPLOY="${AUTHENTIK_DEPLOY:-authentik-server}"
ALLOW_PROD_APPLY="${ALLOW_PROD_APPLY:-0}"
CREATE_PREOP_BACKUP="${CREATE_PREOP_BACKUP:-1}"
CONFIRM_ENSURE_AUTHENTIK_OIDC_REDIRECT_URIS="${CONFIRM_ENSURE_AUTHENTIK_OIDC_REDIRECT_URIS:-}"
CONFIRM_TOKEN="ENSURE_AUTHENTIK_OIDC_REDIRECT_URIS"

CLIENT_ID="${CLIENT_ID:-mereka-lms}"
TARGET_ENV="${TARGET_ENV:-all}" # all | prod | dev | staging

MODE="verify" # verify | apply

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

OPTIONS:
  --verify                  Verify only (default)
  --apply                   Add missing redirect URIs (idempotent)
  --context K8S_CONTEXT     Kube context (default: $K8S_CONTEXT)
  --namespace NAMESPACE     Namespace (default: $NAMESPACE)
  --deploy DEPLOYMENT       Authentik server deployment name (default: $AUTHENTIK_DEPLOY)
  --client-id CLIENT_ID     OAuth2 client_id (default: $CLIENT_ID)
  --env TARGET_ENV          Host set to enforce (all|prod|dev|staging). Default: all
  -h, --help                Show help

Safety controls for --apply:
  CONFIRM_ENSURE_AUTHENTIK_OIDC_REDIRECT_URIS=ENSURE_AUTHENTIK_OIDC_REDIRECT_URIS
  ALLOW_PROD_APPLY=1        Required for prod-like contexts
  CREATE_PREOP_BACKUP=1     Default for prod-like contexts (Velero pre-op backup)
EOF
  exit 1
}

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

is_prod_like_context() {
  local ctx="$1"
  [[ "$ctx" == *"gke_bbi-k8"* ]] || [[ "$ctx" == "prod" ]] || [[ "$ctx" == "production" ]] || [[ "$ctx" == "gke-prod" ]]
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verify) MODE="verify"; shift ;;
    --apply) MODE="apply"; shift ;;
    --context) K8S_CONTEXT="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --deploy) AUTHENTIK_DEPLOY="$2"; shift 2 ;;
    --client-id) CLIENT_ID="$2"; shift 2 ;;
    --env) TARGET_ENV="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

require_bool_01 "ALLOW_PROD_APPLY" "$ALLOW_PROD_APPLY"
require_bool_01 "CREATE_PREOP_BACKUP" "$CREATE_PREOP_BACKUP"
require_cmd kubectl

if [[ "$MODE" == "apply" ]]; then
  if [[ "$CONFIRM_ENSURE_AUTHENTIK_OIDC_REDIRECT_URIS" != "$CONFIRM_TOKEN" ]]; then
    echo "Refusing --apply without explicit confirmation token. Set CONFIRM_ENSURE_AUTHENTIK_OIDC_REDIRECT_URIS=${CONFIRM_TOKEN}" >&2
    exit 1
  fi

  if is_prod_like_context "$K8S_CONTEXT" && [[ "$ALLOW_PROD_APPLY" != "1" ]]; then
    echo "Refusing --apply on prod-like context '$K8S_CONTEXT' without ALLOW_PROD_APPLY=1" >&2
    exit 1
  fi

  if is_prod_like_context "$K8S_CONTEXT"; then
    if [[ "$CREATE_PREOP_BACKUP" == "1" ]]; then
      require_cmd velero
      backup_name="pre-op-${NAMESPACE}-ensure-authentik-redirect-uris-$(date -u +%Y%m%d-%H%M)"
      echo "Creating Velero pre-op backup: $backup_name"
      velero backup create "$backup_name" --include-namespaces "$NAMESPACE" --wait
    else
      echo "WARNING: CREATE_PREOP_BACKUP=0 on prod-like context '$K8S_CONTEXT' (operator override)"
    fi
  fi
fi

if [[ "$TARGET_ENV" != "all" && "$TARGET_ENV" != "prod" && "$TARGET_ENV" != "dev" && "$TARGET_ENV" != "staging" ]]; then
  echo "Invalid --env value: $TARGET_ENV (expected all|prod|dev|staging)" >&2
  exit 1
fi

expected_hosts=()
if [[ "$TARGET_ENV" == "all" || "$TARGET_ENV" == "prod" ]]; then
  expected_hosts+=(
    "$LMS_DOMAIN"
    "$PREVIEW_DOMAIN"
    "$BIJI_DOMAIN"
    "$SKILLOURFUTURE_DOMAIN"
  )
fi
if [[ "$TARGET_ENV" == "all" || "$TARGET_ENV" == "dev" ]]; then
  expected_hosts+=(
    "$DEV_LMS_DOMAIN"
    "$DEV_PREVIEW_DOMAIN"
  )
fi
if [[ "$TARGET_ENV" == "all" || "$TARGET_ENV" == "staging" ]]; then
  expected_hosts+=(
    "$STAGING_LMS_DOMAIN"
    "$STAGING_PREVIEW_DOMAIN"
  )
fi

expected_csv="$(printf "%s\n" "${expected_hosts[@]}" | awk 'NF{print}' | awk '!seen[$0]++' | paste -sd, -)"
if [[ -z "${expected_csv:-}" ]]; then
  echo "No expected hosts resolved from config; refusing to run." >&2
  exit 1
fi

echo "Mode: $MODE"
echo "Context: $K8S_CONTEXT"
echo "Namespace: $NAMESPACE"
echo "Deploy: $AUTHENTIK_DEPLOY"
echo "Client ID: $CLIENT_ID"
echo "Target env: $TARGET_ENV"
echo "Expected LMS hosts: $expected_csv"
echo ""

kubectl --context "$K8S_CONTEXT" exec -i -n "$NAMESPACE" "deploy/$AUTHENTIK_DEPLOY" -- \
  env MODE="$MODE" CLIENT_ID="$CLIENT_ID" EXPECTED_HOSTS_CSV="$expected_csv" \
  ak shell -c '
import os
from authentik.providers.oauth2.models import OAuth2Provider

mode = os.environ.get("MODE", "verify")
client_id = os.environ["CLIENT_ID"].strip()
expected_hosts = [h.strip() for h in os.environ.get("EXPECTED_HOSTS_CSV", "").split(",") if h.strip()]
expected_hosts = list(dict.fromkeys(expected_hosts))

prov = OAuth2Provider.objects.filter(client_id=client_id).order_by("-pk").first()
if not prov:
    raise SystemExit(f"OAuth2Provider not found for client_id={client_id}")

existing_raw = getattr(prov, "_redirect_uris", None) or []
existing_items = []
existing_urls_set = set()
for item in existing_raw:
    if isinstance(item, dict):
        url = str(item.get("url", "")).strip()
        mode_ = str(item.get("matching_mode", "")).strip()
        if url:
            existing_items.append({"url": url, "matching_mode": mode_ or "strict"})
            existing_urls_set.add(url)
    else:
        # Defensive: handle unexpected formats by stringifying.
        url = str(item).strip()
        if url:
            existing_items.append({"url": url, "matching_mode": "strict"})
            existing_urls_set.add(url)

want_urls = []
for host in expected_hosts:
    # Keep both variants (with and without trailing slash). Open edX typically uses the trailing slash.
    want_urls.append(f"https://{host}/auth/complete/oidc")
    want_urls.append(f"https://{host}/auth/complete/oidc/")
want_urls = list(dict.fromkeys(want_urls))

missing = [u for u in want_urls if u not in existing_urls_set]

def ok(msg): print("✓", msg)
def warn(msg): print("!", msg)

if not missing:
    ok("All required redirect URIs already present.")
    print("OK")
    raise SystemExit(0)

warn(f"Missing redirect URIs: {len(missing)}")
for u in missing:
    print("  -", u)

if mode == "verify":
    raise SystemExit(1)

# Apply (additive)
new_items = list(existing_items)
for u in missing:
    new_items.append({"url": u, "matching_mode": "strict"})

prov._redirect_uris = new_items
prov.save(update_fields=["_redirect_uris"])
ok(f"Added {len(missing)} redirect URIs.")
print("OK")
'
