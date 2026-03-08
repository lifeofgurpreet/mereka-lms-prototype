#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS_DOC="$TMP_ROOT/docs/operations/pass.md"
FAIL_DOC="$TMP_ROOT/docs/operations/fail.md"
mkdir -p "$(dirname "$PASS_DOC")"

cat > "$PASS_DOC" <<'EOF_DOC'
---
status: superseded
superseded_by: docs/ops/runbooks/pass.md
---

# Superseded
EOF_DOC

cat > "$FAIL_DOC" <<'EOF_DOC'
# Real content

This should fail.
EOF_DOC

python3 tools/docs/verify/verify-stub-only-transitional-dirs.py "$PASS_DOC" >/tmp/verify_stub_pass.out 2>&1
grep -q "TRANSITIONAL_STUB_OK" /tmp/verify_stub_pass.out

if python3 tools/docs/verify/verify-stub-only-transitional-dirs.py "$FAIL_DOC" >/tmp/verify_stub_fail.out 2>&1; then
  echo "expected failure for non-stub transitional doc"
  exit 1
fi
grep -q "TRANSITIONAL_STUB_ERRORS" /tmp/verify_stub_fail.out

echo "verify-stub-only-transitional-dirs self-test: OK"
