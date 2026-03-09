#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(mktemp -d)
trap 'rm -rf "$ROOT_DIR"' EXIT
mkdir -p "$ROOT_DIR/docs/reference/test" "$ROOT_DIR/docs/status/weekly"
mkdir -p "$ROOT_DIR/docs/guides/admin"
mkdir -p "$ROOT_DIR/docs/adr"

cat > "$ROOT_DIR/docs/README.md" <<'EOF'
# Docs
See [linked](reference/test/linked.md)
EOF

cat > "$ROOT_DIR/docs/status/INDEX.md" <<'EOF'
# Status
EOF

cat > "$ROOT_DIR/docs/status/weekly/README.md" <<'EOF'
# Weekly
EOF

cat > "$ROOT_DIR/docs/reference/test/linked.md" <<'EOF'
# Linked
EOF

cat > "$ROOT_DIR/docs/guides/admin/guide.md" <<'EOF'
# Guide
See [status](../../status/weekly/README.md)
EOF

cat > "$ROOT_DIR/docs/reference/test/orphan.md" <<'EOF'
# Orphan
EOF

cat > "$ROOT_DIR/docs/adr/superseded.md" <<'EOF'
---
status: superseded
superseded_by: docs/adr/rfc/new-path.md
---

# Superseded
EOF

SUMMARY="$ROOT_DIR/summary.json"
python3 tools/docs/verify/scan-doc-orphans.py --root "$ROOT_DIR" --summary-file "$SUMMARY" >/tmp/doc_orphan_scan.out

grep -q 'DOC_ORPHAN_SCAN_ADVISORY' /tmp/doc_orphan_scan.out
python3 - "$SUMMARY" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["orphan_docs_count"] == 2, payload
assert payload["orphan_docs_sample"] == ["guides/admin/guide.md", "reference/test/orphan.md"], payload
PY

echo "scan-doc-orphans self-test: OK"
