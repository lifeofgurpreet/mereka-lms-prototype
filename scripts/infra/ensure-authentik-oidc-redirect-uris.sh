#!/usr/bin/env bash
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

K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
NAMESPACE="${NAMESPACE:-authentik}"
AUTHENTIK_DEPLOY="${AUTHENTIK_DEPLOY:-authentik-server}"

CLIENT_ID="${CLIENT_ID:-mereka-lms}"

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
  -h, --help                Show help
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verify) MODE="verify"; shift ;;
    --apply) MODE="apply"; shift ;;
    --context) K8S_CONTEXT="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --deploy) AUTHENTIK_DEPLOY="$2"; shift 2 ;;
    --client-id) CLIENT_ID="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

expected_hosts=(
  "$LMS_DOMAIN"
  "$PREVIEW_DOMAIN"
  "$BIJI_DOMAIN"
  "$SKILLOURFUTURE_DOMAIN"
  "$DEV_LMS_DOMAIN"
  "$DEV_PREVIEW_DOMAIN"
)

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
