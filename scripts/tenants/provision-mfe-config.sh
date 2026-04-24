#!/usr/bin/env bash
# @covers AC-MTA-015, AC-MTA-016, AC-MTA-017
# @spec: multi-tenancy-architecture_spec.md
# Retired compatibility shim for the legacy per-tenant MFE config writer.
#
# The canonical runtime mutation path for SiteConfiguration/MFE_CONFIG is now:
#   ./scripts/infra/apply-multisite-config.sh --env <prod|dev|staging> --dry-run
#   ./scripts/infra/apply-multisite-config.sh --env <prod|dev|staging> --apply
#
# Verify live tenant MFE config with:
#   ./scripts/qa/verify-mfe-config-api.sh --live --env <dev|staging|production>
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CANONICAL_APPLY="${REPO_ROOT}/scripts/infra/apply-multisite-config.sh"
CANONICAL_VERIFY="${REPO_ROOT}/scripts/qa/verify-mfe-config-api.sh"

print_help() {
  cat <<EOF
Usage: $0 --help

Retired compatibility shim.

This script no longer performs direct SiteConfiguration or MFE_CONFIG mutation.
Use the canonical multisite apply flow instead:

  ./scripts/infra/apply-multisite-config.sh --env <prod|dev|staging> --dry-run
  ./scripts/infra/apply-multisite-config.sh --env <prod|dev|staging> --apply

Then verify the live result with:

  ./scripts/qa/verify-mfe-config-api.sh --live --env <dev|staging|production>

Replacement entrypoints:
  Apply:  ${CANONICAL_APPLY}
  Verify: ${CANONICAL_VERIFY}
EOF
}

reject_legacy_invocation() {
  cat >&2 <<EOF
ERROR: provision-mfe-config.sh is a retired compatibility shim and no longer performs direct SiteConfiguration mutation.
Legacy invocation: $*

Use the canonical multisite apply flow instead:
  ./scripts/infra/apply-multisite-config.sh --env <prod|dev|staging> --dry-run
  ./scripts/infra/apply-multisite-config.sh --env <prod|dev|staging> --apply

Then verify the live tenant MFE config with:
  ./scripts/qa/verify-mfe-config-api.sh --live --env <dev|staging|production>
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
