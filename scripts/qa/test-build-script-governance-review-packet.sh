#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT="${REPO_ROOT}/scripts/qa/build-script-governance-review-packet.sh"
OUT_DIR="$(mktemp -d)"
trap 'rm -rf "$OUT_DIR"' EXIT

"$SCRIPT" --out-dir "$OUT_DIR" >/dev/null

for file in scope.md claims.md script_governance_catalog.json summary.md orphan_candidates.txt dangerous_scripts.txt; do
  if [[ ! -s "$OUT_DIR/$file" ]]; then
    echo "FAIL missing output file: $file" >&2
    exit 1
  fi
done

python3 - <<'PY' "$OUT_DIR/script_governance_catalog.json"
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
required = {"summary", "scripts", "orphan_candidates", "dangerous_scripts"}
missing = required - payload.keys()
if missing:
    raise SystemExit(f"missing keys: {sorted(missing)}")
if payload["summary"].get("total_scripts", 0) <= 0:
    raise SystemExit("expected at least one script in summary.total_scripts")
PY

echo "OK"
