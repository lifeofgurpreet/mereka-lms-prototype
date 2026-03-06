#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=${1:-$(mktemp -d)}
KEEP_ROOT=0

if [ "${1-}" != "" ]; then
  KEEP_ROOT=1
fi

if [ ! -d "$ROOT_DIR" ]; then
  mkdir -p "$ROOT_DIR"
fi

cleanup() {
  if [ "$KEEP_ROOT" -eq 0 ]; then
    rm -rf "$ROOT_DIR"
  fi
}
trap cleanup EXIT

test_case() {
  local name=$1
  local catalog_json=$2
  local expect_fail=$3
  local args=("--max-stale-days" "30" "--root" "$ROOT_DIR" "$ROOT_DIR/$catalog_json")

  if [ "$expect_fail" -eq 1 ]; then
    if python3 docs/qa/verify-doc-catalog-health.py "${args[@]}" >/tmp/catalog_test_${name}.out 2>&1; then
      echo "[$name] expected failure, got success"
      cat /tmp/catalog_test_${name}.out
      return 1
    fi
  else
    if ! python3 docs/qa/verify-doc-catalog-health.py "${args[@]}" >/tmp/catalog_test_${name}.out 2>&1; then
      echo "[$name] expected success, got failure"
      cat /tmp/catalog_test_${name}.out
      return 1
    fi
  fi

  return 0
}

mkdir -p "$ROOT_DIR/docs"

cat > "$ROOT_DIR/docs/ok.md" <<'EOF_DOC'
# OK Doc
EOF_DOC
cat > "$ROOT_DIR/docs/stale.md" <<'EOF_DOC'
# Stale Doc
EOF_DOC

cat > "$ROOT_DIR/catalog-ok.json" <<'EOF_JSON'
[
  {
    "path": "ok.md",
    "status": "canonical",
    "owner": "Docs Team",
    "last_verified_or_updated": "2050-01-01",
    "freshness_risk": "low"
  }
]
EOF_JSON

test_case ok catalog-ok.json 0

grep -q "DOCS_CATALOG_OK" /tmp/catalog_test_ok.out

cat > "$ROOT_DIR/catalog-stale.json" <<'EOF_JSON'
[
  {
    "path": "stale.md",
    "status": "canonical",
    "owner": "Docs Team",
    "last_verified_or_updated": "2000-01-01",
    "freshness_risk": "low"
  }
]
EOF_JSON

test_case stale catalog-stale.json 1

grep -q "DOCS_CATALOG_ERRORS" /tmp/catalog_test_stale.out

cat > "$ROOT_DIR/catalog-missing-owner.json" <<'EOF_JSON'
[
  {
    "path": "ok.md",
    "status": "canonical",
    "owner": "",
    "last_verified_or_updated": "2050-01-01",
    "freshness_risk": "low"
  }
]
EOF_JSON

test_case missing-owner catalog-missing-owner.json 1

grep -q "Missing owner" /tmp/catalog_test_missing-owner.out

echo "verify-doc-catalog-health self-test: OK"
