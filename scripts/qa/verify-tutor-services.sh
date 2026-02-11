#!/usr/bin/env bash
# Best-effort Tutor runtime verification.
#
# This is intended to be run by operators locally (not in CI):
# - Confirms Tutor env is set up
# - Confirms docker services are up (tutor local dc ps)
#
# Usage:
#   ./scripts/qa/verify-tutor-services.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -d ".venv" ]]; then
  echo "SKIP: Missing .venv (run: make bootstrap)"
  exit 0
fi

if [[ ! -d "tutor_env" ]]; then
  echo "SKIP: Missing tutor_env (set TUTOR_ROOT and run tutor config save / quickstart)"
  exit 0
fi

if ! command -v tutor >/dev/null 2>&1; then
  echo "SKIP: tutor command not found (activate venv + source tutor env)"
  exit 0
fi

set +e
tutor local dc ps >/tmp/tutor-dc-ps.txt 2>&1
rc=$?
set -e
if [[ "$rc" -ne 0 ]]; then
  echo "[FAIL] tutor local dc ps failed" >&2
  tail -n 60 /tmp/tutor-dc-ps.txt >&2 || true
  exit 1
fi

if rg -n "\\sUp\\s" /tmp/tutor-dc-ps.txt >/dev/null 2>&1; then
  echo "OK"
  exit 0
fi

echo "[FAIL] No services reported as Up in tutor local dc ps output" >&2
cat /tmp/tutor-dc-ps.txt >&2
exit 1

