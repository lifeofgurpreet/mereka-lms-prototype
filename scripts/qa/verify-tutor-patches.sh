#!/usr/bin/env bash
# @covers AC-001, AC-002, AC-003, AC-004, AC-005
# @spec: tutor-configuration_spec.md
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

TUTOR_ROOT="${TUTOR_ROOT:-$ROOT_DIR/tutor_env}"
if [[ ! -d "$TUTOR_ROOT/env" ]]; then
  echo "SKIP: Tutor env not found at $TUTOR_ROOT (set TUTOR_ROOT or run tutor config save)"
  exit 0
fi

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
require_grep "NODE_OPTIONS=\"--max-old-space-size=6144\"" "tutor_env/env/build/openedx/Dockerfile"
require_grep "COPY --chown=app:app ./infrastructure/tutor/custom-apps/openedx_video_pipeline /openedx/openedx_video_pipeline" "tutor_env/env/build/openedx/Dockerfile"

require_file "tutor_env/env/plugins/mfe/build/mfe/Dockerfile"
python3 - <<'PY'
from pathlib import Path
import sys

dockerfile = Path("tutor_env/env/plugins/mfe/build/mfe/Dockerfile")
if not dockerfile.exists():
    print("[FAIL] Missing tutor_env/env/plugins/mfe/build/mfe/Dockerfile")
    sys.exit(1)

content = dockerfile.read_text(encoding="utf-8")
parts = content.split("AS production", 1)
if len(parts) != 2:
    print("[FAIL] Could not locate production stage in rendered MFE Dockerfile")
    sys.exit(1)

if "COPY mereka/theme /openedx/dist/theme" not in parts[1]:
    print("[FAIL] Rendered MFE production stage missing theme COPY")
    sys.exit(1)

print("[PASS] Rendered MFE production stage carries theme COPY")
PY

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
