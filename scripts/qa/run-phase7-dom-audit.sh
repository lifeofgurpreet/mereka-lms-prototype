#!/usr/bin/env bash
# run-phase7-dom-audit.sh — canonical wrapper for strict runtime DOM selector audits.
#
# This wrapper pins the audit profile to `phase7_strict` and forwards all
# additional flags to verify-mfe-live-dom-audit.sh.
#
# Examples:
#   ./scripts/qa/run-phase7-dom-audit.sh --env prod --project chromium
#   ./scripts/qa/run-phase7-dom-audit.sh --env dev --allow-unbranded-shell
#   ./scripts/qa/run-phase7-dom-audit.sh --help
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VERIFY_SCRIPT="$REPO_ROOT/scripts/qa/verify-mfe-live-dom-audit.sh"

if [[ ! -x "$VERIFY_SCRIPT" ]]; then
  echo "ERROR: missing executable script: $VERIFY_SCRIPT" >&2
  exit 1
fi

exec "$VERIFY_SCRIPT" --audit-profile phase7_strict "$@"
