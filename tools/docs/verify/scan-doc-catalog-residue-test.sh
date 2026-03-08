#!/usr/bin/env bash
set -euo pipefail

TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p \
  "$TMP_ROOT/docs/ops" \
  "$TMP_ROOT/docs/status" \
  "$TMP_ROOT/docs/guides" \
  "$TMP_ROOT/generated/catalogs"

cat > "$TMP_ROOT/docs/ops/CANON.md" <<'EOF_DOC'
# Canon
EOF_DOC

cat > "$TMP_ROOT/docs/status/UNCATALOGED.md" <<'EOF_DOC'
# Missing from catalog
EOF_DOC

cat > "$TMP_ROOT/generated/catalogs/docs-catalog.json" <<'EOF_JSON'
[
  {
    "path": "ops/CANON.md",
    "status": "canonical",
    "canonical_conflict_group": "ops.canon"
  },
  {
    "path": "guides/MISSING.md",
    "status": "canonical",
    "canonical_conflict_group": "guides.missing"
  }
]
EOF_JSON

python3 tools/docs/verify/scan-doc-catalog-residue.py \
  --root "$TMP_ROOT" \
  --summary-file "$TMP_ROOT/summary.json" >/tmp/scan_doc_catalog_residue.out

grep -q "DOCS_CATALOG_RESIDUE_ADVISORY uncataloged_winning_docs=1 stale_catalog_entries=1 duplicate_groups=0" /tmp/scan_doc_catalog_residue.out
grep -q '"uncataloged_winning_docs_count": 1' "$TMP_ROOT/summary.json"
grep -q '"stale_catalog_entries_count": 1' "$TMP_ROOT/summary.json"

if python3 tools/docs/verify/scan-doc-catalog-residue.py \
  --root "$TMP_ROOT" \
  --fail-on-residue \
  >/tmp/scan_doc_catalog_residue_fail.out 2>&1; then
  echo "expected residue failure in strict mode"
  cat /tmp/scan_doc_catalog_residue_fail.out
  exit 1
fi

grep -q "DOCS_CATALOG_RESIDUE_FAIL uncataloged_winning_docs=1 stale_catalog_entries=1 duplicate_groups=0" /tmp/scan_doc_catalog_residue_fail.out

cat > "$TMP_ROOT/generated/catalogs/docs-catalog.json" <<'EOF_JSON'
[
  {
    "path": "ops/CANON.md",
    "status": "canonical",
    "canonical_conflict_group": "ops.shared"
  },
  {
    "path": "status/UNCATALOGED.md",
    "status": "canonical",
    "canonical_conflict_group": "ops.shared"
  }
]
EOF_JSON

python3 tools/docs/verify/scan-doc-catalog-residue.py \
  --root "$TMP_ROOT" \
  --summary-file "$TMP_ROOT/summary-dupe.json" >/tmp/scan_doc_catalog_residue_dupe.out

grep -q "duplicate_groups=1" /tmp/scan_doc_catalog_residue_dupe.out
grep -q '"duplicate_canonical_groups_count": 1' "$TMP_ROOT/summary-dupe.json"

echo "scan-doc-catalog-residue self-test: OK"
