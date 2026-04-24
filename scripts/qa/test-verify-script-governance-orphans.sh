#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
VERIFY_SCRIPT="${REPO_ROOT}/scripts/qa/verify-script-governance-orphans.sh"
GENERATOR="${REPO_ROOT}/scripts/qa/generate-script-governance-catalog.py"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

python3 "$GENERATOR" --repo-root "$REPO_ROOT" --out "$TMP_DIR/catalog.json" --summary-out "$TMP_DIR/summary.md" >/dev/null
ORPHAN_COUNT="$(
  python3 - <<'PY' "$TMP_DIR/catalog.json"
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
print(len(payload.get("orphan_candidates", [])))
PY
)"

SCRIPT_GOVERNANCE_CATALOG_JSON_OVERRIDE="$TMP_DIR/catalog.json" "$VERIFY_SCRIPT" >/dev/null
echo "PASS baseline allowlist passes"

EMPTY_ALLOWLIST="$(mktemp)"
if [[ "$ORPHAN_COUNT" -gt 0 ]]; then
  if ALLOWLIST_FILE_OVERRIDE="$EMPTY_ALLOWLIST" \
    SCRIPT_GOVERNANCE_CATALOG_JSON_OVERRIDE="$TMP_DIR/catalog.json" \
    "$VERIFY_SCRIPT" >/dev/null 2>&1; then
    echo "FAIL expected failure with empty allowlist while orphan candidates exist" >&2
    exit 1
  fi
  echo "PASS empty allowlist fails as expected"
else
  ALLOWLIST_FILE_OVERRIDE="$EMPTY_ALLOWLIST" \
    SCRIPT_GOVERNANCE_CATALOG_JSON_OVERRIDE="$TMP_DIR/catalog.json" \
    "$VERIFY_SCRIPT" >/dev/null
  echo "PASS empty allowlist passes because orphan candidate count is zero"
fi

echo "OK"
