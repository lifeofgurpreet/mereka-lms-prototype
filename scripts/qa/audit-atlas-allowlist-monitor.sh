#!/usr/bin/env bash
# Audit Atlas allowlist monitor posture on VPS host.
#
# Validates:
# - monitor scripts exist
# - cron wiring exists
# - status file is fresh
# - drift status is not active
# - webhook routing is configured (optional strict mode)
#
# Usage:
#   ./scripts/qa/audit-atlas-allowlist-monitor.sh
#   STRICT_WEBHOOK=1 ./scripts/qa/audit-atlas-allowlist-monitor.sh
#   RUN_MONITOR_NOW=0 ./scripts/qa/audit-atlas-allowlist-monitor.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

STATUS_FILE="${STATUS_FILE:-${REPO_ROOT}/var/atlas-allowlist-status.json}"
MAX_STATUS_AGE_MINUTES="${MAX_STATUS_AGE_MINUTES:-90}"
STRICT_WEBHOOK="${STRICT_WEBHOOK:-0}"
RUN_MONITOR_NOW="${RUN_MONITOR_NOW:-1}"

failures=0

ok() { echo "OK   $*"; }
warn() { echo "WARN $*"; }
fail() { echo "FAIL $*"; failures=$((failures + 1)); }

check_repo_scripts() {
  local missing=0
  local f
  for f in \
    scripts/infra/check-atlas-allowlist-vps.sh \
    scripts/infra/monitor-atlas-allowlist-vps.sh \
    scripts/infra/setup-vps-atlas-allowlist-cron.sh
  do
    if [[ ! -f "$f" ]]; then
      echo "missing: $f"
      missing=1
    fi
  done
  return "$missing"
}

check_cron_wiring() {
  if ! command -v crontab >/dev/null 2>&1; then
    echo "crontab command not found"
    return 1
  fi
  if ! crontab -l 2>/dev/null | rg -q "monitor-atlas-allowlist-vps\\.sh"; then
    echo "crontab does not include monitor-atlas-allowlist-vps.sh"
    return 1
  fi
}

check_status_freshness() {
  if [[ ! -f "$STATUS_FILE" ]]; then
    echo "status file missing: $STATUS_FILE"
    return 1
  fi

  python3 - "$STATUS_FILE" "$MAX_STATUS_AGE_MINUTES" <<'PY'
import json
import sys
from datetime import datetime, timezone

status_file = sys.argv[1]
max_age_minutes = float(sys.argv[2])

with open(status_file, "r", encoding="utf-8") as f:
    obj = json.load(f)

ts = obj.get("timestamp_utc")
if not ts:
    raise SystemExit(f"timestamp_utc missing in {status_file}")
dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
age_minutes = (datetime.now(timezone.utc) - dt).total_seconds() / 60.0
if age_minutes > max_age_minutes:
    raise SystemExit(
        f"status stale: age={age_minutes:.1f}m > {max_age_minutes:.1f}m ({status_file})"
    )
print(f"status_age_minutes={age_minutes:.1f}")
PY
}

check_status_ok() {
  python3 - "$STATUS_FILE" <<'PY'
import json
import sys
with open(sys.argv[1], "r", encoding="utf-8") as f:
    obj = json.load(f)
status = (obj.get("status") or "").strip().lower()
if status != "ok":
    raise SystemExit(f"status is not ok: {status}")
print("status=ok")
PY
}

check_webhook_configured() {
  if [[ "$STRICT_WEBHOOK" != "1" ]]; then
    return 0
  fi
  python3 - "$STATUS_FILE" <<'PY'
import json
import sys
with open(sys.argv[1], "r", encoding="utf-8") as f:
    obj = json.load(f)
if not bool(obj.get("webhook_configured")):
    raise SystemExit("webhook_configured=false in status file")
print("webhook_configured=true")
PY
}

run_check() {
  local name="$1"; shift
  local tmp rc out
  tmp="$(mktemp -t audit-atlas-allowlist.XXXXXX)"
  set +e
  "$@" >"$tmp" 2>&1
  rc=$?
  set -e
  out="$(cat "$tmp")"
  rm -f "$tmp"

  if [[ "$rc" -eq 0 ]]; then
    ok "$name"
  else
    fail "$name"
    if [[ -n "$out" ]]; then
      echo "$out" | sed 's/^/  /'
    fi
  fi
}

echo "Audit: Atlas allowlist monitor (VPS)"
echo "  status_file: $STATUS_FILE"
echo "  max_age_min: $MAX_STATUS_AGE_MINUTES"
echo "  strict_webhook: $STRICT_WEBHOOK"
echo ""

run_check "repo: monitor scripts exist" check_repo_scripts
run_check "runtime: cron wiring exists" check_cron_wiring

if [[ "$RUN_MONITOR_NOW" == "1" ]]; then
  run_check "runtime: monitor execution (current state)" ./scripts/infra/monitor-atlas-allowlist-vps.sh
fi

run_check "runtime: status freshness" check_status_freshness
run_check "runtime: status is ok" check_status_ok
run_check "runtime: webhook configured" check_webhook_configured

echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "OK"
else
  echo "FAILED ($failures checks failed)"
fi

[[ "$failures" -eq 0 ]]

