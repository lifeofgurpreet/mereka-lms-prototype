#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
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

PASS_DIR="$ROOT_DIR/pass"
FAIL_DIR="$ROOT_DIR/fail"
mkdir -p "$PASS_DIR/docs" "$FAIL_DIR/docs"

cat > "$PASS_DIR/docs/good-a.md" <<'EOF_DOC'
# good-a
EOF_DOC
cat > "$PASS_DIR/docs/good-b.md" <<'EOF_DOC'
# good-b
EOF_DOC

printf '%s\n' "$PASS_DIR/docs/good-a.md" > "$PASS_DIR/baseline.txt"
printf '%s\n' "$PASS_DIR/docs/good-b.md" >> "$PASS_DIR/baseline.txt"

PASS_SUMMARY="$ROOT_DIR/pass-summary.json"
(
  cd "$PASS_DIR"
  "$REPO_ROOT/docs/qa/verify-doc-command-ref-baseline.sh" \
    --baseline-file "$PASS_DIR/baseline.txt" \
    --summary-json "$PASS_SUMMARY" >/tmp/docs_cmdref_baseline_pass.out 2>&1
)

python3 - "$PASS_SUMMARY" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "pass"
assert payload["entries"] == 2
PY

cat > "$FAIL_DIR/docs/good-a.md" <<'EOF_DOC'
# good-a
EOF_DOC
cat > "$FAIL_DIR/docs/not-markdown.txt" <<'EOF_DOC'
text
EOF_DOC
printf '%s\n' "$FAIL_DIR/docs/good-a.md" > "$FAIL_DIR/baseline.txt"
printf '%s\n' "$FAIL_DIR/docs/good-a.md" >> "$FAIL_DIR/baseline.txt"
printf '%s\n' "$FAIL_DIR/docs/missing.md" >> "$FAIL_DIR/baseline.txt"
printf '%s\n' "$FAIL_DIR/docs/not-markdown.txt" >> "$FAIL_DIR/baseline.txt"

if (
  cd "$FAIL_DIR" && \
  "$REPO_ROOT/docs/qa/verify-doc-command-ref-baseline.sh" \
    --baseline-file "$FAIL_DIR/baseline.txt" >/tmp/docs_cmdref_baseline_fail.out 2>&1
); then
  echo "expected baseline verifier to fail"
  exit 1
fi

grep -q "DOCS_CMDREF_BASELINE_FAIL" /tmp/docs_cmdref_baseline_fail.out
grep -q "duplicate: $FAIL_DIR/docs/good-a.md" /tmp/docs_cmdref_baseline_fail.out
grep -q "missing: $FAIL_DIR/docs/missing.md" /tmp/docs_cmdref_baseline_fail.out
grep -q "invalid_non_markdown: $FAIL_DIR/docs/not-markdown.txt" /tmp/docs_cmdref_baseline_fail.out

echo "verify-doc-command-ref-baseline self-test: OK"
