#!/usr/bin/env bash
# verify-wcag-contrast-v2.sh — compatibility wrapper for contrast verifier
#
# Keeps Phase C command contracts stable while delegating to canonical logic.
# Usage: ./scripts/qa/verify-wcag-contrast-v2.sh
set -euo pipefail

exec "$(dirname "${BASH_SOURCE[0]}")/verify-contrast-compliance.sh" "$@"
