#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../../.." && pwd)

ROOT_DIR=$(mktemp -d)
trap 'rm -rf "$ROOT_DIR"' EXIT

mkdir -p \
  "$ROOT_DIR/docs/concepts/architecture" \
  "$ROOT_DIR/docs/adr" \
  "$ROOT_DIR/generated/catalogs"

cat > "$ROOT_DIR/docs/README.md" <<'EOF_DOC'
# Docs Home
_Audience: Everyone • Owner: Platform Team • Last verified: 2026-03-08 • Status: canonical_
EOF_DOC

cat > "$ROOT_DIR/docs/concepts/architecture/CONTROL_PLANES.md" <<'EOF_DOC'
# Control Planes
_Audience: Contributors • Owner: Platform Team • Last updated: 2026-03-07 • Status: canonical_
EOF_DOC

cat > "$ROOT_DIR/docs/adr/001-sample.md" <<'EOF_DOC'
# ADR-001: Sample

**Status**: Accepted
**Date**: 2026-02-01

<!-- Last verified: 2026-02-13 -->
EOF_DOC

cat > "$ROOT_DIR/generated/catalogs/docs-catalog.json" <<'EOF_JSON'
[
  {
    "canonical_conflict_group": null,
    "freshness_risk": "low",
    "last_verified_or_updated": "2026-03-08",
    "owner": "Platform Team",
    "path": "README.md",
    "status": "canonical",
    "type": "index"
  }
]
EOF_JSON

python3 "$REPO_ROOT/tools/docs/verify/build-doc-catalog.py" --root "$ROOT_DIR" >/tmp/build_doc_catalog_test.out
grep -q "DOCS_CATALOG_BUILD_OK mode=write entries=3" /tmp/build_doc_catalog_test.out

python3 - <<'PY' "$ROOT_DIR/generated/catalogs/docs-catalog.json" "$ROOT_DIR/docs/catalog.json"
import json, sys
source = json.loads(open(sys.argv[1]).read())
mirror = json.loads(open(sys.argv[2]).read())
assert source == mirror
entries = {entry["path"]: entry for entry in source}
assert entries["README.md"]["status"] == "canonical"
assert entries["concepts/architecture/CONTROL_PLANES.md"]["last_verified_or_updated"] == "2026-03-07"
assert entries["adr/001-sample.md"]["last_verified_or_updated"] == "2026-02-13"
assert entries["adr/001-sample.md"]["status"] == "supporting"
PY

python3 "$REPO_ROOT/tools/docs/verify/build-doc-catalog.py" --root "$ROOT_DIR" --check >/tmp/build_doc_catalog_check.out
grep -q "DOCS_CATALOG_BUILD_OK mode=check entries=3" /tmp/build_doc_catalog_check.out

python3 - <<'PY' "$ROOT_DIR/generated/catalogs/docs-catalog.json"
import json, sys
path = sys.argv[1]
payload = json.loads(open(path).read())
payload[0]["owner"] = "Wrong Owner"
open(path, "w").write(json.dumps(payload, indent=2, sort_keys=True) + "\n")
PY

if python3 "$REPO_ROOT/tools/docs/verify/build-doc-catalog.py" --root "$ROOT_DIR" --check >/tmp/build_doc_catalog_drift.out 2>&1; then
  echo "expected build-doc-catalog --check to fail on drift"
  cat /tmp/build_doc_catalog_drift.out
  exit 1
fi
grep -q "DOCS_CATALOG_DRIFT" /tmp/build_doc_catalog_drift.out

echo "build-doc-catalog self-test: OK"
