#!/usr/bin/env bash
# Ensure SiteConfiguration overrides do not force cross-origin login_refresh calls.
#
# Problem:
# - MFEs fetch REFRESH_ACCESS_TOKEN_ENDPOINT from /api/mfe_config/v1.
# - In production we historically stored REFRESH_ACCESS_TOKEN_ENDPOINT as an absolute LMS URL
#   inside SiteConfiguration.site_values["MFE_CONFIG"] per domain.
# - Many MFE stacks use fetch/Axios with credentials="same-origin" by default, so cross-origin
#   refresh calls silently drop cookies and users get stuck in login loops.
#
# Fix:
# - Set REFRESH_ACCESS_TOKEN_ENDPOINT to "/login_refresh" (relative path) for all enabled sites.
# - The MFE edge (apps.*) must reverse-proxy /login_refresh back to LMS.
#
# Safe: updates a single JSON key under SiteConfiguration.site_values; no secrets are printed.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

KUBE_CONTEXT="${KUBE_CONTEXT:-$K8S_CONTEXT}"
NAMESPACE="${NAMESPACE:-$K8S_NAMESPACE}"

echo "Context: $KUBE_CONTEXT"
echo "Namespace: $NAMESPACE"

echo "Patching SiteConfiguration MFE_CONFIG.REFRESH_ACCESS_TOKEN_ENDPOINT -> /login_refresh ..."

kubectl --context "$KUBE_CONTEXT" -n "$NAMESPACE" exec deploy/lms -- bash -lc '
set -euo pipefail
cd /openedx/edx-platform
CODE=$(cat <<"PY"
from openedx.core.djangoapps.site_configuration.models import SiteConfiguration

updated = []
for sc in SiteConfiguration.objects.filter(enabled=True):
    sv = sc.site_values or {}
    mfe = sv.get("MFE_CONFIG") or {}
    old = mfe.get("REFRESH_ACCESS_TOKEN_ENDPOINT")
    if old != "/login_refresh":
        mfe["REFRESH_ACCESS_TOKEN_ENDPOINT"] = "/login_refresh"
        sv["MFE_CONFIG"] = mfe
        sc.site_values = sv
        sc.save()
        updated.append((sc.site.domain, old))

print("updated", len(updated))
for d, o in updated:
    print(d, "was", o)
PY
)
./manage.py lms shell -c "$CODE"
'

echo ""
echo "Verifying public MFE config endpoints..."

primary_refresh="$(curl -fsSL "https://${MFE_DOMAIN}/api/mfe_config/v1" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("REFRESH_ACCESS_TOKEN_ENDPOINT",""))')"
echo "apps.${LMS_DOMAIN} REFRESH_ACCESS_TOKEN_ENDPOINT=$primary_refresh"

biji_refresh="$(curl -fsSL "https://${BIJI_MFE_DOMAIN}/api/mfe_config/v1" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("REFRESH_ACCESS_TOKEN_ENDPOINT",""))')"
echo "apps.${BIJI_DOMAIN} REFRESH_ACCESS_TOKEN_ENDPOINT=$biji_refresh"

if [[ "$primary_refresh" != "/login_refresh" || "$biji_refresh" != "/login_refresh" ]]; then
  echo "ERROR: One or more domains still return a non-relative refresh endpoint." >&2
  exit 1
fi

echo "OK"

