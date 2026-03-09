#!/usr/bin/env bash
# disable-sso-nonprod.sh — Disable OAuth2/OIDC SSO providers on non-prod sites.
#
# Current contract:
# - dev may disable Authentik SSO for local/nonprod recovery work
# - staging is expected to keep Authentik OIDC enabled and requires an explicit override
#
# Usage:
#   ./scripts/tenants/disable-sso-nonprod.sh [--env dev|staging]
#
# Safety:
#   ALLOW_STAGING_SSO_DISABLE=1 is required before targeting staging.
#
# Repeatable: safe to run multiple times (idempotent).
set -euo pipefail

ALLOW_STAGING_SSO_DISABLE="${ALLOW_STAGING_SSO_DISABLE:-0}"
ENV="${1:---env}"
ENV_VAL="${2:-dev}"

if [[ "$ENV" == "--env" ]]; then
  ENV_VAL="${ENV_VAL}"
elif [[ "$ENV" =~ ^(dev|staging)$ ]]; then
  ENV_VAL="$ENV"
else
  echo "Usage: $0 [--env dev|staging]"
  exit 1
fi

if [[ "$ALLOW_STAGING_SSO_DISABLE" != "0" && "$ALLOW_STAGING_SSO_DISABLE" != "1" ]]; then
  echo "ALLOW_STAGING_SSO_DISABLE must be 0 or 1" >&2
  exit 1
fi

if [[ "$ENV_VAL" == "staging" && "$ALLOW_STAGING_SSO_DISABLE" != "1" ]]; then
  echo "Refusing to disable staging SSO without ALLOW_STAGING_SSO_DISABLE=1" >&2
  echo "Staging is expected to keep Authentik OIDC enabled." >&2
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

if [[ "$ENV_VAL" == "dev" ]]; then
  run_in_namespace "mereka-lms-dev" "dev"
fi

if [[ "$ENV_VAL" == "staging" ]]; then
  run_in_namespace "stg-mereka-lms" "staging"
fi

echo ""
echo "Done. SSO providers disabled for ${ENV_VAL} environment(s)."
if [[ "$ENV_VAL" == "staging" ]]; then
  echo "Record: staging override used with ALLOW_STAGING_SSO_DISABLE=1"
else
  echo "Record: dev SSO intentionally disabled for nonprod recovery work"
fi
