#!/usr/bin/env bash
# run-phase7-dom-audit-full.sh — expanded runtime DOM selector audit wrapper.
#
# Pins audit profile to `phase7_full` (multi-route + expanded selector file),
# then forwards all additional arguments to verify-mfe-live-dom-audit.sh.
#
# Examples:
#   ./scripts/qa/run-phase7-dom-audit-full.sh --env prod --project chromium
#   ./scripts/qa/run-phase7-dom-audit-full.sh --env dev --allow-unbranded-shell
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VERIFY_SCRIPT="$REPO_ROOT/scripts/qa/verify-mfe-live-dom-audit.sh"

if [[ ! -x "$VERIFY_SCRIPT" ]]; then
  echo "ERROR: missing executable script: $VERIFY_SCRIPT" >&2
  exit 1
fi

exec "$VERIFY_SCRIPT" --audit-profile phase7_full "$@"
