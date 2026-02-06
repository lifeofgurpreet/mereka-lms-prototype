#!/usr/bin/env bash
# Verify Authentik OIDC provider contains redirect URIs for every LMS hostname.
#
# Why:
# - Adding a new LMS hostname (microsite, alias like preview, or dev hostname) must
#   also be reflected in Authentik redirect URIs, otherwise OIDC login breaks with
#   redirect_uri mismatch.
#
# This is an internal operator check (kubectl required) and contains no secrets.
#
# Usage:
#   ./scripts/qa/verify-authentik-oidc-redirect-uris.sh
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
NAMESPACE="${NAMESPACE:-authentik}"
AUTHENTIK_DEPLOY="${AUTHENTIK_DEPLOY:-authentik-server}"

CLIENT_ID="${CLIENT_ID:-mereka-lms}"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }

# Expected LMS hosts that can start an OIDC flow.
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
  echo "No expected hosts resolved from config; refusing to verify." >&2
  exit 1
fi

log "Context=$K8S_CONTEXT namespace=$NAMESPACE deploy=$AUTHENTIK_DEPLOY client_id=$CLIENT_ID"
log "Expected LMS hosts: $expected_csv"

kubectl --context "$K8S_CONTEXT" exec -i -n "$NAMESPACE" "deploy/$AUTHENTIK_DEPLOY" -- \
  env CLIENT_ID="$CLIENT_ID" EXPECTED_HOSTS_CSV="$expected_csv" \
  ak shell -c '
import os, re
from authentik.providers.oauth2.models import OAuth2Provider

client_id = os.environ["CLIENT_ID"].strip()
expected_hosts = [h.strip() for h in os.environ.get("EXPECTED_HOSTS_CSV", "").split(",") if h.strip()]
expected_hosts = list(dict.fromkeys(expected_hosts))

prov = OAuth2Provider.objects.filter(client_id=client_id).order_by("-pk").first()
if not prov:
    raise SystemExit(f"OAuth2Provider not found for client_id={client_id}")

raw = prov.redirect_uris
if raw is None:
    uris = []
elif isinstance(raw, list):
    uris = [str(u).strip() for u in raw if str(u).strip()]
else:
    raw_s = str(raw).strip()
    uris = [u.strip() for u in re.split(r"[\\s\\n]+", raw_s) if u.strip()]
uris = list(dict.fromkeys(uris))

def ok(msg):
    print("✓", msg)

def fail(msg):
    print("✗", msg)

missing = []
warn = []
for host in expected_hosts:
    want = f"https://{host}/auth/complete/oidc/"
    if want in uris:
        ok(f"redirect_uri present: {want}")
        continue

    # Some configs may have the non-slash variant. That usually breaks auth if the request
    # uses the slash form, so warn loudly.
    alt = f"https://{host}/auth/complete/oidc"
    if alt in uris:
        warn.append((host, want, alt))
        ok(f"redirect_uri present (no trailing slash): {alt} (consider adding {want})")
        continue

    missing.append((host, want))
    fail(f"missing redirect_uri: {want}")

print("")
print(f"Provider: name={prov.name} pk={prov.pk} client_id={prov.client_id}")
print(f"Redirect URIs total={len(uris)}")

if warn:
    print("")
    print("WARN (no trailing slash variant found; recommend adding the slash form too):")
    for host, want, alt in warn:
        print(f"  - host={host} present={alt} recommended={want}")

if missing:
    raise SystemExit(f"FAILED: {len(missing)} expected redirect URIs missing")

print("")
print("OK")
'
