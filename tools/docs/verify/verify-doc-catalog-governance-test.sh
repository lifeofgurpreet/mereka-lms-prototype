#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/generated/catalogs" "$TMP_ROOT/docs/reference"

cat > "$TMP_ROOT/generated/catalogs/docs-catalog.json" <<'EOF_JSON'
[
  {
    "path": "reference/ok.md",
    "status": "canonical",
    "canonical_conflict_group": "ok-group"
  }
]
EOF_JSON

cat > "$TMP_ROOT/docs/reference/ok.md" <<'EOF_DOC'
# ok
EOF_DOC

python3 tools/docs/verify/verify-doc-catalog-governance.py \
  --root "$TMP_ROOT" \
  --range "HEAD...HEAD" \
  --catalog "generated/catalogs/docs-catalog.json" \
  "docs/reference/ok.md" \
  "generated/catalogs/docs-catalog.json" >/tmp/verify_catalog_governance_pass.out 2>&1
grep -q "DOCS_CATALOG_GOVERNANCE_OK" /tmp/verify_catalog_governance_pass.out

cat > "$TMP_ROOT/generated/catalogs/docs-catalog.json" <<'EOF_JSON'
[
  {
    "path": "reference/a.md",
    "status": "canonical",
    "canonical_conflict_group": "dup"
  },
  {
    "path": "reference/b.md",
    "status": "canonical",
    "canonical_conflict_group": "dup"
  }
]
EOF_JSON

cat > "$TMP_ROOT/docs/reference/a.md" <<'EOF_DOC'
# a
EOF_DOC

if python3 tools/docs/verify/verify-doc-catalog-governance.py \
  --root "$TMP_ROOT" \
  --range "HEAD...HEAD" \
  --catalog "generated/catalogs/docs-catalog.json" \
  "docs/reference/a.md" >/tmp/verify_catalog_governance_fail.out 2>&1; then
  echo "expected duplicate canonical governance failure"
  exit 1
fi
grep -q "DOCS_CATALOG_GOVERNANCE_FAIL" /tmp/verify_catalog_governance_fail.out

cat > "$TMP_ROOT/generated/catalogs/docs-catalog.json" <<'EOF_JSON'
[
  {
    "path": "reference/ok.md",
    "status": "canonical",
    "canonical_conflict_group": "ok-group"
  }
]
EOF_JSON

if python3 tools/docs/verify/verify-doc-catalog-governance.py \
  --root "$TMP_ROOT" \
  --range "HEAD...HEAD" \
  --catalog "generated/catalogs/docs-catalog.json" \
  "docs/reference/ok.md" >/tmp/verify_catalog_governance_missing_catalog.out 2>&1; then
  echo "expected missing source catalog update failure"
  exit 1
fi
grep -q "changed winning-root docs require a matching update to generated/catalogs/docs-catalog.json" /tmp/verify_catalog_governance_missing_catalog.out

echo "verify-doc-catalog-governance self-test: OK"
