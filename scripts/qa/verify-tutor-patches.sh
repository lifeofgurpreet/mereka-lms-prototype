#!/usr/bin/env bash
# Verify key Tutor patch artifacts exist in tutor_env/ output.
#
# This is a fast, repo-local check that assumes tutor_env/ has been generated.
# It does not run long builds; it only checks rendered files for required markers.
#
# Usage:
#   ./scripts/qa/verify-tutor-patches.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

failures=0
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }
pass() { echo "[PASS] $*"; }

require_file() {
  local f="$1"
  [[ -f "$f" ]] && pass "File present: $f" || fail "Missing file: $f"
}

require_grep() {
  local needle="$1"
  local f="$2"
  if [[ ! -f "$f" ]]; then
    fail "Missing file for grep: $f"
    return
  fi
  rg -n --fixed-strings -- "$needle" "$f" >/dev/null 2>&1 && pass "Found [$needle] in $f" || fail "Missing [$needle] in $f"
}

require_file "tutor_env/env/local/docker-compose.yml"
require_grep "mysql_native_password" "tutor_env/env/local/docker-compose.yml"

require_file "tutor_env/env/build/openedx/Dockerfile"
require_grep "NODE_OPTIONS=--max-old-space-size=6144" "tutor_env/env/build/openedx/Dockerfile"

require_file "tutor_env/env/apps/openedx/settings/lms/production.py"
require_grep "academy.biji-biji.com" "tutor_env/env/apps/openedx/settings/lms/production.py"
require_grep "skillourfuture.academy.mereka.io" "tutor_env/env/apps/openedx/settings/lms/production.py"
require_grep "mfe_oauth_fix" "tutor_env/env/apps/openedx/settings/lms/production.py"
require_grep "django_prometheus" "tutor_env/env/apps/openedx/settings/lms/production.py"

if [[ "$failures" -gt 0 ]]; then
  echo "FAIL ($failures check(s) failed)" >&2
  exit 1
fi
echo "OK"

