#!/usr/bin/env bash
# @spec: slo-sla-service-level-management_spec.md
# @covers: AC-010, AC-011, AC-012
# Wrapper that delegates to scripts/infra/check-error-budget-gate.sh.
#
# Usage:
#   ./scripts/qa/check-error-budget-gate.sh [--service <name>] [--override <reason>]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec "$ROOT_DIR/scripts/infra/check-error-budget-gate.sh" "$@"
