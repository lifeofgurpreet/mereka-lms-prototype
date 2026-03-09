#!/usr/bin/env bash
# disable-sso-nonprod.sh — Disable OAuth2/OIDC SSO providers on dev/staging sites.
#
# Per closure-truths.json: dev and staging do NOT use Authentik SSO.
# This script ensures no broken "Sign in with Mereka" button is visible.
#
# Usage:
#   ./scripts/tenants/disable-sso-nonprod.sh [--env dev|staging|both]
#
# Repeatable: safe to run multiple times (idempotent).
set -euo pipefail

ENV="${1:---env}"
ENV_VAL="${2:-both}"

if [[ "$ENV" == "--env" ]]; then
  ENV_VAL="${ENV_VAL}"
elif [[ "$ENV" =~ ^(dev|staging|both)$ ]]; then
  ENV_VAL="$ENV"
else
  echo "Usage: $0 [--env dev|staging|both]"
  exit 1
fi

DISABLE_SCRIPT='
from common.djangoapps.third_party_auth.models import OAuth2ProviderConfig
disabled = []
for c in OAuth2ProviderConfig.objects.filter(enabled=True):
    # Create a new config entry with enabled=False (OAuth2ProviderConfig uses
    # a history-based pattern where the latest entry per (site, slug) wins)
    c.enabled = False
    c.pk = None  # Force INSERT (new history entry)
    c.save()
    disabled.append(f"site_id={c.site_id} name={c.name} slug={c.slug}")
if disabled:
    for d in disabled:
        print(f"DISABLED: {d}")
else:
    print("NO_CHANGE: all providers already disabled")
'

run_in_namespace() {
  local ns="$1"
  local label="$2"
  echo "=== Disabling SSO providers in ${label} (${ns}) ==="
  kubectl exec -n "${ns}" deploy/lms -- python manage.py lms shell -c "${DISABLE_SCRIPT}" 2>&1 \
    | grep -E "^(DISABLED|NO_CHANGE):" || echo "ERROR: command failed"
}

if [[ "$ENV_VAL" == "dev" || "$ENV_VAL" == "both" ]]; then
  run_in_namespace "mereka-lms-dev" "dev"
fi

if [[ "$ENV_VAL" == "staging" || "$ENV_VAL" == "both" ]]; then
  run_in_namespace "stg-mereka-lms" "staging"
fi

echo ""
echo "Done. SSO providers disabled for ${ENV_VAL} environment(s)."
echo "Record: SSO intentionally disabled on dev/staging per closure-truths.json"
