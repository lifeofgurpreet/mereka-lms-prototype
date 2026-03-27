#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
GENERATOR="${REPO_ROOT}/scripts/qa/generate-script-governance-catalog.py"
ALLOWLIST_FILE="${ALLOWLIST_FILE_OVERRIDE:-${REPO_ROOT}/scripts/qa/fixtures/script-governance-orphan-allowlist.txt}"

if [[ ! -f "$ALLOWLIST_FILE" ]]; then
  echo "FAIL: orphan allowlist file missing: $ALLOWLIST_FILE" >&2
  exit 1
fi

contains_path() {
  local needle="$1"
  shift || true
  local candidate
  for candidate in "$@"; do
    if [[ "$candidate" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

OUT_JSON="${TMP_DIR}/catalog.json"
OUT_MD="${TMP_DIR}/summary.md"
python3 "$GENERATOR" --repo-root "$REPO_ROOT" --out "$OUT_JSON" --summary-out "$OUT_MD" >/dev/null

mapfile -t current_orphans < <(
  python3 - <<'PY' "$OUT_JSON"
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for path in payload.get("orphan_candidates", []):
    print(path)
PY
)
mapfile -t allowlisted_orphans < <(
  sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$ALLOWLIST_FILE"
)

unexpected=()
for path in "${current_orphans[@]}"; do
  if ! contains_path "$path" "${allowlisted_orphans[@]}"; then
    unexpected+=("$path")
  fi
done

stale=()
for path in "${allowlisted_orphans[@]}"; do
  if ! contains_path "$path" "${current_orphans[@]}"; then
    stale+=("$path")
  fi
done

if [[ "${#unexpected[@]}" -gt 0 ]]; then
  echo "FAIL: new orphan script candidates detected."
  printf '  %s\n' "${unexpected[@]}"
  exit 1
fi

if [[ "${#stale[@]}" -gt 0 ]]; then
  echo "WARN: stale orphan allowlist entries detected (safe to remove):"
  printf '  %s\n' "${stale[@]}"
fi

echo "PASS: orphan script candidates match allowlisted baseline."
