#!/usr/bin/env bash
# @covers AC-MTA-030 (tenant domain migration — Stage 2 runtime exec)
# @spec: multi-tenancy-architecture_spec.md
# @runbook: docs/ops/runbooks/TENANT_DOMAIN_MIGRATION.md
#
# Apply Stage 2 of the tenant domain migration runbook to a live cluster.
#
# Stage 2 is the runtime-only slice: add the NEW tree to SiteConfiguration +
# OAuth2 Application redirect URIs so that when Stage 4 flips the primary,
# the data plane is already prepared. No primary flip happens here — both
# trees serve traffic.
#
# Authentik runtime changes are documented but NOT executed by this script;
# Authentik admin is a separate credentialed surface that belongs on the
# infra side of the boundary.
#
# Usage:
#   scripts/tenants/migrate-tenant-domain.sh \
#     --tenant <slug> \
#     --old-lms-host <old-lms-fqdn> \
#     --new-lms-host <new-lms-fqdn> \
#     --new-studio-host <new-studio-fqdn> \
#     --new-mfe-host <new-mfe-fqdn> \
#     --env <dev|staging|prod> \
#     [--dry-run]
#
# Example (SOF Stage 2 prod):
#   scripts/tenants/migrate-tenant-domain.sh \
#     --tenant skillourfuture \
#     --old-lms-host skillourfuture.academy.mereka.io \
#     --new-lms-host skillourfuture.academyv2.mereka.io \
#     --new-studio-host studio.skillourfuture.academyv2.mereka.io \
#     --new-mfe-host apps.skillourfuture.academyv2.mereka.io \
#     --env prod
#
# Exit codes:
#   0 — all runtime changes applied (or would be applied in --dry-run)
#   1 — argument parse / validation error
#   2 — cluster access / kubectl pod resolution failed
#   3 — Django management command failed
#   4 — OAuth2 Application update failed
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../shared/config.sh
source "${REPO_ROOT}/scripts/shared/config.sh"

TENANT=""
OLD_LMS_HOST=""
NEW_LMS_HOST=""
NEW_STUDIO_HOST=""
NEW_MFE_HOST=""
ENVIRONMENT="dev"
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage: migrate-tenant-domain.sh [OPTIONS]

Required:
  --tenant <slug>               Tenant slug (e.g. skillourfuture)
  --old-lms-host <fqdn>         Current LMS host (dual-active; kept)
  --new-lms-host <fqdn>         Target LMS host (being added)
  --new-studio-host <fqdn>      Target Studio host
  --new-mfe-host <fqdn>         Target MFE/apps host
  --env <dev|staging|prod>      Cluster environment

Options:
  --dry-run                     Print planned commands without executing
  -h, --help                    This help
USAGE
}

while (( $# > 0 )); do
  case "$1" in
    --tenant) TENANT="${2:-}"; shift 2 ;;
    --old-lms-host) OLD_LMS_HOST="${2:-}"; shift 2 ;;
    --new-lms-host) NEW_LMS_HOST="${2:-}"; shift 2 ;;
    --new-studio-host) NEW_STUDIO_HOST="${2:-}"; shift 2 ;;
    --new-mfe-host) NEW_MFE_HOST="${2:-}"; shift 2 ;;
    --env) ENVIRONMENT="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

for var in TENANT OLD_LMS_HOST NEW_LMS_HOST NEW_STUDIO_HOST NEW_MFE_HOST ENVIRONMENT; do
  if [[ -z "${!var}" ]]; then
    echo "Missing required: --${var,,}" | tr _ - >&2
    usage
    exit 1
  fi
done

case "${ENVIRONMENT}" in
  dev)     NAMESPACE="mereka-lms-dev" ;;
  staging) NAMESPACE="stg-mereka-lms" ;;
  prod)    NAMESPACE="mereka-lms" ;;
  *)       echo "Unknown env: ${ENVIRONMENT}" >&2; exit 1 ;;
esac

