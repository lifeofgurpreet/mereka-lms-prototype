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

run_case() {
  local name=$1
  local file=$2
  local expect_fail=$3
  local allowlist_file=${4-}
  local baseline_file=${5-}
  local summary_file="$ROOT_DIR/${name}-summary.json"
  local -a args=("--summary-json" "$summary_file")
  if [ -n "${baseline_file}" ]; then
    args+=("--include-baseline" "--baseline-file" "$baseline_file")
  fi
  args+=("$ROOT_DIR/$file")
  local cmd=(bash docs/qa/verify-doc-command-refs.sh "${args[@]}")
  local return_code=0

  set +e
  if [ -n "${allowlist_file}" ]; then
    DOC_COMMAND_REF_ALLOWLIST_FILE="$allowlist_file" "${cmd[@]}" >"/tmp/cmd_ref_test_${name}.out" 2>&1
    return_code=$?
  else
    "${cmd[@]}" >"/tmp/cmd_ref_test_${name}.out" 2>&1
    return_code=$?
  fi
  set -e

  if [ "$expect_fail" -eq 1 ]; then
    if [ "$return_code" -eq 0 ]; then
      echo "[${name}] expected failure, got success"
      cat /tmp/cmd_ref_test_${name}.out
      return 1
    fi
  else
    if [ "$return_code" -ne 0 ]; then
      echo "[${name}] expected success, got failure"
      cat /tmp/cmd_ref_test_${name}.out
      return 1
    fi
  fi

  echo "$summary_file"
}

assert_summary_status() {
  local summary_file=$1
  local expect_status=$2
  local min_missing=$3

  if [ ! -f "$summary_file" ]; then
    echo "expected summary file missing: $summary_file"
    return 1
  fi

  python3 - "$summary_file" "$expect_status" "$min_missing" <<'PY'
import json
import sys
from pathlib import Path

summary = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
expect_status = sys.argv[2]
min_missing = int(sys.argv[3])

if summary.get("status") != expect_status:
    raise SystemExit(1)
if summary.get("missing_references", 0) < min_missing:
    raise SystemExit(1)
PY
}

mkdir -p "$ROOT_DIR/docs"

cat > "$ROOT_DIR/docs/cmdref-pass.md" <<'EOF_DOC'
# cmdref-pass

Valid references:

`docs/qa/verify-docs-policy.sh`

```bash
cd docs/
ls docs/qa/
```
EOF_DOC

cat > "$ROOT_DIR/docs/cmdref-fail.md" <<'EOF_DOC'
# cmdref-fail

Broken references:

`docs/qa/does-not-exist.sh`

```bash
echo docs/missing/path.md
```
EOF_DOC

cat > "$ROOT_DIR/docs/cmdref-allowed-missing.md" <<'EOF_DOC'
# cmdref-allowed-missing

Allowed generated paths:

`scripts/migrations/kajabi/output/course_structure.json`
`scripts/migrations/kajabi/output/course_packages/sample.tar.gz`
`scripts/migrations/kajabi/logs/`
`services/kajabi-webhook/outbox/event.ndjson`
`scripts/migrations/mct/output/course_packages/categories.csv`

```bash
python scripts/migrations/kajabi/output/course_structure.json
```
EOF_DOC

cat > "$ROOT_DIR/docs/cmdref-allowed-missing-override.md" <<'EOF_DOC'
# cmdref-allowed-missing-override

Allowed via custom allowlist override:

`scripts/custom/preview/outbox/delta.json`

```bash
cat scripts/custom/preview/outbox/delta.json
```
EOF_DOC

cat > "$ROOT_DIR/docs/.doc-command-ref-allowlist" <<'EOF_DOC'
scripts/custom/preview/outbox/
EOF_DOC

cat > "$ROOT_DIR/docs/.doc-command-ref-allowlist-extra" <<'EOF_DOC'
scripts/custom/preview/outbox/
EOF_DOC

printf '%s\n' "$ROOT_DIR/docs/cmdref-pass.md" > "$ROOT_DIR/docs/.doc-command-ref-baseline-pass"
printf '%s\n' "$ROOT_DIR/docs/cmdref-fail.md" > "$ROOT_DIR/docs/.doc-command-ref-baseline-fail"

PASS_SUMMARY=$(run_case pass docs/cmdref-pass.md 0)
FAIL_SUMMARY=$(run_case fail docs/cmdref-fail.md 1)
ALLOWED_SUMMARY=$(run_case allowed-missing docs/cmdref-allowed-missing.md 0)
OVERRIDE_SUMMARY=$(run_case allowed-missing-override docs/cmdref-allowed-missing-override.md 0 "$ROOT_DIR/docs/.doc-command-ref-allowlist-extra")
BASELINE_PASS_SUMMARY=$(run_case baseline-pass docs/cmdref-pass.md 0 "" "$ROOT_DIR/docs/.doc-command-ref-baseline-pass")
BASELINE_FAIL_SUMMARY=$(run_case baseline-fail docs/cmdref-pass.md 1 "" "$ROOT_DIR/docs/.doc-command-ref-baseline-fail")

grep -q "DOCS_CMDREF_ERRORS" /tmp/cmd_ref_test_fail.out
assert_summary_status "$FAIL_SUMMARY" fail 1
assert_summary_status "$PASS_SUMMARY" pass 0
assert_summary_status "$ALLOWED_SUMMARY" pass 0
assert_summary_status "$OVERRIDE_SUMMARY" pass 0
assert_summary_status "$BASELINE_PASS_SUMMARY" pass 0
assert_summary_status "$BASELINE_FAIL_SUMMARY" fail 1

echo "verify-doc-command-refs self-test: OK"
