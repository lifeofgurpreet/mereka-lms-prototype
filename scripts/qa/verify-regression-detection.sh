#!/usr/bin/env bash
# Regression detection wrapper for critical user-facing surfaces.
#
# Usage:
#   ./scripts/qa/verify-regression-detection.sh --env prod
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

ENV_SCOPE="prod"
if [[ "${1:-}" == "--env" ]]; then
  ENV_SCOPE="${2:-}"; shift 2
fi

case "$ENV_SCOPE" in
  prod|dev) ;;
  *) echo "Invalid --env: $ENV_SCOPE (expected prod|dev)" >&2; exit 2 ;;
esac

# Public surface sanity.
./scripts/qa/verify-auth-surfaces.sh "$ENV_SCOPE"
./scripts/qa/public-health-check.sh "$ENV_SCOPE"

echo "OK"

