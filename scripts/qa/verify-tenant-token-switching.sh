#!/usr/bin/env bash
# @covers AC-MTA-008, AC-MTA-009, AC-MTA-010, AC-MTA-011
# @spec: multi-tenancy-architecture_spec.md
#
# Verifies per-tenant token switching pipeline:
# 1) sync-tenant-branding.sh can generate tenants/{slug}/css/tokens.css from brand-pack JSON
# 2) generated CSS contains canonical runtime token overrides
# 3) legacy site_configuration JSON payloads remain supported
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SYNC_SCRIPT="$REPO_ROOT/scripts/tenants/sync-tenant-branding.sh"
MODERN_TEMPLATE="$REPO_ROOT/scripts/tenants/brand-pack-template.json"
LEGACY_TEMPLATE="$REPO_ROOT/scripts/tenants/acme-branding.json"

PASS=0
FAIL=0

pass() {
  echo "PASS: $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "FAIL: $1"
  FAIL=$((FAIL + 1))
}

require_file() {
  local path="$1"
  local label="$2"
  if [[ -f "$path" ]]; then
    pass "$label exists"
  else
    fail "$label missing: $path"
  fi
}

require_grep() {
  local pattern="$1"
  local path="$2"
  local label="$3"
  if grep -qE -- "$pattern" "$path"; then
    pass "$label"
  else
    fail "$label (pattern '$pattern' not found in $path)"
  fi
}

echo "=== Tenant Token Switching Verification ==="

require_file "$SYNC_SCRIPT" "sync-tenant-branding.sh"
require_file "$MODERN_TEMPLATE" "Modern brand template"
require_file "$LEGACY_TEMPLATE" "Legacy brand template"

if [[ ! -x "$SYNC_SCRIPT" ]]; then
  fail "sync-tenant-branding.sh is not executable"
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
TENANTS_ROOT="$WORKDIR/tenants"
mkdir -p "$TENANTS_ROOT"

# Case 1: modern brand-pack JSON format.
MODERN_SLUG="tenant-modern"
"$SYNC_SCRIPT" \
  --slug "$MODERN_SLUG" \
  --base-dir "$TENANTS_ROOT" \
  --branding-file "$MODERN_TEMPLATE" >/dev/null

MODERN_TOKENS="$TENANTS_ROOT/$MODERN_SLUG/css/tokens.css"
require_file "$MODERN_TOKENS" "Modern tenant tokens.css"
require_grep '^:root \{' "$MODERN_TOKENS" "Modern tokens.css has :root block"
require_grep '--tenant-color-primary: #ff5733;' "$MODERN_TOKENS" "Modern primary color mapped"
require_grep '--tenant-color-secondary: #ffc300;' "$MODERN_TOKENS" "Modern secondary color mapped"
require_grep '--tenant-color-accent: #c70039;' "$MODERN_TOKENS" "Modern accent color mapped"
require_grep '--pgn-color-primary-base: var\(--tenant-color-primary\);' "$MODERN_TOKENS" "Modern Paragon primary bridge"
require_grep '--pgn-color-secondary-base: var\(--tenant-color-secondary\);' "$MODERN_TOKENS" "Modern Paragon secondary bridge"

# Case 2: legacy SiteConfiguration JSON format.
LEGACY_SLUG="tenant-legacy"
"$SYNC_SCRIPT" \
  --slug "$LEGACY_SLUG" \
  --base-dir "$TENANTS_ROOT" \
  --branding-file "$LEGACY_TEMPLATE" >/dev/null

LEGACY_TOKENS="$TENANTS_ROOT/$LEGACY_SLUG/css/tokens.css"
require_file "$LEGACY_TOKENS" "Legacy tenant tokens.css"
require_grep '--tenant-color-primary: #e63946;' "$LEGACY_TOKENS" "Legacy primary color mapped"
require_grep '--tenant-color-secondary: #457b9d;' "$LEGACY_TOKENS" "Legacy secondary color mapped"
require_grep '--mereka-color-magenta: var\(--tenant-color-primary\);' "$LEGACY_TOKENS" "Legacy Mereka bridge"

echo ""
echo "=== Summary: PASS=$PASS FAIL=$FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
