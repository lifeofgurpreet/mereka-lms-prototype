#!/usr/bin/env bash
# Verify Tutor-generated settings include our canonical production domains.
#
# Usage:
#   ./scripts/qa/verify-tutor-multisite-domains.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

f="tutor_env/env/apps/openedx/settings/lms/production.py"
if [[ ! -f "$f" ]]; then
  echo "[FAIL] Missing $f (generate tutor_env first)" >&2
  exit 1
fi

for host in academyv2.mereka.io academy.biji-biji.com skillourfuture.academy.mereka.io; do
  rg -n --fixed-strings -- "$host" "$f" >/dev/null 2>&1 || { echo "[FAIL] Missing domain in LMS production settings: $host" >&2; exit 1; }
done

echo "OK"