echo "== Tenant Domain Migration — Stage 2 runtime exec ==" >&2
echo "  tenant        : ${TENANT}" >&2
echo "  env           : ${ENVIRONMENT} (ns=${NAMESPACE})" >&2
echo "  old-lms       : ${OLD_LMS_HOST}" >&2
echo "  new-lms       : ${NEW_LMS_HOST}" >&2
echo "  new-studio    : ${NEW_STUDIO_HOST}" >&2
echo "  new-mfe       : ${NEW_MFE_HOST}" >&2
[[ "${DRY_RUN}" == 1 ]] && echo "  (dry-run mode — no changes applied)" >&2
echo >&2

# -----------------------------------------------------------------
# Resolve a running LMS pod for exec operations.
# -----------------------------------------------------------------
echo "→ Resolving LMS pod in ${NAMESPACE}…" >&2
LMS_POD="$(kubectl -n "${NAMESPACE}" get pod -l app.kubernetes.io/name=lms \
  -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' 2>/dev/null \
  | awk '{print $1}')"
if [[ -z "${LMS_POD}" ]]; then
  echo "ERROR: no running LMS pod found in ${NAMESPACE}" >&2
  exit 2
fi
echo "  LMS_POD=${LMS_POD}" >&2

# -----------------------------------------------------------------
# Step 1 — SiteConfiguration: add NEW rows (keep OLD)
# -----------------------------------------------------------------
# There are two SiteConfiguration rows per tenant in this platform:
#   - LMS host row   (e.g. skillourfuture.academy.mereka.io)
#   - apps host row  (e.g. apps.skillourfuture.academyv2.mereka.io)
# Stage 2 adds the NEW LMS and apps rows as SECONDARY (not yet primary).
# The MFE config API resolves off the apps host row, so existing flows
# keep working via the OLD rows.
# -----------------------------------------------------------------
echo "→ Step 1: SiteConfiguration rows for NEW tree" >&2
python_cmd="$(cat <<PY
from django.contrib.sites.models import Site
from openedx.core.djangoapps.site_configuration.models import SiteConfiguration
import json

targets = [
    ("${NEW_LMS_HOST}", "${TENANT} — new LMS host"),
    ("${NEW_STUDIO_HOST}", "${TENANT} — new Studio host"),
    ("${NEW_MFE_HOST}", "${TENANT} — new MFE host"),
]
for domain, name in targets:
    site, site_created = Site.objects.get_or_create(domain=domain, defaults={"name": name})
    # Copy SiteConfiguration values from the OLD LMS row if one exists.
    old_sc = SiteConfiguration.objects.filter(site__domain="${OLD_LMS_HOST}").first()
    sc, sc_created = SiteConfiguration.objects.get_or_create(
        site=site,
        defaults={
            "enabled": True,
            "site_values": (old_sc.site_values if old_sc else {}),
        },
    )
    print(json.dumps({
        "domain": domain,
        "site_created": site_created,
        "siteconfig_created": sc_created,
        "enabled": sc.enabled,
    }))
PY
)"

if [[ "${DRY_RUN}" == 1 ]]; then
  echo "  [dry-run] would exec LMS shell_plus with SiteConfiguration upserts for 3 hosts" >&2
else
  # shell_plus preferred (already-imported models); fall back to shell.
  echo "${python_cmd}" | kubectl -n "${NAMESPACE}" exec -i "${LMS_POD}" -- \
    python manage.py lms shell_plus --quiet-load 2>&1 \
    | tee /tmp/migrate-tenant-domain.siteconfig.$$.log \
    || { echo "ERROR: SiteConfiguration upsert failed" >&2; exit 3; }
fi

# -----------------------------------------------------------------
# Step 2 — OAuth2 Application: add NEW URLs to redirect_uris
# -----------------------------------------------------------------
# Applications to touch (typical Open edX + Mereka):
#   - LMS OAuth provider (edx-oauth2)
#   - CMS SSO client (cms-sso)
#   - Any tenant-specific MFE client (rare)
# We append NEW URLs to redirect_uris without removing OLD.
# -----------------------------------------------------------------
echo "→ Step 2: OAuth2 Application redirect_uris" >&2
python_cmd_oauth="$(cat <<PY
from oauth2_provider.models import Application
import json

