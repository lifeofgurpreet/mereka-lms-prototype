#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
GENERATOR="${REPO_ROOT}/scripts/qa/generate-script-governance-catalog.py"
OUT_DIR="$(mktemp -d)"
trap 'rm -rf "$OUT_DIR"' EXIT

OUT_JSON="${OUT_DIR}/script_governance_catalog.json"
OUT_MD="${OUT_DIR}/summary.md"

python3 "$GENERATOR" --repo-root "$REPO_ROOT" --out "$OUT_JSON" --summary-out "$OUT_MD" >/dev/null

if [[ ! -s "$OUT_JSON" || ! -s "$OUT_MD" ]]; then
  echo "FAIL: governance census outputs are missing or empty" >&2
  exit 1
fi

python3 - <<'PY' "$OUT_JSON"
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
summary = payload.get("summary", {})
if summary.get("total_scripts", 0) <= 0:
    raise SystemExit("summary.total_scripts must be > 0")
required = {"statuses", "mutability", "risks"}
missing = sorted(required - summary.keys())
if missing:
    raise SystemExit(f"summary missing keys: {missing}")
PY

echo "PASS: script governance census catalog is generated and structurally valid."
