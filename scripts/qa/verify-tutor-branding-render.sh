#!/usr/bin/env bash
# @covers AC-009
# @spec: tutor-configuration_spec.md
# Verify Tutor-rendered theme assets are present in the build context.
#
# This is a file-level check only; it does not validate browser rendering.
#
# Usage:
#   ./scripts/qa/verify-tutor-branding-render.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

failures=0
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }
pass() { echo "[PASS] $*"; }

need() {
  local p="$1"
  [[ -e "$p" ]] && pass "Present: $p" || fail "Missing: $p"
}

# Theme build context (Tutor-rendered) — only present after 'tutor config save' +
# 'apply-patches.sh' has run AND the Mereka theme is copied into the build context.
# tutor_env/ is gitignored; CI and fresh clones skip this check.
if [[ -d "tutor_env/env/build/openedx/themes/mereka" ]]; then
  pass "Present: tutor_env/env/build/openedx/themes/mereka"
else
  echo "[SKIP] tutor_env/env/build/openedx/themes/mereka not present — run 'tutor config save' then 'apply-patches.sh'"
fi

# Runtime override CSS should exist (synced from assets/branding).
need "infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css"
need "infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css"
need "infrastructure/tutor/themes/mereka/cms/static/css/mereka-overrides.css"

# Basic logo assets (source-of-truth location).
need "assets/branding/logo.svg"
need "assets/branding/favicon.ico"

if [[ "$failures" -gt 0 ]]; then
  echo "FAIL ($failures issue(s))" >&2
  exit 1
fi
echo "OK"