new_entries = [
    "https://${NEW_LMS_HOST}/complete/edx-oauth2",
    "https://${NEW_LMS_HOST}/auth/complete/edx-oauth2",
    "https://${NEW_STUDIO_HOST}/complete/edx-oauth2",
    "https://${NEW_MFE_HOST}/authn/complete",
    "https://${NEW_MFE_HOST}/authn/login",
]

# Iterate all Applications — in Open edX most are tenant-scoped via the
# "user" FK but redirect_uris are a free-form whitelist per client.
for app in Application.objects.all():
    current = (app.redirect_uris or "").strip().split()
    changed = False
    for entry in new_entries:
        if entry not in current:
            current.append(entry)
            changed = True
    if changed:
        app.redirect_uris = " ".join(current)
        app.save(update_fields=["redirect_uris"])
    print(json.dumps({
        "client_id": app.client_id,
        "name": app.name,
        "redirect_uris_count": len(current),
        "changed": changed,
    }))
PY
)"

if [[ "${DRY_RUN}" == 1 ]]; then
  echo "  [dry-run] would append 5 NEW redirect URIs to every OAuth2 Application" >&2
else
  echo "${python_cmd_oauth}" | kubectl -n "${NAMESPACE}" exec -i "${LMS_POD}" -- \
    python manage.py lms shell_plus --quiet-load 2>&1 \
    | tee /tmp/migrate-tenant-domain.oauth.$$.log \
    || { echo "ERROR: OAuth2 Application update failed" >&2; exit 4; }
fi

# -----------------------------------------------------------------
# Step 3 — Authentik OIDC whitelist (manual)
# -----------------------------------------------------------------
cat <<EOF >&2

→ Step 3: Authentik OIDC Application — manual action required

  Go to Authentik admin → Applications → <tenant>-lms Provider → Redirect URIs.
  Add the following entries (keep existing entries):

    https://${NEW_LMS_HOST}/complete/edx-oauth2
    https://${NEW_LMS_HOST}/auth/complete/edx-oauth2
    https://${NEW_STUDIO_HOST}/complete/edx-oauth2
    https://${NEW_MFE_HOST}/authn/complete
    https://${NEW_MFE_HOST}/authn/login

  Do NOT remove existing redirect URIs for the OLD tree (that's Stage 6).

EOF

# -----------------------------------------------------------------
# Step 4 — Post-apply verification probes
# -----------------------------------------------------------------
echo "→ Step 4: post-apply verification probes" >&2
if [[ "${DRY_RUN}" == 1 ]]; then
  echo "  [dry-run] would probe NEW + OLD URLs" >&2
else
  echo "  Probing MFE config API on NEW MFE host…" >&2
  curl -sSf "https://${NEW_MFE_HOST}/api/mfe_config/v1/?mfe=learning" \
    | python3 -c 'import json,sys; d=json.load(sys.stdin); print("  LMS_BASE_URL:", d.get("LMS_BASE_URL","?"))' \
    || echo "  NOTE: MFE config API probe failed (may be expected if DNS not yet cut)" >&2

  echo "  Probing MFE config API on OLD LMS host (should still serve)…" >&2
  curl -sSf "https://${OLD_LMS_HOST}/api/mfe_config/v1/?mfe=learning" \
    | python3 -c 'import json,sys; d=json.load(sys.stdin); print("  LMS_BASE_URL:", d.get("LMS_BASE_URL","?"))' \
    || echo "  WARN: OLD-host MFE config API probe failed — investigate" >&2
fi

echo >&2
echo "== Stage 2 runtime changes complete ==" >&2
echo "Next: 14-day soak period (Stage 3), then Stage 4 cut." >&2
echo "Ledger: docs/status/active/TENANT_MIGRATION_<tenant>.md" >&2
