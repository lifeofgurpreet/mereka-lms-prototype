#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
GENERATOR="${REPO_ROOT}/scripts/qa/generate-script-governance-catalog.py"
ALLOWLIST_FILE="${ALLOWLIST_FILE_OVERRIDE:-${REPO_ROOT}/scripts/qa/fixtures/script-governance-dangerous-allowlist.txt}"

if [[ ! -f "$ALLOWLIST_FILE" ]]; then
  echo "FAIL: dangerous allowlist file missing: $ALLOWLIST_FILE" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

OUT_JSON="${TMP_DIR}/catalog.json"
OUT_MD="${TMP_DIR}/summary.md"
python3 "$GENERATOR" --repo-root "$REPO_ROOT" --out "$OUT_JSON" --summary-out "$OUT_MD" >/dev/null

mapfile -t current_dangerous < <(
  python3 - <<'PY' "$OUT_JSON"
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for path in payload.get("dangerous_scripts", []):
    print(path)
PY
)
mapfile -t allowlisted_dangerous < <(
  sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$ALLOWLIST_FILE"
)

unexpected=()
for path in "${current_dangerous[@]}"; do
  if ! printf '%s\n' "${allowlisted_dangerous[@]}" | grep -Fxq "$path"; then
    unexpected+=("$path")
  fi
done

stale=()
for path in "${allowlisted_dangerous[@]}"; do
  if ! printf '%s\n' "${current_dangerous[@]}" | grep -Fxq "$path"; then
    stale+=("$path")
  fi
done

if [[ "${#unexpected[@]}" -gt 0 ]]; then
  echo "FAIL: new dangerous script candidates detected."
  printf '  %s\n' "${unexpected[@]}"
  exit 1
fi

if [[ "${#stale[@]}" -gt 0 ]]; then
  echo "WARN: stale dangerous allowlist entries detected (safe to remove):"
  printf '  %s\n' "${stale[@]}"
fi

echo "PASS: dangerous script candidates match allowlisted baseline."
