#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR=${1:-$(mktemp -d -p "$SCRIPT_DIR" "link-integrity-test-XXXXXX")}
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

run_case() {
  local name=$1
  local file=$2
  local expect_fail=$3
  local out="/tmp/link_integrity_test_${name}.out"
  local summary="/tmp/link_integrity_test_${name}.json"

  if [ "$expect_fail" -eq 1 ]; then
    if tools/docs/verify/verify-doc-link-integrity.sh --summary-json "$summary" "$ROOT_DIR/$file" >"$out" 2>&1; then
      echo "[${name}] expected failure, got success"
      cat "$out"
      return 1
    fi
  else
    if ! tools/docs/verify/verify-doc-link-integrity.sh --summary-json "$summary" "$ROOT_DIR/$file" >"$out" 2>&1; then
      echo "[${name}] expected success, got failure"
      cat "$out"
      return 1
    fi
  fi

  if [ "$expect_fail" -eq 1 ]; then
    grep -q "DOCS_LINK_INTEGRITY_ERRORS" "$out"
    python3 - "$summary" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding='utf-8'))
assert payload["status"] == "fail"
assert payload["broken_links"] > 0
PY
  else
    grep -q "DOCS_LINK_INTEGRITY_OK" "$out"
    python3 - "$summary" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding='utf-8'))
assert payload["status"] == "pass"
assert payload["broken_links"] == 0
PY
  fi
}

mkdir -p "$ROOT_DIR/docs/subdir"

cat > "$ROOT_DIR/docs/link-pass-target.md" <<'EOF_DOC'
# link-pass-target

Anchor target doc.
EOF_DOC

cat > "$ROOT_DIR/docs/link-pass-anchor.md" <<'EOF_DOC'
# Anchor note

## anchor-note
EOF_DOC

cat > "$ROOT_DIR/docs/link-pass.md" <<'EOF_DOC'
# link-pass

Sibling and absolute-doc links.

- [target](./link-pass-target.md)
- [target-with-anchor](./link-pass-anchor.md#anchor-note)
EOF_DOC

cat > "$ROOT_DIR/docs/link-fail.md" <<'EOF_DOC'
# link-fail

Broken links.

- [missing-file](./missing-doc.md)
- [bad-root-link](docs/does-not-exist.md)
EOF_DOC

run_case pass "docs/link-pass.md" 0
run_case fail "docs/link-fail.md" 1

echo "verify-doc-link-integrity self-test: OK"
