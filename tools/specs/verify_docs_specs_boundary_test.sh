#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/docs" "$tmpdir/specs"

cat >"$tmpdir/docs/catalog.json" <<'JSON'
[
  {"path": "README.md", "owner": "docs", "status": "active", "type": "guide"}
]
JSON

cat >"$tmpdir/specs/catalog.json" <<'JSON'
{
  "root": "specs",
  "entries": [
    {"path": "specs/example_spec.md", "spec_class": "system", "normativity": "normative"},
    {"path": "specs/plans/rollout-plan.md", "spec_class": "plan", "normativity": "planning"},
    {"path": "specs/proposals/new-contract.md", "spec_class": "proposal", "normativity": "proposed"}
  ]
}
JSON

python3 tools/specs/verify_docs_specs_boundary.py --repo-root "$tmpdir" >/dev/null

python3 - <<'PY' "$tmpdir"
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
docs = root / "docs" / "catalog.json"
data = json.loads(docs.read_text())
data.append({"path": "specs/bad.md"})
docs.write_text(json.dumps(data))
PY

if python3 tools/specs/verify_docs_specs_boundary.py --repo-root "$tmpdir" >/dev/null 2>&1; then
  echo "verify_docs_specs_boundary should fail on docs/specs overlap"
  exit 1
fi

echo "verify_docs_specs_boundary self-test: OK"
