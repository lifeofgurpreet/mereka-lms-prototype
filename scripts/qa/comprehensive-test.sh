#!/usr/bin/env bash
# Compatibility wrapper for the retired comprehensive local test entrypoint.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

cat <<'MSG'
INFO: scripts/qa/comprehensive-test.sh is retired.
INFO: Running the canonical initialized local setup verifier instead:
INFO:   ./scripts/qa/verify-setup.sh
MSG

exec "$REPO_ROOT/scripts/qa/verify-setup.sh"
