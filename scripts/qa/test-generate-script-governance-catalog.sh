#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
GENERATOR="${REPO_ROOT}/scripts/qa/generate-script-governance-catalog.py"
OUT_DIR="$(mktemp -d)"
trap 'rm -rf "$OUT_DIR"' EXIT

OUT_JSON="${OUT_DIR}/catalog.json"
OUT_MD="${OUT_DIR}/summary.md"

python3 "$GENERATOR" --repo-root "$REPO_ROOT" --out "$OUT_JSON" --summary-out "$OUT_MD" >/dev/null

test -s "$OUT_JSON"
test -s "$OUT_MD"

python3 - <<'PY' "$OUT_JSON"
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("summary", {}).get("total_scripts", 0) <= 0:
    raise SystemExit("expected at least one script in governance catalog")

scripts = {entry["path"]: entry for entry in payload.get("scripts", [])}
paths = set(scripts)
if "scripts/qa/verify-repo-structure.sh" not in paths:
    raise SystemExit("expected verify-repo-structure.sh to be cataloged")

runtime_entry = scripts.get("scripts/qa/verify-dev-visual-correctness.sh")
if not runtime_entry:
    raise SystemExit("expected verify-dev-visual-correctness.sh to be cataloged")
if runtime_entry.get("status") != "inventory_authoritative":
    raise SystemExit("expected verify-dev-visual-correctness.sh to be inventory_authoritative")
if "ci_runtime_inventory" not in set(runtime_entry.get("caller_types", [])):
    raise SystemExit("expected verify-dev-visual-correctness.sh to be covered by ci_runtime_inventory")
PY

echo "OK"
