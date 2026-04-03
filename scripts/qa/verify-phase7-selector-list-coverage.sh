#!/usr/bin/env bash
# Deprecated compatibility shim. Keep callers working while the readable
# operator-facing entrypoint moves to verify-mfe-selector-coverage.sh.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec "$REPO_ROOT/scripts/qa/verify-mfe-selector-coverage.sh" "$@"
