#!/usr/bin/env bash
# Retired compatibility shim for the legacy refresh-endpoint SiteConfiguration patcher.
#
# The canonical writer for REFRESH_ACCESS_TOKEN_ENDPOINT is the multisite apply flow:
#   ./scripts/infra/apply-multisite-config.sh --env <prod|dev|staging> --dry-run
#   ./scripts/infra/apply-multisite-config.sh --env <prod|dev|staging> --apply
#
# That flow delegates to scripts/shared/multisite_bootstrap_django.py, which already
# sets REFRESH_ACCESS_TOKEN_ENDPOINT=/login_refresh in the authoritative SiteConfiguration
# overlay.
#
# Verify the live result with:
#   ./scripts/qa/verify-auth-surfaces.sh prod
#   ./scripts/qa/verify-mfe-config-contract.sh --env prod
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CANONICAL_APPLY="${REPO_ROOT}/scripts/infra/apply-multisite-config.sh"

print_help() {
  cat <<EOF
Usage: $0 --help

Retired compatibility shim.

This script no longer patches SiteConfiguration directly.
Use the canonical multisite apply flow instead:

  ./scripts/infra/apply-multisite-config.sh --env <prod|dev|staging> --dry-run
  ./scripts/infra/apply-multisite-config.sh --env <prod|dev|staging> --apply

The canonical writer already sets:
  REFRESH_ACCESS_TOKEN_ENDPOINT=/login_refresh

Verify the live result with:

  ./scripts/qa/verify-auth-surfaces.sh prod
  ./scripts/qa/verify-mfe-config-contract.sh --env prod

Replacement entrypoint:
  ${CANONICAL_APPLY}
EOF
}

reject_legacy_invocation() {
  cat >&2 <<EOF
ERROR: fix-mfe-refresh-endpoint-site-config.sh is a retired compatibility shim and no longer patches SiteConfiguration directly.
Legacy invocation: $*

Use the canonical multisite apply flow instead:
  ./scripts/infra/apply-multisite-config.sh --env <prod|dev|staging> --dry-run
  ./scripts/infra/apply-multisite-config.sh --env <prod|dev|staging> --apply

Then verify the public MFE config/auth surfaces with:
  ./scripts/qa/verify-auth-surfaces.sh prod
  ./scripts/qa/verify-mfe-config-contract.sh --env prod
EOF
  exit 2
}

if [[ $# -eq 0 ]]; then
  reject_legacy_invocation "(no arguments)"
fi

case "$1" in
  -h|--help)
    print_help
    exit 0
    ;;
  *)
    reject_legacy_invocation "$@"
    ;;
esac
