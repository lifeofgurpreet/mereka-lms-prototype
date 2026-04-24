#!/usr/bin/env bash
# Wrapper for legacy repair-staging-routing.sh (production + dev share same routing fix)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/repair-staging-routing.sh" "$@"
