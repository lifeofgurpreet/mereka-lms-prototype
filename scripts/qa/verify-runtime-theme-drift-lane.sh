#!/usr/bin/env bash
# verify-runtime-theme-drift-lane.sh — enforce runtime-theme drift diagnosis lane wiring.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MAKEFILE="$REPO_ROOT/Makefile"

echo "Checking runtime-theme drift lane contract..."

violations=0

require_exec() {
  local rel="$1"
  if [[ ! -x "$REPO_ROOT/$rel" ]]; then
    echo "❌ Missing executable: $rel"
    violations=1
  fi
}

require_target() {
  local target="$1"
  if ! rg -n "^${target}:" "$MAKEFILE" >/dev/null; then
    echo "❌ Missing Make target: $target"
    violations=1
  fi
}

require_line() {
  local line="$1"
  local label="$2"
  if ! rg -n --fixed-strings "$line" "$MAKEFILE" >/dev/null; then
    echo "❌ Makefile wiring mismatch: $label"
    echo "   Expected line: $line"
    violations=1
  fi
}

if [[ ! -f "$MAKEFILE" ]]; then
  echo "❌ Missing Makefile"
  exit 1
fi

require_exec "scripts/qa/diagnose-runtime-theme-drift.sh"
require_exec "scripts/infra/sync-vendored-mfe-caddyfile.sh"
require_exec "scripts/infra/sync-gitops-prod-image-tags.sh"

require_target "qa-runtime-theme-mode-prod"
require_target "qa-runtime-theme-mode-dev"
require_target "qa-runtime-theme-drift-diagnose"
require_target "infra-sync-vendored-mfe-caddyfile"
require_target "infra-sync-gitops-prod-tags"

require_line \
  "./scripts/qa/diagnose-runtime-theme-drift.sh" \
  "qa-runtime-theme-drift-diagnose delegates to diagnose-runtime-theme-drift.sh"
require_line \
  "./scripts/infra/sync-vendored-mfe-caddyfile.sh" \
  "infra-sync-vendored-mfe-caddyfile delegates to sync-vendored-mfe-caddyfile.sh"
require_line \
  "./scripts/infra/sync-gitops-prod-image-tags.sh" \
  "infra-sync-gitops-prod-tags delegates to sync-gitops-prod-image-tags.sh"

HELP_OUTPUT="$(make help 2>/dev/null || true)"
if [[ -z "$HELP_OUTPUT" ]]; then
  echo "❌ make help produced no output"
  violations=1
else
  for entry in \
    "qa-runtime-theme-drift-diagnose" \
    "infra-sync-vendored-mfe-caddyfile" \
    "infra-sync-gitops-prod-tags"; do
    if ! grep -Fq -- "$entry" <<<"$HELP_OUTPUT"; then
      echo "❌ make help missing target entry: $entry"
      violations=1
    fi
  done
fi

if [[ "$violations" -ne 0 ]]; then
  echo "Runtime-theme drift lane contract failed."
  exit 1
fi

echo "✅ Runtime-theme drift lane contract passed."
