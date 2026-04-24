#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

ARCHIVE_DOC="$TMP_ROOT/docs/archive/test.md"
mkdir -p "$(dirname "$ARCHIVE_DOC")"
printf '# archive test\n' > "$ARCHIVE_DOC"

if python3 tools/docs/verify/verify-archive-write-protection.py "$ARCHIVE_DOC" >/tmp/verify_archive_fail.out 2>&1; then
  echo "expected archive write protection failure"
  exit 1
fi
grep -q "ARCHIVE_WRITE_PROTECTION_FAIL" /tmp/verify_archive_fail.out

DOCS_ALLOW_ARCHIVE_WRITES=1 \
  python3 tools/docs/verify/verify-archive-write-protection.py "$ARCHIVE_DOC" >/tmp/verify_archive_pass.out 2>&1
grep -q "ARCHIVE_WRITE_PROTECTION_AUTHORIZED" /tmp/verify_archive_pass.out

echo "verify-archive-write-protection self-test: OK"
