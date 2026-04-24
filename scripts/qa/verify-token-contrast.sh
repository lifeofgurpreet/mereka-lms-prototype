#!/usr/bin/env bash
# verify-token-contrast.sh — compatibility wrapper for verify-contrast-compliance.sh
# @covers AC-UIA11Y-003
#
# This script exists to satisfy acceptance criteria that expect a script named
# "verify-token-contrast.sh". It delegates all work to verify-contrast-compliance.sh
# to avoid code duplication.
#
# Usage: ./scripts/qa/verify-token-contrast.sh
set -euo pipefail

exec "$(dirname "${BASH_SOURCE[0]}")/verify-contrast-compliance.sh" "$@"
